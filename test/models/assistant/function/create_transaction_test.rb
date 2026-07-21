require "test_helper"

class Assistant::Function::CreateTransactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @account = accounts(:depository)
    @fn = Assistant::Function::CreateTransaction.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "create_transaction", definition[:name]
    assert_not_empty definition[:description]
    %w[account_id amount name date].each do |key|
      assert_includes definition[:params_schema][:required], key
    end
  end

  test "creates an expense transaction" do
    result = nil
    assert_difference "@account.entries.count", 1 do
      result = @fn.call(
        "account_id" => @account.id,
        "amount" => 25,
        "name" => "Coffee",
        "date" => Date.current.to_s,
        "nature" => "expense"
      )
    end

    assert result[:success]
    assert_equal "Coffee", result[:transaction][:name]
    assert_equal "expense", result[:transaction][:classification]
    assert result[:transaction][:id].present?
  end

  test "nature income stores a negative amount" do
    result = @fn.call(
      "account_id" => @account.id,
      "amount" => 100,
      "name" => "Paycheck",
      "date" => Date.current.to_s,
      "nature" => "income"
    )

    assert result[:success]
    assert_equal "income", result[:transaction][:classification]
  end

  test "soft error when account_id is blank" do
    result = @fn.call("account_id" => "", "amount" => 10, "name" => "X", "date" => Date.current.to_s)

    assert_equal false, result[:success]
    assert_equal "account_required", result[:error]
  end

  test "soft error when account does not exist" do
    result = @fn.call("account_id" => SecureRandom.uuid, "amount" => 10, "name" => "X", "date" => Date.current.to_s)

    assert_equal false, result[:success]
    assert_equal "account_not_found", result[:error]
  end
end
