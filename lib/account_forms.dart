import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "package:video_player/video_player.dart";

import "api_client.dart";
import "app_state.dart";
import "models.dart";
import "tj_cities.dart";
import "widgets/kharid_site_header.dart";

typedef SellerAccountNavFn = void Function(String path, String title);
typedef SellerProductCreatedNavFn = void Function(BuildContext context);

Future<XFile> _downloadProductImageAsXFile(String url) async {
  final u = url.trim();
  if (u.isEmpty) throw Exception("Пустой URL изображения.");
  final res = await http.get(Uri.parse(u));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception("Не удалось загрузить изображение (HTTP ${res.statusCode}).");
  }
  final ctRaw = res.headers["content-type"] ?? "image/jpeg";
  final ct = ctRaw.split(";").first.trim();
  final ext = ct.contains("png") ? "png" : "jpg";
  return XFile.fromData(res.bodyBytes, name: "photo.$ext", mimeType: ct);
}

const Color _kSellerBrand = Color(0xFF2563EB);
const Color _kSellerPhotoTeal = Color(0xFF2DD4BF);

/// Ҳамон формулаи футери шиновар дар [app_shell_v2] — то тугмаи «Добавить» аз нави поён пинҳон нашавад.
double _sellerFloatingNavBottomGap(BuildContext context) {
  const lift = 12.0;
  final sys = MediaQuery.viewPaddingOf(context).bottom;
  return sys + 58 + lift + 8;
}

final Random _kVariantRnd = Random();

String _newVariantId() =>
    "v${_kVariantRnd.nextInt(0x7fffffff)}_${DateTime.now().microsecondsSinceEpoch}";

/// Сидҳои атрибут барои қолаби категория (монанди seller-add-product веб).
class _AttrSeed {
  const _AttrSeed({required this.type, required this.slug, required this.name});
  final String type;
  final String slug;
  final String name;
}

List<CategoryLite> _categoryLineage(List<CategoryLite> cats, CategoryLite? cat) {
  final out = <CategoryLite>[];
  var cur = cat;
  final seen = <int>{};
  for (var i = 0; i < 20 && cur != null; i++) {
    if (seen.contains(cur.id)) break;
    seen.add(cur.id);
    out.add(cur);
    final pid = cur.parentId;
    if (pid == null) break;
    CategoryLite? next;
    for (final x in cats) {
      if (x.id == pid) {
        next = x;
        break;
      }
    }
    cur = next;
  }
  return out;
}

/// Қолаби свойств монанди веб: бо рӯйиши slug/name-и категорияҳо.
List<_AttrSeed> _categoryTemplateSeeds(List<CategoryLite> cats, CategoryLite? cat) {
  final lineage = _categoryLineage(cats, cat);
  final hay =
      lineage.map((x) => "${x.slug} ${x.name}".toLowerCase()).join(" | ");

  final isShoe = hay.contains("обув") ||
      hay.contains("ботин") ||
      hay.contains("кросс") ||
      hay.contains("кеды") ||
      hay.contains("туф") ||
      hay.contains("сандал") ||
      hay.contains("сапог") ||
      hay.contains("угги");

  final isClothes = hay.contains("одеж") ||
      hay.contains("плать") ||
      hay.contains("футбол") ||
      hay.contains("рубаш") ||
      hay.contains("брюк") ||
      hay.contains("джинс") ||
      hay.contains("куртк") ||
      hay.contains("худи") ||
      hay.contains("свит") ||
      hay.contains("бель");

  final isElectronics = hay.contains("электро") ||
      hay.contains("смартфон") ||
      hay.contains("телефон") ||
      hay.contains("ноут") ||
      hay.contains("планш");
  final isHomeAppliance = hay.contains("бытовая техника") || hay.contains("кухня и столовая") || hay.contains("техника для дома");
  final isAuto = hay.contains("авто") || hay.contains("мото") || hay.contains("шины") || hay.contains("диски") || hay.contains("запчаст");

  final base = <_AttrSeed>[
    const _AttrSeed(type: "color", slug: "color", name: "Цвет"),
  ];

  void withGender() => base.add(const _AttrSeed(type: "other", slug: "gender", name: "Тип (м/ж/дет)"));
  void withMaterial() => base.add(const _AttrSeed(type: "other", slug: "material", name: "Материал"));
  void withSeason() => base.add(const _AttrSeed(type: "other", slug: "season", name: "Сезон"));

  if (isShoe) {
    base.add(const _AttrSeed(type: "size", slug: "shoe-size", name: "Размер обуви"));
    withMaterial();
    withGender();
    withSeason();
    return base;
  }
  if (isClothes) {
    base.add(const _AttrSeed(type: "size", slug: "size", name: "Размер"));
    withMaterial();
    withGender();
    withSeason();
    return base;
  }
  if (isHomeAppliance) {
    base.addAll(const [
      _AttrSeed(type: "other", slug: "brand", name: "Бренд"),
      _AttrSeed(type: "other", slug: "model", name: "Модель"),
      _AttrSeed(type: "other", slug: "power", name: "Мощность"),
      _AttrSeed(type: "other", slug: "volume", name: "Объем/Размер"),
      _AttrSeed(type: "other", slug: "warranty", name: "Гарантия"),
      _AttrSeed(type: "other", slug: "condition", name: "Состояние"),
    ]);
    return base;
  }
  if (isElectronics) {
    base.addAll(const [
      _AttrSeed(type: "other", slug: "memory", name: "Память"),
      _AttrSeed(type: "other", slug: "ram", name: "ОЗУ"),
      _AttrSeed(type: "other", slug: "condition", name: "Состояние"),
    ]);
    return base;
  }
  if (isAuto) {
    base.addAll(const [
      _AttrSeed(type: "other", slug: "brand-model", name: "Марка/модель"),
      _AttrSeed(type: "other", slug: "year", name: "Год"),
      _AttrSeed(type: "other", slug: "compatibility", name: "Совместимость"),
    ]);
    return base;
  }

  base.add(const _AttrSeed(type: "size", slug: "size", name: "Размер"));
  withMaterial();
  return base;
}

String _inferAttrType(String slug, String name, {VariantOptionMeta? meta}) {
  final kind = meta?.kind?.toLowerCase() ?? "";
  if (kind.contains("color") || kind.contains("цвет")) return "color";
  if (kind.contains("size") || kind.contains("размер")) return "size";
  final s = "${slug}_$name".toLowerCase();
  if (s.contains("color") || s.contains("цвет") || slug == "color") return "color";
  if (s.contains("size") || s.contains("размер") || slug.contains("size")) return "size";
  return "other";
}

String _slugify(String input) {
  return input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[^a-z0-9а-я\s_-]+"), "")
      .replaceAll(RegExp(r"\s+"), "-")
      .replaceAll(RegExp("-+"), "-");
}

/// API + бастаҳои пешфарз барои майдони «Значение» (ҳам барои илова, ҳам барои таҳрир).
List<VariantValueMeta> _variantValueChoicesForCatalog(VariantCatalogMeta catalog, _VariantAttrDraft a) {
  final slug = a.optionSlug.trim();
  final name = a.optionName.text.trim();
  if (slug.isNotEmpty) {
    final api = catalog.valuesBySlug[slug];
    if (api != null && api.isNotEmpty) return _sortedVariantValuesRu(api);
  }
  if (a.type == "color" || _isColorOptionKey(slug) || _isColorOptionKey(name)) {
    return List<VariantValueMeta>.from(_kFrontendColorValuePresets);
  }
  if (a.type == "size" || _isSizeOptionKey(slug) || _isSizeOptionKey(name)) {
    if (slug == "shoe-size") {
      return List.generate(13, (i) {
        final n = 35 + i;
        return VariantValueMeta(value: "$n", label: "$n");
      });
    }
    return List<VariantValueMeta>.from(_kFrontendSizeValuePresets);
  }
  switch (slug) {
    case "gender":
      return List<VariantValueMeta>.from(_kGenderValuePresets);
    case "season":
      return List<VariantValueMeta>.from(_kSeasonValuePresets);
    case "condition":
      return List<VariantValueMeta>.from(_kConditionValuePresets);
    case "warranty":
      return List<VariantValueMeta>.from(_kWarrantyValuePresets);
    default:
      return const [];
  }
}

bool _isColorOptionKey(String s) {
  final k = s.trim().toLowerCase();
  return k.contains("color") ||
      k.contains("colour") ||
      k.contains("цвет") ||
      k.contains("cvet") ||
      k.contains("ранг") ||
      k.contains("rang");
}

bool _isSizeOptionKey(String s) {
  final k = s.trim().toLowerCase();
  return k.contains("size") ||
      k.contains("размер") ||
      k.contains("razmer") ||
      k.contains("андоза") ||
      k.contains("andoza");
}

/// Ҳамон бастаҳо, ки дар seller-add-product веб аст, вақте ки API-база ҳанӯз қайд надорад.
const List<VariantValueMeta> _kFrontendColorValuePresets = [
  VariantValueMeta(value: "Черный", label: "Черный", hex: "#0f172a"),
  VariantValueMeta(value: "Белый", label: "Белый", hex: "#ffffff"),
  VariantValueMeta(value: "Красный", label: "Красный", hex: "#ef4444"),
  VariantValueMeta(value: "Синий", label: "Синий", hex: "#3b82f6"),
  VariantValueMeta(value: "Зеленый", label: "Зеленый", hex: "#22c55e"),
  VariantValueMeta(value: "Желтый", label: "Желтый", hex: "#eab308"),
  VariantValueMeta(value: "Оранжевый", label: "Оранжевый", hex: "#f97316"),
  VariantValueMeta(value: "Фиолетовый", label: "Фиолетовый", hex: "#a855f7"),
  VariantValueMeta(value: "Розовый", label: "Розовый", hex: "#ec4899"),
  VariantValueMeta(value: "Серый", label: "Серый", hex: "#94a3b8"),
];

const List<VariantValueMeta> _kFrontendSizeValuePresets = [
  VariantValueMeta(value: "XS", label: "XS"),
  VariantValueMeta(value: "S", label: "S"),
  VariantValueMeta(value: "M", label: "M"),
  VariantValueMeta(value: "L", label: "L"),
  VariantValueMeta(value: "XL", label: "XL"),
  VariantValueMeta(value: "XXL", label: "XXL"),
  VariantValueMeta(value: "36", label: "36"),
  VariantValueMeta(value: "37", label: "37"),
  VariantValueMeta(value: "38", label: "38"),
  VariantValueMeta(value: "39", label: "39"),
  VariantValueMeta(value: "40", label: "40"),
  VariantValueMeta(value: "41", label: "41"),
  VariantValueMeta(value: "42", label: "42"),
  VariantValueMeta(value: "43", label: "43"),
  VariantValueMeta(value: "44", label: "44"),
  VariantValueMeta(value: "45", label: "45"),
];

const List<VariantValueMeta> _kGenderValuePresets = [
  VariantValueMeta(value: "Мужской", label: "Мужской"),
  VariantValueMeta(value: "Женский", label: "Женский"),
  VariantValueMeta(value: "Детский", label: "Детский"),
];

const List<VariantValueMeta> _kSeasonValuePresets = [
  VariantValueMeta(value: "Лето", label: "Лето"),
  VariantValueMeta(value: "Зима", label: "Зима"),
  VariantValueMeta(value: "Весна/Осень", label: "Весна/Осень"),
  VariantValueMeta(value: "Демисезон", label: "Демисезон"),
];

const List<VariantValueMeta> _kConditionValuePresets = [
  VariantValueMeta(value: "Новый", label: "Новый"),
  VariantValueMeta(value: "Б/у", label: "Б/у"),
];

const List<VariantValueMeta> _kWarrantyValuePresets = [
  VariantValueMeta(value: "Есть", label: "Есть"),
  VariantValueMeta(value: "Нет", label: "Нет"),
  VariantValueMeta(value: "1 месяц", label: "1 месяц"),
  VariantValueMeta(value: "3 месяца", label: "3 месяца"),
  VariantValueMeta(value: "6 месяцев", label: "6 месяцев"),
  VariantValueMeta(value: "12 месяцев", label: "12 месяцев"),
];

List<VariantValueMeta> _sortedVariantValuesRu(List<VariantValueMeta> raw) {
  final copy = List<VariantValueMeta>.from(raw);
  copy.sort((a, b) {
    final la = (a.label.isNotEmpty ? a.label : a.value).toLowerCase();
    final lb = (b.label.isNotEmpty ? b.label : b.value).toLowerCase();
    return la.compareTo(lb);
  });
  return copy;
}

/// Превьюи файл аз [ImagePicker]: дар веб [Image.file] кор намекунад — аз [readAsBytes] истифода мешавад.
class _LocalXFileImage extends StatefulWidget {
  const _LocalXFileImage({required this.file, required this.width, required this.height});

  final XFile file;
  final double width;
  final double height;

  @override
  State<_LocalXFileImage> createState() => _LocalXFileImageState();
}

class _LocalXFileImageState extends State<_LocalXFileImage> {
  Uint8List? _webBytes;

  @override
  void initState() {
    super.initState();
    _primeWebBytes();
  }

  @override
  void didUpdateWidget(covariant _LocalXFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb && oldWidget.file.path != widget.file.path) {
      _webBytes = null;
      _primeWebBytes();
    }
  }

  void _primeWebBytes() {
    if (!kIsWeb) return;
    widget.file.readAsBytes().then((b) {
      if (mounted) setState(() => _webBytes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (_webBytes == null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        );
      }
      return Image.memory(_webBytes!, width: widget.width, height: widget.height, fit: BoxFit.cover);
    }
    return Image.file(File(widget.file.path), width: widget.width, height: widget.height, fit: BoxFit.cover);
  }
}

class _SellerNavItem {
  const _SellerNavItem(this.path, this.title);
  final String path;
  final String title;
}

const List<_SellerNavItem> _kAllSellerNav = [
  _SellerNavItem("/account/seller/products", "Мои товары"),
  _SellerNavItem("/account/seller/add-product", "Добавить товар"),
  _SellerNavItem("/account/seller/orders", "Заказы"),
  _SellerNavItem("/account/seller/analytics", "Аналитика"),
  _SellerNavItem("/account/seller/wishlist", "Мои Избранное"),
  _SellerNavItem("/account/seller/compare", "Сравнение"),
  _SellerNavItem("/account/seller/earnings", "История заработка"),
  _SellerNavItem("/account/seller/referrals", "Мои реферали"),
  _SellerNavItem("/account/seller/settings", "Настройка"),
];

List<_SellerNavItem> _sellerNavForMe(MeProfile me, bool mlmEnabled) {
  if (me.mlmMember && mlmEnabled) return List<_SellerNavItem>.from(_kAllSellerNav);
  return _kAllSellerNav
      .where((e) => !e.path.endsWith("/referrals") && !e.path.endsWith("/earnings"))
      .toList(growable: false);
}

/// Bottom sheet монанди Select2: ҷустӯҷӯ + рӯйхат.
class _SearchPickSheetBody<T extends Object> extends StatefulWidget {
  const _SearchPickSheetBody({required this.title, required this.items, required this.asText});
  final String title;
  final List<T> items;
  final String Function(T) asText;

  @override
  State<_SearchPickSheetBody<T>> createState() => _SearchPickSheetBodyState<T>();
}

class _SearchPickSheetBodyState<T extends Object> extends State<_SearchPickSheetBody<T>> {
  late final TextEditingController _q = TextEditingController();
  late List<T> _shown;

  @override
  void initState() {
    super.initState();
    _shown = List<T>.from(widget.items);
    _q.addListener(_filter);
  }

  void _filter() {
    final t = _q.text.trim().toLowerCase();
    setState(() {
      _shown = t.isEmpty
          ? List<T>.from(widget.items)
          : widget.items.where((e) => widget.asText(e).toLowerCase().contains(t)).toList();
    });
  }

  @override
  void dispose() {
    _q.removeListener(_filter);
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : Colors.white;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: border),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (ctx, scroll) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: muted.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: muted)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Поиск…",
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kSellerBrand, width: 1.4)),
                  ),
                ),
              ),
              Expanded(
                child: _shown.isEmpty
                    ? Center(child: Text("Ничего не найдено", style: TextStyle(color: muted, fontWeight: FontWeight.w600)))
                    : ListView.builder(
                        controller: scroll,
                        itemCount: _shown.length,
                        itemBuilder: (_, i) {
                          final it = _shown[i];
                          return ListTile(
                            title: Text(widget.asText(it), style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
                            onTap: () => Navigator.pop(context, it),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<T?> _showSelect2Sheet<T extends Object>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) asText,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(ctx).top + 8,
        bottom: _sellerFloatingNavBottomGap(ctx),
      ),
      child: _SearchPickSheetBody<T>(title: title, items: items, asText: asText),
    ),
  );
}

const _kValidationDebounce = Duration(milliseconds: 250);

/// Формаи «Настройка» — монанди `AccountSellerSettings` / `AccountClientSettings` дар фронтенд.
class AccountSettingsForm extends StatefulWidget {
  const AccountSettingsForm({super.key, required this.role, required this.api});
  final String role;
  final ApiClient api;

  @override
  State<AccountSettingsForm> createState() => _AccountSettingsFormState();
}

class FullSettingsScreen extends AccountSettingsForm {
  const FullSettingsScreen({super.key, required super.role, required super.api});
}

class _AccountSettingsFormState extends State<AccountSettingsForm> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final birthDate = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  final storeName = TextEditingController();
  final storeCity = TextEditingController();
  final storeAddress = TextEditingController();
  final deliveryType = TextEditingController();
  XFile? avatar;
  XFile? storeLogo;
  bool saving = false;
  String? msg;
  final Map<String, String> _fieldErrors = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _syncFromMe();
  }

  void _syncFromMe() {
    final me = context.read<AppState>().me;
    if (me == null) return;
    firstName.text = me.user.firstName;
    lastName.text = me.user.lastName;
    birthDate.text = me.birthDate ?? "";
    city.text = me.city.isNotEmpty ? me.city : tajikistanCities.first;
    address.text = me.address;
    storeName.text = me.storeName ?? "";
    storeCity.text = (me.storeCity ?? "").isNotEmpty ? me.storeCity! : tajikistanCities.first;
    storeAddress.text = me.storeAddress ?? "";
    deliveryType.text = me.user.deliveryType ?? "";
  }

  Future<void> _pickAvatar() async {
    avatar = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (mounted) setState(() {});
  }

  Future<void> _pickLogo() async {
    storeLogo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (mounted) setState(() {});
  }

  void _clearSettingError(String key) {
    _debounce?.cancel();
    _debounce = Timer(_kValidationDebounce, () {
      if (_fieldErrors.remove(key) != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    firstName.dispose();
    lastName.dispose();
    birthDate.dispose();
    city.dispose();
    address.dispose();
    storeName.dispose();
    storeCity.dispose();
    storeAddress.dispose();
    deliveryType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    final token = app.accessToken;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final fieldFill = isDark ? const Color(0xFF09090B) : Colors.white;

    InputDecoration fieldDeco(String label, {String? error}) {
      return InputDecoration(
        labelText: label,
        errorText: error,
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kSellerBrand, width: 1.4)),
      );
    }

    Widget settingsCard({required Widget child}) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: child,
      );
    }

    Widget imagePickerBlock({
      required String label,
      required String? currentUrl,
      required XFile? file,
      required VoidCallback onPick,
      required VoidCallback onClear,
      String? hint,
    }) {
      return settingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor)),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                    child: file != null
                        ? _LocalXFileImage(file: file, width: 72, height: 72)
                        : (currentUrl != null && currentUrl.isNotEmpty)
                            ? Image.network(currentUrl, fit: BoxFit.cover)
                            : Icon(Icons.image_outlined, color: muted, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton(onPressed: onPick, child: const Text("Выбрать файл")),
                      if (file != null) TextButton(onPressed: onClear, child: const Text("Убрать выбранное")),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        settingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Тема оформления", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor)),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text("Светлая"), icon: Icon(Icons.light_mode_outlined, size: 18)),
                  ButtonSegment(value: true, label: Text("Тёмная"), icon: Icon(Icons.dark_mode_outlined, size: 18)),
                ],
                selected: {app.isDarkTheme},
                onSelectionChanged: (s) => app.setThemeDark(s.first),
              ),
            ],
          ),
        ),
        settingsCard(
          child: TextField(
            controller: firstName,
            onChanged: (_) => _clearSettingError("first_name"),
            decoration: fieldDeco("Имя", error: _fieldErrors["first_name"]),
            style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
          ),
        ),
        settingsCard(
          child: TextField(
            controller: lastName,
            onChanged: (_) => _clearSettingError("last_name"),
            decoration: fieldDeco("Фамилия", error: _fieldErrors["last_name"]),
            style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
          ),
        ),
        if (widget.role != "seller")
          settingsCard(
            child: TextField(
              controller: birthDate,
              onChanged: (_) => _clearSettingError("birth_date"),
              decoration: fieldDeco("Дата рождения (YYYY-MM-DD)", error: _fieldErrors["birth_date"]),
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
            ),
          ),
        if (widget.role == "seller")
          imagePickerBlock(
            label: "Логотип магазина",
            currentUrl: me?.storeLogo,
            file: storeLogo,
            onPick: _pickLogo,
            onClear: () => setState(() => storeLogo = null),
            hint: "Покажем на карточках магазина и товарах.",
          ),
        if (widget.role == "seller")
          settingsCard(
            child: TextField(
              controller: storeName,
              onChanged: (_) => _clearSettingError("store_name"),
              decoration: fieldDeco("Название магазина", error: _fieldErrors["store_name"]),
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
            ),
          ),
        if (widget.role == "seller")
          settingsCard(
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>(storeCity.text),
              value: tajikistanCities.contains(storeCity.text) ? storeCity.text : tajikistanCities.first,
              decoration: fieldDeco("Город"),
              dropdownColor: cardBg,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
              items: tajikistanCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => storeCity.text = v);
              },
            ),
          ),
        if (widget.role == "seller")
          settingsCard(
            child: TextField(
              controller: storeAddress,
              decoration: fieldDeco("Адрес"),
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
            ),
          ),
        if (widget.role != "seller")
          settingsCard(
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>(city.text),
              value: tajikistanCities.contains(city.text) ? city.text : tajikistanCities.first,
              decoration: fieldDeco("Город", error: _fieldErrors["city"]),
              dropdownColor: cardBg,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
              items: tajikistanCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => city.text = v);
                _clearSettingError("city");
              },
            ),
          ),
        if (widget.role != "seller")
          settingsCard(
            child: TextField(
              controller: address,
              onChanged: (_) => _clearSettingError("address"),
              decoration: fieldDeco("Адрес", error: _fieldErrors["address"]),
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
            ),
          ),
        if (widget.role == "courier")
          settingsCard(
            child: DropdownButtonFormField<String>(
              value: courierDeliveryTypes.contains(deliveryType.text) ? deliveryType.text : courierDeliveryTypes.first,
              decoration: fieldDeco("Тип доставки", error: _fieldErrors["delivery_type"]),
              dropdownColor: cardBg,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
              items: courierDeliveryTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => deliveryType.text = v);
                _clearSettingError("delivery_type");
              },
            ),
          ),
        imagePickerBlock(
          label: "Фото профиля",
          currentUrl: me?.avatar,
          file: avatar,
          onPick: _pickAvatar,
          onClear: () => setState(() => avatar = null),
          hint: "Если хотите, можно поставить фото владельца/менеджера.",
        ),
        settingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: saving || token == null
                    ? null
                    : () async {
                        setState(() {
                          saving = true;
                          msg = null;
                          _fieldErrors.clear();
                        });
                        try {
                          if (!_validateSettings()) return;
                          final fields = <String, String>{
                            "first_name": firstName.text.trim(),
                            "last_name": lastName.text.trim(),
                          };
                          if (widget.role != "seller") {
                            fields["city"] = city.text.trim();
                            fields["address"] = address.text.trim();
                          }
                          if (birthDate.text.trim().isNotEmpty) fields["birth_date"] = birthDate.text.trim();
                          if (widget.role == "seller") {
                            fields["store_name"] = storeName.text.trim();
                            fields["store_city"] = storeCity.text.trim();
                            fields["store_address"] = storeAddress.text.trim();
                          }
                          if (widget.role == "courier") {
                            fields["delivery_type"] = deliveryType.text.trim();
                          }
                          await widget.api.updateMeMultipart(
                            accessToken: token,
                            fields: fields,
                            avatar: avatar,
                            storeLogo: widget.role == "seller" ? storeLogo : null,
                          );
                          await app.loadMe();
                          _syncFromMe();
                          setState(() {
                            avatar = null;
                            storeLogo = null;
                          });
                          msg = "Сохранено.";
                        } catch (e) {
                          msg = "$e";
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: _kSellerBrand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(saving ? "Сохранение…" : "Сохранить", style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(msg!, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
                ),
            ],
          ),
        ),
        settingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Удаление аккаунта", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor)),
              const SizedBox(height: 6),
              Text(
                "Все личные данные будут удалены безвозвратно. История заказов сохранится в анонимном виде для бухгалтерии.",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted, height: 1.35),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: token == null
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Удалить аккаунт?"),
                            content: const Text(
                              "Это действие нельзя отменить. Ваши имя, телефон, адрес и фото будут удалены.",
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отмена")),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text("Удалить", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Подтвердите удаление"),
                            content: const Text("Нажмите «Да», чтобы окончательно удалить аккаунт."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Нет")),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text("Да, удалить", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !context.mounted) return;
                        setState(() {
                          saving = true;
                          msg = null;
                        });
                        try {
                          await widget.api.deleteAccount(token);
                          await app.logout();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Аккаунт удалён")),
                            );
                          }
                        } catch (e) {
                          if (mounted) setState(() => msg = "$e");
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Удалить аккаунт", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _validateSettings() {
    _fieldErrors.clear();
    if (firstName.text.trim().isEmpty) _fieldErrors["first_name"] = "Имя обязательно.";
    if (lastName.text.trim().isEmpty) _fieldErrors["last_name"] = "Фамилия обязательна.";
    if (widget.role != "seller") {
      if (city.text.trim().isEmpty) _fieldErrors["city"] = "Город обязателен.";
      if (address.text.trim().isEmpty) _fieldErrors["address"] = "Адрес обязателен.";
    }
    if (birthDate.text.trim().isNotEmpty) {
      final d = DateTime.tryParse(birthDate.text.trim());
      if (d == null) {
        _fieldErrors["birth_date"] = "Дата рождения в формате YYYY-MM-DD.";
      } else {
        final now = DateTime.now();
        final age = now.year - d.year - ((now.month < d.month || (now.month == d.month && now.day < d.day)) ? 1 : 0);
        if (age < 18) _fieldErrors["birth_date"] = "Только 18+.";
      }
    }
    if (widget.role == "seller" && storeName.text.trim().isEmpty) {
      _fieldErrors["store_name"] = "Название магазина обязательно.";
    }
    if (widget.role == "courier" && deliveryType.text.trim().isEmpty) {
      _fieldErrors["delivery_type"] = "Тип доставки обязателен.";
    }
    if (_fieldErrors.isNotEmpty) {
      setState(() {});
      return false;
    }
    return true;
  }
}

class FullSellerAddProductScreen extends StatefulWidget {
  const FullSellerAddProductScreen({
    super.key,
    required this.api,
    this.onSellerAccountNav,
    this.onProductCreatedGoToMyProducts,
  });
  final ApiClient api;
  /// Аз [AccountRouteScreen] — барои нави кабинети фурӯшанда бе import-и `app_shell`.
  final SellerAccountNavFn? onSellerAccountNav;
  /// Пас аз иловаи муваффақ — попап ва гузариш ба «Мои товары» ([AccountRouteScreen]).
  final SellerProductCreatedNavFn? onProductCreatedGoToMyProducts;

  @override
  State<FullSellerAddProductScreen> createState() => _FullSellerAddProductScreenState();
}

class _FullSellerAddProductScreenState extends State<FullSellerAddProductScreen> {
  String productType = "simple";
  final title = TextEditingController();
  final sku = TextEditingController();
  final price = TextEditingController();
  final salePrice = TextEditingController();
  final stockQty = TextEditingController();
  String stockUnit = "pcs";
  final description = TextEditingController();
  int? categoryId;
  List<CategoryLite> categories = const [];
  List<XFile> images = [];
  List<_VariantDraft> variants = [];
  bool loadingCategories = true;
  bool saving = false;
  String? msg;
  final Map<String, String> _fieldErrors = {};
  final Map<int, Map<String, String>> _variantErrors = {};
  String? _imagesError;
  String? _variantsError;
  Timer? _debounce;
  bool _mlmEnabled = true;
  String? _videoUid;
  String? _videoWatchUrl;
  String? _videoFileLabel;
  bool _videoUploading = false;
  bool _videoPreviewOpening = false;
  VideoPlayerController? _videoPreviewCtrl;

  VariantCatalogMeta _variantCatalog = const VariantCatalogMeta(options: [], valuesBySlug: {});
  bool _variantCatalogLoading = false;
  String? _variantCatalogLoadToken;

  @override
  void initState() {
    super.initState();
    sku.addListener(_onBaseSkuChanged);
    _loadCategories();
    _loadMlm();
  }

  Future<void> _loadVariantCatalog(String accessToken) async {
    if (_variantCatalogLoading) return;
    setState(() => _variantCatalogLoading = true);
    try {
      final m = await widget.api.fetchVariantCatalogMeta(accessToken: accessToken);
      if (mounted) setState(() => _variantCatalog = m);
    } catch (_) {
      if (mounted) {
        setState(() => _variantCatalog = const VariantCatalogMeta(options: [], valuesBySlug: {}));
      }
    } finally {
      if (mounted) setState(() => _variantCatalogLoading = false);
    }
  }

  void _ensureVariantCatalogLoaded(String? token) {
    final t = token?.trim() ?? "";
    if (t.isEmpty) return;
    if (_variantCatalogLoadToken == t) return;
    _variantCatalogLoadToken = t;
    unawaited(_loadVariantCatalog(t));
  }

  void _onBaseSkuChanged() {
    if (productType != "variant") return;
    if (!mounted) return;
    setState(_applyAutoVariantSkusInPlace);
  }

  void _applyAutoVariantSkusInPlace() {
    final base = sku.text.trim();
    for (var i = 0; i < variants.length; i++) {
      final v = variants[i];
      if (!v.skuAuto) continue;
      v.sku.text = base.isEmpty ? "" : "$base-${i + 1}";
    }
  }

  void _reapplyVariantTemplateIfNeeded() {
    if (productType != "variant") return;
    final seeds = _categoryTemplateSeeds(categories, _selectedCategory());
    for (final v in variants) {
      final hasAny = v.attrs.any((a) => a.value.text.trim().isNotEmpty);
      if (hasAny) continue;
      for (final a in v.attrs) {
        a.dispose();
      }
      v.attrs = seeds.map(_VariantAttrDraft.fromSeed).toList();
    }
  }

  void _addVariantRow() {
    setState(() {
      variants.add(_VariantDraft.withTemplate(_categoryTemplateSeeds(categories, _selectedCategory())));
      _variantsError = null;
      _applyAutoVariantSkusInPlace();
    });
  }

  _VariantAttrDraft _blankAttrRow() {
    if (_variantCatalog.options.isNotEmpty) {
      final o = _variantCatalog.options.first;
      return _VariantAttrDraft(
        id: _newVariantId(),
        optionSlug: o.slug,
        optionName: TextEditingController(text: o.name),
        type: _inferAttrType(o.slug, o.name, meta: o),
      );
    }
    return _VariantAttrDraft.fromSeed(const _AttrSeed(type: "color", slug: "color", name: "Цвет"));
  }

  String _variantValueDisplay(_VariantAttrDraft a) {
    final q = a.value.text.trim();
    if (q.isEmpty) return "";
    for (final v in _variantValueChoicesForCatalog(_variantCatalog, a)) {
      if (v.value == q) return v.label.isNotEmpty ? v.label : v.value;
    }
    return q;
  }

  List<VariantValueMeta> _valueChoicesForAttr(_VariantAttrDraft a) => _variantValueChoicesForCatalog(_variantCatalog, a);

  Future<void> _loadMlm() async {
    try {
      final d = await widget.api.siteSettings();
      final m = d["mlm_enabled"];
      if (mounted) setState(() => _mlmEnabled = m is bool ? m : true);
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      categories = await widget.api.categories();
    } catch (_) {}
    if (mounted) setState(() => loadingCategories = false);
  }

  Future<void> _disposeVideoPreview({bool notify = true}) async {
    final c = _videoPreviewCtrl;
    _videoPreviewCtrl = null;
    await c?.dispose();
    if (notify && mounted) setState(() {});
  }

  Future<bool> _initVideoPreview(String url) async {
    await _disposeVideoPreview(notify: false);
    if (!mounted || url.trim().isEmpty) return false;
    final u = Uri.tryParse(url.trim());
    if (u == null) return false;
    final c = VideoPlayerController.networkUrl(u, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _videoPreviewCtrl = c;
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _videoPreviewCtrl = null;
        return false;
      }
      c.setLooping(false);
      setState(() {});
      return true;
    } catch (_) {
      await c.dispose();
      _videoPreviewCtrl = null;
      if (mounted) setState(() {});
      return false;
    }
  }

  String _videoMimeForXFile(XFile f) {
    final m = f.mimeType?.trim().toLowerCase();
    if (m != null && m.startsWith("video/")) return m;
    final n = f.name.toLowerCase();
    if (n.endsWith(".webm")) return "video/webm";
    if (n.endsWith(".mov") || n.endsWith(".qt")) return "video/quicktime";
    return "video/mp4";
  }

  /// Плеер сразу после выбора файла (локально), до загрузки в Cloudflare.
  Future<void> _initVideoPreviewFromPick(XFile file) async {
    await _disposeVideoPreview(notify: false);
    if (!mounted) return;
    VideoPlayerController? c;
    try {
      if (kIsWeb) {
        final p = file.path.trim();
        if (p.startsWith("blob:") || p.startsWith("http://") || p.startsWith("https://")) {
          c = VideoPlayerController.networkUrl(Uri.parse(p), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
        } else {
          final bytes = await file.readAsBytes();
          if (bytes.length > 28 * 1024 * 1024) return;
          c = VideoPlayerController.networkUrl(
            Uri.dataFromBytes(bytes, mimeType: _videoMimeForXFile(file)),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }
      } else {
        c = VideoPlayerController.file(File(file.path), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      }
      _videoPreviewCtrl = c;
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _videoPreviewCtrl = null;
        return;
      }
      c.setLooping(false);
      setState(() {});
    } catch (_) {
      await c?.dispose();
      _videoPreviewCtrl = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _addPhotos() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : Colors.white;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: _sellerFloatingNavBottomGap(ctx)),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Камера", style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, "camera"),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Галерея", style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, "gallery"),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    final picker = ImagePicker();
    if (choice == "camera") {
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (x != null && mounted) {
        setState(() {
          images = [...images, x].take(10).toList();
          _imagesError = null;
        });
      }
    } else if (choice == "gallery") {
      final list = await picker.pickMultiImage(imageQuality: 90);
      if (list.isNotEmpty && mounted) {
        setState(() {
          images = [...images, ...list].take(10).toList();
          _imagesError = null;
        });
      }
    }
  }

  Future<void> _pickAndUploadVideo(String? token) async {
    if (token == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : Colors.white;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: _sellerFloatingNavBottomGap(ctx)),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text("Видео · камера", style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, "camera"),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text("Видео · галерея", style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, "gallery"),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    final picker = ImagePicker();
    final XFile? vid = choice == "camera"
        ? await picker.pickVideo(source: ImageSource.camera)
        : choice == "gallery"
            ? await picker.pickVideo(source: ImageSource.gallery)
            : null;
    if (vid == null) return;
    final len = await vid.length();
    if (len > 30 * 1024 * 1024) {
      if (mounted) setState(() => msg = "Видео не больше 30 МБ.");
      return;
    }
    if (mounted) {
      setState(() {
        _videoUid = null;
        _videoWatchUrl = null;
        _videoFileLabel = vid.name;
        msg = null;
        _videoPreviewOpening = true;
      });
    }
    try {
      await _initVideoPreviewFromPick(vid);
    } finally {
      if (mounted) setState(() => _videoPreviewOpening = false);
    }
    if (!mounted) return;
    setState(() => _videoUploading = true);
    String watchUrl = "";
    try {
      final meta = await widget.api.cloudflareDirectUpload(token);
      final uploadUrl = (meta["upload_url"] ?? "").toString().trim();
      final preUid = (meta["uid"] ?? "").toString().trim();
      if (uploadUrl.isEmpty) throw Exception("Нет ссылки загрузки.");
      final uid = await widget.api.cloudflarePostUpload(uploadUrl, vid, fallbackUid: preUid.isNotEmpty ? preUid : null);
      watchUrl = (meta["watch_url"] ?? "").toString().trim();
      if (!mounted) return;
      setState(() {
        _videoUid = uid.isNotEmpty ? uid : (preUid.isNotEmpty ? preUid : null);
        _videoWatchUrl = watchUrl;
      });
      if (watchUrl.isNotEmpty) {
        final ok = await _initVideoPreview(watchUrl);
        if (!ok && mounted) await _initVideoPreviewFromPick(vid);
      }
    } catch (e) {
      if (mounted) setState(() => msg = "$e");
    } finally {
      if (mounted) setState(() => _videoUploading = false);
    }
  }

  Future<void> _pickVariantImage(int index) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : Colors.white;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: _sellerFloatingNavBottomGap(ctx)),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Камера", style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, "camera"),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Галерея", style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, "gallery"),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    final picker = ImagePicker();
    final XFile? img = choice == "camera"
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 90)
        : choice == "gallery"
            ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 90)
            : null;
    if (img == null) return;
    variants[index].image = img;
    _variantErrors[index]?.remove("image");
    if (_variantErrors[index]?.isEmpty ?? false) _variantErrors.remove(index);
    if (mounted) setState(() {});
  }

  void _clearProductError(String key) {
    _debounce?.cancel();
    _debounce = Timer(_kValidationDebounce, () {
      if (_fieldErrors.remove(key) != null && mounted) setState(() {});
    });
  }

  void _clearVariantError(int index, String key) {
    _debounce?.cancel();
    _debounce = Timer(_kValidationDebounce, () {
      final had = _variantErrors[index]?.remove(key) != null;
      if (_variantErrors[index]?.isEmpty ?? false) _variantErrors.remove(index);
      if (had && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    sku.removeListener(_onBaseSkuChanged);
    unawaited(_disposeVideoPreview(notify: false));
    title.dispose();
    sku.dispose();
    price.dispose();
    salePrice.dispose();
    stockQty.dispose();
    description.dispose();
    for (final v in variants) {
      v.dispose();
    }
    super.dispose();
  }

  CategoryLite? _selectedCategory() {
    if (categoryId == null) return null;
    for (final c in categories) {
      if (c.id == categoryId) return c;
    }
    return null;
  }

  String _stockUnitRu(String code) {
    switch (code) {
      case "kg":
        return "кг";
      case "l":
        return "л";
      case "m":
        return "м";
      default:
        return "шт";
    }
  }

  static const List<String> _kStockCodes = ["pcs", "kg", "l", "m"];

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    String? errorText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1);
    final fill = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);
    const bw = 1.85;
    return InputDecoration(
      labelText: labelText.isEmpty ? null : labelText,
      hintText: hintText,
      errorText: errorText,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border, width: bw)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border, width: bw)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kSellerBrand, width: 2.4)),
    );
  }

  Widget _formSection(
    BuildContext context, {
    String? sectionTitle,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0B1120) : Colors.white;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sectionTitle != null) ...[
            Text(sectionTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor)),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }

  Widget _select2Tile({
    required BuildContext context,
    required String label,
    required String hint,
    required String display,
    String? errorText,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1);
    final fill = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);
    const bw = 1.85;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: titleColor)),
        const SizedBox(height: 6),
        Material(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: errorText != null ? Colors.red.shade400 : border, width: bw),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display.isEmpty ? hint : display,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: display.isEmpty ? muted : titleColor,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(errorText, style: TextStyle(color: Colors.red.shade400, fontSize: 12))),
      ],
    );
  }

  Widget _productTypeRadios(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final fill = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);
    Widget cell(String value, String label) {
      final sel = productType == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            productType = value;
            _imagesError = null;
            _variantsError = null;
            if (value == "variant" && variants.isEmpty) {
              variants.add(_VariantDraft.withTemplate(_categoryTemplateSeeds(categories, _selectedCategory())));
              _applyAutoVariantSkusInPlace();
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? _kSellerBrand : border, width: sel ? 2.2 : 1.85),
              color: sel ? _kSellerBrand.withValues(alpha: isDark ? 0.18 : 0.1) : fill,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: sel ? _kSellerBrand : border, width: 2),
                      color: sel ? _kSellerBrand.withValues(alpha: 0.2) : Colors.transparent,
                    ),
                    child: sel
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: _kSellerBrand),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: titleColor))),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Тип товара", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: titleColor)),
        const SizedBox(height: 8),
        Row(
          children: [
            cell("simple", "Простой товар"),
            const SizedBox(width: 10),
            cell("variant", "Вариантный товар"),
          ],
        ),
      ],
    );
  }

  /// Як видеои умумӣ барои ҷамъи товар (простой ё барои ҳама вариантҳо).
  Widget _buildProductVideoSection(BuildContext context, String? token) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return _formSection(
      context,
      sectionTitle: "Видео",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (productType == "variant")
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "Одно общее видео для всего товара (ко всем вариантам). Необязательно.",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.35, color: muted),
              ),
            ),
          Text("MP4/WebM · до 30 МБ", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted)),
          const SizedBox(height: 8),
          if (_videoUploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: _kSellerBrand,
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 6),
            Text("Загрузка на сервер…", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: titleColor)),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: titleColor,
              side: BorderSide(color: isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1), width: 1.85),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: (token == null || _videoUploading || _videoPreviewOpening) ? null : () => _pickAndUploadVideo(token),
            icon: _videoUploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined, size: 20),
            label: Text(_videoUploading ? "Подождите…" : "Загрузить", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          if (_videoPreviewOpening) ...[
            const SizedBox(height: 10),
            Text("Подготовка превью…", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: titleColor)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF020617) : const Color(0xFFE2E8F0),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
              ),
            ),
          ],
          if (!_videoPreviewOpening && _videoPreviewCtrl != null && _videoPreviewCtrl!.value.isInitialized) ...[
            const SizedBox(height: 10),
            Text("Просмотр", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: titleColor)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: _videoPreviewCtrl!.value.aspectRatio.clamp(0.72, 1.78),
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _videoPreviewCtrl!,
                    builder: (context, v, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_videoPreviewCtrl!),
                          if (!v.isPlaying)
                            Material(
                              color: Colors.black38,
                              shape: const CircleBorder(),
                              child: IconButton(
                                iconSize: 44,
                                color: Colors.white,
                                icon: const Icon(Icons.play_circle_filled),
                                onPressed: () async {
                                  await _videoPreviewCtrl!.play();
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                          if (v.isPlaying)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Material(
                                color: Colors.black45,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  iconSize: 28,
                                  color: Colors.white,
                                  icon: const Icon(Icons.pause_circle_filled),
                                  onPressed: () async {
                                    await _videoPreviewCtrl!.pause();
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          if (_videoFileLabel != null && _videoFileLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Файл: $_videoFileLabel", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: muted)),
            ),
          if (_videoUid != null &&
              _videoUid!.isNotEmpty &&
              (_videoWatchUrl == null || _videoWatchUrl!.trim().isEmpty) &&
              (_videoPreviewCtrl == null || !_videoPreviewCtrl!.value.isInitialized))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("Готово", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: titleColor)),
            ),
          if (_videoWatchUrl != null && _videoWatchUrl!.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _videoUploading
                    ? null
                    : () async {
                        final uri = Uri.tryParse(_videoWatchUrl!.trim());
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                child: const Text("Открыть в браузере", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          if (_videoUid != null && _videoUid!.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _videoUploading
                  ? null
                  : () async {
                      await _disposeVideoPreview(notify: false);
                      if (!mounted) return;
                      setState(() {
                        _videoUid = null;
                        _videoWatchUrl = null;
                        _videoFileLabel = null;
                        _videoPreviewOpening = false;
                      });
                    },
              child: const Text("Удалить", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFormSlivers(BuildContext context, String? token) {
    _ensureVariantCatalogLoaded(token);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cat = _selectedCategory();
    return [
      SliverToBoxAdapter(
        child: _formSection(
          context,
          sectionTitle: "Основное",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _productTypeRadios(context),
              const SizedBox(height: 14),
              TextField(
                controller: title,
                onChanged: (_) => _clearProductError("title"),
                decoration: _fieldDecoration(
                  context,
                  labelText: "Название товара *",
                  hintText: "Например: Наушники",
                  errorText: _fieldErrors["title"],
                ),
                style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sku,
                decoration: _fieldDecoration(
                  context,
                  labelText: productType == "variant"
                      ? "Артикул (база для вариантов, необязательно)"
                      : "Артикул (необязательно)",
                  hintText: "SKU-123",
                ),
                style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
              ),
              const SizedBox(height: 12),
              loadingCategories
                  ? const LinearProgressIndicator()
                  : _select2Tile(
                      context: context,
                      label: "Категория *",
                      hint: "Выберите категорию",
                      display: cat?.name ?? "",
                      errorText: _fieldErrors["category"],
                      onTap: () async {
                        if (categories.isEmpty) return;
                        final picked = await _showSelect2Sheet<CategoryLite>(
                          context,
                          title: "Категория",
                          items: categories,
                          asText: (c) => c.name,
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            categoryId = picked.id;
                            _fieldErrors.remove("category");
                            _reapplyVariantTemplateIfNeeded();
                          });
                        }
                      },
                    ),
              if (productType == "simple") ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _clearProductError("price"),
                        decoration: _fieldDecoration(context, labelText: "Цена (сомони) *", errorText: _fieldErrors["price"]),
                        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: salePrice,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _clearProductError("sale_price"),
                        decoration: _fieldDecoration(context, labelText: "Цена скидки", errorText: _fieldErrors["sale_price"]),
                        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockQty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _fieldDecoration(context, labelText: "Остаток"),
                        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final picked = await _showSelect2Sheet<String>(
                              context,
                              title: "Единица измерения",
                              items: _kStockCodes,
                              asText: _stockUnitRu,
                            );
                            if (picked != null && mounted) setState(() => stockUnit = picked);
                          },
                          child: InputDecorator(
                            decoration: _fieldDecoration(context, labelText: "Ед. изм."),
                            isEmpty: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _stockUnitRu(stockUnit),
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: titleColor),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down_rounded, color: muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _formSection(
          context,
          child: TextField(
            controller: description,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => _clearProductError("description"),
            decoration: _fieldDecoration(context, labelText: "Описание *", errorText: _fieldErrors["description"]),
            style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
          ),
        ),
      ),
      if (productType == "simple")
        SliverToBoxAdapter(
          child: _formSection(
            context,
            sectionTitle: "Фото",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Фото: ${images.length}/10", style: TextStyle(fontWeight: FontWeight.w700, color: titleColor, fontSize: 13)),
                const SizedBox(height: 8),
                if (images.isNotEmpty)
                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (context, _) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final e = images[i];
                        return SizedBox(
                          width: 104,
                          height: 104,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: _LocalXFileImage(file: e, width: 104, height: 104),
                                ),
                                if (i == 0)
                                  Positioned(
                                    left: 6,
                                    top: 6,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _kSellerBrand,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        child: Text("Основное", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Material(
                                    color: _kSellerPhotoTeal,
                                    shape: const CircleBorder(),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        images.removeAt(i);
                                        if (images.isNotEmpty) _imagesError = null;
                                      }),
                                      child: const Padding(
                                        padding: EdgeInsets.all(5),
                                        child: Icon(Icons.close, size: 14, color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 28,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
                                          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                                          onPressed: i == 0
                                              ? null
                                              : () => setState(() {
                                                    final t = images[i - 1];
                                                    images[i - 1] = images[i];
                                                    images[i] = t;
                                                  }),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
                                          icon: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
                                          onPressed: i >= images.length - 1
                                              ? null
                                              : () => setState(() {
                                                    final t = images[i + 1];
                                                    images[i + 1] = images[i];
                                                    images[i] = t;
                                                  }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _kSellerBrand),
                  onPressed: _addPhotos,
                  child: const Text("Выбрать фото", style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (_imagesError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_imagesError!, style: const TextStyle(color: Colors.orange)),
                  ),
              ],
            ),
          ),
        ),
      if (productType == "simple")
        SliverToBoxAdapter(
          child: _buildProductVideoSection(context, token),
        ),
      if (productType == "variant")
        SliverToBoxAdapter(
          child: _formSection(
            context,
            sectionTitle: "Варианты",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Добавьте варианты: для каждого укажите свойства (цвет, размер и др.), цену, остаток и фото.",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35, color: muted),
                ),
                if (_variantCatalogLoading) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: _kSellerBrand,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text("Варианты товара", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: titleColor)),
                if (variants.isEmpty) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 42, color: muted.withValues(alpha: 0.65)),
                        const SizedBox(height: 10),
                        Text(
                          "Пока нет ни одного варианта.\nНажмите кнопку ниже, чтобы создать первую комбинацию.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600, color: muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
                ...List.generate(variants.length, (i) {
                  final v = variants[i];
                  final errs = _variantErrors[i] ?? const {};
                  final innerBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC);
                  final innerBr = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: innerBr, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${i + 1} Настройка варианта",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: titleColor),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                final removed = variants.removeAt(i);
                                removed.dispose();
                                _variantErrors.remove(i);
                                if (_variantErrors.isNotEmpty) {
                                  final shifted = <int, Map<String, String>>{};
                                  for (final entry in _variantErrors.entries) {
                                    final k = entry.key;
                                    shifted[k > i ? k - 1 : k] = entry.value;
                                  }
                                  _variantErrors
                                    ..clear()
                                    ..addAll(shifted);
                                }
                                _applyAutoVariantSkusInPlace();
                              }),
                              icon: Icon(Icons.delete_outline_rounded, color: muted),
                            ),
                          ],
                        ),
                        if (errs["attrs"] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(errs["attrs"]!, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          "АРТИКУЛ ВАРИАНТА",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: v.sku,
                          onChanged: (_) {
                            v.skuAuto = false;
                            _clearVariantError(i, "sku");
                          },
                          decoration: _fieldDecoration(context, labelText: "", hintText: "Тест-1", errorText: errs["sku"]),
                          style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "ОСТАТОК НА СКЛАДЕ",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: v.stockQty,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _fieldDecoration(context, labelText: "", hintText: "0"),
                                style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 112,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final picked = await _showSelect2Sheet<String>(
                                      context,
                                      title: "Единица",
                                      items: _kStockCodes,
                                      asText: _stockUnitRu,
                                    );
                                    if (picked != null && mounted) {
                                      setState(() => v.stockUnit = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: _fieldDecoration(context, labelText: ""),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _stockUnitRu(v.stockUnit),
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: titleColor),
                                          ),
                                        ),
                                        Icon(Icons.keyboard_arrow_down_rounded, color: muted, size: 22),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D1117) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: innerBr.withValues(alpha: 0.9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "СВОЙСТВА (ЦВЕТ, РАЗМЕР И ДР.)",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.55,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...List.generate(v.attrs.length, (j) {
                                final a = v.attrs[j];
                                final valueChoices = _valueChoicesForAttr(a);
                                return Padding(
                                  padding: EdgeInsets.only(bottom: j == v.attrs.length - 1 ? 0 : 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: _variantCatalog.options.isEmpty
                                            ? TextField(
                                                controller: a.optionName,
                                                onChanged: (_) {
                                                  a.optionSlug = _slugify(a.optionName.text);
                                                  a.type = _inferAttrType(a.optionSlug, a.optionName.text);
                                                  _clearVariantError(i, "attr_$j");
                                                },
                                                decoration: _fieldDecoration(
                                                  context,
                                                  labelText: "Название опции",
                                                  errorText: errs["attr_${j}_opt"],
                                                ),
                                                style: TextStyle(color: titleColor),
                                              )
                                            : _select2Tile(
                                                context: context,
                                                label: "Название опции",
                                                hint: "Выберите…",
                                                display: a.optionName.text.isEmpty ? "" : a.optionName.text,
                                                errorText: errs["attr_${j}_opt"],
                                                onTap: () async {
                                                  final picked = await _showSelect2Sheet<VariantOptionMeta>(
                                                    context,
                                                    title: "Опция",
                                                    items: _variantCatalog.options,
                                                    asText: (o) => o.name,
                                                  );
                                                  if (picked != null && mounted) {
                                                    setState(() {
                                                      a.optionSlug = picked.slug;
                                                      a.optionName.text = picked.name;
                                                      a.type = _inferAttrType(picked.slug, picked.name, meta: picked);
                                                      a.value.clear();
                                                      _clearVariantError(i, "attr_$j");
                                                    });
                                                  }
                                                },
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (valueChoices.isNotEmpty)
                                              _select2Tile(
                                                context: context,
                                                label: "Значение",
                                                hint: "Выберите...",
                                                display: _variantValueDisplay(a),
                                                errorText: errs["attr_$j"],
                                                onTap: () async {
                                                  final picked = await _showSelect2Sheet<VariantValueMeta>(
                                                    context,
                                                    title: "Значение",
                                                    items: valueChoices,
                                                    asText: (val) => val.label.isNotEmpty ? val.label : val.value,
                                                  );
                                                  if (picked != null && mounted) {
                                                    setState(() {
                                                      a.value.text = picked.value;
                                                      _clearVariantError(i, "attr_$j");
                                                    });
                                                  }
                                                },
                                              )
                                            else
                                              TextField(
                                                controller: a.value,
                                                onChanged: (_) => _clearVariantError(i, "attr_$j"),
                                                decoration: _fieldDecoration(
                                                  context,
                                                  labelText: "Значение",
                                                  hintText: "Выберите или напечатайте…",
                                                  errorText: errs["attr_$j"],
                                                ),
                                                style: TextStyle(color: titleColor),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setState(() {
                                          a.dispose();
                                          v.attrs.removeAt(j);
                                        }),
                                        icon: Icon(Icons.delete_outline_rounded, color: muted.withValues(alpha: 0.85)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: _kSellerBrand,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => setState(() {
                                    v.attrs.add(_blankAttrRow());
                                  }),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text("Добавить свойство", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "СТОИМОСТЬ",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: v.price,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _clearVariantError(i, "price"),
                          decoration: _fieldDecoration(context, labelText: "Цена (сомони) *", errorText: errs["price"]),
                          style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: v.salePrice,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _clearVariantError(i, "sale_price"),
                          decoration: _fieldDecoration(context, labelText: "Цена со скидкой", errorText: errs["sale_price"]),
                          style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "ФОТО ВАРИАНТА *",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: v.image == null
                                  ? Text("Файл не выбран", style: TextStyle(color: muted, fontWeight: FontWeight.w600))
                                  : Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _LocalXFileImage(file: v.image!, width: 46, height: 46),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            v.image!.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: _kSellerBrand),
                              onPressed: () => _pickVariantImage(i),
                              child: const Text("Фото", style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            IconButton(
                              onPressed: v.image == null
                                  ? null
                                  : () => setState(() {
                                        v.image = null;
                                        _variantErrors[i] = {...?_variantErrors[i], "image": "Фото обязательно."};
                                      }),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        if (errs["image"] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(errs["image"]!, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kSellerBrand.withValues(alpha: isDark ? 0.14 : 0.12),
                      foregroundColor: _kSellerBrand,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _addVariantRow,
                    child: const Text("Добавить вариант", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
                if (_variantsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_variantsError!, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      if (productType == "variant")
        SliverToBoxAdapter(
          child: _buildProductVideoSection(context, token),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 88 + _sellerFloatingNavBottomGap(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kSellerBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: saving || token == null || categoryId == null
                    ? null
                    : () async {
                        setState(() {
                          saving = true;
                          msg = null;
                          _fieldErrors.clear();
                          _variantErrors.clear();
                          _imagesError = null;
                          _variantsError = null;
                        });
                        try {
                          if (!_validateProduct()) return;
                          final fields = <String, String>{
                            "product_type": productType,
                            "title": title.text.trim(),
                            "category": categoryId.toString(),
                            "description": description.text.trim(),
                          };
                          if (sku.text.trim().isNotEmpty) fields["sku"] = sku.text.trim();
                          final variantImages = <XFile>[];
                          if (productType == "simple") {
                            if (price.text.trim().isEmpty) throw Exception("Цена обязательна.");
                            fields["price"] = price.text.trim();
                            if (salePrice.text.trim().isNotEmpty) fields["sale_price"] = salePrice.text.trim();
                            if (stockQty.text.trim().isNotEmpty) fields["stock_qty"] = stockQty.text.trim();
                            fields["stock_unit"] = stockUnit;
                            if (images.isEmpty) throw Exception("Добавьте хотя бы 1 фото.");
                          } else {
                            if (variants.isEmpty) throw Exception("Добавьте минимум 1 вариант.");
                            final payload = <Map<String, dynamic>>[];
                            for (var i = 0; i < variants.length; i++) {
                              final v = variants[i];
                              if (v.price.text.trim().isEmpty) throw Exception("Вариант ${i + 1}: цена обязательна.");
                              final vImg = v.image;
                              if (vImg == null) throw Exception("Вариант ${i + 1}: фото обязательно.");
                              variantImages.add(vImg);
                              final vals = <Map<String, dynamic>>[];
                              for (final a in v.attrs) {
                                final rawName = a.optionName.text.trim();
                                var slug = a.optionSlug.trim();
                                if (slug.isEmpty) slug = _slugify(rawName);
                                if (slug.isEmpty) slug = "option";
                                final val = a.value.text.trim();
                                if (val.isEmpty) continue;
                                vals.add({
                                  "option_slug": slug,
                                  "option_name": rawName.isEmpty ? "Опция" : rawName,
                                  "value": val,
                                });
                              }
                              payload.add({
                                "sort_order": i,
                                "sku": v.sku.text.trim(),
                                "values": vals,
                                "price": v.price.text.trim(),
                                "sale_price": v.salePrice.text.trim().isEmpty ? null : v.salePrice.text.trim(),
                                "stock_qty": v.stockQty.text.trim().isEmpty ? "0" : v.stockQty.text.trim(),
                                "stock_unit": v.stockUnit,
                                "is_active": true,
                              });
                            }
                            fields["variants"] = jsonEncode(payload);
                            final minPrice = variants
                                .map((e) => double.tryParse(e.price.text.trim()) ?? 0)
                                .where((e) => e > 0)
                                .fold<double>(0, (a, b) => a == 0 ? b : (b < a ? b : a));
                            if (minPrice > 0) fields["price"] = minPrice.toStringAsFixed(2);
                            if (variants.isNotEmpty) fields["stock_unit"] = variants.first.stockUnit;
                          }
                          final videoUidTrim = _videoUid?.trim();
                          if (videoUidTrim != null && videoUidTrim.isNotEmpty) {
                            fields["cloudflare_video_uid"] = videoUidTrim;
                          }
                          await widget.api.createProductMultipart(
                            accessToken: token,
                            fields: fields,
                            images: productType == "simple" ? images : const [],
                            variantImages: variantImages,
                          );
                          msg = null;
                          await _disposeVideoPreview(notify: false);
                          if (!mounted) return;
                          setState(() {
                            for (final v in variants) {
                              v.dispose();
                            }
                            title.clear();
                            sku.clear();
                            price.clear();
                            salePrice.clear();
                            stockQty.clear();
                            description.clear();
                            images = [];
                            variants = [];
                            _videoUid = null;
                            _videoWatchUrl = null;
                            _videoFileLabel = null;
                            _videoPreviewOpening = false;
                          });
                          if (!mounted) return;
                          final goMy = widget.onProductCreatedGoToMyProducts;
                          if (goMy != null) {
                            if (!context.mounted) return;
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final titleC = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
                            await showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) {
                                Future<void>.delayed(const Duration(seconds: 5), () {
                                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                                });
                                return AlertDialog(
                                  backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  title: Text("Товар сохранён", style: TextStyle(fontWeight: FontWeight.w900, color: titleC)),
                                  content: Text(
                                    "После одобрения модератором ваш товар будет опубликован в приложении Kharid.tj",
                                    style: TextStyle(height: 1.35, fontWeight: FontWeight.w600, color: titleC),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(),
                                      child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (!context.mounted) return;
                            goMy(context);
                          } else {
                            msg = "Товар добавлен.";
                          }
                        } catch (e) {
                          msg = "$e";
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: Text(saving ? "Сохранение..." : "Добавить товар", style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(msg!, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final token = app.accessToken;
    final me = app.me;
    final navFn = widget.onSellerAccountNav;

    final scroll = CustomScrollView(
      slivers: _buildFormSlivers(context, token),
    );

    if (me != null && me.role == "seller" && navFn != null) {
      final nav = _sellerNavForMe(me, _mlmEnabled);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
      final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
      final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
      final fullName = "${me.user.firstName} ${me.user.lastName}".trim();
      final sidebarTitle = fullName.isNotEmpty
          ? fullName
          : ((me.storeName ?? "").trim().isNotEmpty ? me.storeName!.trim() : "Профиль");

      Widget drawerBody({VoidCallback? afterPick}) {
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
                    border: Border.all(color: _kSellerBrand.withValues(alpha: isDark ? 0.45 : 0.35)),
                    color: isDark ? const Color(0x331D4ED8) : const Color(0xFFEFF6FF),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("Баланс", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kSellerBrand.withValues(alpha: 0.85))),
                        const SizedBox(height: 2),
                        Text(
                          "${me.balance.isEmpty ? "0.00" : me.balance} смн",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () {
                            afterPick?.call();
                            navFn("/account/seller/balance", "Баланс");
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _kSellerBrand,
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
                        if (it.path.endsWith("/add-product")) return;
                        navFn(it.path, it.title);
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
                      Text("Добавить товар", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                      Text("Профиль", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => navFn("/account/seller/balance", "Баланс"),
                style: TextButton.styleFrom(
                  backgroundColor: _kSellerBrand,
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
              final active = it.path.endsWith("/add-product");
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  if (active) return;
                  navFn(it.path, it.title);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _kSellerBrand : cardBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: active ? _kSellerBrand : border),
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
        appBar: KharidSiteHeader(
          onMenuPressed: () => context.read<AppState>().openSideMenuFrom(context),
          subtitle: const Text("Профиль"),
        ),
        drawer: Drawer(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: drawerBody(afterPick: () => Navigator.of(context).maybePop()),
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
                Expanded(child: scroll),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: KharidSiteHeader(
        onMenuPressed: () => context.read<AppState>().openSideMenuFrom(context),
        subtitle: const Text("Добавить товар"),
      ),
      body: scroll,
    );
  }

  bool _validateProduct() {
    _fieldErrors.clear();
    _variantErrors.clear();
    _imagesError = null;
    _variantsError = null;
    if (title.text.trim().isEmpty) _fieldErrors["title"] = "Название обязательно.";
    if (description.text.trim().isEmpty) _fieldErrors["description"] = "Описание обязательно.";
    if (categoryId == null) _fieldErrors["category"] = "Категория обязательна.";
    if (productType == "simple") {
      if (price.text.trim().isEmpty) _fieldErrors["price"] = "Цена обязательна.";
      final p = double.tryParse(price.text.trim());
      final sp = double.tryParse(salePrice.text.trim());
      if (price.text.trim().isNotEmpty && (p == null || p <= 0)) _fieldErrors["price"] = "Цена должна быть больше 0.";
      if (sp != null && p != null && sp > p) _fieldErrors["sale_price"] = "Скидочная цена не может быть больше обычной.";
      if (images.isEmpty) _imagesError = "Добавьте хотя бы 1 фото.";
    } else {
      if (variants.isEmpty) {
        _variantsError = "Добавьте минимум 1 вариант.";
      } else {
        for (var i = 0; i < variants.length; i++) {
          final v = variants[i];
          final errs = <String, String>{};
          if (v.attrs.isEmpty) {
            errs["attrs"] = "Добавьте хотя бы одно свойство.";
          }
          if (v.price.text.trim().isEmpty) errs["price"] = "Цена обязательна.";
          final p = double.tryParse(v.price.text.trim());
          final sp = double.tryParse(v.salePrice.text.trim());
          if (v.price.text.trim().isNotEmpty && (p == null || p <= 0)) errs["price"] = "Цена должна быть больше 0.";
          if (sp != null && p != null && sp > p) errs["sale_price"] = "Скидочная цена больше цены.";
          if (v.image == null && (v.existingImageUrl == null || v.existingImageUrl!.trim().isEmpty)) {
            errs["image"] = "Фото обязательно.";
          }
          for (var j = 0; j < v.attrs.length; j++) {
            final a = v.attrs[j];
            if (_variantCatalog.options.isNotEmpty) {
              if (a.optionSlug.trim().isEmpty || a.optionName.text.trim().isEmpty) {
                errs["attr_${j}_opt"] = "Выберите опцию.";
              }
            } else {
              if (a.optionName.text.trim().isEmpty) errs["attr_${j}_opt"] = "Название опции.";
            }
            if (a.value.text.trim().isEmpty) errs["attr_$j"] = "Укажите значение.";
          }
          if (errs.isNotEmpty) _variantErrors[i] = errs;
        }
      }
    }
    final hasErrors = _fieldErrors.isNotEmpty || _imagesError != null || _variantsError != null || _variantErrors.isNotEmpty;
    if (hasErrors) {
      setState(() {});
      return false;
    }
    return true;
  }
}

class _VariantAttrDraft {
  _VariantAttrDraft({
    required this.id,
    required this.optionSlug,
    TextEditingController? optionName,
    required this.type,
    TextEditingController? value,
  })  : optionName = optionName ?? TextEditingController(),
        value = value ?? TextEditingController();

  factory _VariantAttrDraft.fromSeed(_AttrSeed seed) {
    return _VariantAttrDraft(
      id: _newVariantId(),
      optionSlug: seed.slug,
      optionName: TextEditingController(text: seed.name),
      type: seed.type,
    );
  }

  final String id;
  String optionSlug;
  final TextEditingController optionName;
  final TextEditingController value;
  String type;

  void dispose() {
    optionName.dispose();
    value.dispose();
  }
}

class _VariantDraft {
  _VariantDraft({required this.attrs})
      : sku = TextEditingController(),
        price = TextEditingController(),
        salePrice = TextEditingController(),
        stockQty = TextEditingController(),
        stockUnit = "pcs";

  factory _VariantDraft.withTemplate(List<_AttrSeed> seeds) {
    return _VariantDraft(
      attrs: seeds.map(_VariantAttrDraft.fromSeed).toList(),
    );
  }

  /// Барои таҳрир: аз ҷавоби API.
  factory _VariantDraft.fromLoadedProductVariant(ProductVariantLite pv) {
    final attrs = <_VariantAttrDraft>[];
    for (final row in pv.valueRows) {
      final slug = row.optionSlug.trim().isNotEmpty ? row.optionSlug : _slugify(row.optionName);
      final name = row.optionName.trim().isNotEmpty ? row.optionName : slug;
      attrs.add(
        _VariantAttrDraft(
          id: _newVariantId(),
          optionSlug: slug,
          optionName: TextEditingController(text: name),
          type: _inferAttrType(slug, name),
          value: TextEditingController(text: row.value),
        ),
      );
    }
    if (attrs.isEmpty) {
      attrs.add(_VariantAttrDraft.fromSeed(const _AttrSeed(type: "color", slug: "color", name: "Цвет")));
    }
    final d = _VariantDraft(attrs: attrs);
    d.backendVariantId = pv.id > 0 ? pv.id : null;
    d.existingImageUrl = (pv.image ?? "").trim().isNotEmpty ? pv.image : null;
    d.skuAuto = false;
    d.sku.text = pv.sku;
    d.price.text = pv.price;
    d.salePrice.text = pv.salePrice ?? "";
    d.stockQty.text = pv.stockQty ?? "";
    d.stockUnit = pv.stockUnit;
    return d;
  }

  bool skuAuto = true;
  int? backendVariantId;
  String? existingImageUrl;
  final TextEditingController sku;
  final TextEditingController price;
  final TextEditingController salePrice;
  final TextEditingController stockQty;
  String stockUnit;
  List<_VariantAttrDraft> attrs;

  XFile? image;

  void dispose() {
    sku.dispose();
    price.dispose();
    salePrice.dispose();
    stockQty.dispose();
    for (final a in attrs) {
      a.dispose();
    }
  }
}

/// Таҳрири товари фурӯшанда дар дохили барнома (PATCH `/products/{slug}/`).
class FullSellerEditProductScreen extends StatefulWidget {
  const FullSellerEditProductScreen({super.key, required this.api, required this.productSlug});
  final ApiClient api;
  final String productSlug;

  @override
  State<FullSellerEditProductScreen> createState() => _FullSellerEditProductScreenState();
}

class _FullSellerEditProductScreenState extends State<FullSellerEditProductScreen> {
  static const List<String> _stockCodes = ["pcs", "kg", "l", "m"];
  bool _loading = true;
  String? _loadErr;
  String? _msg;
  bool _saving = false;
  ProductDetail? _detail;
  final title = TextEditingController();
  final sku = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final salePrice = TextEditingController();
  final stockQty = TextEditingController();
  String stockUnit = "pcs";
  int? categoryId;
  List<CategoryLite> categories = const [];
  String productType = "simple";
  bool isActive = true;
  List<XFile> newSimpleImages = [];
  List<_VariantDraft> variants = [];
  VariantCatalogMeta _variantCatalog = const VariantCatalogMeta(options: [], valuesBySlug: {});
  String? _cloudflareUid;

  String _unitRu(String code) {
    switch (code) {
      case "kg":
        return "кг";
      case "l":
        return "л";
      case "m":
        return "м";
      default:
        return "шт";
    }
  }

  String _attrValueLabel(_VariantAttrDraft a) {
    final q = a.value.text.trim();
    if (q.isEmpty) return "";
    for (final x in _variantValueChoicesForCatalog(_variantCatalog, a)) {
      if (x.value == q) return x.label.isNotEmpty ? x.label : x.value;
    }
    return q;
  }

  CategoryLite? _catById() {
    if (categoryId == null) return null;
    for (final c in categories) {
      if (c.id == categoryId) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final token = context.read<AppState>().accessToken;
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final cats = await widget.api.categories();
      final meta = await widget.api.fetchVariantCatalogMeta(accessToken: token);
      final d = await widget.api.productDetailAuthenticated(token, widget.productSlug);
      if (!mounted) return;
      setState(() {
        categories = cats;
        _variantCatalog = meta;
        _detail = d;
        title.text = d.title;
        sku.text = d.sku;
        description.text = d.description;
        productType = d.productType == "variant" ? "variant" : "simple";
        isActive = d.isActive;
        categoryId = d.categoryId;
        price.text = d.price;
        salePrice.text = d.salePrice ?? "";
        stockQty.text = d.stockQty ?? "";
        final su = d.stockUnit?.trim() ?? "";
        stockUnit = su.isNotEmpty ? su : "pcs";
        _cloudflareUid = d.cloudflareVideoUid?.trim().isNotEmpty == true ? d.cloudflareVideoUid : null;
        if (categoryId == null && d.categorySlug != null && d.categorySlug!.isNotEmpty) {
          for (final c in cats) {
            if (c.slug == d.categorySlug) {
              categoryId = c.id;
              break;
            }
          }
        }
        variants = d.variants.map(_VariantDraft.fromLoadedProductVariant).toList();
        _loading = false;
        _loadErr = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadErr = "$e";
        });
      }
    }
  }

  Future<void> _pickSimpleMorePhotos() async {
    final picker = ImagePicker();
    final list = await picker.pickMultiImage(imageQuality: 90);
    if (list.isNotEmpty && mounted) {
      setState(() => newSimpleImages = [...newSimpleImages, ...list].take(10).toList());
    }
  }

  Future<void> _pickVariantImage(int i) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x != null && mounted) {
      setState(() => variants[i].image = x);
    }
  }

  Future<void> _save() async {
    final token = context.read<AppState>().accessToken;
    if (token == null || _detail == null || categoryId == null) return;
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) {
      setState(() => _msg = "Заполните название и описание.");
      return;
    }
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      final fields = <String, String>{
        "title": title.text.trim(),
        "sku": sku.text.trim(),
        "description": description.text.trim(),
        "category": categoryId.toString(),
        "product_type": productType,
        "is_active": isActive ? "true" : "false",
      };
      final vuid = _cloudflareUid?.trim();
      if (vuid != null && vuid.isNotEmpty) fields["cloudflare_video_uid"] = vuid;

      final variantFiles = <XFile>[];
      if (productType == "simple") {
        if (price.text.trim().isEmpty) throw Exception("Укажите цену.");
        fields["price"] = price.text.trim();
        if (salePrice.text.trim().isNotEmpty) fields["sale_price"] = salePrice.text.trim();
        if (stockQty.text.trim().isNotEmpty) fields["stock_qty"] = stockQty.text.trim();
        fields["stock_unit"] = stockUnit;
      } else {
        if (variants.isEmpty) throw Exception("Нет вариантов.");
        final payload = <Map<String, dynamic>>[];
        for (var i = 0; i < variants.length; i++) {
          final v = variants[i];
          if (v.price.text.trim().isEmpty) throw Exception("Вариант ${i + 1}: цена.");
          final vals = <Map<String, dynamic>>[];
          for (final a in v.attrs) {
            final rawName = a.optionName.text.trim();
            var slug = a.optionSlug.trim();
            if (slug.isEmpty) slug = _slugify(rawName);
            if (slug.isEmpty) slug = "option";
            final val = a.value.text.trim();
            if (val.isEmpty) continue;
            vals.add({
              "option_slug": slug,
              "option_name": rawName.isEmpty ? "Опция" : rawName,
              "value": val,
            });
          }
          final row = <String, dynamic>{
            "sort_order": i,
            "sku": v.sku.text.trim(),
            "values": vals,
            "price": v.price.text.trim(),
            "sale_price": v.salePrice.text.trim().isEmpty ? null : v.salePrice.text.trim(),
            "stock_qty": v.stockQty.text.trim().isEmpty ? "0" : v.stockQty.text.trim(),
            "stock_unit": v.stockUnit,
            "is_active": true,
          };
          final bid = v.backendVariantId;
          if (bid != null) row["id"] = bid;
          payload.add(row);
          if (v.image != null) {
            variantFiles.add(v.image!);
          } else {
            final u = v.existingImageUrl?.trim();
            if (u == null || u.isEmpty) throw Exception("Вариант ${i + 1}: нет фото.");
            variantFiles.add(await _downloadProductImageAsXFile(u));
          }
        }
        fields["variants"] = jsonEncode(payload);
        final minPrice = variants
            .map((e) => double.tryParse(e.price.text.trim()) ?? 0)
            .where((e) => e > 0)
            .fold<double>(0, (a, b) => a == 0 ? b : (b < a ? b : a));
        if (minPrice > 0) fields["price"] = minPrice.toStringAsFixed(2);
        if (variants.isNotEmpty) fields["stock_unit"] = variants.first.stockUnit;
      }

      await widget.api.updateProductMultipart(
        accessToken: token,
        slug: widget.productSlug,
        fields: fields,
        images: newSimpleImages,
        variantImages: variantFiles,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _msg = "$e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _efd(BuildContext context, {required String labelText, String? hintText, String? errorText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1);
    final fill = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);
    const bw = 1.85;
    return InputDecoration(
      labelText: labelText.isEmpty ? null : labelText,
      hintText: hintText,
      errorText: errorText,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border, width: bw)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border, width: bw)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kSellerBrand, width: 2.4)),
    );
  }

  Widget _efs(BuildContext context, {String? sectionTitle, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0B1120) : Colors.white;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sectionTitle != null) ...[
            Text(sectionTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor)),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }

  Widget _pickTile({
    required BuildContext context,
    required String label,
    required String hint,
    required String display,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1);
    final fill = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);
    const bw = 1.85;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: titleColor)),
        const SizedBox(height: 6),
        Material(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: bw),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display.isEmpty ? hint : display,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: display.isEmpty ? muted : titleColor),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    title.dispose();
    sku.dispose();
    description.dispose();
    price.dispose();
    salePrice.dispose();
    stockQty.dispose();
    for (final v in variants) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final token = context.watch<AppState>().accessToken;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Редактировать")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadErr != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Редактировать")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadErr!, textAlign: TextAlign.center, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text("Редактировать товар")),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + _sellerFloatingNavBottomGap(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _efs(
              context,
              sectionTitle: "Основное",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Тип: ${productType == "variant" ? "Вариантный" : "Простой"}", style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
                  const SizedBox(height: 12),
                  TextField(controller: title, decoration: _efd(context, labelText: "Название *"), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(controller: sku, decoration: _efd(context, labelText: "Артикул"), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _pickTile(
                    context: context,
                    label: "Категория *",
                    hint: "Выберите",
                    display: _catById()?.name ?? "",
                    onTap: () async {
                      if (categories.isEmpty) return;
                      final picked = await _showSelect2Sheet<CategoryLite>(context, title: "Категория", items: categories, asText: (c) => c.name);
                      if (picked != null && mounted) setState(() => categoryId = picked.id);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 6,
                    decoration: _efd(context, labelText: "Описание *"),
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Активен в каталоге", style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v),
                  ),
                ],
              ),
            ),
            if (productType == "simple")
              _efs(
                context,
                sectionTitle: "Цена и остаток",
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _efd(context, labelText: "Цена *"), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: salePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _efd(context, labelText: "Цена со скидкой"), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: stockQty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _efd(context, labelText: "Остаток"), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await _showSelect2Sheet<String>(context, title: "Единица", items: _stockCodes, asText: _unitRu);
                                if (picked != null && mounted) setState(() => stockUnit = picked);
                              },
                              child: InputDecorator(
                                decoration: _efd(context, labelText: "Ед. изм."),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(_unitRu(stockUnit), style: TextStyle(fontWeight: FontWeight.w700, color: titleColor))),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: muted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (productType == "simple" && (_detail?.images.isNotEmpty == true || newSimpleImages.isNotEmpty))
              _efs(
                context,
                sectionTitle: "Фото",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Текущие фото остаются. Новые добавятся в конец.", style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_detail != null && _detail!.images.isNotEmpty)
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _detail!.images.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(_detail!.images[i], width: 88, height: 88, fit: BoxFit.cover),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickSimpleMorePhotos,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text("Добавить фото", style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    if (newSimpleImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text("Новых файлов: ${newSimpleImages.length}", style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            if (productType == "variant")
              ...List.generate(variants.length, (vi) {
                final v = variants[vi];
                return _efs(
                  context,
                  sectionTitle: "Вариант ${vi + 1}",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: v.sku, decoration: _efd(context, labelText: "SKU"), style: TextStyle(color: titleColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: v.price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _efd(context, labelText: "Цена *"), style: TextStyle(color: titleColor))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: v.salePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _efd(context, labelText: "Скидка"), style: TextStyle(color: titleColor))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: v.stockQty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _efd(context, labelText: "Остаток"), style: TextStyle(color: titleColor))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked = await _showSelect2Sheet<String>(context, title: "Ед.", items: _stockCodes, asText: _unitRu);
                                  if (picked != null && mounted) setState(() => v.stockUnit = picked);
                                },
                                child: InputDecorator(
                                  decoration: _efd(context, labelText: "Ед."),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(_unitRu(v.stockUnit), style: TextStyle(fontWeight: FontWeight.w700, color: titleColor))),
                                      Icon(Icons.keyboard_arrow_down_rounded, color: muted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (var ai = 0; ai < v.attrs.length; ai++) ...[
                        Text(v.attrs[ai].optionName.text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted)),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (ctx) {
                            final a = v.attrs[ai];
                            final choices = _variantValueChoicesForCatalog(_variantCatalog, a);
                            if (choices.isNotEmpty) {
                              return _pickTile(
                                context: context,
                                label: "Значение",
                                hint: "Выберите",
                                display: _attrValueLabel(a),
                                onTap: () async {
                                  final picked = await _showSelect2Sheet<VariantValueMeta>(context, title: "Значение", items: choices, asText: (x) => x.label.isNotEmpty ? x.label : x.value);
                                  if (picked != null && mounted) setState(() => a.value.text = picked.value);
                                },
                              );
                            }
                            return TextField(controller: a.value, decoration: _efd(context, labelText: "Значение"), style: TextStyle(color: titleColor));
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if ((v.existingImageUrl ?? "").isNotEmpty && v.image == null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(v.existingImageUrl!, width: 56, height: 56, fit: BoxFit.cover),
                            ),
                          if ((v.existingImageUrl ?? "").isNotEmpty && v.image == null) const SizedBox(width: 8),
                          if (v.image != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _LocalXFileImage(file: v.image!, width: 56, height: 56),
                            ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _pickVariantImage(vi),
                            icon: const Icon(Icons.photo_outlined),
                            label: const Text("Фото", style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(_msg!, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kSellerBrand, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: (token == null || _saving) ? null : _save,
                child: Text(_saving ? "Сохранение…" : "Сохранить", style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
