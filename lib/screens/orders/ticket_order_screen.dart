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
const Color _paidGreen = Color(0xFF2E7D32);
const String _storeSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path fill="#2B2F33" d="M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z"/>'
    '</svg>';

class OrderTicket {
  static Future<void> show(
    BuildContext context, {
    required String orderId,
    Map<String, dynamic>? order,
  }) async {
    _TicketData? data;
    try {
      final db = FirebaseFirestore.instance;
      var orderData = order ?? <String, dynamic>{};
      if (orderData.isEmpty) {
        final doc = await db.collection('orders').doc(orderId).get();
        orderData = doc.data() ?? <String, dynamic>{};
      }
      if (orderData.isEmpty) {
        throw Exception('Pedido no encontrado');
      }
      final branchId = _refId(orderData['id_branches']);
      var branch = <String, dynamic>{};
      if (branchId.isNotEmpty) {
        final doc = await db.collection('branches').doc(branchId).get();
        branch = doc.data() ?? <String, dynamic>{};
      }
      data = _TicketData.from(orderData, branch);
    } catch (error) {
      debugPrint('Error consultando datos del ticket de pedido: $error');
    }
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el ticket.'),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _TicketDialog(data: data!),
    );
  }
}

String _text(dynamic value) => (value ?? '').toString().trim();
String _refId(dynamic value) {
  if (value == null) return '';
  if (value is DocumentReference) {
    return value.id;
  }
  if (value is Map) {
    return _refId(
      value['id'] ??
          value['id_branch'] ??
          value['id_branches'] ??
          value['id_sucursal'],
    );
  }
  final text = _text(value);
  if (text.contains('/')) {
    return text.split('/').last;
  }
  return text;
}
double _num(dynamic value) {
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(
    _text(value).replaceAll(',', ''),
  );
  return parsed ?? 0;
}
String _money(num value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts[0];
  final formattedInteger = integer.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = value < 0 ? '-' : '';
  return '$sign\$$formattedInteger.${parts[1]}';
}
String _qty(dynamic value) {
  final d = _num(value);
  return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}
DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
String _two(int n) => n.toString().padLeft(2, '0');
String _fmtDate(DateTime? d) {
  return d == null ? '—' : '${_two(d.day)}/${_two(d.month)}/${d.year}';
}
String _fmtDateTime(DateTime d) {
  return '${_fmtDate(d)} ${_two(d.hour)}:${_two(d.minute)}';
}
String _normalizeStatus(String raw) {
  final status = raw.trim().toLowerCase();
  if (status.contains('entregado')) return 'entregado';
  if (status.contains('cancelado')) return 'cancelado';
  return 'pendiente';
}
String _statusLabel(String raw) {
  switch (_normalizeStatus(raw)) {
    case 'entregado':
      return 'ENTREGADO';
    case 'cancelado':
      return 'CANCELADO';
    default:
      return 'PENDIENTE';
  }
}
String _paymentName(dynamic value) {
  if (value == null) return '';
  if (value is Map) {
    return _text(
      value['payment_methods_name'] ??
          value['payment_method_name'] ??
          value['method_name'] ??
          value['name'] ??
          value['nombre'] ??
          value['payment_method'],
    );
  }
  return _text(value);
}
String _paymentMethodsLabel(
  dynamic methods, {
  dynamic fallback,
}) {
  final result = <String>[];
  if (methods is List) {
    for (final item in methods) {
      if (item is Map) {
        final name = _paymentName(item);
        if (name.isEmpty) continue;
        final amount = _num(
          item['amount'] ?? item['payment_amount'] ?? item['paid_amount'],
        );
        final amountText = amount > 0 ? ' ${_money(amount)}' : '';
        result.add('$name$amountText');
      } else {
        final name = _paymentName(item);
        if (name.isNotEmpty) {
          result.add(name);
        }
      }
    }
  } else if (methods is Map) {
    final name = _paymentName(methods);
    if (name.isNotEmpty) {
      final amount = _num(
        methods['amount'] ??
            methods['payment_amount'] ??
            methods['paid_amount'],
      );
      result.add(
        amount > 0 ? '$name ${_money(amount)}' : name,
      );
    }
  } else {
    final name = _paymentName(methods);
    if (name.isNotEmpty) {
      result.add(name);
    }
  }
  if (result.isEmpty && fallback != null) {
    final fallbackLabel = _paymentMethodsLabel(fallback);
    if (fallbackLabel != 'No especificada') {
      result.add(fallbackLabel);
    }
  }
  if (result.isEmpty) {
    return 'No especificada';
  }
  return result.join('\n');
}

class _TicketLine {
  final String name;
  final String detail;
  final String total;
  const _TicketLine({
    required this.name,
    required this.detail,
    required this.total,
  });
}

class _TicketAmount {
  final String label;
  final String value;
  final bool big;
  final String tone;
  const _TicketAmount(
    this.label,
    this.value, {
    this.big = false,
    this.tone = 'normal',
  });
}

class _TicketData {
  final String branchName;
  final String branchLogo;
  final String branchPhone;
  final String fileName;
  final List<MapEntry<String, String>> rows;
  final List<_TicketLine> lines;
  final List<_TicketAmount> amounts;
  final List<MapEntry<String, String>> paymentRows;
  final String footer;
  final String observations;
  const _TicketData({
    required this.branchName,
    required this.branchLogo,
    required this.branchPhone,
    required this.fileName,
    required this.rows,
    required this.lines,
    required this.amounts,
    required this.paymentRows,
    required this.footer,
    required this.observations,
  });
  factory _TicketData.from(
    Map<String, dynamic> order,
    Map<String, dynamic> branch,
  ) {
    final branchName = _text(branch['branch_name']).isEmpty
        ? 'Sucursal'
        : _text(branch['branch_name']);
    final branchLogo = _text(branch['branch_logo']);
    final branchPhone = _text(branch['phone_number']);
    final client = _text(order['client_name']).isEmpty
        ? '—'
        : _text(order['client_name']);
    final status = _normalizeStatus(
      _text(order['order_status']),
    );
    final rawProducts = order['products'];
    final lines = <_TicketLine>[];
    if (rawProducts is List) {
      for (final raw in rawProducts.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final name = _text(item['name_product']);
        lines.add(
          _TicketLine(
            name: name.isEmpty ? 'Producto' : name,
            detail:
                '${_qty(item['quantity_product'])} x ${_money(_num(item['unitPrice_product']))}',
            total: _money(_num(item['total_detailSale'])),
          ),
        );
      }
    }
    final totalAmount = _num(order['total_order']);
    final initialPaymentAmount = _num(order['initial_payment_amount']);
    final history = order['delivery_payment_history'];
    double deliveryPayment = 0;
    if (history is List && history.isNotEmpty) {
      for (final entry in history.whereType<Map>()) {
        final methods = entry['payment_methods'];
        if (methods is List && methods.isNotEmpty) {
          final methodTotal = methods.whereType<Map>().fold<double>(
                0.0,
                (acumulado, method) =>acumulado + _num(method['amount']),
              );
          deliveryPayment +=
              methodTotal > 0 ? methodTotal : _num(entry['amount']);
        } else {
          deliveryPayment += _num(entry['amount']);
        }
      }
    } else {
      deliveryPayment = _num(order['delivery_payment']);
    }
    final hasLiquidation = deliveryPayment > 0.009;
    final paidAmount = initialPaymentAmount > 0
        ? initialPaymentAmount
        : (_num(order['paid_amount']) - deliveryPayment)
            .clamp(0.0, double.infinity)
            .toDouble();
    final totalPaid = paidAmount + deliveryPayment;
    final calculatedBalance =
        (totalAmount - totalPaid).clamp(0.0, double.infinity).toDouble();
    final storedBalance = _num(order['balance_due']);
    final remaining = storedBalance > 0 ? storedBalance : calculatedBalance;
    final isPaid = remaining <= 0;
    final advanceMethods = _paymentMethodsLabel(
      order['initial_payment_methods'],
      fallback: order['payment_method'],
    );
    final liquidationMethods = history is List && history.isNotEmpty
        ? _paymentMethodsLabel(
            [
              for (final entry in history.whereType<Map>())
                if (entry['payment_methods'] is List)
                  ...(entry['payment_methods'] as List)
                else if (_num(entry['amount']) > 0)
                  {
                    'payment_methods_name': 'Forma de pago no especificada',
                    'amount': entry['amount'],
                  },
            ],
            fallback: order['delivery_payment_method'],
          )
        : _paymentMethodsLabel(
            order['delivery_payment_methods'],
            fallback: order['delivery_payment_method'],
          );
    final paymentRows = <MapEntry<String, String>>[];
    if (paidAmount > 0) {
      paymentRows.add(
        MapEntry(
          'ANTICIPO',
          'Importe: ${_money(paidAmount)}\n'
              'Forma de pago:\n$advanceMethods',
        ),
      );
    }
    if (hasLiquidation) {
      paymentRows.add(
        MapEntry(
          'LIQUIDACIÓN',
          'Importe: ${_money(deliveryPayment)}\n'
              'Forma de pago:\n$liquidationMethods',
        ),
      );
    }
    final amounts = <_TicketAmount>[
      _TicketAmount(
        'TOTAL',
        _money(totalAmount),
        big: true,
      ),
    ];
    if (paidAmount > 0) {
      amounts.add(
        _TicketAmount(
          'ANTICIPO',
          _money(paidAmount),
        ),
      );
    }
    if (hasLiquidation) {
      amounts.add(
        _TicketAmount(
          'LIQUIDACIÓN',
          _money(deliveryPayment),
        ),
      );
    }
    amounts.add(
      _TicketAmount(
        'PAGADO',
        _money(totalPaid),
        big: true,
        tone: 'green',
      ),
    );
    amounts.add(
      _TicketAmount(
        'FALTANTE',
        _money(remaining),
        big: true,
        tone: remaining > 0 ? 'red' : 'green',
      ),
    );
    String footer;
    if (status == 'cancelado') {
      amounts.add(
        const _TicketAmount(
          'ESTADO',
          'CANCELADO',
          big: true,
          tone: 'red',
        ),
      );
      footer = 'Pedido cancelado';
    } else if (status == 'entregado') {
      footer = '¡Gracias por tu preferencia!';
    } else {
      footer = isPaid
          ? '¡Gracias por tu preferencia!'
          : 'Presenta este ticket para entregar tu pedido';
    }
    return _TicketData(
      branchName: branchName,
      branchLogo: branchLogo,
      branchPhone: branchPhone,
      fileName: 'ticket_pedido.pdf',
      rows: [
        MapEntry(
          'Fecha del pedido:',
          _fmtDate(_date(order['order_date'])),
        ),
        MapEntry(
          'Fecha de entrega:',
          _fmtDate(_date(order['delivery_date'])),
        ),
        MapEntry('Cliente:', client),
        MapEntry('Estado:', _statusLabel(status)),
        MapEntry(
          'Fecha de emisión:',
          _fmtDateTime(DateTime.now()),
        ),
      ],
      lines: lines,
      amounts: amounts,
      paymentRows: paymentRows,
      footer: footer,
      observations: _text(order['observations_order']),
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
  } catch (error) {
    debugPrint('Error cargando imagen de sucursal: $error');
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
  final logo = await _loadLogo(data.branchLogo);
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
  pw.Widget infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Text(
                label,
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
                value,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        ),
      );
  pw.Widget totalRow(
    String label,
    String value, {
    double size = 9,
    String tone = 'normal',
  }) {
    final color = tone == 'green'
        ? PdfColors.green700
        : tone == 'red'
            ? PdfColors.red700
            : PdfColors.grey900;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: bold,
                fontSize: size,
                color: color,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: bold,
              fontSize: size,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  pw.Widget paymentRow(String label, String value) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey400,
          width: 0.6,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: bold,
              fontSize: 8,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 8,
              lineSpacing: 2,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }
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
          // Logo.
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
            data.branchName.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              fontSize: 13,
            ),
          ),
          if (data.branchPhone.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Tel. ${data.branchPhone}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey800,
              ),
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Text(
            'TICKET DE PEDIDO',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          line(),
          for (final row in data.rows) infoRow(row.key, row.value),
          line(),
          pw.Text(
            'PRODUCTOS',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              fontSize: 9,
            ),
          ),
          pw.SizedBox(height: 4),
          if (data.lines.isEmpty)
            pw.Text(
              'Sin productos',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          for (final item in data.lines)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.name,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 8,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          item.detail,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                      pw.Text(
                        item.total,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          line(),
          if (data.paymentRows.isNotEmpty) ...[
            pw.Text(
              'FORMAS DE PAGO',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: bold,
                fontSize: 9,
              ),
            ),
            pw.SizedBox(height: 6),
            for (final payment in data.paymentRows)
              paymentRow(payment.key, payment.value),
            line(),
          ],
          for (final amount in data.amounts)
            totalRow(
              amount.label,
              amount.value,
              size: amount.big ? 10 : 9,
              tone: amount.tone,
            ),
          if (data.observations.isNotEmpty) ...[
            line(),
            pw.Text(
              'Observaciones:',
              style: pw.TextStyle(
                font: bold,
                fontSize: 8,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              data.observations,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          line(),
          pw.Text(
            data.footer,
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
  const _TicketDialog({required this.data});
  final _TicketData data;
  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  bool _busy = false;
  Future<void> _printTicket() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdf(widget.data);
      await Printing.layoutPdf(
        name: widget.data.fileName,
        format: PdfPageFormat.roll80,
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      debugPrint('Error con el PDF del ticket de pedido: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar el ticket.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _logo() {
    const fallback = Icon(
      Icons.storefront_outlined,
      size: 32,
      color: _ink,
    );
    final value = widget.data.branchLogo.trim();
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
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
              value,
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
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    double size = 14,
    String tone = 'normal',
  }) {
    final color = tone == 'green'
        ? _paidGreen
        : tone == 'red'
            ? _cancel
            : _ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFB),
        border: Border.all(
          color: _borderGrey,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

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
          Text(
            data.branchName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          if (data.branchPhone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tel. ${data.branchPhone}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _ink,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Ticket de pedido',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _ink,
            ),
          ),
          _divider(),
          for (final row in data.rows) _infoRow(row.key, row.value),
          _divider(),
          const Text(
            'PRODUCTOS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          if (data.lines.isEmpty)
            const Text(
              'Sin productos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _ink,
              ),
            ),
          for (final item in data.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.detail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _ink,
                          ),
                        ),
                      ),
                      Text(
                        item.total,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          _divider(),
          if (data.paymentRows.isNotEmpty) ...[
            const Text(
              'FORMAS DE PAGO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 9),
            for (final payment in data.paymentRows)
              _paymentCard(payment.key, payment.value),
            _divider(),
          ],
          for (final amount in data.amounts)
            _totalRow(
              amount.label,
              amount.value,
              size: amount.big ? 16 : 14,
              tone: amount.tone,
            ),
          if (data.observations.isNotEmpty) ...[
            _divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Observaciones: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: data.observations),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: _ink,
                ),
              ),
            ),
          ],
          _divider(),
          Text(
            data.footer,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cancel,
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: _cancel,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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