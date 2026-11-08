import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../widgets/primary_button.dart';
import 'ticket_order_screen.dart';

const Color _ordGreen = Color(0xFF0F6B1F);
const Color _ordRed = Color(0xFFF4512A);
const Color _ordBorder = Color(0xFFBDBDBD);
const Color _ordTeal = Color(0xFF63B7C4);
const Color _ordText = Color(0xFF212121);
const Color _ordHint = Color(0xFF9E9E9E);
const Color _ordMuted = Color(0xFF757575);
const Color _ordFill = Color(0xFFF7F8F9);

final ButtonStyle _ordCancelStyle = OutlinedButton.styleFrom(
  foregroundColor: _ordRed,
  backgroundColor: Colors.white,
  side: const BorderSide(color: _ordRed, width: 1.5),
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
);
final ButtonStyle _ordAcceptStyle = OutlinedButton.styleFrom(
  foregroundColor: Colors.black,
  backgroundColor: _ordTeal.withValues(alpha: 0.12),
  side: const BorderSide(color: _ordTeal, width: 1.5),
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
);
String _ordFmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';
class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});
  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}
class _OrderFormScreenState extends State<OrderFormScreen> {
  final OrderService orderService = OrderService();
  final ScrollController scrollController = ScrollController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController obsCtrl = TextEditingController();
  final List<Map<String, dynamic>> advancePayments = [];
  final TextEditingController productSearchCtrl = TextEditingController();
  final TextEditingController customNameCtrl =TextEditingController();
  final TextEditingController customDescriptionCtrl = TextEditingController();
  final Map<String, TextEditingController> qtyCtrls = {};
  final Map<String, TextEditingController> priceCtrls = {};
  final Map<String, TextEditingController> customPriceCtrls = {};
  final Map<String, TextEditingController> customUnitsCtrls = {};
  final List<Map<String, dynamic>> orderItems = [];
  final List<Map<String, dynamic>> customSaleTypes = [];
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> productOptions = [];
  List<Map<String, dynamic>> paymentMethods = [];
  bool loadingPaymentMethods = true;
  bool paymentMethodsOpen = false;
  String paymentMethodQuery = '';
  final TextEditingController paymentMethodSearchCtrl = TextEditingController();
  String? selectedBranchId;
  String? openSaleTypeKey;
  DateTime? deliveryDate;
  bool branchOpen = false;
  bool productsOpen = false;
  bool loadingOptions = true;
  bool loadingProducts = false;
  bool showCustomProductForm = false;
  String? errorMessage;
  String? successMessage;
  bool _saving = false;
  Timer? _messageTimer;
  static const Duration _messageDuration = Duration(seconds: 2);
  bool get locked => _saving;
  bool get branchEditable => true;
  DateTime get minDeliveryDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  String get role =>(Session.user?.roleUser ?? '').toString().trim().toLowerCase();
  bool get isEmployee => role == 'empleado';
  bool get isManager => role == 'administrador' || role == 'supervisor';
  bool get canEditPrices => isManager;

  @override
  void initState() {
    super.initState();
    loadOrderOptions();
    loadPaymentMethods();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    obsCtrl.dispose();
    for (final payment in advancePayments) {
      (payment['controller'] as TextEditingController).dispose();
    }
    productSearchCtrl.dispose();
    paymentMethodSearchCtrl.dispose();
    customNameCtrl.dispose();
    customDescriptionCtrl.dispose();
    scrollController.dispose();
    for (final c in qtyCtrls.values) {
      c.dispose();
    }
    for (final c in priceCtrls.values) {
      c.dispose();
    }
    for (final c in customPriceCtrls.values) {
    c.dispose();
    }
    for (final c in customUnitsCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }
  double parseNum(String? text) {
    final value = (text ?? '')
        .trim()
        .replaceAll(',', '')
        .replaceAll(' ', '');
    if (value.isEmpty) return 0;
    return double.tryParse(value) ?? 0;
  }
  String _formatThousands(String value) {
    final parts = value.split('.');
    final integerPart = parts.first;
    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    if (parts.length > 1) {
      return '$formattedInteger.${parts.sublist(1).join('.')}';
    }
    return formattedInteger;
  }
  String fmtNum(num value) {
    final d = value.toDouble();
    if (!d.isFinite) return '0';
    final text = d == d.roundToDouble()
        ? d.toInt().toString()
        : d.toString();
    return _formatThousands(text);
  }
  String money(num value) {
    final d = value.toDouble();
    if (!d.isFinite) return '\$0.00';
    return '\$${_formatThousands(d.toStringAsFixed(2))}';
  }
  String keyOf(Map<String, dynamic> item) =>
      item['_key'].toString();
  double itemQty(String key) =>
      parseNum(qtyCtrls[key]?.text);
  double itemPrice(String key) =>
      parseNum(priceCtrls[key]?.text);
  double itemSubtotal(String key) =>
      OrderService.round2(itemQty(key) * itemPrice(key));
  double get totalOrder => OrderService.round2(
        orderItems.fold<double>(
          0.0,
          (acumulado, item) =>
              acumulado + itemSubtotal(keyOf(item)),
        ),
      );
  double get paidAmount => OrderService.round2(
        advancePayments.fold<double>(
          0.0,
          (acumulado, payment) =>
              acumulado +
              parseNum(
                (payment['controller'] as TextEditingController).text,
              ),
        ),
      );
  void addAdvancePayment(String id) {
  if (locked) return;
  final existingIndex = advancePayments.indexWhere((p) => p['id'] == id);
  if (existingIndex != -1) {
    removeAdvancePayment(existingIndex);
    return;
  }
  setState(() {
    advancePayments.add({
      'id': id,
      'controller': TextEditingController(text: '0.00'),
    });
    paymentMethodQuery = '';
    paymentMethodSearchCtrl.clear();
  });
  clearMessages();
}
void removeAdvancePayment(int index) {
  if (locked || index < 0 || index >= advancePayments.length) return;
  final payment = advancePayments.removeAt(index);
  (payment['controller'] as TextEditingController).dispose();
  setState(() {});
  clearMessages();
}
  double get balanceDue {
    final b = totalOrder - paidAmount;
    return b <= 0 ? 0 : OrderService.round2(b);
  }
  List<Map<String, dynamic>> getSaleTypes(
    Map<String, dynamic> product,
  ) {
    final raw = product['sale_types'];
    if (raw is List) {
      final types = raw
          .whereType<Map>()
          .map((e) {
            final type = Map<String, dynamic>.from(e);
            type['allows_decimal'] = true;
            return type;
          })
          .where((e) => e['status'] != false)
          .toList();
      if (types.isNotEmpty) return types;
    }
    return [
      {
        'id_type': 'unidad',
        'name_type': (product['base_unit'] ?? 'Unidad').toString(),
        'price': OrderService.toDouble(product['prince']),
        'allows_decimal': true,
        'units_per_sale': 1,
        'status': true,
      },
    ];
  }

  Map<String, dynamic> selectedSaleType(
    Map<String, dynamic> item,
  ) {
    final selected = item['selected_sale_type'];
    if (selected is Map) {
      final type = Map<String, dynamic>.from(selected);
      type['allows_decimal'] = true;
      return type;
    }
    return {
      'id_type': 'unidad',
      'name_type': 'Unidad',
      'price': 0,
      'allows_decimal': true,
      'units_per_sale': 1,
      'status': true,
    };
  }
  void changeSaleType(
    String key,
    Map<String, dynamic> saleType,
  ) {
    if (locked) return;
    final index = orderItems.indexWhere(
      (item) => keyOf(item) == key,
    );
    if (index == -1) return;
    final selectedType = Map<String, dynamic>.from(saleType);
    selectedType['allows_decimal'] = true;
    setState(() {
      orderItems[index]['selected_sale_type'] = selectedType;
      priceCtrls[key]?.text = fmtNum(
        OrderService.toDouble(selectedType['price']),
      );
      openSaleTypeKey = null;
      errorMessage = null;
      successMessage = null;
    });
    _messageTimer?.cancel();
  }

  Future<Map<String, dynamic>?> createSaleTypeDialog() async {
    final nameController = TextEditingController();
    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          bool saving = false;
          String? error;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Nueva presentación de venta',
                          style: TextStyle(
                            color: _ordText,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Escribe el nombre de la presentación que deseas agregar.',
                          style: TextStyle(
                            color: _ordHint,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nombre de la presentación',
                            hintText: 'Ej. Caja, Paquete, Rebanada',
                            filled: true,
                            fillColor: const Color(0xFFFAFCFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: _ordBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: _ordTeal,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            error!,
                            style: const TextStyle(
                              color: _ordRed,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: _ordCancelStyle,
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                style: _ordAcceptStyle,
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final name =
                                            nameController.text.trim();
                                        if (name.isEmpty) {
                                          setDialogState(() {
                                            error = 'Escribe un nombre.';
                                          });
                                          return;
                                        }
                                        setDialogState(() {
                                          saving = true;
                                          error = null;
                                        });
                                        try {
                                          final collection =
                                              FirebaseFirestore.instance
                                                  .collection('product_types');
                                          final existing =
                                              await collection.get();
                                          final found = existing.docs
                                              .where((doc) =>
                                                  (doc.data()['name_type'] ??
                                                          '')
                                                      .toString()
                                                      .trim()
                                                      .toLowerCase() ==
                                                  name.toLowerCase())
                                              .toList();
                                          if (found.isNotEmpty) {
                                            final doc = found.first;
                                            if (doc.data()['status_type'] ==
                                                false) {
                                              await doc.reference.update({
                                                'status_type': true,
                                              });
                                            }
                                            if (dialogContext.mounted) {
                                              Navigator.pop(
                                                dialogContext,
                                                {
                                                  'id_type': doc.id,
                                                  'name_type': name,
                                                  'status_type': true,
                                                },
                                              );
                                            }
                                              return;
                                          }
                                          final ref =
                                              await collection.add({
                                            'name_type': name,
                                            'status_type': true,
                                            'created_at':
                                                FieldValue.serverTimestamp(),
                                          });
                                          if (dialogContext.mounted) {
                                            Navigator.pop(
                                              dialogContext,
                                              {
                                                'id_type': ref.id,
                                                'name_type': name,
                                                'status_type': true,
                                              },
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(() {
                                            saving = false;
                                            error =
                                                'No se pudo crear la presentación.';
                                          });
                                        }
                                      },
                                child: saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _ordTeal,
                                        ),
                                      )
                                    : const Text('Guardar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
    }
  }
  void addCustomOrderProduct() {
    if (locked) return;
    setState(() {
      showCustomProductForm = !showCustomProductForm;
      if (!showCustomProductForm) {
        customNameCtrl.clear();
        customDescriptionCtrl.clear();
        customSaleTypes.clear();
      }
      productsOpen = false;
      productSearchCtrl.clear();
    });
    clearMessages();
  }

  Future<void> addCustomSaleType() async {
    if (locked) return;
    final type = await createSaleTypeDialog();
    if (type == null || !mounted) return;
    final id = type['id_type'].toString();
    if (customSaleTypes.any(
      (element) => element['id_type'].toString() == id,
    )) {
      showError('Esta presentación ya fue agregada.');
      return;
    }
    setState(() {
      customSaleTypes.add({
        'id_type': id,
        'name_type': type['name_type'],
        'price': 0.0,
        'allows_decimal': true,
        'units_per_sale': 1.0,
        'status': true,
      });
    });
    clearMessages();
  }
  void removeCustomSaleType(int index) {
    if (locked || index < 0 || index >= customSaleTypes.length) {
      return;
    }
    setState(() {
      customSaleTypes.removeAt(index);
    });
    clearMessages();
  }
  void saveCustomOrderProduct() {
    if (locked) return;
    final name = customNameCtrl.text.trim();
    final description = customDescriptionCtrl.text.trim();
    if (name.isEmpty) {
      showError('Ingresa el nombre del producto.');
      return;
    }
    if (customSaleTypes.isEmpty) {
      showError('Agrega al menos una presentación de venta.');
      return;
    }
    for (final type in customSaleTypes) {
      final price = OrderService.toDouble(type['price']);
      final units = OrderService.toDouble(type['units_per_sale']);
      if (!price.isFinite || price < 0) {
        showError('Verifica el precio de las presentaciones.');
        return;
      }
      if (!units.isFinite || units <= 0) {
        showError(
          'Las unidades incluidas deben ser mayores a cero.',
        );
        return;
      }
    }
    final key = 'pedido_${DateTime.now().microsecondsSinceEpoch}';
    final saleTypes = customSaleTypes.map((type) {
      final copy = Map<String, dynamic>.from(type);
      copy['allows_decimal'] = true;
      return copy;
    }).toList();
    final selectedType = saleTypes.first;
    final price = OrderService.toDouble(selectedType['price']);
    setState(() {
      orderItems.add({
        '_key': key,
        'id_products': '',
        'name_product': name,
        'description_product': description,
        'sale_types': saleTypes,
        'selected_sale_type': selectedType,
        'base_unit': '',
        'base_unit_symbol': '',
        'is_custom_order_product': true,
      });
      qtyCtrls[key] = TextEditingController(text: '1');
      priceCtrls[key] = TextEditingController(
        text: fmtNum(price),
      );
      showCustomProductForm = false;
      customNameCtrl.clear();
      customDescriptionCtrl.clear();
      customSaleTypes.clear();
    });
    clearMessages();
    showSuccess('Producto agregado al pedido.');
  }

Widget customProductForm() {
  if (!showCustomProductForm) {
    return const SizedBox.shrink();
  }
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _ordTeal, width: 1.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Producto por pedido',
                    style: TextStyle(
                      color: _ordText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Producto especial que no pertenece al catálogo.',
                    style: TextStyle(
                      color: _ordHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: locked ? null : addCustomOrderProduct,
              icon: const Icon(
                Icons.close_rounded,
                color: _ordTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Nombre del producto',
          style: TextStyle(
            color: _ordText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: customNameCtrl,
          enabled: !locked,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => clearMessages(),
          decoration: _ordDecoration(
            hint: 'Ej. Pastel personalizado',
            enabled: !locked,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Descripción',
          style: TextStyle(
            color: _ordText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: customDescriptionCtrl,
          enabled: !locked,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => clearMessages(),
          decoration: _ordDecoration(
            hint: 'Describe cómo lo solicitó el cliente...',
            enabled: !locked,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Formas de venta',
                style: TextStyle(
                  color: _ordText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: locked ? null : addCustomSaleType,
              style: _ordAcceptStyle,
              child: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Define cómo se venderá este producto, por ejemplo: pieza, caja o paquete. También puedes establecer su precio y las unidades que incluye.',
          style: TextStyle(
            color: _ordHint,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (customSaleTypes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFC),
              border: Border.all(color: _ordBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Todavía no has agregado formas de venta. '
              'Presiona "Agregar" para registrar una.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ordHint,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          )
        else
          ...List.generate(customSaleTypes.length, (index) {
            final type = customSaleTypes[index];
            final typeId = type['id_type'].toString();
            return Container(
              key: ValueKey('custom_type_$typeId'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFCFC),
                border: Border.all(color: _ordTeal),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          type['name_type'].toString(),
                          style: const TextStyle(
                            color: _ordText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar forma de venta',
                        onPressed: locked
                            ? null
                            : () => removeCustomSaleType(index),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: _ordRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 420;
                      final priceController =
                          customPriceCtrls.putIfAbsent(
                        typeId,
                        () => TextEditingController(
                          text: _formatThousands(OrderService.toDouble(
                            type['price'],
                          ).clamp(0.0, 999999999.0).toStringAsFixed(2)),
                        ),
                      );
                      final unitsController =
                          customUnitsCtrls.putIfAbsent(
                        typeId,
                        () => TextEditingController(
                          text: fmtNum(
                            OrderService.toDouble(
                              type['units_per_sale'],
                            ).clamp(1.0, 999999999.0),
                          ),
                        ),
                      );
                      final priceField = stepperField(
                        label: 'Precio de venta',
                        controller: priceController,
                        moneyField: true,
                        hint: 'Ej. 25.00',
                        prefixText: '\$ ',
                        enabled: !locked,
                        onUp: () {
                          stepController(
                            priceController,
                            1,
                            decimals: 2,
                          );
                          customSaleTypes[index]['price'] =
                              parseNum(priceController.text);
                        },
                        onDown: () {
                          stepController(
                            priceController,
                            -1,
                            decimals: 2,
                          );
                          customSaleTypes[index]['price'] =
                              parseNum(priceController.text);
                        },
                        onChanged: (value) {
                          customSaleTypes[index]['price'] =
                              parseNum(value);
                        },
                      );
                      final unitsField = stepperField(
                        label: 'Unidades incluidas',
                        controller: unitsController,
                        minValue: 1,
                        hint: 'Ej. 1',
                        enabled: !locked,
                        onUp: () {
                          stepController(
                            unitsController,
                            1,
                            min: 1,
                          );
                          customSaleTypes[index]
                                  ['units_per_sale'] =
                              parseNum(unitsController.text);
                        },
                        onDown: () {
                          stepController(
                            unitsController,
                            -1,
                            min: 1,
                          );
                          customSaleTypes[index]
                                  ['units_per_sale'] =
                              parseNum(unitsController.text);
                        },
                        onChanged: (value) {
                          customSaleTypes[index]
                                  ['units_per_sale'] =
                              parseNum(value).clamp(1.0, 999999999.0).toDouble();
                        },
                      );
                      if (compact) {
                        return Column(
                          children: [
                            priceField,
                            const SizedBox(height: 10),
                            unitsField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: priceField),
                          const SizedBox(width: 12),
                          Expanded(child: unitsField),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: _ordCancelStyle,
                onPressed: locked ? null : addCustomOrderProduct,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: _ordAcceptStyle,
                onPressed: locked ? null : saveCustomOrderProduct,
                child: const Text('Agregar producto'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
  void showError(String message) {
    if (!mounted) return;
    _messageTimer?.cancel();
    setState(() {
      errorMessage = message;
      successMessage = null;
    });
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _messageTimer = Timer(_messageDuration, () {
      if (!mounted) return;
      setState(() => errorMessage = null);
    });
  }
  void showSuccess(String message) {
    if (!mounted) return;
    _messageTimer?.cancel();
    setState(() {
      successMessage = message;
      errorMessage = null;
    });
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _messageTimer = Timer(_messageDuration, () {
      if (!mounted) return;
      setState(() => successMessage = null);
    });
  }
  void clearMessages() {
    _messageTimer?.cancel();
    if (errorMessage != null || successMessage != null) {
      setState(() {
        errorMessage = null;
        successMessage = null;
      });
    }
  }

  Widget orderMessages() {
    if (errorMessage == null && successMessage == null) {
      return const SizedBox.shrink();
    }
    final error = errorMessage != null;
    final message = errorMessage ?? successMessage!;
    final color = error
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);
    final bg = error
        ? const Color(0xFFFDECEA)
        : const Color(0xFFE8F5E9);
    final border = error
        ? const Color(0xFFF5B5AE)
        : const Color(0xFFA5D6A7);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadPaymentMethods() async {
    try {
      final collection = FirebaseFirestore.instance.collection('payment_methods');
      final snapshot = await collection.get();
      final methods = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        return <String, dynamic>{
          ...data,
          'id_payment_methods': (data['id_payment_methods'] ?? doc.id).toString(),
          '_doc_id': doc.id,
          'payment_methods_name': (data['payment_methods_name'] ?? '').toString().trim(),
        };
      }).where((item) => (item['payment_methods_name'] as String).isNotEmpty).toList()
        ..sort((a, b) => (a['payment_methods_name'] as String)
            .toLowerCase()
            .compareTo((b['payment_methods_name'] as String).toLowerCase()));
      if (!mounted) return;
      setState(() {
        paymentMethods = methods;
        loadingPaymentMethods = false;
      });
    } catch (e) {
      debugPrint('Error al cargar formas de pago: $e');
      if (!mounted) return;
      setState(() => loadingPaymentMethods = false);
      showError('No se pudieron cargar las formas de pago.');
    }
  }

  Widget paymentMethodSelector() {
    final filteredMethods = paymentMethods.where((method) {
      final name = (method['payment_methods_name'] ?? '')
          .toString().trim().toLowerCase();
      return name.contains(paymentMethodQuery);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Selecciona una o varias formas de pago que ya estén registradas.',
          style: TextStyle(color: _ordHint, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _ordTeal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                title: const Text('Seleccionar forma de pago',
                    style: TextStyle(color: _ordText,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  advancePayments.isNotEmpty
                      ? '${advancePayments.length} forma(s) agregada(s)'
                      : 'Selecciona una o varias formas de pago',
                  style: TextStyle(
                    color: advancePayments.isNotEmpty ? _ordTeal : _ordHint,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  paymentMethodsOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _ordTeal,
                ),
                onTap: locked ? null : () => setState(() {
                  paymentMethodsOpen = !paymentMethodsOpen;
                  if (!paymentMethodsOpen) {
                    paymentMethodQuery = '';
                    paymentMethodSearchCtrl.clear();
                  }
                }),
              ),
              if (paymentMethodsOpen) ...[
                const Divider(height: 1, color: _ordBorder),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: TextField(
                    controller: paymentMethodSearchCtrl,
                    enabled: !locked,
                    onChanged: (value) => setState(() =>
                        paymentMethodQuery = value.trim().toLowerCase()),
                    decoration: _ordDecoration(
                      hint: 'Buscar forma de pago...',
                      enabled: !locked,
                    ).copyWith(
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _ordTeal),
                    ),
                  ),
                ),
                if (loadingPaymentMethods)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: _ordTeal),
                  )
                else if (filteredMethods.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No hay formas de pago registradas que coincidan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _ordHint),
                    ),
                  )
                else
                  ...filteredMethods.map((method) {
                    final id = method['id_payment_methods'].toString();
                    final name = (method['payment_methods_name'] ?? '').toString();
                    final selected = advancePayments.any((p) => p['id'] == id);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 3),
                      leading: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? _ordTeal : _ordBorder,
                        size: 25,
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              color: _ordText, fontSize: 15)),
                      selected: selected,
                      selectedTileColor: _ordTeal.withValues(alpha: 0.08),
                      onTap: locked ? null : () => addAdvancePayment(id),
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
String? paymentMethodName(String? id) {
  for (final method in paymentMethods) {
    if (method['id_payment_methods'].toString() == id) {
      return method['payment_methods_name'].toString();
    }
  }
  return null;
}

  Future<void> loadOrderOptions() async {
    try {
      final all = await orderService.getBranches();
      final assigned = (Session.user?.idBranches ?? [])
          .map((branch) => branch.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      final list = all.where((branch) {
        if (role == 'administrador') return true;
        return assigned.contains(branch['id'].toString());
      }).toList()
        ..sort(
          (a, b) => (a['branch_name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b['branch_name'] ?? '')
                    .toString()
                    .toLowerCase(),
              ),
        );
      if (!mounted) return;
      setState(() {
        branches = list;
        if ((selectedBranchId == null ||
                selectedBranchId!.isEmpty) &&
            list.isNotEmpty) {
          selectedBranchId = list.first['id'].toString();
        }
        loadingOptions = false;
      });
      await loadProductOptions();
    } catch (e) {
      debugPrint('Error al cargar opciones del pedido: $e');
      if (!mounted) return;
      setState(() => loadingOptions = false);
      showError(
        'No se pudieron cargar las opciones del formulario.',
      );
    }
  }

  Future<void> loadProductOptions() async {
    final id = selectedBranchId;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => productOptions = []);
      return;
    }
    if (mounted) {
      setState(() => loadingProducts = true);
    }
    try {
      final list = await orderService.getProductsForBranch(id);
      if (!mounted || selectedBranchId != id) return;
      setState(() {
        productOptions = list;
        loadingProducts = false;
      });
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
      if (!mounted) return;
      setState(() => loadingProducts = false);
      showError(
        'No se pudieron cargar los productos de la sucursal.',
      );
    }
  }

  void clearItems() {
    for (final c in qtyCtrls.values) {
      c.dispose();
    }
    for (final c in priceCtrls.values) {
      c.dispose();
    }
    qtyCtrls.clear();
    priceCtrls.clear();
    orderItems.clear();
    openSaleTypeKey = null;
  }


  void addProduct(Map<String, dynamic> product) {
    if (locked) return;
    final id = product['id'].toString();
    if (orderItems.any((i) => keyOf(i) == id)) {
      stepController(qtyCtrls[id]!, 1, min: 1);
      setState(() {
        productsOpen = false;
        productSearchCtrl.clear();
      });
      return;
    }
    final saleTypes = getSaleTypes(product);
    final selectedType = saleTypes.first;
    final price = OrderService.toDouble(selectedType['price']);
    setState(() {
      orderItems.add({
        '_key': id,
        'id_products': id,
        'name_product':
            (product['name_product'] ?? '').toString().trim(),
        'description_product':
            (product['description_product'] ?? '').toString(),
        'sale_types': saleTypes,
        'selected_sale_type': selectedType,
        'base_unit': product['base_unit'] ?? '',
        'base_unit_symbol': product['base_unit_symbol'] ?? '',
        'is_custom_order_product': false,
      });
      qtyCtrls[id] = TextEditingController(text: '1');
      priceCtrls[id] = TextEditingController(
        text: fmtNum(price),
      );
      productsOpen = false;
      productSearchCtrl.clear();
    });
    clearMessages();
  }

  void removeItem(String key) {
    if (locked) return;
    setState(() {
      orderItems.removeWhere((i) => keyOf(i) == key);
      qtyCtrls.remove(key)?.dispose();
      priceCtrls.remove(key)?.dispose();
      if (openSaleTypeKey == key) {
        openSaleTypeKey = null;
      }
    });
    clearMessages();
  }

  void stepController(
    TextEditingController controller,
    double change, {
    double min = 0,
    int decimals = -1,
  }) {
    if (locked) return;
    final actual = parseNum(controller.text).clamp(min, 999999999.0).toDouble();
    final next = (actual + change)
        .clamp(min, 999999999.0)
        .toDouble();
    final text = decimals >= 0
        ? _formatThousands(next.toStringAsFixed(decimals))
        : fmtNum(next);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      errorMessage = null;
      successMessage = null;
    });
    _messageTimer?.cancel();
  }

  void _formatControllerValue(TextEditingController controller) {
    final currentValue = controller.text;
    if (currentValue.trim().isEmpty) return;
    final parsed = parseNum(currentValue);
    final formatted = fmtNum(parsed);
    if (formatted == currentValue) return;
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }

  void selectBranch(String id) {
    if (locked || !branchEditable || id == selectedBranchId) {
      return;
    }
    setState(() {
      selectedBranchId = id;
      branchOpen = false;
      clearItems();
      productOptions = [];
    });
    loadProductOptions();
    clearMessages();
  }

  Map<String, dynamic>? collectOrderData() {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      showError('Ingresa el nombre del cliente.');
      return null;
    }
    final branchId = selectedBranchId;
    if (branchId == null || branchId.isEmpty) {
      showError('Selecciona una sucursal.');
      return null;
    }
    if (deliveryDate == null) {
      showError('Selecciona la fecha de entrega.');
      return null;
    }
    if (orderItems.isEmpty) {
      showError('Agrega al menos un producto al pedido.');
      return null;
    }
    final lines = <Map<String, dynamic>>[];
    var total = 0.0;
    for (final item in orderItems) {
      final key = keyOf(item);
      final productName =
          (item['name_product'] ?? '').toString();
      final qty = itemQty(key);
      final price = itemPrice(key);
      final saleType = selectedSaleType(item);
      final isCustom =
          item['is_custom_order_product'] == true;
      final unitsPerSale = OrderService.toDouble(
        saleType['units_per_sale'],
      );
      const allowsDecimal = true;
      if (!qty.isFinite || qty <= 0) {
        showError(
          'La cantidad de "$productName" debe ser mayor a 0.',
        );
        return null;
      }
      if (!unitsPerSale.isFinite || unitsPerSale <= 0) {
        showError(
          'La presentación de "$productName" tiene una conversión inválida.',
        );
        return null;
      }
      if (!price.isFinite || price < 0) {
        showError(
          'Ingresa un precio válido para "$productName".',
        );
        return null;
      }
      final inventoryQuantity = isCustom
          ? 0.0
          : OrderService.round2(qty * unitsPerSale);
      final subtotal = OrderService.round2(qty * price);
      total += subtotal;
      lines.add({
        'id_products': isCustom
            ? ''
            : (item['id_products'] ?? ''),
        'name_product': productName,
        'description_product':
            item['description_product'] ?? '',
        'is_custom_order_product': isCustom,
        'quantity_product': qty == qty.roundToDouble()
            ? qty.toInt()
            : qty,
        'sale_type_id': saleType['id_type'] ?? '',
        'sale_type_name': saleType['name_type'] ?? 'Unidad',
        'allows_decimal': allowsDecimal,
        'units_per_sale': unitsPerSale,
        'inventory_quantity': inventoryQuantity,
        'base_unit': item['base_unit'] ?? '',
        'base_unit_symbol': item['base_unit_symbol'] ?? '',
        'unitPrice_product': price,
        'total_detailSale': subtotal,
      });
    }
    total = OrderService.round2(total);
    final paid = paidAmount;
    if (!paid.isFinite || paid < 0) {
      showError('Ingresa un pago válido.');
      return null;
    }
    if (paid > total) {
      showError(
        'El pago no puede ser mayor al total del pedido.',
      );
      return null;
    }
    if (paid > 0 && advancePayments.isEmpty) {
      showError('Agrega al menos una forma de pago para el anticipo.');
      return null;
    }
    for (final payment in advancePayments) {
      final amount = parseNum(
        (payment['controller'] as TextEditingController).text,
      );
      if (!amount.isFinite || amount < 0) {
        showError('Revisa las cantidades de cada forma de pago.');
        return null;
      }
    }
    final d = deliveryDate!;
    return {
      'client_name': name,
      'client_phone': phoneCtrl.text.trim(),
      'id_branches': branchId,
      'delivery_date': Timestamp.fromDate(
        DateTime(d.year, d.month, d.day),
      ),
      'observations_order': obsCtrl.text.trim(),
      'products': lines,
      'total_order': total,
      'paid_amount': paid,
      'balance_due': OrderService.round2(total - paid),
      'payment_method': advancePayments
          .map((payment) => {
                'id_payment_methods': payment['id'],
                'payment_methods_name': paymentMethodName(payment['id'] as String?),
                'amount': OrderService.round2(parseNum(
                  (payment['controller'] as TextEditingController).text,
                )),
              })
          .where((payment) => (payment['amount'] as double) > 0)
          .toList(),
    };
  }
  InputDecoration _ordDecoration({
    required String hint,
    String? prefixText,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
    }
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _ordHint,
        fontSize: 14,
      ),
      prefixText: prefixText,
      filled: true,
      fillColor: enabled ? Colors.white : _ordFill,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      border: border(_ordBorder),
      enabledBorder: border(_ordBorder),
      disabledBorder: border(_ordBorder),
      focusedBorder: border(_ordTeal, 1.6),
    );
  }

  Widget orderField({
    required String titulo,
    required TextEditingController controller,
    required String hint,
    TextCapitalization capitalization =
        TextCapitalization.sentences,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _ordText,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          enabled: !locked,
          maxLines: maxLines,
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (_) => clearMessages(),
          style: const TextStyle(
            fontSize: 15,
            color: _ordText,
          ),
          decoration: _ordDecoration(
            hint: hint,
            enabled: !locked,
          ).copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget stepperIcons({
    required VoidCallback onUp,
    required VoidCallback onDown,
  }) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: locked ? null : onUp,
            child: const SizedBox(
              width: 38,
              height: 22,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: _ordTeal,
                size: 21,
              ),
            ),
          ),
          InkWell(
            onTap: locked ? null : onDown,
            child: const SizedBox(
              width: 38,
              height: 22,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _ordTeal,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget stepperField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required VoidCallback onUp,
    required VoidCallback onDown,
    ValueChanged<String>? onChanged,
    bool enabled = true,
    String? prefixText,
    bool moneyField = false,
    double? minValue,
  }) {
    final active = enabled && !locked;
    void normalizeMoney() {
      if (!moneyField && minValue == null) return;
      final parsed = parseNum(controller.text);
      final minimum = minValue ?? 0.0;
      final amount = parsed.isFinite ? parsed.clamp(minimum, 999999999.0).toDouble() : minimum;
      final formatted = moneyField
          ? _formatThousands(amount.toStringAsFixed(2))
          : fmtNum(amount);
      if (controller.text != formatted) {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        onChanged?.call(formatted);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _ordText,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (focused) {
            if (!focused) normalizeMoney();
          },
          child: TextField(
          controller: controller,
          enabled: active,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            LengthLimitingTextInputFormatter(15),
          ],
         onChanged: (value) {
            _messageTimer?.cancel();
            setState(() {
              errorMessage = null;
              successMessage = null;
            });
            onChanged?.call(value);
          },
          onEditingComplete: () {
            if (moneyField || minValue != null) { normalizeMoney(); } else { _formatControllerValue(controller); }
            FocusScope.of(context).unfocus();
          },
          onSubmitted: (_) {
            if (moneyField || minValue != null) { normalizeMoney(); } else { _formatControllerValue(controller); }
          },
          style: const TextStyle(
            fontSize: 15,
            color: _ordText,
          ),
          decoration: _ordDecoration(
            hint: hint,
            prefixText: prefixText,
            enabled: active,
            suffixIcon: active
                ? stepperIcons(
                    onUp: onUp,
                    onDown: onDown,
                  )
                : null,
          ),
          ),
        ),
      ],
    );
  }

  String branchNameFor(String? id) {
    for (final branch in branches) {
      if (branch['id'].toString() == id) {
        final name =
            (branch['branch_name'] ?? '').toString().trim();
        return name.isEmpty ? 'Sucursal sin nombre' : name;
      }
    }
    return 'Sucursal no disponible';
  }

  Widget branchSelector() {
  if (isEmployee) {
    return const SizedBox.shrink();
  }
  final fixed = !branchEditable;
  final open = branchOpen && !locked && !fixed;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Sucursal',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _ordText,
        ),
      ),
      const SizedBox(height: 9),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: locked || fixed
            ? null
            : () => setState(() => branchOpen = !branchOpen),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: fixed || locked ? _ordFill : Colors.white,
            border: Border.all(
              color: open ? _ordTeal : _ordBorder,
              width: open ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedBranchId == null
                      ? 'Selecciona una sucursal'
                      : branchNameFor(selectedBranchId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedBranchId == null
                        ? _ordHint
                        : _ordText,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!fixed)
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: open ? _ordTeal : _ordHint,
                ),
            ],
          ),
        ),
      ),
      if (open)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFCFC),
            border: Border.all(color: _ordBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView(
            shrinkWrap: true,
            children: branches.map((branch) {
              final id = branch['id'].toString();
              final selected = id == selectedBranchId;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? _ordTeal
                        : const Color(0xFFE2E8E8),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(
                    branchNameFor(id),
                    style: const TextStyle(color: _ordText),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: _ordTeal,
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: _ordHint,
                        ),
                  onTap: () => selectBranch(id),
                ),
              );
            }).toList(),
          ),
        ),
    ],
  );
}

  Future<DateTime?> showOrderCalendar({
    required DateTime initial,
    required DateTime min,
    required DateTime max,
  }) async {
    DateTime normalize(DateTime d) =>
        DateTime(d.year, d.month, d.day);
    final first = normalize(min);
    final last = normalize(max);
    var start = normalize(initial);
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;
    DateTime selection = start;
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 350,
                child: Theme(
                  data: Theme.of(dialogContext).copyWith(
                    colorScheme:
                        Theme.of(dialogContext).colorScheme.copyWith(
                              primary: _ordTeal,
                              onPrimary: _ordText,
                              surface: Colors.white,
                              onSurface: _ordText,
                            ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: start,
                    firstDate: first,
                    lastDate: last,
                    onDateChanged: (date) {
                      selection = date;
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(),
                        style: _ordCancelStyle,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(selection),
                        style: _ordAcceptStyle,
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget deliveryDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha de entrega',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _ordText,
          ),
        ),
        const SizedBox(height: 9),
        InkWell(
          onTap: locked
              ? null
              : () async {
                  final date = await showOrderCalendar(
                    initial: deliveryDate ?? minDeliveryDate,
                    min: minDeliveryDate,
                    max: DateTime(2100),
                  );
                  if (date == null || !mounted) return;
                  setState(() => deliveryDate = date);
                  clearMessages();
                },
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: locked ? _ordFill : Colors.white,
              suffixIcon: const Icon(
                Icons.calendar_month_outlined,
                color: _ordTeal,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _ordTeal, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              deliveryDate == null
                  ? 'Selecciona una fecha'
                  : _ordFmtDate(deliveryDate!),
              style: TextStyle(
                color: deliveryDate == null ? _ordHint : _ordText,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget saleTypeSelector(
    Map<String, dynamic> item,
    String key,
  ) {
    final types = (item['sale_types'] as List)
        .map((e) {
          final type = Map<String, dynamic>.from(e as Map);
          type['allows_decimal'] = true;
          return type;
        })
        .toList();
    final selected = selectedSaleType(item);
    final selectedId = selected['id_type'].toString();
    final selectedName =
        (selected['name_type'] ?? 'Unidad').toString();
    final isOpen = openSaleTypeKey == key && !locked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Presentación de venta',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _ordText,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: locked
              ? null
              : () {
                  setState(() {
                    openSaleTypeKey = isOpen ? null : key;
                  });
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: locked ? _ordFill : Colors.white,
              border: Border.all(
                color: isOpen ? _ordTeal : _ordBorder,
                width: isOpen ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ordText,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: isOpen ? _ordTeal : _ordHint,
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxHeight: 230),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFC),
              border: Border.all(color: _ordBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView(
              shrinkWrap: true,
              children: types.map((type) {
                final id = type['id_type'].toString();
                final name =
                    (type['name_type'] ?? 'Unidad').toString();
                final price =
                    OrderService.toDouble(type['price']);
                final isSelected = id == selectedId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? _ordTeal
                          : const Color(0xFFE2E8E8),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: _ordText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      money(price),
                      style: const TextStyle(
                        color: _ordMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: _ordTeal,
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: _ordHint,
                          ),
                    onTap: () => changeSaleType(key, type),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

Widget productsSection() {
  final query = productSearchCtrl.text.trim().toLowerCase();
  final options = productOptions.where((p) {
    final name = (p['name_product'] ?? '')
        .toString()
        .toLowerCase();
    final code = (p['barcode'] ?? '')
        .toString()
        .toLowerCase();
    return name.contains(query) || code.contains(query);
  }).toList();
  final open = productsOpen && !locked;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Productos del pedido',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _ordText,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Agrega los productos que pidió el cliente. Puedes cambiar la cantidad de cada uno.',
        style: TextStyle(
          color: _ordHint,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      if (!locked) ...[
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFCFC),
            border: Border.all(color: _ordBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Agregar productos',
                  style: TextStyle(
                    color: _ordText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                trailing: Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _ordTeal,
                ),
                onTap: () {
                  setState(() {
                    productsOpen = !productsOpen;
                    if (productsOpen) {
                      showCustomProductForm = false;
                      customNameCtrl.clear();
                      customDescriptionCtrl.clear();
                      customSaleTypes.clear();
                    }
                  });
                },
              ),
              if (open) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    controller: productSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar producto por nombre o código...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _ordTeal,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: _ordBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: _ordTeal,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (loadingProducts)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _ordTeal,
                      ),
                    ),
                  )
                else if (options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No hay productos con inventario en esta sucursal que coincidan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ordHint,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 260,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        10,
                      ),
                      children: options.map((product) {
                        final id = product['id'].toString();
                        final added = orderItems.any(
                          (i) => keyOf(i) == id,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: added
                                  ? _ordTeal
                                  : const Color(0xFFE2E8E8),
                              width: added ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              (product['name_product'] ?? 'Producto')
                                  .toString(),
                              style: const TextStyle(
                                color: _ordText,
                              ),
                            ),
                            subtitle: Text(
                              money(
                                OrderService.toDouble(
                                  product['prince'],
                                ),
                              ),
                              style: const TextStyle(
                                color: _ordMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              added
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: _ordTeal,
                            ),
                            onTap: () => addProduct(product),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (!showCustomProductForm)
          OutlinedButton(
            onPressed: addCustomOrderProduct,
            style: _ordAcceptStyle,
            child: const Text(
              'Agregar producto por pedido',
            ),
          ),
        if (showCustomProductForm) customProductForm(),
        const SizedBox(height: 16),
      ],
      if (orderItems.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFCFC),
            border: Border.all(color: _ordBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Todavía no agregas productos al pedido.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ordHint,
              height: 1.4,
            ),
          ),
        )
      else
        ...orderItems.map(orderItemCard),
    ],
  );
}

  Widget orderItemCard(Map<String, dynamic> item) {
    final key = keyOf(item);
    final name = (item['name_product'] ?? '').toString();
    final qtyCtrl = qtyCtrls[key];
    final priceCtrl = priceCtrls[key];
    if (qtyCtrl == null || priceCtrl == null) {
      return const SizedBox.shrink();
    }
    final isCustom =
        item['is_custom_order_product'] == true;
    return Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ordTeal),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _ordTeal.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: _ordTeal,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Producto sin nombre' : name,
                      style: const TextStyle(
                        color: _ordText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isCustom)
                      const Text(
                        'Producto especial por pedido',
                        style: TextStyle(
                          color: _ordTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (!locked)
                IconButton(
                  tooltip: 'Quitar del pedido',
                  onPressed: () => removeItem(key),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: _ordRed,
                  ),
                ),
            ],
          ),
          if ((item['description_product'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item['description_product'].toString(),
              style: const TextStyle(
                color: _ordMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),
          saleTypeSelector(item, key),
          const SizedBox(height: 14),
          stepperField(
            label: 'Cantidad',
            controller: qtyCtrl,
            hint: 'Ej. 2',
            onUp: () => stepController(qtyCtrl, 1, min: 0.01),
            onDown: () => stepController(qtyCtrl, -1, min: 0.01),
          ),
          const SizedBox(height: 10),
          stepperField(
            label: 'Precio unitario',
            controller: priceCtrl,
            hint: 'Ej. 25.00',
            prefixText: '\$ ',
            enabled: canEditPrices,
            onUp: () => stepController(
              priceCtrl,
              1,
              decimals: 2,
            ),
            onDown: () => stepController(
              priceCtrl,
              -1,
              decimals: 2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: _ordTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(
                      color: _ordText,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  money(itemSubtotal(key)),
                  style: const TextStyle(
                    color: _ordText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _ordMuted,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? _ordText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

 Widget paymentSection() {
  final total = totalOrder;
  final paid = paidAmount;
  final balance = balanceDue;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Pago',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _ordText,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Selecciona cómo pagó el cliente e ingresa el monto del anticipo. El saldo se calcula automáticamente.',
        style: TextStyle(
          color: _ordHint,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      paymentMethodSelector(),
      const SizedBox(height: 14),
      if (advancePayments.isNotEmpty) ...[
        const Text(
          'Anticipo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ordText,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(advancePayments.length, (index) {
          final payment = advancePayments[index];
          final id = payment['id'] as String;
          final controller =
              payment['controller'] as TextEditingController;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFCFC),
                border: Border.all(color: _ordBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          paymentMethodName(id) ?? 'Forma de pago',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _ordText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  stepperField(
                    label: 'Cantidad recibida',
                    controller: controller,
                    hint: '0.00',
                    moneyField: true,
                    prefixText: '\$ ',
                    enabled: !locked,
                    onUp: () {
                      stepController(
                        controller,
                        1,
                        decimals: 2,
                        min: 0,
                      );
                      setState(() {});
                      clearMessages();
                    },
                    onDown: () {
                      stepController(
                        controller,
                        -1,
                        decimals: 2,
                        min: 0,
                      );
                      setState(() {});
                      clearMessages();
                    },
                    onChanged: (_) {
                      setState(() {});
                      clearMessages();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFCFC),
          border: Border.all(color: _ordBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _summaryRow(
              'Total del pedido',
              money(total),
            ),
            _summaryRow(
              'Anticipo',
              money(paid),
              color: _ordGreen,
            ),
            const Divider(
              color: Color(0xFFEEEEEE),
              height: 16,
            ),
            _summaryRow(
              'Faltante por entregar',
              money(balance),
              color: balance > 0 ? _ordRed : _ordGreen,
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget orderFormBody(bool isMobile) {
    final left = <Widget>[
      orderField(
        titulo: 'Nombre del cliente',
        controller: nameCtrl,
        hint: 'Ej. María López',
        capitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 20),
      orderField(
      titulo: 'Teléfono',
      controller: phoneCtrl,
      hint: 'Ej. 2461234567',
      capitalization: TextCapitalization.none,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      ),
      const SizedBox(height: 20),
      branchSelector(),
      const SizedBox(height: 20),
      deliveryDateField(),
      const SizedBox(height: 20),
      orderField(
        titulo: 'Observaciones (opcional)',
        controller: obsCtrl,
        hint: 'Notas del pedido',
        maxLines: 3,
      ),
    ];
    final right = <Widget>[
      productsSection(),
      const SizedBox(height: 25),
      paymentSection(),
    ];
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...left,
          const SizedBox(height: 25),
          ...right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: left,
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: right,
          ),
        ),
      ],
    );
  }

  Future<bool> confirmOrderDialog({
    required IconData icon,
    required String title,
    required String before,
    required String name,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _ordTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: _ordTeal,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ordText,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      color: _ordText,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: before),
                      TextSpan(
                        text: '"$name"',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        style: _ordCancelStyle,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        style: _ordAcceptStyle,
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _save({bool imprimir = false}) async {
    if (_saving) return;
    for (final controller in qtyCtrls.values) {
      _formatControllerValue(controller);
    }
    for (final controller in priceCtrls.values) {
      _formatControllerValue(controller);
    }
    for (final payment in advancePayments) {
      _formatControllerValue(payment['controller'] as TextEditingController);
    }
    final data = collectOrderData();
    if (data == null) return;
    final confirmed = await confirmOrderDialog(
      icon: Icons.receipt_long_outlined,
      title: 'Confirmar registro',
      before: '¿Estás seguro de que deseas registrar el pedido de ',
      name: nameCtrl.text.trim(),
    );
    if (!confirmed || !mounted) return;
    _messageTimer?.cancel();
    setState(() {
      _saving = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      final now = DateTime.now();
     final fullOrder = <String, dynamic>{
      ...data,
      'order_date': Timestamp.fromDate(
        DateTime(now.year, now.month, now.day),
      ),
      'order_status': 'pendiente',
      'id_users': Session.user?.idUser ?? '',
      'initial_payment_registered_at': Timestamp.fromDate(now),
      'initial_payment_registered_by_id':
          Session.user?.idUser ?? '',
    };
      final orderId = await orderService.createOrder(fullOrder);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (imprimir) {
        await OrderTicket.show(
          context,
          orderId: orderId,
          order: fullOrder,
        );
        if (!mounted) return;
      }
      showSuccess('¡Pedido registrado correctamente!');
      await Future.delayed(_messageDuration);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('Error al registrar pedido: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      showError(
        'No se pudo registrar el pedido. Verifica Firebase.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _botonVolver() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _saving
            ? null
            : () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          foregroundColor: _ordTeal,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 40,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  orderMessages(),
                  _botonVolver(),
                  const SizedBox(height: 12),
                  Text(
                    'Registrar pedido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 25 : 32,
                      fontWeight: FontWeight.w600,
                      color: _ordText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completa los datos del nuevo pedido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                  const SizedBox(height: 34),
                  if (loadingOptions)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _ordTeal,
                        ),
                      ),
                    )
                  else
                    orderFormBody(isMobile),
                  const SizedBox(height: 30),
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 52,
                          child: PrimaryButton(
                            text: _saving
                                ? 'Registrando...'
                                : 'Registrar pedido',
                            onPressed:
                                _saving || loadingOptions ? null : _save,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: PrimaryButton(
                            text: _saving
                                ? 'Registrando...'
                                : 'Registrar e imprimir ticket',
                            onPressed: _saving || loadingOptions
                                ? null
                                : () => _save(imprimir: true),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          height: 52,
                          child: PrimaryButton(
                            text: _saving
                                ? 'Registrando...'
                                : 'Registrar pedido',
                            onPressed:
                                _saving || loadingOptions ? null : _save,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 300,
                          height: 52,
                          child: PrimaryButton(
                            text: _saving
                                ? 'Registrando...'
                                : 'Registrar e imprimir ticket',
                            onPressed: _saving || loadingOptions
                                ? null
                                : () => _save(imprimir: true),
                          ),
                        ),
                      ],
                    ),
                  if (_saving) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            color: _ordGreen,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Guardando pedido, espera un momento...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
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