import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

import "models.dart";

/// Монанди `frontend/lib/kharid-lists.ts`.
const kCompareMax = 4;
const kLsCompare = "kharid:compare-ids";
const kLsWishlist = "kharid:wishlist-ids";

bool _isProductListItem(Map<String, dynamic> o) {
  return o["id"] is num && o["slug"] is String && o["title"] is String;
}

List<ProductListItem> _parseProductArray(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final data = jsonDecode(raw);
    if (data is! List) return [];
    if (data.isNotEmpty && data.first is num) return [];
    final out = <ProductListItem>[];
    for (final e in data) {
      if (e is Map<String, dynamic> && _isProductListItem(e)) {
        out.add(ProductListItem.fromJson(e));
      } else if (e is Map && _isProductListItem(Map<String, dynamic>.from(e))) {
        out.add(ProductListItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<List<ProductListItem>> getCompareList() async {
  final prefs = await SharedPreferences.getInstance();
  var list = _parseProductArray(prefs.getString(kLsCompare));
  if (list.length > kCompareMax) {
    list = list.sublist(0, kCompareMax);
    await prefs.setString(kLsCompare, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
  return list;
}

Future<List<ProductListItem>> getWishlistList() async {
  final prefs = await SharedPreferences.getInstance();
  return _parseProductArray(prefs.getString(kLsWishlist));
}

Future<void> _writeCompare(List<ProductListItem> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kLsCompare, jsonEncode(list.map((e) => e.toJson()).toList()));
}

Future<void> _writeWishlist(List<ProductListItem> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kLsWishlist, jsonEncode(list.map((e) => e.toJson()).toList()));
}

/// `added` | `removed` | `limit_reached`
Future<String> toggleCompareProduct(ProductListItem product) async {
  final list = await getCompareList();
  final i = list.indexWhere((p) => p.id == product.id);
  if (i >= 0) {
    list.removeAt(i);
    await _writeCompare(list);
    return "removed";
  }
  if (list.length >= kCompareMax) return "limit_reached";
  list.add(product);
  await _writeCompare(list);
  return "added";
}

Future<String> toggleWishlistProduct(ProductListItem product) async {
  final list = await getWishlistList();
  final i = list.indexWhere((p) => p.id == product.id);
  if (i >= 0) {
    list.removeAt(i);
    await _writeWishlist(list);
    return "removed";
  }
  list.add(product);
  await _writeWishlist(list);
  return "added";
}

Future<void> removeFromCompare(int id) async {
  final list = await getCompareList();
  await _writeCompare(list.where((p) => p.id != id).toList());
}

Future<void> removeFromWishlist(int id) async {
  final list = await getWishlistList();
  await _writeWishlist(list.where((p) => p.id != id).toList());
}

Future<bool> isInCompare(int id) async {
  final list = await getCompareList();
  return list.any((p) => p.id == id);
}

Future<bool> isInWishlist(int id) async {
  final list = await getWishlistList();
  return list.any((p) => p.id == id);
}
