import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "api_client.dart";
import "app_state.dart";
import "models.dart";

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      CatalogScreen(api: widget.api),
      const CartScreen(),
      OrdersScreen(api: widget.api),
      ProfileScreen(api: widget.api),
    ];
    return Scaffold(
      body: SafeArea(child: tabs[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: "Каталог"),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: "Корзина"),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: "Заказы"),
          NavigationDestination(icon: Icon(Icons.person_outline), label: "Профиль"),
        ],
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  bool loading = true;
  String? error;
  List<ProductListItem> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.api.products();
      items = page.results;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text("Kharid.tj · Корзина ${app.cart.length}"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF101826),
                      textColor: Colors.white,
                      leading: p.primaryImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(p.primaryImage!, width: 52, height: 52, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.image_not_supported_outlined, color: Colors.white70),
                      title: Text(p.title),
                      subtitle: Text("${p.salePrice ?? p.price} cм", style: const TextStyle(color: Colors.blueAccent)),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                        onPressed: () => app.addToCart(p),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProductScreen(api: widget.api, slug: p.slug)),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemCount: items.length,
                ),
    );
  }
}

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key, required this.api, required this.slug});

  final ApiClient api;
  final String slug;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductDetail>(
      future: api.productBySlug(slug),
      builder: (_, snap) {
        return Scaffold(
          appBar: AppBar(title: const Text("Товар")),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snap.hasError
                  ? Center(child: Text("${snap.error}"))
                  : _ProductView(item: snap.data!),
        );
      },
    );
  }
}

class _ProductView extends StatelessWidget {
  const _ProductView({required this.item});

  final ProductDetail item;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final p = ProductListItem(
      id: item.id,
      title: item.title,
      slug: "",
      productType: "simple",
      price: item.price,
      salePrice: item.salePrice,
      primaryImage: item.images.isEmpty ? null : item.images.first,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.images.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(item.images.first, height: 220, fit: BoxFit.cover),
          ),
        const SizedBox(height: 12),
        Text(item.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("${item.salePrice ?? item.price} cм", style: const TextStyle(color: Colors.blue, fontSize: 20)),
        const SizedBox(height: 16),
        Text(item.description),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => app.addToCart(p),
          icon: const Icon(Icons.shopping_cart_checkout),
          label: const Text("Ба корзина"),
        )
      ],
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<City> cities = [];
  String shippingCity = "";
  String shippingAddress = "";
  String phone = "";
  bool placing = false;
  String? message;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final total = app.subtotal;
    return Scaffold(
      appBar: AppBar(title: const Text("Оформление заказа")),
      body: app.cart.isEmpty
          ? const Center(child: Text("Корзина пустая"))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...app.cart.map(
                  (e) => Card(
                    child: ListTile(
                      title: Text(e.product.title),
                      subtitle: Text("${e.product.sellPrice} x ${e.qty}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => app.updateQty(e.product.id, e.qty - 1, variantId: e.product.variantId),
                            icon: const Icon(Icons.remove),
                          ),
                          Text("${e.qty}"),
                          IconButton(
                            onPressed: () => app.updateQty(e.product.id, e.qty + 1, variantId: e.product.variantId),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: "Телефон"),
                  onChanged: (v) => phone = v,
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<City>>(
                  future: context.read<AppState>().api.cities(),
                  builder: (_, snap) {
                    if (snap.hasData && cities.isEmpty) {
                      cities = snap.data!;
                      if (shippingCity.isEmpty && cities.isNotEmpty) {
                        shippingCity = cities.first.name;
                      }
                    }
                    if (!snap.hasData) return const LinearProgressIndicator();
                    return DropdownButtonFormField<String>(
                      initialValue: shippingCity.isEmpty ? null : shippingCity,
                      decoration: const InputDecoration(labelText: "Город"),
                      items: cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                      onChanged: (v) => setState(() => shippingCity = v ?? ""),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: "Адрес"),
                  onChanged: (v) => shippingAddress = v,
                ),
                const SizedBox(height: 14),
                Text("Итого: ${total.toStringAsFixed(2)} cм", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: placing
                      ? null
                      : () async {
                          if (!app.isAuthenticated) {
                            setState(() => message = "Аввал login кунед.");
                            return;
                          }
                          setState(() {
                            placing = true;
                            message = null;
                          });
                          try {
                            await app.api.createOrder(
                              accessToken: app.accessToken!,
                              contactPhone: phone.isEmpty ? (app.me?.phone ?? "") : phone,
                              shippingCity: shippingCity,
                              shippingAddress: shippingAddress,
                              lines: app.cart,
                              paymentMethod: "cash",
                              prepayPercent: 0,
                            );
                            await app.clearCart();
                            setState(() => message = "Заказ успешно создан.");
                          } catch (e) {
                            setState(() => message = e.toString());
                          } finally {
                            setState(() => placing = false);
                          }
                        },
                  child: Text(placing ? "Ожидание..." : "Оформить заказ"),
                ),
                if (message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(message!)),
              ],
            ),
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.isAuthenticated) return const Center(child: Text("Барои дидани заказҳо login кунед"));
    return FutureBuilder<List<OrderModel>>(
      future: api.orders(app.accessToken!),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text("${snap.error}"));
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const Center(child: Text("Заказҳо нестанд"));
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final o = rows[i];
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text("Заказ #${o.id}"),
                subtitle: Text("${o.statusDisplay}\n${o.shippingCity}, ${o.shippingAddress}"),
                trailing: Text("${o.deliveryCost} cм"),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.isAuthenticated) return LoginScreen(api: api);
    final me = app.me;
    if (me == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text("Профиль")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text("Ник"), subtitle: Text(me.user.username)),
          ListTile(title: const Text("Роль"), subtitle: Text(me.role)),
          ListTile(title: const Text("Телефон"), subtitle: Text(me.phone)),
          ListTile(title: const Text("Шаҳр"), subtitle: Text(me.city)),
          ListTile(title: const Text("Баланс"), subtitle: Text("${me.balance} cм")),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.read<AppState>().logout(),
            child: const Text("Выход"),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneCtl = TextEditingController();
  final codeCtl = TextEditingController();
  bool sending = false;
  String? registrationToken;
  String? error;
  bool codeRequested = false;
  String city = "Душанбе";

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Вход / Регистрация", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: "Телефон (+992...)")),
                const SizedBox(height: 10),
                if (codeRequested)
                  TextField(controller: codeCtl, decoration: const InputDecoration(labelText: "Код (4 рақам)")),
                const SizedBox(height: 10),
                if (registrationToken != null)
                  TextField(
                    decoration: const InputDecoration(labelText: "Шаҳр барои регистрация"),
                    onChanged: (v) => city = v,
                  ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          setState(() {
                            sending = true;
                            error = null;
                          });
                          try {
                            if (!codeRequested) {
                              await widget.api.requestOtp(phoneCtl.text.trim());
                              codeRequested = true;
                            } else {
                              final verify = await widget.api.verifyOtp(phoneCtl.text.trim(), codeCtl.text.trim());
                              if (verify["registered"] == true) {
                                await app.loginByTokens(
                                  verify["access"].toString(),
                                  verify["refresh"].toString(),
                                );
                              } else {
                                registrationToken = verify["registration_token"]?.toString();
                                if (registrationToken == null) {
                                  throw Exception("registration_token not found");
                                }
                                final reg = await widget.api.register(
                                  registrationToken: registrationToken!,
                                  role: "client",
                                  city: city,
                                );
                                await app.loginByTokens(reg["access"].toString(), reg["refresh"].toString());
                              }
                            }
                          } catch (e) {
                            error = e.toString();
                          } finally {
                            if (mounted) {
                              setState(() => sending = false);
                            }
                          }
                        },
                  child: Text(sending ? "Ожидание..." : (!codeRequested ? "Отправить код" : "Подтвердить")),
                ),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
