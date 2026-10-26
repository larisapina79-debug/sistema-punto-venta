import 'dart:ui' as ui;
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

  @override
  void dispose() {
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirmar registro',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas registrar la sucursal '
            '"$name"?',
            style: const TextStyle(
              color: _textDark,
              fontSize: 15,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: ButtonStyle(
                foregroundColor: const WidgetStatePropertyAll(_cancel),
                overlayColor:
                    const WidgetStatePropertyAll(Colors.transparent),
                backgroundColor:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed) ||
                      states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)) {
                    return _cancel.withValues(alpha: 0.12);
                  }
                  return Colors.white;
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  final pressed = states.contains(WidgetState.pressed);
                  return BorderSide(
                    color: pressed
                        ? _cancel.withValues(alpha: 0.25)
                        : _cancel,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: _teal.withValues(alpha: 0.12),
                side: const BorderSide(color: _teal, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Aceptar',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _saveBranch() async {
    if (_saving) return;
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
  void _showError(String message) {
    setState(() => _errorMessage = message);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }
  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

 Widget _avisoError() {
  final String? message = _errorMessage;
  return AnimatedSize(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    alignment: Alignment.topCenter,
    child: message == null
        ? const SizedBox(width: double.infinity)
        : Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _red.withValues(alpha: 0.45),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ColoredBox(
                      color: _red,
                      child: SizedBox(width: 5),
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(14, 12, 4, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: _red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.priority_high_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Revisa el formulario',
                                    style: TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      color: Color(0xFF7F1D1D),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: _clearError,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFB71C1C),
                                size: 20,
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
                  _avisoError(),
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
    for (final ui.PathMetric metric in path.computeMetrics()) {
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