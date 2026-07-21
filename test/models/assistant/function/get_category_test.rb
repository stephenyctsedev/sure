require "test_helper"

class Assistant::Function::GetCategoryTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetCategory.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "get_category", definition[:name]
    assert_not_empty definition[:description]
    assert_includes definition[:params_schema][:required], "category_id"
  end

  test "returns the category by id" do
    category = categories(:food_and_drink)
    result = @fn.call("category_id" => category.id)

    assert result[:success]
    assert_equal category.id, result[:category][:id]
    assert_equal category.name, result[:category][:name]
    assert_equal false, result[:category][:is_subcategory]
  end

  test "reports subcategory status" do
    result = @fn.call("category_id" => categories(:subcategory).id)

    assert result[:success]
    assert_equal true, result[:category][:is_subcategory]
    assert result[:category][:parent_id].present?
  end

  test "soft error when category id is not a valid uuid" do
    result = @fn.call("category_id" => "not-a-uuid")

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end

  test "does not return categories from another family" do
    result = @fn.call("category_id" => categories(:one).id)

    assert_equal false, result[:success]
    assert_equal "not_found", result[:error]
  end
end
