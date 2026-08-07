require "test_helper"

class Assistant::Function::GetTransactionsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @transaction = transactions(:one)
    @function = Assistant::Function::GetTransactions.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @function.to_definition
    assert_equal "get_transactions", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "order"
    assert_includes definition[:params_schema][:required], "page"
  end

  test "each transaction includes an id that resolves via get_transaction" do
    result = @function.call("order" => "desc", "page" => 1)

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

  test "returns transaction ids and notes" do
    @transaction.entry.update!(notes: "Visible note")

    result = @function.call(
      "page" => 1,
      "order" => "asc",
      "search" => @transaction.entry.name
    )

    transaction = result[:transactions].find { |item| item[:id] == @transaction.id }

    assert_not_nil transaction
    assert_equal @transaction.entry.notes, transaction[:notes]
  end

  test "excludes transactions from inaccessible accounts" do
    hidden_entry = Entry.create!(
      account: accounts(:investment),
      name: "Private investment transaction",
      date: Date.current,
      amount: 100,
      currency: "USD",
      entryable: Transaction.new
    )
    hidden_entry.update!(notes: "Private note")

    result = Assistant::Function::GetTransactions.new(users(:family_member)).call(
      "page" => 1,
      "order" => "asc",
      "search" => hidden_entry.name
    )

    assert_empty result[:transactions]
  end
end
