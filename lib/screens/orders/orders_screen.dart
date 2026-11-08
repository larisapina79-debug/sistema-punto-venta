
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/new.dart';
import 'package:puntoventa/screens/orders/order_detail_screen.dart';
import 'order_form_screen.dart';
import 'ticket_order_screen.dart';

const _red = Color(0xFFF4512A);
const _borderGrey = Color(0xFFE0E0E0);
const _accent = Color(0xFF63B7C4);
const _blueStat = Color(0xFF1565C0);
const _fieldBg = Color(0xFFF8F8F8);
const _green = Color(0xFF1B7A2F);
const _orange = Color(0xFFE65100);
const _textDark = Color(0xFF171717);
const _muted = Color(0xFF666666);
const _hint = Color(0xFF9E9E9E);

String _groupThousands(String value) {
  final parts = value.split('.');
  final whole = parts.first.replaceAll(',', '');
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return parts.length > 1 ? '$grouped.${parts.sublist(1).join('.')}' : grouped;
}

class _ThousandsInputFormatter extends TextInputFormatter {
  const _ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final plain = newValue.text.replaceAll(',', '');
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(plain)) {
      return oldValue;
    }
    final formatted = _groupThousands(plain);
    final position = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final count = newValue.text.substring(0, position).replaceAll(',', '').length;
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < count) {
      if (formatted[offset] != ',') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}


class OrdersScreen extends StatefulWidget {
  final Set<String>? cashClosureOrderIds;
  const OrdersScreen({
    super.key,
    this.cashClosureOrderIds,
  });
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 5;
  late final AnimationController _deliveryAlertController;
  bool _showOnlyCashClosureOrders = false;
  static const List<MapEntry<String, String>> _statusOptions = [
    MapEntry('pendiente', 'Pendiente'),
    MapEntry('entregado', 'Entregado'),
    MapEntry('cancelado', 'Cancelado'),
  ];
  static const List<MapEntry<String, String>> _periodOptions = [
    MapEntry('hoy', 'Hoy'),
    MapEntry('semana', 'Esta semana'),
    MapEntry('mes', 'Este mes'),
  ];
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BranchService _branchService = BranchService();
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey _branchKey = GlobalKey();
  StreamSubscription<List<Map<String, dynamic>>>? _branchSub;
  List<Map<String, dynamic>> _branches = [];
  String? _branchFilter;
  String? _statusFilter;
  String? _dateFilter;
  String? _filter;
  DateTime? _deliveryRangeStart;
  DateTime? _deliveryRangeEnd;
  String _search = '';
  int _page = 0;
  String get _role =>
      (Session.user?.roleUser ?? '').toString().trim().toLowerCase();
  bool get _isAdmin => _role == 'administrador';
  bool get _isSupervisor => _role == 'supervisor';
  bool get _isEmployee => _role == 'empleado';
  bool get _canManage => _isAdmin || _isSupervisor;
  Set<String> get _assignedBranchIds {
    final branches = Session.user?.idBranches ?? [];
    return branches
        .map((branch) => branch.id)
        .where((id) => id.isNotEmpty)
        .toSet();
  }
  bool _canAccessBranch(String branchId) {
    if (_isAdmin) return true;
    return _assignedBranchIds.contains(branchId);
  }

  @override
  void initState() {
    super.initState();
    _deliveryAlertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _showOnlyCashClosureOrders = widget.cashClosureOrderIds != null;
    final now = DateTime.now();
    if (widget.cashClosureOrderIds == null) {
      _dateFilter = 'mes';
      _deliveryRangeStart = DateTime(now.year, now.month, 1);
      _deliveryRangeEnd = DateTime(now.year, now.month + 1, 0);
    }
    if (_isEmployee && _assignedBranchIds.isNotEmpty) {
      _branchFilter = _assignedBranchIds.first;
    }
    _branchSub = _branchService.watchBranches().listen(
      (rows) {
        if (!mounted) return;
        setState(() {
          final active = rows
              .where((b) => b['branch_status'] == true)
              .toList();
          active.sort(
            (a, b) => _text(a['branch_name'])
                .toLowerCase()
                .compareTo(_text(b['branch_name']).toLowerCase()),
          );
          _branches = _isAdmin
              ? active
              : active
                  .where(
                    (b) => _assignedBranchIds.contains(_text(b['id'])),
                  )
                  .toList();
          if (!_isEmployee &&
              _branchFilter != null &&
              !_branches.any(
                (b) => _text(b['id']) == _branchFilter,
              )) {
            _branchFilter = null;
          }
          _page = 0;
        });
      },
      onError: (e) => debugPrint('Error al cargar sucursales: $e'),
    );
  }

  @override
  void dispose() {
    _deliveryAlertController.dispose();
    _branchSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }
  String _text(dynamic value) => value?.toString().trim() ?? '';
  String _referenceId(dynamic value) {
    if (value is DocumentReference) return value.id;
    return value?.toString().trim() ?? '';
  }
  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          _text(value).replaceAll(',', ''),
        ) ??
        0;
  }
  String _money(dynamic value) => '\$${_groupThousands(_num(value).toStringAsFixed(2))}';
  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
  DateTime _dayOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  String _fmtDate(dynamic value) {
    final d = value is DateTime ? value : _date(value);
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
  String _clientName(Map<String, dynamic> data) {
    final name = _text(data['client_name']);
    return name.isEmpty ? 'Cliente sin nombre' : name;
  }
  String _status(Map<String, dynamic> data) {
    final s = _text(data['order_status']).toLowerCase();
    return s.isEmpty ? 'pendiente' : s;
  }
  String _statusLabel(String status) {
    for (final o in _statusOptions) {
      if (o.key == status) return o.value;
    }
    return status.isEmpty ? 'Pendiente' : status;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'entregado':
        return _green;
      case 'cancelado':
        return _red;
      case 'pendiente':
        return _orange;
      default:
        return _accent;
    }
  }

  String _branchName(String id) {
    for (final b in _branches) {
      if (_text(b['id']) == id) {
        final name = _text(b['branch_name']);
        return name.isEmpty ? 'Sucursal sin nombre' : name;
      }
    }
    return '—';
  }
  bool _orderMatchesBranch(Map<String, dynamic> data) {
    final branchId = _referenceId(data['id_branches']);
    if (_isEmployee) {
      return _assignedBranchIds.contains(branchId);
    }
    if (!_isAdmin && !_assignedBranchIds.contains(branchId)) {
      return false;
    }
    return _branchFilter == null || branchId == _branchFilter;
  }
  bool _hasBalance(Map<String, dynamic> data) =>
      _num(data['balance_due']) > 0 &&
      _status(data) != 'cancelado' &&
      !_isPaidInFull(data);
  bool _isPaidInFull(Map<String, dynamic> data) {
    final total = _num(data['total_order']);
    final paid = _num(data['paid_amount']);
    return total > 0 && paid >= total;
  }
  double _pendingAmount(Map<String, dynamic> data) {
    final balance = _num(data['balance_due']);
    if (balance > 0) return balance;
    final total = _num(data['total_order']);
    final paid = _num(data['paid_amount']);
    return (total - paid).clamp(0.0, double.infinity);
  }
  bool _matchesSearch(String id, Map<String, dynamic> data) {
    if (_search.isEmpty) return true;
    final products = (data['products'] as List?) ?? const [];
    final productNames = products
        .map((p) => p is Map ? _text(p['name_product']) : '')
        .toList();
    return [
      id,
      _text(data['client_name']),
      _text(data['client_phone']),
      _text(data['observations_order']),
      ...productNames,
    ].any((v) => v.toLowerCase().contains(_search));
  }

  bool _matchesDate(Map<String, dynamic> data) {
    final dt = _date(data['delivery_date']);
    if (dt == null) return false;
    final day = _dayOnly(dt);
    if (_deliveryRangeStart != null &&
        _deliveryRangeEnd != null) {
      final start = _dayOnly(_deliveryRangeStart!);
      final end = _dayOnly(_deliveryRangeEnd!);
      return !day.isBefore(start) && !day.isAfter(end);
    }
    final now = DateTime.now();
    final today = _dayOnly(now);
    if (_dateFilter == 'hoy') {
      return day == today;
    }
    if (_dateFilter == 'semana') {
      final start = today.subtract(
        Duration(days: today.weekday - 1),
      );
      final end = start.add(const Duration(days: 7));
      return !day.isBefore(start) && day.isBefore(end);
    }
    if (_dateFilter == 'mes') {
      final start = DateTime(today.year, today.month, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return !day.isBefore(start) && !day.isAfter(end);
    }
    return true;
  }

  void _selectPeriod(String period) {
    final now = DateTime.now();
    final today = _dayOnly(now);
    late DateTime start;
    late DateTime end;
    if (period == 'hoy') {
      start = today;
      end = today;
    } else if (period == 'semana') {
      start = today.subtract(
        Duration(days: today.weekday - 1),
      );
      end = start.add(const Duration(days: 6));
    } else {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0);
    }
    setState(() {
      _showOnlyCashClosureOrders = false;
      _dateFilter = period;
      _deliveryRangeStart = start;
      _deliveryRangeEnd = end;
      _filter = null;
      _statusFilter = null;
      _page = 0;
    });
  }

  Future<DateTime?> _showCustomDatePicker({
    required DateTime? initialDate,
  }) async {
    final now = _dayOnly(DateTime.now());
    DateTime selectedDate = _dayOnly(initialDate ?? now);
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: SizedBox(
                width: screenWidth > 400 ? 360 : screenWidth - 32,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: _accent,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: _textDark,
                        ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CalendarDatePicker(
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        currentDate: now,
                        onDateChanged: (date) {
                          setDialogState(() {
                            selectedDate = _dayOnly(date);
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop(
                                  selectedDate,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Aceptar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectStartDate() async {
    final selected = await _showCustomDatePicker(
      initialDate: _deliveryRangeStart,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _showOnlyCashClosureOrders = false;
      _deliveryRangeStart = _dayOnly(selected);
      if (_deliveryRangeEnd != null &&
          _deliveryRangeEnd!.isBefore(_deliveryRangeStart!)) {
        _deliveryRangeEnd = _deliveryRangeStart;
      }
      _dateFilter = null;
      _filter = null;
      _statusFilter = null;
      _page = 0;
    });
  }

  Future<void> _selectEndDate() async {
    final selected = await _showCustomDatePicker(
      initialDate: _deliveryRangeEnd ?? _deliveryRangeStart,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _showOnlyCashClosureOrders = false;
      _deliveryRangeEnd = _dayOnly(selected);
      if (_deliveryRangeStart != null &&
          _deliveryRangeEnd!.isBefore(_deliveryRangeStart!)) {
        _deliveryRangeStart = _deliveryRangeEnd;
      }
      _dateFilter = null;
      _filter = null;
      _statusFilter = null;
      _page = 0;
    });
  }

  bool _isAttentionOrder(Map<String, dynamic> data) {
    if (_status(data) != 'pendiente') return false;
    final delivery = _date(data['delivery_date']);
    if (delivery == null) return false;
    final today = _dayOnly(DateTime.now());
    final limit = today.add(const Duration(days: 3));
    final day = _dayOnly(delivery);
    return !day.isAfter(limit);
  }
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _ordersNeedingAttention(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
  ) {
    return all.where((doc) {
      return _isAttentionOrder(doc.data());
    }).toList()
      ..sort((a, b) {
        final da = _date(a.data()['delivery_date']);
        final db = _date(b.data()['delivery_date']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
  }

  Widget _upcomingOrdersAlert(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
  ) {
    final attentionOrders = _ordersNeedingAttention(all);
    final today = _dayOnly(DateTime.now());
    final limit = today.add(const Duration(days: 3));
    int overdue = 0;
    int dueToday = 0;
    int upcoming = 0;
    for (final doc in attentionOrders) {
      final delivery = _date(doc.data()['delivery_date']);
      if (delivery == null) continue;
      final day = _dayOnly(delivery);
      if (day.isBefore(today)) {
        overdue++;
      } else if (day == today) {
        dueToday++;
      } else if (!day.isAfter(limit)) {
        upcoming++;
      }
    }
    final totalAttention = attentionOrders.length;
    final selected = _filter == 'proximos';
    final alert = totalAttention > 0;
    final details = <String>[];
    if (overdue > 0) details.add('$overdue vencidos');
    if (dueToday > 0) details.add('$dueToday para hoy');
    if (upcoming > 0) details.add('$upcoming en los próximos 3 días');
    return AnimatedBuilder(
      animation: _deliveryAlertController,
      builder: (context, _) {
        final pulse = alert ? _deliveryAlertController.value : 0.0;
        return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _showOnlyCashClosureOrders = false;
          _filter = selected ? null : 'proximos';
          _statusFilter = null;
          _page = 0;
        });
      },
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: alert
              ? Color.lerp(Colors.white, const Color(0xFFFFE0B2), pulse * 0.55)
              : Colors.white,
          boxShadow: alert
              ? [BoxShadow(
                  color: _orange.withValues(alpha: 0.12 + pulse * 0.34),
                  blurRadius: 5 + pulse * 16,
                  spreadRadius: pulse * 2,
                )]
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: alert ? _orange : (selected ? _orange : _borderGrey),
            width: alert ? 1.5 + pulse : (selected ? 1.8 : 1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Row(
            children: [
              Container(width: 4, color: _orange),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: _orange,
                        size: 19,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalAttention',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: _orange,
                        ),
                      ),
                      const Text(
                        'Por entregar',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        details.isEmpty ? 'Sin alertas' : details.join(' · '),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: _muted,
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
        );
      },
    );
  }

  Widget _paymentSummaryRow(
  String label,
  String value, {
  Color valueColor = _textDark,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

Future<Map<String, double>?> _showDeliveryPaymentDialog(
  double balance,
) async {
  final cashCtrl = TextEditingController(text: '0.00');
  final transferCtrl = TextEditingController(text: '0.00');
  final cashFocus = FocusNode();
  final transferFocus = FocusNode();
  void normalize(TextEditingController ctrl) {
    final raw = double.tryParse(ctrl.text.trim().replaceAll(',', '')) ?? 0.0;
    final amount = raw.isFinite && raw > 0 ? raw : 0.0;
    final formatted = _groupThousands(amount.toStringAsFixed(2));
    if (ctrl.text != formatted) {
      ctrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }
  cashFocus.addListener(() {
    if (!cashFocus.hasFocus) normalize(cashCtrl);
  });
  transferFocus.addListener(() {
    if (!transferFocus.hasFocus) normalize(transferCtrl);
  });
  bool cashSelected = true;
  final searchCtrl = TextEditingController();
  bool methodsOpen = true;
  String methodQuery = '';
  bool transferSelected = false;
  String? errorMessage;
  double parseAmount(String value) {
    final number = double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
    return number.isFinite && number > 0 ? number : 0.0;
  }
  final result = await showDialog<Map<String, double>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final cash = cashSelected ? parseAmount(cashCtrl.text) : 0.0;
          final transfer = transferSelected
              ? parseAmount(transferCtrl.text)
              : 0.0;
          final received = cash + transfer;
          final remaining = balance - received;
          final canConfirm =
              received > 0 && (received - balance).abs() < 0.01;
          Widget paymentOption({
            required String title,
            required bool selected,
            required VoidCallback onTap,
          }) {
            return ListTile(
              minLeadingWidth: 0,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _accent : Colors.transparent,
                  border: selected
                      ? null
                      : Border.all(
                          color: const Color(0xFFBDBDBD),
                          width: 2.7,
                        ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: Colors.white,
                      )
                    : null,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: _textDark,
                ),
              ),
              onTap: onTap,
            );
          }

          Widget amountField({
            required String label,
            required TextEditingController controller,
            required FocusNode focusNode,
          }) {
            void adjust(double delta) {
              final next = (parseAmount(controller.text) + delta)
                  .clamp(0.0, double.infinity);
              controller.value = TextEditingValue(
                text: _groupThousands(next.toStringAsFixed(2)),
                selection: TextSelection.collapsed(
                  offset: _groupThousands(next.toStringAsFixed(2)).length,
                ),
              );
              setDialogState(() => errorMessage = null);
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [
                _ThousandsInputFormatter(),
              ],
              onChanged: (_) {
                setDialogState(() => errorMessage = null);
              },
              onSubmitted: (_) => normalize(controller),
              decoration: InputDecoration(
                labelText: label,
                prefixText: r'$ ',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 56,
                ),
                suffixIcon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => adjust(1),
                      child: const SizedBox(
                        height: 27,
                        width: 44,
                        child: Icon(Icons.keyboard_arrow_up_rounded,
                            color: _accent, size: 22),
                      ),
                    ),
                    InkWell(
                      onTap: () => adjust(-1),
                      child: const SizedBox(
                        height: 27,
                        width: 44,
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: _accent, size: 22),
                      ),
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
              ),
            );
          }
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Registrar pago de entrega',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFCFC),
                        border: Border.all(
                          color: const Color(0xFFBDBDBD),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Seleccionar forma de pago',
                              style: TextStyle(
                                color: _textDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '${(cashSelected ? 1 : 0) + (transferSelected ? 1 : 0)} forma(s) agregada(s)',
                              style: const TextStyle(
                                color: _accent,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Icon(
                              methodsOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: _accent,
                            ),
                            onTap: () {
                              setDialogState(() {
                                methodsOpen = !methodsOpen;
                              });
                            },
                          ),
                          if (methodsOpen) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 0, 14, 10),
                              child: TextField(
                                controller: searchCtrl,
                                onChanged: (value) {
                                  setDialogState(() {
                                    methodQuery = value.trim().toLowerCase();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Buscar forma de pago...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: _accent,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFBDBDBD),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: _accent,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if ('efectivo'.contains(methodQuery))
                              paymentOption(
                                title: 'Efectivo',
                                selected: cashSelected,
                                onTap: () {
                                  setDialogState(() {
                                    cashSelected = !cashSelected;
                                    errorMessage = null;
                                  });
                                },
                              ),
                            if ('transferencia'.contains(methodQuery))
                              paymentOption(
                                title: 'Transferencia',
                                selected: transferSelected,
                                onTap: () {
                                  setDialogState(() {
                                    transferSelected = !transferSelected;
                                    errorMessage = null;
                                  });
                                },
                              ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Importes por forma de pago',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (cashSelected) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFBFB),
                          border: Border.all(
                            color: _borderGrey,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Efectivo',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            amountField(
                              label: 'Cantidad recibida',
                              controller: cashCtrl,
                              focusNode: cashFocus,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (transferSelected)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFBFB),
                          border: Border.all(
                            color: _borderGrey,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transferencia',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            amountField(
                              label: 'Cantidad recibida',
                              controller: transferCtrl,
                              focusNode: transferFocus,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFB),
                        border: Border.all(
                          color: _borderGrey,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _paymentSummaryRow(
                            'Saldo pendiente',
                            _money(balance),
                          ),
                          const Divider(height: 12),
                          _paymentSummaryRow(
                            'Total de este abono',
                            _money(received),
                            valueColor: _green,
                          ),
                          const Divider(height: 12),
                          _paymentSummaryRow(
                            'Faltante por entregar',
                            _money(
                              remaining > 0 ? remaining : 0,
                            ),
                            valueColor: remaining.abs() < 0.01
                                ? _green
                                : _red,
                          ),
                        ],
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: _red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _red,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: _red, width: 1.6),
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Cancelar', textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                            onPressed: () {
                              if (!cashSelected && !transferSelected) {
                                setDialogState(() {
                                  errorMessage =
                                      'Selecciona al menos una forma de pago.';
                                });
                                return;
                              }
                              if ((cashSelected && cash <= 0) ||
                                  (transferSelected && transfer <= 0)) {
                                setDialogState(() {
                                  errorMessage =
                                      'Ingresa un importe válido en cada forma seleccionada.';
                                });
                                return;
                              }
                              if (!canConfirm) {
                                setDialogState(() {
                                  errorMessage = received < balance
                                      ? 'El pago no cubre el saldo pendiente.'
                                      : 'El importe recibido supera el saldo pendiente.';
                                });
                                return;
                              }
                              final payments = <String, double>{};
                              if (cashSelected) {
                                payments['efectivo'] = cash;
                              }
                              if (transferSelected) {
                                payments['transferencia'] = transfer;
                              }
                              Navigator.pop(
                                dialogContext,
                                payments,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE7F4F7),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: _accent, width: 1.6),
                              ),
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Confirmar entrega', textAlign: TextAlign.center),
                            ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  cashFocus.dispose();
  transferFocus.dispose();
  cashCtrl.dispose();
  transferCtrl.dispose();
  searchCtrl.dispose();
  return result;
}

  Future<Map<String, Map<String, String>>> _loadPaymentCatalog() async {
    final snapshot = await _db.collection('payment_methods').get();
    final result = <String, Map<String, String>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['payment_methods_name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      result[name.toLowerCase()] = {'id': doc.id, 'name': name};
    }
    return result;
  }

  Future<void> _setStatus(
    String id,
    String value, {
    Map<String, double>? paymentMethods,
  }) async {
    if (id.isEmpty || (!_canManage && !_isEmployee)) return;
    final paymentUserId = (Session.user?.idUser ?? '').toString().trim();
    if (value == 'entregado' && paymentMethods != null &&
        paymentMethods.isNotEmpty && paymentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se identificó al usuario que recibe el pago.')),
      );
      return;
    }
    final catalog = paymentMethods == null || paymentMethods.isEmpty
        ? <String, Map<String, String>>{}
        : await _loadPaymentCatalog();
    double r2(num v) => double.parse(v.toStringAsFixed(2));
    try {
      final orderRef = _db.collection('orders').doc(id);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) {
          throw Exception('El pedido no existe.');
        }
        final data = snapshot.data() ?? <String, dynamic>{};
        final currentStatus = _status(data);
        if (value == currentStatus) return;
        final branchId = _referenceId(data['id_branches']);
        if (_isEmployee && !_assignedBranchIds.contains(branchId)) {
          throw Exception('No tienes permiso para modificar este pedido.');
        }
        if (_isEmployee && data['employee_status_changed'] == true) {
          throw Exception('Ya realizaste el único cambio permitido.');
        }
        final total = _num(data['total_order']);
        final paid = _num(data['paid_amount']);
        final balance = _num(data['balance_due']);
        final updates = <String, dynamic>{
          'order_status': value,
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (value == 'entregado') {
          final pending = r2(
            balance > 0
                ? balance
                : (total - paid).clamp(0.0, double.infinity),
          );
          if (pending > 0) {
            if (paymentMethods == null || paymentMethods.isEmpty) {
              throw Exception('Debes registrar el pago pendiente.');
            }
            final received = r2(
              paymentMethods.values.fold<double>(
                0,
                (acumulado, amount) => acumulado + amount,)
            );
            if ((received - pending).abs() >= 0.01) {
              throw Exception(
                'El pago no coincide con el saldo pendiente.',
              );
            }
            final paymentMethod = paymentMethods.length > 1
                ? 'mixto'
                : paymentMethods.keys.first;
            final paymentDetails = paymentMethods.entries.map((entry) {
              final key = entry.key.trim().toLowerCase();
              final method = catalog[key];
              if (method == null) {
                throw Exception('La forma de pago ${entry.key} no existe en Firebase.');
              }
              return <String, dynamic>{
                'id_payment_methods': method['id']!,
                'payment_methods_name': method['name']!,
                'amount': r2(entry.value),
              };
            }).toList();
            final paymentRecord = {
              'amount': pending,
              'payment_methods': paymentDetails,
              'registered_by_id': paymentUserId,
              'registered_by_name': (Session.user?.nameUser ?? '').toString(),
              'registered_at': Timestamp.now(),
            };
            updates.addAll({
              'paid_amount': r2(paid + pending),
              'balance_due': 0,
              'delivery_payment': pending,
              'delivery_payment_method': paymentMethod,
              'delivery_payment_methods': paymentDetails,
              'delivery_payment_history': FieldValue.arrayUnion([
                paymentRecord,
              ]),
            });
          } else {
            updates.addAll({
              'balance_due': 0,
              'delivery_payment': 0,
            });
          }
          updates['delivered_at'] = FieldValue.serverTimestamp();
        } else if (currentStatus == 'entregado') {
          final deliveryPayment = _num(data['delivery_payment']);
          final savedPaid = _num(data['paid_amount']);
          final paidBefore = savedPaid >= total && deliveryPayment > 0
              ? r2((total - deliveryPayment).clamp(0.0, total))
              : savedPaid;
          updates.addAll({
            'paid_amount': paidBefore,
            'balance_due': r2(deliveryPayment),
            'delivery_payment': 0,
            'delivered_at': FieldValue.delete(),
          });
        }
        if (_isEmployee) {
          updates['employee_status_changed'] = true;
        }
        transaction.update(orderRef, updates);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido actualizado a ${_statusLabel(value)}.'),
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      debugPrint('Error al cambiar estado del pedido: $e');
      if (!mounted) return;
      final error = e.toString();
      String message;
      if (error.contains('único cambio permitido')) {
        message = 'Ya realizaste el único cambio permitido para este pedido.';
      } else if (error.contains('permiso')) {
        message = 'No tienes permiso para modificar este pedido.';
      } else if (error.contains('registrar el pago')) {
        message = 'Debes registrar el pago pendiente.';
      } else if (error.contains('no coincide')) {
        message = 'El pago no coincide con el saldo pendiente.';
      } else {
        message = 'No se pudo cambiar el estado del pedido.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  void _printTicket(String id, Map<String, dynamic> data) {
    OrderTicket.show(context, orderId: id, order: data);
  }

  Future<String?> _openMenuAt(
    BuildContext? anchor, {
    required List<MapEntry<String, String>> options,
    required String current,
    double maxWidth = 300,
  }) async {
    final box = anchor?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return null;
    final topLeft = box.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + box.size.height + 6,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    return showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 5,
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(
          color: _borderGrey,
          width: 1,
        ),
      ),
      constraints: BoxConstraints(
        minWidth: box.size.width,
        maxWidth: maxWidth,
      ),
      items: options.map((option) {
        final selected = current == option.key;
        return PopupMenuItem<String>(
          value: option.key,
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: _textDark,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  color: _accent,
                  size: 23,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openBranchMenu() async {
    if (_isEmployee) return;
    final selected = await _openMenuAt(
      _branchKey.currentContext,
      current: _branchFilter ?? '',
      options: [
        const MapEntry('', 'Todas las sucursales'),
        ..._branches.map((b) {
          final name = _text(b['branch_name']);
          return MapEntry(
            _text(b['id']),
            name.isEmpty ? 'Sucursal sin nombre' : name,
          );
        }),
      ],
    );
    if (selected == null || !mounted) return;
    final branch = selected.isEmpty ? null : selected;
    if (branch != null && !_canAccessBranch(branch)) return;
    setState(() {
      _branchFilter = branch;
      _page = 0;
    });
  }

  void _openForm() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
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
            width: size.width > 948 ? 900 : size.width - 32,
            height: size.height * 0.88,
            child: OrderFormScreen(),
          ),
        );
      },
    );
  }

  void _openDetail(String id, Map<String, dynamic> data) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
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
            width: size.width > 948 ? 900 : size.width - 32,
            height: size.height * 0.88,
            child: OrderDetailScreen(orderId: id),
          ),
        );
      },
    );
  }

  Widget _titulo(bool compact) {
    return Column(
      children: [
        Text(
          'Pedidos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 26 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Consulta y administra los pedidos de tus clientes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF555555),
          ),
        ),
      ],
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
          hintText: 'Buscar por cliente, teléfono o producto...',
          hintStyle: const TextStyle(
            color: _hint,
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
                  tooltip: 'Limpiar búsqueda',
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

  Widget _nuevoButton() {
    return SizedBox(
      height: 48,
      child: NuevoButton(onPressed: _openForm),
    );
  }

  Widget _periodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Periodo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 48,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _borderGrey),
          ),
          child: Row(
            children: _periodOptions.map((option) {
              final selected = _dateFilter == option.key;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectPeriod(option.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? _accent.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _accent : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      option.value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _dateField({required bool isFrom}) {
    final date = isFrom ? _deliveryRangeStart : _deliveryRangeEnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isFrom ? 'Desde' : 'Hasta',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isFrom) {
              _selectStartDate();
            } else {
              _selectEndDate();
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: _accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date == null ? 'Seleccionar' : _fmtDate(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _branchFilterField() {
    var name = 'Todas las sucursales';
    if (_branchFilter != null) {
      name = _branchName(_branchFilter!);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openBranchMenu,
        child: Container(
          key: _branchKey,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name == '—' ? 'Sucursal' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraBusquedaYRegistro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            if (compact) {
              return Column(
                children: [
                  _periodSelector(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _dateField(isFrom: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _dateField(isFrom: false)),
                    ],
                  ),
                  if (constraints.maxWidth < 600) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!_isEmployee) ...[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Sucursal',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                _branchFilterField(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: _nuevoButton()),
                      ],
                    ),
                  ] else ...[
                    if (!_isEmployee) ...[
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sucursal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _branchFilterField(),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 150,
                        child: _nuevoButton(),
                      ),
                    ),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 5, child: _periodSelector()),
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 1),
                  color: _borderGrey,
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _dateField(isFrom: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _dateField(isFrom: false),
                ),
                if (!_isEmployee) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        const Text(
                          'Sucursal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 7),
                        _branchFilterField(),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: _nuevoButton(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String filtro,
    required Color color,
    required String label,
    required int value,
    required String note,
  }) {
    final selected = _filter == filtro;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _showOnlyCashClosureOrders = false;
          _filter = selected ? null : filtro;
          _statusFilter = null;
          _page = 0;
        });
      },
      child: Container(
        height: mobile ? 116 : 104,
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
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: mobile ? 2 : 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        '$value',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
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
                          fontSize: 10,
                          color: Colors.black45,
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
    );
  }

 
Widget _summaryCards(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
) {
  final pendientes =
      all.where((d) => _status(d.data()) == 'pendiente').length;
  final entregados =
      all.where((d) => _status(d.data()) == 'entregado').length;
  final conSaldo =
      all.where((d) => _hasBalance(d.data())).length;
  final cards = [
    _upcomingOrdersAlert(all),
    _summaryCard(
      filtro: 'pendiente',
      color: _orange,
      label: 'Pedidos pendientes',
      value: pendientes,
      note: 'por entregar',
    ),
    _summaryCard(
      filtro: 'entregado',
      color: _green,
      label: 'Pedidos entregados',
      value: entregados,
      note: 'completados',
    ),
    _summaryCard(
      filtro: 'saldo',
      color: _red,
      label: 'Con pago pendiente',
      value: conSaldo,
      note: 'por cobrar',
    ),
    _summaryCard(
      filtro: 'todas',
      color: _blueStat,
      label: 'Total de pedidos',
      value: all.length,
      note: 'registrados',
    ),
  ];
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 760) {
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        );
      }
      final gap = constraints.maxWidth >= 420 ? 10.0 : 8.0;
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              SizedBox(width: gap),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cards[2]),
              SizedBox(width: gap),
              Expanded(child: cards[3]),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: cards[4],
          ),
        ],
      );
    },
  );
}

  Widget _orderInfo(Map<String, dynamic> data) {
    final clientName = _clientName(data);
    final observation = _text(data['observations_order']);
    final phone = _text(data['client_phone']);
    return SizedBox(
      height: 92,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
          clientName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        if (observation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Observación: $observation',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Teléfono: $phone',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ],
      ),
    );
  }

  Widget _dato(
    String label,
    String value, {
    double? width,
    Color? color,
    bool highlight = false,
  }) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: highlight ? 14 : 12,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.normal,
            color: highlight ? (color ?? _muted) : _muted,
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color ?? _textDark,
            ),
          ),
        ],
      ],
    );
    return width == null
        ? content
        : SizedBox(width: width, child: content);
  }

  Widget _statusControl(
    String id,
    String status,
    Map<String, dynamic> data,
  ) {
    final color = _statusColor(status);
    final employeeLocked =
        _isEmployee && data['employee_status_changed'] == true;
    final canChange = _canManage || (_isEmployee && !employeeLocked);
    return SizedBox(
      width: 174,
      child: Align(
        alignment: Alignment.centerRight,
        child: Builder(
          builder: (anchor) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: !canChange
                  ? null
                  : () async {
                      final selected = await _openMenuAt(
                        anchor,
                        current: status,
                        options: _statusOptions,
                        maxWidth: 200,
                      );
                      if (selected == null ||
                          selected.isEmpty ||
                          selected == status ||
                          !mounted) {
                        return;
                      }
                      Map<String, double>? paymentMethods;
                      if (selected == 'entregado') {
                        final pending = _pendingAmount(data);
                        if (pending > 0.009) {
                          paymentMethods =
                              await _showDeliveryPaymentDialog(pending);
                          if (paymentMethods == null || !mounted) {
                            return;
                          }
                        }
                      }
                      await _setStatus(
                        id,
                        selected,
                        paymentMethods: paymentMethods,
                      );
                    },
              child: Container(
                width: 150,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canChange ? color : Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statusLabel(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: canChange ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                    if (canChange)
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 19,
                      )
                    else
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                        size: 16,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _printButton(String id, Map<String, dynamic> data) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _printTicket(id, data),
      child: Container(
        width: 38,
        height: 36,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _accent,
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.print_outlined,
          color: _accent,
          size: 20,
        ),
      ),
    );
  }

Widget _orderCard(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  final id = doc.id;
  final status = _status(data);
  final stripe = _statusColor(status);
  final total = _money(data['total_order']);
  final paid = _money(data['paid_amount']);
  final balance = _money(data['balance_due']);
  final paidInFull = _isPaidInFull(data);
  final showPaidLabel = status == 'entregado' ||
      (status == 'pendiente' && paidInFull);
  final showCancelledLabel = status == 'cancelado';
  final paymentLabel = showPaidLabel
      ? 'Pagado'
      : showCancelledLabel
          ? 'Cancelado'
          : 'Falta por entregar';
  final paymentValue =
      status == 'pendiente' && !paidInFull
          ? balance
          : '';
  final delivery = _fmtDate(data['delivery_date']);
  final balanceColor =
      _num(data['balance_due']) > 0 ? _red : _green;
  final paymentColor = showPaidLabel
      ? _green
      : showCancelledLabel
          ? _red
          : balanceColor;
  final info = _orderInfo(data);
  return _PressableOrderCard(
    onTap: () => _openDetail(id, data),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1040;
          final mobile = constraints.maxWidth < 600;
          if (wide) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    48, 12, 12, 12,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      Expanded(child: info),
                      const SizedBox(width: 16),
                      _dato(
                        'Entrega',
                        delivery,
                        width: 100,
                      ),
                      const SizedBox(width: 12),
                      _dato(
                        'Total',
                        total,
                        width: 80,
                      ),
                      const SizedBox(width: 12),
                      if (status != 'entregado') ...[
                        _dato(
                          'Anticipo',
                          paid,
                          width: 80,
                        ),
                        const SizedBox(width: 12),
                      ],
                      _dato(
                        paymentLabel,
                        paymentValue,
                        width: 112,
                        color: paymentColor,
                        highlight:
                            showPaidLabel ||
                            showCancelledLabel,
                      ),
                      const SizedBox(width: 16),
                      _statusControl(
                        id,
                        status,
                        data,
                      ),
                      const SizedBox(width: 10),
                      _printButton(id, data),
                      const SizedBox(width: 12),
                      const Text(
                        'Ver detalles',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w600,
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
                      color: stripe,
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            );
          }
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  46, 12, 12, 12,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Expanded(child: info),
                        if (mobile) ...[
                          const Text(
                            'Ver detalles',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
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
                          child: _dato(
                            'Entrega',
                            delivery,
                          ),
                        ),
                        Expanded(
                          child: _dato(
                            'Total',
                            total,
                          ),
                        ),
                        if (status != 'entregado')
                          Expanded(
                            child: _dato(
                              'Anticipo',
                              paid,
                            ),
                          ),
                        Expanded(
                          child: _dato(
                            paymentLabel,
                            paymentValue,
                            color: paymentColor,
                            highlight:
                                showPaidLabel ||
                                showCancelledLabel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        _printButton(id, data),
                        const SizedBox(width: 8),
                        _statusControl(
                          id,
                          status,
                          data,
                        ),
                      ],
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
                    color: stripe,
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
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
              ? 'Mostrando 0 pedidos'
              : 'Mostrando ${start + 1} - $end de $total pedidos',
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

  Widget _emptyOrders() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: _accent,
              size: 35,
            ),
            SizedBox(height: 12),
            Text(
              'No se encontraron pedidos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Prueba con otra búsqueda o cambia el filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(currentRoute: '/pedidos'),
      drawer: AppDrawer(currentRoute: '/pedidos'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('orders').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar los pedidos.\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _red),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _accent,
                    ),
                  );
                }
                final all = snapshot.data!.docs.where((doc) {
                  return _orderMatchesBranch(doc.data());
                }).toList();
                final orders = all.where((doc) {
                  final data = doc.data();
                  if (_showOnlyCashClosureOrders) {
                    final ids = widget.cashClosureOrderIds;
                    if (ids != null && !ids.contains(doc.id)) return false;
                  }
                  if (!_matchesSearch(doc.id, data)) return false;
                  if (_filter == 'proximos') {
                    if (!_isAttentionOrder(data)) return false;
                  } else if (!_showOnlyCashClosureOrders ||
                      _dateFilter != null ||
                      _deliveryRangeStart != null ||
                      _deliveryRangeEnd != null) {
                    if (!_matchesDate(data)) return false;
                  }
                  final status = _status(data);
                  if (_statusFilter != null && status != _statusFilter) {
                    return false;
                  }
                  if (_filter == 'pendiente' && status != 'pendiente') {
                    return false;
                  }
                  if (_filter == 'entregado' && status != 'entregado') {
                    return false;
                  }
                  if (_filter == 'saldo' && !_hasBalance(data)) {
                    return false;
                  }
                  return true;
                }).toList()
                  ..sort((a, b) {
                    final da = _date(a.data()['order_date']);
                    final db = _date(b.data()['order_date']);
                    if (da == null && db == null) return 0;
                    if (da == null) return 1;
                    if (db == null) return -1;
                    return db.compareTo(da);
                  });
                final total = orders.length;
                final totalPages =
                    total == 0 ? 1 : (total / _pageSize).ceil();
                if (_page >= totalPages) {
                  _page = totalPages - 1;
                }
                final start = _page * _pageSize;
                final end = start + _pageSize > total
                    ? total
                    : start + _pageSize;
                final pageOrders = orders.sublist(start, end);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
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
                          if (pageOrders.isEmpty)
                            _emptyOrders()
                          else
                            ...pageOrders.map(_orderCard),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 12 : 24,
                        8,
                        isMobile ? 12 : 24,
                        14,
                      ),
                      child: _pagination(
                        total,
                        totalPages,
                        start,
                        end,
                      ),
                    ),
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

class _PressableOrderCard extends StatefulWidget {
  const _PressableOrderCard({
    required this.onTap,
    required this.child,
  });
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_PressableOrderCard> createState() =>
      _PressableOrderCardState();
}

class _PressableOrderCardState extends State<_PressableOrderCard> {
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
