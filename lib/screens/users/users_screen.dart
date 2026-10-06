import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_services.dart';
import '../../widgets/app_header.dart';
import '../../widgets/new.dart';
import 'user_form_screen.dart';
import 'user_detail_screen.dart';

const _green = Color(0xFF0F6B1F);
const _greenSoft = Color(0xFFE8F5E9);
const _red = Color(0xFFF4512A);
const _borderGrey = Color(0xFFE0E0E0);

class _RoleStyle {
  final Color bg;
  final Color fg;
  final Color border;
  final Color accent;

  const _RoleStyle({
    required this.bg,
    required this.fg,
    required this.border,
    required this.accent,
  });
}

_RoleStyle _roleStyle(String role) {
  switch (role.toLowerCase()) {
    case 'administrador':
      return const _RoleStyle(
        bg: Color(0xFFE8F5E9),
        fg: Color(0xFF0F6B1F),
        border: Color(0xFF81C784),
        accent: Color(0xFF0F6B1F),
      );

    case 'supervisor':
      return const _RoleStyle(
        bg: Color(0xFFFFF3E0),
        fg: Color(0xFFE65100),
        border: Color(0xFFFFB74D),
        accent: Color(0xFFF57C00),
      );

    case 'empleado':
      return const _RoleStyle(
        bg: Color(0xFFE3F2FD),
        fg: Color(0xFF1565C0),
        border: Color(0xFF90CAF9),
        accent: Color(0xFF1E88E5),
      );

    default:
      return const _RoleStyle(
        bg: Color(0xFFF5F5F5),
        fg: Color(0xFF616161),
        border: Color(0xFFBDBDBD),
        accent: Color(0xFF9E9E9E),
      );
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const int _pageSize = 5;
  final _service = UsersService();
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _page = 0;
  bool get _puedeEditar {
    final rol = (Session.user?.roleUser ?? '').toLowerCase();
    return rol == 'administrador' || rol == 'supervisor';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) {
      return '?';
    }
    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }
    return (partes[0].substring(0, 1) +
            partes[1].substring(0, 1))
        .toUpperCase();
  }

  Widget _badge(String role) {
    final s = _roleStyle(role);

    return SizedBox(
      width: 112,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: s.border,
            width: 1,
          ),
        ),
        child: Text(
          role,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: s.fg,
          ),
        ),
      ),
    );
  }

  Widget _chipInactivo() {
    return SizedBox(
      width: 112,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Inactivo',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _red,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _userCard(UserModel u) {
    final s = _roleStyle(u.roleUser);
    return Opacity(
      opacity: u.statusUser ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: _borderGrey,
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserDetailScreen(
                    userId: u.idUser,
                    isOwnProfile: false,
                    canEdit: _puedeEditar,
                  ),
                ),
              );
            },
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    color: s.accent,
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _greenSoft,
                            child: Text(
                              _iniciales(u.fullName),
                              style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  u.fullName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w600,
                                    color:
                                        Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  u.userName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color:
                                        Colors.black54,
                                    fontWeight:
                                        FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.center,
                            children: [
                              _badge(u.roleUser),
                              if (!u.statusUser) ...[
                                const SizedBox(height: 6),
                                _chipInactivo(),
                              ],
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.black38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(
    int total,
    int page,
    int totalPages,
    int start,
    int end,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              total == 0
                  ? 'Mostrando 0'
                  : 'Mostrando ${start + 1} - $end de $total',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Página anterior',
                icon: const Icon(
                  Icons.chevron_left,
                ),
                color: _green,
                splashRadius: 22,
                onPressed: page > 0
                    ? () {
                        setState(() {
                          _page = page - 1;
                        });
                      }
                    : null,
              ),
              Container(
                constraints: const BoxConstraints(
                  minWidth: 70,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Text(
                  '${page + 1} de $totalPages',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Página siguiente',
                icon: const Icon(
                  Icons.chevron_right,
                ),
                color: _green,
                splashRadius: 22,
                onPressed:
                    page < totalPages - 1
                        ? () {
                            setState(() {
                              _page = page + 1;
                            });
                          }
                        : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _titulo(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esMovil = constraints.maxWidth < 600;

        if (esMovil) {
          return Column(
            children: [
              const Text(
                'Usuarios',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              if (_puedeEditar) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: NuevoButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const UserFormScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        }

        return SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                'Usuarios',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),

              if (_puedeEditar)
                Align(
                  alignment: Alignment.centerRight,
                  child: NuevoButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const UserFormScreen(),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        currentRoute: '/usuarios',
      ),
      drawer: AppDrawer(
        currentRoute: '/usuarios',
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                12,
              ),
              child: Column(
                children: [
                  _titulo(context),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      setState(() {
                        _search =
                            v.trim().toLowerCase();
                        _page = 0;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por nombre o usuario',
                      hintStyle: const TextStyle(
                        color: Colors.black38,
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _green,
                      ),
                      filled: true,
                      fillColor:
                          const Color(0xFFF8F8F8),
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(30),
                        borderSide:
                            const BorderSide(
                          color: _borderGrey,
                        ),
                      ),
                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(30),
                        borderSide:
                            const BorderSide(
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child:
                        StreamBuilder<List<UserModel>>(
                      stream: _service.getUsers(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snap.error}',
                            ),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(
                            child:
                                CircularProgressIndicator(
                              color: _green,
                            ),
                          );
                        }
                        final users = snap.data!
                            .where(
                              (u) =>
                                  u.fullName
                                      .toLowerCase()
                                      .contains(_search) ||
                                  u.userName
                                      .toLowerCase()
                                      .contains(_search),
                            )
                            .toList()
                          ..sort(
                            (a, b) => a.fullName
                                .toLowerCase()
                                .compareTo(
                                  b.fullName
                                      .toLowerCase(),
                                ),
                          );
                        final total = users.length;
                        final totalPages = total == 0
                            ? 1
                            : (total / _pageSize).ceil();
                        if (_page >= totalPages) {
                          _page = totalPages - 1;
                        }
                        final page = _page;
                        final start =
                            page * _pageSize;
                        final end =
                            (start + _pageSize > total)
                                ? total
                                : start + _pageSize;
                        final pageUsers =
                            users.sublist(
                          start,
                          end,
                        );
                        return Column(
                          children: [
                            Expanded(
                              child: pageUsers.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No hay usuarios',
                                        style:
                                            TextStyle(
                                          color:
                                              Colors
                                                  .black54,
                                          fontSize: 15,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding:
                                          EdgeInsets.zero,
                                      itemCount:
                                          pageUsers.length,
                                      itemBuilder:
                                          (_, i) {
                                        return _userCard(
                                          pageUsers[i],
                                        );
                                      },
                                    ),
                            ),
                            _footer(
                              total,
                              page,
                              totalPages,
                              start,
                              end,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
