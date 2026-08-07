require "test_helper"

class Assistant::Function::UpdateTransactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @transaction = transactions(:one)
    @function = Assistant::Function::UpdateTransaction.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @function.to_definition
    assert_equal "update_transaction", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "id"
  end

  test "updates the transaction name" do
    result = @function.call("id" => @transaction.id, "name" => "Renamed Coffee")

    assert result[:success]
    assert_equal "Renamed Coffee", result[:transaction][:name]
    assert_equal "Renamed Coffee", @transaction.entry.reload.name
  end

  test "accepts transaction_id as an alias for id" do
    result = @function.call("transaction_id" => @transaction.id, "name" => "Aliased Coffee")

    assert result[:success]
    assert_equal "Aliased Coffee", @transaction.entry.reload.name
  end

  test "updates the transaction amount" do
    result = @function.call("id" => @transaction.id, "amount" => 50, "nature" => "expense")

    assert result[:success]
    assert_equal 50.to_d, @transaction.entry.reload.amount
  end

  test "soft error when transaction id is not a valid uuid" do
    result = @function.call("id" => "not-a-uuid", "name" => "X")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "soft error when transaction does not exist" do
    result = @function.call("id" => SecureRandom.uuid, "name" => "X")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "updates category notes and tags" do
    category = categories(:subcategory)
    tag = tags(:one)

    result = @function.call(
      "id" => @transaction.id,
      "category_id" => category.id,
      "notes" => "Updated by assistant",
      "tag_ids" => [ tag.id ]
    )

    assert_equal true, result[:success]

    @transaction.reload
    assert_equal category, @transaction.category
    assert_equal "Updated by assistant", @transaction.entry.notes
    assert_equal [ tag.id ], @transaction.tag_ids
  end

  test "clears category merchant notes and tags when explicitly requested" do
    @transaction.update!(category: categories(:food_and_drink), merchant: merchants(:amazon))
    @transaction.tags = [ tags(:one) ]

    result = @function.call(
      "id" => @transaction.id,
      "category_id" => nil,
      "merchant_id" => nil,
      "notes" => nil,
      "tag_ids" => []
    )

    assert_equal true, result[:success]

    @transaction.reload
    assert_nil @transaction.category
    assert_nil @transaction.merchant
    assert_nil @transaction.entry.notes
    assert_empty @transaction.tags
    assert @transaction.locked?(:tag_ids)
  end

  test "rejects categories outside the family" do
    other_category = Category.create!(
      family: families(:empty),
      name: "Other",
      color: "#e99537",
      lucide_icon: "tag"
    )

    result = @function.call(
      "id" => @transaction.id,
      "category_id" => other_category.id
    )

    assert_equal false, result[:success]
    assert_equal "invalid_category", result[:error]
  end

  test "does not let read-only collaborators update transactions" do
    transaction = transactions(:transfer_in)
    function = Assistant::Function::UpdateTransaction.new(users(:family_member))

    result = function.call("id" => transaction.id, "notes" => "Should not be saved")

    assert_equal false, result[:success]
    assert_equal "not_authorized", result[:error]
    assert_nil transaction.reload.entry.notes
  end

  test "lets read-write collaborators update annotations but not names or amounts" do
    transaction = transactions(:transfer_in)
    transaction.entry.account.account_shares.find_by!(user: users(:family_member)).update!(permission: "read_write")
    function = Assistant::Function::UpdateTransaction.new(users(:family_member))

    annotation_result = function.call("id" => transaction.id, "notes" => "Shared note")
    rename_result = function.call("id" => transaction.id, "name" => "Renamed transaction")
    amount_result = function.call("id" => transaction.id, "amount" => 42)

    assert_equal true, annotation_result[:success]
    assert_equal "Shared note", transaction.reload.entry.notes
    assert_equal false, rename_result[:success]
    assert_equal "not_authorized", rename_result[:error]
    assert_equal false, amount_result[:success]
    assert_equal "not_authorized", amount_result[:error]
    assert_equal "Payment received from checking account", transaction.reload.entry.name
  end
end
