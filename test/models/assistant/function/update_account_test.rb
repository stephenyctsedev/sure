require "test_helper"

class Assistant::Function::UpdateAccountTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::UpdateAccount.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "update_account", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "account_id"
  end

  test "updates the account name" do
    account = accounts(:depository)
    result = @fn.call("account_id" => account.id, "name" => "Renamed Checking")

    assert result[:success]
    assert_equal "Renamed Checking", result[:account][:name]
    assert_equal "Renamed Checking", account.reload.name
  end

  test "updates the account balance" do
    account = accounts(:depository)
    result = @fn.call("account_id" => account.id, "balance" => 9999)

    assert result[:success]
    assert_equal 9999.to_d, account.reload.balance
  end

  test "soft error when account id is not a valid uuid" do
    result = @fn.call("account_id" => "not-a-uuid", "name" => "X")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "soft error when account does not exist" do
    result = @fn.call("account_id" => SecureRandom.uuid, "name" => "X")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end
end
