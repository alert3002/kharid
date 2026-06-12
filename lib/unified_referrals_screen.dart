import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "api_client.dart";
import "app_state.dart";
import "models.dart";

const _kSiteOrigin = String.fromEnvironment("WEB_BASE_URL", defaultValue: "https://kharid.tj");
const _brand = Color(0xFF2563EB);

/// Монанди `frontend/components/dashboards/sections/unified-referrals.tsx`.
class ReferralsBody extends StatefulWidget {
  const ReferralsBody({super.key, required this.api, this.bottomPadding = 0});

  final ApiClient api;
  final double bottomPadding;

  @override
  State<ReferralsBody> createState() => _ReferralsBodyState();
}

class _ReferralsBodyState extends State<ReferralsBody> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  _ReferralsViewTab _tab = _ReferralsViewTab.tree;
  bool _copied = false;

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
        _error = "Войдите в аккаунт";
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.referralsMy(token);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "$e".replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  String _referralCode(MeProfile? me) {
    final fromMe = (me?.referralShortCode ?? "").trim().isNotEmpty
        ? me!.referralShortCode!.trim()
        : (me?.referralCode ?? "").trim();
    if (fromMe.isNotEmpty) return fromMe;
    return (_data?["code_short"]?.toString() ?? "").trim();
  }

  Future<void> _copyLink(String code) async {
    if (code.isEmpty) return;
    final link = "$_kSiteOrigin/account?ref=${Uri.encodeComponent(code)}";
    await Clipboard.setData(ClipboardData(text: link));
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppState>().me;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;
    final code = _referralCode(me);
    final shareLink = code.isEmpty ? "" : "$_kSiteOrigin/account?ref=${Uri.encodeComponent(code)}";

    if (_loading && _data == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Ваш реферальный код", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
                            const SizedBox(height: 6),
                            Text(code.isEmpty ? "—" : code, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2, color: titleColor)),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: code.isEmpty ? null : () => _copyLink(code),
                        style: FilledButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        child: Text(_copied ? "Скопировано" : "Копия ссылки", style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(shareLink.isEmpty ? "—" : shareLink, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        "Рефералы считаются по уровням из админки (MLM levels). Вы можете делиться этим кодом при регистрации.",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text("Статистика", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor)),
                      const Spacer(),
                      if (_loading) Text("Загрузка…", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3)),
                      ),
                      child: Padding(padding: const EdgeInsets.all(10), child: Text(_error!, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor))),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(label: "Всего: ${_data?["total"] ?? "—"}", highlighted: false, isDark: isDark),
                      if (_data?["counts_by_level"] is Map)
                        ...Map<String, dynamic>.from(_data!["counts_by_level"] as Map).entries.map(
                          (e) => _StatChip(label: "У${e.key}: ${e.value}", highlighted: true, isDark: isDark),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ViewTabButton(label: "🌿 Дерево", selected: _tab == _ReferralsViewTab.tree, onTap: () => setState(() => _tab = _ReferralsViewTab.tree)),
                      const SizedBox(width: 8),
                      _ViewTabButton(label: "📋 Таблица", selected: _tab == _ReferralsViewTab.table, onTap: () => setState(() => _tab = _ReferralsViewTab.table)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_tab == _ReferralsViewTab.tree)
                    SizedBox(
                      height: 520,
                      child: _data == null
                          ? Center(child: Text("Загрузка дерева…", style: TextStyle(color: muted)))
                          : _ReferralTreeCanvas(data: _data!, me: me),
                    )
                  else
                    _ReferralsTable(data: _data, isDark: isDark, border: border, titleColor: titleColor, muted: muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ReferralsViewTab { tree, table }

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.highlighted, required this.isDark});
  final String label;
  final bool highlighted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.45) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
      ),
    );
  }
}

class _ViewTabButton extends StatelessWidget {
  const _ViewTabButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? _brand : (isDark ? const Color(0xFF18181B) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected ? BorderSide.none : BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)))),
        ),
      ),
    );
  }
}

class _ReferralsTable extends StatelessWidget {
  const _ReferralsTable({required this.data, required this.isDark, required this.border, required this.titleColor, required this.muted});
  final Map<String, dynamic>? data;
  final bool isDark;
  final Color border;
  final Color titleColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final rows = data?["table"] is List
        ? (data!["table"] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(500).toList()
        : <Map<String, dynamic>>[];

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text("Нет рефералов.", style: TextStyle(fontWeight: FontWeight.w600, color: muted))),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(isDark ? Colors.black : const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(label: Text("Ур.", style: TextStyle(fontWeight: FontWeight.w900, color: muted))),
              DataColumn(label: Text("Пользователь", style: TextStyle(fontWeight: FontWeight.w900, color: muted))),
              DataColumn(label: Text("Телефон", style: TextStyle(fontWeight: FontWeight.w900, color: muted))),
              DataColumn(label: Text("Роль", style: TextStyle(fontWeight: FontWeight.w900, color: muted))),
              DataColumn(label: Text("Дата", style: TextStyle(fontWeight: FontWeight.w900, color: muted))),
            ],
            rows: rows.map((r) {
                    final role = r["role"]?.toString() ?? "";
                    final color = _roleColor(role);
                    return DataRow(
                      cells: [
                        DataCell(Text("У${r["level"]}", style: TextStyle(fontWeight: FontWeight.w900, color: titleColor))),
                        DataCell(Text(_nameOf(r), style: TextStyle(fontWeight: FontWeight.w800, color: titleColor))),
                        DataCell(Text((r["phone"]?.toString() ?? "").isEmpty ? "—" : r["phone"].toString(), style: TextStyle(color: muted))),
                        DataCell(
                          DecoratedBox(
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Text(_roleLabel(role), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                            ),
                          ),
                        ),
                        DataCell(Text(_fmtDate(r["joined_at"]?.toString()), style: TextStyle(color: muted))),
                      ],
                    );
                  }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Tree canvas ─────────────────────────────────────────────────────────────

const _nodeW = 200.0;
const _nodeH = 72.0;
const _hGap = 32.0;
const _vGap = 80.0;

class _ReferralTreeCanvas extends StatefulWidget {
  const _ReferralTreeCanvas({required this.data, required this.me});
  final Map<String, dynamic> data;
  final MeProfile? me;

  @override
  State<_ReferralTreeCanvas> createState() => _ReferralTreeCanvasState();
}

class _ReferralTreeCanvasState extends State<_ReferralTreeCanvas> {
  final _tc = TransformationController();
  bool _didFit = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final m = Matrix4.copy(_tc.value);
    final scale = m.getMaxScaleOnAxis() * factor;
    final clamped = scale.clamp(0.2, 3.0);
    final ratio = clamped / m.getMaxScaleOnAxis();
    m.scale(ratio);
    _tc.value = m;
  }

  void _resetView(double canvasW, double layoutW, double layoutH) {
    final scaleX = (canvasW - 80) / layoutW;
    final scale = math.min(math.max(math.min(scaleX, 1.0), 0.3), 1.2);
    final x = (canvasW - layoutW * scale) / 2;
    _tc.value = Matrix4.identity()..translate(x, 40.0)..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final treeRaw = widget.data["tree"];
    if (treeRaw is! Map) {
      return const Center(child: Text("Дерево недоступно"));
    }
    final root = Map<String, dynamic>.from(treeRaw);
    final me = widget.me;
    final rootWithMe = <String, dynamic>{
      "user_id": root["user_id"],
      "username": root["username"] ?? "",
      "first_name": me?.user.firstName ?? root["first_name"] ?? "",
      "last_name": me?.user.lastName ?? root["last_name"] ?? "",
      "children": root["children"] ?? const [],
    };
    final layout = _calcLayout(rootWithMe);

    return LayoutBuilder(
      builder: (context, c) {
        if (!_didFit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _didFit) return;
            _didFit = true;
            _resetView(c.maxWidth, layout.width, layout.height);
          });
        }
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: SizedBox(
                    width: layout.width,
                    height: layout.height,
                    child: CustomPaint(
                      painter: _TreeEdgesPainter(layout.edges),
                      child: Stack(
                        children: [
                          for (final ln in layout.nodes)
                            Positioned(
                              left: ln.x,
                              top: ln.y,
                              width: _nodeW,
                              height: _nodeH,
                              child: _TreeNodeCard(
                                layoutNode: ln,
                                me: me,
                                rootData: rootWithMe,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _ZoomBtn(label: "+", onTap: () => _zoom(1.2)),
                  const SizedBox(height: 6),
                  _ZoomBtn(label: "−", onTap: () => _zoom(0.83)),
                  const SizedBox(height: 6),
                  _ZoomBtn(label: "⊞", small: true, onTap: () => _resetView(c.maxWidth, layout.width, layout.height)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn({required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF334155))),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Text(label, style: TextStyle(fontSize: small ? 12 : 18, fontWeight: FontWeight.w800, color: const Color(0xFFCBD5E1)))),
        ),
      ),
    );
  }
}

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({required this.layoutNode, required this.me, required this.rootData});
  final _LayoutNode layoutNode;
  final MeProfile? me;
  final Map<String, dynamic> rootData;

  @override
  Widget build(BuildContext context) {
    final isRoot = layoutNode.node == null;
    final Map<String, dynamic> row;
    String role;
    String phone;
    int level;
    if (isRoot) {
      row = {
        "first_name": me?.user.firstName ?? rootData["first_name"],
        "last_name": me?.user.lastName ?? rootData["last_name"],
        "username": rootData["username"],
        "phone": me?.phone ?? "",
        "store_name": me?.storeName,
      };
      role = me?.role ?? "seller";
      phone = me?.phone ?? "";
      level = 0;
    } else {
      row = layoutNode.node!;
      role = row["role"]?.toString() ?? "";
      phone = row["phone"]?.toString() ?? "";
      level = (row["level"] as num?)?.toInt() ?? 0;
    }
    final color = _roleColor(role);
    final name = _nameOf(row);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isRoot ? color : const Color(0xFF1E293B), width: isRoot ? 2 : 1.5),
        gradient: isRoot
            ? LinearGradient(colors: [color.withValues(alpha: 0.13), color.withValues(alpha: 0.07)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isRoot ? null : const Color(0xFF161B27),
        boxShadow: [BoxShadow(color: isRoot ? color.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.35), blurRadius: isRoot ? 16 : 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: isRoot ? color : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(isRoot ? "Вы" : "У$level", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isRoot ? Colors.white : const Color(0xFF94A3B8))),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: isRoot ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFFE2E8F0)))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    child: Text(_roleLabel(role), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatPhone(phone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeEdgesPainter extends CustomPainter {
  _TreeEdgesPainter(this.edges);
  final List<_TreeEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final e in edges) {
      final midY = (e.y1 + e.y2) / 2;
      final path = Path()
        ..moveTo(e.x1, e.y1)
        ..cubicTo(e.x1, midY, e.x2, midY, e.x2, e.y2);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeEdgesPainter oldDelegate) => oldDelegate.edges != edges;
}

class _LayoutNode {
  _LayoutNode({required this.id, required this.x, required this.y, required this.node, required this.children});
  final int id;
  double x;
  double y;
  final Map<String, dynamic>? node;
  final List<_LayoutNode> children;
}

class _TreeEdge {
  const _TreeEdge({required this.x1, required this.y1, required this.x2, required this.y2});
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

class _TreeLayout {
  const _TreeLayout({required this.nodes, required this.edges, required this.width, required this.height});
  final List<_LayoutNode> nodes;
  final List<_TreeEdge> edges;
  final double width;
  final double height;
}

_TreeLayout _calcLayout(Map<String, dynamic> root) {
  final nodes = <_LayoutNode>[];
  final edges = <_TreeEdge>[];

  _LayoutNode buildNode(Map<String, dynamic> treeNode, int level) {
    final childrenRaw = treeNode["children"];
    final childrenList = childrenRaw is List ? childrenRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    return _LayoutNode(
      id: (treeNode["user_id"] as num?)?.toInt() ?? 0,
      x: 0,
      y: level * (_nodeH + _vGap),
      node: treeNode,
      children: childrenList.map((c) => buildNode(c, level + 1)).toList(),
    );
  }

  final rootChildren = root["children"];
  final rootChildrenList = rootChildren is List
      ? rootChildren.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  final rootLn = _LayoutNode(
    id: (root["user_id"] as num?)?.toInt() ?? 0,
    x: 0,
    y: 0,
    node: null,
    children: rootChildrenList.map((c) => buildNode(c, 1)).toList(),
  );

  var counter = 0;
  void assignX(_LayoutNode ln) {
    if (ln.children.isEmpty) {
      ln.x = counter * (_nodeW + _hGap);
      counter++;
    } else {
      for (final c in ln.children) {
        assignX(c);
      }
      ln.x = (ln.children.first.x + ln.children.last.x) / 2;
    }
  }

  assignX(rootLn);

  void flatten(_LayoutNode ln) {
    nodes.add(ln);
    for (final c in ln.children) {
      edges.add(_TreeEdge(x1: ln.x + _nodeW / 2, y1: ln.y + _nodeH, x2: c.x + _nodeW / 2, y2: c.y));
      flatten(c);
    }
  }

  flatten(rootLn);
  final maxX = nodes.map((n) => n.x + _nodeW).fold(0.0, math.max);
  final maxY = nodes.map((n) => n.y + _nodeH).fold(0.0, math.max);
  return _TreeLayout(nodes: nodes, edges: edges, width: maxX + _hGap, height: maxY + _vGap);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _nameOf(Map<String, dynamic> r) {
  final full = "${r["first_name"] ?? ""} ${r["last_name"] ?? ""}".trim();
  if (full.isNotEmpty) return full;
  final store = r["store_name"]?.toString() ?? "";
  if (store.isNotEmpty) return store;
  final uname = r["username"]?.toString() ?? "";
  if (uname.isNotEmpty && !RegExp(r"^u992\d+$").hasMatch(uname)) return uname;
  final phone = r["phone"]?.toString() ?? "";
  if (phone.isNotEmpty) return _formatPhone(phone);
  return "—";
}

String _formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r"\D"), "");
  if (digits.startsWith("992")) return "+$digits";
  return phone;
}

String _fmtDate(String? s) {
  if (s == null || s.isEmpty) return "—";
  try {
    final d = DateTime.parse(s);
    if (d.year < 1971) return "—";
    return "${d.day.toString().padLeft(2, "0")}.${d.month.toString().padLeft(2, "0")}.${d.year}";
  } catch (_) {
    return "—";
  }
}

Color _roleColor(String role) {
  if (role == "seller") return const Color(0xFFF59E0B);
  if (role == "courier") return const Color(0xFF10B981);
  if (role == "moderator") return const Color(0xFF8B5CF6);
  return const Color(0xFF3B82F6);
}

String _roleLabel(String role) {
  if (role == "seller") return "Продавец";
  if (role == "courier") return "Курьер";
  if (role == "partner") return "Партнёр";
  if (role == "moderator") return "Модератор";
  return "Покупатель";
}
