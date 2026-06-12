import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "api_client.dart";
import "app_state.dart";
import "models.dart";
import "profile_auth_body.dart";
import "widgets/kharid_site_header.dart";

const _kBrand = Color(0xFF2563EB);

/// Охирин суроға аз checkout — чунки дар `/me/` шаҳр/суроға ҳатман пур намешаванд.
const _kPrefLastCheckoutPhone = "kharid:last_checkout_phone";
const _kPrefLastCheckoutCity = "kharid:last_checkout_city";
const _kPrefLastCheckoutAddress = "kharid:last_checkout_address";

/// Корзина / оформление — макет монанди веб [cart-client.tsx].
class CartCheckoutTab extends StatefulWidget {
  const CartCheckoutTab({super.key, required this.api, this.onSellerLoggedIn});
  final ApiClient api;
  final void Function(BuildContext context)? onSellerLoggedIn;

  @override
  State<CartCheckoutTab> createState() => _CartCheckoutTabState();
}

class _CartCheckoutTabState extends State<CartCheckoutTab> {
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  List<City> _cities = const [];
  bool _loadingCities = true;
  String _shippingCity = "";

  int _prepayPercent = 20;
  String _paymentMethod = "smartpay";

  bool _placing = false;
  String? _error;
  bool _success = false;

  AppState? _app;
  bool _listenerAttached = false;

  String _cachedLastCheckoutPhone = "";
  String _cachedLastCheckoutCity = "";
  String _cachedLastCheckoutAddress = "";

  @override
  void initState() {
    super.initState();
    _loadCities();
    _loadCheckoutHints();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    _app ??= app;
    if (!_listenerAttached) {
      _listenerAttached = true;
      app.addListener(_onAppChanged);
    }
    _mergeShippingFromMeAndCache();
  }

  void _onAppChanged() {
    if (!mounted) return;
    _mergeShippingFromMeAndCache();
    setState(() {});
  }

  Future<void> _loadCheckoutHints() async {
    try {
      final p = await SharedPreferences.getInstance();
      _cachedLastCheckoutPhone = p.getString(_kPrefLastCheckoutPhone) ?? "";
      _cachedLastCheckoutCity = p.getString(_kPrefLastCheckoutCity) ?? "";
      _cachedLastCheckoutAddress = p.getString(_kPrefLastCheckoutAddress) ?? "";
    } catch (_) {}
    if (!mounted) return;
    setState(() => _mergeShippingFromMeAndCache());
  }

  /// Профиль (`/me/`) + охирин закази муваффақ дар ин дастгоҳ.
  void _mergeShippingFromMeAndCache() {
    final me = _app?.me;
    if (_phone.text.trim().isEmpty) {
      final m = me?.phone.trim() ?? "";
      if (m.isNotEmpty) {
        _phone.text = m;
      } else if (_cachedLastCheckoutPhone.trim().isNotEmpty) {
        _phone.text = _cachedLastCheckoutPhone.trim();
      }
    }
    if (_address.text.trim().isEmpty) {
      final m = me?.address.trim() ?? "";
      if (m.isNotEmpty) {
        _address.text = m;
      } else if (_cachedLastCheckoutAddress.trim().isNotEmpty) {
        _address.text = _cachedLastCheckoutAddress.trim();
      }
    }
    if (_shippingCity.trim().isEmpty) {
      final m = me?.city.trim() ?? "";
      if (m.isNotEmpty) {
        _shippingCity = m;
      } else if (_cachedLastCheckoutCity.trim().isNotEmpty) {
        _shippingCity = _cachedLastCheckoutCity.trim();
      }
    }
    _matchShippingCityToList();
  }

  void _matchShippingCityToList() {
    if (_cities.isEmpty || _shippingCity.isEmpty) return;
    final want = _shippingCity.toLowerCase();
    for (final c in _cities) {
      if (c.name.toLowerCase() == want) {
        if (c.name != _shippingCity) _shippingCity = c.name;
        return;
      }
    }
    _shippingCity = _cities.first.name;
  }

  Future<void> _loadCities() async {
    try {
      final list = await widget.api.cities();
      if (!mounted) return;
      setState(() {
        _cities = list;
        _mergeShippingFromMeAndCache();
        if (_shippingCity.trim().isEmpty && list.isNotEmpty) {
          _shippingCity = list.first.name;
        }
        _matchShippingCityToList();
      });
    } catch (_) {
      /* холӣ */
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  /// Қимат барои [DropdownButtonFormField] — бояд дар рӯйхати [items] бошад.
  String? _cityDropdownValue() {
    if (_cities.isEmpty) return null;
    if (_shippingCity.isNotEmpty && _cities.any((c) => c.name == _shippingCity)) {
      return _shippingCity;
    }
    return _cities.first.name;
  }

  @override
  void dispose() {
    _app?.removeListener(_onAppChanged);
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  City? get _selectedCity {
    if (_shippingCity.isEmpty) return null;
    try {
      return _cities.firstWhere((c) => c.name == _shippingCity);
    } catch (_) {
      return null;
    }
  }

  double _deliveryEstimate(AppState app) {
    final c = _selectedCity;
    if (c == null) return 0;
    return double.tryParse(c.deliveryCost.replaceAll(",", ".")) ?? 0;
  }

  String get _effectivePaymentMethod {
    if (_prepayPercent == 20) return "smartpay";
    return _paymentMethod;
  }

  Future<void> _placeOrder(AppState app) async {
    final me = app.me;
    if (me == null) return;
    final phone = _phone.text.trim();
    final addr = _address.text.trim();
    final city = _shippingCity.trim();
    if (phone.isEmpty || city.isEmpty || addr.isEmpty) {
      setState(() => _error = "Пожалуйста, укажите город, телефон и адрес доставки.");
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final balance = double.tryParse(me.balance.replaceAll(",", ".")) ?? 0;
      final subtotal = app.subtotal;
      final delivery = _deliveryEstimate(app);
      final total = subtotal + delivery;
      final canBalance = balance >= total;

      if (_prepayPercent == 100 && _paymentMethod == "balance" && !canBalance) {
        setState(() => _error = "Баланса недостаточно для оплаты всего заказа.");
        return;
      }

      final data = await widget.api.createOrder(
        accessToken: app.accessToken!,
        contactPhone: phone,
        shippingCity: city,
        shippingAddress: addr,
        lines: app.cart,
        paymentMethod: _effectivePaymentMethod,
        prepayPercent: _prepayPercent,
        note: _note.text,
      );
      if (!mounted) return;

      final link = data["payment_link"]?.toString();
      if (link != null && link.isNotEmpty) {
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      await app.clearCart();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPrefLastCheckoutPhone, phone);
        await prefs.setString(_kPrefLastCheckoutCity, city);
        await prefs.setString(_kPrefLastCheckoutAddress, addr);
        _cachedLastCheckoutPhone = phone;
        _cachedLastCheckoutCity = city;
        _cachedLastCheckoutAddress = addr;
      } catch (_) {}
      setState(() => _success = true);
    } catch (e) {
      if (mounted) setState(() => _error = "$e".replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 58 + 12 + 8;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    final titleC = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final divide = isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9);

    if (_success) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: _kharidAppBar(context, "Корзина"),
        body: Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0x1A10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 24),
              Text("Заказ принят!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: titleC)),
              const SizedBox(height: 12),
              Text(
                "Спасибо за покупку. Мы свяжемся с вами в ближайшее время.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.4, color: muted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),
              TextButton.icon(
                onPressed: () => app.requestSwitchTab(4),
                icon: const Icon(Icons.arrow_forward_rounded, color: _kBrand, size: 18),
                label: const Text("Перейти в профиль", style: TextStyle(fontWeight: FontWeight.w800, color: _kBrand)),
              ),
            ],
          ),
        ),
      );
    }

    if (app.cart.isEmpty) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: _kharidAppBar(context, "Корзина"),
        body: Padding(
          padding: EdgeInsets.fromLTRB(24, 48, 24, bottomPad),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_rounded, size: 64, color: isDark ? const Color(0xFF27272A) : const Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 28),
              Text("Ваша корзина пуста", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: titleC)),
              const SizedBox(height: 12),
              Text(
                "Самое время добавить в неё что-нибудь интересное!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: muted, height: 1.4),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => app.requestSwitchTab(0),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  child: const Text("Начать покупки"),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final subtotal = app.subtotal;
    final delivery = _deliveryEstimate(app);
    final total = subtotal + delivery;
    final me = app.me;
    final balance = double.tryParse(me?.balance.replaceAll(",", ".") ?? "0") ?? 0;
    final canUseBalance = balance >= total;
    final wide = MediaQuery.sizeOf(context).width >= 960;

    final itemsSection = _CartItemsSection(
      cart: app.cart,
      isDark: isDark,
      cardBg: cardBg,
      border: border,
      divide: divide,
      titleC: titleC,
      muted: muted,
      onDelta: (i, d) {
        final line = app.cart[i];
        app.updateQty(line.product.id, line.qty + d, variantId: line.product.variantId);
      },
      onRemove: (i) {
        final line = app.cart[i];
        app.updateQty(line.product.id, 0, variantId: line.product.variantId);
      },
    );

    final authOrBuyer = _buildAuthOrBuyerBlock(
      context,
      app,
      bottomPad,
      isDark,
      titleC,
      muted,
      cardBg,
      border,
      me,
    );

    final summary = _SummaryCard(
      linesCount: app.cart.length,
      subtotal: subtotal,
      delivery: delivery,
      total: total,
      isDark: isDark,
      titleC: titleC,
      muted: muted,
      cardBg: cardBg,
      border: border,
      me: me,
      prepayPercent: _prepayPercent,
      paymentMethod: _paymentMethod,
      balance: balance,
      canUseBalance: canUseBalance,
      placing: _placing,
      error: _error,
      onPrepay: (p) => setState(() {
        _prepayPercent = p;
        if (p == 20) _paymentMethod = "smartpay";
      }),
      onPaymentMethod: (m) => setState(() => _paymentMethod = m),
      onPlaceOrder: () => _placeOrder(app),
    );

    return Scaffold(
      backgroundColor: pageBg,
      appBar: _kharidAppBar(context, "Корзина"),
      body: LayoutBuilder(
        builder: (context, c) {
          final child = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text("Оформление заказа", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: titleC)),
              ),
              const SizedBox(height: 20),
              if (wide)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: itemsSection),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 20),
                            authOrBuyer,
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      itemsSection,
                      const SizedBox(height: 20),
                      summary,
                      const SizedBox(height: 20),
                      authOrBuyer,
                    ],
                  ),
                ),
              SizedBox(height: bottomPad),
            ],
          );
          return SingleChildScrollView(child: child);
        },
      ),
    );
  }

  PreferredSizeWidget _kharidAppBar(BuildContext context, String subtitle) {
    return KharidSiteHeader(
      onMenuPressed: () => context.read<AppState>().openSideMenuFrom(context),
      subtitle: Text(subtitle),
      showBackWhenCanPop: false,
    );
  }

  Widget _buildAuthOrBuyerBlock(
    BuildContext context,
    AppState app,
    double bottomPad,
    bool isDark,
    Color titleC,
    Color muted,
    Color cardBg,
    Color border,
    MeProfile? me,
  ) {
    if (me == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBFDBFE)),
          color: isDark ? const Color(0x140256EA) : const Color(0x14EFF6FF),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Для оформления нужно войти", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: titleC)),
                  const SizedBox(height: 6),
                  Text(
                    "Войдите или зарегистрируйтесь, чтобы завершить покупку.",
                    style: TextStyle(fontSize: 13, color: muted, height: 1.35),
                  ),
                ],
              ),
            ),
            ColoredBox(
              color: cardBg,
              child: ProfileAuthScrollBody(
                api: widget.api,
                bottomPadding: 8,
                includeSiteFooter: false,
                transparentPageBackground: true,
                shrinkWrapScroll: true,
                showMainTitle: false,
                onSellerLoggedIn: widget.onSellerLoggedIn,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Информация о покупателе", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: titleC)),
          const SizedBox(height: 18),
          _LabeledField(
            label: "Телефон для связи",
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontWeight: FontWeight.w600, color: titleC),
              decoration: _inputDeco(isDark, hint: "+992…"),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: "Город",
            child: _loadingCities
                ? const LinearProgressIndicator(minHeight: 3)
                : _cities.isEmpty
                    ? Text(
                        "Не удалось загрузить города.",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                      )
                    : DropdownButtonFormField<String>(
                    key: ValueKey<String>(_shippingCity),
                    initialValue: _cityDropdownValue(),
                    dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    style: TextStyle(fontWeight: FontWeight.w600, color: titleC, fontSize: 14),
                    decoration: _inputDeco(isDark, hint: "Выберите город…"),
                    items: _cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _shippingCity = v ?? ""),
                  ),
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: "Адрес доставки",
            child: TextField(
              controller: _address,
              style: TextStyle(fontWeight: FontWeight.w600, color: titleC),
              decoration: _inputDeco(isDark, hint: "Улица, дом, квартира…"),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: "Комментарий к заказу (необязательно)",
            child: TextField(
              controller: _note,
              maxLines: 2,
              style: TextStyle(fontWeight: FontWeight.w600, color: titleC),
              decoration: _inputDeco(isDark, hint: "Например: подъезд 3, код 123"),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(bool isDark, {String? hint}) {
    final b = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: b)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: b)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lab = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: lab)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _CartItemsSection extends StatelessWidget {
  const _CartItemsSection({
    required this.cart,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.divide,
    required this.titleC,
    required this.muted,
    required this.onDelta,
    required this.onRemove,
  });
  final List<CartLine> cart;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color divide;
  final Color titleC;
  final Color muted;
  final void Function(int index, int delta) onDelta;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < cart.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: divide),
            _CartLineRow(
              line: cart[i],
              isDark: isDark,
              titleC: titleC,
              muted: muted,
              onMinus: () => onDelta(i, -1),
              onPlus: () => onDelta(i, 1),
              onRemove: () => onRemove(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({
    required this.line,
    required this.isDark,
    required this.titleC,
    required this.muted,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });
  final CartLine line;
  final bool isDark;
  final Color titleC;
  final Color muted;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final unit = p.sellPrice;
    final imgBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);
    final qtyBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);
    final qtyBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: imgBorder),
              color: isDark ? Colors.black : const Color(0xFFF8FAFC),
            ),
            padding: const EdgeInsets.all(6),
            child: p.primaryImage == null
                ? Icon(Icons.image_not_supported_outlined, color: muted, size: 32)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(p.primaryImage!, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25, color: titleC),
                ),
                const SizedBox(height: 6),
                Text("${unit.toStringAsFixed(0)} смн", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kBrand)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: qtyBorder),
                        color: qtyBg,
                      ),
                      child: Row(
                        children: [
                          _QtyIconButton(icon: Icons.remove_rounded, onTap: onMinus),
                          SizedBox(
                            width: 36,
                            child: Text(
                              "${line.qty}",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w800, color: titleC),
                            ),
                          ),
                          _QtyIconButton(icon: Icons.add_rounded, onTap: onPlus),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onRemove,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: isDark ? const Color(0xFF52525B) : const Color(0xFFCBD5E1),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyIconButton extends StatelessWidget {
  const _QtyIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.linesCount,
    required this.subtotal,
    required this.delivery,
    required this.total,
    required this.isDark,
    required this.titleC,
    required this.muted,
    required this.cardBg,
    required this.border,
    required this.me,
    required this.prepayPercent,
    required this.paymentMethod,
    required this.balance,
    required this.canUseBalance,
    required this.placing,
    required this.error,
    required this.onPrepay,
    required this.onPaymentMethod,
    required this.onPlaceOrder,
  });
  final int linesCount;
  final double subtotal;
  final double delivery;
  final double total;
  final bool isDark;
  final Color titleC;
  final Color muted;
  final Color cardBg;
  final Color border;
  final MeProfile? me;
  final int prepayPercent;
  final String paymentMethod;
  final double balance;
  final bool canUseBalance;
  final bool placing;
  final String? error;
  final void Function(int) onPrepay;
  final void Function(String) onPaymentMethod;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    final payBlocked = me == null || (prepayPercent == 100 && paymentMethod == "balance" && !canUseBalance);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 10))],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Итого", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: titleC)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Товары ($linesCount)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
              Text("${subtotal.toStringAsFixed(2)} смн", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleC)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Доставка", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
              Text(
                delivery > 0 ? "${delivery.toStringAsFixed(2)} смн" : "Бесплатно",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: delivery > 0 ? titleC : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ИТОГО", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: titleC)),
              Text("${total.toStringAsFixed(2)} смн", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kBrand)),
            ],
          ),
          if (me != null) ...[
            const SizedBox(height: 20),
            Text("ОПЛАТА", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: muted)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Сколько оплатить сейчас?", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _PctChip(label: "20%", selected: prepayPercent == 20, onTap: () => onPrepay(20))),
                      const SizedBox(width: 8),
                      Expanded(child: _PctChip(label: "100%", selected: prepayPercent == 100, onTap: () => onPrepay(100))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prepayPercent == 20
                        ? "Сейчас оплатите 20% онлайн, остальное — при доставке."
                        : "Полная оплата. При доставке доплачивать не нужно.",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (prepayPercent == 20)
              _PayOptionTile(
                selected: true,
                title: "Онлайн — 20%",
                icon: Icons.credit_card_rounded,
                isDark: isDark,
              )
            else ...[
              if (balance > 0)
                _PayOptionButton(
                  selected: paymentMethod == "balance",
                  title: "Оплатить с баланса",
                  subtitle: "Доступно: ${balance.toStringAsFixed(2)} смн",
                  subtitleColor: canUseBalance ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  icon: Icons.account_balance_wallet_rounded,
                  isDark: isDark,
                  foot: paymentMethod == "balance"
                      ? (canUseBalance
                          ? "Средства будут списаны с вашего счета моментально."
                          : "Баланса недостаточно для оплаты всего заказа.")
                      : null,
                  onTap: () => onPaymentMethod("balance"),
                ),
              const SizedBox(height: 10),
              _PayOptionButton(
                selected: paymentMethod == "smartpay",
                title: "Онлайн",
                subtitle: null,
                subtitleColor: muted,
                icon: Icons.credit_card_rounded,
                isDark: isDark,
                foot: null,
                onTap: () => onPaymentMethod("smartpay"),
              ),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECDD3)),
              ),
              child: Text(error!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C))),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: payBlocked || placing ? null : onPlaceOrder,
              style: FilledButton.styleFrom(
                backgroundColor: _kBrand,
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: _kBrand.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: placing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text("Обработка...", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Оформить заказ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
          if (me == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                "Войдите, чтобы оформить заказ",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 1 : 0.95)),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            "Нажимая кнопку, вы соглашаетесь с условиями оферты и политикой конфиденциальности.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, height: 1.35, color: muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PctChip extends StatelessWidget {
  const _PctChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? _kBrand : (isDark ? const Color(0xFF09090B) : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: selected ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayOptionTile extends StatelessWidget {
  const _PayOptionTile({required this.selected, required this.title, required this.icon, required this.isDark});
  final bool selected;
  final String title;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.65)),
        color: isDark ? const Color(0x140256EA) : const Color(0x12EFF6FF),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class _PayOptionButton extends StatelessWidget {
  const _PayOptionButton({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    required this.isDark,
    required this.foot,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String? subtitle;
  final Color subtitleColor;
  final IconData icon;
  final bool isDark;
  final String? foot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9));
    final bg = selected
        ? (isDark ? const Color(0x140256EA) : const Color(0x12EFF6FF))
        : (isDark ? const Color(0xFF18181B).withValues(alpha: 0.45) : const Color(0xFFF8FAFC));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border.withValues(alpha: selected ? 1 : 0.9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? _kBrand : (isDark ? const Color(0xFF27272A) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: selected ? Colors.white : (isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8)), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        if (subtitle != null)
                          Text(subtitle!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subtitleColor)),
                      ],
                    ),
                  ),
                ],
              ),
              if (foot != null && selected) ...[
                const SizedBox(height: 8),
                Text(foot!, style: TextStyle(fontSize: 10, height: 1.35, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
