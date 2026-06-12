import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "api_client.dart";
import "app_state.dart";
import "models.dart";

/// Монанди `frontend/components/dashboards/sections/client-orders.tsx`.
class ClientOrdersBody extends StatefulWidget {
  const ClientOrdersBody({
    super.key,
    required this.api,
    this.bottomPadding = 0,
    this.onGoShopping,
    this.onOpenProduct,
  });

  final ApiClient api;
  final double bottomPadding;
  final VoidCallback? onGoShopping;
  final void Function(String slug)? onOpenProduct;

  @override
  State<ClientOrdersBody> createState() => _ClientOrdersBodyState();
}

class _ClientOrdersBodyState extends State<ClientOrdersBody> {
  static const _brand = Color(0xFF2563EB);

  List<OrderModel> _orders = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AppState>().accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Войдите в аккаунт";
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.orders(token);
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "$e".replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  void _openTracking(OrderModel order) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x990F172A),
      builder: (ctx) => _OrderTrackingDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;

    if (_loading && _orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _brand),
            SizedBox(height: 16),
            Text("Загрузка заказов…", style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_error != null && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
            ),
          ),
        ),
      );
    }

    if (!_loading && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text("📦", style: TextStyle(fontSize: 32))),
                  ),
                  const SizedBox(height: 24),
                  Text("У вас пока нет заказов", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
                  const SizedBox(height: 8),
                  Text(
                    "Как только вы совершите свою первую покупку, она появится здесь.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: widget.onGoShopping,
                    style: FilledButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Перейти к покупкам", style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _brand,
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (_, i) => _orderCard(
          order: _orders[i],
          isDark: isDark,
          titleColor: titleColor,
          muted: muted,
          border: border,
          cardBg: cardBg,
          onOpenProduct: widget.onOpenProduct,
          onTrack: _openTracking,
        ),
      ),
    );
  }
}

class _OrderStatusStyle {
  const _OrderStatusStyle({required this.label, required this.fg, required this.bg, required this.border});
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
}

_OrderStatusStyle _orderStatusStyle(String status, bool isDark) {
  switch (status.toLowerCase()) {
    case "new":
      return _OrderStatusStyle(
        label: "Новый",
        fg: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
        bg: isDark ? const Color(0x331D4ED8) : const Color(0xFFEFF6FF),
        border: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.35) : const Color(0xFFBFDBFE),
      );
    case "paid":
      return _OrderStatusStyle(
        label: "Оплачен",
        fg: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2),
        bg: isDark ? const Color(0x33155E75) : const Color(0xFFECFEFF),
        border: isDark ? const Color(0xFF22D3EE).withValues(alpha: 0.35) : const Color(0xFFA5F3FC),
      );
    case "shipped":
      return _OrderStatusStyle(
        label: "Отправлен",
        fg: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
        bg: isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.35) : const Color(0xFFF5F3FF),
        border: isDark ? const Color(0xFFA78BFA).withValues(alpha: 0.35) : const Color(0xFFDDD6FE),
      );
    case "in_transit":
      return _OrderStatusStyle(
        label: "В пути",
        fg: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
        bg: isDark ? const Color(0xFF422006).withValues(alpha: 0.5) : const Color(0xFFFFFBEB),
        border: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.35) : const Color(0xFFFDE68A),
      );
    case "done":
      return _OrderStatusStyle(
        label: "Доставлен",
        fg: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
        bg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
        border: isDark ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFFA7F3D0),
      );
    case "canceled":
      return _OrderStatusStyle(
        label: "Отменён",
        fg: isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
        bg: isDark ? const Color(0xFF4C0519).withValues(alpha: 0.4) : const Color(0xFFFFF1F2),
        border: isDark ? const Color(0xFFF43F5E).withValues(alpha: 0.35) : const Color(0xFFFECDD3),
      );
    default:
      return _OrderStatusStyle(
        label: status,
        fg: mutedFallback(isDark),
        bg: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
        border: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
      );
  }
}

Color mutedFallback(bool isDark) => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

String _fmtDateRu(DateTime? d) {
  if (d == null) return "";
  const months = [
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
  ];
  final m = months[d.month - 1];
  final hh = d.hour.toString().padLeft(2, "0");
  final mm = d.minute.toString().padLeft(2, "0");
  return "${d.day.toString().padLeft(2, "0")} $m ${d.year}, $hh:$mm";
}

Widget _orderCard({
  required OrderModel order,
  required bool isDark,
  required Color titleColor,
  required Color muted,
  required Color border,
  required Color cardBg,
  required void Function(String slug)? onOpenProduct,
  required void Function(OrderModel) onTrack,
}) {
  final st = _orderStatusStyle(order.status, isDark);
  final label = order.statusDisplay.trim().isNotEmpty ? order.statusDisplay : st.label;
  final total = order.itemsSubtotal;

  return DecoratedBox(
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: border),
      boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.8))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Text("Заказ #${order.id}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: titleColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: st.bg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: st.border),
                            ),
                            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: st.fg)),
                          ),
                        ],
                      ),
                      if (order.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text("от ${_fmtDateRu(order.createdAt)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "СУММА ЗАКАЗА",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: muted),
                    ),
                    Text(
                      "${total.toStringAsFixed(2)} смн",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (final item in order.items)
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.6))),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: isDark ? Colors.black : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: item.productSlug.isEmpty ? null : () => onOpenProduct?.call(item.productSlug),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item.productImage != null && item.productImage!.isNotEmpty
                              ? Image.network(item.productImage!, fit: BoxFit.contain)
                              : const Center(child: Text("🖼️", style: TextStyle(fontSize: 22))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: item.productSlug.isEmpty ? null : () => onOpenProduct?.call(item.productSlug),
                            child: Text(
                              item.productTitle,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor, height: 1.25),
                            ),
                          ),
                          if (item.variantLabel != null && item.variantLabel!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(item.variantLabel!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text("${item.unitPrice} смн", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                              Text("  |  ", style: TextStyle(color: muted.withValues(alpha: 0.5))),
                              Text("${item.qty} шт.", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC).withValues(alpha: 0.8),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "АДРЕС ДОСТАВКИ",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  order.shippingAddress.trim().isEmpty ? "Не указан" : order.shippingAddress,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor, height: 1.35),
                ),
                const SizedBox(height: 14),
                Text(
                  "КОНТАКТНЫЕ ДАННЫЕ",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  order.contactPhone.trim().isEmpty ? "—" : order.contactPhone,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor),
                ),
                if (order.canTrackCourier) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => onTrack(order),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text("Где мой заказ? (Показать на карте)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      backgroundColor: isDark ? const Color(0x331D4ED8) : const Color(0xFFEFF6FF),
                      side: BorderSide(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFBFDBFE)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _OrderTrackingDialog extends StatefulWidget {
  const _OrderTrackingDialog({required this.order});
  final OrderModel order;

  @override
  State<_OrderTrackingDialog> createState() => _OrderTrackingDialogState();
}

class _OrderTrackingDialogState extends State<_OrderTrackingDialog> {
  String _address = "Загрузка адреса...";

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final c = widget.order.courier;
    final lat = double.tryParse(c?.latitude ?? "");
    final lon = double.tryParse(c?.longitude ?? "");
    if (lat == null || lon == null) {
      setState(() => _address = "Координаты недоступны");
      return;
    }
    try {
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=ru",
      );
      final res = await http.get(uri, headers: {"User-Agent": "kharid.tj-mobile/1.0"});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final name = data["display_name"]?.toString();
        if (mounted) setState(() => _address = (name != null && name.isNotEmpty) ? name : "Адрес не определён");
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _address = "Не удалось загрузить адрес");
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final c = widget.order.courier!;
    final lat = double.parse(c.latitude!);
    final lon = double.parse(c.longitude!);
    final name = "${c.firstName} ${c.lastName}".trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF09090B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x331D4ED8) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Доставка заказа #${widget.order.id}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${name.isEmpty ? "Курьер" : name}${c.deliveryType != null && c.deliveryType!.isNotEmpty ? " · ${c.deliveryType}" : ""}",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: muted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            SizedBox(
              height: 320,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(0)),
                child: FlutterMap(
                  options: MapOptions(initialCenter: LatLng(lat, lon), initialZoom: 15),
                  children: [
                    TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lon),
                          width: 48,
                          height: 48,
                          child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB), size: 36),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ТЕКУЩЕЕ МЕСТОПОЛОЖЕНИЕ",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: muted),
                        ),
                        const SizedBox(height: 4),
                        Text(_address, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
