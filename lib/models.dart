import "package:flutter/material.dart" show Color;

import "api_config.dart";

class Paginated<T> {
  const Paginated({required this.count, required this.next, required this.results});

  final int count;
  final String? next;
  final List<T> results;
}

class City {
  const City({
    required this.id,
    required this.name,
    required this.deliveryCost,
    required this.deliveryCostInternal,
    required this.deliveryCostExternal,
  });

  final int id;
  final String name;
  final String deliveryCost;
  final String deliveryCostInternal;
  final String deliveryCostExternal;

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: (json["id"] as num).toInt(),
      name: (json["name"] ?? "").toString(),
      deliveryCost: (json["delivery_cost"] ?? "0").toString(),
      deliveryCostInternal: (json["delivery_cost_internal"] ?? "0").toString(),
      deliveryCostExternal: (json["delivery_cost_external"] ?? "0").toString(),
    );
  }
}

/// Опцияи вариант (аз API / монанди seller-add-product веб).
class VariantOptionMeta {
  const VariantOptionMeta({this.id, required this.slug, required this.name, this.kind});
  final int? id;
  final String slug;
  final String name;
  final String? kind;

}

/// Қимати опция аз API.
class VariantValueMeta {
  const VariantValueMeta({required this.value, required this.label, this.hex});
  final String value;
  final String label;
  final String? hex;
}

/// Боркунии метои вариант бо чанд URL-ро санҷиш мекунад.
class VariantCatalogMeta {
  const VariantCatalogMeta({required this.options, required this.valuesBySlug});
  final List<VariantOptionMeta> options;
  final Map<String, List<VariantValueMeta>> valuesBySlug;
}

class CategoryLite {
  const CategoryLite({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.image,
    this.productCount = 0,
  });
  final int id;
  final String name;
  final String slug;
  final int? parentId;
  final String? image;
  /// Шумораи товар (аз API: дар ин категория + зердастаҳо).
  final int productCount;

  bool get isRoot => parentId == null;

  factory CategoryLite.fromJson(Map<String, dynamic> json) {
    return CategoryLite(
      id: (json["id"] as num?)?.toInt() ?? 0,
      name: (json["name"] ?? "").toString(),
      slug: (json["slug"] ?? "").toString(),
      parentId: (json["parent_id"] as num?)?.toInt(),
      image: json["image"]?.toString(),
      productCount: (json["product_count"] as num?)?.toInt() ?? 0,
    );
  }
}

class UserBrief {
  const UserBrief({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.latitude,
    required this.longitude,
    required this.deliveryType,
    this.phone,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? latitude;
  final String? longitude;
  final String? deliveryType;
  final String? phone;

  factory UserBrief.fromJson(Map<String, dynamic> json) {
    return UserBrief(
      id: (json["id"] as num?)?.toInt() ?? 0,
      username: (json["username"] ?? "").toString(),
      firstName: (json["first_name"] ?? "").toString(),
      lastName: (json["last_name"] ?? "").toString(),
      latitude: json["latitude"]?.toString(),
      longitude: json["longitude"]?.toString(),
      deliveryType: json["delivery_type"]?.toString(),
      phone: json["phone"]?.toString(),
    );
  }
}

class MeProfile {
  const MeProfile({
    required this.id,
    required this.user,
    required this.role,
    required this.phone,
    required this.address,
    required this.city,
    required this.balance,
    this.storeName,
    this.storeCity,
    this.storeAddress,
    this.referralCode,
    this.referralShortCode,
    this.mlmMember = false,
    this.birthDate,
    this.avatar,
    this.storeLogo,
  });

  final int id;
  final UserBrief user;
  final String role;
  final String phone;
  final String address;
  final String city;
  final String balance;
  final String? storeName;
  final String? storeCity;
  final String? storeAddress;
  final String? referralCode;
  final String? referralShortCode;
  final bool mlmMember;
  final String? birthDate;
  final String? avatar;
  final String? storeLogo;

  factory MeProfile.fromJson(Map<String, dynamic> json) {
    return MeProfile(
      id: (json["id"] as num).toInt(),
      user: UserBrief.fromJson((json["user"] as Map<String, dynamic>? ?? const {})),
      role: (json["role"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
      address: (json["address"] ?? "").toString(),
      city: (json["city"] ?? "").toString(),
      balance: (json["balance"] ?? "0").toString(),
      storeName: json["store_name"]?.toString(),
      storeCity: json["store_city"]?.toString(),
      storeAddress: json["store_address"]?.toString(),
      referralCode: json["referral_code"]?.toString(),
      referralShortCode: json["referral_short_code"]?.toString(),
      mlmMember: json["mlm_member"] == true,
      birthDate: json["birth_date"]?.toString(),
      avatar: json["avatar"]?.toString(),
      storeLogo: json["store_logo"]?.toString(),
    );
  }
}

class ProductListItem {
  const ProductListItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.productType,
    required this.price,
    required this.salePrice,
    required this.primaryImage,
    this.sku = "",
    this.stockQty,
    this.stockUnit = "pcs",
    this.isActive = true,
    this.images = const [],
    this.variantId,
    this.categorySlug = "",
    this.brandSlug,
    this.cashbackPercent,
    this.createdAt = "",
    this.cloudflareVideoUid,
  });

  final int id;
  final String title;
  final String slug;
  final String productType; // "simple" | "variant"
  final String price;
  final String? salePrice;
  final String? primaryImage;
  final String? cloudflareVideoUid;
  final String sku;
  final String? stockQty;
  final String stockUnit;
  final bool isActive;
  final List<String> images;
  /// Барои сатри корзинаи вариантӣ — `POST /orders/` майдони `variant`.
  final int? variantId;
  final String categorySlug;
  final String? brandSlug;
  final String? cashbackPercent;
  final String createdAt;

  double get sellPrice => double.tryParse(salePrice ?? price) ?? 0;

  String? get displayImage {
    if (primaryImage != null && primaryImage!.isNotEmpty) return primaryImage;
    if (images.isNotEmpty) return images.first;
    return null;
  }

  factory ProductListItem.fromJson(Map<String, dynamic> json) {
    final rawImages = json["images"];
    final imgs = <String>[];
    if (rawImages is List) {
      for (final e in rawImages) {
        final s = e?.toString();
        if (s != null && s.isNotEmpty) imgs.add(s);
      }
    }
    return ProductListItem(
      id: (json["id"] as num).toInt(),
      title: (json["title"] ?? "").toString(),
      slug: (json["slug"] ?? "").toString(),
      productType: (json["product_type"] ?? "simple").toString(),
      price: (json["price"] ?? "0").toString(),
      salePrice: json["sale_price"]?.toString(),
      primaryImage: json["primary_image"]?.toString(),
      sku: (json["sku"] ?? "").toString(),
      stockQty: json["stock_qty"]?.toString(),
      stockUnit: (json["stock_unit"] ?? "pcs").toString(),
      isActive: json["is_active"] != false,
      images: imgs,
      variantId: (json["variant_id"] as num?)?.toInt() ?? (json["variant"] as num?)?.toInt(),
      categorySlug: (json["category_slug"] ?? "").toString(),
      brandSlug: json["brand_slug"]?.toString(),
      cashbackPercent: json["cashback_percent"]?.toString(),
      createdAt: (json["created_at"] ?? "").toString(),
      cloudflareVideoUid: json["cloudflare_video_uid"]?.toString(),
    );
  }

  bool get hasCloudflareVideo => (cloudflareVideoUid ?? "").trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "slug": slug,
        "product_type": productType,
        "price": price,
        "sale_price": salePrice,
        "primary_image": primaryImage,
        "sku": sku,
        "stock_qty": stockQty,
        "stock_unit": stockUnit,
        "is_active": isActive,
        "images": images,
        if (variantId != null) "variant_id": variantId,
        "category_slug": categorySlug,
        "brand_slug": brandSlug,
        "cashback_percent": cashbackPercent,
        "created_at": createdAt,
        if (cloudflareVideoUid != null) "cloudflare_video_uid": cloudflareVideoUid,
      };
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.sku,
    required this.description,
    required this.productType,
    required this.price,
    required this.salePrice,
    required this.images,
    required this.variants,
    this.cloudflareVideoUid,
    this.videoWatchUrl,
    this.categorySlug,
    this.categoryName,
    this.categoryId,
    this.stockQty,
    this.stockUnit,
    this.isActive = true,
    this.sellerId,
    this.sellerUsername,
    this.sellerStoreName,
    this.sellerStoreAddress,
    this.sellerAvatar,
  });

  final int id;
  final String slug;
  final String title;
  final String sku;
  final String description;
  final String productType;
  final String price;
  final String? salePrice;
  final List<String> images;
  final List<ProductVariantLite> variants;
  final String? cloudflareVideoUid;
  final String? videoWatchUrl;
  final String? categorySlug;
  final String? categoryName;
  final int? categoryId;
  final String? stockQty;
  final String? stockUnit;
  final bool isActive;
  final int? sellerId;
  final String? sellerUsername;
  final String? sellerStoreName;
  final String? sellerStoreAddress;
  final String? sellerAvatar;

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final rawImages = (json["images"] as List<dynamic>? ?? const []);
    final urls = <String>[];
    for (final item in rawImages) {
      if (item is Map<String, dynamic>) {
        final url = item["image"]?.toString();
        if (url != null && url.isNotEmpty) urls.add(url);
      } else if (item is String && item.isNotEmpty) {
        urls.add(item);
      }
    }
    final cat = json["category"];
    String? catSlug;
    String? catName;
    int? catId;
    if (cat is Map<String, dynamic>) {
      catSlug = cat["slug"]?.toString();
      catName = cat["name"]?.toString();
      catId = (cat["id"] as num?)?.toInt();
    }
    final seller = json["seller"];
    int? sellerId;
    String? sellerUsername;
    if (seller is Map<String, dynamic>) {
      sellerId = (seller["id"] as num?)?.toInt();
      sellerUsername = seller["username"]?.toString();
    }
    final prof = json["seller_profile"];
    String? storeName;
    String? storeAddr;
    String? avatar;
    if (prof is Map<String, dynamic>) {
      storeName = prof["store_name"]?.toString();
      storeAddr = prof["store_address"]?.toString();
      avatar = prof["avatar"]?.toString();
    }
    return ProductDetail(
      id: (json["id"] as num).toInt(),
      slug: (json["slug"] ?? "").toString(),
      title: (json["title"] ?? "").toString(),
      sku: (json["sku"] ?? "").toString(),
      description: (json["description"] ?? "").toString(),
      productType: (json["product_type"] ?? "simple").toString(),
      price: (json["price"] ?? "0").toString(),
      salePrice: json["sale_price"]?.toString(),
      images: urls,
      variants: (json["variants"] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProductVariantLite.fromJson)
          .toList(),
      cloudflareVideoUid: json["cloudflare_video_uid"]?.toString(),
      videoWatchUrl: json["video_watch_url"]?.toString(),
      categorySlug: catSlug,
      categoryName: catName,
      categoryId: catId,
      stockQty: json["stock_qty"]?.toString(),
      stockUnit: (json["stock_unit"] ?? "pcs").toString(),
      isActive: json["is_active"] != false,
      sellerId: sellerId,
      sellerUsername: sellerUsername,
      sellerStoreName: storeName,
      sellerStoreAddress: storeAddr,
      sellerAvatar: avatar,
    );
  }
}

class ProductVariantValueRow {
  const ProductVariantValueRow({required this.optionSlug, required this.optionName, required this.value});
  final String optionSlug;
  final String optionName;
  final String value;
}

class ProductVariantLite {
  const ProductVariantLite({
    required this.id,
    required this.sku,
    required this.price,
    required this.salePrice,
    required this.image,
    required this.valueLabels,
    required this.valueRows,
    this.stockQty,
    this.stockUnit = "pcs",
  });

  final int id;
  final String sku;
  final String price;
  final String? salePrice;
  final String? image;
  final List<String> valueLabels;
  final List<ProductVariantValueRow> valueRows;
  final String? stockQty;
  final String stockUnit;

  double get sellPrice => double.tryParse(salePrice ?? price) ?? 0;

  String get valueText => valueLabels.isEmpty ? "Вариант" : valueLabels.join(" / ");

  factory ProductVariantLite.fromJson(Map<String, dynamic> json) {
    final rows = <ProductVariantValueRow>[];
    for (final raw in json["values"] as List<dynamic>? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      final val = (raw["value"] ?? "").toString().trim();
      rows.add(
        ProductVariantValueRow(
          optionSlug: (raw["option_slug"] ?? "").toString().trim(),
          optionName: (raw["option_name"] ?? "").toString().trim(),
          value: val,
        ),
      );
    }
    final valueLabels = rows.map((r) => r.value).where((v) => v.isNotEmpty).toList();
    return ProductVariantLite(
      id: (json["id"] as num?)?.toInt() ?? 0,
      sku: (json["sku"] ?? "").toString(),
      price: (json["price"] ?? "0").toString(),
      salePrice: json["sale_price"]?.toString(),
      image: json["image"]?.toString(),
      valueLabels: valueLabels,
      valueRows: rows,
      stockQty: json["stock_qty"]?.toString(),
      stockUnit: (json["stock_unit"] ?? "pcs").toString(),
    );
  }
}

class CartLine {
  const CartLine({required this.product, required this.qty});

  final ProductListItem product;
  final int qty;

  Map<String, dynamic> toJson() {
    return {
      "product": {
        "id": product.id,
        "title": product.title,
        "slug": product.slug,
        "product_type": product.productType,
        "price": product.price,
        "sale_price": product.salePrice,
        "primary_image": product.primaryImage,
        if (product.variantId != null) "variant_id": product.variantId,
      },
      "qty": qty,
    };
  }

  factory CartLine.fromJson(Map<String, dynamic> json) {
    return CartLine(
      product: ProductListItem.fromJson((json["product"] as Map<String, dynamic>? ?? const {})),
      qty: (json["qty"] as num?)?.toInt() ?? 1,
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productTitle,
    required this.qty,
    required this.unitPrice,
    this.productImage,
    this.variantLabel,
    this.productSlug = "",
  });

  final int id;
  final String productTitle;
  final int qty;
  final String unitPrice;
  final String? productImage;
  final String? variantLabel;
  final String productSlug;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: (json["id"] as num).toInt(),
      productTitle: (json["product_title"] ?? "").toString(),
      qty: (json["qty"] as num?)?.toInt() ?? 0,
      unitPrice: (json["unit_price"] ?? "0").toString(),
      productImage: json["product_image"]?.toString(),
      variantLabel: json["variant_label"]?.toString(),
      productSlug: (json["product_slug"] ?? "").toString(),
    );
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.status,
    required this.statusDisplay,
    required this.shippingCity,
    required this.shippingAddress,
    required this.deliveryCost,
    required this.items,
    required this.courier,
    required this.createdAt,
    this.contactPhone = "",
    this.note = "",
    this.myRequestStatus,
  });

  final int id;
  final String status;
  final String statusDisplay;
  final String shippingCity;
  final String shippingAddress;
  final String deliveryCost;
  final List<OrderItem> items;
  final UserBrief? courier;
  final DateTime? createdAt;
  final String contactPhone;
  final String note;
  /// `pending` | `approved` | `rejected` | null — барои таби «Доступные».
  final String? myRequestStatus;

  double get itemsSubtotal {
    var sum = 0.0;
    for (final it in items) {
      final p = double.tryParse(it.unitPrice.replaceAll(",", ".")) ?? 0;
      sum += p * it.qty;
    }
    return sum;
  }

  bool get canTrackCourier {
    final s = status.toLowerCase();
    if (s != "shipped" && s != "in_transit") return false;
    final lat = double.tryParse(courier?.latitude ?? "");
    final lon = double.tryParse(courier?.longitude ?? "");
    return lat != null && lon != null;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json["items"] as List<dynamic>? ?? const []);
    final req = json["my_request_status"];
    return OrderModel(
      id: (json["id"] as num).toInt(),
      status: (json["status"] ?? "").toString(),
      statusDisplay: (json["status_display"] ?? "").toString(),
      shippingCity: (json["shipping_city"] ?? "").toString(),
      shippingAddress: (json["shipping_address"] ?? "").toString(),
      deliveryCost: (json["delivery_cost"] ?? "0").toString(),
      items: rawItems.whereType<Map<String, dynamic>>().map(OrderItem.fromJson).toList(),
      courier: json["courier"] is Map<String, dynamic> ? UserBrief.fromJson(json["courier"] as Map<String, dynamic>) : null,
      createdAt: DateTime.tryParse((json["created_at"] ?? "").toString()),
      contactPhone: (json["contact_phone"] ?? "").toString(),
      note: (json["note"] ?? "").toString(),
      myRequestStatus: req == null ? null : req.toString(),
    );
  }
}

/// Сатрҳои заказ барои фурӯшанда (`GET /order-items/seller_list/`).
class SellerOrderItemRow {
  const SellerOrderItemRow({
    required this.id,
    required this.orderId,
    required this.productTitle,
    this.variantLabel,
    required this.qty,
    required this.unitPrice,
    this.deliveredAt,
    required this.orderContactPhone,
    required this.orderShippingAddress,
    this.orderCreatedAt,
    required this.orderStatus,
    required this.orderStatusDisplay,
    required this.productSlug,
    this.orderCourier,
    this.productImage,
  });

  final int id;
  final int orderId;
  final String productTitle;
  final String? variantLabel;
  final int qty;
  final String unitPrice;
  final String? deliveredAt;
  final String orderContactPhone;
  final String orderShippingAddress;
  final DateTime? orderCreatedAt;
  final String orderStatus;
  final String orderStatusDisplay;
  final String productSlug;
  final UserBrief? orderCourier;
  final String? productImage;

  factory SellerOrderItemRow.fromJson(Map<String, dynamic> json) {
    UserBrief? courier;
    final oc = json["order_courier"];
    if (oc is Map<String, dynamic>) {
      courier = UserBrief.fromJson(oc);
    }
    return SellerOrderItemRow(
      id: (json["id"] as num).toInt(),
      orderId: (json["order"] as num).toInt(),
      productTitle: (json["product_title"] ?? "").toString(),
      variantLabel: json["variant_label"]?.toString(),
      qty: (json["qty"] as num?)?.toInt() ?? 0,
      unitPrice: (json["unit_price"] ?? "0").toString(),
      deliveredAt: json["delivered_at"]?.toString(),
      orderContactPhone: (json["order_contact_phone"] ?? "").toString(),
      orderShippingAddress: (json["order_shipping_address"] ?? "").toString(),
      orderCreatedAt: DateTime.tryParse((json["order_created_at"] ?? "").toString()),
      orderStatus: (json["order_status"] ?? "").toString(),
      orderStatusDisplay: (json["order_status_display"] ?? "").toString(),
      productSlug: (json["product_slug"] ?? "").toString(),
      orderCourier: courier,
      productImage: json["product_image"]?.toString(),
    );
  }
}

class HomeBannerItem {
  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.image,
    required this.gradient,
    required this.linkUrl,
    required this.productSlug,
  });

  final int id;
  final String title;
  final String subtitle;
  final String badgeText;
  final String? image;
  final String gradient;
  final String linkUrl;
  final String? productSlug;

  factory HomeBannerItem.fromJson(Map<String, dynamic> json) {
    return HomeBannerItem(
      id: (json["id"] as num).toInt(),
      title: (json["title"] ?? "").toString(),
      subtitle: (json["subtitle"] ?? "").toString(),
      badgeText: (json["badge_text"] ?? "Предложение дня").toString(),
      image: normalizeMediaUrl(json["image"]?.toString()),
      gradient: (json["gradient"] ?? "sky").toString(),
      linkUrl: (json["link_url"] ?? "").toString(),
      productSlug: json["product_slug"]?.toString(),
    );
  }

  static const List<HomeBannerItem> fallbackSlides = [
    HomeBannerItem(
      id: -1,
      title: "Очиститель воздуха",
      subtitle: "Комфорт и чистый воздух для дома и офиса.",
      badgeText: "Предложение дня",
      image: null,
      gradient: "sky",
      linkUrl: "",
      productSlug: null,
    ),
    HomeBannerItem(
      id: -2,
      title: "Электроника и гаджеты",
      subtitle: "Техника с доставкой по всему Таджикистану.",
      badgeText: "Предложение дня",
      image: null,
      gradient: "violet",
      linkUrl: "",
      productSlug: null,
    ),
    HomeBannerItem(
      id: -3,
      title: "Весенняя коллекция",
      subtitle: "Обновите гардероб со скидками сезона.",
      badgeText: "Предложение дня",
      image: null,
      gradient: "emerald",
      linkUrl: "",
      productSlug: null,
    ),
  ];

  static List<Color> gradientColors(String preset) {
    switch (preset) {
      case "violet":
        return const [Color(0xFF7C3AED), Color(0xFF1D4ED8), Color(0xFF0B1220)];
      case "emerald":
        return const [Color(0xFF10B981), Color(0xFF2563EB), Color(0xFF0B1220)];
      default:
        return const [Color(0xFF0EA5E9), Color(0xFF1D4ED8), Color(0xFF6D28D9)];
    }
  }
}
