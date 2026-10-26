import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const Color _accent = Color.fromARGB(255, 99, 183, 196);
const Color _borderGrey = Color(0xFFE0E0E0);
const Color _ink = Color(0xFF2B2F33);
const Color _cancel = Color(0xFFFF5722);

const String _storeSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path fill="#2B2F33" d="M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z"/>'
    '</svg>';

class BranchTicket {
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> branch,
    int? users,
    int? products,
    String lastSale = '—',
  }) async {
    int? usersReal = users;
    int? productsReal = products;
    String lastSaleReal = lastSale;
    try {
      final id = _text(branch['id']);
      if (id.isNotEmpty) {
        final db = FirebaseFirestore.instance;
        final branchRef = db.collection('branches').doc(id);
        if (usersReal == null) {
          final usersSnapshot = await db.collection('users').get();
          usersReal = usersSnapshot.docs.where((doc) {
            final data = doc.data();
            return _belongsToBranch(
              data['id_branches'],
              id,
              branchRef,
            );
          }).length;
        }
        if (productsReal == null) {
          final inventorySnapshot =
              await db.collection('inventory').get();
          final matchingInventory =
              inventorySnapshot.docs.where((doc) {
            final data = doc.data();
            return _belongsToBranch(
                  data['id_branch'],
                  id,
                  branchRef,
                ) ||
                _belongsToBranch(
                  data['id_branches'],
                  id,
                  branchRef,
                ) ||
                _belongsToBranch(
                  data['branch_id'],
                  id,
                  branchRef,
                ) ||
                _belongsToBranch(
                  data['id_sucursal'],
                  id,
                  branchRef,
                ) ||
                _belongsToBranch(
                  data['branch'],
                  id,
                  branchRef,
                );
          }).toList();
          productsReal = matchingInventory.length;
        }
        if (lastSaleReal == '—') {
          final salesSnapshot = await db.collection('sales').get();
          final matchingSales = salesSnapshot.docs.where((doc) {
            final data = doc.data();
            return _belongsToBranch(
              data['id_branches'],
              id,
              branchRef,
            );
          }).toList();
          matchingSales.sort((a, b) {
            final dateA = _dateValue(a.data()['sale_data']);
            final dateB = _dateValue(b.data()['sale_data']);
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });
          if (matchingSales.isNotEmpty) {
            final date = _dateValue(
              matchingSales.first.data()['sale_data'],
            );
            if (date != null) {
              lastSaleReal = _formatLastSale(date);
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Error consultando datos del ticket: $error');
    }
    if (!context.mounted) return;
    final data = _TicketData.from(
      branch,
      users: usersReal,
      products: productsReal,
      lastSale: lastSaleReal,
    );
    await showDialog<void>(
      context: context,
      builder: (_) => _TicketDialog(data: data),
    );
  }
}
String _text(dynamic value) => (value ?? '').toString().trim();
bool _belongsToBranch(
  dynamic value,
  String branchId,
  DocumentReference<Map<String, dynamic>> branchRef,
) {
  if (value == null) return false;
  if (value is DocumentReference) {
    return value.path == branchRef.path || value.id == branchId;
  }
  if (value is String) {
    final normalized = value.trim();
    return normalized == branchId ||
        normalized == branchRef.path;
  }
  if (value is List) {
    return value.any(
      (item) => _belongsToBranch(item, branchId, branchRef),
    );
  }
  if (value is Map) {
    final possibleId = value['id'] ??
        value['id_branch'] ??
        value['id_branches'] ??
        value['id_sucursal'];
    if (possibleId != null) {
      return _belongsToBranch(
        possibleId,
        branchId,
        branchRef,
      );
    }
  }
  return false;
}

DateTime? _dateValue(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatLastSale(DateTime date) {
  String two(int number) => number.toString().padLeft(2, '0');
  final now = DateTime.now();
  final sameDay = date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
  final dateText =
      '${two(date.day)}/${two(date.month)}/${date.year}';
  final timeText = '${two(date.hour)}:${two(date.minute)}';
  return sameDay ? 'Hoy $timeText' : '$dateText $timeText';
}

class _TicketData {
  final String name;
  final String logo;
  final String fileName;
  final String issuedAt;
  final List<MapEntry<String, String>> rows;
  const _TicketData({
    required this.name,
    required this.logo,
    required this.fileName,
    required this.issuedAt,
    required this.rows,
  });
  static String _s(dynamic value) =>
      (value ?? '').toString().trim();
  factory _TicketData.from(
    Map<String, dynamic> branch, {
    int? users,
    int? products,
    required String lastSale,
  }) {
    final id = _s(branch['id']);
    final name = _s(branch['branch_name']).isEmpty
        ? 'Sin nombre'
        : _s(branch['branch_name']);
    final code = _s(branch['branch_code']).isNotEmpty
        ? _s(branch['branch_code'])
        : 'SUC-${id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}';
    final address = _s(branch['branch_address']).isEmpty
        ? '—'
        : _s(branch['branch_address']);
    final phone = _s(branch['phone_number']).isEmpty
        ? '—'
        : _s(branch['phone_number']);
    final manager = _s(branch['branch_manager']);
    final active = branch['branch_status'] == true;
    final now = DateTime.now();
    String two(int number) => number.toString().padLeft(2, '0');
    final issued =
        '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return _TicketData(
      name: name,
      logo: _s(branch['branch_logo']),
      fileName:
          'comprobante_${slug.isEmpty ? 'sucursal' : slug}.pdf',
      issuedAt: issued,
      rows: [
        MapEntry('Clave de sucursal:', code),
        if (manager.isNotEmpty)
          MapEntry('Encargado:', manager),
        MapEntry('Estado:', active ? 'ACTIVA' : 'INACTIVA'),
        MapEntry('Dirección:', address),
        MapEntry('Teléfono:', phone),
        MapEntry(
          'Empleados asignados:',
          users == null ? '—' : '$users',
        ),
        MapEntry(
          'Productos registrados:',
          products == null ? '—' : '$products',
        ),
        MapEntry('Última venta:', lastSale),
        MapEntry('Fecha de emisión:', issued),
      ],
    );
  }
}

Future<pw.ImageProvider?> _loadLogo(String logo) async {
  final value = logo.trim();
  if (value.isEmpty) return null;
  try {
    if (value.startsWith('data:image')) {
      return pw.MemoryImage(
        base64Decode(value.split(',').last),
      );
    }
    return await networkImage(value);
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _buildPdf(_TicketData data) async {
  pw.Font base;
  pw.Font bold;
  try {
    base = await PdfGoogleFonts.nunitoRegular();
    bold = await PdfGoogleFonts.nunitoBold();
  } catch (_) {
    base = pw.Font.helvetica();
    bold = pw.Font.helveticaBold();
  }
  final logo = await _loadLogo(data.logo);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: base,
      bold: bold,
    ),
  );
  pw.Widget line() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 7),
        child: pw.Divider(
          thickness: 0.6,
          color: PdfColors.grey500,
        ),
      );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: logo != null
                ? pw.SizedBox(
                    width: 120,
                    height: 56,
                    child: pw.Image(
                      logo,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                : pw.SizedBox(
                    width: 30,
                    height: 30,
                    child: pw.SvgImage(svg: _storeSvg),
                  ),
          ),
          pw.SizedBox(height: 7),
          pw.Text(
            'PUNTO DE VENTA',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              fontSize: 13,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Text(
            data.name.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'COMPROBANTE DE SUCURSAL',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          line(),
          for (final row in data.rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      row.key,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 8,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      row.value,
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          line(),
          pw.Text(
            'Comprobante informativo de la sucursal',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 5),
        ],
      ),
    ),
  );
  return doc.save();
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog({
    required this.data,
  });

  final _TicketData data;

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}
class _TicketDialogState extends State<_TicketDialog> {
  bool _busy = false;
  Future<void> _run(
    Future<void> Function(Uint8List bytes) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdf(widget.data);
      await action(bytes);
    } catch (error) {
      debugPrint('Error con el PDF del comprobante: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar el comprobante.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _printTicket() => _run(
        (bytes) async {
          await Printing.layoutPdf(
            name: widget.data.fileName,
            format: PdfPageFormat.roll80,
            onLayout: (_) async => bytes,
          );
        },
      );
  Widget _logo() {
    const fallback = Icon(
      Icons.storefront_outlined,
      size: 32,
      color: _ink,
    );
    final value = widget.data.logo.trim();
    if (value.isEmpty) return fallback;
    if (value.startsWith('data:image')) {
      try {
        return SizedBox(
          width: 120,
          height: 64,
          child: Image.memory(
            base64Decode(value.split(',').last),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => fallback,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }
    return SizedBox(
      width: 120,
      height: 64,
      child: Image.network(
        value,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFF9E9E9E),
        ),
      );

  Widget _ticket() {
    final data = widget.data;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _borderGrey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          _logo(),
          const SizedBox(height: 10),
          const Text(
            'PUNTO DE VENTA',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comprobante de sucursal',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _ink,
            ),
          ),
          _divider(),
          for (final row in data.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      row.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _divider(),
          const Text(
            'Comprobante informativo de la sucursal',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: _accent.withValues(alpha: 0.12),
          side: const BorderSide(
            color: _accent,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: _ticket(),
                ),
              ),
              const SizedBox(height: 14),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(
                    color: _accent,
                    backgroundColor: Color(0xFFE0F4F7),
                    minHeight: 3,
                  ),
                ),
              _actionButton(
                icon: Icons.print_outlined,
                label: 'Imprimir ticket',
                onPressed: _busy ? null : _printTicket,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: ButtonStyle(
                    foregroundColor:
                        const WidgetStatePropertyAll(_cancel),
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
                      final pressed =
                          states.contains(WidgetState.pressed);
                      return BorderSide(
                        color: pressed
                            ? _cancel.withValues(alpha: 0.25)
                            : _cancel,
                        width: 1.2,
                      );
                    }),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
