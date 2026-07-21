require "test_helper"

class Assistant::Function::UpdateTransactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::UpdateTransaction.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "update_transaction", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "transaction_id"
  end

  test "updates the transaction name" do
    txn = transactions(:one)
    result = @fn.call("transaction_id" => txn.id, "name" => "Renamed Coffee")

    assert result[:success]
    assert_equal "Renamed Coffee", result[:transaction][:name]
    assert_equal "Renamed Coffee", txn.entry.reload.name
  end

  test "updates the transaction amount" do
    txn = transactions(:one)
    result = @fn.call("transaction_id" => txn.id, "amount" => 50, "nature" => "expense")

    assert result[:success]
    assert_equal 50.to_d, txn.entry.reload.amount
  end

  test "soft error when transaction id is not a valid uuid" do
    result = @fn.call("transaction_id" => "not-a-uuid", "name" => "X")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "soft error when transaction does not exist" do
    result = @fn.call("transaction_id" => SecureRandom.uuid, "name" => "X")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end
end
