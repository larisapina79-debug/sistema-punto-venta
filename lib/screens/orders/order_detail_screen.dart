import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';
import 'ticket_order_screen.dart';

const Color _teal = Color(0xFF63B7C4);
const Color _green = Color(0xFF0F6B1F);
const Color _red = Color(0xFFF4512A);
const Color _orange = Color(0xFFE65100);
const Color _textDark = Color(0xFF212121);
const Color _muted = Color(0xFF757575);
const Color _border = Color(0xFFBDBDBD);
const Color _fieldBg = Color(0xFFF7F8F9);

final ButtonStyle _cancelStyle = OutlinedButton.styleFrom(
  foregroundColor: _red,
  backgroundColor: Colors.white,
  side: const BorderSide(color: _red, width: 1.5),
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
);

final ButtonStyle _acceptStyle = OutlinedButton.styleFrom(
  foregroundColor: Colors.black,
  backgroundColor: _teal.withValues(alpha: 0.12),
  side: const BorderSide(color: _teal, width: 1.5),
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
);

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String currentUserId;
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.currentUserId = '',
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _selectedPayments = [];
  final List<Map<String, dynamic>> _availablePaymentMethods = [];
  final TextEditingController _paymentMethodSearchController =  TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _registeringPayment = false;
  bool _showPaymentMethods = false;
  bool _loadingPaymentMethods = true;
  String _paymentMethodQuery = '';
  String _currentUserName = '';
  Map<String, dynamic> _order = {};
  String _resolvedBranchName = '';
  DateTime? _deliveryDate;
  OverlayEntry? _activeMessage;
  String get _userId {
    final id = (Session.user?.idUser ?? '').toString().trim();
    return id.isNotEmpty ? id : widget.currentUserId.trim();
  }
  bool get _isClosed =>  _status == 'cancelado' || _status == 'entregado';
  String _text(dynamic value) => value?.toString().trim() ?? '';
  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          _text(value).replaceAll(',', ''),
        ) ??
        0;
  }
  String _formatThousands(String value) {
    final parts = value.split('.');
    final integerPart = parts.first;
    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    if (parts.length > 1) {
      return '$formattedInteger.${parts.sublist(1).join('.')}';
    }
    return formattedInteger;
  }
  String _money(dynamic value) {
    final d = _number(value);
    if (!d.isFinite) return '\$0.00';
    return '\$${_formatThousands(d.toStringAsFixed(2))}';
  }
  String _qty(double value) {
    if (!value.isFinite) return '0';
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return _formatThousands(text);
  }
  double _parseAmount(String? value) {
    return double.tryParse(
          (value ?? '')
              .trim()
              .replaceAll(',', '')
              .replaceAll(' ', ''),
        ) ??
        0;
  }
  String _paymentAmountText(double amount) =>
      _formatThousands(amount.clamp(0.0, double.infinity).toStringAsFixed(2));
  TextInputFormatter get _paymentAmountFormatter =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        final raw = newValue.text.replaceAll(',', '');
        if (raw.isEmpty) return newValue;
        if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(raw)) {
          return oldValue;
        }
        final beforeCursor = newValue.text.substring(
          0,
          newValue.selection.baseOffset.clamp(0, newValue.text.length),
        ).replaceAll(',', '');
        final formatted = _formatThousands(raw);
        var cursor = 0;
        var digitsSeen = 0;
        while (cursor < formatted.length &&
            digitsSeen < beforeCursor.length) {
          if (formatted[cursor] != ',') digitsSeen++;
          cursor++;
        }
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: cursor),
        );
      });
  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
  DateTime _dayOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
  String get _status {
    final value = _text(_order['order_status']).toLowerCase();
    return value.isEmpty ? 'pendiente' : value;
  }
  double get _total => _number(_order['total_order']);
  double get _paid => _number(_order['paid_amount']);
  double get _balance {
    if (_status == 'entregado') return 0;
    final stored = _number(_order['balance_due']);
    if (stored > 0) return stored;
    return (_total - _paid)
        .clamp(0.0, double.infinity)
        .toDouble();
  }
  bool get _isFullyPaid =>
      _text(_order['payment_status']).toLowerCase() == 'pagado' ||
      (_total > 0 && _balance <= 0.009);
  String get _clientName {
    final name = _text(_order['client_name']);
    return name.isEmpty ? 'Cliente sin nombre' : name;
  }
  String get _branchName {
    if (_resolvedBranchName.isNotEmpty) {
      return _resolvedBranchName;
    }
    final branch = _order['id_branches'];
    if (branch is Map) {
      final name = _text(
        branch['branch_name'] ??
            branch['name_branch'] ??
            branch['name'] ??
            branch['branchName'],
      );
      if (name.isNotEmpty) return name;
    }
    if (branch is DocumentReference) return branch.id;
    return _text(branch).isEmpty ? '—' : _text(branch);
  }
  double get _enteredPayment {
    return _selectedPayments.fold<double>(
      0,
      (total, payment) {
        return total +
            _parseAmount(
              (payment['controller'] as TextEditingController).text,
            );
      },
    );
  }

  List<Map<String, dynamic>> get _initialPayments {
    final candidates = [
      _order['initial_payment_methods'],
      _order['payment_method'],
      _order['payment_form'],
      _order['payment_type'],
      _order['forma_pago'],
      _order['payment'],
    ];
    for (final value in candidates) {
      if (value is List) {
        final payments = value.whereType<Map>().map((payment) {
          return <String, dynamic>{
            'id_payment_methods': _text(
              payment['id_payment_methods'] ?? payment['id'],
            ),
            'name': _text(
              payment['payment_methods_name'] ??
                  payment['name'] ??
                  payment['payment_method'],
            ),
            'amount': _number(payment['amount']),
          };
        }).where((payment) {
          return _text(payment['name']).isNotEmpty;
        }).toList();
        if (payments.isNotEmpty) return payments;
      }
      if (value is Map) {
        final name = _text(
          value['payment_methods_name'] ??
              value['name'] ??
              value['payment_method'],
        );
        if (name.isNotEmpty) {
          return [
            {
              'id_payment_methods': _text(
                value['id_payment_methods'],
              ),
              'name': name,
              'amount': _number(value['amount']),
            }
          ];
        }
      }
      if (_text(value).isNotEmpty) {
        return [
          {
            'id_payment_methods': '',
            'name': _text(value),
            'amount': _number(
              _order['initial_payment_amount'] ??
                  _order['advance_amount'] ??
                  _order['anticipo'],
            ),
          }
        ];
      }
    }
    final legacyAmount = _number(
      _order['initial_payment_amount'] ??
          _order['advance_amount'] ??
          _order['anticipo'],
    );
    if (legacyAmount > 0) {
      return [
        {
          'id_payment_methods': '',
          'name': 'Forma de pago anterior',
          'amount': legacyAmount,
        }
      ];
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _loadPaymentMethods();
    _loadCurrentUserName();
  }

  void _loadCurrentUserName() {
    try {
      final dynamic user = Session.user;
      _currentUserName = (user?.nameUser ?? '').toString();
    } catch (_) {
      _currentUserName = '';
    }
  }

  @override
  void dispose() {
    _activeMessage?.remove();
    _activeMessage?.dispose();
    _activeMessage = null;
    _scrollController.dispose();
    _paymentMethodSearchController.dispose();
    for (final payment in _selectedPayments) {
      (payment['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }
  void _message(String message, {bool isError = false}) {
    if (!mounted) return;
    _activeMessage?.remove();
    _activeMessage?.dispose();
    _activeMessage = null;
    final color = isError
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);
    final background = isError
        ? const Color(0xFFFDECEA)
        : const Color(0xFFE8F5E9);
    final border = isError
        ? const Color(0xFFF5B5AE)
        : const Color(0xFFA5D6A7);
    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 16,
        left: 16,
        right: 16,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(color: border, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
    _activeMessage = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (_activeMessage == entry) {
        entry.remove();
        entry.dispose();
        _activeMessage = null;
      }
    });
  }

  Future<void> _resolveBranchName(dynamic branchValue) async {
    String branchId = '';
    if (branchValue is DocumentReference) {
      branchId = branchValue.id;
      try {
        final snapshot = await branchValue.get();
        final data = snapshot.data();
        if (data is Map<String, dynamic>) {
          final name = _text(
            data['branch_name'] ??
                data['name_branch'] ??
                data['name'] ??
                data['branchName'],
          );
          if (name.isNotEmpty && mounted) {
            setState(() => _resolvedBranchName = name);
            return;
          }
        }
      } catch (e) {
        debugPrint(
          'No se pudo consultar la referencia de sucursal: $e',
        );
      }
    } else if (branchValue is Map) {
      final directName = _text(
        branchValue['branch_name'] ??
            branchValue['name_branch'] ??
            branchValue['name'] ??
            branchValue['branchName'],
      );
      if (directName.isNotEmpty) {
        if (mounted) {
          setState(() => _resolvedBranchName = directName);
        }
        return;
      }
      branchId = _text(
        branchValue['id_branches'] ?? branchValue['id'],
      );
    } else {
      branchId = _text(branchValue);
    }
    if (branchId.isEmpty) return;
    try {
      final snapshot =
          await _db.collection('branches').doc(branchId).get();
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? <String, dynamic>{};
      final name = _text(
        data['branch_name'] ??
            data['name_branch'] ??
            data['name'] ??
            data['branchName'],
      );
      if (name.isNotEmpty && mounted) {
        setState(() => _resolvedBranchName = name);
      }
    } catch (e) {
      debugPrint(
        'Error al consultar el nombre de la sucursal: $e',
      );
    }
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final snapshot =
          await _db.collection('payment_methods').get();
      final methods = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        return <String, dynamic>{
          ...data,
          'id_payment_methods':
              (data['id_payment_methods'] ?? doc.id).toString(),
          '_doc_id': doc.id,
          'payment_methods_name':
              (data['payment_methods_name'] ?? '')
                  .toString()
                  .trim(),
        };
      }).where((method) {
        return (method['payment_methods_name'] as String).isNotEmpty;
      }).toList()
        ..sort((a, b) {
          return (a['payment_methods_name'] as String)
              .toLowerCase()
              .compareTo(
                (b['payment_methods_name'] as String)
                    .toLowerCase(),
              );
        });
      if (!mounted) return;
      setState(() {
        _availablePaymentMethods
          ..clear()
          ..addAll(methods);
        _loadingPaymentMethods = false;
      });
    } catch (e) {
      debugPrint('Error al cargar formas de pago: $e');
      if (!mounted) return;
      setState(() => _loadingPaymentMethods = false);
      _message(
        'No se pudieron cargar las formas de pago.',
        isError: true,
      );
    }
  }

  Future<void> _loadOrder() async {
    try {
      final doc =
          await _db.collection('orders').doc(widget.orderId).get();
      if (!doc.exists) {
        if (!mounted) return;
        setState(() => _loading = false);
        _message(
          'No se encontró el pedido.',
          isError: true,
        );
        return;
      }
      final data = doc.data() ?? <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _order = data;
        _deliveryDate = _date(data['delivery_date']);
        _loading = false;
      });
      await _resolveBranchName(data['id_branches']);
    } catch (e) {
      debugPrint('Error al cargar pedido: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _message(
        'No se pudo cargar la información del pedido.',
        isError: true,
      );
    }
  }

  String? _paymentMethodName(String id) {
    for (final method in _availablePaymentMethods) {
      if (method['id_payment_methods'].toString() == id) {
        return method['payment_methods_name'].toString();
      }
    }
    return null;
  }
  void _togglePaymentMethod(String id) {
    if (_registeringPayment) return;
    final index = _selectedPayments.indexWhere(
      (payment) => payment['id'] == id,
    );
    if (index >= 0) {
      _removePaymentMethod(index);
      return;
    }
    setState(() {
      _selectedPayments.add({
        'id': id,
        'controller': TextEditingController(
          text: '0.00',
        ),
      });
      _paymentMethodQuery = '';
      _paymentMethodSearchController.clear();
    });
  }

  void _removePaymentMethod(int index) {
    if (_registeringPayment ||
        index < 0 ||
        index >= _selectedPayments.length) {
      return;
    }
    final payment = _selectedPayments.removeAt(index);
    (payment['controller'] as TextEditingController).dispose();
    setState(() {});
  }

  List<Map<String, dynamic>> _paymentPayload() {
    return _selectedPayments.map((payment) {
      final id = payment['id'].toString();
      final amount = _parseAmount(
        (payment['controller'] as TextEditingController).text,
      );
      return <String, dynamic>{
        'id_payment_methods': id,
        'payment_methods_name':
            _paymentMethodName(id) ?? 'Forma de pago',
        'amount': double.parse(amount.toStringAsFixed(2)),
      };
    }).where((payment) {
      return (payment['amount'] as double) > 0;
    }).toList();
  }

  Widget _paymentMethodSelector() {
    final filteredMethods = _availablePaymentMethods.where((method) {
      final name = (method['payment_methods_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return name.contains(_paymentMethodQuery);
    }).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFC),
        border: Border.all(color: _border),
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
              _selectedPayments.isEmpty
                  ? 'Selecciona una o varias formas de pago'
                  : '${_selectedPayments.length} forma(s) agregada(s)',
              style: const TextStyle(
                color: _teal,
                fontSize: 13,
              ),
            ),
            trailing: Icon(
              _showPaymentMethods
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: _teal,
            ),
            onTap: _registeringPayment
                ? null
                : () {
                    setState(() {
                      _showPaymentMethods = !_showPaymentMethods;
                      if (!_showPaymentMethods) {
                        _paymentMethodQuery = '';
                        _paymentMethodSearchController.clear();
                      }
                    });
                  },
          ),
          if (_showPaymentMethods) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: TextField(
                controller: _paymentMethodSearchController,
                enabled: !_registeringPayment,
                onChanged: (value) {
                  setState(() {
                    _paymentMethodQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar forma de pago...',
                  prefixIcon: const Icon(Icons.search, color: _teal),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _teal, width: 1.5),
                  ),
                ),
              ),
            ),
            if (_loadingPaymentMethods)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: CircularProgressIndicator(color: _teal),
                ),
              )
            else if (filteredMethods.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay formas de pago registradas que coincidan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              )
            else
              ...filteredMethods.map((method) {
                final id = method['id_payment_methods'].toString();
                final name = method['payment_methods_name'].toString();
                final selected = _selectedPayments.any(
                  (payment) => payment['id'].toString() == id,
                );
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
                    color: selected ? _teal : Colors.white,
                    border: selected
                        ? null
                        : Border.all(
                            color:_border,
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
                    name,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 15,
                    ),
                  ),
                  onTap: _registeringPayment
                      ? null
                      : () => _togglePaymentMethod(id),
                );
              }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
 
  Future<void> _registerPayment() async {
    if (_registeringPayment) return;
    if (_isClosed) {
      _message(
        'No se pueden registrar pagos en este pedido.',
        isError: true,
      );
      return;
    }
    if (_balance <= 0) {
      _message('Este pedido ya está liquidado.');
      return;
    }
    if (_userId.isEmpty) {
      _message(
        'No se identificó al usuario que registra el abono.',
        isError: true,
      );
      return;
    }
    if (_selectedPayments.isEmpty) {
      _message(
        'Selecciona al menos una forma de pago.',
        isError: true,
      );
      return;
    }
    for (final payment in _selectedPayments) {
      final value = _parseAmount(
        (payment['controller'] as TextEditingController).text,
      );
      if (!value.isFinite || value <= 0) {
        _message(
          'Ingresa una cantidad mayor a cero en cada forma de pago.',
          isError: true,
        );
        return;
      }
    }
    final paymentDetails = _paymentPayload();
    final amount = paymentDetails.fold<double>(
      0,
      (total, payment) => total + _number(payment['amount']),
    );
    final roundedAmount = double.parse(amount.toStringAsFixed(2));
    if (roundedAmount <= 0 ||
        roundedAmount > _balance + 0.009) {
      _message(
        'La suma de los pagos debe ser mayor a cero y no superar el saldo pendiente.',
        isError: true,
      );
      return;
    }
    setState(() => _registeringPayment = true);
    try {
      final ref = _db.collection('orders').doc(widget.orderId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          throw Exception('El pedido ya no existe.');
        }
        final data = snapshot.data() ?? <String, dynamic>{};
        final total = _number(data['total_order']);
        final paid = _number(data['paid_amount']);
        final storedBalance = _number(data['balance_due']);
        final currentBalance = storedBalance > 0
            ? storedBalance
            : (total - paid)
                .clamp(0.0, double.infinity)
                .toDouble();
        final currentStatus =
            _text(data['order_status']).toLowerCase();
        if (currentStatus == 'cancelado' ||
            currentStatus == 'entregado') {
          throw Exception(
            'No se pueden registrar pagos en este pedido.',
          );
        }
        if (roundedAmount > currentBalance + 0.009) {
          throw Exception(
            'El saldo cambió. Actualiza el pedido e inténtalo de nuevo.',
          );
        }
        final newPaid = double.parse(
          (paid + roundedAmount).toStringAsFixed(2),
        );
        final newBalance = double.parse(
          (currentBalance - roundedAmount)
              .clamp(0.0, double.infinity)
              .toStringAsFixed(2),
        );
        final paymentNames = paymentDetails
            .map((payment) =>
                payment['payment_methods_name'].toString())
            .toSet()
            .join(' + ');
        final oldHistory = data['delivery_payment_history'];
        final history = oldHistory is List
            ? List<dynamic>.from(oldHistory)
            : <dynamic>[];
        history.add({
          'amount': roundedAmount,
          'payment_methods': paymentDetails,
          'registered_by_id': _userId,
          'registered_by_name': _currentUserName,
          'registered_at': Timestamp.now(),
        });
        transaction.update(ref, {
          'paid_amount': newPaid,
          'balance_due': newBalance,
          'delivery_payment': double.parse(
            (_number(data['delivery_payment']) + roundedAmount)
                .toStringAsFixed(2),
          ),
          'delivery_payment_method': paymentNames,
          'delivery_payment_methods': paymentDetails,
          'delivery_payment_history': history,
          'payment_status':
              newBalance <= 0.009 ? 'pagado' : 'pendiente',
          'last_payment_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
      for (final payment in _selectedPayments) {
        (payment['controller'] as TextEditingController).dispose();
      }
      if (!mounted) return;
      setState(() {
        _selectedPayments.clear();
        _showPaymentMethods = false;
        _paymentMethodQuery = '';
        _paymentMethodSearchController.clear();
      });
      await _loadOrder();
      if (!mounted) return;
      setState(() => _registeringPayment = false);
      _message(
        _isFullyPaid
            ? 'Abono registrado. El pedido está completamente pagado.'
            : 'Abono registrado correctamente.',
      );
    } catch (e) {
      debugPrint('Error al registrar abono: $e');
      if (!mounted) return;
      setState(() => _registeringPayment = false);
      _message(
        'No se pudo registrar el abono: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    }
  }

  Future<DateTime?> _showOrderCalendar({
    required DateTime initial,
    required DateTime min,
    required DateTime max,
  }) async {
    DateTime normalize(DateTime date) {
      return DateTime(date.year, date.month, date.day);
    }
    final first = normalize(min);
    final last = normalize(max);
    var start = normalize(initial);
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;
    DateTime selection = start;
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 350,
                child: Theme(
                  data: Theme.of(dialogContext).copyWith(
                    colorScheme:
                        Theme.of(dialogContext).colorScheme.copyWith(
                              primary: _teal,
                              onPrimary: _textDark,
                              surface: Colors.white,
                              onSurface: _textDark,
                            ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: start,
                    firstDate: first,
                    lastDate: last,
                    onDateChanged: (date) {
                      selection = date;
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: _cancelStyle,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(selection);
                        },
                        style: _acceptStyle,
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editDeliveryDate() async {
    if (_saving) return;
    final today = _dayOnly(DateTime.now());
    final selected = await _showOrderCalendar(
      initial: _deliveryDate ?? today,
      min: today,
      max: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    final newDate = _dayOnly(selected);
    if (_deliveryDate != null &&
        _dayOnly(_deliveryDate!) == newDate) {
      return;
    }
    final previousDate = _deliveryDate;
    setState(() {
      _deliveryDate = newDate;
      _saving = true;
    });
    try {
      await _db.collection('orders').doc(widget.orderId).update({
        'delivery_date': Timestamp.fromDate(newDate),
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await _loadOrder();
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Fecha de entrega actualizada correctamente.');
    } catch (e) {
      debugPrint(
        'Error al actualizar la fecha de entrega: $e',
      );
      if (!mounted) return;
      setState(() {
        _deliveryDate = previousDate;
        _saving = false;
      });
      _message(
        'No se pudo actualizar la fecha de entrega.',
        isError: true,
      );
    }
  }

  Widget _sectionTitle(
    String title, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: _teal, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
        ),
      ),
      child: child,
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                color: valueColor ?? _textDark,
                fontSize: 14,
                fontWeight: emphasize
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha de entrega',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: _saving ? null : _editDeliveryDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: _teal,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatDate(_deliveryDate),
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _teal,
                    ),
                  )
                else
                  const Icon(
                    Icons.edit_outlined,
                    color: _muted,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _generalInformation() {
    return _infoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Información general',
          ),
          _detailRow('Cliente', _clientName),
          _detailRow(
            'Teléfono',
            _text(_order['client_phone']),
          ),
          _detailRow('Sucursal', _branchName),
          _detailRow(
            'Fecha del pedido',
            _formatDate(_date(_order['order_date'])),
          ),
          _deliveryDateField(),
          const SizedBox(height: 8),
          _detailRow(
            'Observaciones',
            _text(_order['observations_order']),
          ),
        ],
      ),
    );
  }

  Widget _productsSection() {
    final products = (_order['products'] as List?) ?? const [];
    return _infoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Productos',
          ),
          if (products.isEmpty)
            const Text(
              'Este pedido no tiene productos registrados.',
              style: TextStyle(color: _muted),
            ),
          ...products.map((product) {
            final item = product is Map ? product : const {};
            final name = _text(item['name_product']);
            final quantity = _number(item['quantity_product']);
            final unitPrice = _number(item['unitPrice_product']);
            final subtotal = _number(item['total_detailSale']);
            final saleType = _text(item['sale_type_name']);
            final description = _text(item['description_product']);
            final isCustom =item['is_custom_order_product'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: const Color(0xFFE8E8E8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty
                              ? 'Producto sin nombre'
                              : name,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_qty(quantity)} '
                          '${saleType.isEmpty ? '' : '$saleType '}'
                          'x ${_money(unitPrice)}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                          ),
                        ),
                        if (isCustom)
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Text(
                              'Producto especial por pedido',
                              style: TextStyle(
                                color: _teal,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              description,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(subtotal),
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _selectedPaymentCards() {
    if (_selectedPayments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Anticipo',
          style: TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_selectedPayments.length, (index) {
          final payment = _selectedPayments[index];
          final id = payment['id'].toString();
          final name = _paymentMethodName(id) ?? 'Forma de pago';
          final controller = payment['controller'] as TextEditingController;
          void changeAmount(double delta) {
            if (_registeringPayment) return;
            final current = _parseAmount(controller.text);
            final next = (current + delta).clamp(0.0, double.infinity);
            controller.text = _paymentAmountText(next.toDouble());
            controller.selection = TextSelection.collapsed(
              offset: controller.text.length,
            );
            setState(() {});
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar forma de pago',
                      onPressed: _registeringPayment
                          ? null
                          : () => _removePaymentMethod(index),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: _red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'Cantidad recibida',
                  style: TextStyle(color: _textDark, fontSize: 14),
                ),
                const SizedBox(height: 9),
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      final amount = _parseAmount(controller.text);
                      controller.text = _paymentAmountText(amount);
                      setState(() {});
                    }
                  },
                  child: TextField(
                  controller: controller,
                  enabled: !_registeringPayment,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    _paymentAmountFormatter,
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: r'$ ',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 17,
                    ),
                    suffixIcon: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _registeringPayment
                              ? null
                              : () => changeAmount(1),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: _teal,
                            size: 20,
                          ),
                        ),
                        InkWell(
                          onTap: _registeringPayment
                              ? null
                              : () => changeAmount(-1),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _teal,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: _teal, width: 1.5),
                    ),
                  ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _paymentBreakdown(
    String title,
    double amount,
    List<Map<String, dynamic>> methods,
  ) {
    final visibleMethods = methods.where(
      (method) => _number(method['amount']) > 0,
    ).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            color: _textDark, fontSize: 14, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 8),
          Text('Importe: ${_money(amount)}', style: const TextStyle(
            color: _textDark, fontSize: 14,
          )),
          if (visibleMethods.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Forma de pago:', style: TextStyle(
              color: _textDark, fontSize: 14,
            )),
            ...visibleMethods.map((method) {
              final name = _text(method['name']);
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${name.isEmpty ? 'Forma de pago no especificada' : name} '
                  '${_money(method['amount'])}',
                  style: const TextStyle(color: _textDark, fontSize: 14),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _paymentSection() {
    final balance = _balance;
    final hasBalance = balance > 0.009 && !_isClosed;
    final initialPayments = _initialPayments;
    final initialAmount = _number(
      _order['initial_payment_amount'] ??
          _order['advance_amount'] ??
          _order['anticipo'],
    );
    final initialMethodsTotal = initialPayments.fold<double>(
      0.0,
      (acumulado, item) => acumulado + _number(item['amount']),
    );
    final advanceAmount = initialAmount > 0 ? initialAmount : initialMethodsTotal;
    final laterPayments = <Map<String, dynamic>>[];
    final history = _order['delivery_payment_history'];
    if (history is List && history.isNotEmpty) {
      for (final entry in history.whereType<Map>()) {
        final methods = entry['payment_methods'];
        if (methods is List && methods.isNotEmpty) {
          for (final method in methods.whereType<Map>()) {
            final amount = _number(method['amount']);
            if (amount > 0) {
              laterPayments.add({
                'name': _text(method['payment_methods_name'] ?? method['name']),
                'amount': amount,
              });
            }
          }
        } else {
          final amount = _number(entry['amount']);
          if (amount > 0) {
            laterPayments.add({'name': 'Forma de pago no especificada', 'amount': amount});
          }
        }
      }
    } else {
      final legacyAmount = _number(_order['delivery_payment']);
      if (legacyAmount > 0) {
        final legacyMethods = _order['delivery_payment_methods'];
        if (legacyMethods is List && legacyMethods.isNotEmpty) {
          for (final method in legacyMethods.whereType<Map>()) {
            final amount = _number(method['amount']);
            if (amount > 0) {
              laterPayments.add({
                'name': _text(method['payment_methods_name'] ?? method['name']),
                'amount': amount,
              });
            }
          }
        }
        if (laterPayments.isEmpty) {
          laterPayments.add({
            'name': _text(_order['delivery_payment_method']).isEmpty
                ? 'Forma de pago no especificada'
                : _text(_order['delivery_payment_method']),
            'amount': legacyAmount,
          });
        }
      }
    }
    final laterAmount = laterPayments.fold<double>(
      0.0,
    (acumulado, item) => acumulado + _number(item['amount']),
    );
    final hasLaterPayments = laterAmount > 0.009;
    return _infoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Resumen de pago',
          ),
          _detailRow('Total del pedido', _money(_total)),
          const SizedBox(height: 12),
          if (advanceAmount > 0 || initialPayments.isNotEmpty) ...[
            _paymentBreakdown('ANTICIPO', advanceAmount, initialPayments),
            const SizedBox(height: 10),
          ],
          if (hasLaterPayments && _isFullyPaid) ...[
            _paymentBreakdown(
              'LIQUIDACIÓN',
              laterAmount,
              laterPayments,
            ),
            const SizedBox(height: 10),
          ],
          const Divider(height: 22),
          const Divider(
            height: 22,
            color: Color(0xFFEEEEEE),
          ),
          if (hasBalance) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),
            _sectionTitle(
              'Liquidación',
            ),
            _paymentMethodSelector(),
            _selectedPaymentCards(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  _detailRow(
                    'Total de este abono',
                    _money(_enteredPayment),
                    valueColor: _green,
                  ),
                  const Divider(
                    color: Color(0xFFEEEEEE),
                  ),
                  _detailRow(
                    'Faltante por entregar',
                    _money(
                      (balance - _enteredPayment)
                          .clamp(0.0, double.infinity),
                    ),
                    valueColor:
                        (balance - _enteredPayment) > 0.009
                            ? _red
                            : _green,
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: OutlinedButton.icon(
                onPressed: _registeringPayment
                    ? null
                    : _registerPayment,
                icon: _registeringPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _green,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline_rounded,
                      ),
                label: const Text('Liquidación'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textDark,
                  backgroundColor: const Color(0xFFDCE7E9),
                  side: const BorderSide(
                    color: _teal,
                    width: 1.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: _status == 'cancelado'
                    ? const Color(0xFFFDECEA)
                    : const Color(0xFFEAF7F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _status == 'cancelado'
                      ? const Color(0xFFF5B5AE)
                      : const Color(0xFFB7E4D3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _status == 'cancelado'
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline_rounded,
                    color: _status == 'cancelado'
                        ? const Color(0xFFC62828)
                        : const Color(0xFF009E79),
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _status == 'cancelado'
                          ? 'Este pedido está cancelado.'
                          : _status == 'entregado'
                              ? 'Este pedido ya fue entregado.'
                              : _isFullyPaid
                                  ? 'El pedido está completamente pagado.'
                                  : 'El pedido no tiene saldo pendiente.',
                      style: TextStyle(
                        color: _status == 'cancelado'
                            ? const Color(0xFFC62828)
                            : const Color(0xFF009E79),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  List<Widget> _statusChips() {
    if (_status == 'cancelado') {
      return [
        _statusChip('Cancelado', _red),
      ];
    }
    return [
      _statusChip(
        _isFullyPaid ? 'Pagado' : 'Pago pendiente',
        _isFullyPaid ? _green : _orange,
      ),
      _statusChip(
        _status == 'entregado'
            ? 'Entregado'
            : 'Pendiente de entrega',
        _status == 'entregado' ? _green : _orange,
      ),
    ];
  }

  Widget _header() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _saving
                ? null
                : () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: _teal,
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
            ),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
            ),
            label: const Text(
              'Regresar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Detalles del pedido',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _clientName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textDark,
            fontSize: 27,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: _statusChips(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 850;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _teal,
                ),
              )
            : _order.isEmpty
                ? const Center(
                    child: Text(
                      'No hay información disponible del pedido.',
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 16 : 30,
                      vertical: 22,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1250,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            _header(),
                            const SizedBox(height: 26),
                            if (mobile) ...[
                              _generalInformation(),
                              const SizedBox(height: 16),
                              _productsSection(),
                              const SizedBox(height: 16),
                              _paymentSection(),
                            ] else
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 11,
                                    child: Column(
                                      children: [
                                        _generalInformation(),
                                        const SizedBox(height: 16),
                                        _productsSection(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 9,
                                    child: _paymentSection(),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            Center(
                              child: SizedBox(
                                width: mobile
                                    ? double.infinity
                                    : 320,
                                height: 52,
                                child: PrimaryButton(
                                  text: 'Imprimir ticket',
                                  onPressed: () => OrderTicket.show(
                                    context,
                                    orderId: widget.orderId,
                                    order: _order,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }