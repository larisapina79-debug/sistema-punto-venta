import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/branch_service.dart';
import '../../widgets/save.dart';
import '../../widgets/cancel.dart';

const Color _green = Color(0xFF0F6B1F);
const Color _red = Color(0xFFF4512A);
const Color _greenSoft = Color(0xFFE8F5E9);
const Color _borderGrey = Color(0xFFE0E0E0);
const Color _accent = Color.fromARGB(255, 99, 183, 196);
class BranchDetailScreen extends StatefulWidget {
  final String branchId;
  const BranchDetailScreen({
    super.key,
    required this.branchId,
  });

  @override
  State<BranchDetailScreen> createState() =>
      _BranchDetailScreenState();
}
class _BranchDetailScreenState extends State<BranchDetailScreen> {
  final BranchService _service = BranchService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController nombreController =  TextEditingController();
  final TextEditingController direccionController =  TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  String _logoUrl = '';
  String _nombreOriginal = '';
  String _direccionOriginal = '';
  String _telefonoOriginal = '';
  XFile? _nuevoLogo;
  Uint8List? _nuevoLogoBytes;
  bool _quitarLogo = false;
  bool _editando = false;
  bool _cargando = true;
  String? _mensajeGeneral;
  bool _mostrandoMensajeGeneral = false;
  bool _mensajeExito = false;

  @override
  void initState() {
    super.initState();
    _cargarSucursal();
  }

  @override
  void dispose() {
    nombreController.dispose();
    direccionController.dispose();
    telefonoController.dispose();
    super.dispose();
  }

  Future<void> _cargarSucursal() async {
    if (mounted) {
      setState(() => _cargando = true);
    }
    try {
      final sucursal =
          await _service.getBranchById(widget.branchId);
      if (!mounted) return;
      if (sucursal == null) {
        _mostrarMensaje('No se encontró la sucursal.');
        return;
      }
      nombreController.text =
          (sucursal['branch_name'] ?? '').toString();
      direccionController.text =
          (sucursal['branch_address'] ?? '').toString();
      telefonoController.text =
          (sucursal['phone_number'] ?? '').toString();
      _logoUrl = (sucursal['branch_logo'] ?? '').toString();
      _nombreOriginal = nombreController.text;
      _direccionOriginal = direccionController.text;
      _telefonoOriginal = telefonoController.text;
    } catch (e) {
      if (mounted) {
        _mostrarMensaje('Error al cargar la sucursal: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _regresar() {
    Navigator.of(context).maybePop();
  }

  void _editar() {
    setState(() {
      _editando = true;
      _quitarLogo = false;
      _mensajeGeneral = null;
      _mostrandoMensajeGeneral = false;
    });
  }

  void _cancelar() {
    setState(() {
      nombreController.text = _nombreOriginal;
      direccionController.text = _direccionOriginal;
      telefonoController.text = _telefonoOriginal;
      _nuevoLogo = null;
      _nuevoLogoBytes = null;
      _quitarLogo = false;
      _editando = false;
    });
  }

  Future<void> _guardar() async {
    final nombre = nombreController.text.trim();
    final direccion = direccionController.text.trim();
    final telefono = telefonoController.text.trim();
    if (nombre.isEmpty) {
      _mostrarMensaje('Ingresa el nombre de la sucursal.');
      return;
    }
    if (direccion.isEmpty) {
      _mostrarMensaje('Ingresa la dirección de la sucursal.');
      return;
    }
    setState(() => _cargando = true);
    try {
      String logoFinal = _quitarLogo ? '' : _logoUrl;
      if (!_quitarLogo &&
          _nuevoLogo != null &&
          _nuevoLogoBytes != null) {
        logoFinal = await _service.prepareLogo(
          _nuevoLogo!,
          imageBytes: _nuevoLogoBytes,
        );
      }
      await _service.updateBranch(
        id: widget.branchId,
        name: nombre,
        address: direccion,
        phoneNumber: telefono,
        logo: logoFinal,
      );
      if (!mounted) return;
      _nombreOriginal = nombre;
      _direccionOriginal = direccion;
      _telefonoOriginal = telefono;

      setState(() {
        _logoUrl = logoFinal;
        _nuevoLogo = null;
        _nuevoLogoBytes = null;
        _quitarLogo = false;
        _editando = false;
        _cargando = false;
      });

      _mostrarMensaje(
        'Sucursal actualizada correctamente.',
        exito: true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _cargando = false);
      _mostrarMensaje('Error al guardar los cambios: $e');
    }
  }

  Future<void> _cambiarLogo() async {
    if (!_editando) return;
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (imagen == null || !mounted) return;
      if (!imagen.name.toLowerCase().endsWith('.png')) {
        _mostrarMensaje('Solo se permiten imágenes PNG.');
        return;
      }
      final Uint8List bytes = await imagen.readAsBytes();
      if (!mounted) return;
      const pngSignature = <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ];
      final bool esPng = bytes.length >= 8 &&
          bytes.take(8).toList().toString() ==
              pngSignature.toString();
      if (!esPng) {
        _mostrarMensaje(
          'El archivo seleccionado no es un PNG válido.',
        );
        return;
      }

      setState(() {
        _nuevoLogo = imagen;
        _nuevoLogoBytes = bytes;
        _quitarLogo = false;
      });
    } catch (e) {
      _mostrarMensaje('Error al seleccionar la imagen: $e');
    }
  }

  void _eliminarLogo() {
    setState(() {
      _quitarLogo = true;
      _nuevoLogo = null;
      _nuevoLogoBytes = null;
    });
  }

  void _mostrarMensaje(
    String mensaje, {
    bool exito = false,
  }) {
    if (!mounted) return;

    setState(() {
      _mensajeGeneral = mensaje;
      _mensajeExito = exito;
      _mostrandoMensajeGeneral = true;
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _mostrandoMensajeGeneral = false);
    });
  }

  Widget _mensaje() {
    if (!_mostrandoMensajeGeneral) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _mensajeExito
            ? _greenSoft
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _mensajeExito
              ? const Color(0xFFB7DDBA)
              : const Color(0xFFFFC5C5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _mensajeExito
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: _mensajeExito ? _green : _red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _mensajeGeneral ?? '',
              style: TextStyle(
                color: _mensajeExito ? _green : _red,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconoSinImagen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 42,
            color: Color(0xFF9E9E9E),
          ),
          SizedBox(height: 6),
          Text(
            '---',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagenLogo(
    String logo,
    Widget vacio, {
    BoxFit fit = BoxFit.cover,
  }) {
    final String valor = logo.trim();
    if (valor.isEmpty) return vacio;
    if (valor.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(valor.split(',').last),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => vacio,
        );
      } catch (_) {
        return vacio;
      }
    }

    return Image.network(
      valor,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => vacio,
    );
  }

  bool get _tieneLogo =>
      !_quitarLogo &&
      (_nuevoLogoBytes != null || _logoUrl.trim().isNotEmpty);

  Widget _logoEncabezado() {
    final Widget contenido = !_tieneLogo
        ? _iconoSinImagen()
        : _nuevoLogoBytes != null
            ? Image.memory(
                _nuevoLogoBytes!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : _imagenLogo(_logoUrl, _iconoSinImagen());

    return Container(
      width: 120,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: contenido,
    );
  }

  Widget _campo({
    required String titulo,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: _editando,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF212121),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _editando
                ? Colors.white
                : const Color(0xFFF7F8F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                color: _accent,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

Widget _campoLogo() {
  final Widget imagen = !_tieneLogo
      ? _iconoSinImagen()
      : _nuevoLogoBytes != null
          ? Image.memory(
              _nuevoLogoBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : _imagenLogo(_logoUrl, _iconoSinImagen());
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Imagen de la sucursal',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF424242),
        ),
      ),
      const SizedBox(height: 7),
      CustomPaint(
        foregroundPainter: _BordeDiscontinuo(
          color: _accent,
          radio: 9,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 210,
            width: double.infinity,
            color: const Color(0xFFF7F8F9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: imagen),
                if (_editando && _tieneLogo)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _cambiarLogo,
                      ),
                    ),
                  ),
                if (_editando && _tieneLogo)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        tooltip: 'Quitar imagen',
                        onPressed: _eliminarLogo,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: _red,
                        ),
                      ),
                    ),
                  ),
                if (_editando && !_tieneLogo)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Colors.black54,
                      child: InkWell(
                        onTap: _cambiarLogo,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Agregar imagen PNG',
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
                  ),
              ],
            ),
          ),
        ),
      ),
      if (!_tieneLogo) ...[
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 15,
              color: Color(0xFF757575),
            ),
            SizedBox(width: 6),
            Text(
              'Formato permitido: PNG',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

  Widget _encabezado(bool esMovil) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _regresar,
            style: TextButton.styleFrom(
              foregroundColor: _accent,
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
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _logoEncabezado(),
        const SizedBox(height: 12),
        const Text(
          'Detalles de sucursal',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF757575),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          nombreController.text.trim().isEmpty
              ? 'Sucursal'
              : nombreController.text.trim(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: esMovil ? 19 : 23,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF212121),
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
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _campo(
                titulo: 'Nombre de la sucursal',
                controller: nombreController,
              ),
              const SizedBox(height: 18),
              _campo(
                titulo: 'Dirección',
                controller: direccionController,
              ),
              const SizedBox(height: 18),
              _campo(
                titulo: 'Número de teléfono',
                controller: telefonoController,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
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
          controller: nombreController,
        ),
        const SizedBox(height: 16),
        _campo(
          titulo: 'Dirección',
          controller: direccionController,
        ),
        const SizedBox(height: 16),
        _campo(
          titulo: 'Número de teléfono',
          controller: telefonoController,
        ),
        const SizedBox(height: 20),
        _campoLogo(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esMovil = ancho < 700;

    return Material(
      color: Colors.white,
      child: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: _accent),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                esMovil ? 18 : 28,
                14,
                esMovil ? 18 : 28,
                esMovil ? 18 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezado(esMovil),
                  const SizedBox(height: 20),
                  const Divider(
                    color: Color(0xFFEEEEEE),
                    height: 1,
                  ),
                  const SizedBox(height: 18),
                  _mensaje(),
                  const Center(
                    child: Text(
                      'Información de la sucursal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (esMovil)
                    _formularioMovil()
                  else
                    _formularioDesktop(),
                  if (!_editando) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: 150,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _editar,
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                          ),
                          label: const Text('Editar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(0xFF212121),
                            backgroundColor:
                                const Color(0xFFEAF7F9),
                            side: const BorderSide(
                              color: _accent,
                              width: 1.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_editando) ...[
                    const SizedBox(height: 24),
                    const Divider(
                      color: Color(0xFFEEEEEE),
                      height: 1,
                    ),
                    const SizedBox(height: 20),
                    if (esMovil)
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 44,
                            child: GuardarButton(
                              onPressed: _guardar,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            child: CancelButton(
                              onPressed: _cancelar,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 44,
                            child: CancelButton(
                              onPressed: _cancelar,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 150,
                            height: 44,
                            child: GuardarButton(
                              onPressed: _guardar,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
class _BordeDiscontinuo extends CustomPainter {
  final Color color;
  final double radio;
  _BordeDiscontinuo({
    required this.color,
    this.radio = 9,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(0.75),
          Radius.circular(radio),
        ),
      );
    const double largo = 7;
    const double espacio = 5;
    for (final metric in path.computeMetrics()) {
      double distancia = 0;
      while (distancia < metric.length) {
        final fin = (distancia + largo).clamp(
          0.0,
          metric.length,
        );
        canvas.drawPath(
          metric.extractPath(distancia, fin),
          paint,
        );
        distancia += largo + espacio;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordeDiscontinuo oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radio != radio;
  }
}
