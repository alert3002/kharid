import "dart:async";
import "dart:math" show Random, min, max;

import "package:flutter/foundation.dart" show kDebugMode;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:share_plus/share_plus.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "account_forms.dart";
import "account_nav.dart";
import "cart_checkout_tab.dart";
import "api_client.dart";
import "api_config.dart";
import "app_state.dart";
import "kharid_lists.dart";
import "models.dart";
import "profile_auth_body.dart";
import "screens/about_screen.dart";
import "screens/become_seller_screen.dart";
import "courier_deliveries_screen.dart";
import "client_orders_screen.dart";
import "earnings_history_screen.dart";
import "unified_referrals_screen.dart";
import "mlm_tab_screen.dart";
import "screens/bonus_screen.dart";
import "screens/reels_screen.dart";
import "widgets/app_logo.dart";
import "widgets/kharid_site_header.dart";

const String _kPublicSiteOrigin = String.fromEnvironment("WEB_BASE_URL", defaultValue: "https://kharid.tj");

/// Футер аз поёни экран каме боло мемонад (на дар системаи gesture печида).
const double _kFloatingNavLiftFromBottom = 12;

/// Фосилаи поён: safe area + баландии наздикии нави поён + боло баровардани футер + ҷой барои тугмаи «В корзину».
double _floatingNavBottomInset(BuildContext context) {
  final sys = MediaQuery.viewPaddingOf(context).bottom;
  return sys + 58 + _kFloatingNavLiftFromBottom + 8;
}

/// Болои тугмаи фикси «В корзину» аз футер — иловагӣ ба [bottom] дар `Positioned`.
const double _kFixedAddToCartExtraAboveNav = 14;

/// Сарлавҳаи умум: меню + лого дар марказ; `subtitle` — сатри зери он (унвони саҳифа дар веб-макет).
KharidSiteHeader _kharidChromeAppBar(
  BuildContext context, {
  String? subtitle,
  bool showBackWhenCanPop = true,
  Widget? trailing,
  VoidCallback? onNotificationPressed,
}) {
  return KharidSiteHeader(
    onMenuPressed: () => context.read<AppState>().openSideMenuFrom(context),
    subtitle: subtitle != null ? Text(subtitle) : null,
    showBackWhenCanPop: showBackWhenCanPop,
    trailing: trailing,
    onNotificationPressed: onNotificationPressed,
  );
}

class AppShellV2 extends StatefulWidget {
  const AppShellV2({super.key, required this.api});
  final ApiClient api;

  @override
  State<AppShellV2> createState() => _AppShellV2State();
}

class _AppShellV2State extends State<AppShellV2> {
  int index = 0;
  AppState? _appState;
  final List<GlobalKey<NavigatorState>> _tabNavKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    _appState = app;
    app.setSideMenuOpener((BuildContext anchor) {
      if (!mounted) return;
      _openKharidMenuSheet(anchor);
    });
    app.onRequestSwitchTab = (int i) {
      if (!mounted) return;
      if (i == 0) {
        _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);
      }
      setState(() => index = i);
    };
  }

  @override
  void dispose() {
    _appState?.setSideMenuOpener(null);
    _appState?.onRequestSwitchTab = null;
    super.dispose();
  }

  void _onBottomNavChanged(int v) {
    if (v == 0) {
      _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);
    }
    if (!mounted) return;
    if (index != v) {
      setState(() => index = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: index,
                sizing: StackFit.expand,
                children: [
                  _TabShell(navKey: _tabNavKeys[0], child: HomeTab(api: api)),
                  _TabShell(navKey: _tabNavKeys[1], child: CatalogTab(api: api)),
                  _TabShell(navKey: _tabNavKeys[2], child: CartCheckoutTab(api: api, onSellerLoggedIn: (ctx) => _pushSellerMyProducts(api, ctx, rootNavigator: true))),
                  _TabShell(navKey: _tabNavKeys[3], child: MlmTab(api: api)),
                  _TabShell(navKey: _tabNavKeys[4], child: ProfileTab(api: api)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _kFloatingNavLiftFromBottom,
            child: _BottomNav(
              index: index,
              onChanged: _onBottomNavChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigator-и дохили як таб: `push` дар ин ҷо мемонад, футери поён ҳамеша намоён аст.
class _TabShell extends StatelessWidget {
  const _TabShell({required this.navKey, required this.child});
  final GlobalKey<NavigatorState> navKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateInitialRoutes: (NavigatorState state, String initialRouteName) {
        return [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: "/"),
            builder: (_) => child,
          ),
        ];
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const Color _inactiveIcon = Color(0xFF0F172A);
  static const Color _activeBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveIcon = isDark ? const Color(0xFFBFDBFE) : _inactiveIcon;
    final cartCount = app.cart.fold<int>(0, (sum, e) => sum + e.qty);

    Widget cartIcon(bool selected) {
      final icon = Icon(
        Icons.shopping_cart_rounded,
        size: 20,
        color: selected ? Colors.white : inactiveIcon,
      );
      if (cartCount <= 0) return icon;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          icon,
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                cartCount > 99 ? "99+" : cartCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
          ),
        ],
      );
    }

    Widget item({
      required int i,
      required IconData iconData,
      required String label,
      Widget? customIcon,
    }) {
      final selected = index == i;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: selected ? _activeBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 22,
                    child: Center(
                      child: customIcon ??
                          Icon(
                            iconData,
                            size: 20,
                            color: selected ? Colors.white : inactiveIcon,
                          ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      color: selected ? Colors.white : inactiveIcon,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1A3A) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: isDark ? Border.all(color: const Color(0xFF1E3A8A)) : null,
            boxShadow: [
              BoxShadow(
                color: (isDark ? const Color(0xFF020617) : const Color(0xFF0F172A)).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
          child: Row(
            children: [
              item(i: 0, iconData: Icons.home_rounded, label: "Главная"),
              item(i: 1, iconData: Icons.grid_view_rounded, label: "Каталог"),
              item(i: 2, iconData: Icons.shopping_cart_rounded, label: "Корзина", customIcon: cartIcon(index == 2)),
              item(i: 3, iconData: Icons.hub_rounded, label: "МЛМ"),
              item(i: 4, iconData: Icons.person_rounded, label: "Профиль"),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.api});
  final ApiClient api;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomGap = _floatingNavBottomInset(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF061433) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _HomeHeader()),
          SliverToBoxAdapter(child: _HeroCard(api: widget.api)),
          SliverToBoxAdapter(child: _QuickPills()),
          SliverToBoxAdapter(child: _PopularProducts(api: widget.api)),
          SliverToBoxAdapter(child: _NewProducts(api: widget.api)),
          SliverToBoxAdapter(child: _CategoryPromoSection(api: widget.api)),
          SliverToBoxAdapter(child: _SiteFooter(onScrollToTop: _scrollToTop)),
          SliverToBoxAdapter(child: SizedBox(height: bottomGap)),
        ],
      ),
    );
  }
}

class _NewProducts extends StatefulWidget {
  const _NewProducts({required this.api});
  final ApiClient api;

  @override
  State<_NewProducts> createState() => _NewProductsState();
}

class _NewProductsState extends State<_NewProducts> {
  bool loading = true;
  bool loadingMore = false;
  String? error;
  int page = 1;
  bool hasMorePages = true;

  List<ProductListItem> fetched = const [];
  int visible = 10;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      loading = true;
      error = null;
      page = 1;
      hasMorePages = true;
      visible = 10;
    });
    try {
      final res = await widget.api.products(page: 1, ordering: "-created_at");
      fetched = res.results;
      hasMorePages = res.next != null && res.next!.isNotEmpty;
    } catch (e) {
      error = friendlyApiError(e);
      fetched = const [];
      hasMorePages = false;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadMore() async {
    if (loadingMore) return;
    // If we already have enough cached items for next +10, just reveal.
    final nextVisible = visible + 10;
    if (fetched.length >= nextVisible || !hasMorePages) {
      setState(() => visible = nextVisible.clamp(0, fetched.length));
      return;
    }

    setState(() => loadingMore = true);
    try {
      final nextPage = page + 1;
      final res = await widget.api.products(page: nextPage, ordering: "-created_at");
      fetched = [...fetched, ...res.results];
      page = nextPage;
      hasMorePages = res.next != null && res.next!.isNotEmpty;
      visible = nextVisible.clamp(0, fetched.length);
    } catch (e) {
      error = friendlyApiError(e);
    }
    if (mounted) setState(() => loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final showItems = fetched.take(visible).toList();
    final canLoadMore = (hasMorePages || fetched.length > visible) && showItems.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Новинки",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CategoryProductsScreen(api: widget.api, categorySlug: null, title: "Каталог"),
                    ),
                  );
                },
                child: const Text(
                  "Все товары →",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (error != null && showItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
            )
          else if (showItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text("Пока нет товаров.", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.51,
              ),
              itemCount: showItems.length,
              itemBuilder: (context, i) => _ProductCardMini(api: widget.api, p: showItems[i], showHit: false),
            ),
            const SizedBox(height: 14),
            if (canLoadMore)
              Center(
                child: ElevatedButton.icon(
                  onPressed: loadingMore ? null : _loadMore,
                  icon: loadingMore
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.expand_more_rounded, size: 22),
                  label: Text(
                    loadingMore ? "Загрузка…" : "Загрузить ещё",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            const _MotivationCards(),
          ],
        ],
      ),
    );
  }
}

class _MotivationCards extends StatelessWidget {
  const _MotivationCards();

  @override
  Widget build(BuildContext context) {
    Widget card({
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 12, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        card(
          icon: Icons.cached_rounded,
          title: "Гарантия возврата денег",
          subtitle: "Вернём деньги, если товар не подошёл — до 14 дней по правилам маркетплейса.",
        ),
        const SizedBox(height: 10),
        card(
          icon: Icons.local_shipping_outlined,
          title: "Доставка за счёт маркетплейса",
          subtitle: "Бесплатная доставка при заказе от 1000 сомони — уточняйте при оформлении.",
        ),
        const SizedBox(height: 10),
        card(
          icon: Icons.support_agent_rounded,
          title: "Служба поддержки клиентов 24/7",
          subtitle: "Помощь в чате и по телефону в любое время.",
        ),
      ],
    );
  }
}

class _PopularProducts extends StatefulWidget {
  const _PopularProducts({required this.api});
  final ApiClient api;

  @override
  State<_PopularProducts> createState() => _PopularProductsState();
}

class _PopularProductsState extends State<_PopularProducts> {
  bool loading = true;
  String? error;
  List<ProductListItem> items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.api.products(page: 1, ordering: "-created_at");
      items = page.results;
    } catch (e) {
      error = friendlyApiError(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = (w - 14 * 2 - 12) / 2; // 2 cards visible + gap
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Популярные товары",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CategoryProductsScreen(api: widget.api, categorySlug: null, title: "Каталог"),
                    ),
                  );
                },
                child: const Text(
                  "Все товары →",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text("Пока нет товаров.", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            )
          else
            SizedBox(
              height: cardW * 1.25 + 142,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length.clamp(0, 20),
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                  width: cardW,
                  child: _ProductCardMini(api: widget.api, p: items[i], showHit: i < 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCardMini extends StatefulWidget {
  const _ProductCardMini({required this.api, required this.p, this.showHit = false, this.compact = false});
  final ApiClient api;
  final ProductListItem p;
  final bool showHit;
  /// Режими хурд барои каруселҳо (масалан «Похожие товары»): акси кӯтароҳ, бе фосилаи зиёд.
  final bool compact;

  @override
  State<_ProductCardMini> createState() => _ProductCardMiniState();
}

class _ProductCardMiniState extends State<_ProductCardMini> {
  void _openProductPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: widget.api, slug: widget.p.slug)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final app = context.watch<AppState>();
    final inCompare = app.isProductInCompare(p.id);
    final inWishlist = app.isProductInWishlist(p.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = double.tryParse(p.price) ?? 0;
    final sale = double.tryParse(p.salePrice ?? "") ?? price;
    final hasSale = p.salePrice != null && p.salePrice!.isNotEmpty && sale > 0 && sale < price;
    final isVariant = p.productType == "variant";
    final compact = widget.compact;
    final edge = compact ? 8.0 : 10.0;

    Widget topIcon({
      required IconData icon,
      required VoidCallback onTap,
      bool active = false,
      bool wishlist = false,
    }) {
      final d = compact ? 28.0 : 36.0;
      final iconSz = compact ? 15.0 : 18.0;
      final r = compact ? 8.0 : 10.0;
      final borderColor = wishlist && active
          ? const Color(0xFFFDA4AF)
          : active
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFE2E8F0);
      final iconColor = wishlist && active
          ? const Color(0xFFE11D48)
          : active
              ? const Color(0xFF2563EB)
              : const Color(0xFF64748B);
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: Container(
          height: d,
          width: d,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: borderColor),
            boxShadow: const [BoxShadow(color: Color(0x120F172A), blurRadius: 10, offset: Offset(0, 6))],
          ),
          child: Icon(
            icon,
            size: iconSz,
            color: iconColor,
            fill: wishlist && active ? 1.0 : 0.0,
          ),
        ),
      );
    }

    Future<void> onCartTap() async {
      if (isVariant) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductScreenV2(api: widget.api, slug: p.slug)),
        );
        return;
      }
      await app.addToCart(p);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Товар добавлен в корзину")),
        );
      }
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1A3A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x33060B12) : const Color(0x0F0F172A),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openProductPage,
              child: AspectRatio(
                aspectRatio: compact ? 1 : 4 / 5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: p.displayImage == null
                          ? Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: Text(
                                  "Нет фото",
                                  style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800),
                                ),
                              ),
                            )
                          : Image.network(p.displayImage!, fit: BoxFit.cover),
                    ),
                    if (widget.showHit)
                      Positioned(
                        top: edge,
                        left: edge,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
                          ),
                          child: const Text(
                            "ХИТ",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.3),
                          ),
                        ),
                      ),
                    Positioned(
                      top: edge,
                      right: edge,
                      child: Row(
                        children: [
                          topIcon(
                            icon: Icons.compare_arrows_rounded,
                            active: inCompare,
                            onTap: () async {
                              final limit = await app.toggleCompare(p);
                              if (limit == "limit" && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Не более $kCompareMax товаров для сравнения")),
                                );
                              }
                            },
                          ),
                          SizedBox(width: compact ? 4 : 6),
                          topIcon(
                            icon: inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            active: inWishlist,
                            wishlist: true,
                            onTap: () async {
                              await app.toggleWishlist(p);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      app.isProductInWishlist(p.id)
                                          ? "Добавлено в избранное"
                                          : "Удалено из избранного",
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (compact)
            Material(
              color: isDark ? const Color(0xFF0A1530) : Colors.transparent,
              child: InkWell(
                onTap: _openProductPage,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                if (isVariant)
                                  const Text(
                                    "от",
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                                  ),
                                if (hasSale)
                                  Text(
                                    "${price.toStringAsFixed(0)} смн",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  "${sale.toStringAsFixed(0)} смн",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: onCartTap,
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  isVariant ? Icons.touch_app_rounded : Icons.shopping_cart_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!compact) ...[
            Material(
              color: isDark ? const Color(0xFF0A1530) : Colors.transparent,
              child: InkWell(
                onTap: _openProductPage,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isVariant)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Text(
                                "от",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          if (hasSale)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                "${price.toStringAsFixed(0)} смн",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          Text(
                            "${sale.toStringAsFixed(0)} смн",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 1, color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: onCartTap,
                  icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                  label: Text(
                    isVariant ? "Выбрать" : "В корзину",
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }
}

class ProductScreenV2 extends StatelessWidget {
  const ProductScreenV2({super.key, required this.api, required this.slug});

  final ApiClient api;
  final String slug;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductDetail>(
      future: api.productBySlug(slug),
      builder: (context, snap) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _kharidChromeAppBar(context, subtitle: "Товар"),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snap.hasError
                  ? Center(child: Text("${snap.error}"))
                  : _ProductViewV2(api: api, item: snap.data!),
        );
      },
    );
  }
}

class _ProductViewV2 extends StatefulWidget {
  const _ProductViewV2({required this.api, required this.item});

  final ApiClient api;
  final ProductDetail item;

  @override
  State<_ProductViewV2> createState() => _ProductViewV2State();
}

class _PgSlide {
  const _PgSlide._({required this.isVideo, this.uid, this.url});
  final bool isVideo;
  final String? uid;
  final String? url;

  factory _PgSlide.video(String u) => _PgSlide._(isVideo: true, uid: u, url: null);
  factory _PgSlide.image(String u) => _PgSlide._(isVideo: false, uid: null, url: u);
}

String _fmtRuSmn(String? raw) {
  if (raw == null || raw.isEmpty) return "—";
  final n = double.tryParse(raw);
  if (n == null) return raw;
  final x = n.round();
  final s = x.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(" ");
    b.write(s[i]);
  }
  return "${b.toString()} смн";
}

Uri _kharidProductPublicUri(ProductDetail item) {
  var o = _kPublicSiteOrigin.trim();
  if (o.endsWith("/")) o = o.substring(0, o.length - 1);
  final base = Uri.parse(o);
  final slug = item.slug.trim();
  if (slug.isEmpty) return base.resolve("products/${item.id}");
  return base.resolve("p/$slug/");
}

String _kharidOriginNoTrailingSlash() {
  var o = _kPublicSiteOrigin.trim();
  if (o.endsWith("/")) o = o.substring(0, o.length - 1);
  return o;
}

/// Иконкаҳои бренд дар давра + скролл — бе матни дароз дар тугма.
class _ProductShareIconRow extends StatelessWidget {
  const _ProductShareIconRow({required this.productUrl, required this.productTitle});

  final String productUrl;
  final String productTitle;

  static const List<BoxShadow> _kShareShadow = [BoxShadow(color: Color(0x260F172A), blurRadius: 10, offset: Offset(0, 4))];

  Widget _circle({
    required String tooltip,
    required VoidCallback onTap,
    required Widget icon,
    Color? color,
    Gradient? gradient,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Ink(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                gradient: gradient,
                boxShadow: _kShareShadow,
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openShareSheet(BuildContext context) async {
    final text = "$productTitle\n$productUrl";
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Не удалось открыть меню «Поделиться»")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final encodedUrl = Uri.encodeComponent(productUrl);
    final mailQuery = "subject=${Uri.encodeQueryComponent(productTitle)}&body=${Uri.encodeQueryComponent(productUrl)}";

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _circle(
            tooltip: "Facebook",
            color: const Color(0xFF1877F2),
            icon: const FaIcon(FontAwesomeIcons.facebookF, color: Colors.white, size: 22),
            onTap: () => _openExternalUrl("https://www.facebook.com/sharer/sharer.php?u=$encodedUrl"),
          ),
          _circle(
            tooltip: "Instagram",
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
            ),
            icon: const FaIcon(FontAwesomeIcons.instagram, color: Colors.white, size: 24),
            onTap: () => _openShareSheet(context),
          ),
          _circle(
            tooltip: "Telegram",
            color: const Color(0xFF229ED9),
            icon: const FaIcon(FontAwesomeIcons.telegram, color: Colors.white, size: 22),
            onTap: () => _openExternalUrl("https://t.me/share/url?url=$encodedUrl"),
          ),
          _circle(
            tooltip: "WhatsApp",
            color: const Color(0xFF25D366),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 24),
            onTap: () => _openExternalUrl("https://wa.me/?text=${Uri.encodeComponent(productUrl)}"),
          ),
          _circle(
            tooltip: "Почта",
            color: const Color(0xFF64748B),
            icon: const FaIcon(FontAwesomeIcons.envelope, color: Colors.white, size: 20),
            onTap: () => _openExternalUrl("mailto:?$mailQuery"),
          ),
          _circle(
            tooltip: "Копия ссылки",
            color: const Color(0xFF334155),
            icon: const FaIcon(FontAwesomeIcons.copy, color: Colors.white, size: 18),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: productUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ссылка скопирована")));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ProductViewV2State extends State<_ProductViewV2> {
  final PageController _galleryPage = PageController();
  final ScrollController _productScroll = ScrollController();
  final GlobalKey _purchaseBlockKey = GlobalKey();
  int _galleryIndex = 0;
  int selectedVariantIdx = 0;
  int qty = 1;
  List<ProductListItem> related = const [];
  bool relatedLoading = true;
  /// Монанди React: вақте блоки харид дар экран намоён аст, тугмаи фикс пинҳон мешавад.
  bool _showFixedCta = true;

  @override
  void initState() {
    super.initState();
    _loadRelated();
    _productScroll.addListener(_updatePurchaseVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePurchaseVisibility());
  }

  @override
  void dispose() {
    _productScroll.removeListener(_updatePurchaseVisibility);
    _productScroll.dispose();
    _galleryPage.dispose();
    super.dispose();
  }

  void _updatePurchaseVisibility() {
    if (!mounted) return;
    final box = _purchaseBlockKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final media = MediaQuery.of(context);
    final topGuard = media.padding.top + 64;
    final bottomGuard = media.size.height - _floatingNavBottomInset(context);
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visibleTop = max(rect.top, topGuard);
    final visibleBottom = min(rect.bottom, bottomGuard);
    final visibleH = max(0.0, visibleBottom - visibleTop);
    final ratio = rect.height <= 0 ? 1.0 : visibleH / rect.height;
    final inlineEnough = ratio >= 0.45;
    final next = !inlineEnough;
    if (next == _showFixedCta) return;
    setState(() => _showFixedCta = next);
  }

  Future<void> _commitAddToCart() async {
    final item = widget.item;
    final isVariantProduct = item.productType == "variant" && item.variants.isNotEmpty;
    final selected = isVariantProduct ? item.variants[selectedVariantIdx.clamp(0, item.variants.length - 1)] : null;
    final shownImage = selected?.image ?? (item.images.isEmpty ? null : item.images.first);
    final shownPrice = selected?.price ?? item.price;
    final shownSalePrice = selected?.salePrice ?? item.salePrice;
    if (isVariantProduct && (selected == null || selected.id == 0)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Не удалось определить вариант. Обновите страницу.")));
      return;
    }
    final p = ProductListItem(
      id: item.id,
      title: selected == null ? item.title : "${item.title} • ${selected.valueText}",
      slug: item.slug,
      productType: item.productType,
      price: shownPrice,
      salePrice: shownSalePrice,
      primaryImage: shownImage,
      sku: selected?.sku ?? item.sku,
      variantId: selected?.id,
    );
    if (!mounted) return;
    final cartApp = context.read<AppState>();
    final idx = cartApp.cart.indexWhere(
      (e) => e.product.id == item.id && e.product.variantId == p.variantId,
    );
    if (idx < 0) {
      await cartApp.addToCart(p);
      if (qty != 1) await cartApp.updateQty(item.id, qty, variantId: p.variantId);
    } else {
      await cartApp.updateQty(item.id, cartApp.cart[idx].qty + qty, variantId: p.variantId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Добавлено в корзину")));
    }
  }

  Widget _buildAddToCartPill() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _commitAddToCart(),
        icon: const Icon(Icons.shopping_cart_rounded),
        label: const Text("В корзину", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _loadRelated() async {
    final slug = widget.item.categorySlug;
    if (slug == null || slug.isEmpty) {
      if (mounted) setState(() => relatedLoading = false);
      return;
    }
    try {
      final page = await widget.api.products(page: 1, ordering: "-created_at", categoryTreeSlug: slug);
      final list = page.results.where((e) => e.id != widget.item.id).take(16).toList();
      if (mounted) {
        setState(() {
          related = list;
          relatedLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => relatedLoading = false);
    }
  }

  List<_PgSlide> _slides(ProductDetail item, ProductVariantLite? selected, bool isVariant) {
    final out = <_PgSlide>[];
    final uid = (item.cloudflareVideoUid ?? "").trim();
    if (uid.isNotEmpty) out.add(_PgSlide.video(uid));
    if (item.images.isNotEmpty) {
      for (final u in item.images) {
        if (u.isNotEmpty) out.add(_PgSlide.image(u));
      }
    } else if (isVariant) {
      for (final v in item.variants) {
        final u = v.image;
        if (u != null && u.isNotEmpty && !out.any((s) => !s.isVideo && s.url == u)) out.add(_PgSlide.image(u));
      }
    }
    if (out.isEmpty) {
      final one = selected?.image ?? (item.images.isNotEmpty ? item.images.first : null);
      if (one != null && one.isNotEmpty) out.add(_PgSlide.image(one));
    }
    return out;
  }

  ProductListItem _listItemFromDetail(ProductDetail item, ProductVariantLite? selected) {
    return ProductListItem(
      id: item.id,
      title: item.title,
      slug: item.slug,
      productType: item.productType,
      price: selected?.price ?? item.price,
      salePrice: selected?.salePrice ?? item.salePrice,
      primaryImage: selected?.image ?? (item.images.isNotEmpty ? item.images.first : null),
      sku: item.sku,
      stockQty: selected?.stockQty ?? item.stockQty,
      stockUnit: item.stockUnit ?? selected?.stockUnit ?? "pcs",
      isActive: item.isActive,
      images: item.images,
      variantId: selected?.id,
      categorySlug: item.categorySlug ?? "",
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0B1A3A) : Colors.white;
    final border = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final isVariantProduct = item.productType == "variant" && item.variants.isNotEmpty;
    final selected = isVariantProduct ? item.variants[selectedVariantIdx.clamp(0, item.variants.length - 1)] : null;
    final listItem = _listItemFromDetail(item, selected);
    final inCompare = app.isProductInCompare(item.id);
    final inWishlist = app.isProductInWishlist(item.id);
    final shownPrice = selected?.price ?? item.price;
    final shownSalePrice = selected?.salePrice ?? item.salePrice;
    final priceVal = double.tryParse(shownPrice) ?? 0;
    final saleVal = double.tryParse(shownSalePrice ?? "") ?? priceVal;
    final hasSale = (shownSalePrice?.isNotEmpty ?? false) && saleVal < priceVal && saleVal > 0;
    final slides = _slides(item, selected, isVariantProduct);

    Widget iconAct({required IconData icon, required bool active, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101826) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? const Color(0xFF2563EB) : border),
          ),
          child: Icon(icon, size: 18, color: active ? const Color(0xFF2563EB) : textMuted),
        ),
      );
    }

    Widget cardWrap({required Widget child}) {
      return Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(14),
        child: child,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification n) {
            if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
              _updatePurchaseVisibility();
            }
            return false;
          },
          child: ListView(
            controller: _productScroll,
            padding: EdgeInsets.fromLTRB(14, 6, 14, 24 + _floatingNavBottomInset(context)),
            children: [
        if (item.categorySlug != null && item.categorySlug!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () {
                    while (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text("Главная", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMuted)),
                ),
                Text("/", style: TextStyle(color: textMuted.withValues(alpha: 0.5))),
                TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CategoryProductsScreen(
                          api: widget.api,
                          categorySlug: null,
                          title: item.categoryName ?? "Каталог",
                          categoryTreeSlug: item.categorySlug,
                        ),
                      ),
                    );
                  },
                  child: Text("Каталог", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMuted)),
                ),
                Text("/", style: TextStyle(color: textMuted.withValues(alpha: 0.5))),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMuted.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: slides.isEmpty
                ? ColoredBox(
                    color: const Color(0xFFF1F5F9),
                    child: Center(child: Text("Нет фото", style: TextStyle(color: textMuted, fontWeight: FontWeight.w800))),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView(
                        controller: _galleryPage,
                        onPageChanged: (i) => setState(() => _galleryIndex = i),
                        children: slides.map((s) {
                          if (s.isVideo && s.uid != null) {
                            final uri = Uri.parse("https://iframe.videodelivery.net/${Uri.encodeComponent(s.uid!)}?autoplay=false&muted=false&loop=true&preload=true");
                            return ColoredBox(
                              color: Colors.black,
                              child: InAppWebView(
                                key: ValueKey<String>(uri.toString()),
                                initialUrlRequest: URLRequest(url: WebUri(uri.toString())),
                                initialSettings: InAppWebViewSettings(
                                  javaScriptEnabled: true,
                                  mediaPlaybackRequiresUserGesture: false,
                                  isInspectable: kDebugMode,
                                  transparentBackground: false,
                                ),
                              ),
                            );
                          }
                          return Image.network(s.url!, fit: BoxFit.cover);
                        }).toList(),
                      ),
                      if (slides.length > 1) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _RoundIconBtn(
                              icon: Icons.chevron_left_rounded,
                              onTap: () {
                                final n = (_galleryIndex - 1 + slides.length) % slides.length;
                                _galleryPage.jumpToPage(n);
                              },
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _RoundIconBtn(
                              icon: Icons.chevron_right_rounded,
                              onTap: () {
                                final n = (_galleryIndex + 1) % slides.length;
                                _galleryPage.jumpToPage(n);
                              },
                            ),
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              "${_galleryIndex + 1}/${slides.length}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: slides.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = slides[i];
                final sel = i == _galleryIndex;
                return GestureDetector(
                  onTap: () => _galleryPage.jumpToPage(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? const Color(0xFF2563EB) : border, width: sel ? 2 : 1),
                      color: isDark ? const Color(0xFF101826) : const Color(0xFFF8FAFC),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: s.isVideo
                        ? const Center(child: Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB), size: 28))
                        : Image.network(s.url!, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(item.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textMain, height: 1.2)),
            ),
            iconAct(
              icon: Icons.compare_arrows_rounded,
              active: inCompare,
              onTap: () async {
                final limit = await app.toggleCompare(listItem);
                if (limit == "limit" && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Не более $kCompareMax товаров для сравнения")),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            iconAct(
              icon: inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              active: inWishlist,
              onTap: () => app.toggleWishlist(listItem),
            ),
          ],
        ),
        if (item.sku.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text("SKU: ${item.sku}", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMuted)),
        ],
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (isVariantProduct)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text("от", style: TextStyle(color: textMuted, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            if (hasSale)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  _fmtRuSmn(shownPrice),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            Text(
              _fmtRuSmn(hasSale ? (shownSalePrice ?? shownPrice) : shownPrice),
              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        KeyedSubtree(
          key: _purchaseBlockKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isVariantProduct) ...[
                const SizedBox(height: 14),
                Text("Выберите вариант", style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(item.variants.length, (i) {
                    final v = item.variants[i];
                    final selectedNow = i == selectedVariantIdx;
                    return ChoiceChip(
                      selected: selectedNow,
                      label: Text(
                        "${v.valueText} • ${(v.salePrice ?? v.price)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: selectedNow ? Colors.white : textMain,
                        ),
                      ),
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: surface,
                      side: BorderSide(color: selectedNow ? const Color(0xFF2563EB) : border),
                      onSelected: (_) {
                        setState(() => selectedVariantIdx = i);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _updatePurchaseVisibility());
                      },
                    );
                  }),
                ),
              ],
              if (!isVariantProduct) ...[
                const SizedBox(height: 16),
                Text("Количество", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textMain)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyBtn(icon: Icons.remove_rounded, onTap: () => setState(() => qty = (qty - 1).clamp(1, 999))),
                    Container(
                      width: 52,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF101826) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Text("$qty", style: TextStyle(fontWeight: FontWeight.w900, color: textMain)),
                    ),
                    _QtyBtn(icon: Icons.add_rounded, onTap: () => setState(() => qty = (qty + 1).clamp(1, 999))),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _buildAddToCartPill(),
            ],
          ),
        ),
        if (isVariantProduct)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              item.variants.length > 1
                  ? "Выберите вариант в списке выше и нажмите «В корзину»."
                  : "Нажмите «В корзину», чтобы добавить этот вариант.",
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w600, fontSize: 12, height: 1.25),
            ),
          ),
        if (item.sellerId != null || (item.sellerStoreName != null && item.sellerStoreName!.isNotEmpty) || (item.sellerUsername != null && item.sellerUsername!.isNotEmpty)) ...[
          const SizedBox(height: 18),
          cardWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Магазин продавца", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textMain)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.sellerAvatar != null && item.sellerAvatar!.isNotEmpty
                          ? Image.network(item.sellerAvatar!, width: 44, height: 44, fit: BoxFit.cover)
                          : Container(
                              width: 44,
                              height: 44,
                              color: const Color(0xFFE2E8F0),
                              child: Icon(Icons.storefront_rounded, color: textMuted),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item.sellerStoreName != null && item.sellerStoreName!.trim().isNotEmpty)
                                ? item.sellerStoreName!.trim()
                                : (item.sellerUsername ?? "Продавец"),
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textMain),
                          ),
                          if (item.sellerStoreAddress != null && item.sellerStoreAddress!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(item.sellerStoreAddress!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textMuted)),
                            ),
                          if (item.sellerId != null)
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              onPressed: () => _openExternalUrl("${_kharidOriginNoTrailingSlash()}/seller/${item.sellerId}"),
                              child: const Text("Все товары продавца →", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        cardWrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Поделиться", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textMain)),
              const SizedBox(height: 12),
              _ProductShareIconRow(
                productUrl: _kharidProductPublicUri(item).toString(),
                productTitle: item.title,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        cardWrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Описание", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textMain)),
              const SizedBox(height: 8),
              Text(item.description.isEmpty ? "—" : item.description, style: TextStyle(color: textMuted, height: 1.4, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (related.isNotEmpty || relatedLoading) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text("Похожие товары", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textMain))),
              TextButton(
                onPressed: item.categorySlug == null || item.categorySlug!.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CategoryProductsScreen(
                              api: widget.api,
                              categorySlug: null,
                              title: item.categoryName ?? "Каталог",
                              categoryTreeSlug: item.categorySlug,
                            ),
                          ),
                        );
                      },
                child: const Text("Все товары →", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (relatedLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            Builder(
              builder: (context) {
                final w = MediaQuery.sizeOf(context).width * 0.42;
                final rowH = w + 108;
                return SizedBox(
                  height: rowH,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: related.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      return SizedBox(
                        width: w,
                        child: _ProductCardMini(api: widget.api, p: related[i], showHit: false, compact: true),
                      );
                    },
                  ),
                );
              },
            ),
        ],
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: _floatingNavBottomInset(context) + _kFixedAddToCartExtraAboveNav,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            offset: _showFixedCta ? Offset.zero : const Offset(0, 0.12),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              opacity: _showFixedCta ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showFixedCta,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    boxShadow: [BoxShadow(color: Color(0x332563EB), blurRadius: 22, offset: Offset(0, 10))],
                  ),
                  child: _buildAddToCartPill(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 26, color: const Color(0xFF334155)),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF101826) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: const Color(0xFF334155))),
      ),
    );
  }
}

void _openKharidSearchBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Поиск",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF0F172A),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 10)),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: "Искать на Kharid.tj…",
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            onSubmitted: (_) => Navigator.of(ctx).pop(),
                          ),
                        ),
                        Container(
                          height: 38,
                          width: 44,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Совет: начните вводить название товара.",
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _openExternalUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Бейджи меню — монанди `site-header.tsx` (0 = пинҳон).
String? _navCountBadge(int count) {
  if (count <= 0) return null;
  return count > 99 ? "99+" : count.toString();
}

void _openKharidMenuSheet(BuildContext context) {
  final app = context.read<AppState>();
  final api = app.api;
  final role = app.me?.role ?? "client";
  bool isDarkMenu = app.isDarkTheme;
  unawaited(app.reloadStoredLists());

  Future<void> openPage(Widget page) async {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> openLink(String url) async {
    Navigator.of(context).pop();
    await _openExternalUrl(url);
  }

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: "menu",
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final media = MediaQuery.of(ctx);
      final panelWidth = min(media.size.width * 0.9, 360.0);
      return ListenableBuilder(
        listenable: app,
        builder: (ctx, _) {
          final cartCount = app.cart.fold<int>(0, (sum, e) => sum + e.qty);
          final compareCount = app.compareList.length;
          final wishlistCount = app.wishlistList.length;
          final cartBadge = _navCountBadge(cartCount);
          final compareBadge = _navCountBadge(compareCount);
          final wishlistBadge = _navCountBadge(wishlistCount);

          return StatefulBuilder(
            builder: (ctx, setInner) {
              final bg = isDarkMenu ? const Color(0xFF061433) : Colors.white;
          final textMain = isDarkMenu ? Colors.white : const Color(0xFF0F172A);
          final textMuted = isDarkMenu ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
          final cardBg = isDarkMenu ? const Color(0xFF0A1632) : const Color(0xFFF8FAFC);
          final border = isDarkMenu ? const Color(0xFF172554) : const Color(0xFFE2E8F0);
          final iconFg = isDarkMenu ? const Color(0xFFBFDBFE) : const Color(0xFF334155);
          final contactLink = isDarkMenu ? const Color(0xFFBFDBFE) : const Color(0xFF2563EB);

          return Align(
            alignment: Alignment.centerLeft,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: Material(
                color: bg,
                child: SizedBox(
                  width: panelWidth,
                  height: media.size.height,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          child: Row(
                            children: [
                              const AppLogo(height: 32),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: Icon(Icons.close_rounded, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: border),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MenuQuickAction(
                                        isDark: isDarkMenu,
                                        icon: Icons.balance_rounded,
                                        label: "Сравн.",
                                        badge: compareBadge,
                                        onTap: () => openPage(CompareScreen(api: api, role: role)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _MenuQuickAction(
                                        isDark: isDarkMenu,
                                        icon: Icons.favorite_border_rounded,
                                        label: "Избр.",
                                        badge: wishlistBadge,
                                        onTap: () => openPage(WishlistScreen(api: api, role: role)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _MenuQuickAction(
                                        isDark: isDarkMenu,
                                        icon: Icons.person_outline_rounded,
                                        label: "Профиль",
                                        onTap: () => openPage(DashboardByRole(api: app.api, role: role)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _MenuQuickAction(
                                        isDark: isDarkMenu,
                                        icon: Icons.shopping_cart_outlined,
                                        label: "Корзина",
                                        badge: cartBadge,
                                        onTap: () => openPage(CartCheckoutTab(api: app.api)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: border),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Тема\nСейчас: ${isDarkMenu ? "dark" : "light"}",
                                          style: TextStyle(
                                            color: textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      _ThemePill(
                                        label: "Светлая",
                                        selected: !isDarkMenu,
                                        isDark: isDarkMenu,
                                        onTap: () async {
                                          setInner(() => isDarkMenu = false);
                                          await app.setThemeDark(false);
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _ThemePill(
                                        label: "Тёмная",
                                        selected: isDarkMenu,
                                        isDark: isDarkMenu,
                                        onTap: () async {
                                          setInner(() => isDarkMenu = true);
                                          await app.setThemeDark(true);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _MenuSectionTitle("ПОКУПКИ", isDark: isDarkMenu),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.grid_view_rounded,
                                  title: "Каталог",
                                  onTap: () => openPage(CategoryProductsScreen(api: app.api, categorySlug: null, title: "Каталог")),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.search_rounded,
                                  title: "Товары",
                                  onTap: () => openPage(CategoryProductsScreen(api: app.api, categorySlug: null, title: "Товары")),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.movie_creation_outlined,
                                  title: "Reels",
                                  onTap: () => openPage(
                                    ReelsScreen(
                                      api: app.api,
                                      onOpenProduct: (c, slug) {
                                        Navigator.of(c).push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ProductScreenV2(api: app.api, slug: slug),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.balance_rounded,
                                  title: "Сравнение",
                                  badge: compareBadge,
                                  onTap: () => openPage(CompareScreen(api: api, role: role)),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.favorite_border_rounded,
                                  title: "Избранное",
                                  badge: wishlistBadge,
                                  onTap: () => openPage(WishlistScreen(api: api, role: role)),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.shopping_cart_outlined,
                                  title: "Корзина",
                                  badge: cartBadge,
                                  onTap: () => openPage(CartCheckoutTab(api: app.api)),
                                ),
                                const SizedBox(height: 14),
                                _MenuSectionTitle("ИНФОРМАЦИЯ", isDark: isDarkMenu),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.info_outline_rounded,
                                  title: "О Kharid.tj",
                                  onTap: () => openPage(const AboutScreen()),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.info_outline_rounded,
                                  title: "О нас",
                                  onTap: () => openPage(const AboutScreen()),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.workspace_premium_outlined,
                                  title: "Бонусная программа",
                                  onTap: () => openPage(const BonusScreen()),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.storefront_outlined,
                                  title: "Стать продавцом",
                                  onTap: () => openPage(const BecomeSellerScreen()),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.contact_phone_outlined,
                                  title: "Контакты",
                                  onTap: () => openLink("https://kharid.tj/contacts"),
                                ),
                                const SizedBox(height: 14),
                                _MenuSectionTitle("ПОДДЕРЖКА", isDark: isDarkMenu),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.help_outline_rounded,
                                  title: "Центр помощи",
                                  onTap: () => openLink("https://kharid.tj/help"),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.question_answer_outlined,
                                  title: "Вопрос / ответ",
                                  onTap: () => openLink("https://t.me/kharid24tj"),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.feedback_outlined,
                                  title: "Обратная связь",
                                  onTap: () => openLink("https://kharid.tj/feedback"),
                                ),
                                _MenuTile(
                                  isDark: isDarkMenu,
                                  icon: Icons.credit_card_outlined,
                                  title: "Способ оплаты",
                                  onTap: () => openLink("https://kharid.tj/payment"),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: border),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "КОНТАКТЫ",
                                        style: TextStyle(color: textMuted, fontWeight: FontWeight.w900, fontSize: 12),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () => openLink("tel:+992939888883"),
                                        child: Row(
                                          children: [
                                            Icon(Icons.phone_rounded, color: iconFg, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              "+992 93 988 88 83",
                                              style: TextStyle(color: textMain, fontWeight: FontWeight.w800, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () => openLink("https://kharid.tj/contacts"),
                                        child: Text(
                                          "Все контакты →",
                                          style: TextStyle(color: contactLink, fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
            },
          );
        },
      );
    },
  );
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle(this.text, {required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A1632) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF172554) : const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF13254C) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF334155), size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuQuickAction extends StatelessWidget {
  const _MenuQuickAction({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final bool isDark;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A1632) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF172554) : const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF334155), size: 18),
                  if (badge != null)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: isDark ? const Color(0xFF061433) : Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badge!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9, height: 1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
              : (isDark ? const Color(0xFF111827) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF1F2937) : const Color(0xFFCBD5E1))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    final header = KharidSiteHeader(
      onMenuPressed: () => _openKharidMenuSheet(context),
      showBackWhenCanPop: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {},
            iconSize: 26,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.notifications_none_rounded, color: iconColor),
            tooltip: "Уведомления",
          ),
          IconButton(
            onPressed: () => _openKharidSearchBottomSheet(context),
            iconSize: 26,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.search_rounded, color: iconColor),
            tooltip: "Поиск",
          ),
        ],
      ),
    );
    return SizedBox(width: double.infinity, height: header.preferredSize.height, child: header);
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.api});
  final ApiClient api;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  final controller = PageController();
  int page = 0;
  bool loading = true;
  List<HomeBannerItem> slides = const [];
  Timer? _autoTimer;

  List<HomeBannerItem> get _displaySlides =>
      slides.isNotEmpty ? slides : HomeBannerItem.fallbackSlides;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.homeBanners();
      if (!mounted) return;
      setState(() {
        slides = list;
        loading = false;
      });
      _restartAutoPlay();
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      _restartAutoPlay();
    }
  }

  void _restartAutoPlay() {
    _autoTimer?.cancel();
    final count = _displaySlides.length;
    if (count <= 1) return;
    _autoTimer = Timer.periodic(const Duration(milliseconds: 6500), (_) {
      if (!mounted || !controller.hasClients) return;
      final next = (page + 1) % count;
      controller.animateToPage(next, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _goRelative(int delta) {
    final count = _displaySlides.length;
    if (count <= 1) return;
    final next = (page + delta + count) % count;
    controller.animateToPage(next, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _goTo(int index) {
    final count = _displaySlides.length;
    if (index < 0 || index >= count) return;
    controller.animateToPage(index, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _openBanner(BuildContext context, HomeBannerItem banner) {
    final slug = banner.productSlug?.trim();
    if (slug != null && slug.isNotEmpty) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: widget.api, slug: slug)),
      );
      return;
    }
    final link = banner.linkUrl.trim();
    if (link.isEmpty) return;
    final slugFromPath = RegExp(r"/products/([^/?#]+)").firstMatch(link)?.group(1);
    if (slugFromPath != null && slugFromPath.isNotEmpty) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: widget.api, slug: slugFromPath)),
      );
      return;
    }
  }

  Widget _dot(bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 6,
        width: active ? 18 : 6,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _bannerImage(String? imageUrl) {
    const w = 108.0;
    const h = 168.0;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            imageUrl,
            width: w,
            height: h,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _bannerImagePlaceholder(w, h),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return ColoredBox(
                color: Colors.white.withValues(alpha: 0.12),
                child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))),
              );
            },
          ),
        ),
      );
    }
    return _bannerImagePlaceholder(w, h);
  }

  Widget _bannerImagePlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: SizedBox(
          height: 228,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    final display = _displaySlides;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: SizedBox(
        height: 228,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x1A0F172A), blurRadius: 22, offset: Offset(0, 14)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: display.length,
                  physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                  allowImplicitScrolling: true,
                  onPageChanged: (i) {
                    setState(() => page = i);
                    _restartAutoPlay();
                  },
                  itemBuilder: (context, i) {
                    final s = display[i];
                    final grad = HomeBannerItem.gradientColors(s.gradient);
                    final imageUrl = s.image?.trim();
                    final hasLink = (s.productSlug?.trim().isNotEmpty ?? false) || s.linkUrl.trim().isNotEmpty;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: grad,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.08),
                                    Colors.black.withValues(alpha: 0.18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        s.badgeText.toUpperCase(),
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        s.title,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        s.subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: hasLink ? () => _openBanner(context, s) : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF0F172A),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                        ),
                                        child: const Text(
                                          "Смотреть",
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _bannerImage(imageUrl),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                if (display.length > 1) ...[
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _CircleBtn(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _goRelative(-1),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _CircleBtn(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _goRelative(1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: Row(
                      children: List.generate(display.length, (i) => _dot(i == page, () => _goTo(i))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Color(0x160F172A), blurRadius: 10, offset: Offset(0, 6))],
        ),
        child: Icon(icon, color: const Color(0xFF0F172A)),
      ),
    );
  }
}

class _QuickPills extends StatelessWidget {
  const _QuickPills();

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    Widget pill(String text, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: Color(0x202563EB), blurRadius: 10, offset: Offset(0, 6))],
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          pill("О нас", () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()))),
          pill("Бонусная программа", () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BonusScreen()))),
          pill("Стать продавцом", () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BecomeSellerScreen()))),
          pill("Вопрос / ответ", () => _open("https://t.me/kharid24tj")),
        ],
      ),
    );
  }
}

class _CategoryPromoSection extends StatefulWidget {
  const _CategoryPromoSection({required this.api});
  final ApiClient api;

  @override
  State<_CategoryPromoSection> createState() => _CategoryPromoSectionState();
}

class _CategoryPromoSectionState extends State<_CategoryPromoSection> {
  bool loading = true;
  String? error;
  List<CategoryLite> categories = const [];

  static const List<String> _subtitles = [
    "Новинки и акции — не пропустите",
    "Всё для готовки в одном месте",
    "Развивайте детей с удовольствием",
    "Скидки на сезонные коллекции",
    "Выгодные цены каждый день",
  ];

  static const List<List<Color>> _gradients = [
    [Color(0xFF38BDF8), Color(0xFF0F172A)],
    [Color(0xFF8B5CF6), Color(0xFF312E81)],
    [Color(0xFF10B981), Color(0xFF0F172A)],
    [Color(0xFF2563EB), Color(0xFF1E1B4B)],
    [Color(0xFFEC4899), Color(0xFF4C1D95)],
    [Color(0xFF14B8A6), Color(0xFF134E4A)],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await widget.api.categories();
      final rnd = Random();
      final shuffled = List<CategoryLite>.from(list)..shuffle(rnd);
      final int n;
      if (shuffled.isEmpty) {
        n = 0;
      } else if (shuffled.length <= 3) {
        n = shuffled.length;
      } else {
        n = min(shuffled.length, 3 + rnd.nextInt(2));
      }
      if (mounted) {
        setState(() => categories = shuffled.sublist(0, n));
      }
    } catch (e) {
      if (mounted) setState(() => error = "$e");
    }
    if (mounted) setState(() => loading = false);
  }

  void _openCategory(BuildContext context, CategoryLite c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryProductsScreen(api: widget.api, categorySlug: c.slug, title: c.name),
      ),
    );
  }

  void _openAllOffers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryProductsScreen(api: widget.api, categorySlug: null, title: "Каталог"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Наши любимые предложения этой недели",
            style: TextStyle(
              fontSize: MediaQuery.sizeOf(context).width < 360 ? 17 : 19,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _openAllOffers(context),
            borderRadius: BorderRadius.circular(4),
            child: const Text(
              "Все предложения",
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (error != null)
            Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700))
          else if (categories.isEmpty)
            const Text("Категории скоро появятся.", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600))
          else
            ...List.generate(categories.length, (i) {
              final c = categories[i];
              final colors = _gradients[i % _gradients.length];
              final subtitle = _subtitles[i % _subtitles.length];
              final tn = c.name.trim();
              final wm = tn.isEmpty ? "•" : (tn.length >= 2 ? tn.substring(0, 2) : tn);
              return Padding(
                padding: EdgeInsets.only(bottom: i == categories.length - 1 ? 0 : 12),
                child: _CategoryPromoCard(
                  title: c.name,
                  subtitle: subtitle,
                  gradientColors: colors,
                  watermark: wm.toUpperCase(),
                  onTap: () => _openCategory(context, c),
                  onBuyTap: () => _openCategory(context, c),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CategoryPromoCard extends StatelessWidget {
  const _CategoryPromoCard({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.watermark,
    required this.onTap,
    required this.onBuyTap,
  });

  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final String watermark;
  final VoidCallback onTap;
  final VoidCallback onBuyTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
            boxShadow: const [BoxShadow(color: Color(0x180F172A), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  right: -24,
                  top: -24,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: -16,
                  child: Text(
                    watermark,
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: onBuyTap,
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              child: Text(
                                "Купить сейчас",
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Список товаров: весь каталог, фильтр по `categorySlug` ё дарахт бо `categoryTreeSlug`.
class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.api,
    required this.categorySlug,
    required this.title,
    this.categoryTreeSlug,
  });

  final ApiClient api;
  final String? categorySlug;
  /// Агар пур бошад, `category_tree` дар API — товарҳои ин категория ва ҳамаи зердастаҳо.
  final String? categoryTreeSlug;
  final String title;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  bool loading = true;
  String? error;
  List<ProductListItem> products = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.api.products(
        categorySlug: widget.categoryTreeSlug != null && widget.categoryTreeSlug!.isNotEmpty ? null : widget.categorySlug,
        categoryTreeSlug: widget.categoryTreeSlug,
      );
      products = page.results;
    } catch (e) {
      error = "$e";
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final onTile = Theme.of(context).colorScheme.onSurface;
    final bottomPad = 20.0 + _floatingNavBottomInset(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: widget.title),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: TextStyle(color: onTile.withValues(alpha: 0.85))))
              : products.isEmpty
                  ? Center(
                      child: Text(
                        "В этой категории пока нет товаров.",
                        style: TextStyle(color: onTile.withValues(alpha: 0.75)),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(14, 12, 14, bottomPad),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.51,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _ProductCardMini(api: api, p: products[i], showHit: false),
                              childCount: products.length,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

const String _kSiteOrigin = "https://kharid.tj";

class _FooterLink {
  const _FooterLink(this.label, this.href);
  final String label;
  final String href;
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter({required this.onScrollToTop});
  final VoidCallback onScrollToTop;

  static const _learn = [
    _FooterLink("О Kharid.tj", "/about"),
    _FooterLink("Партнёры", "/partners"),
  ];
  static const _support = [
    _FooterLink("Центр помощи", "/help"),
    _FooterLink("Вопрос / ответ", "/faq"),
    _FooterLink("Обратная связь", "/feedback"),
    _FooterLink("Способ оплаты", "/payment"),
  ];
  static const _orders = [
    _FooterLink("Доставка & отправка", "/delivery"),
    _FooterLink("Возврат & обмен", "/returns"),
    _FooterLink("Гарантия лучшей цены", "/best-price"),
  ];

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLink(BuildContext context, _FooterLink link) async {
    switch (link.href) {
      case "/about":
        if (!context.mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
      case "/faq":
        await _openUrl("https://t.me/kharid24tj");
      default:
        await _openUrl("$_kSiteOrigin${link.href}");
    }
  }

  Widget _expansion(String title, List<_FooterLink> links, BuildContext context, {required bool isDark}) {
    final tileStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
    );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
        iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        collapsedIconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        title: Text(title, style: tileStyle),
        children: links
            .map(
              (e) => ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  e.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                onTap: () => _openLink(context, e),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainText = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final mutedText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final borderColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0);
    final year = DateTime.now().year;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF061433) : Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(height: 40),
          const SizedBox(height: 10),
          Text(
            "Лучшие покупки в Таджикистане: быстро и удобно.",
            style: TextStyle(fontSize: 14, height: 1.45, color: mutedText, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 22),
          Text("Контакты", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: mainText)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _openUrl("tel:+992939888883"),
            child: Row(
              children: [
                const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text("+992 93 988 88 83", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: mainText)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openUrl("mailto:info@kharid.tj"),
            child: Row(
              children: [
                const Icon(Icons.mail_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text("info@kharid.tj", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: mainText)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _IconCircle(isDark: isDark, icon: Icons.facebook_rounded, onTap: () => _openUrl("https://facebook.com")),
              _IconCircle(isDark: isDark, icon: Icons.camera_alt_rounded, onTap: () => _openUrl("https://instagram.com")),
              _IconCircle(isDark: isDark, icon: Icons.send_rounded, onTap: () => _openUrl("https://t.me/kharid24tj")),
              _IconCircle(isDark: isDark, icon: Icons.chat_rounded, onTap: () => _openUrl("https://wa.me")),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1A3A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _expansion("Узнайте нас лучше", _learn, context, isDark: isDark),
                _expansion("Служба поддержки", _support, context, isDark: isDark),
                _expansion("Заказы и возвраты", _orders, context, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 10,
            children: [
              InkWell(
                onTap: () => _openUrl("$_kSiteOrigin/privacy"),
                child: Text(
                  "Правила конфиденциальности",
                  style: TextStyle(fontSize: 14, color: mutedText, fontWeight: FontWeight.w600),
                ),
              ),
              InkWell(
                onTap: () => _openUrl("$_kSiteOrigin/terms"),
                child: Text(
                  "Правила пользования",
                  style: TextStyle(fontSize: 14, color: mutedText, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Image.asset(
              "assets/carts.png",
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _paymentFallbackRow(isDark: isDark),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "Copyright © $year Kharid.tj. Все права защищены.",
                  style: TextStyle(fontSize: 12, color: mutedText, height: 1.35),
                ),
              ),
              Material(
                color: isDark ? const Color(0xFF0B1A3A) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(999),
                elevation: 2,
                shadowColor: isDark ? const Color(0x22060B12) : const Color(0x330F172A),
                child: InkWell(
                  onTap: onScrollToTop,
                  borderRadius: BorderRadius.circular(999),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _paymentFallbackRow({required bool isDark}) {
  Widget chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1A3A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        ),
      ),
    );
  }

  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [chip("Alif"), chip("Eskhata"), chip("VISA")],
  );
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.onTap, required this.isDark});
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
          color: isDark ? const Color(0xFF0B1A3A) : const Color(0xFFF8FAFC),
        ),
        child: Icon(icon, size: 18, color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF334155)),
      ),
    );
  }
}

const List<List<Color>> _kCatalogGradients = [
  [Color(0xFFEC4899), Color(0xFF7C3AED)],
  [Color(0xFF22C55E), Color(0xFFEAB308)],
  [Color(0xFF06B6D4), Color(0xFF2563EB)],
  [Color(0xFFF97316), Color(0xFFEA580C)],
  [Color(0xFFA855F7), Color(0xFF1E3A8A)],
  [Color(0xFF14B8A6), Color(0xFF14532D)],
];

String _categoryInitials(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return "?";
  String firstGrapheme(String x) {
    if (x.isEmpty) return "";
    return String.fromCharCode(x.runes.first);
  }

  final parts = s.split(RegExp(r"\s+"));
  if (parts.length >= 2) {
    return "${firstGrapheme(parts[0])}${firstGrapheme(parts[1])}".toUpperCase();
  }
  if (s.length >= 2) return s.substring(0, 2).toUpperCase();
  return s.toUpperCase();
}

List<Color> _gradientForCatalogIndex(int i) => _kCatalogGradients[i % _kCatalogGradients.length];

class _CatalogPageChrome extends StatelessWidget {
  const _CatalogPageChrome();

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    final header = KharidSiteHeader(
      onMenuPressed: () => _openKharidMenuSheet(context),
      showBackWhenCanPop: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {},
            iconSize: 26,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.notifications_none_rounded, color: iconColor),
          ),
          IconButton(
            onPressed: () => _openKharidSearchBottomSheet(context),
            iconSize: 26,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.search_rounded, color: iconColor),
            tooltip: "Поиск",
          ),
        ],
      ),
    );
    return SizedBox(width: double.infinity, height: header.preferredSize.height, child: header);
  }
}

class _CatalogCategoryGridCard extends StatelessWidget {
  const _CatalogCategoryGridCard({
    required this.name,
    required this.initials,
    required this.colors,
    required this.onTap,
    this.imageUrl,
  });

  final String name;
  final String initials;
  final List<Color> colors;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final inner = colors.first;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            boxShadow: const [BoxShadow(color: Color(0x120F172A), blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          inner.withValues(alpha: 0.92),
                          Color.lerp(inner, colors.last, 0.55)!,
                        ],
                      ),
                    ),
                  ),
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.35,
                        child: Image.network(imageUrl!, fit: BoxFit.cover),
                      ),
                    ),
                  Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.95),
                        shadows: const [Shadow(color: Color(0x40000000), blurRadius: 8)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(17),
                          bottomRight: Radius.circular(17),
                        ),
                      ),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SubcategoryListScreen extends StatefulWidget {
  const SubcategoryListScreen({
    super.key,
    required this.api,
    required this.parent,
    required this.allCategories,
  });

  final ApiClient api;
  final CategoryLite parent;
  final List<CategoryLite> allCategories;

  @override
  State<SubcategoryListScreen> createState() => _SubcategoryListScreenState();
}

class _SubcategoryListScreenState extends State<SubcategoryListScreen> {
  String _query = "";

  List<CategoryLite> get _subs {
    bool keepName(CategoryLite c) => c.name.trim().toLowerCase() != "все товары";
    final list = widget.allCategories.where((c) => c.parentId == widget.parent.id).where(keepName).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (_query.trim().isEmpty) return list;
    final q = _query.trim().toLowerCase();
    return list.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 24;
    final subs = _subs;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF061433) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final searchFill = isDark ? const Color(0xFF0B1A3A) : Colors.white;
    final searchBorder = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0);
    final searchIconHint = isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);
    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CatalogPageChrome(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF0B1A3A) : const Color(0xFFF1F5F9),
                    foregroundColor: titleColor,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.parent.name,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor, height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Выберите подкатегорию",
                        style: TextStyle(fontSize: 13, color: subtitleColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              cursorColor: const Color(0xFF2563EB),
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Поиск категории...",
                hintStyle: TextStyle(color: searchIconHint, fontWeight: FontWeight.w600, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: searchIconHint),
                filled: true,
                fillColor: searchFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: searchBorder)),
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: searchBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: subs.isEmpty
                ? Center(
                    child: Text(
                      "Нет подкатегорий",
                      style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(14, 4, 14, bottomPad),
                    itemCount: subs.length,
                    itemBuilder: (context, index) {
                      final c = subs[index];
                      final gi = widget.allCategories.indexWhere((x) => x.id == c.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SubcategoryListRow(
                          title: c.name,
                          productCount: c.productCount,
                          colors: _gradientForCatalogIndex(gi >= 0 ? gi : index),
                          initials: _categoryInitials(c.name),
                          imageUrl: c.image,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CategoryProductsScreen(api: widget.api, categorySlug: c.slug, title: c.name),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubcategoryListRow extends StatelessWidget {
  const _SubcategoryListRow({
    required this.title,
    required this.productCount,
    required this.colors,
    required this.initials,
    required this.onTap,
    this.imageUrl,
  });

  final String title;
  final int productCount;
  final List<Color> colors;
  final String initials;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF0B1A3A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0);
    final shadowCol = isDark ? const Color(0x44060B12) : const Color(0x080F172A);
    final titleTxt = isDark ? Colors.white : const Color(0xFF0F172A);
    final countTxt = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final chevronCol = isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1);

    return Material(
      color: tileBg,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
            boxShadow: [BoxShadow(color: shadowCol, blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                        ),
                      ),
                      if (imageUrl != null && imageUrl!.isNotEmpty)
                        Opacity(
                          opacity: 0.4,
                          child: Image.network(imageUrl!, fit: BoxFit.cover),
                        ),
                      Center(
                        child: Text(
                          initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: titleTxt),
                ),
              ),
              Text(
                "$productCount шт",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: countTxt),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: chevronCol, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key, required this.api});
  final ApiClient api;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  bool loading = true;
  String? error;
  List<CategoryLite> allCategories = const [];
  String _categoryQuery = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await widget.api.categories();
      if (mounted) setState(() => allCategories = list);
    } catch (e) {
      if (mounted) setState(() => error = "$e");
    }
    if (mounted) setState(() => loading = false);
  }

  void _openCategory(BuildContext context, CategoryLite c) {
    final kids = allCategories.where((x) => x.parentId == c.id).toList();
    if (kids.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubcategoryListScreen(api: widget.api, parent: c, allCategories: allCategories),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CategoryProductsScreen(api: widget.api, categorySlug: c.slug, title: c.name),
        ),
      );
    }
  }

  /// Танҳо категорияҳои асосӣ (родительские, `parent_id == null`).
  List<CategoryLite> get _categoriesForGrid {
    final roots = allCategories.where((c) => c.isRoot).toList()..sort((a, b) => a.name.compareTo(b.name));
    if (_categoryQuery.trim().isEmpty) return roots;
    final q = _categoryQuery.trim().toLowerCase();
    return roots.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = _floatingNavBottomInset(context);
    final categories = _categoriesForGrid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF061433) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final searchFill = isDark ? const Color(0xFF0B1A3A) : Colors.white;
    final searchBorder = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: pageBg,
      body: loading
          ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : null))
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Color(0xFFEF4444))))
              : CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: _CatalogPageChrome()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Каталог",
                                    style:
                                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: titleColor, height: 1.1),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Выберите категорию",
                                    style: TextStyle(fontSize: 14, color: subtitleColor, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CategoryProductsScreen(api: widget.api, categorySlug: null, title: "Каталог"),
                                  ),
                                );
                              },
                              child: const Text("Все товары", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: TextField(
                          onChanged: (v) => setState(() => _categoryQuery = v),
                          cursorColor: const Color(0xFF2563EB),
                          style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Поиск категории...",
                            hintStyle: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: subtitleColor),
                            filled: true,
                            fillColor: searchFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: searchBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: searchBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (categories.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              "Категории не найдены",
                              style: TextStyle(color: subtitleColor),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPad),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final c = categories[i];
                              final gi = allCategories.indexWhere((x) => x.id == c.id);
                              return _CatalogCategoryGridCard(
                                name: c.name,
                                initials: _categoryInitials(c.name),
                                colors: _gradientForCatalogIndex(gi >= 0 ? gi : i),
                                imageUrl: c.image,
                                onTap: () => _openCategory(context, c),
                              );
                            },
                            childCount: categories.length,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.isAuthenticated) {
      return const Center(child: Text("Login кунед то dashboard бинед"));
    }
    final role = app.me?.role ?? "client";
    return DashboardByRole(api: api, role: role);
  }
}

class DashboardByRole extends StatelessWidget {
  const DashboardByRole({super.key, required this.api, required this.role});
  final ApiClient api;
  final String role;

  @override
  Widget build(BuildContext context) {
    final items = _menuByRole(role);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Dashboard: $role", showBackWhenCanPop: false),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) => _DarkCard(
          child: ListTile(
            title: Text(items[i].title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, AccountRouteScreen(api: api, role: role, route: items[i])),
          ),
        ),
      ),
    );
  }

  List<AccountRouteItem> _menuByRole(String r) {
    if (r == "seller") {
      return const [
        AccountRouteItem("/account/seller/products", "Мои товары"),
        AccountRouteItem("/account/seller/add-product", "Добавить товар"),
        AccountRouteItem("/account/seller/orders", "Заказы"),
        AccountRouteItem("/account/seller/analytics", "Аналитика"),
        AccountRouteItem("/account/seller/wishlist", "Мои Избранное"),
        AccountRouteItem("/account/seller/compare", "Сравнение"),
        AccountRouteItem("/account/seller/earnings", "История заработка"),
        AccountRouteItem("/account/seller/referrals", "Мои реферали"),
        AccountRouteItem("/account/seller/settings", "Настройка"),
      ];
    }
    if (r == "courier") {
      return const [
        AccountRouteItem("/account/courier/deliveries", "Мои доставки"),
        AccountRouteItem("/account/courier/wishlist", "Мои Избранное"),
        AccountRouteItem("/account/courier/compare", "Сравнение"),
        AccountRouteItem("/account/courier/earnings", "История заработка"),
        AccountRouteItem("/account/courier/referrals", "Мои реферали"),
        AccountRouteItem("/account/courier/settings", "Настройка"),
      ];
    }
    if (r == "partner") {
      return const [
        AccountRouteItem("/account/partner/orders", "Мои заказы"),
        AccountRouteItem("/account/partner/wishlist", "Мои Избранное"),
        AccountRouteItem("/account/partner/compare", "Сравнение"),
        AccountRouteItem("/account/partner/earnings", "История заработка"),
        AccountRouteItem("/account/partner/referrals", "Мои реферали"),
        AccountRouteItem("/account/partner/settings", "Настройка"),
      ];
    }
    return const [
      AccountRouteItem("/account/client/orders", "Мои заказы"),
      AccountRouteItem("/account/client/wishlist", "Мои Избранное"),
      AccountRouteItem("/account/client/compare", "Сравнение"),
      AccountRouteItem("/account/client/earnings", "История заработка"),
      AccountRouteItem("/account/client/referrals", "Мои реферали"),
      AccountRouteItem("/account/client/settings", "Настройка"),
    ];
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

void _pushSellerMyProducts(ApiClient api, BuildContext ctx, {bool rootNavigator = false}) {
  Navigator.of(ctx, rootNavigator: rootNavigator).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AccountRouteScreen(
        api: api,
        role: "seller",
        route: const AccountRouteItem("/account/seller/products", "Мои товары"),
      ),
    ),
  );
}

void _pushCourierDeliveries(ApiClient api, BuildContext ctx, {bool rootNavigator = false}) {
  Navigator.of(ctx, rootNavigator: rootNavigator).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AccountRouteScreen(
        api: api,
        role: "courier",
        route: const AccountRouteItem("/account/courier/deliveries", "Мои доставки"),
      ),
    ),
  );
}

void _pushClientOrders(ApiClient api, BuildContext ctx, {bool rootNavigator = false}) {
  Navigator.of(ctx, rootNavigator: rootNavigator).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AccountRouteScreen(
        api: api,
        role: "client",
        route: const AccountRouteItem("/account/client/orders", "Мои заказы"),
      ),
    ),
  );
}

void _pushPartnerOrders(ApiClient api, BuildContext ctx, {bool rootNavigator = false}) {
  Navigator.of(ctx, rootNavigator: rootNavigator).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AccountRouteScreen(
        api: api,
        role: "partner",
        route: const AccountRouteItem("/account/partner/orders", "Мои заказы"),
      ),
    ),
  );
}

class AccountRouteScreen extends StatelessWidget {
  const AccountRouteScreen({super.key, required this.api, required this.role, required this.route});

  final ApiClient api;
  final String role;
  final AccountRouteItem route;

  @override
  Widget build(BuildContext context) {
    final p = route.path;
    if (p.endsWith("/orders")) {
      if (role == "seller") {
        return SellerOrdersScreen(api: api);
      }
      if (role == "client" || role == "partner") {
        return ClientOrdersScreen(api: api, role: role);
      }
      return OrdersRoleScreen(api: api, title: route.title);
    }
    if (p.endsWith("/deliveries")) return CourierDeliveriesScreen(api: api);
    if (p.endsWith("/products")) return SellerProductsScreen(api: api);
    if (p.endsWith("/add-product")) {
      return FullSellerAddProductScreen(
        api: api,
        onSellerAccountNav: (path, title) {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => AccountRouteScreen(api: api, role: role, route: AccountRouteItem(path, title)),
            ),
          );
        },
        onProductCreatedGoToMyProducts: (ctx) {
          Navigator.of(ctx).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AccountRouteScreen(api: api, role: role, route: const AccountRouteItem("/account/seller/products", "Мои товары")),
            ),
          );
        },
      );
    }
    if (p.endsWith("/analytics")) return SellerAnalyticsScreen(api: api);
    if (p.endsWith("/wishlist")) return WishlistScreen(api: api, role: role);
    if (p.endsWith("/compare")) return CompareScreen(api: api, role: role);
    if (p.endsWith("/earnings")) return EarningsHistoryScreen(api: api, role: role);
    if (p.endsWith("/referrals")) return PartnerReferralsScreen(api: api, role: role);
    if (p.endsWith("/settings")) return AccountSettingsScreen(api: api, role: role);
    if (p.contains("/balance")) return BalanceHubScreen(api: api);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: route.title),
      body: const Center(child: Text("Not implemented yet")),
    );
  }
}

class ClientOrdersScreen extends StatelessWidget {
  const ClientOrdersScreen({super.key, required this.api, required this.role, this.isProfileRoot = false, this.bottomPadding = 0});

  final ApiClient api;
  final String role;
  final bool isProfileRoot;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return AccountCabinetShell(
      api: api,
      role: role,
      activePath: "/account/$role/orders",
      pageTitle: "Мои заказы",
      isProfileRoot: isProfileRoot,
      body: ClientOrdersBody(
        api: api,
        bottomPadding: bottomPadding,
        onGoShopping: () => app.requestSwitchTab(0),
        onOpenProduct: (slug) {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: api, slug: slug)),
          );
        },
      ),
    );
  }
}

class EarningsHistoryScreen extends StatelessWidget {
  const EarningsHistoryScreen({super.key, required this.api, required this.role, this.isProfileRoot = false});

  final ApiClient api;
  final String role;
  final bool isProfileRoot;

  @override
  Widget build(BuildContext context) {
    return AccountCabinetShell(
      api: api,
      role: role,
      activePath: "/account/$role/earnings",
      pageTitle: "История заработка",
      isProfileRoot: isProfileRoot,
      body: EarningsHistoryBody(api: api),
    );
  }
}

class PartnerReferralsScreen extends StatelessWidget {
  const PartnerReferralsScreen({super.key, required this.api, required this.role, this.isProfileRoot = false});

  final ApiClient api;
  final String role;
  final bool isProfileRoot;

  @override
  Widget build(BuildContext context) {
    return AccountCabinetShell(
      api: api,
      role: role,
      activePath: "/account/$role/referrals",
      pageTitle: "Мои реферали",
      isProfileRoot: isProfileRoot,
      body: ReferralsBody(api: api),
    );
  }
}

class OrdersRoleScreen extends StatelessWidget {
  const OrdersRoleScreen({super.key, required this.api, this.title = "Orders"});
  final ApiClient api;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: title),
      body: const Center(child: Text("Not implemented")),
    );
  }
}

class LiveTrackingMapScreen extends StatefulWidget {
  const LiveTrackingMapScreen({super.key, required this.api, required this.orderId});
  final ApiClient api;
  final int orderId;

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  OrderModel? order;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AppState>().accessToken!;
    try {
      final o = await widget.api.orderById(token, widget.orderId);
      if (mounted) setState(() => order = o);
    } catch (_) {}
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(order?.courier?.latitude ?? "");
    final lon = double.tryParse(order?.courier?.longitude ?? "");
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Live tracking #${widget.orderId}"),
      body: (lat == null || lon == null)
          ? const Center(child: Text("Courier coordinates unavailable"))
          : FlutterMap(
              options: MapOptions(initialCenter: LatLng(lat, lon), initialZoom: 14),
              children: [
                TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lon),
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.local_shipping, color: Colors.blue, size: 34),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class CourierDeliveriesScreen extends StatelessWidget {
  const CourierDeliveriesScreen({super.key, required this.api, this.isProfileRoot = false, this.bottomPadding = 0});

  final ApiClient api;
  final bool isProfileRoot;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return AccountCabinetShell(
      api: api,
      role: "courier",
      activePath: "/account/courier/deliveries",
      pageTitle: "Доставки",
      isProfileRoot: isProfileRoot,
      body: CourierDeliveriesBody(
        api: api,
        bottomPadding: bottomPadding,
        onOpenSettings: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => AccountRouteScreen(
                api: api,
                role: "courier",
                route: const AccountRouteItem("/account/courier/settings", "Настройка"),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _fmtPriceRuSmn(String? raw) {
  if (raw == null || raw.trim().isEmpty) return "—";
  final n = double.tryParse(raw.replaceAll(RegExp(r"\s"), "").replaceAll(",", "."));
  if (n == null) return raw;
  final neg = n < 0;
  final v = neg ? -n : n;
  final s = v.toStringAsFixed(10).replaceFirst(RegExp(r"\.?0+$"), "");
  String intPart;
  String? decPart;
  final dot = s.indexOf(".");
  if (dot < 0) {
    intPart = s;
    decPart = null;
  } else {
    intPart = s.substring(0, dot);
    decPart = s.substring(dot + 1);
  }
  final buf = StringBuffer();
  if (neg) buf.write("-");
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(" ");
    buf.write(intPart[i]);
  }
  if (decPart != null && decPart.isNotEmpty) {
    buf.write(",");
    buf.write(decPart);
  }
  return buf.toString();
}

String _sellerStockUnitLabel(String u) {
  switch (u) {
    case "kg":
      return "кг";
    case "l":
      return "л";
    case "m":
      return "м";
    case "pcs":
    default:
      return "шт";
  }
}

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key, required this.api, this.isProfileRoot = false, this.bottomPadding = 0});
  final ApiClient api;
  /// Вкладка «Профиль» для продавца — без кнопки «назад».
  final bool isProfileRoot;
  final double bottomPadding;

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _searchDebounce;
  String _status = "all";
  String _ptype = "all";
  bool _mlmEnabled = true;
  List<ProductListItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(_onSearchChanged);
    _loadMlm();
    _loadProducts();
  }

  Future<void> _loadMlm() async {
    try {
      final d = await widget.api.siteSettings();
      final m = d["mlm_enabled"];
      if (mounted) setState(() => _mlmEnabled = m is bool ? m : true);
    } catch (_) {}
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _loadProducts();
    });
  }

  Future<void> _loadProducts() async {
    final token = context.read<AppState>().accessToken;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.myProducts(
        token,
        search: _searchCtl.text,
        status: _status,
        type: _ptype,
      );
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = "$e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.removeListener(_onSearchChanged);
    _searchCtl.dispose();
    super.dispose();
  }

  void _openSellerRoute(BuildContext context, AccountRouteItem route, {VoidCallback? after}) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => AccountRouteScreen(api: widget.api, role: "seller", route: route),
          ),
        )
        .then((_) => after?.call());
  }

  void _openEditInApp(BuildContext context, String slug) {
    if (slug.trim().isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FullSellerEditProductScreen(api: widget.api, productSlug: slug.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    if (me == null || me.role != "seller") {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _kharidChromeAppBar(context, subtitle: "Мои товары"),
        body: const Center(child: Text("Доступно только продавцам")),
      );
    }

    final nav = cabinetNavFiltered(me, _mlmEnabled);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final fullName = "${me.user.firstName} ${me.user.lastName}".trim();
    final sidebarTitle = fullName.isNotEmpty
        ? fullName
        : ((me.storeName ?? "").trim().isNotEmpty ? me.storeName!.trim() : "Профиль");
    final balanceRoute = AccountRouteItem("/account/seller/balance", "Баланс");

    Widget sellerSidebar({VoidCallback? afterPick}) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withValues(alpha: 0.85)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sidebarTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
              const SizedBox(height: 4),
              Text("+${me.phone}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kCabinetBrand.withValues(alpha: isDark ? 0.45 : 0.35)),
                  color: isDark ? const Color(0x331D4ED8) : const Color(0xFFEFF6FF),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Баланс", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kCabinetBrand.withValues(alpha: 0.85))),
                      const SizedBox(height: 2),
                      Text(
                        "${me.balance.isEmpty ? "0.00" : me.balance} смн",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          afterPick?.call();
                          _openSellerRoute(context, balanceRoute);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _kCabinetBrand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Пополнить / Вывод", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final it in nav)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton(
                    onPressed: () {
                      afterPick?.call();
                      if (it.path.endsWith("/products")) {
                        Navigator.of(context).maybePop();
                        return;
                      }
                      _openSellerRoute(context, it);
                    },
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: titleColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(it.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              TextButton(
                onPressed: () {
                  afterPick?.call();
                  app.logout();
                },
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Выйти", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    Widget mobileTop(BuildContext scaffoldCtx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(backgroundColor: cardBg, foregroundColor: titleColor),
              onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Мои товары", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                    Text("Профиль", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openSellerRoute(context, balanceRoute),
              style: TextButton.styleFrom(
                backgroundColor: _kCabinetBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text("${me.balance.isEmpty ? "0.00" : me.balance} смн", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    Widget navPills() {
      return SizedBox(
        height: 46,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          scrollDirection: Axis.horizontal,
          itemCount: nav.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final it = nav[i];
            final active = it.path.endsWith("/products");
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                if (active) return;
                _openSellerRoute(context, it);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _kCabinetBrand : cardBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? _kCabinetBrand : border),
                ),
                child: Center(
                  child: Text(
                    it.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : titleColor,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    InputDecoration fieldDeco(String hint, {bool dense = false}) {
      return InputDecoration(
        hintText: hint,
        isDense: dense,
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kCabinetBrand, width: 1.4)),
      );
    }

    Widget filterBar() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchCtl,
              decoration: fieldDeco("Поиск по названию или артикулу…"),
              style: TextStyle(fontWeight: FontWeight.w700, color: titleColor, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(_status),
                    isExpanded: true,
                    initialValue: _status,
                    decoration: fieldDeco("", dense: true),
                    dropdownColor: cardBg,
                    style: TextStyle(fontWeight: FontWeight.w700, color: titleColor, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("Все")),
                      DropdownMenuItem(value: "active", child: Text("Активные")),
                      DropdownMenuItem(value: "inactive", child: Text("Скрытые")),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _status = v);
                      _loadProducts();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(_ptype),
                    isExpanded: true,
                    initialValue: _ptype,
                    decoration: fieldDeco("", dense: true),
                    dropdownColor: cardBg,
                    style: TextStyle(fontWeight: FontWeight.w700, color: titleColor, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("Тип: все")),
                      DropdownMenuItem(value: "simple", child: Text("Простой")),
                      DropdownMenuItem(value: "variant", child: Text("Вариантный")),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ptype = v);
                      _loadProducts();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => _openSellerRoute(context, const AccountRouteItem("/account/seller/add-product", "Добавить товар")),
                style: FilledButton.styleFrom(
                  backgroundColor: _kCabinetBrand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Добавить товар", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
    }

    Widget productCard(ProductListItem p) {
      final img = (p.primaryImage != null && p.primaryImage!.isNotEmpty)
          ? p.primaryImage!
          : (p.images.isNotEmpty ? p.images.first : null);
      final isOnSale = p.salePrice != null && p.salePrice!.trim().isNotEmpty;
      final sell = isOnSale ? p.salePrice! : p.price;
      final typeRu = p.productType == "variant" ? "Вариантный" : "Простой";
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                  child: img != null
                      ? Image.network(img, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => _sellerNoPhoto(muted))
                      : _sellerNoPhoto(muted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "SKU: ${p.sku.isEmpty ? "—" : p.sku} · $typeRu",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.isActive
                                ? (isDark ? const Color(0x3310B981) : const Color(0xFFD1FAE5))
                                : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            p.isActive ? "Активен" : "Скрыт",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: p.isActive
                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                  : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${_fmtPriceRuSmn(sell)} смн",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                              ),
                              if (isOnSale && p.price.isNotEmpty)
                                Text(
                                  "${_fmtPriceRuSmn(p.price)} смн",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          "Остаток: ${p.stockQty?.isNotEmpty == true ? p.stockQty : "—"} ${_sellerStockUnitLabel(p.stockUnit)}",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: widget.api, slug: p.slug)),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: titleColor,
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text("Открыть", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: p.slug.isEmpty ? null : () => _openEditInApp(context, p.slug),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: titleColor,
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text("Редактировать", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final listBody = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: filterBar()),
        if (_error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x33451A1A) : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600))),
              ),
            ),
          ),
        if (_loading && _items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: LinearProgressIndicator(),
            ),
          ),
        if (_loading && _items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!_loading && _items.isEmpty && _error == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Пока нет товаров", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor)),
                      const SizedBox(height: 6),
                      Text("Нажмите «Добавить товар», чтобы создать первый товар.", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_items.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 24 + widget.bottomPadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => productCard(_items[i]),
                childCount: _items.length,
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Профиль", showBackWhenCanPop: !widget.isProfileRoot),
      drawer: Drawer(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: sellerSidebar(afterPick: () => Navigator.of(context).maybePop()),
          ),
        ),
      ),
      body: Builder(
        builder: (scaffoldCtx) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mobileTop(scaffoldCtx),
              navPills(),
              Expanded(child: listBody),
            ],
          );
        },
      ),
    );
  }
}

Widget _sellerNoPhoto(Color muted) {
  return Center(child: Text("Нет фото", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted)));
}

({Color bg, Color fg, Color border}) _sellerOrderStatusStyle(String raw, bool isDark) {
  switch (raw.toLowerCase()) {
    case "new":
      return (
        bg: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
        fg: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
        border: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.35) : const Color(0xFFBFDBFE),
      );
    case "paid":
      return (
        bg: isDark ? const Color(0xFF164E63) : const Color(0xFFECFEFF),
        fg: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
        border: isDark ? const Color(0xFF22D3EE).withValues(alpha: 0.35) : const Color(0xFFA5F3FC),
      );
    case "processing":
      return (
        bg: isDark ? const Color(0xFF422006) : const Color(0xFFFFFBEB),
        fg: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        border: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.35) : const Color(0xFFFDE68A),
      );
    case "shipped":
      return (
        bg: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
        fg: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
        border: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.35) : const Color(0xFFC7D2FE),
      );
    case "in_transit":
      return (
        bg: isDark ? const Color(0xFF422006) : const Color(0xFFFFFBEB),
        fg: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        border: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.35) : const Color(0xFFFDE68A),
      );
    case "delivered":
    case "done":
      return (
        bg: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
        fg: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
        border: isDark ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFFA7F3D0),
      );
    case "cancelled":
    case "canceled":
      return (
        bg: isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2),
        fg: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
        border: isDark ? const Color(0xFFF43F5E).withValues(alpha: 0.35) : const Color(0xFFFECDD3),
      );
    default:
      return (
        bg: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        fg: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        border: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
      );
  }
}

String _sellerOrderDateTimeRu(DateTime? dt) {
  if (dt == null) return "—";
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, "0");
  return "${two(d.day)}.${two(d.month)}.${d.year}, ${two(d.hour)}:${two(d.minute)}";
}

double? _sellerParsePriceSmn(String raw) {
  final n = double.tryParse(raw.replaceAll(RegExp(r"\s"), "").replaceAll(",", "."));
  return n;
}

/// Қобили кабинет — монанди `DashboardLayout` дар фронтенд.
class AccountCabinetShell extends StatefulWidget {
  const AccountCabinetShell({
    super.key,
    required this.api,
    required this.role,
    required this.activePath,
    required this.pageTitle,
    required this.body,
    this.isProfileRoot = false,
  });

  final ApiClient api;
  final String role;
  final String activePath;
  final String pageTitle;
  final Widget body;
  final bool isProfileRoot;

  @override
  State<AccountCabinetShell> createState() => _AccountCabinetShellState();
}

class _AccountCabinetShellState extends State<AccountCabinetShell> {
  bool _mlmEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadMlm();
  }

  Future<void> _loadMlm() async {
    try {
      final d = await widget.api.siteSettings();
      final m = d["mlm_enabled"];
      if (mounted) setState(() => _mlmEnabled = m is bool ? m : true);
    } catch (_) {}
  }

  void _openRoute(BuildContext context, AccountRouteItem route) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AccountRouteScreen(api: widget.api, role: widget.role, route: route),
      ),
    );
  }

  void _switchRoute(BuildContext context, AccountRouteItem route) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AccountRouteScreen(api: widget.api, role: widget.role, route: route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    if (me == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _kharidChromeAppBar(context, subtitle: widget.pageTitle),
        body: const Center(child: Text("Войдите в аккаунт")),
      );
    }

    final nav = cabinetNavFiltered(me, _mlmEnabled);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final fullName = "${me.user.firstName} ${me.user.lastName}".trim();
    final sidebarTitle = fullName.isNotEmpty
        ? fullName
        : ((me.storeName ?? "").trim().isNotEmpty ? me.storeName!.trim() : "Профиль");
    final balanceRoute = AccountRouteItem("/account/${widget.role}/balance", "Баланс");

    Widget sellerSidebar({VoidCallback? afterPick}) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withValues(alpha: 0.85)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sidebarTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
              const SizedBox(height: 4),
              Text("+${me.phone}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kCabinetBrand.withValues(alpha: isDark ? 0.45 : 0.35)),
                  color: isDark ? const Color(0x331D4ED8) : const Color(0xFFEFF6FF),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Баланс", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kCabinetBrand.withValues(alpha: 0.85))),
                      const SizedBox(height: 2),
                      Text(
                        "${me.balance.isEmpty ? "0.00" : me.balance} смн",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          afterPick?.call();
                          _openRoute(context, balanceRoute);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _kCabinetBrand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Пополнить / Вывод", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final it in nav)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton(
                    onPressed: () {
                      afterPick?.call();
                      if (it.path == widget.activePath) {
                        Navigator.of(context).maybePop();
                        return;
                      }
                      _switchRoute(context, it);
                    },
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: titleColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(it.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              TextButton(
                onPressed: () {
                  afterPick?.call();
                  app.logout();
                },
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Выйти", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    Widget mobileTop(BuildContext scaffoldCtx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(backgroundColor: cardBg, foregroundColor: titleColor),
              onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.pageTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                    Text("Профиль", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openRoute(context, balanceRoute),
              style: TextButton.styleFrom(
                backgroundColor: _kCabinetBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text("${me.balance.isEmpty ? "0.00" : me.balance} смн", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    Widget navPills() {
      return SizedBox(
        height: 46,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          scrollDirection: Axis.horizontal,
          itemCount: nav.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final it = nav[i];
            final active = it.path == widget.activePath;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                if (active) return;
                _switchRoute(context, it);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _kCabinetBrand : cardBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? _kCabinetBrand : border),
                ),
                child: Center(
                  child: Text(
                    it.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : titleColor,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Профиль", showBackWhenCanPop: !widget.isProfileRoot),
      drawer: Drawer(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: sellerSidebar(afterPick: () => Navigator.of(context).maybePop()),
          ),
        ),
      ),
      body: Builder(
        builder: (scaffoldCtx) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mobileTop(scaffoldCtx),
              navPills(),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(top: BorderSide(color: border.withValues(alpha: 0.85))),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: widget.body,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  List<SellerOrderItemRow> _items = const [];
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
        _error = "Нет токена. Войдите заново.";
        _items = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.api.sellerOrderItems(token);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "$e".replaceFirst("Exception: ", "");
        _loading = false;
        _items = const [];
      });
    }
  }

  void _openProduct(BuildContext context, String slug) {
    if (slug.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: widget.api, slug: slug)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final innerCardBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);

    Widget skeleton() {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
        ),
      );
    }

    Widget statusChip(String code, String display) {
      final st = _sellerOrderStatusStyle(code, isDark);
      final d = display.trim();
      final label = d.isNotEmpty ? d : code.toUpperCase();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: st.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: st.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: st.fg),
        ),
      );
    }

    Widget orderCard(SellerOrderItemRow r) {
      final unit = _sellerParsePriceSmn(r.unitPrice);
      final total = unit != null ? unit * r.qty : null;
      final totalStr = total != null ? _fmtPriceRuSmn(total.toString()) : "—";
      final unitStr = _fmtPriceRuSmn(r.unitPrice);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: innerCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 15, color: muted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _sellerOrderDateTimeRu(r.orderCreatedAt),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      statusChip(r.orderStatus, r.orderStatusDisplay),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _openProduct(context, r.productSlug),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border.withValues(alpha: 0.8)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: (r.productImage != null && r.productImage!.isNotEmpty)
                              ? Image.network(r.productImage!, fit: BoxFit.cover)
                              : Icon(Icons.inventory_2_outlined, color: muted, size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _openProduct(context, r.productSlug),
                              child: Text(
                                r.productTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, height: 1.2, color: titleColor),
                              ),
                            ),
                            if ((r.variantLabel ?? "").trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                r.variantLabel!.trim(),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kCabinetBrand),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  "${r.qty} шт. × $unitStr смн",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                                ),
                                const Spacer(),
                                Text(
                                  "$totalStr смн",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: titleColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AccountCabinetShell(
      api: widget.api,
      role: "seller",
      activePath: "/account/seller/orders",
      pageTitle: "Заказы",
      body: RefreshIndicator(
        color: _kCabinetBrand,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "Заказы по вашим товарам",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.2, color: titleColor),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kCabinetBrand.withValues(alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "${_items.length} ${_items.length == 1 ? "заказ" : "заказов"}",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF93C5FD) : _kCabinetBrand),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x33451A1A) : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF881337) : const Color(0xFFFECDD3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded, color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    skeleton(),
                    skeleton(),
                    skeleton(),
                  ],
                  if (!_loading && _error == null && _items.isEmpty) ...[
                    const SizedBox(height: 20),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border, style: BorderStyle.solid),
                        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.45) : const Color(0xFFF8FAFC),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.inventory_2_outlined, size: 30, color: muted),
                            ),
                            const SizedBox(height: 14),
                            Text("У вас пока нет заказов", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                            const SizedBox(height: 8),
                            Text(
                              "Как только покупатели начнут приобретать ваши товары, заказы появятся здесь.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!_loading && _items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._items.map(orderCard),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerAnalyticsChartPoint {
  const SellerAnalyticsChartPoint({this.date, required this.sales, required this.ordersCount});

  final DateTime? date;
  final double sales;
  final int ordersCount;

  static SellerAnalyticsChartPoint fromJson(Map<String, dynamic> json) {
    final rawDate = json["date"];
    DateTime? dt;
    if (rawDate is String && rawDate.isNotEmpty) {
      dt = DateTime.tryParse(rawDate);
    }
    final salesRaw = json["sales"];
    final sales = salesRaw is num ? salesRaw.toDouble() : double.tryParse("$salesRaw") ?? 0;
    final ordersRaw = json["orders_count"];
    final orders = ordersRaw is num ? ordersRaw.toInt() : int.tryParse("$ordersRaw") ?? 0;
    return SellerAnalyticsChartPoint(date: dt, sales: sales, ordersCount: orders);
  }
}

class SellerAnalyticsData {
  const SellerAnalyticsData({
    required this.totalRevenue,
    required this.totalItemsSold,
    required this.totalOrders,
    required this.chartData,
  });

  final double totalRevenue;
  final int totalItemsSold;
  final int totalOrders;
  final List<SellerAnalyticsChartPoint> chartData;

  static SellerAnalyticsData fromJson(Map<String, dynamic> json) {
    final revRaw = json["total_revenue"];
    final revenue = revRaw is num ? revRaw.toDouble() : double.tryParse("$revRaw") ?? 0;
    final itemsRaw = json["total_items_sold"];
    final items = itemsRaw is num ? itemsRaw.toInt() : int.tryParse("$itemsRaw") ?? 0;
    final ordersRaw = json["total_orders"];
    final orders = ordersRaw is num ? ordersRaw.toInt() : int.tryParse("$ordersRaw") ?? 0;
    final chartRaw = json["chart_data"];
    final chart = chartRaw is List
        ? chartRaw.whereType<Map>().map((e) => SellerAnalyticsChartPoint.fromJson(Map<String, dynamic>.from(e))).toList()
        : <SellerAnalyticsChartPoint>[];
    return SellerAnalyticsData(
      totalRevenue: revenue,
      totalItemsSold: items,
      totalOrders: orders,
      chartData: chart,
    );
  }
}

String _analyticsChartDateLabel(DateTime? d) {
  if (d == null) return "";
  const months = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
  final m = d.month.clamp(1, 12);
  return "${d.day} ${months[m - 1]}";
}

class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  SellerAnalyticsData? _data;
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
        _error = "Нет токена. Войдите заново.";
        _data = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.api.sellerAnalytics(token);
      if (!mounted) return;
      setState(() {
        _data = SellerAnalyticsData.fromJson(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Не удалось загрузить аналитику";
        _loading = false;
        _data = null;
      });
    }
  }

  Widget _metricCard({
    required bool isDark,
    required Color borderColor,
    required List<Color> gradientColors,
    required Color iconBg,
    required Color iconColor,
    required IconData icon,
    required String value,
    required String valueSuffix,
    required String label,
  }) {
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.1,
              child: Icon(icon, size: 80, color: iconColor),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: titleColor, height: 1.1),
                  children: [
                    TextSpan(text: value),
                    if (valueSuffix.isNotEmpty)
                      TextSpan(
                        text: " $valueSuffix",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _salesChart({
    required bool isDark,
    required List<SellerAnalyticsChartPoint> points,
    required Color titleColor,
    required Color muted,
    required Color border,
    required Color cardBg,
  }) {
    if (points.isEmpty) {
      return SizedBox(
        height: 192,
        child: Center(
          child: Text(
            "Нет данных за выбранный период",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted),
          ),
        ),
      );
    }

    final maxSales = points.fold<double>(0, (m, p) => p.sales > m ? p.sales : m);

    return SizedBox(
      height: 256,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 32, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < points.length; i++)
              Builder(
                builder: (context) {
                  final p = points[i];
                  final pct = maxSales > 0 ? (p.sales / maxSales) : 0.0;
                  final barH = (pct * 160).clamp(8.0, 160.0);
                  return Padding(
                    padding: EdgeInsets.only(right: i < points.length - 1 ? 8 : 0),
                    child: SizedBox(
                      width: 44,
                      height: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 400 + i * 20),
                                curve: Curves.easeOutCubic,
                                width: 40,
                                height: barH,
                                decoration: BoxDecoration(
                                  color: _kCabinetBrand,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Transform.rotate(
                            angle: 0.785398,
                            child: Text(
                              _analyticsChartDateLabel(p.date),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final panelBg = isDark ? const Color(0xFF18181B) : Colors.white;

    Widget skeletonCard() {
      return Container(
        height: 128,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
      );
    }

    final data = _data;

    return AccountCabinetShell(
      api: widget.api,
      role: "seller",
      activePath: "/account/seller/analytics",
      pageTitle: "Аналитика",
      body: RefreshIndicator(
        color: _kCabinetBrand,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    "Обзор продаж",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.2, color: titleColor),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x33451A1A) : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF881337) : const Color(0xFFFECDD3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded, color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_loading && data == null) ...[
                    const SizedBox(height: 16),
                    skeletonCard(),
                    const SizedBox(height: 12),
                    skeletonCard(),
                    const SizedBox(height: 12),
                    skeletonCard(),
                  ],
                  if (data != null) ...[
                    const SizedBox(height: 16),
                    _metricCard(
                      isDark: isDark,
                      borderColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFBFDBFE),
                      gradientColors: isDark
                          ? [const Color(0xFF172554).withValues(alpha: 0.55), const Color(0xFF0F172A)]
                          : [const Color(0xFFEFF6FF), Colors.white],
                      iconBg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFDBEAFE),
                      iconColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                      icon: Icons.trending_up_rounded,
                      value: _fmtPriceRuSmn(data.totalRevenue.toString()),
                      valueSuffix: "смн",
                      label: "Общая выручка",
                    ),
                    const SizedBox(height: 12),
                    _metricCard(
                      isDark: isDark,
                      borderColor: isDark ? const Color(0xFF065F46).withValues(alpha: 0.35) : const Color(0xFFA7F3D0),
                      gradientColors: isDark
                          ? [const Color(0xFF064E3B).withValues(alpha: 0.45), const Color(0xFF0F172A)]
                          : [const Color(0xFFECFDF5), Colors.white],
                      iconBg: isDark ? const Color(0xFF065F46).withValues(alpha: 0.5) : const Color(0xFFD1FAE5),
                      iconColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                      icon: Icons.inventory_2_outlined,
                      value: _fmtPriceRuSmn(data.totalItemsSold.toString()),
                      valueSuffix: "шт.",
                      label: "Продано товаров",
                    ),
                    const SizedBox(height: 12),
                    _metricCard(
                      isDark: isDark,
                      borderColor: isDark ? const Color(0xFF3730A3).withValues(alpha: 0.35) : const Color(0xFFC7D2FE),
                      gradientColors: isDark
                          ? [const Color(0xFF312E81).withValues(alpha: 0.45), const Color(0xFF0F172A)]
                          : [const Color(0xFFEEF2FF), Colors.white],
                      iconBg: isDark ? const Color(0xFF3730A3).withValues(alpha: 0.5) : const Color(0xFFE0E7FF),
                      iconColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                      icon: Icons.credit_card_rounded,
                      value: _fmtPriceRuSmn(data.totalOrders.toString()),
                      valueSuffix: "",
                      label: "Всего заказов",
                    ),
                    const SizedBox(height: 24),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: border),
                        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Динамика продаж (последние 30 дней)",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: titleColor),
                            ),
                            const SizedBox(height: 8),
                            _salesChart(
                              isDark: isDark,
                              points: data.chartData,
                              titleColor: titleColor,
                              muted: muted,
                              border: border,
                              cardBg: panelBg,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CompareTableBody extends StatelessWidget {
  const _CompareTableBody({required this.api, required this.products});
  final ApiClient api;
  final List<ProductListItem> products;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final panelBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final stickyBg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC);

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Text(
                "Здесь появятся товары, которые вы добавите для сравнения (до $kCompareMax шт.).",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, height: 1.4),
              ),
            ),
          ),
        ),
      );
    }

    final rows = <({String label, String Function(ProductListItem) cell})>[
      (label: "Цена", cell: _comparePriceCell),
      (label: "Артикул (SKU)", cell: (p) => p.sku.isEmpty ? "—" : p.sku),
      (label: "Тип товара", cell: _compareTypeCell),
      (label: "Категория (slug)", cell: (p) => p.categorySlug.isEmpty ? "—" : p.categorySlug),
      (label: "Бренд", cell: (p) => (p.brandSlug ?? "").isEmpty ? "—" : p.brandSlug!),
      (label: "Остаток", cell: (p) => (p.stockQty ?? "").isEmpty ? "—" : p.stockQty!),
      (label: "Ед. измерения", cell: (p) => _compareUnitCell(p.stockUnit)),
      (label: "Кешбэк, %", cell: (p) => (p.cashbackPercent ?? "").isEmpty ? "—" : p.cashbackPercent!),
      (label: "Дата появления", cell: (p) => _compareDateCell(p.createdAt)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Container(
                          color: stickyBg,
                          padding: const EdgeInsets.all(14),
                          child: Text("Параметр", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: muted, letterSpacing: 0.4)),
                        ),
                      ),
                      ...products.map((p) => _CompareProductHeader(api: api, product: p)),
                    ],
                  ),
                  for (var i = 0; i < rows.length; i++)
                    Container(
                      color: i.isOdd ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.35) : const Color(0xFFF8FAFC)) : panelBg,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Container(
                              color: stickyBg,
                              padding: const EdgeInsets.all(14),
                              child: Text(rows[i].label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
                            ),
                          ),
                          ...products.map(
                            (p) => SizedBox(
                              width: 200,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(rows[i].cell(p), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted, height: 1.35)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.35) : const Color(0xFFF8FAFC),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Container(
                            color: stickyBg,
                            padding: const EdgeInsets.all(14),
                            child: Text("Действие", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
                          ),
                        ),
                        ...products.map(
                          (p) => SizedBox(
                            width: 200,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: FilledButton(
                                onPressed: () async {
                                  await app.addToCart(p);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Товар добавлен в корзину")),
                                    );
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kCabinetBrand,
                                  minimumSize: const Size(120, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("В корзину", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareProductHeader extends StatelessWidget {
  const _CompareProductHeader({required this.api, required this.product});
  final ApiClient api;
  final ProductListItem product;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final img = product.displayImage;
    final price = double.tryParse(product.price) ?? 0;
    final sale = double.tryParse(product.salePrice ?? "") ?? price;
    final hasSale = product.salePrice != null && product.salePrice!.isNotEmpty && sale > 0 && sale < price;

    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => app.removeCompare(product.id),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
                  side: BorderSide(color: border),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: api, slug: product.slug)),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: img == null
                      ? Container(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          child: const Center(child: Text("Нет фото", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                        )
                      : Image.network(img, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: api, slug: product.slug)),
                );
              },
              child: Text(
                product.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${(hasSale ? sale : price).toStringAsFixed(0)} смн",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }
}

String _comparePriceCell(ProductListItem p) {
  final price = double.tryParse(p.price) ?? 0;
  final sale = double.tryParse(p.salePrice ?? "") ?? price;
  final hasSale = p.salePrice != null && p.salePrice!.isNotEmpty && sale > 0 && sale < price;
  if (hasSale) return "${sale.toStringAsFixed(0)} смн (было ${price.toStringAsFixed(0)} смн)";
  return "${price.toStringAsFixed(0)} смн";
}

String _compareTypeCell(ProductListItem p) {
  if (p.productType == "simple") return "Простой товар";
  if (p.productType == "variant") return "Вариантный товар";
  return p.productType;
}

String _compareUnitCell(String u) {
  switch (u) {
    case "pcs":
      return "шт";
    case "kg":
      return "кг";
    case "l":
      return "л";
    case "m":
      return "м";
    default:
      return u;
  }
}

String _compareDateCell(String iso) {
  if (iso.isEmpty) return "—";
  final d = DateTime.tryParse(iso);
  if (d == null) return "—";
  String two(int n) => n.toString().padLeft(2, "0");
  const months = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
  return "${two(d.day)} ${months[d.month - 1]} ${d.year}";
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key, required this.api, required this.role});
  final ApiClient api;
  final String role;

  @override
  Widget build(BuildContext context) {
    final path = "/account/$role/settings";
    return AccountCabinetShell(
      api: api,
      role: role,
      activePath: path,
      pageTitle: accountPageTitle(path),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: AccountSettingsForm(api: api, role: role),
      ),
    );
  }
}

/// Карточка избранного для сетки кабинета — заполняет ячейку GridView, без обрезки кнопки и иконок.
class _WishlistGridCard extends StatelessWidget {
  const _WishlistGridCard({required this.api, required this.product});
  final ApiClient api;
  final ProductListItem product;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = double.tryParse(product.price) ?? 0;
    final sale = double.tryParse(product.salePrice ?? "") ?? price;
    final hasSale = product.salePrice != null && product.salePrice!.isNotEmpty && sale > 0 && sale < price;
    final isVariant = product.productType == "variant";
    final img = product.displayImage;

    Future<void> openProduct() {
      return Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProductScreenV2(api: api, slug: product.slug)),
      );
    }

    Future<void> onCart() async {
      if (isVariant) {
        await openProduct();
        return;
      }
      await app.addToCart(product);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Товар добавлен в корзину")),
        );
      }
    }

    Future<void> onHeart() async {
      await app.toggleWishlist(product);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Удалено из избранного")),
        );
      }
    }

    Widget overlayIcon({required IconData icon, required VoidCallback onTap, required bool heart}) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 2,
        shadowColor: const Color(0x330F172A),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: heart ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: heart ? const Color(0xFFE11D48) : const Color(0xFF64748B),
              fill: heart ? 1.0 : 0.0,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1A3A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33060B12) : const Color(0x0F0F172A),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: openProduct,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (img == null)
                        const ColoredBox(
                          color: Color(0xFFF1F5F9),
                          child: Center(
                            child: Text(
                              "Нет фото",
                              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                        )
                      else
                        Image.network(img, fit: BoxFit.cover),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            overlayIcon(
                              icon: Icons.compare_arrows_rounded,
                              heart: false,
                              onTap: () async {
                                final limit = await app.toggleCompare(product);
                                if (limit == "limit" && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Не более $kCompareMax товаров для сравнения")),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 6),
                            overlayIcon(
                              icon: Icons.favorite_rounded,
                              heart: true,
                              onTap: onHeart,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: isDark ? const Color(0xFF0A1530) : Colors.transparent,
              child: InkWell(
                onTap: openProduct,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${(hasSale ? sale : price).toStringAsFixed(0)} смн",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 1, color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: onCart,
                  icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                  label: Text(
                    isVariant ? "Выбрать" : "В корзину",
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key, required this.api, required this.role});
  final ApiClient api;
  final String role;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.wishlistList;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final path = "/account/$role/wishlist";

    return AccountCabinetShell(
      api: api,
      role: role,
      activePath: path,
      pageTitle: accountPageTitle(path),
      body: RefreshIndicator(
        color: _kCabinetBrand,
        onRefresh: app.reloadStoredLists,
        child: list.isEmpty
            ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                            color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                            child: Text(
                              "Здесь появятся товары из избранного.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, height: 1.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 360,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _WishlistGridCard(api: api, product: list[i]),
              ),
      ),
    );
  }
}

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key, required this.api, required this.role});
  final ApiClient api;
  final String role;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final path = "/account/$role/compare";
    return AccountCabinetShell(
      api: api,
      role: role,
      activePath: path,
      pageTitle: accountPageTitle(path),
      body: _CompareTableBody(api: api, products: app.compareList),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Settings · $role"),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _DarkCard(child: ListTile(title: const Text("Имя пользователя"), subtitle: Text(me?.user.username ?? "-"))),
          _DarkCard(child: ListTile(title: const Text("Телефон"), subtitle: Text(me?.phone ?? "-"))),
          _DarkCard(child: ListTile(title: const Text("Шаҳр"), subtitle: Text(me?.city ?? "-"))),
          _DarkCard(child: ListTile(title: const Text("Адрес"), subtitle: Text(me?.address ?? "-"))),
        ],
      ),
    );
  }
}

class BalanceHubScreen extends StatelessWidget {
  const BalanceHubScreen({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppState>().me;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Balance"),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _DarkCard(
            child: ListTile(
              title: const Text("Текущий баланс"),
              trailing: Text("${me?.balance ?? "0"} cм"),
            ),
          ),
          _DarkCard(
            child: ListTile(
              title: const Text("Topup SmartPay"),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TopupScreen(api: api))),
            ),
          ),
          _DarkCard(
            child: ListTile(
              title: const Text("Wallet History"),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                final role = me?.role ?? "client";
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => EarningsHistoryScreen(api: api, role: role)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SellerAddProductScreen extends StatelessWidget {
  const SellerAddProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Добавить товар"),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          _DarkCard(child: ListTile(title: Text("Название"), subtitle: Text("Форма будет расширена под 1:1 parity"))),
          _DarkCard(child: ListTile(title: Text("Цена"), subtitle: Text("..."))),
          _DarkCard(child: ListTile(title: Text("Категория"), subtitle: Text("..."))),
        ],
      ),
    );
  }
}

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  final amountCtl = TextEditingController(text: "100");
  String? out;

  @override
  Widget build(BuildContext context) {
    final token = context.read<AppState>().accessToken!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Topup SmartPay"),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: amountCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount")),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                try {
                  final val = double.tryParse(amountCtl.text) ?? 0;
                  final data = await widget.api.topupSmartpay(token, val);
                  final link = data["payment_link"]?.toString();
                  if (link != null && link.isNotEmpty) {
                    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                    setState(() => out = "Payment link opened.");
                  } else {
                    setState(() => out = data.toString());
                  }
                } catch (e) {
                  setState(() => out = "$e");
                }
              },
              child: const Text("Topup"),
            ),
            if (out != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(out!)),
          ],
        ),
      ),
    );
  }
}

const Color _kCabinetBrand = Color(0xFF2563EB);

String _cabinetRoleRu(String r) {
  switch (r) {
    case "seller":
      return "Продавец";
    case "courier":
      return "Курьер";
    case "partner":
      return "Партнёр";
    case "moderator":
      return "Модератор";
    case "admin":
      return "Админ";
    default:
      return "Покупатель";
  }
}

class ProfileCabinetScaffold extends StatefulWidget {
  const ProfileCabinetScaffold({super.key, required this.api, required this.bottomPadding});
  final ApiClient api;
  final double bottomPadding;

  @override
  State<ProfileCabinetScaffold> createState() => _ProfileCabinetScaffoldState();
}

class _ProfileCabinetScaffoldState extends State<ProfileCabinetScaffold> {
  bool _mlmEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSiteSettings();
  }

  Future<void> _loadSiteSettings() async {
    try {
      final d = await widget.api.siteSettings();
      final m = d["mlm_enabled"];
      if (!mounted) return;
      setState(() => _mlmEnabled = m is bool ? m : true);
    } catch (_) {}
  }

  void _pushRoute(BuildContext context, MeProfile me, AccountRouteItem route, {VoidCallback? onReturn}) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => AccountRouteScreen(api: widget.api, role: me.role, route: route),
          ),
        )
        .then((_) => onReturn?.call());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me!;
    final role = me.role;
    final nav = cabinetNavFiltered(me, _mlmEnabled);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final fullName = "${me.user.firstName} ${me.user.lastName}".trim();
    final sidebarTitle = fullName.isNotEmpty
        ? fullName
        : ((me.storeName ?? "").trim().isNotEmpty ? me.storeName!.trim() : "Профиль");
    final balanceRoute = AccountRouteItem("/account/$role/balance", "Баланс");

    Widget row(String k, String v) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(k, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
            ),
            Expanded(child: Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor))),
          ],
        ),
      );
    }

    Widget overviewCard() {
      final ref = (me.referralShortCode ?? "").trim().isNotEmpty
          ? me.referralShortCode!.trim()
          : (me.referralCode ?? "").trim();
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withValues(alpha: 0.9)),
          boxShadow: isDark ? null : const [BoxShadow(color: Color(0x120F172A), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Кабинет", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
              const SizedBox(height: 6),
              Text(_cabinetRoleRu(role), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kCabinetBrand)),
              const SizedBox(height: 18),
              row("Логин", me.user.username),
              row("Телефон", me.phone),
              row("Город", me.city.isEmpty ? "—" : me.city),
              row("Адрес", me.address.isEmpty ? "—" : me.address),
              row("Баланс", "${me.balance} смн"),
              if (ref.isNotEmpty) row("Реферал", ref),
              if (me.storeName != null && me.storeName!.trim().isNotEmpty) row("Магазин", me.storeName!.trim()),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => _pushRoute(context, me, AccountRouteItem("/account/$role/settings", "Настройка")),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: titleColor,
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Настройки профиля", style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget sidebarNav({VoidCallback? afterPick}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final it in nav)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton(
                onPressed: () {
                  afterPick?.call();
                  _pushRoute(context, me, it);
                },
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: titleColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(it.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              afterPick?.call();
              app.logout();
            },
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Выйти", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    }

    Widget balanceCard() {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kCabinetBrand.withValues(alpha: isDark ? 0.45 : 0.35)),
          color: isDark ? const Color(0x331D4ED8) : const Color(0xFFEFF6FF),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Баланс", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kCabinetBrand.withValues(alpha: 0.85))),
              const SizedBox(height: 2),
              Text(
                "${me.balance.isEmpty ? "0.00" : me.balance} смн",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).maybePop();
                  _pushRoute(context, me, balanceRoute);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _kCabinetBrand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Пополнить / Вывод", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    Widget sidebarColumn() {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withValues(alpha: 0.85)),
          boxShadow: isDark ? null : const [BoxShadow(color: Color(0x100F172A), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sidebarTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
              const SizedBox(height: 4),
              Text("+${me.phone}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
              const SizedBox(height: 14),
              balanceCard(),
              const SizedBox(height: 12),
              sidebarNav(afterPick: wide ? null : () => Navigator.of(context).maybePop()),
            ],
          ),
        ),
      );
    }

    Widget mobileHeader(BuildContext scaffoldCtx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(backgroundColor: cardBg, foregroundColor: titleColor),
              onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Кабинет", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                    Text(
                      sidebarTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => _pushRoute(context, me, balanceRoute),
              style: TextButton.styleFrom(
                backgroundColor: _kCabinetBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text("${me.balance.isEmpty ? "0.00" : me.balance} смн", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    Widget navPills() {
      return SizedBox(
        height: 48,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          scrollDirection: Axis.horizontal,
          itemCount: nav.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final it = nav[i];
            return ActionChip(
              label: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              onPressed: () => _pushRoute(context, me, it),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide(color: border)),
              backgroundColor: cardBg,
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _kharidChromeAppBar(context, subtitle: "Профиль", showBackWhenCanPop: false),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: sidebarColumn(),
                ),
              ),
            ),
      body: Builder(
        builder: (scaffoldCtx) {
          if (wide) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + widget.bottomPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: SingleChildScrollView(child: sidebarColumn())),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border.withValues(alpha: 0.85)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                              child: Text("Кабинет", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          overviewCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              mobileHeader(scaffoldCtx),
              navPills(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + widget.bottomPadding),
                  child: overviewCard(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bottomPad = _floatingNavBottomInset(context);
    if (!app.isAuthenticated) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _kharidChromeAppBar(context, subtitle: "Профиль", showBackWhenCanPop: false),
        body: ProfileAuthScrollBody(
          api: api,
          bottomPadding: bottomPad,
          onSellerLoggedIn: (ctx) => _pushSellerMyProducts(api, ctx),
          onCourierLoggedIn: (ctx) => _pushCourierDeliveries(api, ctx),
          onClientLoggedIn: (ctx) => _pushClientOrders(api, ctx),
          onPartnerLoggedIn: (ctx) => _pushPartnerOrders(api, ctx),
        ),
      );
    }
    if (app.me == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _kharidChromeAppBar(context, subtitle: "Профиль", showBackWhenCanPop: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (app.me!.role == "seller") {
      return SellerProductsScreen(api: api, isProfileRoot: true, bottomPadding: bottomPad);
    }
    if (app.me!.role == "courier") {
      return CourierDeliveriesScreen(api: api, isProfileRoot: true, bottomPadding: bottomPad);
    }
    if (app.me!.role == "client") {
      return ClientOrdersScreen(api: api, role: "client", isProfileRoot: true, bottomPadding: bottomPad);
    }
    if (app.me!.role == "partner") {
      return ClientOrdersScreen(api: api, role: "partner", isProfileRoot: true, bottomPadding: bottomPad);
    }
    return ProfileCabinetScaffold(api: api, bottomPadding: bottomPad);
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.child});
  final Widget child;

  final _bg = const Color(0xFF101826);
  final _border = const Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}
