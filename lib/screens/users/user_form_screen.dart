
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_services.dart';
import '../../widgets/app_header.dart';
import '../../widgets/primary_button.dart';


const _green = Color(0xFF0F6B1F);

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();

 Set<String> _branchIds = {};
bool _loading = false;
bool _verPassword = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }



  Future<bool> _confirmar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: const Text('Registrar usuario'),
        content: Text(
          '¿Deseas registrar a ${_nameCtrl.text.trim()} '
          '${_lastNameCtrl.text.trim()} con el rol ${_roleCtrl.text.trim()}?',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    return ok ?? false;
  }

  Future<void> _exito() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Icon(
              Icons.check_circle,
              color: _green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Usuario registrado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'El usuario ya puede iniciar sesión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 16),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 14,
              ),
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirSucursales(
    Map<String, String> nombres,
    FormFieldState<Set<String>> state,
  ) async {
    final temp = {..._branchIds};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Selecciona las sucursales'),
          content: SizedBox(
            width: 380,
            child: nombres.isEmpty
                ? const Text('No hay sucursales registradas')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in nombres.entries)
                        CheckboxListTile(
                          value: temp.contains(e.key),
                          activeColor: _green,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                          title: Text(e.value),
                          onChanged: (v) {
                            setD(() {
                              if (v == true) {
                                temp.add(e.key);
                              } else {
                                temp.remove(e.key);
                              }
                            });
                          },
                        ),
                    ],
                  ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => _branchIds = temp);
      state.didChange(temp);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmar()) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await UsersService().createUser(
        name: _nameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        userName: _userCtrl.text,
        password: _passCtrl.text.trim(),
        role: _roleCtrl.text.trim(),
        branchIds: _branchIds.toList(),
      );
      if (!mounted) return;
      await _exito();
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensaje = 'Error al registrar: ${e.code}';
      if (e.code == 'email-already-in-use') {
        mensaje = 'Ese usuario ya existe';
      }
      if (e.code == 'weak-password') {
        mensaje = 'La contraseña debe tener mínimo 6 caracteres';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;
  InputDecoration _deco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black38,
        fontSize: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 20,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(
          color: _green,
          width: 1.6,
        ),
      ),
    );
  }

  Widget _etiqueta(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }

 Widget _campo(
  String label,
  TextEditingController ctrl,
  String hint, {
  bool esPassword = false,
  List<TextInputFormatter>? formatters,
  String? Function(String?)? validator,
  TextCapitalization capitalization = TextCapitalization.none,
}) {
  return _etiqueta(
    label,
    TextFormField(
      controller: ctrl,
      obscureText: esPassword && !_verPassword,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      validator: validator ?? _req,
      style: const TextStyle(fontSize: 16),
      decoration: _deco(hint).copyWith(
        suffixIcon: esPassword
            ? IconButton(
                icon: Icon(
                  _verPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.black54,
                ),
                onPressed: () {
                  setState(() {
                    _verPassword = !_verPassword;
                  });
                },
              )
            : null,
      ),
    ),
  );
}

  Widget _rolField() {
    return _etiqueta(
      'Rol',
      DropdownButtonFormField<String>(
       initialValue: _roleCtrl.text.isEmpty ? null : _roleCtrl.text,
        decoration: _deco('Selecciona el rol'),
        items: const [
          DropdownMenuItem(
            value: 'Administrador',
            child: Text('Administrador'),
          ),
          DropdownMenuItem(
            value: 'Empleado',
            child: Text('Empleado'),
          ),
          DropdownMenuItem(
            value: 'Supervisor',
            child: Text('Supervisor'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            _roleCtrl.text = value;
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Selecciona un rol';
          }

          return null;
        },
        icon: const Icon(
          Icons.arrow_drop_down,
          color: Colors.black54,
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _sucursalField() {
    return _etiqueta(
      'Sucursales',
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('branches')
            .where(
              'branch_status',
              isEqualTo: true,
            )
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint(
              'Error branches: ${snap.error}',
            );
            return Text(
              'Error al cargar sucursales: ${snap.error}',
              style: const TextStyle(
                color: Colors.red,
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          final nombres = <String, String>{
            for (final d in snap.data?.docs ?? [])
              d.id:
                  '${(d.data() as Map<String, dynamic>)['branch_name'] ?? d.id}',
          };
          return FormField<Set<String>>(
            initialValue: _branchIds,
            autovalidateMode:
                AutovalidateMode.onUserInteraction,
            validator: (_) =>
                _branchIds.isEmpty
                    ? 'Selecciona al menos una sucursal'
                    : null,
            builder: (state) {
              return InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () =>
                    _abrirSucursales(nombres, state),
                child: InputDecorator(
                  isEmpty: false,
                  decoration: _deco('').copyWith(
                    errorText: state.errorText,
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.black54,
                    ),
                  ),
                  child: _branchIds.isEmpty
                      ? const Text(
                          'Selecciona las sucursales',
                          style: TextStyle(
                            color: Colors.black38,
                            fontSize: 16,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final id in _branchIds)
                              Chip(
                                label: Text(
                                  nombres[id] ?? id,
                                ),
                                backgroundColor:
                                    const Color(0xFFC8F7C5),
                                side: const BorderSide(
                                  color: Color(0xFF66BB6A),
                                ),
                                visualDensity:
                                    VisualDensity.compact,
                                onDeleted: () {
                                  final nuevo =
                                      {..._branchIds}..remove(id);
                                  setState(() {
                                    _branchIds = nuevo;
                                  });
                                  state.didChange(nuevo);
                                },
                              ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _flechaVolver(bool wide) {
    final size = wide ? 48.0 : 40.0;

    return Tooltip(
      message: 'Volver a usuarios',
      child: InkWell(
        onTap: _loading
            ? null
            : () => Navigator.pop(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black26,
            ),
          ),
          child: Icon(
            Icons.arrow_back,
            color: _green,
            size: wide ? 26 : 22,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _campo(
      'Nombre',
      _nameCtrl,
      'Escribe tu nombre',
    );
    final apellido = _campo(
      'Apellido',
      _lastNameCtrl,
      'Escribe tus apellidos',
    );
    final usuario = _campo(
      'Usuario',
      _userCtrl,
      'Escribe el usuario (sin espacios)',
      formatters: [
        FilteringTextInputFormatter.deny(
          RegExp(r'\s'),
        ),
      ],
      validator: (v) =>
          (v == null || v.trim().length < 3)
              ? 'Mínimo 3 caracteres'
              : null,
    );
    final pass = _campo(
      'Contraseña',
      _passCtrl,
      '••••••••',
      esPassword: true,
      validator: (v) =>
          (v == null || v.trim().length < 6)
              ? 'Mínimo 6 caracteres'
              : null,
    );
    final rol = _rolField();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(currentRoute: '/usuarios'),
      drawer: AppDrawer(currentRoute: '/usuarios'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 800;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 55 : 20,
                vertical: 28,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1100,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _flechaVolver(wide),
                            ),
                            Text(
                              'Registrar Usuario',
                              style: TextStyle(
                                fontSize: wide ? 38 : 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Completa los datos del nuevo usuario',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (wide)
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    nombre,
                                    usuario,
                                    rol,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 60),
                              Expanded(
                                child: Column(
                                  children: [
                                    apellido,
                                    pass,
                                    _sucursalField(),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              nombre,
                              apellido,
                              usuario,
                              pass,
                              rol,
                              _sucursalField(),
                            ],
                          ),
                        const SizedBox(height: 40),
                        PrimaryButton(
                          text: 'Registrar',
                          onPressed: _guardar,
                          loading: _loading,
                          width: wide
                              ? 420
                              : double.infinity,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
