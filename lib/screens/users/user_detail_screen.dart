import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_services.dart';
import '../../widgets/app_header.dart';
import '../../widgets/save.dart';
import '../../widgets/cancel.dart';
import '../../widgets/status.dart';
import '../../widgets/edit.dart';

const _green = Color(0xFF0F6B1F);
const _red = Color(0xFFF4512A);

class UserDetailScreen extends StatefulWidget {
  final String? userId;
  final bool isOwnProfile;
  final bool canEdit;
  const UserDetailScreen({
    super.key,
    this.userId,
    this.isOwnProfile = false,
    this.canEdit = false,
  });
  @override
  State<UserDetailScreen> createState() =>
      _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final nombreController = TextEditingController();
  final apellidoController = TextEditingController();
  final usuarioController = TextEditingController();
  final passwordController = TextEditingController();
  String rol = 'Empleado';
  String estado = 'activo';
  String rolUsuarioActual = '';
  String _nombreOriginal = '';
  String _apellidoOriginal = '';
  String _usuarioOriginal = '';
  String _rolOriginal = 'Empleado';
  List<String> _sucursalesOriginales = [];
  List<String> sucursales = [];
  List<String> todasLasSucursales = [];
  final Map<String, String> _idPorNombre = {};
  bool editando = false;
  bool cargando = false;
  bool _verPassword = false;
  String? _mensajeEstado;
  bool _mostrandoMensajeEstado = false;
  String? _mensajeGeneral;
  bool _mostrandoMensajeGeneral = false;
  bool _mensajeGeneralExito = true;
  String? get _id =>
      widget.userId ?? Session.user?.idUser;
  @override
  void initState() {
    super.initState();
    cargarDatosUsuario();
  }
  @override
  void dispose() {
    nombreController.dispose();
    apellidoController.dispose();
    usuarioController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool get _esAdministradorOSupervisor {
    return rolUsuarioActual == 'administrador' ||
        rolUsuarioActual == 'supervisor';
  }
  bool puedeEditar() {
    if (widget.isOwnProfile) {
      return true;
    }
    return _esAdministradorOSupervisor;
  }
  bool get _puedeEditarRolYSucursales {
    return _esAdministradorOSupervisor;
  }
  bool puedeCambiarEstado() {
    return true;
  }
  Future<void> cargarDatosUsuario() async {
    setState(() {
      cargando = true;
    });
    try {
      final db = FirebaseFirestore.instance;
      final usuarioActualId = Session.user?.idUser;
      if (usuarioActualId != null) {
        final docActual = await db
            .collection('users')
            .doc(usuarioActualId)
            .get();
        final datosActuales = docActual.data();
        rolUsuarioActual =
            '${datosActuales?['role'] ?? ''}'
                .trim()
                .toLowerCase();
      }
      final branches =
          await db.collection('branches').get();
      _idPorNombre.clear();
      final activas = <String>[];
      for (final b in branches.docs) {
        final data = b.data();
        final nombre =
            '${data['branch_name'] ?? b.id}';
        _idPorNombre[nombre] = b.id;
        if (data['branch_status'] == true) {
          activas.add(nombre);
        }
      }
      todasLasSucursales = activas;
      final id = _id;
      if (id == null) {
        return;
      }
      final doc = await db
          .collection('users')
          .doc(id)
          .get();
      final d = doc.data();
      if (d == null) {
        mostrarMensaje(
          'No se encontró el usuario',
        );
        return;
      }

      nombreController.text =
          '${d['name'] ?? ''}';
      apellidoController.text =
          '${d['lastName'] ?? ''}';
      usuarioController.text =
          '${d['userName'] ?? ''}';
      _nombreOriginal =
          nombreController.text;
      _apellidoOriginal =
          apellidoController.text;
      _usuarioOriginal =
          usuarioController.text;

      const roles = [
        'Administrador',
        'Supervisor',
        'Empleado',
      ];

      rol = roles.firstWhere(
        (r) =>
            r.toLowerCase() ==
            '${d['role'] ?? ''}'.toLowerCase(),
        orElse: () => 'Empleado',
      );
      _rolOriginal = rol;

      estado = (d['status'] ?? true) == true
          ? 'activo'
          : 'inactivo';

      final ids =
          ((d['id_branches'] as List?) ?? [])
              .whereType<DocumentReference>()
              .map((r) => r.id)
              .toSet();
      sucursales = _idPorNombre.entries
          .where(
            (e) => ids.contains(e.value),
          )
          .map((e) => e.key)
          .toList();
      _sucursalesOriginales = [
        ...sucursales,
      ];
    } catch (e) {
      mostrarMensaje(
        'Error al cargar: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  void cancelarEdicion() {
    setState(() {
      nombreController.text =
          _nombreOriginal;
      apellidoController.text =
          _apellidoOriginal;
      usuarioController.text =
          _usuarioOriginal;
      rol = _rolOriginal;
      sucursales = [
        ..._sucursalesOriginales,
      ];
      passwordController.clear();
      _verPassword = false;
      editando = false;
    });
  }

  Future<void> guardarCambios() async {
    final id = _id;
    if (id == null) {
      return;
    }
    if (nombreController.text.trim().isEmpty) {
      mostrarMensaje(
        'El nombre es obligatorio',
      );
      return;
    }
    if (apellidoController.text.trim().isEmpty) {
      mostrarMensaje(
        'El apellido es obligatorio',
      );
      return;
    }
    final usuario = usuarioController.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s'), '');
    if (usuario.length < 3) {
      mostrarMensaje(
        'El usuario debe tener mínimo 3 caracteres',
      );
      return;
    }
    final nuevaPass =
        passwordController.text.trim();
    if (nuevaPass.isNotEmpty &&
        nuevaPass.length < 6) {
      mostrarMensaje(
        'La contraseña debe tener mínimo 6 caracteres',
      );
      return;
    }
    setState(() {
      cargando = true;
    });
    try {
      final db = FirebaseFirestore.instance;
      final repetido = await db
          .collection('users')
          .where(
            'userName',
            isEqualTo: usuario,
          )
          .get();
      if (repetido.docs.any(
        (d) => d.id != id,
      )) {
        mostrarMensaje(
          'Ese usuario ya existe',
        );
        if (mounted) {
          setState(() {
            cargando = false;
          });
        }
        return;
      }

      final data = <String, dynamic>{
        'name': nombreController.text.trim(),
        'lastName': apellidoController.text.trim(),
        'userName': usuario,
      };
      if (nuevaPass.isNotEmpty) {
        data['password'] = nuevaPass;
      }
      if (_puedeEditarRolYSucursales) {
        data['role'] = rol;
        data['id_branches'] = sucursales
            .map(
              (n) => _idPorNombre[n],
            )
            .whereType<String>()
            .map(
              (b) => db
                  .collection('branches')
                  .doc(b),
            )
            .toList();
      }

      await UsersService().updateUser(
        id,
        data,
      );
      if (id == Session.user?.idUser) {
        final doc = await db
            .collection('users')
            .doc(id)
            .get();
        Session.user =
            UserModel.fromDoc(doc);
      }
      if (!mounted) {
        return;
      }
       _nombreOriginal =
          nombreController.text.trim();
      _apellidoOriginal =
          apellidoController.text.trim();
      _usuarioOriginal = usuario;
      _rolOriginal = rol;
      _sucursalesOriginales = [
        ...sucursales,
      ];
      passwordController.clear();
      setState(() {
        cargando = false;
        _verPassword = false;
        editando = false;
      });
      mostrarMensaje(
        'Cambios guardados correctamente',
        exito: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
      mostrarMensaje(
        'Error al guardar: $e',
      );
    }
  }

  Future<void> _cambiarEstado(
    bool value,
  ) async {
    final id = _id;
    if (id == null) {
      return;
    }
    try {
      await UsersService().setStatus(
        id,
        value,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        estado =
            value ? 'activo' : 'inactivo';
        _mensajeEstado = value
            ? 'Usuario activado correctamente'
            : 'Usuario desactivado correctamente';
        _mostrandoMensajeEstado = true;
      });

      Future.delayed(
        const Duration(milliseconds: 2500),
        () {
          if (!mounted) {
            return;
          }
          setState(() {
            _mostrandoMensajeEstado = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mensajeEstado =
            'No se pudo cambiar el estado';

        _mostrandoMensajeEstado = true;
      });

      Future.delayed(
        const Duration(milliseconds: 2500),
        () {
          if (!mounted) {
            return;
          }
          setState(() {
            _mostrandoMensajeEstado = false;
          });
        },
      );
    }
  }

  Future<void> seleccionarSucursales() async {
    final seleccionadas = [
      ...sucursales,
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Sucursales asignadas',
              ),
              content: SizedBox(
                width: 360,
                child: todasLasSucursales.isEmpty
                    ? const Text(
                        'No hay sucursales registradas',
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final sucursal
                              in todasLasSucursales)
                            CheckboxListTile(
                              value: seleccionadas
                                  .contains(sucursal),
                              activeColor: _green,
                              title: Text(
                                sucursal,
                              ),
                              onChanged:
                                  (value) {
                                setDialogState(
                                  () {
                                    if (value ==
                                        true) {
                                      if (!seleccionadas
                                          .contains(
                                        sucursal,
                                      )) {
                                        seleccionadas
                                            .add(
                                          sucursal,
                                        );
                                      }
                                    } else {
                                      seleccionadas
                                          .remove(
                                        sucursal,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancelar',
                  ),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor:
                        Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      sucursales = [
                        ...seleccionadas,
                      ];
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Aceptar',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void mostrarMensaje(
    String mensaje, {
    bool exito = false,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _mensajeGeneral = mensaje;
      _mensajeGeneralExito = exito;
      _mostrandoMensajeGeneral = true;
    });

    Future.delayed(
      const Duration(milliseconds: 2500),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _mostrandoMensajeGeneral = false;
        });
      },
    );
  }

  Widget _mensajeCambios() {
    if (!_mostrandoMensajeGeneral) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity:
          _mostrandoMensajeGeneral ? 1.0 : 0.0,
      duration:
          const Duration(milliseconds: 250),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 250),
        margin:
            const EdgeInsets.only(bottom: 18),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: _mensajeGeneralExito
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFEBEE),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: _mensajeGeneralExito
                ? const Color(0xFFB7DDBA)
                : const Color(0xFFFFC5C5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _mensajeGeneralExito
                  ? Icons.check_circle
                  : Icons.info_outline,
              size: 19,
              color: _mensajeGeneralExito
                  ? _green
                  : _red,
            ),
            const SizedBox(width: 8),
            Text(
              _mensajeGeneral ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _mensajeGeneralExito
                    ? _green
                    : _red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String obtenerIniciales() {
    final nombre =
        nombreController.text.trim();
    final apellido =
        apellidoController.text.trim();
    if (nombre.isEmpty) {
      return '?';
    }
    var iniciales = nombre
        .substring(0, 1)
        .toUpperCase();
    if (apellido.isNotEmpty) {
      iniciales += apellido
          .substring(0, 1)
          .toUpperCase();
    }
    return iniciales;
  }
  String obtenerNombreCompleto() {
    final nombre =
        nombreController.text.trim();
    final apellido =
        apellidoController.text.trim();

    return '$nombre $apellido'.trim();
  }
  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.of(context).size.width;
    final esMovil = width < 700;
    final ruta = widget.isOwnProfile
        ? '/perfil'
        : '/usuarios';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        currentRoute: ruta,
      ),
      drawer: AppDrawer(
        currentRoute: ruta,
      ),
      body: SafeArea(
        child: cargando
            ? const Center(
                child:
                    CircularProgressIndicator(
                  color: _green,
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      esMovil ? 18 : 55,
                  vertical: 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 1000,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment:
                              Alignment.centerLeft,
                          child:
                              _flechaVolver(),
                        ),
                        const SizedBox(
                          height: 18,
                        ),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width:
                                  esMovil
                                      ? 58
                                      : 65,
                              height:
                                  esMovil
                                      ? 58
                                      : 65,
                              decoration:
                                  const BoxDecoration(
                                color:
                                    Color(
                                  0xFFA5D6A7,
                                ),
                                shape:
                                    BoxShape.circle,
                              ),
                              alignment:
                                  Alignment.center,
                              child: Text(
                                obtenerIniciales(),
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.black87,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 14,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    obtenerNombreCompleto(),
                                    style:
                                        TextStyle(
                                      fontSize:
                                          esMovil
                                              ? 16
                                              : 18,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 6,
                                  ),
                                  StatusSwitch(
                                    activo:
                                        estado ==
                                            'activo',
                                    mensajeEstado:
                                        _mensajeEstado,
                                    mostrandoMensajeEstado:
                                        _mostrandoMensajeEstado,
                                    puedeCambiar:
                                        puedeCambiarEstado(),
                                    onChanged:
                                        _cambiarEstado,
                                  ),
                                ],
                              ),
                            ),
                            if (!esMovil)
                              Row(
                                children: [
                                  if (!editando &&
                                      puedeEditar())
                                    EditButton(
                                      onPressed: () {
                                        setState(() {
                                          editando =
                                              true;
                                        });
                                      },
                                    ),
                                ],
                              ),
                          ],
                        ),
                        if (esMovil)
                          Padding(
                            padding:
                                const EdgeInsets.only(
                              top: 18,
                            ),
                            child: Row(
                              children: [
                                if (!editando &&
                                    puedeEditar())
                                  Expanded(
                                    child:
                                        EditButton(
                                      onPressed: () {
                                        setState(() {
                                          editando =
                                              true;
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        const SizedBox(
                          height: 32,
                        ),
                        _mensajeCambios(),

                        const Text(
                          'Información',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),

                        const SizedBox(
                          height: 35,
                        ),
                        if (esMovil)
                          _formularioMovil()
                        else
                          _formularioDesktop(),
                        const SizedBox(
                          height: 30,
                        ),
                        if (editando)
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width:
                                    esMovil
                                        ? 150
                                        : 180,
                                height: 42,
                                child:
                                    GuardarButton(
                                  onPressed:
                                      guardarCambios,
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              SizedBox(
                                width:
                                    esMovil
                                        ? 150
                                        : 180,
                                height: 42,
                                child:
                                    CancelButton(
                                  onPressed:
                                      cancelarEdicion,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _flechaVolver() {
    return Tooltip(
      message: 'Volver',
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
        },
        customBorder:
            const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black26,
            ),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: _green,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _formularioDesktop() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _campo(
                label: 'Nombre',
                controller:
                    nombreController,
              ),
              const SizedBox(
                height: 18,
              ),
              _campo(
                label: 'Usuario',
                controller:
                    usuarioController,
              ),
              const SizedBox(
                height: 18,
              ),
              _campoRol(),
            ],
          ),
        ),

        const SizedBox(
          width: 70,
        ),
        Expanded(
          child: Column(
            children: [
              _campo(
                label: 'Apellido',
                controller:
                    apellidoController,
              ),
              const SizedBox(
                height: 18,
              ),
              _campo(
                label:
                    'Restablecer contraseña',
                controller:
                    passwordController,
                esPassword: true,
                hintText: '••••••••',
              ),
              const SizedBox(
                height: 18,
              ),

              _campoSucursales(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formularioMovil() {
    return Column(
      children: [
        _campo(
          label: 'Nombre',
          controller:
              nombreController,
        ),
        const SizedBox(
          height: 16,
        ),
        _campo(
          label: 'Apellido',
          controller:
              apellidoController,
        ),
        const SizedBox(
          height: 16,
        ),
        _campo(
          label: 'Usuario',
          controller:
              usuarioController,
        ),
        const SizedBox(
          height: 16,
        ),
        _campo(
          label:
              'Restablecer contraseña',
          controller:
              passwordController,
          esPassword: true,
          hintText: '••••••••',
        ),
        const SizedBox(
          height: 16,
        ),
        _campoRol(),
        const SizedBox(
          height: 16,
        ),
        _campoSucursales(),
      ],
    );
  }

  Widget _campo({
    required String label,
    required TextEditingController
        controller,
    bool esPassword = false,
    String? hintText,
  }) {
    OutlineInputBorder borde(
      Color color, [
      double width = 1,
    ]) {
      return OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: BorderSide(
          color: color,
          width: width,
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        TextField(
          controller: controller,
          enabled: editando,
          obscureText:
              esPassword && !_verPassword,
          decoration: InputDecoration(
            hintText: hintText,

            suffixIcon: esPassword
                ? IconButton(
                    icon: Icon(
                      _verPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.black54,
                    ),
                    onPressed: editando
                        ? () {
                            setState(() {
                              _verPassword =
                                  !_verPassword;
                            });
                          }
                        : null,
                  )
                : null,
            filled: true,
            fillColor: editando
                ? Colors.white
                : const Color(0xFFF8F8F8),
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: borde(
              const Color(0xFFBDBDBD),
            ),
            enabledBorder: borde(
              const Color(0xFFBDBDBD),
            ),
            disabledBorder: borde(
              const Color(0xFFBDBDBD),
            ),
            focusedBorder: borde(
              _green,
              1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoRol() {
    final habilitado =
        editando &&
        _puedeEditarRolYSucursales;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Rol',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(
          height: 7,
        ),
        DropdownButtonFormField<String>(
          initialValue: rol,
          decoration: InputDecoration(
            filled: true,
            fillColor: habilitado
                ? Colors.white
                : const Color(0xFFF8F8F8),
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
              borderSide:
                  const BorderSide(
                color: Color(0xFFBDBDBD),
              ),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Administrador',
              child: Text(
                'Administrador',
              ),
            ),
            DropdownMenuItem(
              value: 'Supervisor',
              child: Text(
                'Supervisor',
              ),
            ),
            DropdownMenuItem(
              value: 'Empleado',
              child: Text(
                'Empleado',
              ),
            ),
          ],
          onChanged: habilitado
              ? (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    rol = value;
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _campoSucursales() {
    final habilitado =
        editando &&
        _puedeEditarRolYSucursales;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Sucursales',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(
          height: 7,
        ),
        InkWell(
          onTap: habilitado
              ? seleccionarSucursales
              : null,
          borderRadius:
              BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: habilitado
                  ? Colors.white
                  : const Color(0xFFF8F8F8),
              border: Border.all(
                color:
                    const Color(0xFFBDBDBD),
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: sucursales.isEmpty
                      ? const Text(
                          'Sin sucursales asignadas',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            for (final sucursal
                                in sucursales)
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFE8F5E9,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    15,
                                  ),
                                ),
                                child: Text(
                                  sucursal,
                                  style:
                                      const TextStyle(
                                    fontSize: 12,
                                    color:
                                        _green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                if (habilitado)
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
