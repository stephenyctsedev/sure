require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
  end

  test "replacing and destroying" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(categories(:income))

    assert_equal categories(:income), transactions.map { |t| t.reload.category }.uniq.first
  end

  test "replacing with nil should nullify the category" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(nil)

    assert_nil transactions.map { |t| t.reload.category }.uniq.first
  end

  test "subcategory can only be one level deep" do
    category = categories(:subcategory)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      category.subcategories.create!(name: "Invalid category", family: @family)
    end

    assert_equal "Validation failed: Parent can't have more than 2 levels of subcategories", error.message
  end

  test "all_investment_contributions_names returns all locale variants" do
    names = Category.all_investment_contributions_names

    assert_includes names, "Investment Contributions"  # English
    assert_includes names, "Contributions aux investissements"  # French
    assert_includes names, "Investeringsbijdragen"  # Dutch
    assert names.all? { |name| name.is_a?(String) }
    assert_equal names, names.uniq  # No duplicates
  end

  test "cannot destroy category with linked transactions" do
    category = categories(:food_and_drink) # has transactions(:one) linked
    assert_no_difference "Category.count" do
      category.destroy
    end
    assert_includes category.errors[:base], "Cannot delete a category that has transactions linked to it"
  end

  test "cannot destroy category whose subcategory has linked transactions" do
    fresh_parent = families(:dylan_family).categories.create!(
      name: "Fresh Parent",
      classification: "expense",
      color: "#aabbcc",
      lucide_icon: "shapes"
    )
    fresh_child = families(:dylan_family).categories.create!(
      name: "Fresh Child",
      classification: "expense",
      color: "#aabbcc",
      lucide_icon: "shapes",
      parent: fresh_parent
    )
    child_entry = accounts(:depository).entries.create!(
      name: "Child tx",
      date: Date.today,
      amount: 10,
      currency: "USD",
      entryable: Transaction.new(category: fresh_child)
    )

    assert_no_difference "Category.count" do
      fresh_parent.destroy
    end
    assert_includes fresh_parent.errors[:base], "Cannot delete a category that has transactions linked to it"
  ensure
    child_entry&.destroy
    fresh_child&.destroy
    fresh_parent&.destroy
  end
end
