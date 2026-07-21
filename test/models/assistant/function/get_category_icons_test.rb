require "test_helper"

class Assistant::Function::GetCategoryIconsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @fn = Assistant::Function::GetCategoryIcons.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "get_category_icons", definition[:name]
    assert_not_empty definition[:description]
  end

  test "returns the icon codes and palette colors" do
    result = @fn.call

    assert_equal Category.icon_codes, result[:icons]
    assert_equal Category::COLORS, result[:colors]
    assert result[:icons].any?
  end
end
