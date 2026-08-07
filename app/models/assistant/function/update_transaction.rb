class Assistant::Function::UpdateTransaction < Assistant::Function
  # Fields that change the substance of the transaction rather than annotate it.
  # Collaborators with only :read_write access may not touch these.
  SUBSTANTIVE_FIELDS = %w[name amount date nature].freeze

  class << self
    def name
      "update_transaction"
    end

    def description
      <<~INSTRUCTIONS
        Updates an existing transaction. Only include the fields you want to change —
        omitted fields are left as-is. Pass null for notes, category_id, or merchant_id
        to clear them, and pass tag_ids to replace the transaction's tags (an empty
        array clears them).

        Use get_transactions first to find the transaction id, and get_categories,
        get_tags, or get_merchants before referencing related ids.

        A positive amount is an expense and a negative amount is income; set nature to
        "income"/"expense" to apply the sign explicitly. date must be YYYY-MM-DD.

        It will not edit split child transactions directly, and the amount, date, and
        type of a split parent cannot be changed here.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "id" ],
      properties: {
        id: {
          type: "string",
          description: "Transaction ID from get_transactions"
        },
        name: {
          type: "string",
          description: "New transaction name / payee. Omit to leave unchanged."
        },
        amount: {
          type: "number",
          description: "New amount. Positive = expense, negative = income, unless nature is set. Omit to leave unchanged."
        },
        date: {
          type: "string",
          description: "New transaction date in YYYY-MM-DD format. Omit to leave unchanged."
        },
        nature: {
          type: "string",
          description: "Optional. 'income' or 'expense' to set the amount sign explicitly.",
          enum: [ "income", "expense" ]
        },
        notes: {
          type: [ "string", "null" ],
          description: "New transaction notes. Use null to clear notes. Omit to leave unchanged."
        },
        category_id: {
          type: [ "string", "null" ],
          description: "Category ID from get_categories. Use null to clear category. Omit to leave unchanged."
        },
        merchant_id: {
          type: [ "string", "null" ],
          description: "Merchant ID from get_merchants. Use null to clear merchant. Omit to leave unchanged."
        },
        tag_ids: {
          type: "array",
          items: { type: "string" },
          description: "Full list of tag IDs to set. Use an empty array to clear all tags. Omit to leave unchanged."
        }
      }
    )
  end

  def call(params = {})
    params = normalize_params(params)
    id = params["id"].to_s

    transaction = find_transaction(id)
    return error("not_found", "Transaction with id '#{id}' not found.") unless transaction

    entry = transaction.entry
    return error("split_child", "Split child transactions cannot be edited directly. Use the split editor.") if entry.split_child?

    if entry.split_parent? && SUBSTANTIVE_FIELDS.excluding("name").any? { |field| params.key?(field) }
      return error("validation_failed", "Split parent amount, date, and type cannot be changed directly.")
    end

    return error("not_authorized", "You do not have permission to update this transaction.") unless permitted_to_update?(entry.account, params)

    entry_attrs = entry_attributes(params, entry)
    return entry_attrs if error_response?(entry_attrs)

    tag_ids = nil
    if params.key?("tag_ids")
      tag_ids = Array(params["tag_ids"]).map(&:to_s).reject(&:blank?)
      return error("invalid_tags", "One or more tag_ids do not belong to the user's family.") unless valid_tag_ids?(tag_ids)
    end

    return error("no_changes", "Provide at least one field to update.") if no_changes?(entry_attrs, params)

    Entry.transaction do
      entry.update!(entry_attrs)

      if params.key?("tag_ids")
        transaction.tag_ids = tag_ids
        transaction.save!
        transaction.lock_attr!(:tag_ids)
      end

      entry.sync_account_later
      entry.lock_saved_attributes!
    end

    {
      success: true,
      transaction: serialize(transaction.reload),
      message: "Transaction '#{transaction.entry.name}' updated."
    }
  rescue ActiveRecord::RecordInvalid => e
    error("validation_failed", e.record.errors.full_messages.join("; "))
  end

  private
    # `transaction_id` is accepted as an alias for `id` so callers written against
    # the sibling get_transaction / link_transfer tools keep working.
    def normalize_params(params)
      normalized = params.to_h.transform_keys(&:to_s)
      normalized["id"] = normalized["transaction_id"] if !normalized.key?("id") && normalized.key?("transaction_id")
      normalized
    end

    def find_transaction(id)
      return nil unless valid_uuid?(id)

      family.transactions
        .joins(:entry)
        .where(entries: { account_id: user.accessible_accounts.visible.select(:id) })
        .find_by(id: id)
    end

    def permitted_to_update?(account, params)
      permission = account.permission_for(user)
      return true if permission.in?([ :owner, :full_control ])

      permission == :read_write && SUBSTANTIVE_FIELDS.none? { |field| params.key?(field) }
    end

    def entry_attributes(params, entry)
      entryable_attrs = { id: entry.entryable_id }

      if params.key?("category_id")
        category_id = optional_uuid(params["category_id"])
        return category_id if error_response?(category_id)
        return error("invalid_category", "category_id does not belong to the user's family.") if category_id && !family.categories.exists?(id: category_id)

        entryable_attrs[:category_id] = category_id
      end

      if params.key?("merchant_id")
        merchant_id = optional_uuid(params["merchant_id"])
        return merchant_id if error_response?(merchant_id)
        return error("invalid_merchant", "merchant_id is not available to the user's family.") if merchant_id && !available_merchants.exists?(id: merchant_id)

        entryable_attrs[:merchant_id] = merchant_id
      end

      attrs = {}
      attrs[:name] = params["name"].to_s.strip if params.key?("name")
      attrs[:notes] = params["notes"] if params.key?("notes")
      attrs[:date] = params["date"] if params.key?("date")
      attrs[:amount] = signed_amount(params["amount"], params["nature"]) if params["amount"].present?
      attrs[:entryable_attributes] = entryable_attrs if entryable_attrs.keys.size > 1
      attrs
    end

    def signed_amount(amount, nature)
      amount = amount.to_f
      case nature.to_s.downcase
      when "income", "inflow" then -amount.abs
      when "expense", "outflow" then amount.abs
      else amount
      end
    end

    def optional_uuid(value)
      return nil if value.nil? || value == ""
      return value.to_s if valid_uuid?(value)

      error("invalid_uuid", "Expected a valid UUID.")
    end

    def valid_tag_ids?(tag_ids)
      family.tags.where(id: tag_ids).count == tag_ids.uniq.size
    end

    def available_merchants
      family.available_merchants_for(user)
    end

    def no_changes?(entry_attrs, params)
      entry_attrs.empty? && !params.key?("tag_ids")
    end

    def serialize(transaction)
      entry = transaction.entry
      {
        id: transaction.id,
        name: entry.name,
        date: entry.date,
        amount: entry.amount.abs,
        currency: entry.currency,
        formatted_amount: entry.amount_money.abs.format,
        classification: entry.amount.negative? ? "income" : "expense",
        account: entry.account.name,
        account_id: entry.account_id,
        notes: entry.notes,
        category: transaction.category && {
          id: transaction.category.id,
          name: transaction.category.name
        },
        merchant: transaction.merchant && {
          id: transaction.merchant.id,
          name: transaction.merchant.name
        },
        tags: transaction.tags.map { |tag| { id: tag.id, name: tag.name } }
      }
    end

    def error_response?(value)
      value.is_a?(Hash) && value[:success] == false
    end

    def error(key, message)
      { success: false, error: key, message: message }
    end
end
