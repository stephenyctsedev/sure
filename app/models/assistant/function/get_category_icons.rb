class Assistant::Function::GetCategoryIcons < Assistant::Function
  class << self
    def name
      "get_category_icons"
    end

    def description
      <<~INSTRUCTIONS
        Returns the valid Lucide icon codes and palette colors that can be used when
        creating or updating a category (see create_category / update_category).

        Icons are Lucide icon names (e.g. 'shopping-cart'); colors are hex codes.
      INSTRUCTIONS
    end
  end

  def call(params = {})
    {
      icons: Category.icon_codes,
      colors: Category::COLORS
    }
  end
end
