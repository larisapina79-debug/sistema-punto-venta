import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/cash_closure_service.dart';
class StartCashRegisterScreen extends StatefulWidget {
  const StartCashRegisterScreen({super.key});

  @override
  State<StartCashRegisterScreen> createState() =>
      _StartCashRegisterScreenState();
}

class _StartCashRegisterScreenState extends State<StartCashRegisterScreen> {
  static const Color _green = Color(0xFF0F6B1F);
  static const Color _greenLight = Color(0xFF63B7C4);
  static const Color _black = Color(0xFF111111);
  static const Color _grayText = Color(0xFF555555);
  static const Color _fieldBorder = Color(0xFFBDBDBD);
  static const Color _fieldBackground = Color(0xFFF8F8F8);
  static const Color _white = Colors.white;

  Timer? _timer;
  DateTime _now = DateTime.now();
  String _amount = '';
  bool _saving = false;
  bool _updatingController = false;

  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  String get _dateText {
    final day = _now.day.toString().padLeft(2, '0');
    final month = _now.month.toString().padLeft(2, '0');
    final year = _now.year.toString();
    return '$day/$month/$year';
  }

  String get _timeText {
    final hour = _now.hour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  void initState() {
    super.initState();
    _checkOpenRegister();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }
    Future<void> _checkOpenRegister() async {
    final user = Session.user;
    if (user == null || user.idBranches.isEmpty) return;
    try {
      final caja = await CashClosureService().getOpenCashRegister(
        idBranch: user.idBranches.first.id,
        idUser: user.idUser,
      );
      debugPrint('CHECK CAJA: id=${caja?.idClosure} '
          'status=${caja?.statusClosing}');
      if (!mounted) return;
      if (caja != null && !caja.statusClosing) {
        Navigator.pushReplacementNamed(context, '/ventas');
      }
    } catch (e, st) {
      debugPrint('CHECK CAJA ERROR: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  String _formatMoney(String value) {
    if (value.isEmpty) return '0.00';
    final cleanValue = value.replaceAll(',', '');
    final number = double.tryParse(cleanValue);
    if (number == null) return '0.00';
    final fixed = number.toStringAsFixed(2);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '$formattedInteger.$decimalPart';
  }

  String get _amountText => _formatMoney(_amount);
  String _formatInputValue(String value) {
    final cleanValue = value.replaceAll(',', '');
    if (cleanValue.isEmpty) return '';
    final parts = cleanValue.split('.');
    String integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;
    if (integerPart.isEmpty) {
      integerPart = '0';
    }

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
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _updatingController = false;
  }

  void _updateAmount(
    String value, {
    int? cursorPosition,
  }) {
    final cleanValue = value.replaceAll(',', '');
    if (cleanValue.isEmpty) {
      setState(() {
        _amount = '';
      });
      if (_amountController.text.isNotEmpty) {
        _updatingController = true;
        _amountController.value = const TextEditingValue(
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
    _amountController.value = TextEditingValue(
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
    final cursor = _amountController.selection.baseOffset;
    int rawCursor = cursor;
    if (cursor > 0) {
      final beforeCursor = value.substring(
        0,
        cursor.clamp(0, value.length),
      );
      rawCursor = beforeCursor.replaceAll(',', '').length;
    }
    _updateAmount(
      cleanValue,
      cursorPosition: rawCursor,
    );
  }

  void _onKey(String value) {
    final current = _amount;
    final controllerValue = _amountController.value;
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
    final integerPart = newValue.split('.').first;
    if (integerPart.length > 9) return;
    if (newValue.contains('.')) {
      final parts = newValue.split('.');
      final decimals = parts.length > 1 ? parts[1] : '';
      if (decimals.length > 2) return;
    }
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
    final bgColor =
        success ? const Color(0xFFE8F5E9) : const Color(0xFFFDECEA);
    final borderColor =
        success ? const Color(0xFFA5D6A7) : const Color(0xFFF5B5B0);
    final contentColor =
        success ? const Color(0xFF1B5E20) : const Color(0xFFB3261E);
    final alertIcon =
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
                tween: Tween(begin: -20, end: 0),
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
                        Icon(alertIcon, color: contentColor, size: 22),
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

  Widget _readOnlyField({
    required IconData icon,
    required String text,
    bool centered = true,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _greenLight, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: centered ? TextAlign.center : TextAlign.left,
              style: const TextStyle(
                color: _black,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
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
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? _green : _fieldBorder,
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Text(
            '\$',
            style: TextStyle(
              color: _greenLight,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _amountController,
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
                color: _black,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Ingresa el efectivo',
                hintStyle: TextStyle(
                  color: _grayText,
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
                  color: _greenLight,
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
              final selection = _amountController.selection;
              if (!hadFocus || !selection.isValid) {
                _amountController.selection = TextSelection.collapsed(
                  offset: _amountController.text.length,
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
                        color: _greenLight,
                        size: 23,
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          color: _black,
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

  Widget _keypad() {
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

  Future<bool> _showConfirmDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final dialogWidth = screenWidth >= 800 ? 440.0 : null;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: dialogWidth,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 70,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '¿Iniciar caja?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: _greenLight,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Fecha:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _dateText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: _greenLight,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Hora:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Efectivo inicial',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$$_amountText',
                            style: const TextStyle(
                              color: _greenLight,
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white38,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Confirmar'),
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
      },
    );
    return result ?? false;
  }

  Future<void> _onStart() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_amount.isEmpty) {
      _showTopAlert(
        message: 'Ingresa el efectivo en caja.',
        icon: Icons.attach_money_rounded,
      );
      _amountFocusNode.requestFocus();
      return;
    }
    final amount = double.tryParse(_amount);
    if (amount == null || !amount.isFinite || amount < 0) {
      _showTopAlert(
        message: 'Ingresa un monto válido.',
        icon: Icons.warning_amber_rounded,
      );
      _amountFocusNode.requestFocus();
      return;
    }
    final user = Session.user;
    if (user == null) {
      _showTopAlert(
        message: 'No se encontró la sesión del usuario. Inicia sesión nuevamente.',
        icon: Icons.person_outline_rounded,
      );
      return;
    }
    if (user.idBranches.isEmpty) {
      _showTopAlert(
        message: 'No tienes una sucursal asignada.',
        icon: Icons.store_outlined,
      );
      return;
    }
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
    });
    try {
      await CashClosureService().openCashRegister(
        idBranch: user.idBranches.first.id,
        idUser: user.idUser,
        initialCash: amount,
        openingDate: DateTime.now(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/ventas',
      );
    } catch (e) {
      if (!mounted) return;
      _showTopAlert(
        message: e.toString().replaceFirst('Exception: ', ''),
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _saving ? null : _onStart,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _green.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Iniciar caja',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _imageSection() {
    return Expanded(
      flex: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final availableWidth = constraints.maxWidth;
          final imageWidth =
              (availableWidth * 0.78).clamp(380.0, 620.0);
          final imageHeight =
              (availableHeight * 0.62).clamp(330.0, 500.0);
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
                          color: _black,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: 'de Venta',
                        style: TextStyle(
                          color: _greenLight,
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
                    color: _grayText,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: imageWidth,
                      height: imageHeight,
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/logo.png',
                        width: imageWidth,
                        height: imageHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _mobileImageSection(double screenWidth) {
    final double imageWidth =
        (screenWidth * 0.40).clamp(120.0, 170.0);
    return SizedBox(
      width: double.infinity,
      height: 150,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 15,
          right: 15,
          top: 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Punto ',
                    style: TextStyle(
                      color: _black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'de Venta',
                    style: TextStyle(
                      color: _greenLight,
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
                color: _grayText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: imageWidth,
              height: 80,
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

  Widget _formSection({bool mobile = false}) {
    return Expanded(
      flex: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              mobile ? 25 : 35,
              mobile ? 8 : 20,
              mobile ? 25 : 35,
              mobile ? 12 : 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        Text(
                          'Bienvenido',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _black,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Inicia la caja para comenzar el día.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _grayText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: mobile ? 14 : 18),
                  const Text(
                    'Fecha de inicio',
                    style: TextStyle(
                      color: _black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _readOnlyField(
                    icon: Icons.calendar_today_outlined,
                    text: _dateText,
                    centered: false,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hora de inicio',
                    style: TextStyle(
                      color: _black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _readOnlyField(
                    icon: Icons.access_time,
                    text: _timeText,
                    centered: false,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Efectivo inicial',
                    style: TextStyle(
                      color: _black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _amountField(),
                  const SizedBox(height: 9),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Monto: \$$_amountText',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 16, 16, 16),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _keypad(),
                  const SizedBox(height: 12),
                  _startButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _imageSection(),
                  _formSection(mobile: false),
                ],
              );
            }
            return Column(
              children: [
                _mobileImageSection(constraints.maxWidth),
                _formSection(mobile: true),
              ],
            );
          },
        ),
      ),
    );
  }
}
