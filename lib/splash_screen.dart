import "package:flutter/material.dart";

import "api_client.dart";
import "app_shell_v2.dart";
import "app_state.dart";
import "kharid_assets.dart";

/// Экрани боздоштан: «Маркетплейс», логотип, счётчик 10–100%.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key, required this.api, required this.state});

  final ApiClient api;
  final AppState state;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  static const _brand = Color(0xFF2563EB);

  int _percent = 10;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final anim = _animateProgress();
    final init = widget.state.init();
    await Future.wait([anim, init]);
    if (!mounted) return;
    setState(() {
      _percent = 100;
      _ready = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => AppShellV2(api: widget.api),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _animateProgress() async {
    const steps = <int>[10, 18, 26, 34, 42, 50, 58, 66, 74, 82, 90, 96, 100];
    for (final p in steps) {
      if (!mounted) return;
      setState(() => _percent = p);
      await Future<void>.delayed(const Duration(milliseconds: 95));
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const titleColor = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Маркетплейс",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Image.asset(
                      KharidAssets.logoSquare,
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          "kharid.tj",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  "$_percent%",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _ready ? _brand : titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _ready ? "Готово" : "Загрузка…",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _percent / 100,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: _brand,
                    ),
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
