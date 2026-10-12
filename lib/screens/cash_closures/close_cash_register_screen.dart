import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/cash_closure_model.dart';
import '../../services/auth_service.dart';
import '../../services/cash_closure_service.dart';

const Color _kGreen = Color(0xFF63B7C4);
const Color _kGreenDark = Color(0xFF0F6B1F);
const Color _kBackground = Color(0xFFFFFFFF);
const Color _kText = Color(0xFF171717);
const Color _kMuted = Color(0xFF666666);

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

class _CloseCashRegisterScreenState extends State<CloseCashRegisterScreen> {
  final CashClosureService _service = CashClosureService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _cashController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  Timer? _timer;
  DateTime _now = DateTime.now();
  CashClosureModel? _closure;
  bool _loading = true;
  bool _saving = false;
  bool _updatingController = false;
  String? _error;
  String _amount = '';
  double? _countedCash;
  double? _liveTotalSale;
  double? _liveCashSale;
  int? _liveSaleCount;
  double get _initialCash => _closure?.initialCash ?? widget.initialCash;
  double get _cashSales =>
      _liveCashSale ?? _closure?.cashSale ?? widget.cashSales;
  double get _totalSales =>
      _liveTotalSale ?? _closure?.totalSale ?? widget.totalSales;
  int get _saleCount =>
      _liveSaleCount ?? _closure?.saleCount ?? widget.saleCount;
  double get _expectedCash => _initialCash + _cashSales;
  String get _closeDateText {
    final day = _now.day.toString().padLeft(2, '0');
    final month = _now.month.toString().padLeft(2, '0');
    return '$day/$month/${_now.year}';
  }
  String get _closeTimeText {
    final hour = _now.hour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  void initState() {
    super.initState();
    _loadCashData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cashController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCashData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _closure = null;
        _liveTotalSale = null;
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
          final branch = (data['id_branch'] ?? '').toString().trim();
          final user = (data['id_users'] ?? data['id_user'] ?? '')
              .toString()
              .trim();
          final branchMatches = widget.idBranch.trim().isEmpty ||
              branch == widget.idBranch.trim();
          final userMatches =
              widget.idUser.trim().isEmpty || user == widget.idUser.trim();
          return branchMatches && userMatches;
        }).toList();
        if (documents.isNotEmpty) {
          documents.sort((a, b) {
            final aDate = a.data()['opening_date'];
            final bDate = b.data()['opening_date'];
            final aTime =
                aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
            final bTime =
                bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
            return bTime.compareTo(aTime);
          });
          result = CashClosureModel.fromFirestore(documents.first);
        }
      }
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = widget.idClosure.trim().isNotEmpty
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
        summary = await _service.calculateSalesSummary(loaded.idClosure);
      }
      if (!mounted) return;
      setState(() {
        _closure = loaded;
        if (summary != null) {
          _liveTotalSale = (summary['total_sale'] as num).toDouble();
          _liveCashSale = (summary['cash_sale'] as num).toDouble();
          _liveSaleCount = (summary['sale_count'] as num).toInt();
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
      (match) => ',',
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
      selection: TextSelection.collapsed(offset: formatted.length),
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
    final valid = RegExp(r'^\d*\.?\d{0,2}$');
    if (!valid.hasMatch(cleanValue)) {
      _restoreController();
      return;
    }
    final integerPart = cleanValue.split('.').first;
    if (integerPart.length > 9) {
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
    final formattedBeforeCursor = _formatInputValue(cursorBefore);
    final formatted = _formatInputValue(cleanValue);
    final newCursor = formattedBeforeCursor.length;
    _updatingController = true;
    _cashController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursor.clamp(0, formatted.length),
      ),
    );
    _updatingController = false;
  }

  void _onAmountChanged(String value) {
    if (_updatingController) return;
    final cleanValue = value.replaceAll(',', '');
    final cursor = _cashController.selection.baseOffset;
    int rawCursor = cursor;
    if (cursor > 0) {
      final beforeCursor = value.substring(
        0,
        cursor.clamp(0, value.length),
      );
      rawCursor = beforeCursor.replaceAll(',', '').length;
    }
    _updateAmount(cleanValue, cursorPosition: rawCursor);
  }

  void _onKey(String value) {
    final current = _amount;
    final controllerValue = _cashController.value;
    int cursor = controllerValue.selection.baseOffset;
    final displayText = controllerValue.text;
    if (cursor >= 0 && cursor <= displayText.length) {
      cursor = displayText.substring(0, cursor).replaceAll(',', '').length;
    } else {
      cursor = current.length;
    }
    final selectionEnd = cursor;
    if (value == '⌫') {
      if (current.isEmpty || cursor == 0) return;
      final newValue = current.replaceRange(cursor - 1, cursor, '');
      _updateAmount(
        newValue,
        cursorPosition: cursor - 1,
      );
      return;
    }
    if (value == '.') {
      if (current.contains('.')) return;
      final newValue = current.replaceRange(cursor, selectionEnd, '.');
      _updateAmount(
        newValue,
        cursorPosition: cursor + 1,
      );
      return;
    }
    if (!RegExp(r'^\d$').hasMatch(value)) return;
    final newValue = current.replaceRange(cursor, selectionEnd, value);
    final valid = RegExp(r'^\d*\.?\d{0,2}$');
    if (!valid.hasMatch(newValue)) return;
    if (newValue.split('.').first.length > 9) return;
    _updateAmount(
      newValue,
      cursorPosition: cursor + 1,
    );
  }

  void _showTopAlert({
    required String message,
    IconData? icon,
    bool success = false,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    final Color bgColor = success
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFDECEA);
    final Color borderColor = success
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFF5B5B0);
    final Color contentColor = success
        ? const Color(0xFF1B5E20)
        : const Color(0xFFB3261E);
    final IconData alertIcon =
        icon ?? (success ? Icons.check_circle : Icons.error);
    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 18,
          left: 20,
          right: 20,
          child: SafeArea(
            child: Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                tween: Tween<double>(begin: -20, end: 0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: child,
                  );
                },
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
        );
      },
    );
    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
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
    if (closure.statusClosing) {
      _showTopAlert(
        message: 'Esta caja ya está cerrada.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final cash = _parseCash(_cashController.text);
    if (cash == null) {
      _showTopAlert(
        message: 'Ingresa el efectivo contado para continuar.',
        icon: Icons.attach_money_rounded,
      );
      _amountFocusNode.requestFocus();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Confirmar cierre',
          style: TextStyle(color: _kText),
        ),
        content: Text(
          '¿Estás seguro de cerrar esta caja?\n\n'
          'Efectivo esperado: ${_money(_expectedCash)}\n'
          'Efectivo contado: ${_money(cash)}\n'
          'Diferencia: ${_money(cash - _expectedCash)}',
          style: const TextStyle(color: _kText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreenDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.closeCashRegister(
        idClosure: closure.idClosure,
        recordedCash: cash,
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
      (match) => ',',
    );
    final sign = value < 0 ? '-' : '';
    return '$sign\$$grouped.${fixed[1]}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 1, child: _brandSection()),
                  Expanded(flex: 1, child: _buildBody()),
                ],
              );
            }
            return Column(
              children: [
                _mobileBrandSection(),
                Expanded(child: _buildBody()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _brandSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 28, 25, 28),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Punto ',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'de Venta',
                  style: TextStyle(
                    color: Color(0xFF63B7C4),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu negocio, más cerca de tus clientes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 14,
            ),
          ),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Image(
                  image: AssetImage('assets/logo.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileBrandSection() {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Punto ',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'de Venta',
                    style: TextStyle(
                      color: Color(0xFF63B7C4),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tu negocio, más cerca de tus clientes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 65,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kText,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
    final closure = _closure!;
    if (closure.statusClosing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: _kGreen,
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
                  'Fecha de cierre: ${_formatDate(closure.closingDate!)}',
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
  builder: (context, box) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final hPad = isMobile ? 22.0 : 35.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (box.maxHeight - 44).clamp(0.0, double.infinity),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
              const Text(
                'Cierre de caja',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Registra el efectivo contado para cerrar la caja.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fecha de cierre',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _displayField(
                icon: Icons.calendar_today_outlined,
                text: _closeDateText,
              ),
              const SizedBox(height: 15),
              const Text(
                'Hora de cierre',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _displayField(
                icon: Icons.access_time,
                text: _closeTimeText,
              ),
              const SizedBox(height: 15),
              const Text(
                'Resumen de caja',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _compactSummary(
                        width: itemWidth,
                        title: 'Efectivo inicial',
                        amount: _initialCash,
                      ),
                      _compactSummary(
                        width: itemWidth,
                        title: 'Ventas en efectivo',
                        amount: _cashSales,
                      ),
                      _compactSummary(
                        width: itemWidth,
                        title: 'Total de ventas',
                        amount: _totalSales,
                        subtitle: '$_saleCount ventas',
                      ),
                      _compactSummary(
                        width: itemWidth,
                        title: 'Efectivo esperado',
                        amount: _expectedCash,
                        highlight: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Efectivo contado',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _amountField(),
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Monto: ${_money(_countedCash ?? 0)}',
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _numericKeypad(),
              const SizedBox(height: 12),
              _differenceCard(),
              const SizedBox(height: 18),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _saving ? null : _confirmClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreenDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _saving
                        ? 'Cerrando caja...'
                        : 'Confirmar cierre de caja',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],              
            ),
          ),
        ),
      ),
    );
  },
);
}

  Widget _displayField({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kGreen, size: 23),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactSummary({
    required double width,
    required String title,
    required double amount,
    String? subtitle,
    bool highlight = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFF0F9F3)
            : const Color(0xFFF8F8F8),
        border: Border.all(
          color: highlight
              ? const Color(0xFFB6DCC0)
              : const Color(0xFFDEDEDE),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _money(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight
                        ? const Color(0xFF0F6B1F)
                        : _kText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
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
          color: focused ? _kGreenDark : const Color(0xFFBDBDBD),
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
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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

  Widget _keyButton(String value) {
    final isBackspace = value == '⌫';
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final hadFocus = _amountFocusNode.hasFocus;
              final selection = _cashController.selection;
              if (!hadFocus || !selection.isValid) {
                _cashController.selection = TextSelection.collapsed(
                  offset: _cashController.text.length,
                );
              }
              _amountFocusNode.requestFocus();
              _onKey(value);
            },
            child: Container(
              height: isMobile ? 46 : 58,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: isBackspace
                    ? const Icon(
                        Icons.backspace_outlined,
                        color: _kGreen,
                        size: 23,
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numericKeypad() {
    return Column(
      children: [
        Row(
          children: [
            _keyButton('1'),
            _keyButton('2'),
            _keyButton('3'),
          ],
        ),
        Row(
          children: [
            _keyButton('4'),
            _keyButton('5'),
            _keyButton('6'),
          ],
        ),
        Row(
          children: [
            _keyButton('7'),
            _keyButton('8'),
            _keyButton('9'),
          ],
        ),
        Row(
          children: [
            _keyButton('.'),
            _keyButton('0'),
            _keyButton('⌫'),
          ],
        ),
      ],
    );
  }

  Widget _differenceCard() {
    final difference =
    _countedCash == null ? null : _countedCash! - _expectedCash;
    late final String title;
    late final String message;
    late final Color color;
    late final Color background;
    late final Color borderColor;
    if (difference == null) {
      title = 'Pendiente de conteo';
      message = 'Ingresa el efectivo contado para conocer la diferencia.';
      color = const Color(0xFF666666);
      background = const Color(0xFFF7F8FA);
      borderColor = const Color(0xFFE1E4E8);
    } else if (difference > 0) {
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
          Row(
            children: [
              Expanded(
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            difference == null ? '--' : _money(difference),
            style: TextStyle(
              color: color,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
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
          if (difference != null) ...[
            const SizedBox(height: 14),
            Divider(
              color: borderColor,
              height: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Efectivo esperado',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _money(_expectedCash),
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Efectivo contado',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _money(_countedCash!),
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}