import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/cash_closure_service.dart';

const Color _bg = Color(0xFF1A1A1A);
const Color _green = Color(0xFF0F6B1F);
const Color _greenText = Color.fromARGB(255, 99, 183, 196);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _loading = false;
  bool _verPassword = false;
  String _mensajeError = '';

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String userName = _userCtrl.text.trim();
    final String password = _passCtrl.text.trim();
    if (userName.isEmpty || password.isEmpty) {
      setState(() {
        _mensajeError = 'Ingresa tu usuario y contraseña';
      });
      return;
    }
    setState(() {
      _loading = true;
      _mensajeError = '';
    });
    try {
      final user = await AuthService().login(
        userName,
        password,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _mensajeError = 'Usuario o contraseña incorrectos';
        });
        return;
      }
      
 final cajaAbierta =
        await CashClosureService().getOpenCashRegister(
      idBranch: user.idBranches.first.id,
      idUser: user.idUser,
    );

    if (!mounted) return;

    if (cajaAbierta != null && !cajaAbierta.statusClosing) {
      // Si ya tiene caja abierta, regresar a ventas.
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/ventas',
        (route) => false,
      );
    } else {
      // Si no tiene caja abierta, iniciar una nueva.
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/start-cash-register',
        (route) => false,
      );
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _mensajeError =
          'Ocurrió un error al iniciar sesión: '
          '${e.toString().replaceFirst('Exception: ', '')}';
    });
  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
  }

  Widget _title({
    bool desktop = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          desktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        RichText(
          textAlign: desktop ? TextAlign.center : TextAlign.left,
          text: TextSpan(
            style: TextStyle(
              fontSize: desktop ? 46 : 32,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            children: const [
              TextSpan(
                text: 'Punto ',
              ),
              TextSpan(
                text: 'de Venta',
                style: TextStyle(
                  color: _greenText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tu negocio, más cerca de tus clientes',
          textAlign: desktop ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white70,
            fontSize: desktop ? 17 : 13,
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    IconData icon,
    String hint,
    TextEditingController controller, {
    bool obscure = false,
    bool desktop = false,
  }) {
    final double fieldHeight = desktop ? 64.0 : 54.0;
    final double labelSize = desktop ? 19.0 : 17.0;
    final double textSize = desktop ? 17.0 : 15.0;
    final double hintSize = desktop ? 16.0 : 14.0;
    final double iconSize = desktop ? 25.0 : 21.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: fieldHeight,
          child: TextField(
            controller: controller,
            obscureText: obscure ? !_verPassword : false,
            onSubmitted: (_) {
              if (obscure && !_loading) {
                _login();
              }
            },
            style: TextStyle(
              color: Colors.white,
              fontSize: textSize,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: _greenText,
                size: iconSize,
              ),
              suffixIcon: obscure
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _verPassword = !_verPassword;
                        });
                      },
                      icon: Icon(
                        _verPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: _greenText,
                        size: iconSize,
                      ),
                    )
                  : null,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white38,
                fontSize: hintSize,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.025),
              contentPadding: EdgeInsets.symmetric(
                horizontal: desktop ? 22 : 18,
                vertical: 0,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Colors.white24,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: _greenText,
                  width: 1.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _form({
    bool desktop = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mensajeError.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF3A1717),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF8B3A3A),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF8A80),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _mensajeError,
                    style: const TextStyle(
                      color: Color(0xFFFFB4AB),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
        Text(
          'Bienvenido',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: desktop ? 40 : 30,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          height: desktop ? 32 : 24,
        ),
        _field(
          'Usuario',
          Icons.person_outline,
          'usuario',
          _userCtrl,
          desktop: desktop,
        ),
        SizedBox(
          height: desktop ? 22 : 16,
        ),
        _field(
          'Contraseña',
          Icons.lock_outline,
          '••••••••',
          _passCtrl,
          obscure: true,
          desktop: desktop,
        ),
        SizedBox(
          height: desktop ? 34 : 28,
        ),
        SizedBox(
          height: desktop ? 62 : 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              disabledBackgroundColor: _green.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? SizedBox(
                    width: desktop ? 25 : 21,
                    height: desktop ? 25 : 21,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Iniciar sesión',
                    style: TextStyle(
                      fontSize: desktop ? 19 : 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _desktopLayout(
    BoxConstraints constraints,
  ) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1500,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 80,
              vertical: 40,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _title(
                        desktop: true,
                      ),
                      const SizedBox(height: 35),
                      Image.asset(
                        'assets/logo.png',
                        width: 500,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 100),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 560,
                      ),
                      child: _form(
                        desktop: true,
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
  }

  Widget _mobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 30,
        ),
        child: Column(
          children: [
            _title(),
            const SizedBox(height: 22),
            Image.asset(
              'assets/logo.png',
              width: 190,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            _form(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final bool isWide = constraints.maxWidth >= 800;
            if (isWide) {
              return _desktopLayout(constraints);
            }
            return _mobileLayout();
          },
        ),
      ),
    );
  }
}