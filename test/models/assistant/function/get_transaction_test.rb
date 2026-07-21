require "test_helper"

class Assistant::Function::GetTransactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetTransaction.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "get_transaction", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "transaction_id"
  end

  test "returns the transaction by id" do
    txn = transactions(:one)
    result = @fn.call("transaction_id" => txn.id)

    assert result[:success]
    assert_equal txn.id, result[:transaction][:id]
    assert_equal txn.entry.name, result[:transaction][:name]
    assert_equal txn.entry.account.name, result[:transaction][:account]
  end

  test "soft error when transaction id is not a valid uuid" do
    result = @fn.call("transaction_id" => "not-a-uuid")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "soft error when transaction does not exist" do
    result = @fn.call("transaction_id" => SecureRandom.uuid)

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end
end
