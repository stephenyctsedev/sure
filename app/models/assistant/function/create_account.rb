class Assistant::Function::CreateAccount < Assistant::Function
  class << self
    def name
      "create_account"
    end

    def description
      <<~INSTRUCTIONS
        Creates a new manual account for the user's family.

        accountable_type must be one of (PascalCase): Depository (checking/savings),
        Investment (brokerage/retirement), Crypto (crypto wallet), Property (real estate),
        Vehicle (car/boat), OtherAsset (any other asset), CreditCard (credit card),
        Loan (mortgage/personal loan), OtherLiability (any other liability).

        balance defaults to 0 and currency defaults to the family currency.
        opening_balance_date (ISO 8601) defaults to 2 years ago. This creates a manual
        account only — linked accounts are managed by their provider.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "name", "accountable_type" ],
      properties: {
        name: {
          type: "string",
          description: "Account name, e.g. 'My Savings'"
        },
        accountable_type: {
          type: "string",
          description: "Account type (PascalCase). One of: #{Accountable::TYPES.join(", ")}"
        },
        balance: {
          type: "number",
          description: "Opening balance (default 0)"
        },
        currency: {
          type: "string",
          description: "ISO 4217 currency code, e.g. 'USD'. Defaults to the family currency."
        },
        institution_name: {
          type: "string",
          description: "Bank or institution name"
        },
        notes: {
          type: "string",
          description: "Free-text notes"
        },
        opening_balance_date: {
          type: "string",
          description: "ISO 8601 date for the opening balance entry (e.g. '2024-01-01'). Defaults to 2 years ago."
        }
      }
    )
  end

  def call(params = {})
    name = params["name"].to_s.strip
    return error("name_required", "Please provide a name for the account.") if name.blank?

    accountable_type = params["accountable_type"].to_s
    unless Accountable::TYPES.include?(accountable_type)
      return error("invalid_account_type", "accountable_type must be one of: #{Accountable::TYPES.join(", ")}.")
    end

    opening_balance_date = parse_date(params["opening_balance_date"]) || 2.years.ago.to_date

    attrs = {
      name: name,
      balance: params["balance"] || 0,
      currency: params["currency"].presence || family.currency,
      accountable_type: accountable_type,
      accountable_attributes: {}
    }
    attrs[:institution_name] = params["institution_name"] if params["institution_name"].present?
    attrs[:notes] = params["notes"] if params["notes"].present?

    account = family.accounts.create_and_sync(attrs, opening_balance_date: opening_balance_date)
    account.lock_saved_attributes!

    { success: true, account: serialize(account), message: "Account '#{account.name}' created." }
  rescue ActiveRecord::RecordInvalid => e
    error("validation_failed", e.record.errors.full_messages.join("; "))
  rescue => e
    error("unexpected_error", e.message)
  end

  private
    def parse_date(str)
      return nil if str.blank?
      Date.parse(str.to_s)
    rescue ArgumentError
      nil
    end

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
