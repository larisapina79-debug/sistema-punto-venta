import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:puntoventa/models/cash_closure_model.dart';
import 'package:puntoventa/screens/cash_closures/cash_closure_detail_screen.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';

const Color _kGreen = Color.fromARGB(255, 99, 183, 196);
const Color _kGreenDark = Color.fromARGB(255, 99, 183, 196);
const Color _kBlack = Color(0xFF111111);
const Color _kGrayText = Color(0xFF555555);
const Color _kSoftGray = Color(0xFF8A8A8A);
const Color _kBorderLight = Color(0xFFE0E0E0);
const Color _kFieldBg = Color(0xFFF8F8F8);
const Color _kBackground = Colors.white;
const Color _kMissing = Color(0xFFC62828);
const Color _kExtra = Color(0xFFE65100);
const Color _kBlue = Color(0xFF1565C0);
const Color _kCancel = Color(0xFFFF5722);
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
  bool get isClosed => closure.statusClosing || closure.closingDate != null;
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
  static const List<String> _periods = [
    'Hoy',
    'Esta semana',
    'Este mes',
  ];
  static const int _fEmployee = 30;
  static const int _fOpen = 16;
  static const int _fClose = 16;
  static const int _fTime = 21;
  static const int _fStatus = 17;
  final BranchService _branchService = BranchService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _initialCashController = TextEditingController();
  bool _savingInitialCash = false;
  List<_ClosureView> _items = [];
  List<String> _allBranches = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _branch;
  String _statusFilter = '';
  int _page = 0;
  String? _pressedPageArrow;
  String _period = 'Este mes';
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _setPeriodDates('Este mes');
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _initialCashController.dispose();
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
          final name = _pickString(data, ['name', 'nombre']) ?? '';
          final lastName = _pickString(
                data,
                ['last_name', 'lastName', 'apellido', 'apellidos'],
              ) ??
              '';
          final joinedName = '$name $lastName'.trim();
          userNames[doc.id] =
              joinedName.isEmpty ? 'Usuario' : joinedName;
        }
        userRoles[doc.id] = _normalizeRole(
          _pickString(data, ['role', 'rol', 'user_role']),
        );
      }
      final List<_ClosureView> items = closuresSnap.docs.map((doc) {
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
        _allBranches = branchNames.values.toSet().toList()..sort();
        _loading = false;
        _page = 0;
        if (_branch != null && !_allBranches.contains(_branch)) {
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
      if (value is num) return value.toString();
    }
    return null;
  }

  String _normalizeRole(String? raw) {
    final value = (raw ?? '').toLowerCase().trim();
    if (value.contains('admin')) return 'Administrador';
    if (value.contains('super')) return 'Supervisor';
    return 'Empleado';
  }

  void _setPeriodDates(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case 'Hoy':
        _from = today;
        _to = today;
        break;
      case 'Esta semana':
        _from = today.subtract(Duration(days: today.weekday - 1));
        _to = _from.add(const Duration(days: 6));
        break;
      case 'Este mes':
        _from = DateTime(now.year, now.month, 1);
        _to = DateTime(now.year, now.month + 1, 0);
        break;
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom ? _from : _to;
    DateTime tempDate = initialDate;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                                primary: const Color.fromARGB(255, 99, 183, 196),
                                onPrimary: Colors.black,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: tempDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          currentDate: DateTime.now(),
                          onDateChanged: (date) {
                            setDialogState(() {
                              tempDate = date;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 8,
                          bottom: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    const Color.fromARGB(255, 26, 27, 27),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop(tempDate);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _kBlack,
                              ),
                              child: const Text('Aceptar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(picked)) {
          _to = picked;
        }
      } else {
        _to = picked;
        if (_from.isAfter(picked)) {
          _from = picked;
        }
      }
      _period = '';
      _page = 0;
    });
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
    if (start == null) return 'Sin fecha de inicio';
    final end = c.closedAt ?? DateTime.now();
    final difference = end.difference(start);
    if (difference.isNegative) return 'Fechas inválidas';
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

  String _durationShort(_ClosureView c) {
    final start = c.openedAt;
    if (start == null) return '—';
    final end = c.closedAt ?? DateTime.now();
    final difference = end.difference(start);
    if (difference.isNegative) return '—';
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    if (hours == 0 && minutes == 0) return 'Menos de 1 min';
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
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

  Color _accentColor(_ClosureView c) {
    if (!c.isClosed) return _kBlue;
    if (c.difference == 0) return _kGreen;
    return c.difference < 0 ? _kMissing : _kExtra;
  }

  List<_ClosureView> get _baseFiltered {
    final query = _search.trim().toLowerCase();
    final start = DateTime(_from.year, _from.month, _from.day);
    final end = DateTime(
      _to.year,
      _to.month,
      _to.day,
      23,
      59,
      59,
      999,
    );
    return _items.where((c) {
      final opened = c.openedAt;
      if (opened != null &&
          (opened.isBefore(start) || opened.isAfter(end))) {
        return false;
      }
      if (_branch != null && c.branch != _branch) return false;
      if (query.isNotEmpty &&
          !c.userName.toLowerCase().contains(query) &&
          !c.branch.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_ClosureView> get _filtered {
    return _baseFiltered.where((c) {
      switch (_statusFilter) {
        case 'curso':
          return !c.isClosed;
        case 'cuadrada':
          return c.isClosed && c.difference == 0;
        case 'diferencia':
          return c.isClosed && c.difference != 0;
        default:
          return true;
      }
    }).toList();
  }
  void _toggleStatus(String key) {
    setState(() {
      _statusFilter = _statusFilter == key ? '' : key;
      _page = 0;
    });
  }

  Widget _titleBlock(bool compact) {
  return SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Corte de caja',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kBlack,
            fontSize: compact ? 26 : 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Consulta y revisa los cortes de caja de tus sucursales.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kGrayText,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

  Widget _searchField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _search = value;
            _page = 0;
          });
        },
        style: const TextStyle(color: _kBlack, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o sucursal',
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
          ),
          filled: true,
          fillColor: _kFieldBg,
          prefixIcon: const Icon(Icons.search, color: _kGreen),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _kGreen,
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
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: _kBorderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: _kGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

Widget _periodSelector() {
  return Container(
    width: double.infinity,
    height: 48,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorderLight),
    ),
    child: Row(
      children: _periods.map((label) {
        final selected = _period == label;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () {
                setState(() {
                  _period = label;
                  _setPeriodDates(label);
                  _page = 0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? _kGreen.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected ? _kGreen : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: _kBlack,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}


 Widget _labeled(String label, Widget child) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: double.infinity,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kBlack,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

  Widget _dateField({required bool isFrom}) {
    final date = isFrom ? _from : _to;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _kFieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorderLight),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 17,
              color: _kGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _dateText(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kBlack,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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
      offset: const Offset(0, 48),
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _kBorderLight),
      ),
      onSelected: (value) {
        setState(() {
          _branch = value == allKey ? null : value;
          _page = 0;
        });
      },
      itemBuilder: (context) {
        PopupMenuItem<String> option(String value, String label) {
          final selected =
              (value == allKey && _branch == null) || value == _branch;
          return PopupMenuItem<String>(
            value: value,
            height: 44,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _kGreen : _kBlack,
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }
        return [
          option(allKey, 'Todas las sucursales'),
          ..._allBranches.map((b) => option(b, b)),
        ];
      },
      child: Container(
        height: 46,
        width: double.infinity,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: active
              ? _kGreen.withValues(alpha: 0.15)
              : _kFieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? _kGreen : _kBorderLight,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _branch ?? 'Todas las sucursales',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kBlack,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _kGreen,
              size: 23,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final from = _labeled('Desde', _dateField(isFrom: true));
        final to = _labeled('Hasta', _dateField(isFrom: false));
        final branch = _labeled('Sucursal', _branchDropdown());
        if (width >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: _labeled('Período', _periodSelector()),
              ),
              const SizedBox(width: 18),
              Container(width: 1, height: 46, color: _kBorderLight),
              const SizedBox(width: 18),
              Expanded(child: from),
              const SizedBox(width: 10),
              Expanded(child: to),
              const SizedBox(width: 10),
              Expanded(child: branch),
              const SizedBox(width: 12),
              SizedBox(width: 205, child: _initialCashButton()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _labeled(
              'Período',
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _periodSelector(),
              ),
            ),
            const SizedBox(height: 14),
            if (width >= 600)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: from),
                  const SizedBox(width: 10),
                  Expanded(child: to),
                  const SizedBox(width: 10),
                  Expanded(child: branch),
                  const SizedBox(width: 10),
                  SizedBox(width: 205, child: _initialCashButton()),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(child: from),
                  const SizedBox(width: 10),
                  Expanded(child: to),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: branch),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _initialCashButton()),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _initialCashButton() {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: _savingInitialCash ? null : _showInitialCashDialog,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: _kGreen.withValues(alpha: 0.12),
          side: const BorderSide(color: _kGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Configurar efectivo inicial',
            maxLines: 1,
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showInitialCashDialog() async {
    try {
      final branches = await _branchService.getBranches();
      if (!mounted) return;
      final usableBranches = branches
          .where((b) => (b['id']?.toString() ?? '').isNotEmpty)
          .toList();
      if (usableBranches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sucursales disponibles.')),
        );
        return;
      }
      String? selectedBranchId = usableBranches.first['id'].toString();
      String selectedBranchName = _pickString(
            usableBranches.first,
            ['branch_name', 'name', 'nombre'],
          ) ??
          'Sucursal';
      _initialCashController.clear();
      final initialDoc = await FirebaseFirestore.instance
          .collection('branch_initial_cash')
          .doc(selectedBranchId)
          .get();
      final savedAmount = initialDoc.data()?['initial_cash'];
      if (savedAmount is num) {
        _initialCashController.text = savedAmount.toStringAsFixed(2);
      } else if (savedAmount is String) {
        _initialCashController.text = savedAmount;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Configurar efectivo inicial',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Sucursal',
                      floatingLabelStyle:
                          const TextStyle(color: _kGreenDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _kGreenDark,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: usableBranches.map((branch) {
                      final id = branch['id'].toString();
                      final name = _pickString(
                            branch,
                            ['branch_name', 'name', 'nombre'],
                          ) ??
                          'Sucursal';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      final branch = usableBranches.firstWhere(
                        (b) => b['id']?.toString() == value,
                      );
                      final name = _pickString(
                            branch,
                            ['branch_name', 'name', 'nombre'],
                          ) ??
                          'Sucursal';
                      setDialogState(() {
                        selectedBranchId = value;
                        selectedBranchName = name;
                        _initialCashController.clear();
                      });
                      try {
                        final doc = await FirebaseFirestore.instance
                            .collection('branch_initial_cash')
                            .doc(value)
                            .get();
                        final stored = doc.data()?['initial_cash'];
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          if (stored is num) {
                            _initialCashController.text =
                                stored.toStringAsFixed(2);
                          } else if (stored is String) {
                            _initialCashController.text = stored;
                          } else {
                            _initialCashController.clear();
                          }
                        });
                      } catch (e) {
                        debugPrint(
                          'Error al consultar el efectivo inicial: $e',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _initialCashController,
                    cursorColor: _kGreenDark,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Efectivo inicial',
                      floatingLabelStyle:
                          const TextStyle(color: _kGreenDark),
                      hintText: '00.00',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _kGreenDark,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: _savingInitialCash
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                style: ButtonStyle(
                  foregroundColor: const WidgetStatePropertyAll(_kCancel),
                  overlayColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed) ||
                        states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)) {
                      return _kCancel.withValues(alpha: 0.12);
                    }
                    return Colors.white;
                  }),
                  side: WidgetStateProperty.resolveWith((states) {
                    final pressed = states.contains(WidgetState.pressed);
                    return BorderSide(
                      color: pressed
                          ? _kCancel.withValues(alpha: 0.25)
                          : _kCancel,
                      width: 1.2,
                    );
                  }),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: _kGreen.withValues(alpha: 0.12),
                  side: const BorderSide(color: _kGreen, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _savingInitialCash
                    ? null
                    : () async {
                        final branchId = selectedBranchId;
                        final amount = double.tryParse(
                          _initialCashController.text
                              .trim()
                              .replaceAll(',', ''),
                        );
                        if (branchId == null ||
                            amount == null ||
                            !amount.isFinite ||
                            amount < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Selecciona una sucursal e ingresa un monto válido.',
                              ),
                            ),
                          );
                          return;
                        }
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Debes iniciar sesión para guardar.',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => _savingInitialCash = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('branch_initial_cash')
                              .doc(branchId)
                              .set({
                            'branch_id': branchId,
                            'branch_name': selectedBranchName,
                            'initial_cash': amount,
                            'updated_at': FieldValue.serverTimestamp(),
                            'updated_by': user.uid,
                          }, SetOptions(merge: true));
                          _savingInitialCash = false;
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Efectivo inicial guardado correctamente.',
                              ),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => _savingInitialCash = false);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo guardar el efectivo inicial.',
                              ),
                            ),
                          );
                          debugPrint(
                            'Error al guardar efectivo inicial: $e',
                          );
                        }
                      },
                child: const Text(
                  'Guardar',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error al abrir configuración de efectivo inicial: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar las sucursales.'),
        ),
      );
    }
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String note,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    bool pressed = false;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return Listener(
          onPointerDown: (_) => setLocal(() => pressed = true),
          onPointerUp: (_) => setLocal(() => pressed = false),
          onPointerCancel: (_) => setLocal(() => pressed = false),
          child: Material(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: pressed
                        ? _kGreenDark
                        : (selected ? color : _kBorderLight),
                    width: (pressed || selected) ? 1.6 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ColoredBox(
                          color: color,
                          child: const SizedBox(width: 4),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 12, 8, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: _kBlack,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Center(
                                  child: Text(
                                    value,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  note,
                                  style: const TextStyle(
                                    color: _kSoftGray,
                                    fontSize: 11,
                                  ),
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
          ),
        );
      },
    );
  }

  Widget _gridRow(List<Widget> children) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }

  Widget _summaryCards(List<_ClosureView> items) {
    final open = items.where((c) => !c.isClosed).length;
    final balanced =
        items.where((c) => c.isClosed && c.difference == 0).length;
    final withDifference =
        items.where((c) => c.isClosed && c.difference != 0).length;
    final cards = <Widget>[
      _summaryCard(
        label: 'En curso',
        value: '$open',
        note: 'cortes de caja',
        color: _kBlue,
        selected: _statusFilter == 'curso',
        onTap: () => _toggleStatus('curso'),
      ),
      _summaryCard(
        label: 'Cuadradas',
        value: '$balanced',
        note: 'cortes de caja',
        color: _kGreen,
        selected: _statusFilter == 'cuadrada',
        onTap: () => _toggleStatus('cuadrada'),
      ),
      _summaryCard(
        label: 'Con diferencia',
        value: '$withDifference',
        note: 'sobrante o faltante',
        color: _kExtra,
        selected: _statusFilter == 'diferencia',
        onTap: () => _toggleStatus('diferencia'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return _gridRow(cards);
        }
        return Column(
          children: [
            _gridRow([cards[0], cards[1]]),
            const SizedBox(height: 10),
            _gridRow([cards[2]]),
          ],
        );
      },
    );
  }

  Widget _avatar(String name, {double size = 44}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE0F4EC),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: _kGreen,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
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
      bg = const Color(0xFFE3F0FD);
      fg = _kBlue;
      border = const Color(0xFFB9D6F5);
    } else if (c.difference == 0) {
      text = 'Cuadrada';
      bg = _kGreen.withValues(alpha: 0.15);
      fg = _kGreen;
      border = _kGreen;
    } else if (c.difference < 0) {
      text = 'Faltante';
      bg = const Color(0xFFFDECEA);
      fg = const Color(0xFFC62828);
      border = const Color(0xFFEF9A9A);
    } else {
      text = 'Sobrante';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      border = const Color(0xFFFFB74D);
    }
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          date == null ? '—' : _dateText(date),
          style: const TextStyle(color: _kGrayText, fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(
          date == null ? '$timeLabel —' : '$timeLabel ${_timeText(date)}',
          style: const TextStyle(color: _kGrayText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _dateTimeCell(DateTime? date) {
    if (date == null) {
      return const Text(
        '—',
        textAlign: TextAlign.center,
        style: TextStyle(color: _kSoftGray, fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _dateText(date),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kBlack,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _timeText(date),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kGrayText, fontSize: 13),
        ),
      ],
    );
  }

  Widget _closeCell(_ClosureView c) {
    if (c.closedAt != null) return _dateTimeCell(c.closedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '—',
          textAlign: TextAlign.center,
          style: TextStyle(color: _kSoftGray, fontSize: 14),
        ),
        if (!c.isClosed) ...[
          const SizedBox(height: 3),
          const Text(
            'En curso',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kSoftGray, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _closureRow(_ClosureView c) {
    const titleStyle = TextStyle(
      color: _kBlack,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );

    Widget titled(String title, Widget content) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          const SizedBox(height: 10),
          content,
        ],
      );
    }

    return _PressableCard(
      onTap: () => _openClosureDetails(c),
      padding: const EdgeInsets.fromLTRB(26, 14, 12, 14),
      shadowColor: const Color(0x0F000000),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 28, right: 170),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Empleado y sucursal sin encabezado.
                  Expanded(
                    flex: _fEmployee,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _avatar(c.userName, size: 58),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.userName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _kBlack,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c.branch,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _kGrayText,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  c.role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _kSoftGray,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: _fOpen,
                    child: titled(
                      'Apertura',
                      _dateTimeCell(c.openedAt),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: _fClose,
                    child: titled(
                      'Cierre',
                      _closeCell(c),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: _fTime,
                    child: titled(
                      'Tiempo de apertura',
                      Text(
                        _durationShort(c),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _kBlack,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: _fStatus,
                    child: titled(
                      'Estado',
                      Align(
                        alignment: Alignment.topCenter,
                        child: _statusBadge(c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(
                color: _accentColor(c),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 162,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Ver resumen',
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _kGreenDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _kGreenDark,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _closureCard(_ClosureView c) {
    Widget timeInformation() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final start = _timeBlock(
            title: 'Inicio',
            timeLabel: 'Entrada',
            date: c.openedAt,
          );
          final close = _timeBlock(
            title: 'Cierre',
            timeLabel: 'Salida',
            date: c.closedAt,
          );
          final duration = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tiempo de apertura',
                style: TextStyle(
                  color: _kBlack,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _durationText(c),
                style: const TextStyle(
                  color: _kBlack,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!c.isClosed) ...[
                const SizedBox(height: 4),
                const Text(
                  'En curso',
                  style: TextStyle(
                    color: _kBlack,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: start),
                    const SizedBox(width: 12),
                    Expanded(child: close),
                  ],
                ),
                const SizedBox(height: 14),
                duration,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: start),
              const SizedBox(width: 12),
              Expanded(child: close),
              const SizedBox(width: 12),
              Expanded(child: duration),
            ],
          );
        },
      );
    }

    return _PressableCard(
      onTap: () => _openClosureDetails(c),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: _avatar(c.userName, size: 50),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kBlack,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c.branch} • ${c.role}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kSoftGray,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _statusBadge(c),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Flexible(
                                child: Text(
                                  'Ver resumen',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _kGreenDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 1),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: _kGreenDark,
                                size: 25,
                              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: timeInformation(),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: _accentColor(c)),
            ),
          ],
        ),
      ),
    );
  }

Widget _pageButton(
  String label, {
  bool selected = false,
  bool big = false,
  VoidCallback? onTap,
}) {
  final bool isArrow = label == '‹' || label == '›';
  final bool arrowPressed = isArrow && _pressedPageArrow == label;

  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      onHighlightChanged: (pressed) {
        if (!isArrow || onTap == null) return;

        setState(() {
          _pressedPageArrow = pressed ? label : null;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _kGreen.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected || arrowPressed
                ? _kGreenDark
                : isArrow
                    ? _kBorderLight
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
                color: onTap == null
                    ? Colors.black26
                    : Colors.black,
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: big ? 16 : 14,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.w500,
                  color: Colors.black,
                ),
              ),
      ),
    ),
  );
}
  Widget _pagination(int total, int totalPages, int start, int end) {
    final canPrev = _page > 0;
    final canNext = _page < totalPages - 1;
    const visible = 5;
    final maxStart = totalPages > visible ? totalPages - visible : 0;
    final first = (_page - 2).clamp(0, maxStart).toInt();
    final last =
        (first + visible) < totalPages ? first + visible : totalPages;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Text(
          total == 0
              ? 'Mostrando 0 cortes de caja'
              : 'Mostrando ${start + 1} - $end de $total cortes de caja',
          style: const TextStyle(color: _kSoftGray, fontSize: 13),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pageButton(
              '‹',
              big: true,
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
              big: true,
              onTap: canNext ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openClosureDetails(_ClosureView closure) async {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width - 32).clamp(280.0, 850.0);
    final dialogHeight = (screenSize.height - 48).clamp(300.0, 760.0);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: CashClosureDetailScreen(closureId: closure.id),
          ),
        );
      },
    );
  }

  Widget _listArea(List<_ClosureView> pageItems) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(color: _kGreen),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
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
                  foregroundColor: _kGreen,
                  side: const BorderSide(color: _kGreen),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (pageItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            'No hay cortes de caja para mostrar.',
            style: TextStyle(
              color: _kGrayText,
              fontSize: 15,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return Column(
          children: [
            ...pageItems.map(
              (c) => wide ? _closureRow(c) : _closureCard(c),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseFiltered;
    final filtered = _filtered;
    final total = filtered.length;
    final totalPages =
        (total / _pageSize).ceil().clamp(1, 9999).toInt();
    if (_page >= totalPages) {
      _page = totalPages - 1;
    }
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, total).toInt();
    final pageItems = filtered.sublist(start, end);

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: const AppHeader(currentRoute: '/cortes'),
      drawer: const AppDrawer(currentRoute: '/cortes'),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _kGreen,
          onRefresh: _load,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 24,
                          compact ? 14 : 20,
                          compact ? 12 : 24,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _titleBlock(compact),
                            const SizedBox(height: 18),
                            _searchField(),
                            const SizedBox(height: 16),
                            _filters(),
                            const SizedBox(height: 18),
                            if (!_loading && _error == null) ...[
                              _summaryCards(base),
                              const SizedBox(height: 18),
                            ],
                            _listArea(pageItems),
                            if (!_loading && _error == null) ...[
                              const SizedBox(height: 6),
                              _pagination(
                                total,
                                totalPages,
                                start,
                                end,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
    this.padding = EdgeInsets.zero,
    this.shadowColor = const Color(0x10000000),
  });
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color shadowColor;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}
class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;
  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
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
          padding: widget.padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed ? _kGreenDark : _kBorderLight,
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}