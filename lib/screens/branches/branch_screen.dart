import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/new.dart';
import 'branch_detail.dart';
import 'branch_form_screen.dart';

const _green = Color(0xFF0F6B1F);
const _greenSoft = Color(0xFFE8F5E9);
const _red = Color(0xFFF4512A);
const _borderGrey = Color(0xFFE0E0E0);
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  static const int _pageSize = 5;
  final BranchService _service = BranchService();
  final TextEditingController _searchCtrl =
      TextEditingController();
  String _search = '';
  int _page = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _statusBadge(bool activo) {
    return SizedBox(
      width: 100,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo
              ? _greenSoft
              : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo
                ? const Color(0xFF81C784)
                : const Color(0xFFEF9A9A),
          ),
        ),
        child: Text(
          activo ? 'Activa' : 'Inactiva',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: activo ? _green : _red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _imagenLogo(String logo, Widget vacio) {
    final String valor = logo.trim();

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
    final String limpio = nombre.trim();
    final String inicial =
        limpio.isEmpty ? 'S' : limpio[0].toUpperCase();
    final Widget vacio = Center(
      child: Text(
        inicial,
        style: const TextStyle(
          color: _green,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Container(
      width: 88,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: _imagenLogo(logo, vacio),
    );
  }

  Widget _branchCard(Map<String, dynamic> branch) {
    final nombre =
        (branch['branch_name'] ?? 'Sin nombre').toString();
    final direccion =
        (branch['branch_address'] ?? 'Sin dirección').toString();
    final logo =
        (branch['branch_logo'] ?? '').toString();
    final activo = branch['branch_status'] == true;
    return Opacity(
      opacity: activo ? 1 : 0.6,
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
                  builder: (_) => BranchDetailScreen(
                    branchId: (branch['id'] ?? '').toString(),
                  ),
                ),
              );
            },
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    color: activo ? _green : _red,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _branchLogo(logo, nombre),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  direccion,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                         const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _statusBadge(activo),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Página anterior',
                icon: const Icon(Icons.chevron_left),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(8),
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
                icon: const Icon(Icons.chevron_right),
                color: _green,
                splashRadius: 22,
                onPressed: page < totalPages - 1
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
                'Sucursales',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: NuevoButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BranchFormScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }
        return SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                'Sucursales',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: NuevoButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BranchFormScreen(),
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
        currentRoute: '/sucursales',
      ),
      drawer: AppDrawer(
        currentRoute: '/sucursales',
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
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim().toLowerCase();
                        _page = 0;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o dirección',
                      hintStyle: const TextStyle(
                        color: Colors.black38,
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _green,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: _borderGrey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: _green,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: StreamBuilder<
                        List<Map<String, dynamic>>>(
                      stream: _service.watchBranches(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text('Error: ${snap.error}'),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _green,
                            ),
                          );
                        }
                        final branches = snap.data!
                            .where((branch) {
                              final nombre =
                                  (branch['branch_name'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              final direccion =
                                  (branch['branch_address'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              return nombre.contains(_search) ||
                                  direccion.contains(_search);
                            })
                            .toList()
                          ..sort((a, b) {
                            final nombreA =
                                (a['branch_name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                            final nombreB =
                                (b['branch_name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                            return nombreA.compareTo(nombreB);
                          });
                        final total = branches.length;
                        final totalPages = total == 0
                            ? 1
                            : (total / _pageSize).ceil();
                        if (_page >= totalPages) {
                          _page = totalPages - 1;
                        }
                        final page = _page;
                        final start = page * _pageSize;
                        final end = (start + _pageSize > total)
                            ? total
                            : start + _pageSize;
                        final pageBranches =
                            branches.sublist(start, end);
                        return Column(
                          children: [
                            Expanded(
                              child: pageBranches.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No hay sucursales',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 15,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: pageBranches.length,
                                      itemBuilder: (_, index) {
                                        return _branchCard(
                                          pageBranches[index],
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
