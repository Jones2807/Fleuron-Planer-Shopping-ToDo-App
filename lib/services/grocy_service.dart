import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/grocy_models.dart';

/// Talks to the Grocy REST API: handles everything related to the
/// shopping list and products.
class GrocyService {
  final String baseUrl;
  final String apiKey;

  GrocyService({required this.baseUrl, required this.apiKey});

  /// Helper for standardized GET requests against the Grocy API, with
  /// a 3-second timeout so a spotty in-store connection fails fast
  /// instead of hanging the UI.
  Future<http.Response> _get(String endpoint) async {
    return await http.get(Uri.parse('$baseUrl$endpoint'), headers: {
      'GROCY-API-KEY': apiKey,
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 3));
  }

  /// Loads the current shopping list plus all products and product
  /// groups from the server, and merges them into a list grouped by
  /// category.
  ///
  /// Returns `null` on any failure (offline, timeout, server error) -
  /// distinct from a genuinely empty list (`{}`). Callers need this
  /// distinction to tell "couldn't reach the server, keep showing
  /// what we have" apart from "the list is really empty now, show
  /// that". Returning `{}` for both used to make every connection
  /// hiccup look identical to an intentionally emptied list.
  Future<Map<String, List<GrocyItem>>?> fetchGroupedShoppingList() async {
    try {
      final responses = await Future.wait([
        _get('/objects/shopping_list'),
        _get('/objects/products'),
        _get('/objects/product_groups'),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load Grocy data');
      }

      final List<dynamic> listJson = jsonDecode(responses[0].body);
      final List<dynamic> prodJson = jsonDecode(responses[1].body);
      final List<dynamic> groupJson = jsonDecode(responses[2].body);

      final Map<String, dynamic> products = { for (var p in prodJson) p['id'].toString(): p };
      final Map<String, String> groups = { for (var g in groupJson) g['id'].toString(): g['name'].toString() };

      Map<String, List<GrocyItem>> groupedList = {};

      for (var item in listJson) {
        final String productId = item['product_id'].toString();
        final product = products[productId];

        if (product != null) {
          final String categoryName = groups[product['product_group_id']?.toString() ?? ''] ?? 'Sonstiges';
          final bool isDone = item['done']?.toString() == '1';

          final grocyItem = GrocyItem(
            id: item['id'].toString(),
            productId: productId,
            name: product['name'].toString(),
            category: categoryName,
            amount: double.tryParse(item['amount'].toString()) ?? 1.0,
            isDone: isDone,
          );

          if (!groupedList.containsKey(categoryName)) {
            groupedList[categoryName] = [];
          }
          groupedList[categoryName]!.add(grocyItem);
        }
      }
      return groupedList;
    } catch (e) {
      // Lands here immediately once the timeout above fires.
      debugPrint('Grocy API error (shopping list / offline?): $e');
      return null;
    }
  }

  /// Fetches a flat list of every product defined in Grocy.
  ///
  /// Returns `null` on failure, distinct from a genuinely empty
  /// product catalog - same reasoning as [fetchGroupedShoppingList].
  Future<List<GrocyProduct>?> fetchAllProducts() async {
    try {
      final response = await _get('/objects/products');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((p) => GrocyProduct(
            id: p['id'].toString(),
            name: p['name'].toString()
        )).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading products: $e');
      return null;
    }
  }

  /// Loads master data (groups, units, locations).
  ///
  /// Returns `null` on failure, distinct from an empty result -
  /// same reasoning as [fetchGroupedShoppingList].
  Future<Map<String, dynamic>?> fetchFormData() async {
    try {
      final responses = await Future.wait([
        _get('/objects/product_groups'),
        _get('/objects/quantity_units'),
        _get('/objects/locations'),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load master data');
      }

      return {
        'groups': (jsonDecode(responses[0].body) as List)
            .map((p) => GrocyProductGroup(id: p['id'].toString(), name: p['name'].toString())).toList(),
        'units': (jsonDecode(responses[1].body) as List)
            .map((p) => GrocyQuantityUnit(id: p['id'].toString(), name: p['name'].toString())).toList(),
        'locations': (jsonDecode(responses[2].body) as List)
            .map((p) => GrocyLocation(id: p['id'].toString(), name: p['name'].toString())).toList(),
      };
    } catch (e) {
      debugPrint('Grocy API error (form data): $e');
      return null;
    }
  }

  /// Creates a brand-new category (product group).
  Future<String?> createProductGroup(String name) async {
    final headers = {'GROCY-API-KEY': apiKey, 'Content-Type': 'application/json'};
    final body = jsonEncode({
      "name": name,
      "description": "Created via app"
    });

    try {
      final response = await http.post(Uri.parse('$baseUrl/objects/product_groups'), headers: headers, body: body)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Grocy sometimes returns created_object_id, sometimes id.
        return data['created_object_id']?.toString() ?? data['id']?.toString();
      }
      debugPrint("Error creating category: ${response.body}");
      return null;
    } catch (e) {
      debugPrint('Grocy API error (createProductGroup): $e');
      return null;
    }
  }

  /// Creates a brand-new product in the Grocy database.
  Future<String?> createProduct({
    required String name,
    required String groupId,
    required String unitId,
    required String locationId
  }) async {
    final headers = {'GROCY-API-KEY': apiKey, 'Content-Type': 'application/json'};
    final body = jsonEncode({
      "name": name,
      "product_group_id": groupId,
      "location_id": locationId,
      "qu_id_purchase": unitId,
      "qu_id_stock": unitId,
      "min_stock_amount": 0,
      "default_best_before_days": 0
    });

    try {
      final response = await http.post(Uri.parse('$baseUrl/objects/products'), headers: headers, body: body)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['created_object_id']?.toString();
      }
      debugPrint("Error creating product: ${response.body}");
      return null;
    } catch (e) {
      debugPrint('Grocy API error (createProduct): $e');
      return null;
    }
  }

  /// Updates the name of an existing category (product group).
  Future<bool> updateProductGroup(String groupId, String newName) async {
    final headers = {'GROCY-API-KEY': apiKey, 'Content-Type': 'application/json'};
    final body = jsonEncode({"name": newName});
    try {
      final response = await http.put(Uri.parse('$baseUrl/objects/product_groups/$groupId'), headers: headers, body: body).timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Grocy API error (updateProductGroup): $e');
      return false;
    }
  }

  /// Updates the name and category of an existing product.
  Future<bool> updateProduct(String productId, String newName, String newGroupId) async {
    final headers = {'GROCY-API-KEY': apiKey, 'Content-Type': 'application/json'};
    final body = jsonEncode({
      "name": newName,
      "product_group_id": newGroupId
    });

    try {
      final response = await http.put(Uri.parse('$baseUrl/objects/products/$productId'), headers: headers, body: body)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint("Error updating product: ${response.body}");
      return false;
    } catch (e) {
      debugPrint('Grocy API error (updateProduct): $e');
      return false;
    }
  }

  /// Adds an existing product to the Grocy shopping list.
  Future<void> addProductToShoppingList(String productId, {double amount = 1.0}) async {
    final headers = {'GROCY-API-KEY': apiKey, 'Content-Type': 'application/json'};
    final body = jsonEncode({
      "product_id": productId,
      "shopping_list_id": 1,
      "amount": amount
    });
    try {
      await http.post(Uri.parse('$baseUrl/objects/shopping_list'), headers: headers, body: body)
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Grocy add failed (offline): $e');
    }
  }

  /// Toggles a shopping-list item's done/open status.
  Future<void> toggleShoppingListItem(String itemId, bool isDone) async {
    final headers = {'GROCY-API-KEY': apiKey, 'Content-Type': 'application/json'};
    final body = jsonEncode({"done": isDone ? 1 : 0});
    try {
      await http.put(Uri.parse('$baseUrl/objects/shopping_list/$itemId'), headers: headers, body: body)
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Grocy toggle failed (offline): $e');
    }
  }

  /// Permanently removes an item from the shopping list.
  Future<void> removeShoppingListItem(String itemId) async {
    try {
      await http.delete(Uri.parse('$baseUrl/objects/shopping_list/$itemId'), headers: {'GROCY-API-KEY': apiKey})
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Grocy remove failed (offline): $e');
    }
  }
}