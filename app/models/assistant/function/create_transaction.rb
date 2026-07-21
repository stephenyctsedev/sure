class Assistant::Function::CreateTransaction < Assistant::Function
  class << self
    def name
      "create_transaction"
    end

    def description
      <<~INSTRUCTIONS
        Creates a new transaction in one of the user's accounts.

        By default a positive amount is treated as an expense (money out) and a negative
        amount as income (money in). To be explicit, set nature to "income" or "expense"
        and provide amount as a positive number — the sign will be applied automatically.

        Use get_accounts to find account_id, get_categories for category_id,
        get_merchants for merchant_id, and get_tags for tag_ids. date must be YYYY-MM-DD.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "account_id", "amount", "name", "date" ],
      properties: {
        account_id: {
          type: "string",
          description: "UUID of the account to add the transaction to (from get_accounts)"
        },
        amount: {
          type: "number",
          description: "Transaction amount. Positive = expense, negative = income, unless nature is set."
        },
        name: {
          type: "string",
          description: "Transaction name / payee"
        },
        date: {
          type: "string",
          description: "Transaction date in YYYY-MM-DD format"
        },
        nature: {
          type: "string",
          description: "Optional. 'income' or 'expense' to set the amount sign explicitly.",
          enum: [ "income", "expense" ]
        },
        currency: {
          type: "string",
          description: "ISO 4217 currency code. Defaults to the account/family currency."
        },
        category_id: {
          type: "string",
          description: "Optional category UUID (from get_categories)"
        },
        merchant_id: {
          type: "string",
          description: "Optional merchant UUID (from get_merchants)"
        },
        notes: {
          type: "string",
          description: "Optional free-text notes"
        },
        tag_ids: {
          type: "array",
          description: "Optional list of tag UUIDs (from get_tags)",
          items: { type: "string" }
        }
      }
    )
  end

  def call(params = {})
    account_id = params["account_id"].to_s
    return error("account_required", "Please provide an account_id for the transaction.") if account_id.blank?
    return error("account_not_found", "Account with id '#{account_id}' not found.") unless valid_uuid?(account_id)

    account = family.accounts.writable_by(user).find_by(id: account_id)
    return error("account_not_found", "Account with id '#{account_id}' not found.") unless account

    entry = account.entries.new(
      name: params["name"],
      date: params["date"],
      amount: signed_amount(params["amount"], params["nature"]),
      currency: params["currency"].presence || account.currency,
      notes: params["notes"],
      entryable_type: "Transaction",
      entryable_attributes: {
        category_id: params["category_id"],
        merchant_id: params["merchant_id"],
        tag_ids: params["tag_ids"] || []
      }
    )

    if entry.save
      entry.sync_account_later
      entry.lock_saved_attributes!
      entry.transaction.lock_attr!(:tag_ids) if entry.transaction.tags.any?

      { success: true, transaction: serialize(entry.transaction), message: "Transaction '#{entry.name}' created." }
    else
      error("validation_failed", entry.errors.full_messages.join("; "))
    end
  rescue => e
    error("unexpected_error", e.message)
  end

  private
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
