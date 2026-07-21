require "test_helper"

class Assistant::Function::GetMerchantsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetMerchants.new(@user)
  end

  test "to_definition returns correct name and description" do
    definition = @fn.to_definition
    assert_equal "get_merchants", definition[:name]
    assert_not_empty definition[:description]
    assert_equal "object", definition[:params_schema][:type]
  end

  test "returns all family merchants sorted alphabetically" do
    result = @fn.call

    assert_kind_of Array, result[:merchants]
    assert_equal @family.merchants.count, result[:total]

    names = result[:merchants].map { |m| m[:name] }
    assert_equal names.sort, names
  end

  test "each merchant includes id and name" do
    result = @fn.call
    result[:merchants].each do |m|
      assert m[:id].present?
      assert m[:name].present?
    end
  end

  test "scopes to the user's family" do
    other_family = Family.create!(name: "Other", currency: "USD", locale: "en", country: "US", timezone: "UTC")
    other_family.merchants.create!(name: "Foreign Merchant", type: "FamilyMerchant")

    result = @fn.call
    merchant_names = result[:merchants].map { |m| m[:name] }
    assert_not_includes merchant_names, "Foreign Merchant"
  end
end
