class Assistant::Function::UpdateTransaction < Assistant::Function
  class << self
    def name
      "update_transaction"
    end

    def description
      <<~INSTRUCTIONS
        Updates an existing transaction. Only include the fields you want to change —
        omitted fields are left as-is.

        As with create_transaction, a positive amount is an expense and a negative amount
        is income; set nature to "income"/"expense" to apply the sign explicitly.
        Pass tag_ids to replace the transaction's tags (an empty array clears them).
        Use get_transactions to find transaction ids. date must be YYYY-MM-DD.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "transaction_id" ],
      properties: {
        transaction_id: {
          type: "string",
          description: "UUID of the transaction to update (from get_transactions)"
        },
        amount: {
          type: "number",
          description: "New amount. Positive = expense, negative = income, unless nature is set."
        },
        name: {
          type: "string",
          description: "New transaction name / payee"
        },
        date: {
          type: "string",
          description: "New transaction date in YYYY-MM-DD format"
        },
        nature: {
          type: "string",
          description: "Optional. 'income' or 'expense' to set the amount sign explicitly.",
          enum: [ "income", "expense" ]
        },
        category_id: {
          type: "string",
          description: "New category UUID (from get_categories)"
        },
        merchant_id: {
          type: "string",
          description: "New merchant UUID"
        },
        notes: {
          type: "string",
          description: "New free-text notes"
        },
        tag_ids: {
          type: "array",
          description: "Replace the transaction's tags with these tag UUIDs. Empty array clears tags.",
          items: { type: "string" }
        }
      }
    )
  end

  def call(params = {})
    transaction_id = params["transaction_id"].to_s
    return error("not_found", "Transaction with id '#{transaction_id}' not found.") unless valid_uuid?(transaction_id)

    transaction = accessible_transactions.find_by(id: transaction_id)
    return error("not_found", "Transaction with id '#{transaction_id}' not found.") unless transaction

    entry = transaction.entry

    return error("validation_failed", "Split child transactions cannot be edited directly.") if entry.split_child?

    if entry.split_parent? && (params.key?("amount") || params.key?("date") || params.key?("nature"))
      return error("validation_failed", "Split parent amount, date, and type cannot be changed directly.")
    end

    entryable_attributes = { id: entry.entryable_id }
    entryable_attributes[:category_id] = params["category_id"] if params.key?("category_id")
    entryable_attributes[:merchant_id] = params["merchant_id"] if params.key?("merchant_id")

    entry_attrs = { entryable_attributes: entryable_attributes }
    entry_attrs[:name] = params["name"] if params.key?("name")
    entry_attrs[:date] = params["date"] if params.key?("date")
    entry_attrs[:notes] = params["notes"] if params.key?("notes")
    entry_attrs[:amount] = signed_amount(params["amount"], params["nature"]) if params["amount"].present?

    updated = false
    Entry.transaction do
      if entry.update(entry_attrs)
        if params.key?("tag_ids")
          transaction.tag_ids = params["tag_ids"] || []
          transaction.save!
          transaction.lock_attr!(:tag_ids) if transaction.tags.any?
        end
        entry.sync_account_later
        entry.lock_saved_attributes!
        updated = true
      else
        raise ActiveRecord::Rollback
      end
    end

    return error("validation_failed", entry.errors.full_messages.join("; ")) unless updated

    { success: true, transaction: serialize(entry.reload.transaction), message: "Transaction '#{entry.name}' updated." }
  rescue => e
    error("unexpected_error", e.message)
  end

  private
    def accessible_transactions
      family.transactions
        .joins(entry: :account)
        .merge(Account.accessible_by(user))
    end

    def signed_amount(amount, nature)
      amount = amount.to_f
      case nature.to_s.downcase
      when "income", "inflow" then -amount.abs
      when "expense", "outflow" then amount.abs
      else amount
      end
    end

    def serialize(txn)
      entry = txn.entry
      {
        id: txn.id,
        name: entry.name,
        date: entry.date,
        amount: entry.amount.abs,
        currency: entry.currency,
        formatted_amount: entry.amount_money.abs.format,
        classification: entry.amount.negative? ? "income" : "expense",
        account: entry.account.name,
        account_id: entry.account_id,
        category: txn.category&.name,
        category_id: txn.category_id,
        merchant: txn.merchant&.name,
        notes: entry.notes,
        tags: txn.tags.map(&:name)
      }
    end

    def error(key, message)
      { success: false, error: key, message: message }
    end
end
