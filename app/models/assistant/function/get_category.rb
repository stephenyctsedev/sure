class Assistant::Function::GetCategory < Assistant::Function
  class << self
    def name
      "get_category"
    end

    def description
      <<~INSTRUCTIONS
        Retrieve a single category by its id, including color, icon, parent, and the
        hierarchical name (e.g. "Food & Drink > Restaurants").

        Use get_categories to list every category and find ids.
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [ "category_id" ],
      properties: {
        category_id: {
          type: "string",
          description: "UUID of the category to retrieve (from get_categories)"
        }
      }
    )
  end

  def call(params = {})
    category_id = params["category_id"].to_s
    return error("not_found", "Category with id '#{category_id}' not found.") unless valid_uuid?(category_id)

    category = family.categories.find_by(id: category_id)
    return error("not_found", "Category with id '#{category_id}' not found.") unless category

    { success: true, category: serialize(category) }
  end

  private
    def serialize(c)
      {
        id: c.id,
        name: c.name,
        name_with_parent: c.name_with_parent,
        color: c.color,
        icon: c.lucide_icon,
        parent_id: c.parent_id,
        is_subcategory: c.subcategory?
      }
    end

    def error(key, message)
      { success: false, error: key, message: message }
    end
end
