class Assistant::Function::GetTransaction < Assistant::Function
  class << self
    def name
      "get_transaction"
    end

    def description
      <<~INSTRUCTIONS
        Retrieve a single transaction by its id, including amount, date, account,
        category, merchant, notes, and tags.

        Use get_transactions to search for transactions and find their ids.
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [ "transaction_id" ],
      properties: {
        transaction_id: {
          type: "string",
          description: "UUID of the transaction to retrieve (from get_transactions)"
        }
      }
    )
  end

  def call(params = {})
    transaction_id = params["transaction_id"].to_s
    return error("not_found", "Transaction with id '#{transaction_id}' not found.") unless valid_uuid?(transaction_id)

    transaction = accessible_transactions.find_by(id: transaction_id)
    return error("not_found", "Transaction with id '#{transaction_id}' not found.") unless transaction

    { success: true, transaction: serialize(transaction) }
  end

  private
    def accessible_transactions
      family.transactions
        .joins(entry: :account)
        .merge(Account.accessible_by(user))
        .includes({ entry: :account }, :category, :merchant, :tags)
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
        tags: txn.tags.map(&:name),
        is_transfer: txn.transfer?
      }
    end

    def error(key, message)
      { success: false, error: key, message: message }
    end
end
