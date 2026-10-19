import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/edit.dart';
import '../../widgets/save.dart';
import '../../widgets/cancel.dart';
import '../../widgets/status.dart';

const Color _green = Color(0xFF0F6B1F);
const Color _red = Color(0xFFF4512A);
const Color _greenSoft = Color(0xFFE8F5E9);
const Color _borderGrey = Color(0xFFBDBDBD);

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
  final TextEditingController nombreController =
      TextEditingController();
  final TextEditingController direccionController =
      TextEditingController();

  String _logoUrl = '';
  String _nombreOriginal = '';
  String _direccionOriginal = '';
  XFile? _nuevoLogo;
  Uint8List? _nuevoLogoBytes;
  bool _activo = true;
  bool _editando = false;
  bool _cargando = true;
  String? _mensajeEstado;
  bool _mostrandoMensajeEstado = false;
  String? _mensajeGeneral;
  bool _mostrandoMensajeGeneral = false;
  bool _mensajeExito = true;

  @override
  void initState() {
    super.initState();
    _cargarSucursal();
  }
  @override
  void dispose() {
    nombreController.dispose();
    direccionController.dispose();
    super.dispose();
  }
  Future<void> _cargarSucursal() async {
    setState(() {
      _cargando = true;
    });
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
      _logoUrl =
          (sucursal['branch_logo'] ?? '').toString();
      _activo = sucursal['branch_status'] == true;
      _nombreOriginal = nombreController.text;
      _direccionOriginal = direccionController.text;
    } catch (e) {
      if (mounted) {
        _mostrarMensaje('Error al cargar la sucursal: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }
  void _editar() {
    setState(() {
      _editando = true;
      _mensajeGeneral = null;
      _mostrandoMensajeGeneral = false;
    });
  }

  void _cancelar() {
    setState(() {
      nombreController.text = _nombreOriginal;
      direccionController.text = _direccionOriginal;
      _nuevoLogo = null;
      _nuevoLogoBytes = null;
      _editando = false;
    });

    _cargarSucursal();
  }

  Future<void> _guardar() async {
    final nombre = nombreController.text.trim();
    final direccion = direccionController.text.trim();
    if (nombre.isEmpty) {
      _mostrarMensaje(
        'Ingresa el nombre de la sucursal.',
      );
      return;
    }
    if (direccion.isEmpty) {
      _mostrarMensaje(
        'Ingresa la dirección de la sucursal.',
      );
      return;
    }
    setState(() {
      _cargando = true;
    });
    try {
      String logoFinal = _logoUrl;
      if (_nuevoLogo != null && _nuevoLogoBytes != null) {
        logoFinal = await _service.prepareLogo(
          _nuevoLogo!,
          imageBytes: _nuevoLogoBytes,
        );
      }
      await _service.updateBranch(
        id: widget.branchId,
        name: nombre,
        address: direccion,
        logo: logoFinal,
      );
      if (!mounted) return;
      _nombreOriginal = nombre;
      _direccionOriginal = direccion;
      setState(() {
        _logoUrl = logoFinal;
        _nuevoLogo = null;
        _nuevoLogoBytes = null;
        _editando = false;
        _cargando = false;
      });
      _mostrarMensaje(
        'Sucursal actualizada correctamente.',
        exito: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
      });
      _mostrarMensaje('Error al guardar los cambios: $e');
    }
  }

  Future<void> _cambiarEstado(bool nuevoEstado) async {
    try {
      await _service.updateBranchStatus(
        id: widget.branchId,
        status: nuevoEstado,
      );
      if (!mounted) return;
      setState(() {
        _activo = nuevoEstado;
        _mensajeEstado = nuevoEstado
            ? 'Sucursal activada correctamente.'
            : 'Sucursal desactivada correctamente.';
        _mostrandoMensajeEstado = true;
      });
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() {
          _mostrandoMensajeEstado = false;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajeEstado = 'No se pudo cambiar el estado.';
        _mostrandoMensajeEstado = true;
      });
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() {
          _mostrandoMensajeEstado = false;
        });
      });
    }
  }

  Future<void> _cambiarLogo() async {
    if (!_editando) return;
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (imagen == null || !mounted) return;
      final Uint8List bytes = await imagen.readAsBytes();
      if (!mounted) return;
      setState(() {
        _nuevoLogo = imagen;
        _nuevoLogoBytes = bytes;
      });
    } catch (e) {
      _mostrarMensaje('Error al seleccionar la imagen: $e');
    }
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

      setState(() {
        _mostrandoMensajeGeneral = false;
      });
    });
  }

  Widget _mensaje() {
    if (!_mostrandoMensajeGeneral) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _mensajeExito
            ? _greenSoft
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 9),
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

  String _inicial() {
    final String nombre = nombreController.text.trim();
    return nombre.isEmpty ? 'S' : nombre[0].toUpperCase();
  }

  Widget _logo({double size = 68}) {
    final Widget vacio = Center(
      child: Text(
        _inicial(),
        style: TextStyle(
          color: _green,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFD5E8D7),
        ),
      ),
      child: _nuevoLogoBytes != null
          ? Image.memory(
              _nuevoLogoBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            )
          : _imagenLogo(_logoUrl, vacio),
    );
  }

  Widget _campo({
    required String titulo,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: _editando,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            fillColor: _editando
                ? Colors.white
                : const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
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
    final bool tieneLogo =
        _nuevoLogoBytes != null || _logoUrl.trim().isNotEmpty;
    final Widget vacio = const Center(
      child: Text(
        'Sin logo',
        style: TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    final Widget imagen = _nuevoLogoBytes != null
        ? Image.memory(
            _nuevoLogoBytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          )
        : _imagenLogo(_logoUrl, vacio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logo de la sucursal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _editando ? _cambiarLogo : null,
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: _editando ? _green : _borderGrey,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imagen,
                    if (_editando)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          color: Colors.black54,
                          child: Text(
                            tieneLogo
                                ? 'Toca para cambiar la imagen'
                                : 'Toca para agregar una imagen',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _botonVolver() {
    return InkWell(
      onTap: () => Navigator.pop(context),
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
        child: const Icon(
          Icons.arrow_back,
          color: _green,
          size: 22,
        ),
      ),
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
                controller: nombreController,
              ),
              const SizedBox(height: 24),
              _campo(
                titulo: 'Dirección',
                controller: direccionController,
              ),
            ],
          ),
        ),
        const SizedBox(width: 55),
        Expanded(child: _campoLogo()),
      ],
    );
  }

  Widget _formularioMovil() {
    return Column(
      children: [
        _campo(
          titulo: 'Nombre de la sucursal',
          controller: nombreController,
        ),
        const SizedBox(height: 20),
        _campo(
          titulo: 'Dirección',
          controller: direccionController,
        ),
        const SizedBox(height: 24),
        _campoLogo(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esMovil = ancho < 700;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        currentRoute: '/sucursales',
      ),
      drawer: AppDrawer(
        currentRoute: '/sucursales',
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(
                  color: _green,
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: esMovil ? 18 : 55,
                  vertical: 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1000,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _botonVolver(),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _logo(size: esMovil ? 58 : 68),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombreController.text.isEmpty
                                        ? 'Sucursal'
                                        : nombreController.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          esMovil ? 17 : 20,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          const Color(0xFF212121),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  StatusSwitch(
                                    activo: _activo,
                                    mensajeEstado: _mensajeEstado,
                                    mostrandoMensajeEstado:
                                        _mostrandoMensajeEstado,
                                    puedeCambiar: !_editando,
                                    onChanged: _cambiarEstado,
                                  ),
                                ],
                              ),
                            ),
                            if (!esMovil && !_editando)
                              EditButton(
                                onPressed: _editar,
                              ),
                          ],
                        ),
                        if (esMovil && !_editando) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: EditButton(
                              onPressed: _editar,
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        _mensaje(),
                        const Center(
                          child: Text(
                            'Información',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF212121),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (esMovil)
                          _formularioMovil()
                        else
                          _formularioDesktop(),
                        if (_editando) ...[
                          const SizedBox(height: 32),
                          if (esMovil)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: GuardarButton(
                                    onPressed: _guardar,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: CancelButton(
                                    onPressed: _cancelar,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 180,
                                  height: 44,
                                  child: GuardarButton(
                                    onPressed: _guardar,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 180,
                                  height: 44,
                                  child: CancelButton(
                                    onPressed: _cancelar,
                                  ),
                                ),
                              ],
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
  static const double _radius = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 6),
          paint,
        );
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}