class Assistant::Function::GetMerchants < Assistant::Function
  class << self
    def name
      "get_merchants"
    end

    def description
      <<~INSTRUCTIONS
        Returns all merchants defined for the user's family, sorted alphabetically.

        Use this when the user wants to see available merchants or before referencing
        a merchant_id in create_transaction or update_transaction.
      INSTRUCTIONS
    end
  end

  def call(params = {})
    merchants = family.merchants.alphabetically

    {
      merchants: merchants.map { |m| { id: m.id, name: m.name } },
      total: merchants.size
    }
  end
end
