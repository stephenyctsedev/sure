class Assistant::Function::GetAccount < Assistant::Function
  class << self
    def name
      "get_account"
    end

    def description
      <<~INSTRUCTIONS
        Retrieve a single account by its id, including current balance, type, and status.

        Use get_accounts first to find account ids and see the full list.
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [ "account_id" ],
      properties: {
        account_id: {
          type: "string",
          description: "UUID of the account to retrieve (from get_accounts)"
        }
      }
    )
  end

  def call(params = {})
    account_id = params["account_id"].to_s
    return error("not_found", "Account with id '#{account_id}' not found.") unless valid_uuid?(account_id)

    account = user.accessible_accounts.find_by(id: account_id)
    return error("not_found", "Account with id '#{account_id}' not found.") unless account

    { success: true, account: serialize(account) }
  end

  private
    def serialize(account)
      {
        id: account.id,
        name: account.name,
        balance: account.balance_money.format,
        currency: account.currency,
        classification: account.classification,
        account_type: account.accountable_type&.underscore,
        subtype: account.subtype,
        status: account.status,
        institution_name: account.institution_name,
        is_linked: account.linked?
      }
    end

    def error(key, message)
      { success: false, error: key, message: message }
    end
end
