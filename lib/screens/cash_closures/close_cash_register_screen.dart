import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/cash_closure_model.dart';
import '../../services/auth_service.dart';
import '../../services/cash_closure_service.dart';
import '../../widgets/app_header.dart';

const Color _kGreen = Color.fromARGB(255, 99, 183, 196);
const Color _kGreenDark = Color.fromARGB(255, 99, 183, 196);
const Color _kBackground = Colors.white;
const Color _kText = Color(0xFF171717);
const Color _kMuted = Color(0xFF666666);
const Color _kCancel = Color(0xFFFF5722);

ButtonStyle _tealButtonStyle({
  double radius = 12,
  EdgeInsetsGeometry? padding,
  Color disabled = const Color(0xFFECF6F8),
}) {
  return ElevatedButton.styleFrom(
    foregroundColor: Colors.black,
    elevation: 0,
    padding: padding,
    splashFactory: NoSplash.splashFactory,
    side: const BorderSide(color: _kGreen, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    ),
  ).copyWith(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabled;
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)) {
        return const Color(0xFFD9E2E4);
      }
      return const Color(0xFFECF6F8);
    }),
    overlayColor: WidgetStateProperty.all(Colors.transparent),
  );
}

class CloseCashRegisterScreen extends StatefulWidget {
  const CloseCashRegisterScreen({
    super.key,
    this.idClosure = '',
    this.idBranch = '',
    this.idUser = '',
    this.initialCash = 0,
    this.totalSales = 0,
    this.cashSales = 0,
    this.saleCount = 0,
  });
  final String idClosure;
  final String idBranch;
  final String idUser;
  final double initialCash;
  final double totalSales;
  final double cashSales;
  final int saleCount;

  @override
  State<CloseCashRegisterScreen> createState() =>
      _CloseCashRegisterScreenState();
}
class _CloseCashRegisterScreenState
    extends State<CloseCashRegisterScreen> {
  static const List<double> _billDenoms = [
    1000,
    500,
    200,
    100,
    50,
    20,
  ];
  static const List<double> _coinDenoms = [
    10,
    5,
    2,
    1,
    0.5,
  ];
  static const double _contentMaxWidth = 520;
  final CashClosureService _service = CashClosureService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _cashController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final TextEditingController _commentController = TextEditingController();
  final Map<double, int> _counts = {};
  final Map<double, TextEditingController> _countControllers = {};
  CashClosureModel? _closure;
  bool _loading = true;
  bool _saving = false;
  bool _updatingController = false;
  bool _typeTotal = false;
  bool _confirmedCount = false;
  String? _error;
  String _amount = '';
  double? _countedCash;
  double? _liveCashSale;
  int? _liveSaleCount;
  double get _initialCash =>
      _closure?.initialCash ?? widget.initialCash;
  double get _cashSales =>
      _liveCashSale ?? _closure?.cashSale ?? widget.cashSales;
  int get _saleCount =>
      _liveSaleCount ?? _closure?.saleCount ?? widget.saleCount;
  double get _expectedCash => _initialCash + _cashSales;
  double get _denomTotal => _counts.entries.fold(
        0.0,
        (total, entry) => total + entry.key * entry.value,
      );
  double get _counted =>
      _typeTotal ? (_countedCash ?? 0) : _denomTotal;

  @override
  void initState() {
    super.initState();
    for (final denomination in [..._billDenoms, ..._coinDenoms]) {
      _counts[denomination] = 0;
      _countControllers[denomination] =
          TextEditingController(text: '0');
    }
    _amountFocusNode.addListener(_onAmountFocusChanged);
    _loadCashData();
  }
  void _onAmountFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cashController.dispose();
    _commentController.dispose();
    _amountFocusNode.removeListener(_onAmountFocusChanged);
    _amountFocusNode.dispose();
    for (final controller in _countControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCashData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _closure = null;
        _liveCashSale = null;
        _liveSaleCount = null;
      });
    }
    try {
      CashClosureModel? result;
      final id = widget.idClosure.trim();
      if (id.isNotEmpty) {
        result = await _service.getCashClosureById(id);
      } else {
        final snapshot = await _db
            .collection('cash_closures')
            .where('status_closing', isEqualTo: false)
            .get();
        final documents = snapshot.docs.where((doc) {
          final data = doc.data();
          final branch =
              (data['id_branch'] ?? '').toString().trim();
          final user =
              (data['id_users'] ?? data['id_user'] ?? '')
                  .toString()
                  .trim();
          final branchMatches =
              widget.idBranch.trim().isEmpty ||
                  branch == widget.idBranch.trim();
          final userMatches =
              widget.idUser.trim().isEmpty ||
                  user == widget.idUser.trim();
          return branchMatches && userMatches;
        }).toList();
        if (documents.isNotEmpty) {
          documents.sort((a, b) {
            final aDate = a.data()['opening_date'];
            final bDate = b.data()['opening_date'];
            final aTime = aDate is Timestamp
                ? aDate.millisecondsSinceEpoch
                : 0;
            final bTime = bDate is Timestamp
                ? bDate.millisecondsSinceEpoch
                : 0;
            return bTime.compareTo(aTime);
          });
          result = CashClosureModel.fromFirestore(documents.first);
        }
      }
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = idIsNotEmpty()
              ? 'No se encontró el documento de la caja indicado.'
              : 'No hay cajas abiertas que coincidan con los filtros. '
                  'Verifica que exista una caja con status_closing = false.';
          _loading = false;
        });
        return;
      }
      final loaded = result;
      Map<String, dynamic>? summary;
      if (!loaded.statusClosing) {
        summary =
            await _service.calculateSalesSummary(loaded.idClosure);
      }
      if (!mounted) return;
      setState(() {
        _closure = loaded;
        if (summary != null) {
          _liveCashSale =
              (summary['cash_sale'] as num).toDouble();
          _liveSaleCount =
              (summary['sale_count'] as num).toInt();
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al consultar Firestore: $e';
        _loading = false;
      });
    }
  }
  bool idIsNotEmpty() => widget.idClosure.trim().isNotEmpty;
  double? _parseCash(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) return null;
    final amount = double.tryParse(normalized);
    if (amount == null || !amount.isFinite || amount < 0) {
      return null;
    }
    return amount;
  }

  String _formatInputValue(String value) {
    final cleanValue = value.replaceAll(',', '');
    if (cleanValue.isEmpty) return '';
    final parts = cleanValue.split('.');
    String integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;
    if (integerPart.isEmpty) integerPart = '0';
    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    if (decimalPart != null) {
      return '$formattedInteger.$decimalPart';
    }
    return formattedInteger;
  }

  void _restoreController() {
    final formatted = _formatInputValue(_amount);
    _updatingController = true;
    _cashController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
    _updatingController = false;
  }

  void _updateAmount(String value, {int? cursorPosition}) {
    final cleanValue = value.replaceAll(',', '');
    if (cleanValue.isEmpty) {
      setState(() {
        _amount = '';
        _countedCash = null;
      });
      if (_cashController.text.isNotEmpty) {
        _updatingController = true;
        _cashController.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
        _updatingController = false;
      }
      return;
    }
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(cleanValue)) {
      _restoreController();
      return;
    }
    if (cleanValue.split('.').first.length > 9) {
      _restoreController();
      return;
    }
    setState(() {
      _amount = cleanValue;
      _countedCash = _parseCash(cleanValue);
    });
    final rawCursor = cursorPosition ?? cleanValue.length;
    final cursorBefore = cleanValue.substring(
      0,
      rawCursor.clamp(0, cleanValue.length),
    );
    final formattedBeforeCursor =
        _formatInputValue(cursorBefore);
    final formatted = _formatInputValue(cleanValue);
    _updatingController = true;
    _cashController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formattedBeforeCursor.length.clamp(
          0,
          formatted.length,
        ),
      ),
    );
    _updatingController = false;
  }

  void _onAmountChanged(String value) {
    if (_updatingController) return;
    final cursor = _cashController.selection.baseOffset;
    int rawCursor = cursor;
    if (cursor > 0) {
      final beforeCursor = value.substring(
        0,
        cursor.clamp(0, value.length),
      );
      rawCursor = beforeCursor.replaceAll(',', '').length;
    }

    _updateAmount(
      value.replaceAll(',', ''),
      cursorPosition: rawCursor,
    );
  }

  void _setCount(double denomination, int value) {
    setState(() => _counts[denomination] = value);
    final text = value.toString();
    final controller = _countControllers[denomination]!;
    if (controller.text != text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: text.length,
        ),
      );
    }
  }

  void _changeCount(double denomination, int delta) {
    final next = ((_counts[denomination] ?? 0) + delta)
        .clamp(0, 99999)
        .toInt();
    _setCount(denomination, next);
  }

  void _onCountTyped(double denomination, String text) {
    final value = int.tryParse(text) ?? 0;
    setState(() => _counts[denomination] = value);
  }

  String _denomLabel(double denomination) {
    return denomination >= 1
        ? '\$${_formatInputValue(denomination.toInt().toString())}'
        : '\$${denomination.toStringAsFixed(2)}';
  }

  void _goToSummary() {
    FocusScope.of(context).unfocus();
    if (_typeTotal && _countedCash == null) {
      _showTopAlert(
        message: 'Ingresa el efectivo contado para continuar.',
        icon: Icons.attach_money_rounded,
      );
      _amountFocusNode.requestFocus();
      return;
    }
    setState(() => _confirmedCount = true);
  }

  void _showTopAlert({
    required String message,
    IconData? icon,
    bool success = false,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    final bgColor =
        success ? const Color(0xFFE8F5E9) : const Color(0xFFFDECEA);
    final borderColor =
        success ? const Color(0xFFA5D6A7) : const Color(0xFFF5B5B0);
    final contentColor =
        success ? const Color(0xFF1B5E20) : const Color(0xFFB3261E);
    final alertIcon =
        icon ?? (success ? Icons.check_circle : Icons.error);
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 18,
        left: 20,
        right: 20,
        child: SafeArea(
          child: Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              tween: Tween<double>(begin: -20, end: 0),
              builder: (context, value, child) => Transform.translate(
                offset: Offset(0, value),
                child: child,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        alertIcon,
                        color: contentColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: contentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
      ),
    );
    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> _showCloseConfirmation() async {
  if (_saving) return;
  final now = DateTime.now();
  final difference = _counted - _expectedCash;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: !_saving,
    builder: (dialogContext) {
      final isMobile =
          MediaQuery.of(dialogContext).size.width < 500;
      Widget infoTile(
        String label,
        String value, {
        Color? valueColor,
      }) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: valueColor ?? _kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 12,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 40,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '¿Cerrar caja?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _kText,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verifica los datos antes de continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                infoTile('Fecha', _formatDateOnly(now)),
                const SizedBox(height: 12),
                infoTile('Hora', _formatTime(now)),
                const SizedBox(height: 12),
                infoTile(
                  'Efectivo contado',
                  _money(_counted),
                  valueColor: _kGreenDark,
                ),
                const SizedBox(height: 12),
                infoTile(
                  'Diferencia',
                  _money(difference),
                  valueColor: difference < 0
                      ? const Color(0xFFC62828)
                      : _kGreenDark,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: ButtonStyle(
                            foregroundColor:
                                const WidgetStatePropertyAll(_kCancel),
                            overlayColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
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
                              final pressed =
                                  states.contains(WidgetState.pressed);
                              return BorderSide(
                                color: pressed
                                    ? _kCancel.withValues(alpha: 0.25)
                                    : _kCancel,
                                width: 1.2,
                              );
                            }),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: _kGreen.withValues(alpha: 0.12),
                            side: const BorderSide(
                              color: _kGreen,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirmar',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
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
  if (confirmed == true && mounted) {
    await _confirmClose();
  }
}

  Future<void> _confirmClose() async {
    if (_saving) return;
    final closure = _closure;
    if (closure == null) {
      _showTopAlert(
        message: 'No hay una caja cargada para cerrar.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (_counted < _expectedCash &&
        _commentController.text.trim().isEmpty) {
      _showTopAlert(
        message: 'Escribe el motivo del faltante de efectivo.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.closeCashRegister(
        idClosure: closure.idClosure,
        recordedCash: _counted,
        closingComment: _counted < _expectedCash
            ? _commentController.text.trim()
            : null,
      );
      if (!mounted) return;
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showTopAlert(
        message: 'No se pudo completar el cierre. '
            '${e.toString().replaceFirst('Exception: ', '')}',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  String _money(double value) {
    final fixed = value.abs().toStringAsFixed(2).split('.');
    final grouped = fixed[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final sign = value < 0 ? '-' : '';
    return '$sign\$$grouped.${fixed[1]}';
  }

  String _formatDate(DateTime date) {
    return '${_formatDateOnly(date)}  ${_formatTime(date)}';
  }

  String _formatDateOnly(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: const AppHeader(currentRoute: '/cierre'),
      drawer: const AppDrawer(currentRoute: '/cierre'),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kGreen),
      );
    }
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kText,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    final closure = _closure!;
    if (closure.statusClosing) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color.fromARGB(255, 16, 220, 105),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta caja ya está cerrada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kText,
                  fontSize: 18,
                ),
              ),
              if (closure.closingDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Fecha de cierre: '
                  '${_formatDate(closure.closingDate!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kMuted),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        final hPad = isMobile ? 20.0 : 35.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            hPad,
            20,
            hPad,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _contentMaxWidth,
              ),
              child: SizedBox(
                width: double.infinity,
                child: _confirmedCount
                    ? _summaryStep()
                    : _countStep(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _title(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF555555),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _countStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'Cierre de caja',
          'Cuenta los billetes y monedas o ingresa directamente el monto.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _cashModeOption(
                  title: 'Contar efectivo',
                  selected: !_typeTotal,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _typeTotal = false);
                  },
                ),
              ),
              Expanded(
                child: _cashModeOption(
                  title: 'Ingresar importe',
                  selected: _typeTotal,
                  onTap: () => setState(() => _typeTotal = true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            border: Border.all(
              color: const Color(0xFFDEDEDE),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Ventas del turno',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_saleCount',
                style: const TextStyle(
                  color: _kText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_typeTotal) ...[
          const Text(
            'Efectivo contado',
            style: TextStyle(
              color: _kText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _amountField(),
        ] else
          _denomSection(),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 380;
            final total = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total contado',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _money(_counted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kGreenDark,
                    fontSize: isNarrow ? 24 : 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
            final button = SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _goToSummary,
                style: _tealButtonStyle(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 12 : 18,
                  ),
                ),
                child: const Text(
                  'Confirmar conteo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  total,
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: button,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: total),
                const SizedBox(width: 12),
                button,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _cashModeOption({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFECF6F8) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        hoverColor: const Color(0xFFD9E2E4),
        highlightColor: const Color(0xFFD9E2E4),
        splashColor: const Color(0xFFD9E2E4),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(color: _kGreen, width: 1.5)
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : _kMuted,
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'Resumen del cierre',
          'Revisa los datos antes de cerrar la caja.',
        ),
        const SizedBox(height: 14),
        _summaryRow('Efectivo inicial', _money(_initialCash)),
        _summaryRow('Ventas en efectivo', _money(_cashSales)),
        _summaryRow('Efectivo esperado', _money(_expectedCash)),
        _summaryRow(
          'Efectivo contado',
          _money(_counted),
          last: true,
        ),
        const SizedBox(height: 16),
        _differenceCard(),
        if (_counted < _expectedCash) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Motivo del faltante',
              hintText: 'Explica por qué falta efectivo...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFBDBDBD),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: _kGreen,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 380;
            final backButton = SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _confirmedCount = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  splashFactory: NoSplash.splashFactory,
                  side: const BorderSide(
                    color: _kGreen,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ).copyWith(
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed) ||
                        states.contains(WidgetState.hovered)) {
                      return const Color(0xFFD9E2E4);
                    }
                    return Colors.white;
                  }),
                  overlayColor:
                      WidgetStateProperty.all(Colors.transparent),
                ),
                child: const Text(
                  'Corregir conteo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
            final closeButton = SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _showCloseConfirmation,
                style: _tealButtonStyle(
                  disabled: Colors.grey.shade400,
                ),
                child: Text(
                  _saving ? 'Cerrando...' : 'Cerrar caja',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: backButton,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: closeButton,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: backButton),
                const SizedBox(width: 12),
                Expanded(child: closeButton),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0xFFE6EBE8),
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _denomSection() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _contentMaxWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _denomCard(
                      'Billetes',
                      _billDenoms,
                      compact: compact,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: _denomCard(
                      'Monedas',
                      _coinDenoms,
                      compact: compact,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _denomCard(
    String title,
    List<double> denominations, {
    required bool compact,
  }) {
    final subtotal = denominations.fold<double>(
      0,
      (total, denomination) =>
          total + denomination * (_counts[denomination] ?? 0),
    );
    final rowHeight = compact ? 44.0 : 40.0;
    final needsAlignmentSpace =
        denominations.length < _billDenoms.length;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        10,
        compact ? 8 : 10,
        8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E8E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _kGreenDark,
              fontSize: 11,
              letterSpacing: 0.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          for (int i = 0; i < denominations.length; i++) ...[
            _denomRow(denominations[i], compact: compact),
            if (i < denominations.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF0F2F1),
              ),
          ],
          if (needsAlignmentSpace) ...[
            for (
              int i = 0;
              i < _billDenoms.length - denominations.length;
              i++
            )
              SizedBox(height: rowHeight + 1),
          ],
          const Divider(
            height: 18,
            thickness: 1,
            color: Color(0xFFDDE2DF),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Subtotal',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  _money(subtotal),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kGreenDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _denomRow(double denomination, {required bool compact}) {
    final count = _counts[denomination] ?? 0;
    final btn = compact ? 28.0 : 36.0;
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(
          icon: Icons.remove_rounded,
          size: btn,
          onTap: count > 0
              ? () => _changeCount(denomination, -1)
              : null,
        ),
        SizedBox(
          width: compact ? 26 : 36,
          child: TextField(
            controller: _countControllers[denomination],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            onTap: () {
              final c = _countControllers[denomination]!;
              c.selection = TextSelection(
                baseOffset: 0,
                extentOffset: c.text.length,
              );
            },
            onChanged: (value) => _onCountTyped(denomination, value),
            style: TextStyle(
              color: const Color(0xFF202522),
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        _stepButton(
          icon: Icons.add_rounded,
          size: btn,
          onTap: () => _changeCount(denomination, 1),
        ),
      ],
    );

    final amountText = Text(
      _money(denomination * count),
      maxLines: 1,
      style: TextStyle(
        color: const Color(0xFF626B66),
        fontSize: compact ? 9 : 10,
        fontWeight: FontWeight.w500,
      ),
    );
    return SizedBox(
      height: compact ? 44 : 40,
      child: Row(
        children: [
          SizedBox(
            width: compact ? 46 : 58,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _denomLabel(denomination),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF202522),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (compact) amountText,
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: controls,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 54,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: amountText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required VoidCallback? onTap,
    double size = 36,
  }) {
    final isDisabled = onTap == null;
    return SizedBox(
      width: size,
      height: size,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(size, size),
          maximumSize: Size(size, size),
          foregroundColor: isDisabled
              ? const Color(0xFFBFC6C2)
              : _kGreenDark,
          side: BorderSide(
            color: isDisabled
                ? const Color(0xFFE0E5E2)
                : const Color(0xFFD5E2DA),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Icon(icon, size: size < 36 ? 16 : 18),
      ),
    );
  }

  Widget _amountField() {
    final focused = _amountFocusNode.hasFocus;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? _kGreen : const Color(0xFFBDBDBD),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Text(
            '\$',
            style: TextStyle(
              color: _kGreen,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _cashController,
              focusNode: _amountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _onAmountChanged,
              enableInteractiveSelection: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9.]'),
                ),
              ],
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Ingresa el efectivo',
                hintStyle: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 15,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_amount.isNotEmpty)
            GestureDetector(
              onTap: () {
                _updateAmount('');
                _amountFocusNode.requestFocus();
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 15),
                child: Icon(
                  Icons.close_rounded,
                  color: _kGreen,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _differenceCard() {
    final difference = _counted - _expectedCash;
    final String title;
    final String message;
    final Color color;
    final Color background;
    final Color borderColor;
    if (difference > 0) {
      title = 'Sobrante de efectivo';
      message = 'Hay más efectivo del esperado en la caja.';
      color = const Color(0xFF237A3B);
      background = const Color(0xFFEFF8F0);
      borderColor = const Color(0xFFB8DEC0);
    } else if (difference < 0) {
      title = 'Faltante de efectivo';
      message = 'Hay menos efectivo del esperado en la caja.';
      color = const Color(0xFFC62828);
      background = const Color(0xFFFFF1F0);
      borderColor = const Color(0xFFF2C2BE);
    } else {
      title = 'Caja exacta';
      message = 'El efectivo contado coincide con el esperado.';
      color = const Color(0xFF237A3B);
      background = const Color(0xFFEFF8F0);
      borderColor = const Color(0xFFB8DEC0);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Diferencia de caja',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(difference),
              style: TextStyle(
                color: color,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
