// ==========================================
// DATA MODELS (GROCY)
// ==========================================

/// Represents a single item on the shopping list in Grocy.
///
/// This model holds the state and details of an item that needs to be
/// purchased or is already marked as done.
class GrocyItem {
  /// The unique identifier of the shopping list entry.
  final String id;

  /// The identifier of the associated product in the Grocy database.
  final String productId;

  /// The display name of the item.
  final String name;

  /// The category or product group to which this item belongs.
  final String category;

  /// The required amount or quantity of the item.
  final double amount;

  /// Indicates whether the item has already been purchased or completed.
  final bool isDone;

  /// Creates a new instance of [GrocyItem].
  GrocyItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.category,
    required this.amount,
    required this.isDone,
  });
}

/// Represents a general product within the Grocy database.
///
/// Products are the base entities that can be added to shopping lists
/// or inventory.
class GrocyProduct {
  /// The unique identifier of the product.
  final String id;

  /// The name of the product.
  final String name;

  /// Creates a new instance of [GrocyProduct].
  GrocyProduct({
    required this.id,
    required this.name,
  });
}

/// Represents a product group (category) in Grocy.
///
/// Used to group products together, e.g., "Dairy", "Sweets", or "Bakery".
class GrocyProductGroup {
  /// The unique identifier of the product group.
  final String id;

  /// The name of the product group.
  final String name;

  /// Creates a new instance of [GrocyProductGroup].
  GrocyProductGroup({
    required this.id,
    required this.name,
  });
}

/// Represents a quantity unit in Grocy.
///
/// Defines how a product is measured, e.g., "Piece", "Liter", or "Pack".
class GrocyQuantityUnit {
  /// The unique identifier of the quantity unit.
  final String id;

  /// The name of the quantity unit.
  final String name;

  /// Creates a new instance of [GrocyQuantityUnit].
  GrocyQuantityUnit({
    required this.id,
    required this.name,
  });
}

/// Represents a storage location in Grocy.
///
/// Defines where products are physically stored, e.g., "Fridge" or "Pantry".
class GrocyLocation {
  /// The unique identifier of the location.
  final String id;

  /// The name of the location.
  final String name;

  /// Creates a new instance of [GrocyLocation].
  GrocyLocation({
    required this.id,
    required this.name,
  });
}
