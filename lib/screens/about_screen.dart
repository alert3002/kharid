import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../app_state.dart";
import "../widgets/app_logo.dart";
import "../widgets/kharid_site_header.dart";

/// Мазмуни «О нас»: видеоҳои шабакаи бонусӣ (RU / TJ).
/// Рангҳо аз [Theme] мегиранд — реҷаи светлая: фони равшан, реҷаи торик: монанди макет.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const String _siteUrl = "https://kharid.tj";

  static const String _youtubeRu = "https://www.youtube.com/watch?v=0DBnIWgXUJI";
  static const String _youtubeTj = "https://www.youtube.com/watch?v=9pmlEHgsyLI";
  static const String _thumbRu = "https://img.youtube.com/vi/0DBnIWgXUJI/hqdefault.jpg";
  static const String _thumbTj = "https://img.youtube.com/vi/9pmlEHgsyLI/hqdefault.jpg";

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _langRu = true;

  static bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _fieldBg(BuildContext c) => _isDark(c) ? const Color(0xFF111827) : const Color(0xFFE2E8F0);

  Color _pillInactive(BuildContext c) => _isDark(c) ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

  Color _mutedFg(BuildContext c) => _isDark(c) ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

  Color _onPage(BuildContext c) => Theme.of(c).colorScheme.onSurface;

  String get _videoUrl => _langRu ? AboutScreen._youtubeRu : AboutScreen._youtubeTj;
  String get _thumbUrl => _langRu ? AboutScreen._thumbRu : AboutScreen._thumbTj;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Невозможно открыть: $url")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final siteHeader = KharidSiteHeader(
      onMenuPressed: () => context.read<AppState>().openSideMenuFrom(context),
    );
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: siteHeader.preferredSize.height,
                width: double.infinity,
                child: siteHeader,
              ),
            ),
            SliverToBoxAdapter(child: _searchRow(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 14)),
            SliverToBoxAdapter(child: _langTabs(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _videoBlock(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 28)),
            SliverToBoxAdapter(child: _footerBlock(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _searchRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = _mutedFg(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: _fieldBg(context),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Поиск...",
                    style: TextStyle(color: hint.withValues(alpha: 0.95), fontSize: 15),
                  ),
                ),
              ),
              Material(
                color: scheme.primary,
                child: InkWell(
                  onTap: () => _openUrl(AboutScreen._siteUrl),
                  child: SizedBox(
                    width: 52,
                    height: 48,
                    child: Icon(Icons.search_rounded, color: scheme.onPrimary, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _fieldBg(context), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(
              child: _tabPill(
                context: context,
                label: "Информация О нас",
                selected: _langRu,
                onTap: () => setState(() => _langRu = true),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _tabPill(
                context: context,
                label: "Маълумот Дар бораи мо",
                selected: !_langRu,
                onTap: () => setState(() => _langRu = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabPill({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected
        ? scheme.onPrimary
        : (_isDark(context) ? Colors.white.withValues(alpha: 0.88) : _onPage(context).withValues(alpha: 0.9));
    return Material(
      color: selected ? scheme.primary : _pillInactive(context),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => _openUrl(_videoUrl),
                child: Image.network(
                  _thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => Container(
                    color: _fieldBg(context),
                    alignment: Alignment.center,
                    child: Icon(Icons.video_library_rounded, color: _mutedFg(context), size: 48),
                  ),
                ),
              ),
              Material(
                color: Colors.black.withValues(alpha: 0.28),
                child: InkWell(
                  onTap: () => _openUrl(_videoUrl),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14)],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: TextButton.icon(
                  onPressed: () => _openUrl(_videoUrl),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                  label: Text(
                    "YouTube",
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerBlock(BuildContext context) {
    final t = Theme.of(context);
    final onPage = _onPage(context).withValues(alpha: 0.92);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: AppLogo(height: 28)),
          const SizedBox(height: 10),
          Text(
            "Лучшие покупки в Таджикистане:\nбыстро и удобно.",
            textAlign: TextAlign.center,
            style: t.textTheme.titleSmall?.copyWith(
                  color: onPage,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ) ??
                TextStyle(color: onPage, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 22),
          Text(
            "Контакты",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _onPage(context).withValues(alpha: 0.96),
            ),
          ),
          const SizedBox(height: 12),
          _footerLine(context, Icons.phone_rounded, "+992 (93) 988-88-83", () => _openUrl("tel:+992939888883")),
          const SizedBox(height: 8),
          _footerLine(context, Icons.email_outlined, "info@kharid.tj", () => _openUrl("mailto:info@kharid.tj")),
          const SizedBox(height: 18),
          Row(
            children: [
              _social(context, Icons.facebook_rounded, () => _openUrl("https://www.facebook.com/kharidtj")),
              const SizedBox(width: 12),
              _social(context, Icons.photo_camera_rounded, () => _openUrl("https://www.instagram.com/kharidtj")),
              const SizedBox(width: 12),
              _social(context, Icons.telegram, () => _openUrl("https://t.me/kharidTJ")),
              const SizedBox(width: 12),
              _social(context, Icons.language_rounded, () => _openUrl(AboutScreen._siteUrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerLine(BuildContext context, IconData icon, String text, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary.withValues(alpha: 0.95)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 14, color: _onPage(context).withValues(alpha: 0.9))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _social(BuildContext context, IconData icon, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: _pillInactive(context),
      shape: CircleBorder(side: BorderSide(color: scheme.primary.withValues(alpha: _isDark(context) ? 0.28 : 0.35))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: _onPage(context).withValues(alpha: 0.92)),
        ),
      ),
    );
  }
}
