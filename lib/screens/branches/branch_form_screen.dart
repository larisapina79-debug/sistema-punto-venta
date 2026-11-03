import 'dart:ui' show PathMetric, Path, Rect, RRect, Radius;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/branch_service.dart';
import '../../widgets/primary_button.dart';

const Color _green = Color(0xFF0F6B1F);
const Color _borderGrey = Color(0xFFBDBDBD);
const Color _hintGrey = Color(0xFF9E9E9E);
const Color _textDark = Color(0xFF212121);
const Color _teal = Color(0xFF63B7C4);
const Color _red = Color(0xFFF4512A);
const Color _cancel = Color(0xFFFF5722);

class BranchFormScreen extends StatefulWidget {
  const BranchFormScreen({super.key});

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}
class _BranchFormScreenState extends State<BranchFormScreen> {
  final BranchService _branchService = BranchService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController =  TextEditingController();
  final bool _active = true;
  bool _saving = false;
  XFile? _image;
  Uint8List? _imageBytes;
  String? _errorMessage;
  Timer? _messageTimer;
  String? _successMessage;
  bool _registrado = false;

  ButtonStyle get _cancelStyle => OutlinedButton.styleFrom(
        foregroundColor: _cancel,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _cancel, width: 1.5),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );

  ButtonStyle get _acceptStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: _teal.withValues(alpha: 0.12),
        side: const BorderSide(color: _teal, width: 1.5),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );

  @override
  void dispose() {
    _messageTimer?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    if (_saving) return;
    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (selectedImage == null || !mounted) return;
      if (!selectedImage.name.toLowerCase().endsWith('.png')) {
        _showError('Solo se permiten imágenes PNG.');
        return;
      }
      final Uint8List bytes = await selectedImage.readAsBytes();
      if (!mounted) return;
      const List<int> pngSignature = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ];
      final bool isPng = bytes.length >= pngSignature.length &&
          List<int>.generate(
            pngSignature.length,
            (index) => bytes[index],
          ).toString() ==
              pngSignature.toString();
      if (!isPng) {
        _showError(
          'El archivo seleccionado no es una imagen PNG válida.',
        );
        return;
      }
      setState(() {
        _image = selectedImage;
        _imageBytes = bytes;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      if (!mounted) return;
      _showError('No se pudo seleccionar la imagen.');
    }
  }
  void _removeImage() {
    if (_saving) return;
    setState(() {
      _image = null;
      _imageBytes = null;
    });
  }

   Future<bool> _confirmarRegistro(String name) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined, color: _teal, size: 32),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Confirmar registro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      color: _textDark,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            '¿Estás seguro de que deseas registrar la sucursal ',
                      ),
                      TextSpan(
                        text: '"$name"',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: _cancelStyle,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: _acceptStyle,
                        child: const Text('Aceptar'),
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
    return result == true;
  }

  Future<void> _saveBranch() async {
    if (_saving || _registrado) return;
    final String name = _nameController.text.trim();
    final String address = _addressController.text.trim();
    final String phone = _phoneController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresa el nombre de la sucursal.');
      return;
    }
    if (address.isEmpty) {
      _showError('Ingresa la dirección de la sucursal.');
      return;
    }
    if (phone.length != 10) {
      _showError(
        'El número de teléfono debe tener exactamente 10 dígitos.',
      );
      return;
    }
    setState(() => _errorMessage = null);
    final bool confirmed = await _confirmarRegistro(name);
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final Stopwatch timer = Stopwatch()..start();
    try {
      String logo = '';
      if (_image != null && _imageBytes != null) {
        logo = await _branchService.prepareLogo(
          _image!,
          imageBytes: _imageBytes,
        );
      }
      await _branchService.createBranch(
        name: name,
        address: address,
        phoneNumber: phone,
        logo: logo,
        status: _active,
      );
      timer.stop();
      debugPrint(
        'Tiempo total del registro: '
        '${timer.elapsedMilliseconds} ms.',
      );
      if (!mounted) return;
      _registrado = true;
      _showSuccess('Sucursal registrada correctamente.');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('Error al registrar sucursal: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      _showError(
        'No se pudo registrar la sucursal. Verifica Firebase.',
      );
    } finally {
      timer.stop();
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _scrollArriba() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _messageTimer?.cancel();
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    _scrollArriba();
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_errorMessage == message) setState(() => _errorMessage = null);
    });
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    _messageTimer?.cancel();
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
    _scrollArriba();
  }

  void _clearError() {
    _messageTimer?.cancel();
    if (_errorMessage != null || _successMessage != null) {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }

  Widget _messages() {
    if (_errorMessage == null && _successMessage == null) {
      return const SizedBox.shrink();
    }

    final error = _errorMessage != null;
    final message = _errorMessage ?? _successMessage!;

    final color = error ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final bg = error ? const Color(0xFFFDECEA) : const Color(0xFFE8F5E9);
    final border = error ? const Color(0xFFF5B5AE) : const Color(0xFFA5D6A7);

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonVolver() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _saving
            ? null
            : () => Navigator.of(context).pop(),
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
    );
  }

  Widget _campo({
    required String titulo,
    required TextEditingController controller,
    required String hint,
    TextCapitalization capitalization =
        TextCapitalization.sentences,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          enabled: !_saving,
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (_) => _clearError(),
          style: const TextStyle(
            fontSize: 15,
            color: _textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _hintGrey,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _borderGrey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _borderGrey,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _borderGrey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _teal,
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoTelefono() {
    return _campo(
      titulo: 'Número de teléfono',
      controller: _phoneController,
      hint: 'Ingresa el teléfono a 10 dígitos',
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
    );
  }

  Widget _campoLogo() {
    final bool hasImage = _imageBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imagen de la sucursal (opcional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 9),
        CustomPaint(
          foregroundPainter: const _DashedBorderPainter(
            color: _teal,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    )
                  else
                    Container(
                      color: const Color(0xFFFAFCFC),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 42,
                            color: _teal,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Agregar imagen PNG',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Toca aquí para elegir una imagen',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _hintGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _saving ? null : _selectImage,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (hasImage)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          color: Colors.black54,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Cambiar imagen PNG',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (hasImage)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Material(
                        color: Colors.white,
                        elevation: 2,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Eliminar imagen',
                          onPressed: _saving ? null : _removeImage,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: _red,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 15,
              color: _hintGrey,
            ),
            SizedBox(width: 6),
            Text(
              'Formato permitido: PNG',
              style: TextStyle(
                color: _hintGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _formularioDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _campo(
                titulo: 'Nombre de la sucursal',
                controller: _nameController,
                hint: 'Ej. Sucursal Centro',
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 25),
              _campo(
                titulo: 'Dirección',
                controller: _addressController,
                hint: 'Ingresa la dirección de la sucursal',
              ),
              const SizedBox(height: 25),
              _campoTelefono(),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          child: _campoLogo(),
        ),
      ],
    );
  }

  Widget _formularioMovil() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo(
          titulo: 'Nombre de la sucursal',
          controller: _nameController,
          hint: 'Ej. Sucursal Centro',
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),
        _campo(
          titulo: 'Dirección',
          controller: _addressController,
          hint: 'Ingresa la dirección de la sucursal',
        ),
        const SizedBox(height: 20),
        _campoTelefono(),
        const SizedBox(height: 24),
        _campoLogo(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double ancho = MediaQuery.of(context).size.width;
    final bool esMovil = ancho < 700;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: esMovil ? 20 : 40,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                 _messages(), 
                  _botonVolver(),
                  const SizedBox(height: 12),
                  Text(
                    'Registrar sucursal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: esMovil ? 25 : 32,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completa los datos de la nueva sucursal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                  const SizedBox(height: 34),
                  if (esMovil)
                    _formularioMovil()
                  else
                    _formularioDesktop(),
                  const SizedBox(height: 36),
                  Center(
                    child: SizedBox(
                      width: esMovil ? double.infinity : 420,
                      height: 52,
                      child: PrimaryButton(
                        text: _saving
                            ? 'Registrando...'
                            : 'Registrar sucursal',
                        onPressed: _saving ? null : _saveBranch,
                      ),
                    ),
                  ),
                  if (_saving) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            color: _green,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Guardando sucursal, espera un momento...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 1.5;
    const double dashLength = 6;
    const double gapLength = 4;
    const double radius = 12;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth / 2,
            strokeWidth / 2,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          const Radius.circular(radius),
        ),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end =
            (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _DashedBorderPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}