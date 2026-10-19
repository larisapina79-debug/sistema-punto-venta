import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/primary_button.dart';

const Color _green = Color(0xFF0F6B1F);
const Color _borderGrey = Color(0xFFBDBDBD);
const Color _hintGrey = Color(0xFF9E9E9E);
const Color _textDark = Color(0xFF212121);
class BranchFormScreen extends StatefulWidget {
  const BranchFormScreen({super.key});
  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}
class _BranchFormScreenState extends State<BranchFormScreen> {
  final BranchService _branchService = BranchService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

final bool _active = true;
  bool _saving = false;
  XFile? _image;
  Uint8List? _imageBytes;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    if (_saving) return;
    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (selectedImage == null || !mounted) return;
      final Uint8List bytes = await selectedImage.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = selectedImage;
        _imageBytes = bytes;
      });
      debugPrint(
        'Imagen seleccionada: ${(bytes.length / 1024).toStringAsFixed(2)} KB',
      );
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      if (!mounted) return;
      _showMessage(
        'No se pudo seleccionar la imagen.',
        error: true,
      );
    }
  }

  Future<void> _saveBranch() async {
    if (_saving) return;
    final String name = _nameController.text.trim();
    final String address = _addressController.text.trim();
    if (name.isEmpty) {
      _showMessage(
        'Ingresa el nombre de la sucursal.',
        error: true,
      );
      return;
    }
    if (address.isEmpty) {
      _showMessage(
        'Ingresa la dirección de la sucursal.',
        error: true,
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    final Stopwatch timer = Stopwatch()..start();
    try {
      debugPrint('Iniciando registro de sucursal en Firestore...');
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
        logo: logo,
        status: _active,
      );
      timer.stop();
      debugPrint(
        'Tiempo total del registro: ${timer.elapsedMilliseconds} ms.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('Error al registrar sucursal: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      _showMessage(
        'No se pudo registrar la sucursal. Verifica Firebase.',
        error: true,
      );
    } finally {
      timer.stop();
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? const Color(0xFFF4512A) : const Color(0xFF0F6B1F),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _botonVolver() {
    return InkWell(
      onTap: _saving ? null : () => Navigator.of(context).pop(),
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
        child: const Icon(
          Icons.arrow_back,
          color: _green,
          size: 24,
        ),
      ),
    );
  }

  Widget _campo({
    required String titulo,
    required TextEditingController controller,
    required String hint,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: !_saving,
          textCapitalization: capitalization,
          style: const TextStyle(
            fontSize: 16,
            color: _textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _hintGrey,
              fontSize: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _green,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logo de la sucursal (opcional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _saving ? null : _selectImage,
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomPaint(
              foregroundPainter: const _DashedBorderPainter(color: _borderGrey),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _imageBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              color: Colors.black54,
                              child: const Text(
                                'Toca para cambiar la imagen',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Seleccionar imagen',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Toca aquí para elegir una imagen',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _hintGrey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
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
              const SizedBox(height: 26),
              _campo(
                titulo: 'Dirección',
                controller: _addressController,
                hint: 'Ingresa la dirección de la sucursal',
              ),
            ],
          ),
        ),
        const SizedBox(width: 60),
        Expanded(child: _campoLogo()),
      ],
    );
  }

  Widget _formularioMovil() {
    return Column(
      children: [
        _campo(
          titulo: 'Nombre de la sucursal',
          controller: _nameController,
          hint: 'Ej. Sucursal Centro',
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 22),
        _campo(
          titulo: 'Dirección',
          controller: _addressController,
          hint: 'Ingresa la dirección de la sucursal',
        ),
        const SizedBox(height: 22),
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
      appBar: const AppHeader(
        currentRoute: '/sucursales',
      ),
      drawer: const AppDrawer(
        currentRoute: '/sucursales',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: esMovil ? 20 : 40,
            vertical: 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: esMovil ? 56 : 0,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Registrar Sucursal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: esMovil ? 26 : 36,
                                fontWeight: FontWeight.w400,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Completa los datos de la nueva sucursal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF8A8A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: _botonVolver(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  if (esMovil) _formularioMovil() else _formularioDesktop(),
                  const SizedBox(height: 44),
                  Center(
                    child: SizedBox(
                      width: esMovil ? double.infinity : 420,
                      height: 54,
                      child: PrimaryButton(
                        text: _saving ? 'Registrando...' : 'Registrar sucursal',
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
  const _DashedBorderPainter({required this.color});

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
        final double length = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        canvas.drawPath(
          metric.extractPath(distance, distance + length),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}