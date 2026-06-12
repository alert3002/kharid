import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "api_client.dart";
import "app_state.dart";

/// Монанди `frontend/components/dashboards/sections/earnings-history.tsx`.
class EarningsHistoryBody extends StatefulWidget {
  const EarningsHistoryBody({super.key, required this.api});

  final ApiClient api;

  @override
  State<EarningsHistoryBody> createState() => _EarningsHistoryBodyState();
}

class _EarningsHistoryBodyState extends State<EarningsHistoryBody> {
  static const _brand = Color(0xFF2563EB);

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  _EarningsTab _tab = _EarningsTab.all;

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
      final data = await widget.api.fetchWalletHistory(token);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF09090B) : Colors.white;

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor))),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final totals = data["totals"] is Map ? Map<String, dynamic>.from(data["totals"] as Map) : <String, dynamic>{};
    final rows = _tab == _EarningsTab.all ? _txnList(data["items"]) : _txnList(data["referral_items"]);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 900 ? 5 : (w >= 520 ? 3 : 2);
              final cards = [
                _SummaryCard(title: "Заработал", value: "${totals["earned"] ?? "0"} смн"),
                _SummaryCard(title: "Рефералы", value: "${totals["referral_earned"] ?? "0"} смн"),
                _SummaryCard(title: "Пополнил", value: "${totals["topup"] ?? "0"} смн"),
                _SummaryCard(title: "Вывел", value: "${totals["withdrawn"] ?? "0"} смн"),
                _SummaryCard(title: "Потратил", value: "${totals["spent"] ?? "0"} смн"),
              ];
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cols >= 5 ? 1.55 : 1.35,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TabChip(label: "Все операции", selected: _tab == _EarningsTab.all, onTap: () => setState(() => _tab = _EarningsTab.all)),
              const SizedBox(width: 8),
              _TabChip(
                label: "Доход от рефералов",
                selected: _tab == _EarningsTab.referrals,
                onTap: () => setState(() => _tab = _EarningsTab.referrals),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Container(
                    color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text("ОПЕРАЦИЯ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: muted, letterSpacing: 0.4))),
                        SizedBox(width: 72, child: Text("СУММА", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: muted, letterSpacing: 0.4))),
                        const SizedBox(width: 8),
                        SizedBox(width: 88, child: Text("ДАТА", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: muted, letterSpacing: 0.4))),
                      ],
                    ),
                  ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text("Пока нет операций.", style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
                    )
                  else
                    ...rows.map((tx) {
                      final amount = tx["amount"]?.toString() ?? "0";
                      return Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: border.withValues(alpha: 0.7)))),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_kindLabel(tx["kind"]?.toString() ?? ""), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
                                  if ((tx["comment"]?.toString() ?? "").isNotEmpty)
                                    Text(tx["comment"].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              child: Text("$amount смн", textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _amountColor(amount, isDark))),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 88,
                              child: Text(_fmtDate(tx["created_at"]?.toString() ?? ""), textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: muted)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _txnList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String _kindLabel(String kind) {
    switch (kind) {
      case "referral_bonus":
        return "Реферальный доход";
      case "purchase_cashback":
        return "Кэшбек";
      case "withdrawal":
        return "Вывод средств";
      case "topup":
        return "Пополнение";
      case "order_payment":
        return "Оплата заказа";
      case "delivery_payment":
        return "Заработок (доставка)";
      case "adjustment":
        return "Корректировка";
      default:
        return kind;
    }
  }

  static Color _amountColor(String amount, bool isDark) {
    final n = double.tryParse(amount);
    if (n == null) return isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    if (n > 0) return isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
    if (n < 0) return isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C);
    return isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
  }

  static String _fmtDate(String iso) {
    try {
      return DateTime.parse(iso).toLocal().toString().substring(0, 16);
    } catch (_) {
      return iso;
    }
  }
}

enum _EarningsTab { all, referrals }

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: muted, letterSpacing: 0.35)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? _EarningsHistoryBodyState._brand : (isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
        ),
      ),
    );
  }
}
