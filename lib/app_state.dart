import "dart:convert";

import "package:flutter/widgets.dart";
import "package:shared_preferences/shared_preferences.dart";

import "api_client.dart";
import "kharid_lists.dart";
import "models.dart";

const _kAccess = "kharid:access";
const _kRefresh = "kharid:refresh";
const _kCart = "kharid:cart";
const _kThemeDark = "kharid:theme_dark";

class AppState extends ChangeNotifier {
  AppState(this.api);

  final ApiClient api;

  String? accessToken;
  String? refreshToken;
  MeProfile? me;
  List<CartLine> cart = [];
  List<ProductListItem> compareList = [];
  List<ProductListItem> wishlistList = [];
  bool isDarkTheme = true;

  /// Аз [AppShellV2] гузошта мешавад — кушодани менюи чап (sheet), на `pop`.
  /// [BuildContext] — контексти ҷойе, ки тугмаи меню пахш шудааст (Navigator-и дохили таб).
  void Function(BuildContext)? _sideMenuOpener;

  void setSideMenuOpener(void Function(BuildContext)? fn) {
    _sideMenuOpener = fn;
  }

  /// Менюро кушоед; агар hook насб нашуда бошад (масалан дар санҷиш), `pop` мекунад.
  void openSideMenuFrom(BuildContext context) {
    final fn = _sideMenuOpener;
    if (fn != null) {
      fn(context);
    } else {
      Navigator.maybePop(context);
    }
  }

  /// [AppShellV2] насб мекунад — гузариш ба таби поён (масалан аз корзинаи холӣ ба «Главная»).
  void Function(int tabIndex)? onRequestSwitchTab;

  void requestSwitchTab(int tabIndex) => onRequestSwitchTab?.call(tabIndex);

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
  double get subtotal => cart.fold(0, (sum, e) => sum + (e.product.sellPrice * e.qty));

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_kAccess);
    refreshToken = prefs.getString(_kRefresh);
    isDarkTheme = prefs.getBool(_kThemeDark) ?? true;
    final rawCart = prefs.getString(_kCart);
    if (rawCart != null) {
      final arr = jsonDecode(rawCart) as List<dynamic>;
      cart = arr.whereType<Map<String, dynamic>>().map(CartLine.fromJson).toList();
    }
    compareList = await getCompareList();
    wishlistList = await getWishlistList();
    if (isAuthenticated) {
      await loadMe();
      await syncWishlistWithServer();
    }
    notifyListeners();
  }

  Future<void> loginByTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, access);
    await prefs.setString(_kRefresh, refresh);
    await loadMe();
    await syncWishlistWithServer();
    notifyListeners();
  }

  Future<void> loadMe() async {
    if (!isAuthenticated) return;
    try {
      me = await api.me(accessToken!);
    } catch (_) {
      me = null;
    }
    notifyListeners();
  }

  /// Барои дархостҳои API пас аз 401 — навсозии access аз refresh.
  Future<bool> tryRefreshAccessToken() async {
    final rt = refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final r = await api.refresh(rt);
      final access = r["access"]?.toString();
      if (access == null || access.isEmpty) return false;
      accessToken = access;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccess, access);
      await loadMe();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    me = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    notifyListeners();
  }

  Future<void> addToCart(ProductListItem product) async {
    final idx = cart.indexWhere(
      (e) => e.product.id == product.id && e.product.variantId == product.variantId,
    );
    if (idx == -1) {
      cart = [...cart, CartLine(product: product, qty: 1)];
    } else {
      final row = cart[idx];
      cart[idx] = CartLine(product: row.product, qty: row.qty + 1);
      cart = [...cart];
    }
    await _persistCart();
    notifyListeners();
  }

  Future<void> updateQty(int productId, int nextQty, {int? variantId}) async {
    if (nextQty <= 0) {
      cart = cart.where((e) => !(e.product.id == productId && e.product.variantId == variantId)).toList();
    } else {
      cart = cart
          .map(
            (e) => (e.product.id == productId && e.product.variantId == variantId)
                ? CartLine(product: e.product, qty: nextQty)
                : e,
          )
          .toList();
    }
    await _persistCart();
    notifyListeners();
  }

  Future<void> clearCart() async {
    cart = [];
    await _persistCart();
    notifyListeners();
  }

  Future<void> _persistCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCart, jsonEncode(cart.map((e) => e.toJson()).toList()));
  }

  Future<void> setThemeDark(bool v) async {
    if (isDarkTheme == v) return;
    isDarkTheme = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThemeDark, v);
    notifyListeners();
  }

  Future<void> reloadStoredLists() async {
    compareList = await getCompareList();
    if (isAuthenticated) {
      await syncWishlistWithServer();
    } else {
      wishlistList = await getWishlistList();
    }
    notifyListeners();
  }

  Future<void> _persistWishlistLocal(List<ProductListItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLsWishlist, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// Объединить локальное избранное с сервером (один аккаунт — сайт и приложение).
  Future<void> syncWishlistWithServer() async {
    final token = accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final local = await getWishlistList();
      final remote = await api.fetchWishlist(token);
      final ids = <int>{...local.map((e) => e.id), ...remote.map((e) => e.id)};
      final merged = ids.isEmpty ? remote : await api.mergeWishlist(token, ids.toList());
      wishlistList = merged;
      await _persistWishlistLocal(merged);
    } catch (_) {
      wishlistList = await getWishlistList();
    }
  }

  bool isProductInCompare(int id) => compareList.any((p) => p.id == id);

  bool isProductInWishlist(int id) => wishlistList.any((p) => p.id == id);

  Future<String?> toggleCompare(ProductListItem product) async {
    final r = await toggleCompareProduct(product);
    await reloadStoredLists();
    return r == "limit_reached" ? "limit" : null;
  }

  Future<void> toggleWishlist(ProductListItem product) async {
    final token = accessToken;
    if (token != null && token.isNotEmpty) {
      try {
        final r = await api.toggleWishlist(token, product.id);
        if (r.items.isNotEmpty || r.status == "removed") {
          wishlistList = r.items;
          await _persistWishlistLocal(r.items);
          notifyListeners();
          return;
        }
      } catch (_) {
        // fallback to local
      }
    }
    await toggleWishlistProduct(product);
    wishlistList = await getWishlistList();
    notifyListeners();
  }

  Future<void> removeCompare(int id) async {
    await removeFromCompare(id);
    await reloadStoredLists();
  }

  Future<void> removeWishlist(int id) async {
    await removeFromWishlist(id);
    await reloadStoredLists();
  }
}
