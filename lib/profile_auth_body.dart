import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "screens/about_screen.dart";
import "api_client.dart";
import "app_state.dart";
import "models.dart";
import "widgets/app_logo.dart";

const _kSiteOrigin = "https://kharid.tj";
const _kBrand = Color(0xFF2563EB);
const _kCourierTypes = ["Пешком", "На велосипеде", "На скутере", "На машине"];

class _FooterLink {
  const _FooterLink(this.label, this.href);
  final String label;
  final String href;
}

const _kLearn = [
  _FooterLink("О Kharid.tj", "/about"),
  _FooterLink("Партнёры", "/partners"),
];
const _kSupport = [
  _FooterLink("Центр помощи", "/help"),
  _FooterLink("Вопрос / ответ", "/faq"),
  _FooterLink("Обратная связь", "/feedback"),
  _FooterLink("Способ оплаты", "/payment"),
];
const _kOrders = [
  _FooterLink("Доставка & отправка", "/delivery"),
  _FooterLink("Возврат & обмен", "/returns"),
  _FooterLink("Гарантия лучшей цены", "/best-price"),
];

String _onlyDigits(String s) => s.replaceAll(RegExp(r"\D"), "");

/// Локалӣ: то 9 рақам, намоиш ба шакли `92 123 45 67`.
/// [composing] ҳамеша хол — барои кори дурусти клавиатураи Android/Gboard.
class _TjLocalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = _onlyDigits(newValue.text);
    if (d.startsWith("992")) {
      d = d.length > 3 ? d.substring(3) : "";
    }
    if (d.length > 9) d = d.substring(0, 9);

    if (d.isEmpty) {
      return const TextEditingValue(
        text: "",
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }

    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5 || i == 7) buf.write(" ");
      buf.write(d[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _openFooterLink(BuildContext context, _FooterLink link) async {
  switch (link.href) {
    case "/about":
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
    case "/faq":
      await _openUrl("https://t.me/kharid24tj");
    default:
      await _openUrl("$_kSiteOrigin${link.href}");
  }
}

/// Танаи scroll барои таби «Профиль» — вақте корбар ворид нашудааст (монанди веб: [AccountAuthClient] + футер).
class ProfileAuthScrollBody extends StatefulWidget {
  const ProfileAuthScrollBody({
    super.key,
    required this.api,
    required this.bottomPadding,
    this.includeSiteFooter = true,
    this.transparentPageBackground = false,
    this.shrinkWrapScroll = false,
    this.showMainTitle = true,
    this.onSellerLoggedIn,
    this.onCourierLoggedIn,
    this.onClientLoggedIn,
    this.onPartnerLoggedIn,
  });
  final ApiClient api;
  final double bottomPadding;
  /// Дар корзина танҳо корти воридшавӣ — бе блоки футери сайт.
  final bool includeSiteFooter;
  /// Дар embed ҳамон scaffoldBackgroundColor-и волида истифода шавад.
  final bool transparentPageBackground;
  /// Дар embed дохили scroll-и волида — скролли дубора нест.
  final bool shrinkWrapScroll;
  /// Сарлавҳаи «Вход / Регистрация» — дар корзина пинҳон.
  final bool showMainTitle;
  /// Пас аз воридшавӣ агар [MeProfile.role] баробари `seller` бошад (нав ба «Мои товары» аз [app_shell_v2]).
  final void Function(BuildContext context)? onSellerLoggedIn;
  /// Пас аз воридшавӣ агар рол `courier` бошад (нав ба «Мои доставки»).
  final void Function(BuildContext context)? onCourierLoggedIn;
  /// Пас аз воридшавӣ агар рол `client` бошад (нав ба «Мои заказы»).
  final void Function(BuildContext context)? onClientLoggedIn;
  /// Пас аз воридшавӣ агар рол `partner` бошад (нав ба «Мои заказы»).
  final void Function(BuildContext context)? onPartnerLoggedIn;

  @override
  State<ProfileAuthScrollBody> createState() => _ProfileAuthScrollBodyState();
}

enum _AuthStep { phone, code, register }

class _ProfileAuthScrollBodyState extends State<ProfileAuthScrollBody> {
  _AuthStep _step = _AuthStep.phone;
  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _referralCtl = TextEditingController();
  final _storeNameCtl = TextEditingController();
  final _storeAddressCtl = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  String? _error;
  int _resendLeftSec = 0;
  Timer? _resendTimer;
  bool _autoSubmitArmed = true;
  String? _registrationToken;

  String _role = "client";
  String _storeCity = "";
  String _courierCity = "";
  String _deliveryType = _kCourierTypes.first;
  List<City> _cities = const [];
  bool _citiesLoading = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtl.dispose();
    _codeCtl.dispose();
    _referralCtl.dispose();
    _storeNameCtl.dispose();
    _storeAddressCtl.dispose();
    super.dispose();
  }

  String get _phoneFull {
    final d = _onlyDigits(_phoneCtl.text);
    return d.length == 9 ? "992$d" : "";
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendLeftSec = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendLeftSec <= 1) {
        t.cancel();
        setState(() => _resendLeftSec = 0);
      } else {
        setState(() => _resendLeftSec--);
      }
    });
  }

  Future<void> _loadCities() async {
    if (_citiesLoading || _cities.isNotEmpty) return;
    setState(() => _citiesLoading = true);
    try {
      final list = await widget.api.cities();
      if (!mounted) return;
      setState(() {
        _cities = list;
        if (_storeCity.isEmpty && list.isNotEmpty) _storeCity = list.first.name;
        if (_courierCity.isEmpty && list.isNotEmpty) _courierCity = list.first.name;
      });
    } catch (_) {
      /* UI бо рӯйхати холӣ */
    } finally {
      if (mounted) setState(() => _citiesLoading = false);
    }
  }

  Future<void> _sendCode() async {
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      final d = _onlyDigits(_phoneCtl.text);
      if (d.length != 9) {
        setState(() => _error = "Введите номер правильно (92 123 45 67).");
        return;
      }
      final full = _phoneFull;
      await widget.api.requestOtp(full);
      if (!mounted) return;
      setState(() {
        _step = _AuthStep.code;
        _codeCtl.clear();
        _autoSubmitArmed = true;
      });
      _startResendCountdown();
    } catch (e) {
      if (mounted) setState(() => _error = "$e".replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final app = context.read<AppState>();
    final c = _onlyDigits(_codeCtl.text);
    if (c.length != 4) {
      setState(() => _error = "Код должен быть из 4 цифр.");
      return;
    }
    if (_verifying) return;
    setState(() {
      _error = null;
      _verifying = true;
    });
    try {
      final data = await widget.api.verifyOtp(_phoneFull, c);
      if (!mounted) return;
      if (data["registered"] == true) {
        await app.loginByTokens(data["access"].toString(), data["refresh"].toString());
        if (!mounted) return;
        if (app.me?.role == "seller" && widget.onSellerLoggedIn != null) {
          widget.onSellerLoggedIn!(context);
          return;
        }
        if (app.me?.role == "courier" && widget.onCourierLoggedIn != null) {
          widget.onCourierLoggedIn!(context);
          return;
        }
        if (app.me?.role == "client" && widget.onClientLoggedIn != null) {
          widget.onClientLoggedIn!(context);
          return;
        }
        if (app.me?.role == "partner" && widget.onPartnerLoggedIn != null) {
          widget.onPartnerLoggedIn!(context);
          return;
        }
        return;
      }
      setState(() {
        _registrationToken = data["registration_token"]?.toString();
        _step = _AuthStep.register;
      });
      await _loadCities();
    } catch (e) {
      if (mounted) setState(() => _error = "$e".replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _register() async {
    final app = context.read<AppState>();
    final tok = _registrationToken;
    if (tok == null || tok.isEmpty) {
      setState(() => _error = "Токен регистрации отсутствует.");
      return;
    }
    if (_role == "partner" && _referralCtl.text.trim().isEmpty) {
      setState(() => _error = "Введите реферальный код (обязательно для партнёра).");
      return;
    }
    if (_role == "seller") {
      if (_storeNameCtl.text.trim().isEmpty) {
        setState(() => _error = "Укажите название магазина.");
        return;
      }
      if (_storeCity.trim().isEmpty) {
        setState(() => _error = "Выберите город.");
        return;
      }
      if (_storeAddressCtl.text.trim().isEmpty) {
        setState(() => _error = "Укажите адрес магазина.");
        return;
      }
    }
    if (_role == "courier") {
      if (_courierCity.trim().isEmpty) {
        setState(() => _error = "Выберите город.");
        return;
      }
      if (_deliveryType.trim().isEmpty) {
        setState(() => _error = "Выберите тип доставки.");
        return;
      }
    }

    setState(() {
      _error = null;
      _verifying = true;
    });
    try {
      final r = await widget.api.register(
        registrationToken: tok,
        role: _role,
        city: _role == "courier" ? _courierCity : "",
        referralCode: _role == "partner" ? _referralCtl.text : null,
        storeName: _role == "seller" ? _storeNameCtl.text : null,
        storeCity: _role == "seller" ? _storeCity : null,
        storeAddress: _role == "seller" ? _storeAddressCtl.text : null,
        deliveryType: _role == "courier" ? _deliveryType : null,
      );
      if (!mounted) return;
      await app.loginByTokens(r["access"].toString(), r["refresh"].toString());
      if (!mounted) return;
      if (app.me?.role == "seller" && widget.onSellerLoggedIn != null) {
        widget.onSellerLoggedIn!(context);
      } else if (app.me?.role == "courier" && widget.onCourierLoggedIn != null) {
        widget.onCourierLoggedIn!(context);
      } else if (app.me?.role == "client" && widget.onClientLoggedIn != null) {
        widget.onClientLoggedIn!(context);
      } else if (app.me?.role == "partner" && widget.onPartnerLoggedIn != null) {
        widget.onPartnerLoggedIn!(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = "$e".replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _onCodeChanged(String _) {
    if (_step != _AuthStep.code) return;
    final c = _onlyDigits(_codeCtl.text);
    if (c.length != 4) {
      setState(() => _autoSubmitArmed = true);
      return;
    }
    if (!_autoSubmitArmed || _verifying) return;
    setState(() => _autoSubmitArmed = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _verifyCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final labelColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? Colors.black : Colors.white;
    final prefixBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);

    final pad = EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding + 16);
    final columnChild = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder.withValues(alpha: 0.85)),
            boxShadow: isDark ? null : const [BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showMainTitle) ...[
                  Text(
                    "Вход / Регистрация",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor),
                  ),
                ],
                if (_error != null) ...[
                  SizedBox(height: widget.showMainTitle ? 14 : 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECDD3)),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFECACA) : const Color(0xFF9F1239),
                      ),
                    ),
                  ),
                ],
                if (_step == _AuthStep.phone) _buildPhoneStep(isDark, labelColor, muted, inputBg, prefixBg, cardBorder, topGap: widget.showMainTitle ? 20.0 : 10.0),
                if (_step == _AuthStep.code) _buildCodeStep(isDark, titleColor, labelColor, muted, inputBg, cardBorder),
                if (_step == _AuthStep.register) _buildRegisterStep(isDark, titleColor, labelColor, muted, inputBg, cardBorder),
              ],
            ),
          ),
        ),
        if (widget.includeSiteFooter) ...[
          const SizedBox(height: 22),
          _ProfileAuthFooter(isDark: isDark, titleColor: titleColor, muted: muted, borderColor: cardBorder),
        ],
      ],
    );

    return ColoredBox(
      color: widget.transparentPageBackground ? Colors.transparent : pageBg,
      child: widget.shrinkWrapScroll
          ? Padding(padding: pad, child: columnChild)
          : SingleChildScrollView(padding: pad, child: columnChild),
    );
  }

  Widget _buildPhoneStep(bool isDark, Color labelColor, Color muted, Color inputBg, Color prefixBg, Color border, {double topGap = 20}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topGap),
        Text("Номер телефона", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
            boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 4, offset: Offset(0, 1))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                color: prefixBg,
                child: Text(
                  "+992",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: labelColor),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtl,
                  keyboardType: TextInputType.phone,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _TjLocalPhoneFormatter(),
                  ],
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: "92 123 45 67",
                    hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _sending ? null : _sendCode,
            style: FilledButton.styleFrom(
              backgroundColor: _kBrand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            child: Text(_sending ? "Отправка…" : "Отправить код"),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep(
    bool isDark,
    Color titleColor,
    Color labelColor,
    Color muted,
    Color inputBg,
    Color border,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text("Код (4 цифры)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _codeCtl,
          onChanged: _onCodeChanged,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: titleColor,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: inputBg,
            hintText: "____",
            hintStyle: TextStyle(color: muted, letterSpacing: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: _resendLeftSec > 0
              ? Text(
                  "Отправить ещё код через $_resendLeftSec сек",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                )
              : TextButton(
                  onPressed: _sending ? null : _sendCode,
                  child: Text(
                    "Отправить ещё код",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFBFDBFE) : _kBrand,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _verifying
                    ? null
                    : () {
                        setState(() {
                          _step = _AuthStep.phone;
                          _codeCtl.clear();
                          _resendLeftSec = 0;
                          _autoSubmitArmed = true;
                          _error = null;
                        });
                        _resendTimer?.cancel();
                      },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                  foregroundColor: labelColor,
                ),
                child: const Text("Назад", style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _verifying ? null : _verifyCode,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: _kBrand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_verifying ? "Проверка…" : "Подтвердить", style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterStep(
    bool isDark,
    Color titleColor,
    Color labelColor,
    Color muted,
    Color inputBg,
    Color border,
  ) {
    final digits = _onlyDigits(_phoneCtl.text);
    final phonePretty = digits.length == 9
        ? "+992 ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 7)} ${digits.substring(7, 9)}"
        : "+992 …";

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint.isEmpty ? null : hint,
          filled: true,
          fillColor: inputBg,
          hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );

    InputDecoration dropdownShell() => InputDecoration(
          filled: true,
          fillColor: inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        );

    String pickCity(String current) {
      if (_cities.isEmpty) return current;
      return _cities.any((c) => c.name == current) ? current : _cities.first.name;
    }

    final storeCityVal = pickCity(_storeCity);
    final courierCityVal = pickCity(_courierCity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
          ),
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 13, color: labelColor, height: 1.35),
              children: [
                const TextSpan(text: "Телефон подтверждён: "),
                TextSpan(text: phonePretty, style: TextStyle(fontWeight: FontWeight.w800, color: titleColor)),
              ],
            ),
          ),
        ),
        if (_role == "partner") ...[
          const SizedBox(height: 16),
          Text("Реферальный код (обязательно)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
          const SizedBox(height: 8),
          TextField(controller: _referralCtl, decoration: deco("REFCODE"), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        Text("Роль", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _role,
          dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
          decoration: dropdownShell(),
          items: const [
            DropdownMenuItem(value: "client", child: Text("Покупатель")),
            DropdownMenuItem(value: "partner", child: Text("Партнёр")),
            DropdownMenuItem(value: "seller", child: Text("Продавец")),
            DropdownMenuItem(value: "courier", child: Text("Курьер")),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _role = v;
              if (v != "partner") _referralCtl.clear();
            });
          },
        ),
        if (_role == "seller") ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Данные магазина", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor)),
                const SizedBox(height: 12),
                Text("Название магазина", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
                const SizedBox(height: 6),
                TextField(controller: _storeNameCtl, decoration: deco("Магазин"), style: TextStyle(color: titleColor)),
                const SizedBox(height: 12),
                Text("Город", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
                const SizedBox(height: 6),
                if (_citiesLoading)
                  const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_cities.isEmpty)
                  Text(
                    "Список городов недоступен. Проверьте сеть и откройте шаг снова.",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: storeCityVal,
                    dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    decoration: dropdownShell(),
                    items: _cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _storeCity = v ?? storeCityVal),
                  ),
                const SizedBox(height: 12),
                Text("Адрес магазина", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
                const SizedBox(height: 6),
                TextField(controller: _storeAddressCtl, decoration: deco("Адрес"), style: TextStyle(color: titleColor)),
                const SizedBox(height: 8),
                Text("Фото (аватар) добавим позже в профиле.", style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
        ],
        if (_role == "courier") ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Город", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
                const SizedBox(height: 6),
                if (_citiesLoading)
                  const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_cities.isEmpty)
                  Text(
                    "Список городов недоступен.",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: courierCityVal,
                    dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    decoration: dropdownShell(),
                    items: _cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _courierCity = v ?? courierCityVal),
                  ),
                const SizedBox(height: 12),
                Text("Тип доставки", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _deliveryType,
                  dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                  decoration: dropdownShell(),
                  items: _kCourierTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _deliveryType = v ?? _deliveryType),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _verifying ? null : _register,
            style: FilledButton.styleFrom(
              backgroundColor: _kBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_verifying ? "Сохранение…" : "Зарегистрироваться", style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Color cardBg(bool isDark) => isDark ? const Color(0xFF09090B) : Colors.white;
}

class _ProfileAuthFooter extends StatelessWidget {
  const _ProfileAuthFooter({
    required this.isDark,
    required this.titleColor,
    required this.muted,
    required this.borderColor,
  });
  final bool isDark;
  final Color titleColor;
  final Color muted;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(height: 40),
        const SizedBox(height: 10),
        Text(
          "Лучшие покупки в Таджикистане: быстро и удобно.",
          style: TextStyle(fontSize: 14, height: 1.45, color: muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        Text("Контакты", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => _openUrl("tel:+992939888883"),
          child: Row(
            children: [
              const Icon(Icons.phone_rounded, size: 18, color: _kBrand),
              const SizedBox(width: 8),
              Text("+992 93 988 88 83", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openUrl("mailto:info@kharid.tj"),
          child: Row(
            children: [
              const Icon(Icons.mail_rounded, size: 18, color: _kBrand),
              const SizedBox(width: 8),
              Text("info@kharid.tj", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SocialDot(isDark: isDark, icon: Icons.facebook_rounded, onTap: () => _openUrl("https://facebook.com")),
            _SocialDot(isDark: isDark, icon: Icons.camera_alt_rounded, onTap: () => _openUrl("https://instagram.com")),
            _SocialDot(isDark: isDark, icon: Icons.send_rounded, onTap: () => _openUrl("https://t.me/kharid24tj")),
            _SocialDot(isDark: isDark, icon: Icons.chat_rounded, onTap: () => _openUrl("https://wa.me")),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1A3A).withValues(alpha: 0.35) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.75)),
          ),
          child: Column(
            children: [
              _FooterExpansion(title: "Узнайте нас лучше", links: _kLearn, isDark: isDark, titleColor: titleColor, muted: muted),
              _FooterExpansion(title: "Служба поддержки", links: _kSupport, isDark: isDark, titleColor: titleColor, muted: muted),
              _FooterExpansion(title: "Заказы и возвраты", links: _kOrders, isDark: isDark, titleColor: titleColor, muted: muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _FooterExpansion extends StatelessWidget {
  const _FooterExpansion({
    required this.title,
    required this.links,
    required this.isDark,
    required this.titleColor,
    required this.muted,
  });
  final String title;
  final List<_FooterLink> links;
  final bool isDark;
  final Color titleColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        iconColor: muted,
        collapsedIconColor: muted,
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor)),
        children: links
            .map(
              (e) => ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(e.label, style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w600)),
                onTap: () => _openFooterLink(context, e),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SocialDot extends StatelessWidget {
  const _SocialDot({required this.isDark, required this.icon, required this.onTap});
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

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
          border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
        ),
        child: Icon(icon, size: 18, color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF334155)),
      ),
    );
  }
}
