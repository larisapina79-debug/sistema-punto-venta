import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/new.dart';
import '../users/users_screen.dart';
import 'branch_detail.dart';
import 'branch_form_screen.dart';
import 'branch_ticket.dart';

const _red = Color(0xFFF4512A);
const _borderGrey = Color(0xFFE0E0E0);
const _accent = Color.fromARGB(255, 99, 183, 196);
const _blueStat = Color(0xFF1565C0);
const _fieldBg = Color(0xFFF8F8F8);
const _green = Color(0xFF1B7A2F);

class _BranchStats {
  final int users;
  final int products;

  const _BranchStats(this.users, this.products);
}

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  static const int _pageSize = 5;
  final BranchService _service = BranchService();
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, Future<_BranchStats>> _statsCache = {};
  String _search = '';
  int _page = 0;
  String? _filtro;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(String id) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        final ancho = size.width > 948 ? 900.0 : size.width - 32;
        final alto = size.height * 0.88;
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: ancho,
            height: alto,
            child: BranchDetailScreen(branchId: id),
          ),
        );
      },
    );
  }

  void _openUsers(String id, String nombre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: {
            'branchId': id,
            'branchName': nombre,
          },
        ),
        builder: (_) => UsersScreen(),
      ),
    );
  }

  void _openProducts(String id, String nombre) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La pantalla de inventario aún no está disponible.',
        ),
      ),
    );
  }

  Future<void> _setStatus(String id, bool value) async {
    if (id.isEmpty) return;
    try {
      await _service.updateBranchStatus(
        id: id,
        status: value,
      );
      if (!mounted) return;
      setState(() {
        _statsCache.remove(id);
      });
    } catch (e) {
      debugPrint('Error al cambiar estado de sucursal: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cambiar el estado.'),
        ),
      );
    }
  }

  bool _refMatches(dynamic item, String id) {
    if (item == null) return false;
    if (item is DocumentReference) return item.id == id;
    final s = item.toString();
    return s == id || s.endsWith('/$id');
  }
  bool _assignedTo(dynamic assigned, String id) {
    if (assigned is List) {
      return assigned.any((item) => _refMatches(item, id));
    }
    return _refMatches(assigned, id);
  }

  Future<_BranchStats> _loadStats(String id) {
    return _statsCache.putIfAbsent(id, () async {
      final db = FirebaseFirestore.instance;
      int users = 0;
      int products = 0;
      try {
        final snapshot = await db.collection('users').get();
        users = snapshot.docs
            .where(
              (doc) => _assignedTo(
                doc.data()['id_branches'],
                id,
              ),
            )
            .length;
      } catch (e) {
        debugPrint('Error contando usuarios de $id: $e');
      }
      try {
        final snapshot = await db.collection('inventory').get();
        const branchFields = [
          'id_branch',
          'id_branches',
          'branch_id',
          'branch',
          'id_sucursal',
        ];
        products = snapshot.docs.where((doc) {
          final data = doc.data();
          for (final field in branchFields) {
            if (_assignedTo(data[field], id)) return true;
          }
          return false;
        }).length;
      } catch (e) {
        debugPrint('Error contando inventario de $id: $e');
      }
      return _BranchStats(users, products);
    });
  }

  Widget _titulo(bool compact) {
    return Column(
      children: [
        Text(
          'Sucursales',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 26 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Administra y controla el estado de tus sucursales.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF555555),
          ),
        ),
      ],
    );
  }

  Widget _nuevoButton() {
    return SizedBox(
      height: 48,
      child: NuevoButton(
        onPressed: () {
          showDialog<void>(
            context: context,
            barrierColor: Colors.black54,
            builder: (ctx) {
              final size = MediaQuery.of(ctx).size;
              final ancho = size.width > 948 ? 900.0 : size.width - 32;
              final alto = size.height * 0.88;
              return Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: ancho,
                  height: alto,
                  child: const BranchFormScreen(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _barraBusquedaYRegistro() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 650) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 14),
              _nuevoButton(),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchField(),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _nuevoButton(),
            ),
          ],
        );
      },
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() {
            _search = value.trim().toLowerCase();
            _page = 0;
          });
        },
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black,
        ),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o dirección...',
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
          ),
          filled: true,
          fillColor: _fieldBg,
          prefixIcon: const Icon(
            Icons.search,
            color: _accent,
          ),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _accent,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _search = '';
                      _page = 0;
                    });
                  },
                ),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: _borderGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
              color: _accent,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String filtro,
    required Color color,
    required String label,
    required int value,
    required String note,
  }) {
    final selected = _filtro == filtro;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _filtro = selected ? null : filtro;
          _page = 0;
        });
      },
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : _borderGrey,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$value',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        Text(
                          note,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCards(List<Map<String, dynamic>> all) {
    final activas =
        all.where((b) => b['branch_status'] == true).length;
    final total = all.length;
    final cards = [
      _summaryCard(
        filtro: 'activas',
        color: _accent,
        label: 'Sucursales activas',
        value: activas,
        note: 'de $total sucursales',
      ),
      _summaryCard(
        filtro: 'desactivadas',
        color: _red,
        label: 'Sucursales desactivadas',
        value: total - activas,
        note: 'de $total sucursales',
      ),
      _summaryCard(
        filtro: 'todas',
        color: _blueStat,
        label: 'Total de sucursales',
        value: total,
        note: 'registradas en el sistema',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 600) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 10),
            cards[2],
          ],
        );
      },
    );
  }

  Widget _imagenLogo(String logo, Widget vacio) {
    final valor = logo.trim();
    if (valor.isEmpty) return vacio;
    if (valor.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(valor.split(',').last),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => vacio,
        );
      } catch (_) {
        return vacio;
      }
    }
    return Image.network(
      valor,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => vacio,
    );
  }

  Widget _branchLogo(String logo, String nombre) {
    final limpio = nombre.trim();
    final inicial = limpio.isEmpty ? 'S' : limpio[0].toUpperCase();
    final vacio = Center(
      child: Text(
        inicial,
        style: const TextStyle(
          color: _accent,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: _imagenLogo(logo, vacio),
    );
  }

  Widget _stat(
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 104,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.black,
          backgroundColor: _accent.withValues(alpha: 0.10),
          side: BorderSide(
            color: _accent.withValues(alpha: 0.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _printButton(Map<String, dynamic> branch) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => BranchTicket.show(
          context,
          branch: branch,
        ),
        icon: const Icon(
          Icons.print_rounded,
          size: 20,
          color: _accent,
        ),
        label: const Text(
          'Imprimir ticket',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: _accent.withValues(alpha: 0.10),
          side: BorderSide(
            color: _accent.withValues(alpha: 0.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _statusControl(
    Map<String, dynamic> branch,
    bool activo,
  ) {
    final id = (branch['id'] ?? '').toString();
    final color = activo ? _green : _red;
    return SizedBox(
      width: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 125,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  activo
                      ? Icons.check_circle_outline_rounded
                      : Icons.highlight_off_rounded,
                  size: 22,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    activo ? 'Activado' : 'Desactivado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Switch(
              value: activo,
              onChanged: (v) => _setStatus(id, v),
              activeThumbColor: Colors.white,
              activeTrackColor: _green,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: _red,
              trackOutlineColor:
                  WidgetStateProperty.all(Colors.transparent),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchCard(
    Map<String, dynamic> branch,
    int numero,
  ) {
    final id = (branch['id'] ?? '').toString();
    final nombre =
        (branch['branch_name'] ?? 'Sin nombre').toString();
    final direccion =
        (branch['branch_address'] ?? 'Sin dirección').toString();
    final logo = (branch['branch_logo'] ?? '').toString();
    final activo = branch['branch_status'] == true;
    return _PressableCard(
      onTap: () => _openDetail(id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: FutureBuilder<_BranchStats>(
          future: _loadStats(id),
          builder: (context, snap) {
            final stats = snap.data;
            final users = stats == null ? '—' : '${stats.users}';
            final products = stats == null ? '—' : '${stats.products}';
            final info = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF171717),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  direccion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sucursal $numero',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            );
            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1040;
                if (wide) {
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          54, 12, 12, 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _branchLogo(logo, nombre),
                            const SizedBox(width: 20),
                            Expanded(child: info),
                            const SizedBox(width: 14),
                            _stat(
                              users,
                              'Usuarios',
                              onTap: () => _openUsers(id, nombre),
                            ),
                            const SizedBox(width: 10),
                            _stat(
                              products,
                              'Productos',
                              onTap: () => _openProducts(id, nombre),
                            ),
                            const SizedBox(width: 12),
                            _printButton(branch),
                            const SizedBox(width: 8),
                            _statusControl(branch, activo),
                            const SizedBox(width: 12),
                            const Text(
                              'Ver detalles',
                              style: TextStyle(
                                color: _accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _accent,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 26,
                        top: 24,
                        bottom: 24,
                        width: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: activo ? _accent : _red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _branchLogo(logo, nombre),
                              const SizedBox(width: 12),
                              Expanded(child: info),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: _accent,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _stat(
                                  users,
                                  'Usuarios',
                                  onTap: () => _openUsers(id, nombre),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _stat(
                                  products,
                                  'Productos',
                                  onTap: () => _openProducts(id, nombre),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _printButton(branch),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _statusControl(branch, activo),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      bottom: 12,
                      width: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: activo ? _accent : _red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _pageButton(
    String label, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final isArrow = label == '‹' || label == '›';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? _accent
                : isArrow
                    ? _borderGrey
                    : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isArrow
            ? Icon(
                label == '‹'
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 23,
                color: onTap == null ? Colors.black26 : Colors.black,
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.w500,
                  color: Colors.black,
                ),
              ),
      ),
    );
  }

  Widget _pagination(
    int total,
    int totalPages,
    int start,
    int end,
  ) {
    final canPrev = _page > 0;
    final canNext = _page < totalPages - 1;
    const visible = 5;
    final maxStart =
        totalPages > visible ? totalPages - visible : 0;
    final first = (_page - 2).clamp(0, maxStart).toInt();
    final last = (first + visible) < totalPages
        ? first + visible
        : totalPages;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Text(
          total == 0
              ? 'Mostrando 0 sucursales'
              : 'Mostrando ${start + 1} - $end de $total sucursales',
          style: const TextStyle(
            color: Color(0xFF8A8A8A),
            fontSize: 13,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pageButton(
              '‹',
              onTap: canPrev ? () => setState(() => _page--) : null,
            ),
            for (int i = first; i < last; i++) ...[
              const SizedBox(width: 5),
              _pageButton(
                '${i + 1}',
                selected: i == _page,
                onTap: () => setState(() => _page = i),
              ),
            ],
            const SizedBox(width: 5),
            _pageButton(
              '›',
              onTap: canNext ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(currentRoute: '/sucursales'),
      drawer: AppDrawer(currentRoute: '/sucursales'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.watchBranches(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }
                final all = snap.data!;
                final branches = all.where((b) {
                  final activa = b['branch_status'] == true;
                  if (_filtro == 'activas' && !activa) return false;
                  if (_filtro == 'desactivadas' && activa) return false;
                  final n = (b['branch_name'] ?? '')
                      .toString()
                      .toLowerCase();
                  final d = (b['branch_address'] ?? '')
                      .toString()
                      .toLowerCase();
                  return n.contains(_search) || d.contains(_search);
                }).toList()
                  ..sort(
                    (a, b) => (a['branch_name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .compareTo(
                          (b['branch_name'] ?? '')
                              .toString()
                              .toLowerCase(),
                        ),
                  );
                final total = branches.length;
                final totalPages =
                    total == 0 ? 1 : (total / _pageSize).ceil();
                if (_page >= totalPages) {
                  _page = totalPages - 1;
                }
                final start = _page * _pageSize;
                final end = (start + _pageSize > total)
                    ? total
                    : start + _pageSize;
                final pageBranches = branches.sublist(start, end);
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 24,
                    20,
                    isMobile ? 12 : 24,
                    12,
                  ),
                  children: [
                    _titulo(isMobile),
                    const SizedBox(height: 22),
                    _barraBusquedaYRegistro(),
                    const SizedBox(height: 18),
                    _summaryCards(all),
                    const SizedBox(height: 18),
                    if (pageBranches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text(
                            'No hay sucursales',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    else
                      ...pageBranches.map(
                        (b) => _branchCard(
                          b,
                          all.indexWhere((x) => x['id'] == b['id']) + 1,
                        ),
                      ),
                    const SizedBox(height: 6),
                    _pagination(total, totalPages, start, end),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
class _PressableCard extends StatefulWidget {
  const _PressableCard({
    required this.onTap,
    required this.child,
  });
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;
  void _set(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed ? _accent : _borderGrey,
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}