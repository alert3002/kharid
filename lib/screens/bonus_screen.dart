import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../app_state.dart";
import "../widgets/app_logo.dart";
import "../widgets/kharid_site_header.dart";

/// Бонусная программа — калькулятор + видео + футер; рангҳо аз [Theme].
class BonusScreen extends StatefulWidget {
  const BonusScreen({super.key});

  static const String _youtubeCalcRu = "https://www.youtube.com/watch?v=t_xjCNj0kZg";
  static const String _youtubeCalcTj = "https://www.youtube.com/watch?v=nwS_HnwQ4wo";
  static const String _thumbRu = "https://img.youtube.com/vi/t_xjCNj0kZg/hqdefault.jpg";
  static const String _thumbTj = "https://img.youtube.com/vi/nwS_HnwQ4wo/hqdefault.jpg";
  static const String _siteUrl = "https://kharid.tj";

  @override
  State<BonusScreen> createState() => _BonusScreenState();
}

class _BonusScreenState extends State<BonusScreen> {
  static const Color _gold = Color(0xFFFBBF24);
  static const Color _rowBlueDark = Color(0xFF0F2942);

  late final TextEditingController _avgCtrl;
  late final TextEditingController _partnersCtrl;

  bool _videoRu = true;

  static bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _pillInactive(BuildContext c) => _isDark(c) ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

  Color _onPage(BuildContext c) => Theme.of(c).colorScheme.onSurface;

  @override
  void initState() {
    super.initState();
    _avgCtrl = TextEditingController(text: "100");
    _partnersCtrl = TextEditingController(text: "5");
    _avgCtrl.addListener(() => setState(() {}));
    _partnersCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _avgCtrl.dispose();
    _partnersCtrl.dispose();
    super.dispose();
  }

  int get _avgOrder => int.tryParse(_avgCtrl.text.trim()) ?? 0;
  int get _partnersL1 => int.tryParse(_partnersCtrl.text.trim()) ?? 0;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Невозможно открыть: $url")));
    }
  }

  String _formatSom(num value) {
    final parts = value.toStringAsFixed(1).split(".");
    final intPart = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(" ");
      buf.write(intPart[i]);
    }
    return "${buf.toString()},$dec с.";
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Map<String, num>>[];
    num total = 0;
    var currentPeople = _partnersL1;
    for (var level = 1; level <= 6; level++) {
      final percent = level == 1 ? 5.0 : level == 2 ? 1.0 : 0.5;
      final amount = (_avgOrder * percent / 100) * currentPeople;
      total += amount;
      rows.add({"level": level, "people": currentPeople, "percent": percent, "amount": amount});
      currentPeople *= _partnersL1;
    }

    final videoUrl = _videoRu ? BonusScreen._youtubeCalcRu : BonusScreen._youtubeCalcTj;
    final thumbUrl = _videoRu ? BonusScreen._thumbRu : BonusScreen._thumbTj;
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
            SliverToBoxAdapter(child: const SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _calculatorCard(context, rows, total),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 20)),
            SliverToBoxAdapter(child: _videoModeTabs(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _videoBlock(context, videoUrl, thumbUrl),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 20)),
            SliverToBoxAdapter(child: _footerBlock(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  Widget _calculatorCard(BuildContext context, List<Map<String, num>> rows, num total) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(context);
    final on = _onPage(context);
    final subtitle = dark ? const Color(0xFF93C5FD) : scheme.primary.withValues(alpha: 0.92);

    final outerDecoration = dark
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B1220), Color(0xFF0A1A4A), Color(0xFF1E3A8A)],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 14)),
            ],
          )
        : BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: outerDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  "1234",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: -0.3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Бонусная программа Kharid.tj",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: dark ? Colors.white : on,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ) ??
                          TextStyle(color: dark ? Colors.white : on, fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Введите цифры — увидите свой потенциал дохода по 6 уровням.",
                      style: TextStyle(color: subtitle, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _inputField(
            context: context,
            icon: Icons.payments_outlined,
            label: "Средняя сумма заказа команды (сомони)",
            controller: _avgCtrl,
            dark: dark,
          ),
          const SizedBox(height: 14),
          _inputField(
            context: context,
            icon: Icons.groups_2_outlined,
            label: "Количество партнёров в 1 уровне",
            controller: _partnersCtrl,
            dark: dark,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4338CA)]),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _th("УРОВЕНЬ")),
                      Expanded(flex: 2, child: _th("КОЛ-ВО\nЛЮДЕЙ", align: TextAlign.center)),
                      Expanded(flex: 2, child: _th("БОНУС\n%", align: TextAlign.center)),
                      Expanded(
                        flex: 3,
                        child: _th("ДОХОД\n(сомони)", align: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                ...rows.asMap().entries.map((e) {
                  final r = e.value;
                  final isLast = e.key == rows.length - 1;
                  final rowBg = dark
                      ? _rowBlueDark
                      : (e.key.isEven ? const Color(0xFFF8FAFC) : const Color(0xFFEEF2FF));
                  final divider = dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Theme.of(context).dividerColor.withValues(alpha: 0.9);
                  final cellMain = dark ? Colors.white : const Color(0xFF0F172A);

                  return Container(
                    decoration: BoxDecoration(
                      color: rowBg,
                      border: isLast ? null : Border(bottom: BorderSide(color: divider)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${r["level"]}",
                            style: TextStyle(color: cellMain, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${r["people"]}",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cellMain, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${r["percent"]}%",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: dark ? _gold : const Color(0xFFD97706),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _formatSom(r["amount"]!),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: dark ? _gold : const Color(0xFFD97706),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Builder(
                  builder: (ctx) {
                    if (dark) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFF1E3A8A).withValues(alpha: 0.9),
                              const Color(0xFF0B1220).withValues(alpha: 0.95),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "Итого:",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.98),
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatSom(total),
                              style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE0E7FF), Color(0xFFF1F5F9)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Итого:",
                            style: TextStyle(
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatSom(total),
                            style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.98),
        fontWeight: FontWeight.w800,
        fontSize: 9.5,
        height: 1.2,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _inputField({
    required BuildContext context,
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool dark,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = dark ? const Color(0xFF93C5FD) : scheme.primary.withValues(alpha: 0.85);
    final border = Theme.of(context).dividerColor.withValues(alpha: dark ? 0.35 : 0.95);
    final fill = dark ? Colors.black.withValues(alpha: 0.28) : scheme.surfaceContainerHighest;
    final fg = dark ? Colors.white : _onPage(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: subtitle),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: dark ? Colors.white.withValues(alpha: 0.88) : fg.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _videoModeTabs(BuildContext context) {
    final dark = _isDark(context);
    final border = Theme.of(context).dividerColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? Colors.grey.shade700.withValues(alpha: 0.65) : border),
          color: dark ? Colors.black.withValues(alpha: 0.4) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        ),
        child: Row(
          children: [
            Expanded(
              child:
                  _modePill(context, label: "Калькулятор", selected: _videoRu, onTap: () => setState(() => _videoRu = true)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _modePill(context, label: "Ҳисобкунак", selected: !_videoRu, onTap: () => setState(() => _videoRu = false)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modePill(BuildContext context, {required String label, required bool selected, required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected
        ? scheme.onPrimary
        : (_isDark(context) ? Colors.white.withValues(alpha: 0.85) : _onPage(context).withValues(alpha: 0.88));

    return Material(
      color: selected ? scheme.primary : _pillInactive(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ),
    );
  }

  Widget _videoBlock(BuildContext context, String videoUrl, String thumbUrl) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => _openUrl(videoUrl),
              child: Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: _pillInactive(context),
                  alignment: Alignment.center,
                  child: Icon(Icons.play_circle_outline_rounded, color: _onPage(context).withValues(alpha: 0.4), size: 52),
                ),
              ),
            ),
            Material(
              color: Colors.black.withValues(alpha: 0.25),
              child: InkWell(
                onTap: () => _openUrl(videoUrl),
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
                onPressed: () => _openUrl(videoUrl),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                label: Text("YouTube", style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerBlock(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final on = _onPage(context).withValues(alpha: 0.92);
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
            style: style.titleSmall?.copyWith(
                  color: on,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ) ??
                TextStyle(color: on, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 22),
          Text(
            "Контакты",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _onPage(context).withValues(alpha: 0.96)),
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
              _social(context, Icons.language_rounded, () => _openUrl(BonusScreen._siteUrl)),
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
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: _onPage(context).withValues(alpha: 0.9)))),
          ],
        ),
      ),
    );
  }

  Widget _social(BuildContext context, IconData icon, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: _pillInactive(context),
      shape: CircleBorder(side: BorderSide(color: scheme.primary.withValues(alpha: _isDark(context) ? 0.25 : 0.35))),
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