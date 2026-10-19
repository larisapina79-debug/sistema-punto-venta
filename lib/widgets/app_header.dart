import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/users/user_detail_screen.dart';
import '../screens/cash_closures/cash_register_history_screen.dart';
import '../screens/cash_closures/close_cash_register_screen.dart';

const Color kGreen = Color.fromARGB(255, 99, 183, 196);
const Color kBlueUser = Color.fromARGB(255, 99, 183, 196);
const Color kDark = Color(0xFF1E1E1E);
const double kWebBreakpoint = 800;
const String kLogoAsset = 'assets/logo.png';

class NavItem {
  final String label;
  final String route;

  const NavItem(this.label, this.route);
}

const List<NavItem> navItems = [
  NavItem('Ventas', '/ventas'),
  NavItem('Pedidos', '/pedidos'),
  NavItem('Inventario', '/inventario'),
  NavItem('Productos', '/productos'),
  NavItem('Usuarios', '/usuarios'),
  NavItem('Sucursales', '/sucursales'),
  NavItem('Cortes', '/cortes'),
];

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String currentRoute;
  final String userName;

  const AppHeader({
    super.key,
    required this.currentRoute,
    this.userName = 'Usuario',
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);
  bool _puedeVerUsuariosYSucursales() {
    final rol = Session.user?.roleUser.toLowerCase().trim();
    return rol == 'administrador' || rol == 'supervisor';
  }

  List<NavItem> _itemsVisibles() {
    final puedeVerUsuariosYSucursales =
        _puedeVerUsuariosYSucursales();
    if (puedeVerUsuariosYSucursales) {
      return navItems;
    }
    return navItems.where((item) {
      return item.route != '/usuarios' &&
          item.route != '/sucursales'&&
          item.route != '/cortes';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kWebBreakpoint;
    final sidePad = width >= 1300 ? 80.0 : 24.0;
    final wide = width >= 1250;
    final itemsVisibles = _itemsVisibles();
    return AppBar(
      backgroundColor: kDark,
      foregroundColor: Colors.white,
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      flexibleSpace: wide
          ? SizedBox(
              height: 70,
              width: double.infinity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final item in itemsVisibles)
                    _NavButton(
                      item: item,
                      selected: item.route == currentRoute,
                    ),
                ],
              ),
            )
          : null,
      leading: isMobile
          ? Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(
                  Icons.menu,
                  size: 36,
                ),
                onPressed: () =>
                    Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      titleSpacing: isMobile ? 8 : sidePad,
      title: Row(
        children: [
          _Logo(
            size: isMobile ? 32 : 56,
          ),
          SizedBox(
            width: isMobile ? 10 : 16,
          ),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: isMobile ? 14 : 24,
              ),
              children: const [
                TextSpan(
                  text: 'Punto ',
                  style: TextStyle(
                    color: Color.fromARGB(
                      255,
                      242,
                      248,
                      243,
                    ),
                  ),
                ),
                TextSpan(
                  text: 'de Venta',
                  style: TextStyle(
                    color: kGreen,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile && !wide) ...[
            const SizedBox(width: 40),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        for (final item in itemsVisibles)
                          _NavButton(
                            item: item,
                            selected:
                                item.route == currentRoute,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        _UserMenu(
          userName:
              Session.user?.userName ?? userName,
          compact: isMobile,
        ),
        SizedBox(
          width: isMobile ? 12 : sidePad,
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  final double size;

  const _Logo({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kLogoAsset,
      height: size,
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;

  const _NavButton({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        if (item.route == '/cortes') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CashRegisterHistoryScreen(),
            ),
          );
          return;
        }
        if (!selected) {
          Navigator.pushReplacementNamed(
            context,
            item.route,
          );
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: Text(
        item.label,
        style: TextStyle(
          color: selected ? kGreen : Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }
}
class _UserMenu extends StatelessWidget {
  final String userName;
  final bool compact;

  const _UserMenu({
    required this.userName,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    
    return PopupMenuButton<String>(
      offset: const Offset(0, 8),
      position: PopupMenuPosition.under,
      elevation: 8,
      color: Colors.white,
      onSelected: (value) {
        if (value == 'profile') {
          final user = Session.user;
          if (user == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailScreen(
                userId: user.idUser,
                isOwnProfile: true,
              ),
            ),
          );
        }
      if (value == 'logout') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CloseCashRegisterScreen(
                initialCash: 0,
                totalSales: 0,
                cashSales: 0,
              ),
            ),
          );
        }
      },

      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 21,
                color: Colors.black87,
              ),
              SizedBox(width: 10),
              Text(
                'Perfil',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),

        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 21,
                color: Colors.black87,
              ),
              SizedBox(width: 10),
              Text(
                'Cerrar sesión',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(
            color: Colors.white,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person,
              color: kBlueUser,
              size: compact ? 21 : 26,
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: compact ? 17 : 20,
            ),
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });
  bool _puedeVerUsuariosYSucursales() {
    final rol = Session.user?.roleUser.toLowerCase().trim();
    return rol == 'administrador' || rol == 'supervisor';
  }
  List<NavItem> _itemsVisibles() {
    final puedeVerUsuariosYSucursales =
        _puedeVerUsuariosYSucursales();
    if (puedeVerUsuariosYSucursales) {
      return navItems;
    }
    return navItems.where((item) {
      return item.route != '/usuarios' &&
          item.route != '/sucursales' &&
           item.route != '/cortes';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final itemsVisibles = _itemsVisibles();
    return Drawer(
      backgroundColor: const Color(0xFF0E0D0D),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                24,
                20,
                20,
              ),
              child: Row(
                children: [
                  const _Logo(size: 40),
                  const SizedBox(width: 12),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: 'Punto ',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: 'de Venta',
                          style: TextStyle(
                            color: kGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              color: Colors.white24,
              height: 1,
            ),
            const SizedBox(height: 12),
           
            for (final item in itemsVisibles)
              _DrawerItem(
                item: item,
                selected: item.route == currentRoute,
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final NavItem item;
  final bool selected;
  const _DrawerItem({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? kGreen
        : Colors.white;
    return InkWell(
     onTap: () {
  if (item.route == '/cortes') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CashRegisterHistoryScreen(),
      ),
    );
    return;
  }
  if (!selected) {
    Navigator.pushReplacementNamed(
      context,
      item.route,
    );
  }
},
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
