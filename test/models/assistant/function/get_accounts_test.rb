require "test_helper"

class Assistant::Function::GetAccountsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetAccounts.new(@user)
  end

  test "to_definition returns correct name and description" do
    definition = @fn.to_definition
    assert_equal "get_accounts", definition[:name]
    assert_not_empty definition[:description]
  end

  test "each account includes an id that resolves via get_account" do
    result = @fn.call

    assert_operator result[:accounts].size, :>, 0

    result[:accounts].each do |account|
      assert account[:id].present?
    end

    account_id = result[:accounts].first[:id]
    get_account = Assistant::Function::GetAccount.new(@user)
    lookup = get_account.call("account_id" => account_id)

    assert lookup[:success]
    assert_equal account_id, lookup[:account][:id]
  end
end
