import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:puntoventa/models/cash_closure_model.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';

const Color _kGreen = Color(0xFF63B7C4);
const Color _kGreenDark = Color(0xFF0F6B1F);
const Color _kBlack = Color(0xFF111111);
const Color _kGrayText = Color(0xFF555555);
const Color _kSoftGray = Color(0xFF8A8A8A);
const Color _kBorderLight = Color(0xFFE0E0E0);
const Color _kFieldBg = Color(0xFFF8F8F8);
const Color _kBackground = Colors.white;
const Color _kOk = Color(0xFF1B5E20);
const Color _kMissing = Color(0xFFC62828);
const Color _kExtra = Color(0xFFE65100);

class _ClosureView {
  final CashClosureModel closure;
  final String userName;
  final String role;
  final String branch;

  const _ClosureView({
    required this.closure,
    required this.userName,
    required this.role,
    required this.branch,
  });

  String get id => closure.idClosure;
  DateTime? get openedAt => closure.openingDate;
  DateTime? get closedAt => closure.closingDate;
  double get initialCash => closure.initialCash;
  double get totalSale => closure.totalSale;
  double get closingCash => closure.recordedCash;
  double get difference => closure.difference;
  bool get isClosed =>
      closure.statusClosing || closure.closingDate != null;
}

class CashRegisterHistoryScreen extends StatefulWidget {
  const CashRegisterHistoryScreen({super.key});
  @override
  State<CashRegisterHistoryScreen> createState() =>
      _CashRegisterHistoryScreenState();
}

class _CashRegisterHistoryScreenState
    extends State<CashRegisterHistoryScreen> {
  static const int _pageSize = 5;
  final BranchService _branchService = BranchService();
  final TextEditingController _searchController =
      TextEditingController();
  List<_ClosureView> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _branch;
  String _role = 'Todos';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final closuresFuture = db
          .collection('cash_closures')
          .orderBy('opening_date', descending: true)
          .get();
      final branchesFuture = _branchService.getBranches();
      final usersFuture = db.collection('users').get();
      final closuresSnap = await closuresFuture;
      final List<Map<String, dynamic>> branchesData =
          await branchesFuture;
      final usersSnap = await usersFuture;
      final Map<String, String> branchNames = {};
      for (final branch in branchesData) {
        final id = branch['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        branchNames[id] = _pickString(
              branch,
              ['branch_name', 'name', 'nombre'],
            ) ??
            'Sucursal';
      }
      final Map<String, String> userNames = {};
      final Map<String, String> userRoles = {};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final fullName = _pickString(
          data,
          ['full_name', 'fullName'],
        );
        if (fullName != null) {
          userNames[doc.id] = fullName;
        } else {
          final name = _pickString(
                data,
                ['name', 'nombre'],
              ) ??
              '';
          final lastName = _pickString(
                data,
                [
                  'last_name',
                  'lastName',
                  'apellido',
                  'apellidos',
                ],
              ) ??
              '';
          final joinedName = '$name $lastName'.trim();
          userNames[doc.id] =
              joinedName.isEmpty ? 'Usuario' : joinedName;
        }
        userRoles[doc.id] = _normalizeRole(
          _pickString(
            data,
            ['role', 'rol', 'user_role'],
          ),
        );
      }
      final List<_ClosureView> items =
          closuresSnap.docs.map((doc) {
        final closure = CashClosureModel.fromFirestore(doc);
        return _ClosureView(
          closure: closure,
          userName: userNames[closure.idUsers] ?? 'Usuario',
          role: userRoles[closure.idUsers] ?? 'Empleado',
          branch: branchNames[closure.idBranch] ?? 'Sucursal',
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _page = 0;
        if (_branch != null &&
            !items.any((c) => c.branch == _branch)) {
          _branch = null;
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error al cargar el historial de caja: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los cortes de caja.';
      });
    }
  }
  String? _pickString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
    return null;
  }
  String _normalizeRole(String? raw) {
    final value = (raw ?? '').toLowerCase().trim();
    if (value.contains('admin')) return 'Administrador';
    if (value.contains('super')) return 'Supervisor';
    return 'Empleado';
  }
  String _money(double value) {
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${value < 0 ? '- ' : ''}\$ $intPart.${parts[1]}';
  }
  String _differenceText(double diff) {
    if (diff == 0) return _money(0);
    return '${diff < 0 ? '-' : '+'} ${_money(diff.abs())}';
  }
  String _dateText(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
  String _timeText(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'p.m.' : 'a.m.';
    return '${hour12.toString().padLeft(2, '0')}:$minute $suffix';
  }
  String _durationText(_ClosureView c) {
    final start = c.openedAt;
    if (start == null) {
      return 'Sin fecha de inicio';
    }
    final end = c.closedAt ?? DateTime.now();
    final difference = end.difference(start);
    if (difference.isNegative) {
      return 'Fechas inválidas';
    }
    final totalHours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    if (totalHours == 0 && minutes == 0) {
      return 'Menos de un minuto';
    }
    if (totalHours == 0) {
      return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    }
    if (minutes == 0) {
      return '$totalHours ${totalHours == 1 ? 'hora' : 'horas'}';
    }
    return '$totalHours ${totalHours == 1 ? 'hora' : 'horas'} '
        'y $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
  }
  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
  Color _differenceColor(double diff) {
    if (diff == 0) return _kOk;
    return diff < 0 ? _kMissing : _kExtra;
  }
  Color _accentColor(_ClosureView c) {
    if (!c.isClosed) return _kGreen;
    if (c.difference == 0) return _kGreenDark;
    return c.difference < 0
        ? _kMissing
        : const Color(0xFFF57C00);
  }

  List<String> get _branches {
    final branches =
        _items.map((c) => c.branch).toSet().toList();
    branches.sort();
    return branches;
  }
  List<_ClosureView> get _filtered {
    final query = _search.trim().toLowerCase();
    return _items.where((c) {
      if (_role != 'Todos' && c.role != _role) {
        return false;
      }
      if (_branch != null && c.branch != _branch) {
        return false;
      }
      if (query.isNotEmpty &&
          !c.userName.toLowerCase().contains(query) &&
          !c.branch.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _searchField() {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _search = value;
            _page = 0;
          });
        },
        style: const TextStyle(
          color: _kBlack,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o sucursal',
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 16,
          ),
          filled: true,
          fillColor: _kFieldBg,
          prefixIcon: const Icon(
            Icons.search,
            color: _kGreenDark,
          ),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _kGreenDark,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _search = '';
                      _page = 0;
                    });
                  },
                ),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: _kBorderLight,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: _kGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _branchDropdown() {
    const allKey = '__all__';
    final active = _branch != null;
    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 58),
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _kBorderLight),
      ),
      onSelected: (value) {
        setState(() {
          _branch = value == allKey ? null : value;
          _page = 0;
        });
      },
      itemBuilder: (context) {
        PopupMenuItem<String> option(
          String value,
          String label,
        ) {
          final selected =
              (value == allKey && _branch == null) ||
                  value == _branch;
          return PopupMenuItem<String>(
            value: value,
            height: 46,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _kGreen : _kBlack,
                fontSize: 15,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }
        return [
          option(allKey, 'Todas las sucursales'),
          ..._branches.map((b) => option(b, b)),
        ];
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        constraints: const BoxConstraints(
          minWidth: 120,
          maxWidth: 210,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE8F5F7)
              : _kFieldBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? _kGreen : _kBorderLight,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sucursal',
                    style: TextStyle(
                      color: _kSoftGray,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _branch ?? 'Todas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? _kGreen : _kBlack,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _kGreen,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChips() {
    final options = <Map<String, dynamic>>[
      {'label': 'Todos', 'color': _kGreen},
      {
        'label': 'Administrador',
        'color': const Color(0xFF2E7D32),
      },
      {
        'label': 'Supervisor',
        'color': const Color(0xFFF57C00),
      },
      {
        'label': 'Empleado',
        'color': const Color(0xFF1E88E5),
      },
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((item) {
          final label = item['label'] as String;
          final color = item['color'] as Color;
          final selected = _role == label;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                setState(() {
                  _role = label;
                  _page = 0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected ? color : _kBorderLight,
                    width: 1.2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _kBlack,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _avatar(String name) {
    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE8F5F7),
      ),
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Color(0xFF2E7D32),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusBadge(_ClosureView c) {
    late final String text;
    late final Color bg;
    late final Color fg;
    late final Color border;

    if (!c.isClosed) {
      text = 'En curso';
      bg = const Color(0xFFE0F2F5);
      fg = const Color(0xFF0B5A66);
      border = _kGreen;
    } else if (c.difference == 0) {
      text = 'Cuadrada';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF1B5E20);
      border = const Color(0xFF81C784);
    } else if (c.difference < 0) {
      text = 'Faltan';
      bg = const Color(0xFFFDECEA);
      fg = const Color(0xFFC62828);
      border = const Color(0xFFEF9A9A);
    } else {
      text = 'Sobran';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      border = const Color(0xFFFFB74D);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _timeBlock({
    required String title,
    required String timeLabel,
    required DateTime? date,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _kBlack,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          date == null ? '—' : _dateText(date),
          style: const TextStyle(
            color: _kGrayText,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          date == null
              ? '$timeLabel —'
              : '$timeLabel ${_timeText(date)}',
          style: const TextStyle(
            color: _kGrayText,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _amountColumn(
    String label,
    String value, {
    Color valueColor = _kGrayText,
    bool bold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kBlack,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _closureCard(_ClosureView c) {
    final amounts = <Widget>[
      _amountColumn(
        'Efectivo inicial',
        _money(c.initialCash),
      ),
      _amountColumn(
        'Venta',
        _money(c.totalSale),
      ),
      _amountColumn(
        'Efectivo al cerrar',
        _money(c.closingCash),
        valueColor: _kBlack,
        bold: true,
      ),
      _amountColumn(
        'Diferencia',
        _differenceText(c.difference),
        valueColor: _differenceColor(c.difference),
        bold: true,
      ),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12,
                    ),
                    child: Row(
                      children: [
                        _avatar(c.userName),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kBlack,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c.branch}  •  ${c.role}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kSoftGray,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _statusBadge(c),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEAEAEA),
                  ),

                  // Inicio, cierre y tiempo en la misma fila.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _timeBlock(
                            title: 'Inicio',
                            timeLabel: 'Entrada',
                            date: c.openedAt,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _timeBlock(
                            title: 'Cierre',
                            timeLabel: 'Salida',
                            date: c.closedAt,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tiempo de apertura',
                                style: TextStyle(
                                  color: _kBlack,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _durationText(c),
                                style: const TextStyle(
                                  color: _kGreenDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!c.isClosed) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'En curso',
                                  style: TextStyle(
                                    color: _kGreenDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEAEAEA),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      14,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 520) {
                          return Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: amounts,
                          );
                        }
                        final itemWidth =
                            (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: amounts
                              .map(
                                (w) => SizedBox(
                                  width: itemWidth,
                                  child: w,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: _accentColor(c)),
            ),
          ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            total == 0
                ? 'Mostrando 0'
                : 'Mostrando ${start + 1} - $end de $total',
            style: const TextStyle(
              color: _kSoftGray,
              fontSize: 14,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed:
                  canPrev ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              iconSize: 28,
              color: _kSoftGray,
              disabledColor: Colors.black26,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _kGreenDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_page + 1} de $totalPages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed:
                  canNext ? () => setState(() => _page++) : null,
              icon: const Icon(Icons.chevron_right_rounded),
              iconSize: 28,
              color: _kSoftGray,
              disabledColor: Colors.black26,
            ),
          ],
        ),
      ],
    );
  }

  Widget _listArea(List<_ClosureView> pageItems) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _kGreenDark,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kGrayText,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGreenDark,
                side: const BorderSide(color: _kGreenDark),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _kGreenDark,
      onRefresh: _load,
      child: pageItems.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No hay cortes de caja para mostrar.',
                    style: TextStyle(
                      color: _kGrayText,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: pageItems.map(_closureCard).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = filtered.length;
    final totalPages =
        (total / _pageSize).ceil().clamp(1, 9999);
    if (_page >= totalPages) {
      _page = totalPages - 1;
    }
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, total);
    final pageItems = filtered.sublist(start, end);
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: const AppHeader(currentRoute: '/cortes'),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Corte de caja',
                      style: TextStyle(
                        color: _kBlack,
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _searchField()),
                      const SizedBox(width: 12),
                      _branchDropdown(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _roleChips(),
                  const SizedBox(height: 16),
                  Expanded(child: _listArea(pageItems)),
                  const SizedBox(height: 4),
                  _pagination(total, totalPages, start, end),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
