require "test_helper"

class Assistant::Function::LinkTransferTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::LinkTransfer.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "link_transfer", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "transaction_id"
    assert_includes definition[:params_schema][:required], "other_transaction_id"
  end

  test "links two unlinked transactions as a transfer" do
    outflow = create_transaction(date: Date.current, account: accounts(:depository), amount: 500)
    inflow = create_transaction(date: Date.current, account: accounts(:credit_card), amount: -500)

    result = nil
    assert_difference "Transfer.count", 1 do
      result = @fn.call(
        "transaction_id" => outflow.transaction.id,
        "other_transaction_id" => inflow.transaction.id
      )
    end

    assert result[:success]
    assert result[:transfer_id].present?
    assert_equal inflow.transaction.id, result[:inflow_transaction_id]
    assert_equal outflow.transaction.id, result[:outflow_transaction_id]
  end

  test "soft error when a transaction is already linked" do
    already_linked = transactions(:transfer_out)
    other = create_transaction(date: Date.current, account: accounts(:credit_card), amount: -100)

    result = nil
    assert_no_difference "Transfer.count" do
      result = @fn.call(
        "transaction_id" => already_linked.id,
        "other_transaction_id" => other.transaction.id
      )
    end

    assert_match(/already linked/, result[:error])
  end

  test "soft error when a transaction is not found" do
    outflow = create_transaction(date: Date.current, account: accounts(:depository), amount: 500)

    result = @fn.call(
      "transaction_id" => outflow.transaction.id,
      "other_transaction_id" => SecureRandom.uuid
    )

    assert_match(/not found/, result[:error])
  end
end
