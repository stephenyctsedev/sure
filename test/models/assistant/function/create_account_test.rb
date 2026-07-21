require "test_helper"

class Assistant::Function::CreateAccountTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::CreateAccount.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "create_account", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "name"
    assert_includes definition[:params_schema][:required], "accountable_type"
  end

  test "creates a manual account" do
    result = nil
    assert_difference "@family.accounts.count", 1 do
      result = @fn.call(
        "name" => "My Savings",
        "accountable_type" => "Depository",
        "balance" => 1500,
        "currency" => "USD"
      )
    end

    assert result[:success]
    assert_equal "My Savings", result[:account][:name]
    assert_equal "depository", result[:account][:account_type]
    assert result[:account][:id].present?
  end

  test "soft error when name is blank" do
    result = @fn.call("name" => "  ", "accountable_type" => "Depository")

    assert_equal false, result[:success]
    assert_equal "name_required", result[:error]
  end

  test "soft error when accountable_type is invalid" do
    result = @fn.call("name" => "Bad Type", "accountable_type" => "Wallet")

    assert_equal false, result[:success]
    assert_equal "invalid_account_type", result[:error]
  end

  test "scopes created account to user's family" do
    @fn.call("name" => "Scoped Account", "accountable_type" => "Depository")
    account = @family.accounts.find_by(name: "Scoped Account")

    assert account.present?
    assert_equal @family.id, account.family_id
  end
end
