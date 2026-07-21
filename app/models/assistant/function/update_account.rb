class Assistant::Function::UpdateAccount < Assistant::Function
  class << self
    def name
      "update_account"
    end

    def description
      <<~INSTRUCTIONS
        Updates an existing account's name, balance, institution name, or notes.

        Only include the fields you want to change — omitted fields are left as-is.
        accountable_type cannot be changed after creation.

        Changing balance creates a balance-adjustment entry to reconcile the difference,
        so only send balance if you intend to update it. Use get_accounts to find account ids.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "account_id" ],
      properties: {
        account_id: {
          type: "string",
          description: "UUID of the account to update (from get_accounts)"
        },
        name: {
          type: "string",
          description: "New account name"
        },
        balance: {
          type: "number",
          description: "New current balance (creates a balance adjustment entry)"
        },
        institution_name: {
          type: "string",
          description: "Bank or institution name"
        },
        notes: {
          type: "string",
          description: "Free-text notes"
        }
      }
    )
  end

  def call(params = {})
    account_id = params["account_id"].to_s
    return error("not_found", "Account with id '#{account_id}' not found.") unless valid_uuid?(account_id)

    account = user.accessible_accounts.find_by(id: account_id)
    return error("not_found", "Account with id '#{account_id}' not found.") unless account

    if params["balance"].present?
      new_balance = params["balance"].to_d
      if new_balance != account.balance
        result = account.set_current_balance(new_balance)
        return error("validation_failed", result.error) unless result.success?
      end
    end

    attrs = {}
    attrs[:name] = params["name"] if params.key?("name")
    attrs[:institution_name] = params["institution_name"] if params.key?("institution_name")
    attrs[:notes] = params["notes"] if params.key?("notes")

    if attrs.any? && !account.update(attrs)
      return error("validation_failed", account.errors.full_messages.join("; "))
    end

    account.lock_saved_attributes!
    account.reload

    { success: true, account: serialize(account), message: "Account '#{account.name}' updated." }
  rescue => e
    error("unexpected_error", e.message)
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
        status: account.status,
        institution_name: account.institution_name
      }
    end

    def error(key, message)
      { success: false, error: key, message: message }
    end
end
