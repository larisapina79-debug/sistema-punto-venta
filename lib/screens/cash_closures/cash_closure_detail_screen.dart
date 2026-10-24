import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/cash_closure_model.dart';
import '../../services/cash_closure_service.dart';

const Color primary = Color(0xFF61B8C4);
const Color background = Color(0xFFF5F7F9);
const Color dark = Color(0xFF263238);
const Color muted = Color(0xFF707780);
const Color red = Color(0xFFDC2626);
const Color green = Color(0xFF159A75);

class CashClosureDetailScreen extends StatefulWidget {
  final String closureId;
  const CashClosureDetailScreen({
    super.key,
    required this.closureId,
  });

  @override
  State<CashClosureDetailScreen> createState() =>
      _CashClosureDetailScreenState();
}

class _CashClosureDetailScreenState
    extends State<CashClosureDetailScreen> { 
  final CashClosureService _service = CashClosureService();
  late Future<_DetailData> _future;

@override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final closure =
        await _service.getCashClosureById(widget.closureId);
    if (closure == null) {
      throw Exception('No se encontró el cierre seleccionado.');
    }

    final results = await Future.wait<dynamic>([
      _service.calculatePaymentMethodSummary(closure.idClosure),
      _loadBranchInfo(closure.idBranch),
    ]);

    return _DetailData(
      closure: closure,
      payments: Map<String, double>.from(results[0] as Map),
      branchName: (results[1] as _BranchInfo).name,
      branchImageUrl: (results[1] as _BranchInfo).imageUrl,
    );
  }

  Future<_BranchInfo> _loadBranchInfo(String branchId) async {
    final db = FirebaseFirestore.instance;
    for (final collectionName in ['branches', 'sucursales']) {
      try {
        final doc =
            await db.collection(collectionName).doc(branchId).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          return _BranchInfo(
            name: _firstString(data, [
                  'branch_name',
                  'branchName',
                  'name',
                  'nombre',
                  'sucursal',
                ]) ??
                'Sucursal',
            imageUrl: _firstString(data, [
              'branch_logo',
              'image_url',
              'imageUrl',
              'photo_url',
              'photoUrl',
              'logo_url',
              'logoUrl',
              'imagen',
              'imagen_url',
              'foto',
              'logo',
              'image',
            ]),
          );
        }
      } catch (_) {}
    }
    for (final collectionName in ['branches', 'sucursales']) {
      try {
        final query = await db
            .collection(collectionName)
            .where('id', isEqualTo: branchId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          return _BranchInfo(
            name: _firstString(data, [
                  'branch_name',
                  'branchName',
                  'name',
                  'nombre',
                  'sucursal',
                ]) ??
                'Sucursal',
            imageUrl: _firstString(data, [
              'branch_logo',
              'image_url',
              'imageUrl',
              'photo_url',
              'photoUrl',
              'logo_url',
              'logoUrl',
              'imagen',
              'imagen_url',
              'foto',
              'logo',
              'image',
            ]),
          );
        }
      } catch (_) {}
    }

    return const _BranchInfo(
      name: 'Sucursal',
      imageUrl: null,
    );
  }
  String? _firstString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  String _money(double value) {
    final negative = value < 0;
    final parts = value.abs().toStringAsFixed(2).split('.');
    final digits = parts[0];
    final formatted = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      formatted.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        formatted.write(',');
      }
    }
    return '${negative ? '-' : ''}\$${formatted.toString()}.${parts[1]}';
  }

  String _date(DateTime? date) {
    if (date == null) return 'Pendiente';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Resumen de caja',
              style: TextStyle(
                color: dark,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Consulta los movimientos y el estado de tu caja',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primary),
      ),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudo cargar el detalle.',
                      style: TextStyle(
                        color: dark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 850
                  ? 850.0
                  : double.infinity;
              return Center(
                child: SizedBox(
                  width: width,
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: primary,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _header(data),
                        const SizedBox(height: 14),
                        _initial(data.closure),
                        const SizedBox(height: 14),
                        _payments(data),
                        const SizedBox(height: 14),
                        _closing(data.closure),
                        const SizedBox(height: 14),
                        _comments(data.closure),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _header(_DetailData data) {
    final c = data.closure;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE8EDF1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 64,
                  height: 64,
                  color: primary.withAlpha(30),
                  child: data.branchImageUrl != null
                      ? Image.network(
                          data.branchImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: primary,
                              size: 32,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: primary,
                            size: 32,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen de caja',
                      style: TextStyle(
                        color: dark,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Sucursal: ${data.branchName}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Apertura: ${_date(c.openingDate)}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cierre: ${_date(c.closingDate)}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.statusClosing
                          ? green.withAlpha(25)
                          : Colors.orange.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      c.statusClosing ? 'Cerrada' : 'Abierta',
                      style: TextStyle(
                        color: c.statusClosing
                            ? green
                            : Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initial(CashClosureModel c) {
    final configured = c.configuredInitialCash;
    final hasConfiguredAmount = configured != null;
    final matchesConfigured = hasConfiguredAmount &&
        (c.initialCash * 100).round() ==
            (configured * 100).round();
    final initialColor = !hasConfiguredAmount
        ? primary
        : matchesConfigured
            ? green
            : red;
    final statusText = !hasConfiguredAmount
        ? 'No hay importe configurado para comparar'
        : matchesConfigured
            ? 'El importe coincide con lo configurado'
            : 'El importe no coincide con lo configurado';
    final statusColor = !hasConfiguredAmount
        ? muted
        : matchesConfigured
            ? green
            : red;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Efectivo inicial'),
          const SizedBox(height: 18),
          _row(
            'Importe de apertura',
            _money(c.initialCash),
            prominent: true,
            valueColor: initialColor,
          ),
          if (hasConfiguredAmount) ...[
            const SizedBox(height: 12),
            _row(
              'Importe configurado',
              _money(configured),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor.withAlpha(55),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasConfiguredAmount && matchesConfigured
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _payments(_DetailData data) {
    final entries = data.payments.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Ventas por método de pago'),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const Text(
              'No hay ventas registradas para este cierre.',
              style: TextStyle(color: muted),
            )
          else
            ...entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: dark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _money(entry.value),
                      style: const TextStyle(
                        color: dark,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 24),
          _row('Número de ventas', '${data.closure.saleCount}'),
          const SizedBox(height: 10),
          _row(
            'Total de ventas',
            _money(data.closure.totalSale),
            prominent: true,
          ),
        ],
      ),
    );
  }

  Widget _closing(CashClosureModel c) {
    final difference = c.difference;
    final balanced = difference == 0;
    final shortage = difference < 0;
    final color = balanced
        ? green
        : shortage
            ? red
            : Colors.orange.shade800;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Efectivo final'),
          const SizedBox(height: 18),
          _row('Efectivo inicial', _money(c.initialCash)),
          const SizedBox(height: 12),
          _row('Ventas en efectivo', _money(c.cashSale)),
          const Divider(height: 28),
          _row(
            'Efectivo esperado',
            _money(c.expectedCash),
            prominent: true,
          ),
          const SizedBox(height: 12),
          _row(
            'Efectivo contado',
            _money(c.recordedCash),
            prominent: true,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  balanced
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    balanced
                        ? 'Caja cuadrada'
                        : shortage
                            ? 'Faltante de efectivo'
                            : 'Sobrante de efectivo',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _money(difference),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comments(CashClosureModel c) {
    final initial = (c.initialCashComment ?? '').trim();
    final closing = (c.closingComment ?? '').trim();
    if (initial.isEmpty && closing.isEmpty) {
      return const SizedBox.shrink();
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Comentarios'),
          if (initial.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Comentario de apertura',
              style: TextStyle(
                color: dark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              initial,
              style: const TextStyle(
                color: muted,
                height: 1.5,
              ),
            ),
          ],
          if (closing.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Comentario de cierre',
              style: TextStyle(
                color: dark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              closing,
              style: const TextStyle(
                color: muted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: dark,
        fontWeight: FontWeight.w700,
        fontSize: 17,
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool prominent = false,
    Color valueColor = dark,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: prominent ? dark : muted,
              fontSize: prominent ? 15 : 14,
              fontWeight:
                  prominent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: prominent ? 18 : 15,
            fontWeight:
                prominent ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE8EDF1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BranchInfo {
  final String name;
  final String? imageUrl;
  const _BranchInfo({
    required this.name,
    required this.imageUrl,
  });
}

class _DetailData {
  final CashClosureModel closure;
  final Map<String, double> payments;
  final String branchName;
  final String? branchImageUrl;
  const _DetailData({
    required this.closure,
    required this.payments,
    required this.branchName,
    required this.branchImageUrl,
  });
}
