import "dart:convert";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";

import "models.dart";

String? _parseCfStreamUploadUid(dynamic body) {
  if (body is! Map) return null;
  final m = Map<String, dynamic>.from(body);
  for (final key in ["uid", "id"]) {
    final v = m[key]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  final r = m["result"];
  if (r is Map) {
    final rm = Map<String, dynamic>.from(r);
    for (final key in ["uid", "id"]) {
      final v = rm[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
  }
  return null;
}

/// Сервери API баргашт дод 401 — лозим аст access-ро аз нав кунед.
class ApiUnauthorized implements Exception {
  const ApiUnauthorized();
}

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith("/") ? path : "/$path";
    return Uri.parse("$baseUrl$normalized").replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final res = await http.post(
      _uri("/auth/phone/request/"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"phone": phone}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final res = await http.post(
      _uri("/auth/phone/verify/"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"phone": phone, "code": code}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> register({
    required String registrationToken,
    required String role,
    String city = "",
    String? referralCode,
    String? storeName,
    String? storeCity,
    String? storeAddress,
    String? deliveryType,
  }) async {
    final payload = <String, dynamic>{
      "registration_token": registrationToken,
      "role": role,
    };
    final c = city.trim();
    if (c.isNotEmpty) payload["city"] = c;
    final ref = referralCode?.trim();
    if (ref != null && ref.isNotEmpty) payload["referral_code"] = ref;
    final sn = storeName?.trim();
    if (sn != null && sn.isNotEmpty) payload["store_name"] = sn;
    final sc = storeCity?.trim();
    if (sc != null && sc.isNotEmpty) payload["store_city"] = sc;
    final sa = storeAddress?.trim();
    if (sa != null && sa.isNotEmpty) payload["store_address"] = sa;
    final dt = deliveryType?.trim();
    if (dt != null && dt.isNotEmpty) payload["delivery_type"] = dt;
    final res = await http.post(
      _uri("/auth/phone/register/"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode(payload),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final res = await http.post(
      _uri("/auth/token/refresh/"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"refresh": refreshToken}),
    );
    return _decode(res);
  }

  Future<MeProfile> me(String accessToken) async {
    final res = await http.get(_uri("/me/"), headers: _auth(accessToken));
    final data = _decode(res);
    return MeProfile.fromJson(data);
  }

  Future<void> deleteAccount(String accessToken) async {
    final res = await http.delete(_uri("/me/"), headers: _auth(accessToken));
    _decode(res);
  }

  Future<List<ProductListItem>> fetchWishlist(String accessToken) async {
    final res = await http.get(_uri("/wishlist/"), headers: _auth(accessToken));
    final data = _decode(res);
    return _extractResults(data).map(ProductListItem.fromJson).toList();
  }

  Future<List<ProductListItem>> mergeWishlist(String accessToken, List<int> productIds) async {
    final res = await http.put(
      _uri("/wishlist/"),
      headers: {..._auth(accessToken), "Content-Type": "application/json"},
      body: jsonEncode({"product_ids": productIds}),
    );
    final data = _decode(res);
    return _extractResults(data).map(ProductListItem.fromJson).toList();
  }

  Future<({String status, List<ProductListItem> items})> toggleWishlist(
    String accessToken,
    int productId,
  ) async {
    final res = await http.post(
      _uri("/wishlist/"),
      headers: {..._auth(accessToken), "Content-Type": "application/json"},
      body: jsonEncode({"product_id": productId}),
    );
    final data = _decode(res);
    final status = (data["status"] ?? "").toString();
    final raw = data["items"];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(ProductListItem.fromJson).toList()
        : <ProductListItem>[];
    return (status: status, items: items);
  }

  Future<List<City>> cities() async {
    final res = await http.get(_uri("/cities/"), headers: {"Accept": "application/json"});
    final data = _decode(res);
    final list = _extractResults(data);
    return list.map(City.fromJson).toList();
  }

  /// Ҳамаи категорияҳо (ҳамаи саҳифаҳои пагинатсияи DRF).
  Future<List<CategoryLite>> categories() async {
    final out = <CategoryLite>[];
    Uri? nextUri = _uri("/categories/");
    while (nextUri != null) {
      final res = await http.get(nextUri, headers: {"Accept": "application/json"});
      final data = _decode(res);
      out.addAll(_extractResults(data).map(CategoryLite.fromJson));
      final next = data["next"]?.toString();
      nextUri = (next != null && next.isNotEmpty) ? Uri.parse(next) : null;
    }
    return out;
  }

  static const List<String> _variantOptionPaths = [
    "/product-options/",
    "/variant-options/",
    "/variant-attributes/",
    "/attributes/",
    "/options/",
  ];

  static const List<String> _variantValuePaths = [
    "/product-option-values/",
    "/variant-option-values/",
    "/option-values/",
    "/attribute-values/",
    "/variant-values/",
  ];

  int? _readDynInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? "");

  Map<String, dynamic>? _asMap(dynamic v) => v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : null);

  /// Ҳамон маълумоти Combobox-ҳо барои форми «вариантный товар» (веб монанд).
  Future<VariantCatalogMeta> fetchVariantCatalogMeta({String? accessToken}) async {
    final headers = <String, String>{"Accept": "application/json"};
    final tok = accessToken?.trim() ?? "";
    if (tok.isNotEmpty) headers["Authorization"] = "Bearer $tok";

    Future<List<Map<String, dynamic>>> firstList(List<String> paths) async {
      for (final p in paths) {
        try {
          final res = await http.get(_uri(p), headers: headers);
          if (res.statusCode < 200 || res.statusCode >= 300) continue;
          final data = jsonDecode(res.body);
          List<Map<String, dynamic>> rows;
          if (data is List) {
            rows = data.whereType<Map<String, dynamic>>().map((x) => Map<String, dynamic>.from(x)).toList();
          } else if (data is Map<String, dynamic>) {
            final raw = data["results"];
            if (raw is List) {
              rows = raw.map((x) => _asMap(x)).whereType<Map<String, dynamic>>().toList();
            } else {
              rows = const [];
            }
          } else {
            rows = const [];
          }
          if (rows.isNotEmpty) return rows;
        } catch (_) {
          continue;
        }
      }
      return const [];
    }

    final optsRaw = await firstList(_variantOptionPaths);
    final valsRaw = await firstList(_variantValuePaths);

    final options = <VariantOptionMeta>[];
    final seenSlugs = <String>{};
    for (final r in optsRaw) {
      final slug = "${r["slug"] ?? r["code"] ?? r["key"] ?? ""}".trim();
      final name = "${r["name"] ?? r["title"] ?? slug}".trim();
      if (slug.isEmpty) continue;
      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);
      options.add(
        VariantOptionMeta(
          id: _readDynInt(r["id"]),
          slug: slug,
          name: name.isEmpty ? slug : name,
          kind: (() {
            final k =
                "${r["kind"] ?? r["type"] ?? r["data_type"] ?? ""}".trim();
            return k.isEmpty ? null : k;
          })(),
        ),
      );
    }

    final bySlug = <String, List<VariantValueMeta>>{};
    for (final raw in valsRaw) {
      var oSlug =
          "${raw["option_slug"] ?? raw["attribute_slug"] ?? ""}".trim();
      final optField =
          raw["option_id"] ?? raw["attribute_id"] ?? raw["option"] ?? raw["attribute"];
      final optRec = _asMap(optField);
      if (oSlug.isEmpty) {
        oSlug = "${optRec?["slug"] ?? ""}".trim();
      }
      if (oSlug.isEmpty && optRec != null) {
        final id = optField is num ? optField.toInt() : int.tryParse(optField?.toString() ?? "");
        if (id != null) {
          for (final o in options) {
            if (o.id == id) {
              oSlug = o.slug;
              break;
            }
          }
        }
      }
      if (oSlug.isEmpty && optField is String) {
        oSlug = optField.trim();
      }

      final value =
          "${raw["value"] ?? raw["name"] ?? raw["title"] ?? ""}".trim();
      if (oSlug.isEmpty || value.isEmpty) continue;

      final label =
          "${raw["label"] ?? raw["title"] ?? raw["name"] ?? ""}".trim();
      final hexRaw =
          "${raw["hex"] ?? raw["color"] ?? raw["code"] ?? ""}".trim();

      final v = VariantValueMeta(
        value: value,
        label: label.isEmpty ? value : label,
        hex: hexRaw.isEmpty ? null : hexRaw,
      );
      final list =
          bySlug.putIfAbsent(oSlug, () => [])..add(v);
      bySlug[oSlug] = list;
    }

    return VariantCatalogMeta(options: options, valuesBySlug: bySlug);
  }

  /// Товары с Cloudflare-видео — лента Reels (`has_video=1`).
  Future<Paginated<ProductListItem>> reelsProducts({int page = 1, int pageSize = 12}) async {
    final q = <String, String>{
      "page": "$page",
      "ordering": "-created_at",
      "has_video": "1",
      "page_size": "$pageSize",
    };
    final res = await http.get(_uri("/products/", q), headers: const {"Accept": "application/json"});
    final data = _decode(res);
    final results = _extractResults(data).map(ProductListItem.fromJson).toList();
    return Paginated(
      count: (data["count"] as num?)?.toInt() ?? results.length,
      next: data["next"]?.toString(),
      results: results,
    );
  }

  /// Следующая страница товаров по DRF `next` URL.
  Future<Paginated<ProductListItem>> productsPageFromUrl(String nextUrl) async {
    final raw = nextUrl.trim();
    if (raw.isEmpty) {
      return const Paginated(count: 0, next: null, results: []);
    }
    final uri = raw.startsWith("http") ? Uri.parse(raw) : _uri(raw);
    final res = await http.get(uri, headers: const {"Accept": "application/json"});
    final data = _decode(res);
    final results = _extractResults(data).map(ProductListItem.fromJson).toList();
    return Paginated(
      count: (data["count"] as num?)?.toInt() ?? results.length,
      next: data["next"]?.toString(),
      results: results,
    );
  }

  Future<Paginated<ProductListItem>> products({
    int page = 1,
    String ordering = "-created_at",
    String? categorySlug,
    String? categoryTreeSlug,
  }) async {
    final q = <String, String>{"page": "$page", "ordering": ordering};
    if (categoryTreeSlug != null && categoryTreeSlug.isNotEmpty) {
      q["category_tree"] = categoryTreeSlug;
    } else if (categorySlug != null && categorySlug.isNotEmpty) {
      q["category"] = categorySlug;
    }
    final res = await http.get(_uri("/products/", q), headers: const {"Accept": "application/json"});
    final data = _decode(res);
    final results = _extractResults(data).map(ProductListItem.fromJson).toList();
    return Paginated(
      count: (data["count"] as num?)?.toInt() ?? results.length,
      next: data["next"]?.toString(),
      results: results,
    );
  }

  Future<ProductDetail> productBySlug(String slug) async {
    final res = await http.get(_uri("/products/$slug/"), headers: {"Accept": "application/json"});
    return ProductDetail.fromJson(_decode(res));
  }

  /// GET `/products/{slug}/` бо token — барои фурӯшанда (масалан товарҳои ғайрифаъол).
  Future<ProductDetail> productDetailAuthenticated(String accessToken, String slug) async {
    final res = await http.get(_uri("/products/$slug/"), headers: {..._auth(accessToken), "Accept": "application/json"});
    return ProductDetail.fromJson(_decode(res));
  }

  Future<List<OrderModel>> orders(String accessToken) async {
    final res = await http.get(_uri("/orders/"), headers: _auth(accessToken));
    final data = _decode(res);
    return _extractResults(data).map(OrderModel.fromJson).toList();
  }

  Future<OrderModel> orderById(String accessToken, int orderId) async {
    final res = await http.get(_uri("/orders/$orderId/"), headers: _auth(accessToken));
    return OrderModel.fromJson(_decode(res));
  }

  Future<List<SellerOrderItemRow>> sellerOrderItems(String accessToken) async {
    final res = await http.get(_uri("/order-items/seller_list/"), headers: _auth(accessToken));
    final data = _decode(res);
    return _extractResults(data).map(SellerOrderItemRow.fromJson).toList();
  }

  Future<Map<String, dynamic>> sellerAnalytics(String accessToken) async {
    final res = await http.get(_uri("/order-items/seller_analytics/"), headers: _auth(accessToken));
    return _decode(res);
  }

  Future<({List<OrderModel> orders, bool profileIncomplete})> courierAvailable(String accessToken) async {
    final res = await http.get(_uri("/orders/available_for_courier/"), headers: _auth(accessToken));
    if (res.statusCode == 400) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body["code"]?.toString() == "PROFILE_INCOMPLETE") {
          return (orders: const <OrderModel>[], profileIncomplete: true);
        }
      } catch (_) {}
    }
    final data = _decode(res);
    return (
      orders: _extractResults(data).map(OrderModel.fromJson).toList(),
      profileIncomplete: false,
    );
  }

  Future<List<OrderModel>> courierMyDeliveries(String accessToken) async {
    final res = await http.get(_uri("/orders/my_deliveries/"), headers: _auth(accessToken));
    final data = _decode(res);
    return _extractResults(data).map(OrderModel.fromJson).toList();
  }

  Future<Map<String, dynamic>> courierRequestAssignment(String accessToken, int orderId) async {
    final res = await http.post(_uri("/orders/$orderId/request_assignment/"), headers: _auth(accessToken));
    return _decode(res);
  }

  Future<void> patchMeLocation(String accessToken, double latitude, double longitude) async {
    final res = await http.patch(
      _uri("/me/"),
      headers: {..._auth(accessToken), "Content-Type": "application/json"},
      body: jsonEncode({
        "latitude": latitude.toStringAsFixed(6),
        "longitude": longitude.toStringAsFixed(6),
      }),
    );
    _decode(res);
  }

  /// GET `/wallet/history/` — объект бо `balance`, `totals`, `items`, `referral_items`.
  Future<Map<String, dynamic>> fetchWalletHistory(String accessToken) async {
    final res = await http.get(_uri("/wallet/history/"), headers: _auth(accessToken));
    return _decode(res);
  }

  Future<Map<String, dynamic>> referralsMy(String accessToken) async {
    final res = await http.get(_uri("/referrals/my/"), headers: _auth(accessToken));
    return _decode(res);
  }

  Future<Map<String, dynamic>> topupSmartpay(String accessToken, double amount) async {
    final res = await http.post(
      _uri("/wallet/topup/"),
      headers: {..._auth(accessToken), "Content-Type": "application/json"},
      body: jsonEncode({"amount": amount.toStringAsFixed(2)}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> createOrder({
    required String accessToken,
    required String contactPhone,
    required String shippingCity,
    required String shippingAddress,
    required List<CartLine> lines,
    required String paymentMethod,
    required int prepayPercent,
    String? note,
  }) async {
    final payload = {
      "contact_phone": contactPhone,
      "shipping_city": shippingCity,
      "shipping_address": shippingAddress,
      "payment_method": paymentMethod,
      "prepay_percent": prepayPercent,
      "items": lines.map((e) {
        final row = <String, dynamic>{"product": e.product.id, "qty": e.qty};
        final vid = e.product.variantId;
        if (vid != null) row["variant"] = vid;
        return row;
      }).toList(),
    };
    final n = note?.trim();
    if (n != null && n.isNotEmpty) payload["note"] = n;
    final res = await http.post(
      _uri("/orders/"),
      headers: {..._auth(accessToken), "Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    return _decode(res);
  }

  /// GET `/products/my/?search=&status=all|active|inactive&type=all|simple|variant`
  Future<List<ProductListItem>> myProducts(
    String accessToken, {
    String? search,
    String status = "all",
    String type = "all",
  }) async {
    final q = <String, String>{
      "status": status,
      "type": type,
    };
    final s = search?.trim();
    if (s != null && s.isNotEmpty) q["search"] = s;
    final res = await http.get(_uri("/products/my/", q), headers: _auth(accessToken));
    final data = _decode(res);
    return _extractResults(data).map(ProductListItem.fromJson).toList();
  }

  Future<Map<String, dynamic>> siteSettings() async {
    final res = await http.get(_uri("/site-settings/"), headers: {"Accept": "application/json"});
    return _decode(res);
  }

  Future<List<HomeBannerItem>> homeBanners() async {
    try {
      final res = await http
          .get(_uri("/home-banners/"), headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final raw = data is Map ? (data["results"] ?? data) : data;
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().map(HomeBannerItem.fromJson).toList();
      }
    } catch (_) {
      // fallback handled in UI
    }
    return const [];
  }

  Future<Map<String, dynamic>> updateMeMultipart({
    required String accessToken,
    required Map<String, String> fields,
    XFile? avatar,
    XFile? storeLogo,
  }) async {
    final req = http.MultipartRequest("PATCH", _uri("/me/"));
    req.headers.addAll(_auth(accessToken));
    req.fields.addAll(fields);
    if (avatar != null) {
      req.files.add(await http.MultipartFile.fromPath("avatar", avatar.path));
    }
    if (storeLogo != null) {
      req.files.add(await http.MultipartFile.fromPath("store_logo", storeLogo.path));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  /// GET `/seller-applications/my/` — JSON заявка ё `null`.
  Future<Map<String, dynamic>?> sellerApplicationMy(String accessToken) async {
    final res = await http.get(_uri("/seller-applications/my/"), headers: _auth(accessToken));
    if (res.statusCode == 401) throw const ApiUnauthorized();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}");
    }
    if (res.body.isEmpty) return null;
    final decoded = jsonDecode(res.body);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<Map<String, dynamic>> sellerApplicationSubmit({
    required String accessToken,
    required String storeName,
    required String storeCity,
    required String storeAddress,
    XFile? storeLogo,
  }) async {
    final req = http.MultipartRequest("POST", _uri("/seller-applications/my/"));
    req.headers.addAll(_auth(accessToken));
    req.fields["store_name"] = storeName.trim();
    req.fields["store_city"] = storeCity.trim();
    req.fields["store_address"] = storeAddress.trim();
    if (storeLogo != null) {
      req.files.add(await http.MultipartFile.fromPath("store_logo", storeLogo.path));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401) throw const ApiUnauthorized();
    final dynamic body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = body is Map ? body["error"]?.toString() : null;
      throw Exception(err ?? "HTTP ${res.statusCode}");
    }
    if (body is! Map<String, dynamic>) {
      throw Exception("Invalid response");
    }
    return body;
  }

  Future<Map<String, dynamic>> createProductMultipart({
    required String accessToken,
    required Map<String, String> fields,
    List<XFile> images = const [],
    List<XFile> variantImages = const [],
  }) async {
    final req = http.MultipartRequest("POST", _uri("/products/"));
    req.headers.addAll(_auth(accessToken));
    req.fields.addAll(fields);
    for (final img in images) {
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes("images", bytes, filename: img.name));
      } else {
        req.files.add(await http.MultipartFile.fromPath("images", img.path));
      }
    }
    for (final img in variantImages) {
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes("variant_images", bytes, filename: img.name));
      } else {
        req.files.add(await http.MultipartFile.fromPath("variant_images", img.path));
      }
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  /// PATCH `/products/{slug}/` — тағйири товар (монанди POST, вариантҳо бо `id` дар JSON).
  Future<Map<String, dynamic>> updateProductMultipart({
    required String accessToken,
    required String slug,
    required Map<String, String> fields,
    List<XFile> images = const [],
    List<XFile> variantImages = const [],
  }) async {
    final enc = Uri.encodeComponent(slug);
    final req = http.MultipartRequest("PATCH", _uri("/products/$enc/"));
    req.headers.addAll(_auth(accessToken));
    req.fields.addAll(fields);
    for (final img in images) {
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes("images", bytes, filename: img.name));
      } else {
        req.files.add(await http.MultipartFile.fromPath("images", img.path));
      }
    }
    for (final img in variantImages) {
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes("variant_images", bytes, filename: img.name));
      } else {
        req.files.add(await http.MultipartFile.fromPath("variant_images", img.path));
      }
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  /// POST `/media/cloudflare/direct-upload/` — барои бор кардани видео ба Cloudflare.
  Future<Map<String, dynamic>> cloudflareDirectUpload(String accessToken, {int maxDurationSeconds = 60}) async {
    final res = await http.post(
      _uri("/media/cloudflare/direct-upload/"),
      headers: {..._auth(accessToken), "Content-Type": "application/json"},
      body: jsonEncode({"max_duration_seconds": maxDurationSeconds}),
    );
    return _decode(res);
  }

  /// POST файл ба `upload_url`. Баъзан Cloudflare ҷавоби холӣ медиҳад — [fallbackUid] аз қадами direct-upload.
  Future<String> cloudflarePostUpload(String uploadUrl, XFile file, {String? fallbackUid}) async {
    final uri = Uri.parse(uploadUrl);
    final http.MultipartFile mf;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      mf = http.MultipartFile.fromBytes("file", bytes, filename: file.name);
    } else {
      mf = await http.MultipartFile.fromPath("file", file.path, filename: file.name);
    }
    final req = http.MultipartRequest("POST", uri)..files.add(mf);
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final snippet = res.body.length > 400 ? "${res.body.substring(0, 400)}…" : res.body;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Cloudflare upload HTTP ${res.statusCode}: $snippet");
    }
    final fb = fallbackUid?.trim();
    if (res.body.trim().isEmpty) {
      if (fb != null && fb.isNotEmpty) return fb;
      throw Exception("Cloudflare: пустой ответ загрузки (HTTP ${res.statusCode}).");
    }
    dynamic raw;
    try {
      raw = jsonDecode(res.body);
    } catch (_) {
      if (fb != null && fb.isNotEmpty) return fb;
      throw Exception("Cloudflare: ответ не JSON: $snippet");
    }
    final uid = _parseCfStreamUploadUid(raw);
    if (uid != null && uid.isNotEmpty) return uid;
    if (fb != null && fb.isNotEmpty) return fb;
    throw Exception("Cloudflare: нет uid в ответе: $snippet");
  }

  Map<String, String> _auth(String token) {
    return {"Accept": "application/json", "Authorization": "Bearer $token"};
  }

  List<Map<String, dynamic>> _extractResults(Map<String, dynamic> data) {
    final raw = data["results"];
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _decode(http.Response res) {
    final bodyText = res.body;
    final trimmed = bodyText.trim();
    if (trimmed.isEmpty) {
      if (res.statusCode >= 200 && res.statusCode < 300) return {};
      throw Exception("HTTP ${res.statusCode}: пустой ответ");
    }
    final ct = (res.headers["content-type"] ?? "").toLowerCase();
    if (ct.contains("text/html") || trimmed.startsWith("<")) {
      throw Exception(
        "Сервер вернул HTML, а не JSON (HTTP ${res.statusCode}). "
        "Проверьте адрес API: он должен заканчиваться на /api/v1 и указывать на Django "
        "(например http://10.0.2.2:8003/api/v1 в Android-эмуляторе), а не на фронтенд Next.js.",
      );
    }
    late final dynamic body;
    try {
      body = jsonDecode(bodyText);
    } on FormatException catch (e) {
      final head = trimmed.length > 120 ? "${trimmed.substring(0, 120)}…" : trimmed;
      throw Exception("Ответ не JSON (HTTP ${res.statusCode}): $e. Начало ответа: $head");
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map<String, dynamic>) return body;
      if (body is List) return {"results": body};
      return {};
    }
    if (body is Map<String, dynamic>) {
      final detail = body["detail"];
      if (detail is String && detail.isNotEmpty) throw Exception(detail);
      final err = body["error"];
      if (err is String && err.isNotEmpty) throw Exception(err);
      if (err is Map && err["msg"] is String) throw Exception(err["msg"] as String);
      throw Exception(body["message"]?.toString() ?? body.toString());
    }
    throw Exception("HTTP ${res.statusCode}");
  }
}
