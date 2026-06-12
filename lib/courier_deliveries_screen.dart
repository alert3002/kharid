import "dart:async";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:provider/provider.dart";

import "api_client.dart";
import "app_state.dart";
import "models.dart";

/// Танҳо контенти «Доставки» — shell дар [app_shell_v2.dart].
class CourierDeliveriesBody extends StatefulWidget {
  const CourierDeliveriesBody({super.key, required this.api, this.bottomPadding = 0, required this.onOpenSettings});

  final ApiClient api;
  final double bottomPadding;
  final VoidCallback onOpenSettings;

  @override
  State<CourierDeliveriesBody> createState() => _CourierDeliveriesBodyState();
}

class _CourierDeliveriesBodyState extends State<CourierDeliveriesBody> {
  static const _brand = Color(0xFF2563EB);

  _CourierTab _tab = _CourierTab.available;
  List<OrderModel> _available = const [];
  List<OrderModel> _my = const [];
  bool _loading = true;
  String? _error;
  bool _profileIncomplete = false;
  Map<int, String>? _actionMsg;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _startGpsTracking();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  void _startGpsTracking() {
    _gpsTimer?.cancel();
    Future<void> tick() async {
      final app = context.read<AppState>();
      if (!app.isAuthenticated || app.me?.role != "courier") return;
      final token = app.accessToken;
      if (token == null || token.isEmpty) return;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
        final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
        await widget.api.patchMeLocation(token, pos.latitude, pos.longitude);
      } catch (_) {}
    }

    tick();
    _gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) => tick());
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
      final av = await widget.api.courierAvailable(token);
      final my = await widget.api.courierMyDeliveries(token);
      if (!mounted) return;
      setState(() {
        _available = av.orders;
        _my = my;
        _profileIncomplete = av.profileIncomplete;
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

  Future<void> _requestOrder(int orderId) async {
    final token = context.read<AppState>().accessToken;
    if (token == null) return;
    setState(() => _actionMsg = {orderId: "…"});
    try {
      await widget.api.courierRequestAssignment(token, orderId);
      if (!mounted) return;
      setState(() => _actionMsg = {orderId: "Заявка отправлена!"});
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionMsg = {orderId: "$e".replaceFirst("Exception: ", "")});
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    if (me == null || me.role != "courier") {
      return const Center(child: Text("Доступно только курьерам"));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
    final tabBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final innerBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC);

    Widget profileIncompleteCard() {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border, style: BorderStyle.solid),
              color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x331D4ED8) : const Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, size: 40, color: _brand),
                  ),
                  const SizedBox(height: 24),
                  Text("Профиль не заполнен", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
                  const SizedBox(height: 8),
                  Text(
                    "Чтобы видеть заказы в вашем городе, укажите город, имя, фамилию и загрузите фото профиля.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text("Перейти в Танзимот", style: TextStyle(fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget tabSwitcher() {
      return DecoratedBox(
        decoration: BoxDecoration(color: tabBg, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _tabChip(
                  label: "Доступные (${_available.length})",
                  active: _tab == _CourierTab.available,
                  onTap: () => setState(() => _tab = _CourierTab.available),
                  isDark: isDark,
                  titleColor: titleColor,
                ),
              ),
              Expanded(
                child: _tabChip(
                  label: "Мои заказы (${_my.length})",
                  active: _tab == _CourierTab.my,
                  onTap: () => setState(() => _tab = _CourierTab.my),
                  isDark: isDark,
                  titleColor: titleColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = _tab == _CourierTab.available ? _available : _my;

    Widget bodyContent() {
      if (_profileIncomplete) return profileIncompleteCard();
      if (_loading && list.isEmpty && _error == null) {
        return const Center(child: CircularProgressIndicator(color: _brand));
      }
      if (_error != null && list.isEmpty) {
        return Center(child: Text(_error!, style: TextStyle(color: titleColor, fontWeight: FontWeight.w700)));
      }
      if (!_loading && list.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: muted.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  _tab == _CourierTab.available
                      ? "В городе ${me.city.isEmpty ? "—" : me.city} пока нет новых заказов."
                      : "У вас пока нет активных доставок.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _orderCard(
          order: list[i],
          isAvailableTab: _tab == _CourierTab.available,
          actionMsg: _actionMsg,
          onRequest: _requestOrder,
          isDark: isDark,
          titleColor: titleColor,
          muted: muted,
          border: border,
          cardBg: cardBg,
          innerBg: innerBg,
        ),
      );
    }

    return RefreshIndicator(
      color: _brand,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: tabSwitcher()),
          ),
          if (_loading && list.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LinearProgressIndicator(color: _brand),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverFillRemaining(
              hasScrollBody: list.isNotEmpty,
              child: bodyContent(),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CourierTab { available, my }

Widget _tabChip({
  required String label,
  required bool active,
  required VoidCallback onTap,
  required bool isDark,
  required Color titleColor,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? (isDark ? const Color(0xFF0F172A) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active && !isDark ? const [BoxShadow(color: Color(0x120F172A), blurRadius: 8, offset: Offset(0, 2))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)) : titleColor.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _orderCard({
  required OrderModel order,
  required bool isAvailableTab,
  required Map<int, String>? actionMsg,
  required void Function(int) onRequest,
  required bool isDark,
  required Color titleColor,
  required Color muted,
  required Color border,
  required Color cardBg,
  required Color innerBg,
}) {
  final created = order.createdAt;
  final dateStr = created != null
      ? "${created.day.toString().padLeft(2, "0")}.${created.month.toString().padLeft(2, "0")}.${created.year}"
      : "";
  final deliveryType = order.courier?.deliveryType;
  final pending = order.myRequestStatus == "pending";
  final msg = actionMsg?[order.id];

  return DecoratedBox(
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 4)],
                  ),
                  child: Icon(Icons.shopping_bag_outlined, color: titleColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Заказ #${order.id}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor)),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: muted),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x331D4ED8) : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  ),
                ),
                if (deliveryType != null && deliveryType.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_courierDeliveryIcon(deliveryType), size: 12, color: muted),
                        const SizedBox(width: 4),
                        Text(deliveryType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: muted)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "АДРЕС ДОСТАВКИ",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${order.shippingCity}, ${order.shippingAddress}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Доставка:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: muted)),
                          Text(
                            "${order.deliveryCost} смн.",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isAvailableTab)
                        FilledButton(
                          onPressed: (msg != null && msg != "…") || pending ? null : () => onRequest(order.id),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0x802563EB),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            msg ?? (pending ? "Вы уже подали заявку" : "Взять заказ →"),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pedal_bike_rounded, size: 18, color: muted),
                              const SizedBox(width: 8),
                              Text("Вы назначены", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: border, height: 1),
              const SizedBox(height: 12),
              Text(
                "ТОВАРЫ",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: muted),
              ),
              const SizedBox(height: 8),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${item.productTitle} ×${item.qty}",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                        ),
                      ),
                      Text(
                        "${item.unitPrice} смн.",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

IconData _courierDeliveryIcon(String type) {
  switch (type) {
    case "Пешком":
      return Icons.directions_walk_rounded;
    case "На велосипеде":
      return Icons.pedal_bike_rounded;
    case "На скутере":
      return Icons.two_wheeler_rounded;
    case "На машине":
      return Icons.directions_car_rounded;
    default:
      return Icons.local_shipping_outlined;
  }
}
