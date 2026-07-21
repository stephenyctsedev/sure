require "test_helper"

class Assistant::Function::GetAccountTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetAccount.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "get_account", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "account_id"
  end

  test "returns the account by id" do
    account = accounts(:depository)
    result = @fn.call("account_id" => account.id)

    assert result[:success]
    assert_equal account.id, result[:account][:id]
    assert_equal account.name, result[:account][:name]
    assert_equal "depository", result[:account][:account_type]
  end

  test "soft error when account id is not a valid uuid" do
    result = @fn.call("account_id" => "not-a-uuid")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "soft error when account does not exist" do
    result = @fn.call("account_id" => SecureRandom.uuid)

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "does not return accounts from another family" do
    other_account = accounts(:depository)
    other_account.update_column(:family_id, families(:empty).id)

    result = @fn.call("account_id" => other_account.id)

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end
end
