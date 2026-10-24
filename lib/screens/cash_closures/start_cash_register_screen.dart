import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/cash_closure_service.dart';

const Color _kGreen = Color.fromARGB(255, 99, 183, 196);
const Color _green = Color.fromARGB(255, 99, 183, 196);
const Color _greenLight = Color.fromARGB(255, 99, 183, 196);
const Color _black = Color(0xFF111111);
const Color _grayText = Color(0xFF666666);
const Color _fieldBorder = Color(0xFFE0E0E0);
const Color _fieldBackground = Color(0xFFF8F8F8);
const double _contentMaxWidth = 520;
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
class StartCashRegisterScreen extends StatefulWidget {
  const StartCashRegisterScreen({super.key});
  @override
  State<StartCashRegisterScreen> createState() =>
      _StartCashRegisterScreenState();
}
class _StartCashRegisterScreenState
    extends State<StartCashRegisterScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _saving = false;
  bool _loadingBranch = true;
  bool _countMode = true;
  String? _branchId;
  double? _expectedCash;
  final TextEditingController _commentController =
      TextEditingController();
  OverlayEntry? _alertEntry;
  Timer? _alertTimer;
  final TextEditingController _amountController =
      TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final List<int> _billDenoms = [1000, 500, 200, 100, 50, 20];
  final List<double> _coinDenoms = [10, 5, 2, 1, 0.5];
  final Map<double, int> _counts = {};
  final Map<double, TextEditingController> _countControllers = {};
  double get _countTotal {
    double total = 0;
    for (final denomination in _billDenoms) {
      total += denomination *
          (_counts[denomination.toDouble()] ?? 0);
    }
    for (final denomination in _coinDenoms) {
      total += denomination * (_counts[denomination] ?? 0);
    }
    return total;
  }
  double get _manualAmount {
    final value = _amountController.text
        .replaceAll(',', '')
        .replaceAll('\$', '')
        .trim();
    return double.tryParse(value) ?? 0;
  }
  double get _initialAmount =>
      _countMode ? _countTotal : _manualAmount;
  double get _difference => _initialAmount - (_expectedCash ?? 0);
  bool get _hasExpected => _expectedCash != null;
  bool get _isBalanced =>
      _hasExpected && _difference.abs() < 0.005;
  bool get _isShort =>
      _hasExpected && _difference < -0.005;

  @override
  void initState() {
    super.initState();
    for (final denomination in _billDenoms) {
      final key = denomination.toDouble();
      _counts[key] = 0;
      _countControllers[key] = TextEditingController(text: '0');
    }
    for (final denomination in _coinDenoms) {
      _counts[denomination] = 0;
      _countControllers[denomination] =
          TextEditingController(text: '0');
    }
    _loadAssignedBranch();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    _alertEntry?.remove();
    _amountController.dispose();
    _amountFocusNode.dispose();
    _commentController.dispose();
    for (final controller in _countControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _dateText {
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
    return '${_now.day} de ${months[_now.month - 1]} de ${_now.year}';
  }

  String get _timeText {
    final hour = _now.hour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatMoney(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      buffer.write(integerPart[i]);
      final remaining = integerPart.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }
    return '\$${buffer.toString()}.${parts[1]}';
  }

  Future<void> _loadAssignedBranch() async {
    try {
      final user = Session.user;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }
      if (user.idBranches.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingBranch = false;
        });
        _showAlert(
          'Sin sucursal asignada',
          'Tu usuario no tiene una sucursal asignada.',
        );
        return;
      }
      final branchId = user.idBranches.first.id;
      final openRegister =
          await CashClosureService().getOpenCashRegister(
        idBranch: branchId,
        idUser: user.idUser,
      );
      if (!mounted) return;
      if (openRegister != null) {
        Navigator.pushReplacementNamed(context, '/ventas');
        return;
      }
      double? expected;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('branch_initial_cash')
            .doc(branchId)
            .get();
        final raw = doc.data()?['initial_cash'];
        if (raw is num) {
          expected = raw.toDouble();
        } else if (raw is String) {
          expected = double.tryParse(
            raw.replaceAll(',', '').trim(),
          );
        }
      } catch (_) {
      }
      if (!mounted) return;
      setState(() {
        _branchId = branchId;
        _expectedCash = expected;
        _loadingBranch = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBranch = false;
      });
      _showAlert(
        'Error',
        'No fue posible verificar el estado de la caja.',
      );
    }
  }

  void _showTopAlert(String message, {bool error = true}) {
    _alertTimer?.cancel();
    _alertEntry?.remove();
    _alertEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: error ? const Color(0xFFB3261E) : _green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_alertEntry!);
    _alertTimer = Timer(const Duration(seconds: 3), () {
      _alertEntry?.remove();
      _alertEntry = null;
    });
  }

  Future<void> _showAlert(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: _black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: _grayText,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Aceptar',
              style: TextStyle(
                color: _black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog() async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 58,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
              const SizedBox(height: 18),
              const Text(
                '¿Iniciar caja?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verifica los datos antes de continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _grayText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              _dialogRow('Fecha', _dateText),
              const SizedBox(height: 12),
              _dialogRow('Hora', _timeText),
              const SizedBox(height: 12),
              _dialogRow(
                'Importe inicial',
                _formatMoney(_initialAmount),
                highlight: true,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, false),
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
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 13),
                        ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: _kGreen.withValues(alpha: 0.12),
                        side: const BorderSide(
                          color: _kGreen,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
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
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

  Widget _dialogRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFEAF4EC)
            : _fieldBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _grayText,
                fontSize: 13,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? _green : _black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setCount(double denomination, int value) {
    final count = value.clamp(0, 99999);
    setState(() {
      _counts[denomination] = count;
      _countControllers[denomination]!.text = count.toString();
      _countControllers[denomination]!.selection =
          TextSelection.collapsed(
        offset: _countControllers[denomination]!.text.length,
      );
    });
  }
  void _changeCount(double denomination, int amount) {
    final current = _counts[denomination] ?? 0;
    _setCount(denomination, current + amount);
  }
  void _onCountTyped(double denomination, String value) {
    setState(() {
      _counts[denomination] =
          (int.tryParse(value) ?? 0).clamp(0, 99999);
    });
  }

  String _denomLabel(double denomination) {
    if (denomination == denomination.roundToDouble()) {
      final text = denomination.toInt().toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => ',',
          );
      return '\$$text';
    }
    return '\$${denomination.toStringAsFixed(2)}';
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
              final controller = _countControllers[denomination]!;
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            },
            onChanged: (value) =>
                _onCountTyped(denomination, value),
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
              contentPadding: EdgeInsets.only(bottom: 6),
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
      _formatMoney(denomination * count),
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
          foregroundColor:
              isDisabled ? const Color(0xFFBFC6C2) : _green,
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

  Widget _denomSection({
    required String title,
    required List<double> denominations,
    required bool compact,
  }) {
    double subtotal = 0;
    for (final denomination in denominations) {
      subtotal += denomination * (_counts[denomination] ?? 0);
    }
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
              color: _green,
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
                    color: _grayText,
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  _formatMoney(subtotal),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _green,
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

  Widget _cashSummaryCard() {
    final expected = _expectedCash;
    final balanced = _isBalanced;
    final short = _isShort;
    final Color statusColor = balanced
        ? const Color(0xFF237A3B)
        : short
            ? const Color(0xFFC62828)
            : const Color(0xFFE65100);
    final String statusText = balanced
        ? 'El efectivo cuadra'
        : short
            ? 'Faltan ${_formatMoney(_difference.abs())}'
            : 'Sobran ${_formatMoney(_difference.abs())}';
    final Color borderColor = expected == null
        ? const Color(0xFFD3E7D6)
        : statusColor.withValues(alpha: 0.5);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFECF6F8),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Importe inicial de caja',
                    style: TextStyle(
                      color: _grayText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _formatMoney(_initialAmount),
                      key: ValueKey(_initialAmount),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _countMode
                        ? 'Total calculado a partir del conteo de efectivo.'
                        : 'Importe capturado manualmente.',
                    style: const TextStyle(
                      color: _grayText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (expected != null)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Efectivo inicial de la sucursal',
                            style: TextStyle(
                              color: _grayText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          _formatMoney(expected),
                          style: const TextStyle(
                            color: _black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          balanced
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (short) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        maxLines: 2,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: 'Comentario (opcional)',
                          filled: true,
                          fillColor: _fieldBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: _fieldBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: _fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: _green,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeOption(
              title: 'Contar efectivo',
              selected: _countMode,
              onTap: () {
                setState(() {
                  _countMode = true;
                });
              },
            ),
          ),
          Expanded(
            child: _modeOption(
              title: 'Ingresar importe',
              selected: !_countMode,
              onTap: () {
                setState(() {
                  _countMode = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeOption({
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
              color: selected ? Colors.black : _grayText,
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _manualAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cuánto dinero hay en caja?',
          style: TextStyle(
            color: _black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          focusNode: _amountFocusNode,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d{0,9}(\.\d{0,2})?$'),
            ),
          ],
          onChanged: (_) {
            setState(() {});
          },
          decoration: InputDecoration(
            prefixText: '\$ ',
            hintText: '0.00',
            filled: true,
            fillColor: _fieldBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _green,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Escribe el importe total, incluyendo los centavos si los hay.',
          style: TextStyle(
            color: _grayText,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _onStart() async {
    if (_saving || _loadingBranch) return;
    final user = Session.user;
    if (user == null) {
      _showTopAlert(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
      return;
    }
    if (_branchId == null) {
      _showTopAlert('No se encontró una sucursal asignada.');
      return;
    }
    if (_initialAmount <= 0) {
      _showTopAlert(
        _countMode
            ? 'Registra al menos un billete o una moneda.'
            : 'Escribe un importe inicial mayor que cero.',
      );
      return;
    }
    if (!_countMode && _manualAmount > 999999999.99) {
      _showTopAlert('El importe ingresado es demasiado grande.');
      return;
    }
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
    });
    try {
      await CashClosureService().openCashRegister(
        idBranch: _branchId!,
        idUser: user.idUser,
        initialCash: _initialAmount,
        openingDate: DateTime.now(),
        configuredInitialCash: _expectedCash,
        initialCashComment: _isShort
            ? _commentController.text.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/ventas');
    } catch (e) {
      if (!mounted) return;
      _showTopAlert(
        'No fue posible iniciar la caja. Inténtalo nuevamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _header() {
    final user = Session.user;
    final userName = user?.nameUser.trim().split(' ').first ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final hPad = compact
            ? 14.0
            : (constraints.maxWidth * 0.052).clamp(24.0, 110.0);
        return Container(
          width: double.infinity,
          height: compact ? 64 : 70,
          color: const Color(0xFF202020),
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: compact ? 36 : 56,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
              SizedBox(width: compact ? 10 : 20),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: compact ? 18 : 24,
                        fontWeight: FontWeight.w500,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Punto ',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'de Venta',
                          style: TextStyle(color: _greenLight),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _userChip(userName, compact),
            ],
          ),
        );
      },
    );
  }

  Widget _userChip(String userName, bool compact) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 130 : 240),
      child: Container(
        height: compact ? 38 : 44,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white70),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_rounded,
              color: _greenLight,
              size: compact ? 20 : 24,
            ),
            if (userName.isNotEmpty) ...[
              SizedBox(width: compact ? 6 : 8),
              Flexible(
                child: Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _saving || _loadingBranch ? null : _onStart,
        style: _tealButtonStyle(radius: 14),
        child: _saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: _kGreen,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 10),
                  Text(
                    'Iniciar caja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _form() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _contentMaxWidth,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Inicio de caja',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Prepara tu caja para comenzar a registrar ventas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _grayText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _modeSelector(),
              const SizedBox(height: 18),
              if (_countMode) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 500;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _denomSection(
                              title: 'Billetes',
                              denominations: _billDenoms
                                  .map((e) => e.toDouble())
                                  .toList(),
                              compact: compact,
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 14),
                          Expanded(
                            child: _denomSection(
                              title: 'Monedas',
                              denominations: _coinDenoms,
                              compact: compact,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                _manualAmountField(),
              ],
              const SizedBox(height: 18),
              _cashSummaryCard(),
              const SizedBox(height: 20),
              _startButton(),
              if (_loadingBranch) ...[
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Verificando sucursal...',
                    style: TextStyle(
                      color: _grayText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F5),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _form(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
