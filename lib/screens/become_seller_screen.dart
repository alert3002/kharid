import "package:flutter/foundation.dart" show kDebugMode;
import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "package:youtube_player_flutter/youtube_player_flutter.dart";

import "../api_client.dart";
import "../app_state.dart";
import "../widgets/kharid_site_header.dart";

const String _kWebBase = String.fromEnvironment("WEB_BASE_URL", defaultValue: "https://kharid.tj");

/// YouTube: 11 символ. Барои тағйир: `--dart-define=BECOME_SELLER_RU_YOUTUBE=...`
const String _kRuYoutube = String.fromEnvironment("BECOME_SELLER_RU_YOUTUBE", defaultValue: "ENFAb4Wjkmg");
const String _kTjYoutube = String.fromEnvironment("BECOME_SELLER_TJ_YOUTUBE", defaultValue: "BXnVMHNdVtQ");

/// Reels дар сайт — Cloudflare Stream (`cloudflare_video_uid`).
const String _kTjCloudflareUid = String.fromEnvironment("BECOME_SELLER_TJ_CLOUDFLARE_UID", defaultValue: "");

/// Instagram / Facebook reel — URL-и пурра; дар барнома embed мекушояд.
const String _kTjSocialUrl = String.fromEnvironment("BECOME_SELLER_TJ_SOCIAL_URL", defaultValue: "");

enum _VideoTab { ru, tj }

String _watchUrl(String id) => "https://www.youtube.com/watch?v=${Uri.encodeComponent(id)}";

bool _isValidYoutubeId(String? id) {
  if (id == null) return false;
  return id.trim().length == 11;
}

Uri? _cloudflareEmbedUri(String uid) {
  final u = uid.trim();
  if (u.isEmpty) return null;
  return Uri.parse("https://iframe.videodelivery.net/${Uri.encodeComponent(u)}?autoplay=false&muted=false&loop=true&preload=true");
}

Uri? _socialEmbedUri(String watchUrl) {
  final raw = watchUrl.trim();
  if (raw.isEmpty) return null;
  final u = Uri.tryParse(raw);
  if (u == null) return null;
  final host = u.host.toLowerCase();
  if (host.contains("instagram.com")) {
    final segs = u.pathSegments;
    for (var i = 0; i < segs.length; i++) {
      if ((segs[i] == "reel" || segs[i] == "reels") && i + 1 < segs.length) {
        final code = segs[i + 1];
        if (code.isNotEmpty) {
          return Uri.parse("https://www.instagram.com/reel/$code/embed/?cr=1");
        }
      }
    }
    return u;
  }
  if (host.contains("facebook.com")) {
    return Uri.parse("https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(raw)}&show_text=false&width=476");
  }
  return u;
}

class _BecomeSellerClip {
  const _BecomeSellerClip({required this.label, this.youtubeId, this.embedUri, this.fallbackOpenUrl});

  final String label;
  final String? youtubeId;
  final Uri? embedUri;
  final String? fallbackOpenUrl;
}

_BecomeSellerClip _clipForTab(_VideoTab tab) {
  if (tab == _VideoTab.ru) {
    return _BecomeSellerClip(label: "Регистрация", youtubeId: _kRuYoutube);
  }
  final cf = _kTjCloudflareUid.trim();
  if (cf.isNotEmpty) {
    final embed = _cloudflareEmbedUri(cf);
    if (embed != null) {
      return _BecomeSellerClip(label: "Бақайдгирӣ", embedUri: embed, fallbackOpenUrl: embed.toString());
    }
  }
  final soc = _kTjSocialUrl.trim();
  if (soc.isNotEmpty) {
    final embed = _socialEmbedUri(soc);
    if (embed != null) {
      return _BecomeSellerClip(label: "Бақайдгирӣ", embedUri: embed, fallbackOpenUrl: soc);
    }
  }
  return _BecomeSellerClip(label: "Бақайдгирӣ", youtubeId: _kTjYoutube);
}

String? _openUrlForClip(_BecomeSellerClip c) {
  if (_isValidYoutubeId(c.youtubeId)) return _watchUrl(c.youtubeId!.trim());
  if (c.fallbackOpenUrl != null && c.fallbackOpenUrl!.trim().isNotEmpty) return c.fallbackOpenUrl!.trim();
  if (c.embedUri != null) return c.embedUri.toString();
  return null;
}

class BecomeSellerScreen extends StatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  State<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends State<BecomeSellerScreen> {
  _VideoTab _tab = _VideoTab.ru;
  YoutubePlayerController? _youtubeController;

  Map<String, dynamic>? _sellerApp;
  bool _appLoading = false;

  final _storeName = TextEditingController();
  final _storeCity = TextEditingController();
  final _storeAddress = TextEditingController();
  XFile? _logo;

  bool _submitBusy = false;
  String? _submitError;
  bool _submitOk = false;

  @override
  void initState() {
    super.initState();
    final clip = _clipForTab(_tab);
    if (_isValidYoutubeId(clip.youtubeId)) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: clip.youtubeId!.trim(),
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false, enableCaption: false),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromMe();
      _loadSellerApplication();
    });
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _storeName.dispose();
    _storeCity.dispose();
    _storeAddress.dispose();
    super.dispose();
  }

  void _setTab(_VideoTab t) {
    if (_tab == t) return;
    final prev = _youtubeController;
    YoutubePlayerController? next;
    final clip = _clipForTab(t);
    if (_isValidYoutubeId(clip.youtubeId)) {
      next = YoutubePlayerController(
        initialVideoId: clip.youtubeId!.trim(),
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false, enableCaption: false),
      );
    }
    setState(() {
      _tab = t;
      _youtubeController = next;
    });
    prev?.dispose();
  }

  Widget _buildMediaSlot(bool isDark) {
    final clip = _clipForTab(_tab);
    if (_youtubeController != null && _isValidYoutubeId(clip.youtubeId)) {
      return YoutubePlayer(
        key: ValueKey<String>("yt-${clip.youtubeId!}"),
        controller: _youtubeController!,
        aspectRatio: 16 / 9,
        showVideoProgressIndicator: true,
      );
    }
    if (clip.embedUri != null) {
      return _ClipEmbedView(uri: clip.embedUri!);
    }
    return _FallbackOpenClip(clip: clip, isDark: isDark);
  }

  void _syncFromMe() {
    final m = context.read<AppState>().me;
    if (m == null) return;
    if (_storeName.text.trim().isEmpty) _storeName.text = (m.storeName ?? "").trim();
    if (_storeCity.text.trim().isEmpty) _storeCity.text = (m.storeCity ?? "").trim();
    if (_storeAddress.text.trim().isEmpty) _storeAddress.text = (m.storeAddress ?? "").trim();
  }

  Future<void> _loadSellerApplication() async {
    final app = context.read<AppState>();
    if (!app.isAuthenticated) {
      setState(() => _sellerApp = null);
      return;
    }
    setState(() => _appLoading = true);
    try {
      Map<String, dynamic>? data;
      try {
        data = await app.api.sellerApplicationMy(app.accessToken!);
      } on ApiUnauthorized {
        if (await app.tryRefreshAccessToken()) {
          data = await app.api.sellerApplicationMy(app.accessToken!);
        }
      }
      if (mounted) setState(() => _sellerApp = data);
    } catch (_) {
      if (mounted) setState(() => _sellerApp = null);
    } finally {
      if (mounted) setState(() => _appLoading = false);
    }
  }

  Future<void> _openSellerCabinet() async {
    final uri = Uri.parse("$_kWebBase/account/seller/products");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _logo = x);
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    setState(() {
      _submitBusy = true;
      _submitError = null;
      _submitOk = false;
    });
    try {
      var token = app.accessToken;
      if (token == null || token.isEmpty) {
        setState(() => _submitError = "Сначала войдите в аккаунт.");
        return;
      }
      Future<Map<String, dynamic>> post(String t) {
        return app.api.sellerApplicationSubmit(
          accessToken: t,
          storeName: _storeName.text,
          storeCity: _storeCity.text,
          storeAddress: _storeAddress.text,
          storeLogo: _logo,
        );
      }

      Map<String, dynamic> data;
      try {
        data = await post(token);
      } on ApiUnauthorized {
        if (!await app.tryRefreshAccessToken()) {
          setState(() => _submitError = "Сессия истекла. Войдите снова.");
          return;
        }
        token = app.accessToken;
        if (token == null) {
          setState(() => _submitError = "Сессия истекла. Войдите снова.");
          return;
        }
        data = await post(token);
      }

      if (!mounted) return;
      setState(() {
        _sellerApp = data;
        _submitOk = true;
      });
      await app.loadMe();
    } catch (e) {
      if (mounted) setState(() => _submitError = "$e");
    } finally {
      if (mounted) setState(() => _submitBusy = false);
    }
  }

  ({String text, Color fg, Color bg, Color border}) _statusBadge(String? status) {
    switch (status) {
      case "approved":
        return (
          text: "Одобрено",
          fg: const Color(0xFF6EE7B7),
          bg: const Color(0xFF064E3B).withValues(alpha: 0.35),
          border: const Color(0xFF34D399).withValues(alpha: 0.35),
        );
      case "rejected":
        return (
          text: "Отклонено",
          fg: const Color(0xFFFBCFE8),
          bg: const Color(0xFF881337).withValues(alpha: 0.35),
          border: const Color(0xFFF472B6).withValues(alpha: 0.35),
        );
      default:
        return (
          text: "На рассмотрении",
          fg: const Color(0xFFFDE68A),
          bg: const Color(0xFF78350F).withValues(alpha: 0.35),
          border: const Color(0xFFFBBF24).withValues(alpha: 0.35),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF0C1222) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Consumer<AppState>(
      builder: (context, app, _) {
        final me = app.me;
        final meLoading = app.isAuthenticated && me == null;
        final isAnon = !app.isAuthenticated;
        final role = me?.role ?? "";
        final canApply = role == "client" || role == "partner" || role == "courier";
        final alreadySeller = role == "seller";
        final isStaff = role == "admin" || role == "moderator";
        final appStatus = _sellerApp?["status"]?.toString();
        final badge = _sellerApp != null ? _statusBadge(appStatus) : null;

        return Scaffold(
          backgroundColor: bg,
          appBar: KharidSiteHeader(
            onMenuPressed: () => app.openSideMenuFrom(context),
            subtitle: null,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                "Стать продавцом",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: titleColor, letterSpacing: -0.5),
              ),
              if (!alreadySeller) ...[
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 14, height: 1.45, color: muted, fontWeight: FontWeight.w600),
                    children: [
                      const TextSpan(text: "Хотите продавать на "),
                      TextSpan(text: "Kharid.tj", style: TextStyle(color: titleColor, fontWeight: FontWeight.w900)),
                      const TextSpan(text: "? Посмотрите видео и отправьте заявку — админ активирует роль продавца."),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              _PillTabs(
                isDark: isDark,
                tab: _tab,
                onChanged: _setTab,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.12)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildMediaSlot(isDark),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cardBorder),
                  boxShadow: isDark ? null : const [BoxShadow(color: Color(0x120F172A), blurRadius: 24, offset: Offset(0, 12))],
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Заявка на продавца",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: titleColor),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badge.bg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: badge.border),
                            ),
                            child: Text(badge.text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badge.fg)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (meLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text("Загрузка…", style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                      )
                    else if (isAnon) ...[
                      Text("Сначала войдите в аккаунт.", style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _InlinePhoneAuth(
                        api: app.api,
                        onLoggedIn: () async {
                          if (!mounted) return;
                          _syncFromMe();
                          await _loadSellerApplication();
                          if (mounted) setState(() {});
                        },
                      ),
                    ] else if (alreadySeller)
                      _InfoBox(
                        isDark: isDark,
                        border: const Color(0xFF34D399).withValues(alpha: 0.45),
                        bg: const Color(0xFF064E3B).withValues(alpha: 0.25),
                        fg: const Color(0xFFD1FAE5),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            const Text("Вы уже зарегистрированы как продавец."),
                            GestureDetector(
                              onTap: _openSellerCabinet,
                              child: const Text(
                                "Перейти в кабинет →",
                                style: TextStyle(fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isStaff)
                      _InfoBox(
                        isDark: isDark,
                        border: cardBorder,
                        bg: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
                        fg: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        child: const Text("Для вашей роли заявка не требуется."),
                      )
                    else ...[
                      if (_appLoading)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text("Проверяем заявки…", style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                        ),
                      if (appStatus == "approved")
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InfoBox(
                            isDark: isDark,
                            border: const Color(0xFF34D399).withValues(alpha: 0.45),
                            bg: const Color(0xFF064E3B).withValues(alpha: 0.25),
                            fg: const Color(0xFFD1FAE5),
                            child: const Text("Заявка одобрена. Зайдите снова, если роль ещё не обновилась."),
                          ),
                        ),
                      if (appStatus == "rejected")
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InfoBox(
                            isDark: isDark,
                            border: const Color(0xFFF472B6).withValues(alpha: 0.45),
                            bg: const Color(0xFF881337).withValues(alpha: 0.25),
                            fg: const Color(0xFFFCE7F3),
                            child: Text(
                              "Заявка отклонена.${_sellerApp?["admin_note"] != null && (_sellerApp!["admin_note"].toString().isNotEmpty) ? " Комментарий: ${_sellerApp!["admin_note"]}" : ""}",
                            ),
                          ),
                        ),
                      if (!canApply)
                        _InfoBox(
                          isDark: isDark,
                          border: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                          bg: const Color(0xFF78350F).withValues(alpha: 0.25),
                          fg: const Color(0xFFFEF3C7),
                          child: const Text("Для вашей роли заявка недоступна."),
                        )
                      else if (appStatus == "pending")
                        _InfoBox(
                          isDark: isDark,
                          border: cardBorder,
                          bg: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
                          fg: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          child: const Text("Заявка уже отправлена и находится на рассмотрении."),
                        )
                      else ...[
                        _LabeledField(
                          isDark: isDark,
                          label: "Название магазина",
                          controller: _storeName,
                          hint: "Например: Магазин электроники",
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _LabeledField(
                                isDark: isDark,
                                label: "Город",
                                controller: _storeCity,
                                hint: "Душанбе",
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Лого / фото", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                                  const SizedBox(height: 6),
                                  OutlinedButton(
                                    onPressed: _pickLogo,
                                    child: Text(_logo == null ? "Выбрать файл" : "Файл выбран", overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _LabeledField(
                          isDark: isDark,
                          label: "Адрес",
                          controller: _storeAddress,
                          hint: "Улица, дом, ориентир…",
                          maxLines: 3,
                        ),
                        if (_submitError != null) ...[
                          const SizedBox(height: 10),
                          _InfoBox(
                            isDark: isDark,
                            border: const Color(0xFFF87171).withValues(alpha: 0.5),
                            bg: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
                            fg: const Color(0xFFFECACA),
                            child: Text(_submitError!),
                          ),
                        ],
                        if (_submitOk) ...[
                          const SizedBox(height: 10),
                          _InfoBox(
                            isDark: isDark,
                            border: const Color(0xFF34D399).withValues(alpha: 0.45),
                            bg: const Color(0xFF064E3B).withValues(alpha: 0.25),
                            fg: const Color(0xFFD1FAE5),
                            child: const Text("Заявка отправлена. Мы рассмотрим её и активируем роль продавца."),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitBusy || _storeName.text.trim().length < 2 ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0008C7),
                              disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(_submitBusy ? "Отправляем…" : "Оставить заявку", style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "После одобрения админ заполнит/проверит данные магазина и выдаст роль «Продавец».",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClipEmbedView extends StatelessWidget {
  const _ClipEmbedView({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
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
}

class _FallbackOpenClip extends StatelessWidget {
  const _FallbackOpenClip({required this.clip, required this.isDark});

  final _BecomeSellerClip clip;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final url = _openUrlForClip(clip);
    final isYt = _isValidYoutubeId(clip.youtubeId);
    final hint = isYt
        ? "Плеер недоступен — откройте ролик в YouTube."
        : "Откройте ролик в браузере (Instagram / Facebook или прямая ссылка).";

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_fill_rounded, size: 56, color: Color(0xFF2563EB)),
              const SizedBox(height: 12),
              Text(
                clip.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(isYt ? "Смотреть на YouTube" : "Кушодан дар браузер"),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0008C7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.isDark, required this.tab, required this.onChanged});

  final bool isDark;
  final _VideoTab tab;
  final ValueChanged<_VideoTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final track = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : const Color(0xFFF1F5F9);
    final border = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.8)),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          for (final id in [_VideoTab.ru, _VideoTab.tj])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: tab == id ? const LinearGradient(colors: [Color(0xFF0008C7), Color(0xFF4F46E5)]) : null,
                    color: tab == id ? null : Colors.transparent,
                    boxShadow: tab == id ? [BoxShadow(color: const Color(0xFF0008C7).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    id == _VideoTab.ru ? "Регистрация" : "Бақайдгирӣ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: tab == id ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
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

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.isDark, required this.border, required this.bg, required this.fg, required this.child});

  final bool isDark;
  final Color border;
  final Color bg;
  final Color fg;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: DefaultTextStyle(style: TextStyle(fontSize: 14, height: 1.35, color: fg, fontWeight: FontWeight.w600), child: child),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.isDark,
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final bool isDark;
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: labelColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            filled: true,
            fillColor: isDark ? const Color(0xFF101826) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0008C7), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlinePhoneAuth extends StatefulWidget {
  const _InlinePhoneAuth({required this.api, required this.onLoggedIn});

  final ApiClient api;
  final Future<void> Function() onLoggedIn;

  @override
  State<_InlinePhoneAuth> createState() => _InlinePhoneAuthState();
}

class _InlinePhoneAuthState extends State<_InlinePhoneAuth> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _city = TextEditingController(text: "Душанбе");
  bool _requested = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: "Телефон", hintText: "+992…"),
        ),
        if (_requested) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Код из SMS"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: "Город", hintText: "Душанбе"),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    final app = context.read<AppState>();
                    if (!_requested) {
                      await widget.api.requestOtp(_phone.text.trim());
                      setState(() => _requested = true);
                    } else {
                      final v = await widget.api.verifyOtp(_phone.text.trim(), _code.text.trim());
                      if (v["registered"] == true) {
                        await app.loginByTokens(v["access"].toString(), v["refresh"].toString());
                      } else {
                        final tok = v["registration_token"]?.toString();
                        if (tok == null) throw Exception("Нет registration_token");
                        final r = await widget.api.register(
                          registrationToken: tok,
                          role: "client",
                          city: _city.text.trim().isEmpty ? "Душанбе" : _city.text.trim(),
                        );
                        await app.loginByTokens(r["access"].toString(), r["refresh"].toString());
                      }
                      await widget.onLoggedIn();
                    }
                  } catch (e) {
                    setState(() => _error = "$e");
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? "…" : (_requested ? "Подтвердить" : "Получить код")),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)))),
      ],
    );
  }
}
