require "test_helper"

class Assistant::Function::GetTransactionsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetTransactions.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "get_transactions", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "order"
    assert_includes definition[:params_schema][:required], "page"
  end

  test "each transaction includes an id that resolves via get_transaction" do
    result = @fn.call("order" => "desc", "page" => 1)

    assert_operator result[:transactions].size, :>, 0

    result[:transactions].each do |txn|
      assert txn[:id].present?
    end

    txn_id = result[:transactions].first[:id]
    get_transaction = Assistant::Function::GetTransaction.new(@user)
    lookup = get_transaction.call("transaction_id" => txn_id)

    assert lookup[:success]
    assert_equal txn_id, lookup[:transaction][:id]
  end
end
