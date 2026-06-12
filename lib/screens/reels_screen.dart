import "package:flutter/foundation.dart" show kDebugMode;
import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:provider/provider.dart";
import "package:share_plus/share_plus.dart";

import "../api_client.dart";
import "../app_state.dart";
import "../models.dart";

const String _kWebBase = String.fromEnvironment("WEB_BASE_URL", defaultValue: "https://kharid.tj");

Uri? _cloudflareReelEmbedUri(String uid) {
  final u = uid.trim();
  if (u.isEmpty) return null;
  return Uri.parse(
    "https://iframe.videodelivery.net/${Uri.encodeComponent(u)}?autoplay=true&muted=true&loop=true&preload=true",
  );
}

typedef ReelOpenProduct = void Function(BuildContext context, String slug);

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, required this.api, this.onOpenProduct});

  final ApiClient api;
  final ReelOpenProduct? onOpenProduct;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final _pageController = PageController();
  final List<ProductListItem> _items = [];
  String? _next;
  bool _loading = true;
  String? _error;
  int _activeIdx = 0;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.reelsProducts();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.results.where((p) => p.hasCloudflareVideo));
        _next = page.next;
        _error = _items.isEmpty ? "Пока нет товаров с видео" : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items.clear();
        _next = null;
        _error = "Не удалось загрузить ленту";
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final next = _next;
    if (next == null || next.isEmpty || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await widget.api.productsPageFromUrl(next);
      if (!mounted) return;
      final seen = _items.map((e) => e.id).toSet();
      final add = page.results.where((p) => p.hasCloudflareVideo && !seen.contains(p.id));
      setState(() {
        _items.addAll(add);
        _next = page.next;
      });
    } catch (_) {
      // ignore pagination errors
    } finally {
      _loadingMore = false;
    }
  }

  void _onPageChanged(int idx) {
    setState(() => _activeIdx = idx);
    if (_next != null && idx >= _items.length - 3) {
      _loadMore();
    }
  }

  void _openProduct(ProductListItem product) {
    final opener = widget.onOpenProduct;
    if (opener != null) {
      opener(context, product.slug);
      return;
    }
  }

  Future<void> _shareProduct(ProductListItem product) async {
    final url = "$_kWebBase/p/${Uri.encodeComponent(product.slug)}";
    await SharePlus.instance.share(ShareParams(text: url, subject: product.title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  ),
                  SizedBox(height: 12),
                  Text("Загрузка…", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            )
          else if (_error != null || _items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie_creation_outlined, size: 48, color: Colors.white38),
                    const SizedBox(height: 16),
                    Text(
                      _error ?? "Видео для Reels пока недоступно",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text("На главную", style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, i) {
                final product = _items[i];
                final app = context.watch<AppState>();
                return _ReelSlide(
                  product: product,
                  active: i == _activeIdx,
                  inWishlist: app.isProductInWishlist(product.id),
                  onFavorite: () async {
                    await app.toggleWishlist(product);
                    if (!context.mounted) return;
                    final added = app.isProductInWishlist(product.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(added ? "В избранном" : "Убрано из избранного"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onShare: () => _shareProduct(product),
                  onOpenProduct: () => _openProduct(product),
                );
              },
            ),

          // Header
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: const CircleBorder(side: BorderSide(color: Color(0x26FFFFFF))),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.movie_creation_outlined, color: Color(0xFF93C5FD), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        "Reels",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelSlide extends StatelessWidget {
  const _ReelSlide({
    required this.product,
    required this.active,
    required this.inWishlist,
    required this.onFavorite,
    required this.onShare,
    required this.onOpenProduct,
  });

  final ProductListItem product;
  final bool active;
  final bool inWishlist;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final uid = (product.cloudflareVideoUid ?? "").trim();
    final poster = product.displayImage;
    final embed = uid.isNotEmpty ? _cloudflareReelEmbedUri(uid) : null;

    return ColoredBox(
      color: const Color(0xFF020617),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (poster != null && poster.isNotEmpty)
            Image.network(
              poster,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _ReelPosterFallback(),
            )
          else
            const _ReelPosterFallback(),

          if (embed != null && active)
            InAppWebView(
              key: ValueKey<String>("reel-$uid"),
              initialUrlRequest: URLRequest(url: WebUri(embed.toString())),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                isInspectable: kDebugMode,
                transparentBackground: true,
              ),
            )
          else if (uid.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Видео недоступно",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            )
          else if (!active)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  "Листайте вверх / вниз",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),

          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.42,
            child: Column(
              children: [
                _ReelSideAction(
                  icon: inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: "Избранное",
                  active: inWishlist,
                  onTap: onFavorite,
                ),
                const SizedBox(height: 20),
                _ReelSideAction(
                  icon: Icons.share_rounded,
                  label: "Поделиться",
                  onTap: onShare,
                ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: GestureDetector(
              onTap: onOpenProduct,
              child: Text(
                product.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPosterFallback extends StatelessWidget {
  const _ReelPosterFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), Color(0xFF020617), Colors.black],
        ),
      ),
    );
  }
}

class _ReelSideAction extends StatelessWidget {
  const _ReelSideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? const Color(0x66FB7185) : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: active ? const Color(0xFFFB7185) : Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 72,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
