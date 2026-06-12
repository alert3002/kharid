import "models.dart";

class AccountRouteItem {
  const AccountRouteItem(this.path, this.title);
  final String path;
  final String title;
}

/// Нави кабинет монанди `frontend/components/dashboards/nav.ts` — бе сатри алоҳидаи «Баланс».
List<AccountRouteItem> cabinetNavForRole(String role) {
  switch (role) {
    case "seller":
      return const [
        AccountRouteItem("/account/seller/products", "Мои товары"),
        AccountRouteItem("/account/seller/add-product", "Добавить товар"),
        AccountRouteItem("/account/seller/orders", "Заказы"),
        AccountRouteItem("/account/seller/analytics", "Аналитика"),
        AccountRouteItem("/account/seller/wishlist", "Мои Избранное"),
        AccountRouteItem("/account/seller/compare", "Сравнение"),
        AccountRouteItem("/account/seller/earnings", "История заработка"),
        AccountRouteItem("/account/seller/referrals", "Мои реферали"),
        AccountRouteItem("/account/seller/settings", "Настройка"),
      ];
    case "courier":
      return const [
        AccountRouteItem("/account/courier/deliveries", "Мои доставки"),
        AccountRouteItem("/account/courier/wishlist", "Мои Избранное"),
        AccountRouteItem("/account/courier/compare", "Сравнение"),
        AccountRouteItem("/account/courier/earnings", "История заработка"),
        AccountRouteItem("/account/courier/referrals", "Мои реферали"),
        AccountRouteItem("/account/courier/settings", "Настройка"),
      ];
    case "partner":
      return const [
        AccountRouteItem("/account/partner/orders", "Мои заказы"),
        AccountRouteItem("/account/partner/wishlist", "Мои Избранное"),
        AccountRouteItem("/account/partner/compare", "Сравнение"),
        AccountRouteItem("/account/partner/earnings", "История заработка"),
        AccountRouteItem("/account/partner/referrals", "Мои реферали"),
        AccountRouteItem("/account/partner/settings", "Настройка"),
      ];
    default:
      return const [
        AccountRouteItem("/account/client/orders", "Мои заказы"),
        AccountRouteItem("/account/client/wishlist", "Мои Избранное"),
        AccountRouteItem("/account/client/compare", "Сравнение"),
        AccountRouteItem("/account/client/earnings", "История заработка"),
        AccountRouteItem("/account/client/referrals", "Мои реферали"),
        AccountRouteItem("/account/client/settings", "Настройка"),
      ];
  }
}

List<AccountRouteItem> cabinetNavFiltered(MeProfile me, bool mlmEnabled) {
  final base = cabinetNavForRole(me.role);
  if (me.mlmMember && mlmEnabled) return base;
  return base
      .where((e) => !e.path.endsWith("/referrals") && !e.path.endsWith("/earnings"))
      .toList(growable: false);
}

String accountPageTitle(String path) {
  if (path.endsWith("/wishlist")) return "Мои Избранное";
  if (path.endsWith("/compare")) return "Сравнение";
  if (path.endsWith("/settings")) return "Настройка";
  if (path.endsWith("/analytics")) return "Аналитика";
  if (path.endsWith("/orders")) return path.contains("seller") ? "Заказы" : "Мои заказы";
  if (path.endsWith("/products")) return "Мои товары";
  if (path.endsWith("/add-product")) return "Добавить товар";
  if (path.endsWith("/deliveries")) return "Мои доставки";
  return "Кабинет";
}
