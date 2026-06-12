import "package:flutter/foundation.dart" show kDebugMode;
import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "api_client.dart";
import "app_state.dart";
import "unified_referrals_screen.dart";
import "widgets/kharid_site_header.dart";

const _mlmRequestTelegram = "https://t.me/kharid24tj";
const _brand = Color(0xFF2563EB);

/// Таби поён «МЛМ» — монанди `frontend/components/dashboards/sections/mlm.tsx`.
class MlmTab extends StatefulWidget {
  const MlmTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<MlmTab> createState() => _MlmTabState();
}

class _MlmTabState extends State<MlmTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      if (app.isAuthenticated && app.me == null) {
        app.loadMe();
      }
    });
  }

  void _openMlmRequest(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MlmTelegramRequestScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final header = KharidSiteHeader(
      onMenuPressed: () => app.openSideMenuFrom(context),
      showBackWhenCanPop: false,
    );

    Widget body;
    if (!app.isAuthenticated) {
      body = _MlmLoginPrompt(
        onGoProfile: () => app.requestSwitchTab(4),
      );
    } else if (app.me == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!app.me!.mlmMember) {
      body = _MlmInactiveCard(onRequest: () => _openMlmRequest(context));
    } else {
      final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 58 + 12 + 8;
      body = ReferralsBody(api: widget.api, bottomPadding: bottomPad);
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: header.preferredSize.height, child: header),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Карта «MLM не активен» — 1:1 ба фронтенд.
class _MlmInactiveCard extends StatelessWidget {
  const _MlmInactiveCard({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155).withValues(alpha: 0.8) : const Color(0xFFE2E8F0).withValues(alpha: 0.9);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [Colors.white, Colors.white, const Color(0xFFF8FAFC).withValues(alpha: 0.9)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -48,
                  top: -48,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _brand.withValues(alpha: isDark ? 0.1 : 0.15),
                    ),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.05 : 0.1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _brand.withValues(alpha: 0.22)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Icon(Icons.share_rounded, size: 28, color: _brand),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "MLM для вас не активен",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Хотите участвовать в реферальной программе? Оставьте запрос — мы рассмотрим обращение и свяжемся с вами.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: muted, height: 1.45),
                      ),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, c) {
                          final fullWidth = c.maxWidth < 480;
                          return Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: fullWidth ? double.infinity : null,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 220),
                                child: _MlmSubmitRequestButton(onPressed: onRequest),
                              ),
                            ),
                          );
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
    );
  }
}

/// Тугма «Подать запрос» — матн + стрелка ба рост, монанди `mlm.tsx`.
class _MlmSubmitRequestButton extends StatelessWidget {
  const _MlmSubmitRequestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _brand,
      elevation: 4,
      shadowColor: _brand.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Подать запрос",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xE6FFFFFF)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Telegram дар дохили барнома (WebView), на браузери берун.
class MlmTelegramRequestScreen extends StatefulWidget {
  const MlmTelegramRequestScreen({super.key});

  @override
  State<MlmTelegramRequestScreen> createState() => _MlmTelegramRequestScreenState();
}

class _MlmTelegramRequestScreenState extends State<MlmTelegramRequestScreen> {
  double _progress = 0;
  bool _loading = true;

  Future<void> _openExternally() async {
    final uri = Uri.parse(_mlmRequestTelegram);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF020617) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF061433) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        title: const Text("Подать запрос", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: "Открыть в Telegram",
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading)
            LinearProgressIndicator(
              value: _progress > 0 && _progress < 1 ? _progress : null,
              minHeight: 2,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              color: _brand,
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_mlmRequestTelegram)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                isInspectable: kDebugMode,
              ),
              onProgressChanged: (_, p) {
                if (!mounted) return;
                setState(() {
                  _progress = p / 100;
                  if (p >= 100) _loading = false;
                });
              },
              onLoadStop: (_, __) {
                if (mounted) setState(() => _loading = false);
              },
              onReceivedError: (_, __, ___) {
                if (mounted) setState(() => _loading = false);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MlmLoginPrompt extends StatelessWidget {
  const _MlmLoginPrompt({required this.onGoProfile});

  final VoidCallback onGoProfile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_rounded, size: 48, color: isDark ? const Color(0xFF60A5FA) : _brand),
            const SizedBox(height: 16),
            Text(
              "Войдите в аккаунт",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor),
            ),
            const SizedBox(height: 8),
            Text(
              "Раздел MLM и реферальная программа доступны после входа.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onGoProfile,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Перейти в профиль", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
