import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../widgets/primary_button.dart';

const Color _green = Color(0xFF0F6B1F);
const Color _borderGrey = Color(0xFFBDBDBD);
const Color _hintGrey = Color(0xFF9E9E9E);
const Color _textDark = Color(0xFF212121);
const Color _teal = Color(0xFF63B7C4);
const Color _red = Color(0xFFF4512A);
const Color _cancel = Color(0xFFFF5722);

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductService _productService = ProductService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _newCategoryController =TextEditingController();
  final TextEditingController _newTypeController = TextEditingController();
  final TextEditingController _newUnitController = TextEditingController();
  final TextEditingController _stockController =  TextEditingController(text: '0');
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _unitsControllers = {};
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _units = [];
  final Set<String> _selectedBranchIds = {};
  final Map<String, TextEditingController> _stockControllersByBranch = {};
  String? _selectedCategoryId;
  String? _selectedUnitId;
  final List<Map<String, dynamic>> _saleTypes = [];
  DateTime _entryDate = DateTime.now();
  DateTime? _expiryDate;
  XFile? _image;
  Uint8List? _imageBytes;
  bool _saving = false;
  bool _loadingOptions = true;
  bool _creatingCategory = false;
  bool _creatingType = false;
  bool _creatingUnit = false;
  bool _categoriaAbierta = false;
  bool _unidadAbierta = false;
  bool _sucursalAbierta = false;
  bool _tiposAbiertos = false;
  String _typeQuery = '';
  String? _errorMessage;
  String? _successMessage;
  bool get _esEmpleado =>
      (Session.user?.roleUser ?? '').trim().toLowerCase() == 'empleado';
  bool get _puedeModificarPrecios {
    final rol = (Session.user?.roleUser ?? '').trim().toLowerCase();
    return rol == 'administrador' || rol == 'supervisor';
  }
  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    _newTypeController.dispose();
    _newUnitController.dispose();
    _stockController.dispose();
    for (final controller in _stockControllersByBranch.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _unitsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  void _agregarIdSucursal(Set<String> ids, dynamic value) {
    if (value == null) return;
    if (value is DocumentReference) {
      ids.add(value.id);
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        _agregarIdSucursal(ids, item);
      }
      return;
    }
    if (value is Map) {
      final id = value['id'] ??
          value['id_branches'] ??
          value['branch_id'] ??
          value['idBranches'] ??
          value['reference'];
      if (id != null) {
        _agregarIdSucursal(ids, id);
      }
      return;
    }
    final texto = value.toString().trim();
    if (texto.isEmpty || texto == 'null') return;
    final id = texto.contains('/') ? texto.split('/').last : texto;
    if (id.isNotEmpty) {
      ids.add(id);
    }
  }

  Future<void> _loadOptions() async {
    if (mounted) {
      setState(() => _loadingOptions = true);
    }
    try {
      final results = await Future.wait([
        _db.collection('categories').get(),
        _db.collection('product_types').get(),
        _db.collection('branches').get(),
        _db.collection('inventory').get(),
      ]);
      final categories = results[0].docs
          .map((doc) => <String, dynamic>{
                'id': doc.id,
                ...doc.data(),
              })
          .toList()
        ..sort((a, b) => (a['name_category'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['name_category'] ?? '').toString().toLowerCase(),
            ));
      final types = results[1].docs
          .map((doc) => <String, dynamic>{
                'id': doc.id,
                ...doc.data(),
              })
          .toList()
        ..sort((a, b) => (a['name_type'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['name_type'] ?? '').toString().toLowerCase(),
            ));
      final unitsMap = <String, Map<String, dynamic>>{};
      for (final doc in results[3].docs) {
        final data = doc.data();
        final name = (data['base_unit'] ?? data['name_unit'] ?? '')
            .toString()
            .trim();
        final symbol =
            (data['base_unit_symbol'] ?? data['symbol_unit'] ?? '')
                .toString()
                .trim();
        if (name.isEmpty) continue;
        final unitKey = '$name|$symbol';
        unitsMap[unitKey] = {
          'id': unitKey,
          'name_unit': name,
          'symbol_unit': symbol.isEmpty ? name : symbol,
        };
      }
      final units = unitsMap.values.toList()
        ..sort((a, b) => (a['name_unit'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['name_unit'] ?? '').toString().toLowerCase(),
            ));
      final allBranches = results[2].docs
          .where((doc) => doc.data()['branch_status'] != false)
          .map((doc) => <String, dynamic>{
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      final user = Session.user;
      final role = (user?.roleUser ?? '').trim().toLowerCase();
      final assignedIds = <String>{};
      _agregarIdSucursal(assignedIds, user?.idBranches);
      final branches = allBranches.where((branch) {
        final branchId = branch['id'].toString();
        if (role == 'administrador') {
          return true;
        }
        if (role == 'supervisor' || role == 'empleado') {
          return assignedIds.contains(branchId);
        }
        return false;
      }).toList()
        ..sort((a, b) => (a['branch_name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['branch_name'] ?? '').toString().toLowerCase(),
            ));
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _types = types;
        _units = units;
        _branches = branches;
        if (_selectedUnitId != null &&
            !_units.any((u) => u['id'].toString() == _selectedUnitId)) {
          _selectedUnitId = null;
        }
        if (_esEmpleado) {
          _selectedBranchIds
            ..clear()
            ..addAll(
              branches.isEmpty
                  ? <String>[]
                  : [branches.first['id'].toString()],
            );
        } else {
          _selectedBranchIds.removeWhere(
            (id) => !branches.any(
              (branch) => branch['id'].toString() == id,
            ),
          );
          if (_selectedBranchIds.isEmpty && branches.isNotEmpty) {
            _selectedBranchIds.add(branches.first['id'].toString());
          }
        }
        for (final id in _selectedBranchIds) {
          _stockControllersByBranch.putIfAbsent(
            id,
            () => TextEditingController(text: _stockController.text),
          );
        }
        _loadingOptions = false;
      });
    } catch (e) {
      debugPrint('Error al cargar opciones: $e');
      if (!mounted) return;
      setState(() => _loadingOptions = false);
      _showError('No se pudieron cargar las opciones del formulario.');
    }
  }

  Future<void> _createCategory() async {
    if (_saving || _creatingCategory) return;
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      _showError('Escribe el nombre de la categoría.');
      return;
    }
    setState(() => _creatingCategory = true);
    try {
      final snapshot = await _db.collection('categories').get();
      final matches = snapshot.docs.where(
        (doc) =>
            (doc.data()['name_category'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            name.toLowerCase(),
      );
      String id;
      if (matches.isNotEmpty) {
        final existing = matches.first;
        id = existing.id;
        if (existing.data()['status_category'] == false) {
          await existing.reference.update({
            'status_category': true,
          });
        }
      } else {
        final doc = await _db.collection('categories').add({
          'name_category': name,
          'status_category': true,
          'created_at': FieldValue.serverTimestamp(),
        });
        id = doc.id;
      }
      await _loadOptions();
      if (!mounted) return;
      setState(() {
        _selectedCategoryId = id;
        _categoriaAbierta = false;
      });
      _newCategoryController.clear();
      _showSuccess('Categoría seleccionada correctamente.');
    } catch (e) {
      debugPrint('Error al crear categoría: $e');
      _showError('No se pudo crear la categoría.');
    } finally {
      if (mounted) {
        setState(() => _creatingCategory = false);
      }
    }
  }

  Map<String, dynamic>? get _unidadSeleccionada {
    for (final unit in _units) {
      if (unit['id'].toString() == _selectedUnitId) {
        return unit;
      }
    }
    return null;
  }
  String get _nombreUnidad =>
      (_unidadSeleccionada?['name_unit'] ?? '').toString();
  String get _simboloUnidad {
    final symbol =
        (_unidadSeleccionada?['symbol_unit'] ?? '').toString().trim();
    return symbol.isNotEmpty ? symbol : _nombreUnidad;
  }

  Future<String?> _pedirSimboloUnidad(String nombre) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Crear unidad de inventario',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unidad: $nombre',
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Escribe el símbolo que se mostrará en las existencias.',
              style: TextStyle(color: _hintGrey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ej. kg, g, l, ml, pza',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: _teal,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: _cancel,
              side: const BorderSide(color: _cancel),
            ),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () {
              final symbol = controller.text.trim();
              if (symbol.isNotEmpty) {
                Navigator.of(dialogContext).pop(symbol);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: _teal.withValues(alpha: 0.12),
              side: const BorderSide(color: _teal, width: 1.5),
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createUnit() async {
    if (_saving || _creatingUnit) return;
    final name = _newUnitController.text.trim();
    if (name.isEmpty) {
      _showError('Escribe el nombre de la unidad de inventario.');
      return;
    }
    setState(() => _creatingUnit = true);
    try {
      final existing = _units.where(
        (item) =>
            (item['name_unit'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            name.toLowerCase(),
      );
      String symbol;
      if (existing.isNotEmpty) {
        symbol = (existing.first['symbol_unit'] ?? name).toString();
      } else {
        final result = await _pedirSimboloUnidad(name);
        if (result == null || result.trim().isEmpty) return;
        symbol = result.trim();
      }
      final unitKey = '$name|$symbol';
      if (!mounted) return;
      setState(() {
        final index = _units.indexWhere(
          (item) => item['id'].toString() == unitKey,
        );
        if (index < 0) {
          _units.add({
            'id': unitKey,
            'name_unit': name,
            'symbol_unit': symbol,
          });
        }
        _selectedUnitId = unitKey;
        _unidadAbierta = false;
      });
      _newUnitController.clear();
      _showSuccess('Unidad de inventario seleccionada correctamente.');
    } catch (e) {
      debugPrint('Error al crear unidad: $e');
      _showError('No se pudo crear la unidad de inventario.');
    } finally {
      if (mounted) {
        setState(() => _creatingUnit = false);
      }
    }
  }

  Future<void> _createType() async {
    if (_saving || _creatingType) return;
    final name = _newTypeController.text.trim();
    if (name.isEmpty) {
      _showError('Escribe el nombre de la forma de venta.');
      return;
    }
    setState(() => _creatingType = true);
    try {
      final snapshot = await _db.collection('product_types').get();
      final matches = snapshot.docs.where(
        (doc) =>
            (doc.data()['name_type'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            name.toLowerCase(),
      );
      String id;
      if (matches.isNotEmpty) {
        final existing = matches.first;
        id = existing.id;
        if (existing.data()['status_type'] == false) {
          await existing.reference.update({
            'status_type': true,
          });
        }
      } else {
        final doc = await _db.collection('product_types').add({
          'name_type': name,
          'status_type': true,
          'created_at': FieldValue.serverTimestamp(),
        });
        id = doc.id;
      }
      await _loadOptions();
      if (!mounted) return;
      final type = _types.where(
        (item) => item['id'].toString() == id,
      );
      if (type.isNotEmpty) {
        _toggleSaleType(type.first, true);
      }
      setState(() {
        _tiposAbiertos = true;
        _typeQuery = '';
      });
      _newTypeController.clear();
      _showSuccess('Forma de venta agregada al producto.');
    } catch (e) {
      debugPrint('Error al crear forma de venta: $e');
      _showError('No se pudo crear la forma de venta.');
    } finally {
      if (mounted) {
        setState(() => _creatingType = false);
      }
    }
  }
  bool _typeIsSelected(String id) {
    return _saleTypes.any(
      (item) => item['id_type'].toString() == id,
    );
  }
  void _toggleSaleType(Map<String, dynamic> type, bool selected) {
    if (_saving) return;
    final id = type['id'].toString();
    if (selected && !_typeIsSelected(id)) {
      final name = (type['name_type'] ?? '').toString();
      setState(() {
        _priceControllers[id] = TextEditingController(text: '0.00');
        _unitsControllers[id] = TextEditingController(text: '1');
        _saleTypes.add({
          'id_type': id,
          'name_type': name,
          'price': 0.0,
          'allows_decimal': true,
          'status': true,
          'units_per_sale': 1.0,
        });
        _errorMessage = null;
        _successMessage = null;
      });
    } else if (!selected && _typeIsSelected(id)) {
      setState(() {
        _saleTypes.removeWhere(
          (item) => item['id_type'].toString() == id,
        );
        _priceControllers.remove(id)?.dispose();
        _unitsControllers.remove(id)?.dispose();
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }
  void _updateSalePrice(String id, String value) {
    if (!_puedeModificarPrecios) return;
    final normalized = value.replaceAll(',', '.');
    final price = double.tryParse(normalized);
    final index = _saleTypes.indexWhere(
      (item) => item['id_type'].toString() == id,
    );
    if (index < 0) return;
    _saleTypes[index]['price'] =
        price != null && price.isFinite && price >= 0 ? price : 0.0;
    if (_errorMessage != null || _successMessage != null) {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }
  void _changeSalePrice(String id, double change) {
    if (_saving || !_puedeModificarPrecios) return;
    final controller = _priceControllers[id];
    if (controller == null) return;
    final actual = double.tryParse(
          controller.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final next = (actual + change).clamp(0.0, 999999999.0);
    final text = next.toStringAsFixed(2);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _updateSalePrice(id, text);
    setState(() {});
  }

  Widget _priceField(String id, String typeName) {
    final controller = _priceControllers[id];
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Precio por $typeName',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_saving && _puedeModificarPrecios,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            LengthLimitingTextInputFormatter(15),
          ],
          onChanged: (value) => _updateSalePrice(id, value),
          style: const TextStyle(
            fontSize: 15,
            color: _textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Ej. 25.00',
            hintStyle: const TextStyle(
              color: _hintGrey,
              fontSize: 14,
            ),
            prefixText: '\$ ',
            filled: true,
            fillColor: _puedeModificarPrecios
                ? Colors.white
                : const Color(0xFFF7F8F9),
            suffixIcon: SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: _saving || !_puedeModificarPrecios
                        ? null
                        : () => _changeSalePrice(id, 1),
                    child: const SizedBox(
                      width: 38,
                      height: 22,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: _teal,
                        size: 21,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _saving || !_puedeModificarPrecios
                        ? null
                        : () => _changeSalePrice(id, -1),
                    child: const SizedBox(
                      width: 38,
                      height: 22,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _teal,
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _teal,
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
  void _updateUnitsPerSale(String clave, String value) {
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    final index = _saleTypes.indexWhere(
      (item) => item['id_type'].toString() == clave,
    );
    if (index < 0) return;
    _saleTypes[index]['units_per_sale'] =
        n != null && n.isFinite && n > 0 ? n : 1.0;
  }
  void _changeUnitsPerSale(String clave, double change) {
    if (_saving) return;
    final controller = _unitsControllers[clave];
    if (controller == null) return;
    final actual = double.tryParse(
          controller.text.trim().replaceAll(',', '.'),
        ) ??
        1;
    final next = (actual + change).clamp(1.0, 999999.0);
    final text = next == next.roundToDouble()
        ? next.toInt().toString()
        : next.toString();
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _updateUnitsPerSale(clave, text);
    setState(() {});
  }

  Widget _unitsField(String clave, String typeName) {
    final controller = _unitsControllers[clave];
    if (controller == null) {
      return const SizedBox.shrink();
    }
    final cantidad = double.tryParse(
          controller.text.trim().replaceAll(',', '.'),
        ) ??
        1;
    final cantidadTexto = cantidad == cantidad.roundToDouble()
        ? cantidad.toInt().toString()
        : cantidad.toString();
    final unidad =
        _unidadSeleccionada == null ? 'unidades' : _simboloUnidad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unidades que incluye',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Escribe cuántas unidades del inventario se descuentan cada vez '
          'que vendes 1 $typeName. Si vendes por pieza, déjalo en 1. '
          'Si vendes una caja de 12, pon 12.',
          style: const TextStyle(
            color: _hintGrey,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (value) {
            _updateUnitsPerSale(clave, value);
            setState(() {
              _errorMessage = null;
              _successMessage = null;
            });
          },
          style: const TextStyle(
            fontSize: 15,
            color: _textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Ej. 12',
            hintStyle: const TextStyle(
              color: _hintGrey,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: _saving
                        ? null
                        : () => _changeUnitsPerSale(clave, 1),
                    child: const SizedBox(
                      width: 38,
                      height: 22,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: _teal,
                        size: 21,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _saving
                        ? null
                        : () => _changeUnitsPerSale(clave, -1),
                    child: const SizedBox(
                      width: 38,
                      height: 22,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _teal,
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _teal,
                width: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF757575),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Al vender 1 $typeName se descontarán $cantidadTexto '
                  '$unidad del inventario.',
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _campoModalidades() {
    final options = _types.where((item) {
      final name = (item['name_type'] ?? '').toString().toLowerCase();
      return item['status_type'] != false && name.contains(_typeQuery);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Formas de venta y precios',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Selecciona todas las formas de venta que necesites. Cada una tendrá su propio precio.',
          style: TextStyle(
            color: _hintGrey,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFCFC),
            border: Border.all(color: _borderGrey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Seleccionar formas de venta',
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                trailing: Icon(
                  _tiposAbiertos
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _teal,
                ),
                onTap: _saving
                    ? null
                    : () => setState(
                          () => _tiposAbiertos = !_tiposAbiertos,
                        ),
              ),
              if (_tiposAbiertos) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    controller: _newTypeController,
                    enabled: !_saving && !_creatingType,
                    onChanged: (value) => setState(
                      () => _typeQuery = value.trim().toLowerCase(),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar o crear forma de venta...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _hintGrey,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _borderGrey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: _teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_typeQuery.isNotEmpty &&
                    !options.any(
                      (item) =>
                          (item['name_type'] ?? '')
                              .toString()
                              .trim()
                              .toLowerCase() ==
                          _typeQuery,
                    ))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _saving || _creatingType ? null : _createType,
                        icon: _creatingType
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _teal,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text('Crear "$_typeQuery"'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: _teal.withValues(alpha: 0.12),
                          side: const BorderSide(
                            color: _teal,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No hay formas de venta activas que coincidan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _hintGrey),
                    ),
                  )
                else
                  ...options.map((type) {
                    final id = type['id'].toString();
                    final selected = _typeIsSelected(id);

                    return CheckboxListTile(
                      value: selected,
                      activeColor: _teal,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        (type['name_type'] ?? '').toString(),
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: selected
                          ? const Text(
                              'Seleccionada',
                              style: TextStyle(
                                color: _teal,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      onChanged: _saving
                          ? null
                          : (value) =>
                              _toggleSaleType(type, value ?? false),
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_saleTypes.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFC),
              border: Border.all(color: _borderGrey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Todavía no seleccionas formas de venta. Marca una o varias casillas para asignar sus precios.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _hintGrey,
                height: 1.4,
              ),
            ),
          )
        else
          ..._saleTypes.map((item) {
            final id = item['id_type'].toString();
            final name = (item['name_type'] ?? '').toString();
            final active = item['status'] == true;
            return Container(
              key: ValueKey(id),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: active ? _teal : _borderGrey,
                ),
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
                          color: _teal.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sell_outlined,
                          color: _teal,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: _textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !_saving,
                        onSelected: (value) {
                          if (value == 'toggle') {
                            setState(() {
                              item['status'] = item['status'] != true;
                            });
                          } else if (value == 'remove') {
                            _toggleSaleType(
                              {
                                'id': id,
                                'name_type': name,
                              },
                              false,
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              active ? 'Desactivar' : 'Activar',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Quitar del producto'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _priceField(id, name),
                  const SizedBox(height: 8),
                  _unitsField(id, name),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        active
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        color: active ? _teal : _hintGrey,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        active ? 'Disponible para vender' : 'No disponible',
                        style: TextStyle(
                          color: active ? _textDark : _hintGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _selectImage() async {
    if (_saving) return;
    try {
      final selected = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (selected == null || !mounted) return;
      if (!selected.name.toLowerCase().endsWith('.png')) {
        _showError('Solo se permiten imágenes PNG.');
        return;
      }
      final bytes = await selected.readAsBytes();
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      final valid = bytes.length >= signature.length &&
          List<int>.generate(
            signature.length,
            (i) => bytes[i],
          ).toString() ==
              signature.toString();
      if (!valid) {
        _showError('El archivo seleccionado no es una imagen PNG válida.');
        return;
      }
      setState(() {
        _image = selected;
        _imageBytes = bytes;
      });
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      _showError('No se pudo seleccionar la imagen.');
    }
  }
  void _removeImage() {
    if (_saving) return;
    setState(() {
      _image = null;
      _imageBytes = null;
    });
  }

  Widget _campoImagen() {
    final hasImage = _imageBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imagen del producto (opcional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 9),
        CustomPaint(
          foregroundPainter: const _DashedBorderPainter(color: _teal),
          child: Container(
            width: double.infinity,
            height: 210,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Padding(
                      padding: EdgeInsets.zero,
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    )
                  else
                    const ColoredBox(
                      color: Color(0xFFFAFCFC),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            color: _teal,
                            size: 35,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Agregar imagen PNG',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Toca aquí para elegir una imagen',
                            style: TextStyle(
                              color: _hintGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _saving ? null : _selectImage,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  if (hasImage)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Eliminar imagen',
                          onPressed: _saving ? null : _removeImage,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: _red,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
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
    );
  }

  Widget _campo({
    required String titulo,
    required TextEditingController controller,
    required String hint,
    TextCapitalization capitalization = TextCapitalization.sentences,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          enabled: !_saving,
          maxLines: maxLines,
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (_) => _clearMessages(),
          style: const TextStyle(
            fontSize: 15,
            color: _textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _hintGrey,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _teal,
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectorLista({
    required String titulo,
    required String? textoSeleccionado,
    required String placeholder,
    required bool abierto,
    required VoidCallback onToggle,
    required TextEditingController controller,
    required String hint,
    required List<Map<String, dynamic>> options,
    required String Function(Map<String, dynamic>) nameOf,
    required String Function(Map<String, dynamic>) idOf,
    required String? selectedId,
    required String query,
    required bool exacta,
    required bool creando,
    required Future<void> Function() onCreate,
    required String createLabel,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 9),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _saving ? null : onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: abierto ? _teal : _borderGrey,
                width: abierto ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    textoSeleccionado ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textoSeleccionado == null
                          ? _hintGrey
                          : _textDark,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  abierto
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: abierto ? _teal : _hintGrey,
                ),
              ],
            ),
          ),
        ),
        if (abierto) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFC),
              border: Border.all(color: _borderGrey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  enabled: !_saving && !creando,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _hintGrey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _borderGrey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: _teal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (query.isNotEmpty && !exacta) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving || creando ? null : onCreate,
                      icon: creando
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _teal,
                              ),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text('$createLabel "$query"'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: _teal.withValues(alpha: 0.12),
                        side: const BorderSide(
                          color: _teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No hay registros activos que coincidan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _hintGrey),
                    ),
                  )
                else
                  ...options.map((item) {
                    final selected = idOf(item) == selectedId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? _teal : const Color(0xFFE2E8E8),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          nameOf(item),
                          style: const TextStyle(color: _textDark),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: _teal,
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                color: _hintGrey,
                              ),
                        onTap: _saving ? null : () => onSelect(item),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _campoCategoria() {
    final query = _newCategoryController.text.trim().toLowerCase();
    final options = _categories.where((item) {
      return item['status_category'] != false &&
          (item['name_category'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query);
    }).toList();
    final exacta = _categories.any(
      (item) =>
          (item['name_category'] ?? '').toString().trim().toLowerCase() ==
              query &&
          query.isNotEmpty &&
          item['status_category'] != false,
    );
    final matches = _categories.where(
      (item) => item['id'] == _selectedCategoryId,
    );
    return _selectorLista(
      titulo: 'Categoría',
      textoSeleccionado: matches.isEmpty
          ? null
          : (matches.first['name_category'] ?? '').toString(),
      placeholder: 'Selecciona una categoría',
      abierto: _categoriaAbierta,
      onToggle: () => setState(
        () => _categoriaAbierta = !_categoriaAbierta,
      ),
      controller: _newCategoryController,
      hint: 'Buscar categoría o crear nueva...',
      options: options,
      nameOf: (item) => (item['name_category'] ?? '').toString(),
      idOf: (item) => item['id'].toString(),
      selectedId: _selectedCategoryId,
      query: query,
      exacta: exacta,
      creando: _creatingCategory,
      onCreate: _createCategory,
      createLabel: 'Crear categoría',
      onSelect: (item) {
        setState(() {
          _selectedCategoryId = item['id'].toString();
          _categoriaAbierta = false;
          _newCategoryController.clear();
        });
        _clearMessages();
      },
    );
  }

  Widget _selectorUnidadInventario() {
    final query = _newUnitController.text.trim().toLowerCase();
    final options = _units.where((item) {
      final name = (item['name_unit'] ?? '').toString().toLowerCase();
      final symbol = (item['symbol_unit'] ?? '').toString().toLowerCase();
      return name.contains(query) || symbol.contains(query);
    }).toList();
    final exacta = _units.any(
      (item) =>
          (item['name_unit'] ?? '').toString().trim().toLowerCase() == query &&
          query.isNotEmpty,
    );
    final unit = _unidadSeleccionada;
    final selected = unit == null
        ? null
        : '${unit['name_unit']} (${unit['symbol_unit'] ?? unit['name_unit']})';
    return _selectorLista(
      titulo: 'Unidad de inventario',
      textoSeleccionado: selected,
      placeholder: 'Selecciona una unidad',
      abierto: _unidadAbierta,
      onToggle: () => setState(() {
        _unidadAbierta = !_unidadAbierta;
        if (!_unidadAbierta) {
          _newUnitController.clear();
        }
      }),
      controller: _newUnitController,
      hint: 'Buscar unidad o crear nueva...',
      options: options,
      nameOf: (item) {
        final name = (item['name_unit'] ?? '').toString();
        final symbol = (item['symbol_unit'] ?? '').toString();
        return symbol.isEmpty ? name : '$name ($symbol)';
      },
      idOf: (item) => item['id'].toString(),
      selectedId: _selectedUnitId,
      query: query,
      exacta: exacta,
      creando: _creatingUnit,
      onCreate: _createUnit,
      createLabel: 'Crear unidad',
      onSelect: (item) {
        setState(() {
          _selectedUnitId = item['id'].toString();
          _unidadAbierta = false;
          _newUnitController.clear();
        });
        _clearMessages();
      },
    );
  }

  Future<DateTime?> _mostrarCalendario({
    required DateTime fechaInicial,
    required DateTime fechaMinima,
    required DateTime fechaMaxima,
  }) async {
    DateTime normalizar(DateTime d) => DateTime(d.year, d.month, d.day);
    final primera = normalizar(fechaMinima);
    final ultima = normalizar(fechaMaxima);
    var inicial = normalizar(fechaInicial);
    if (inicial.isBefore(primera)) inicial = primera;
    if (inicial.isAfter(ultima)) inicial = ultima;
    DateTime seleccion = inicial;
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
                    colorScheme: Theme.of(dialogContext).colorScheme.copyWith(
                          primary: _teal,
                          onPrimary: _textDark,
                          surface: Colors.white,
                          onSurface: _textDark,
                        ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: inicial,
                    firstDate: primera,
                    lastDate: ultima,
                    onDateChanged: (date) => seleccion = date,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cancel,
                        side: const BorderSide(color: _cancel),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(seleccion),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: _teal.withValues(alpha: 0.12),
                        side: const BorderSide(
                          color: _teal,
                          width: 1.5,
                        ),
                      ),
                      child: const Text('Aceptar'),
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

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    String format(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _saving ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              suffixIcon: onClear == null
                  ? const Icon(
                      Icons.calendar_month_outlined,
                      color: _teal,
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: _hintGrey,
                      ),
                      onPressed: _saving ? null : onClear,
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderGrey),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              value == null ? 'Selecciona una fecha' : format(value),
              style: TextStyle(
                color: value == null ? _hintGrey : _textDark,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
  void _cambiarExistenciasSucursal(String branchId, double cambio) {
    if (_saving) return;
    final controller = _stockControllersByBranch.putIfAbsent(
      branchId,
      () => TextEditingController(text: '0'),
    );
    final actual = double.tryParse(
          controller.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final nuevo = (actual + cambio).clamp(0.0, 999999999.0);
    final texto = nuevo == nuevo.roundToDouble()
        ? nuevo.toInt().toString()
        : nuevo.toStringAsFixed(2).replaceFirst(
              RegExp(r'0+$'),
              '',
            );
    controller.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
    _clearMessages();
  }

  Widget _campoInventario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Inventario',
          style: TextStyle(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _selectorUnidadInventario(),
        const SizedBox(height: 16),
        if (!_esEmpleado) ...[
          const Text(
            'Sucursales del producto',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _saving
                ? null
                : () => setState(
                      () => _sucursalAbierta = !_sucursalAbierta,
                    ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _sucursalAbierta ? _teal : _borderGrey,
                  width: _sucursalAbierta ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedBranchIds.isEmpty
                          ? 'Selecciona una o varias sucursales'
                          : '${_selectedBranchIds.length} sucursal(es) seleccionada(s)',
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _sucursalAbierta
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _teal,
                  ),
                ],
              ),
            ),
          ),
          if (_sucursalAbierta)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _borderGrey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView(
                shrinkWrap: true,
                children: _branches.map((branch) {
                  final id = branch['id'].toString();
                  final selected = _selectedBranchIds.contains(id);
                  return CheckboxListTile(
                    dense: true,
                    activeColor: _teal,
                    value: selected,
                    title: Text(
                      (branch['branch_name'] ?? 'Sucursal').toString(),
                      style: const TextStyle(color: _textDark),
                    ),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selectedBranchIds.add(id);
                                _stockControllersByBranch.putIfAbsent(
                                  id,
                                  () => TextEditingController(text: '0'),
                                );
                              } else if (_selectedBranchIds.length > 1) {
                                _selectedBranchIds.remove(id);
                              }
                            });
                            _clearMessages();
                          },
                  );
                }).toList(),
              ),
            ),
        ] else ...[
          const Text(
            'Sucursal asignada',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderGrey),
            ),
            child: Text(
              _branches.isEmpty
                  ? 'No tienes una sucursal asignada'
                  : (_branches.first['branch_name'] ?? 'Sucursal').toString(),
              style: const TextStyle(
                color: _textDark,
                fontSize: 14,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ..._selectedBranchIds.map((id) {
          final branch = _branches.firstWhere(
            (b) => b['id'].toString() == id,
            orElse: () => <String, dynamic>{},
          );
          final branchName = (branch['branch_name'] ?? 'Sucursal').toString();
          final controller = _stockControllersByBranch.putIfAbsent(
            id,
            () => TextEditingController(text: '0'),
          );
          final label = _unidadSeleccionada == null
              ? 'Stock inicial - $branchName'
              : 'Stock inicial - $branchName ($_simboloUnidad)';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _campo(
              titulo: label,
              controller: controller,
              hint: 'Ej. 1.5',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                LengthLimitingTextInputFormatter(15),
              ],
              suffixIcon: SizedBox(
                width: 38,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: _saving
                          ? null
                          : () => _cambiarExistenciasSucursal(id, 1),
                      child: const SizedBox(
                        height: 23,
                        width: 36,
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: _teal,
                          size: 21,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _saving
                          ? null
                          : () => _cambiarExistenciasSucursal(id, -1),
                      child: const SizedBox(
                        height: 23,
                        width: 36,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _teal,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Text(
          _unidadSeleccionada == null
              ? 'Indica las existencias iniciales de cada sucursal. Selecciona una unidad de inventario.'
              : 'Indica las existencias de cada sucursal en $_nombreUnidad ($_simboloUnidad).',
          style: const TextStyle(
            color: _hintGrey,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        _dateField(
          label: 'Fecha de entrada',
          value: _entryDate,
          onTap: () async {
            if (_saving) return;
            final date = await _mostrarCalendario(
              fechaInicial: _entryDate,
              fechaMinima: DateTime(2000),
              fechaMaxima: DateTime(2100),
            );
            if (date == null || !mounted) return;
            setState(() {
              _entryDate = date;
              if (_expiryDate != null &&
                  _expiryDate!.isBefore(
                    DateTime(date.year, date.month, date.day),
                  )) {
                _expiryDate = null;
              }
            });
            _clearMessages();
          },
        ),
        const SizedBox(height: 16),
        _dateField(
          label: 'Fecha de caducidad (opcional)',
          value: _expiryDate,
          onTap: () async {
            if (_saving) return;
            final date = await _mostrarCalendario(
              fechaInicial: _expiryDate ?? _entryDate,
              fechaMinima: DateTime(
                _entryDate.year,
                _entryDate.month,
                _entryDate.day,
              ),
              fechaMaxima: DateTime(2100),
            );
            if (date == null || !mounted) return;
            setState(() => _expiryDate = date);
            _clearMessages();
          },
          onClear: _expiryDate == null
              ? null
              : () {
                  setState(() => _expiryDate = null);
                  _clearMessages();
                },
        ),
      ],
    );
  }

  Future<bool> _confirmRegistration(String name) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Confirmar registro',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas registrar el producto "$name"?',
          style: const TextStyle(
            color: _textDark,
            fontSize: 15,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _cancel,
              side: const BorderSide(color: _cancel),
            ),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: _teal.withValues(alpha: 0.12),
              side: const BorderSide(
                color: _teal,
                width: 1.5,
              ),
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _saveProduct() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final description = _descriptionController.text.trim();
    final unidad = _unidadSeleccionada;
    if (name.isEmpty) {
      _showError('Ingresa el nombre del producto.');
      return;
    }
    if (barcode.isEmpty) {
      _showError('Ingresa el código de barras.');
      return;
    }
    if (unidad == null) {
      _showError('Selecciona una unidad de inventario.');
      return;
    }
    final baseUnit = (unidad['name_unit'] ?? '').toString().trim();
    final baseUnitSymbol =
        (unidad['symbol_unit'] ?? '').toString().trim();
    if (baseUnit.isEmpty) {
      _showError('La unidad seleccionada no tiene un nombre válido.');
      return;
    }
    if (_selectedCategoryId == null ||
        !_categories.any((c) => c['id'] == _selectedCategoryId)) {
      _showError('Selecciona una categoría válida.');
      return;
    }
    if (_saleTypes.isEmpty) {
      _showError('Selecciona al menos una forma de venta.');
      return;
    }
    for (final item in _saleTypes) {
      final id = item['id_type'].toString();
      final price = double.tryParse(
        (_priceControllers[id]?.text ?? '')
            .trim()
            .replaceAll(',', '.'),
      );
      if (price == null || !price.isFinite || price < 0) {
        _showError('Ingresa un precio válido para "${item['name_type']}".');
        return;
      }
      if (_puedeModificarPrecios) {
        item['price'] = price;
      }
      final ups = double.tryParse(
        (_unitsControllers[id]?.text ?? '')
            .trim()
            .replaceAll(',', '.'),
      );
      if (ups == null || !ups.isFinite || ups <= 0) {
        _showError(
          'Las unidades por venta de "${item['name_type']}" deben ser mayores a 0.',
        );
        return;
      }
      item['units_per_sale'] = ups;
    }
    if (!_saleTypes.any((item) => item['status'] == true)) {
      _showError('Activa al menos una forma de venta.');
      return;
    }
    if (_selectedBranchIds.isEmpty ||
        _selectedBranchIds.any(
          (id) => !_branches.any((b) => b['id'].toString() == id),
        )) {
      _showError('Selecciona al menos una sucursal válida.');
      return;
    }
    final role = (Session.user?.roleUser ?? '').trim().toLowerCase();
    if (role != 'administrador' &&
        role != 'supervisor' &&
        role != 'empleado') {
      _showError('No tienes permisos para registrar productos.');
      return;
    }
    final stocksByBranch = <String, double>{};
    for (final id in _selectedBranchIds) {
      final value = double.tryParse(
        (_stockControllersByBranch[id]?.text ?? '0')
            .trim()
            .replaceAll(',', '.'),
      );
      if (value == null || !value.isFinite || value < 0) {
        final branch = _branches.firstWhere(
          (b) => b['id'].toString() == id,
          orElse: () => <String, dynamic>{},
        );
        final branchName =
            (branch['branch_name'] ?? 'sucursal').toString();
        _showError('Ingresa un stock válido para $branchName.');
        return;
      }
      stocksByBranch[id] = value;
    }
    if (_expiryDate != null &&
        _expiryDate!.isBefore(
          DateTime(
            _entryDate.year,
            _entryDate.month,
            _entryDate.day,
          ),
        )) {
      _showError(
        'La fecha de caducidad no puede ser anterior a la fecha de entrada.',
      );
      return;
    }
    final confirmed = await _confirmRegistration(name);
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      String imageUrl = '';
      if (_image != null && _imageBytes != null) {
        imageUrl = await _productService.prepareImage(
          _image!,
          imageBytes: _imageBytes,
        );
      }
      final primeraModalidad = _saleTypes.firstWhere(
        (item) => item['status'] == true,
      );
      final productRef = _db.collection('products').doc();
      final batch = _db.batch();
      batch.set(productRef, {
        'name_product': name,
        'barcode': barcode,
        'description_product': description,
        'id_categories': _selectedCategoryId,
        'base_unit': baseUnit,
        'base_unit_symbol': baseUnitSymbol,
        'prince': primeraModalidad['price'],
        'typeProduct': primeraModalidad['name_type'],
        'sale_types': _saleTypes.map((item) {
          return <String, dynamic>{
            'id_type': item['id_type'],
            'name_type': item['name_type'],
            'price': item['price'],
            'allows_decimal': true,
            'status': item['status'] != false,
            'units_per_sale': item['units_per_sale'] ?? 1,
          };
        }).toList(),
        'image_url': imageUrl,
        'status_product': true,
        'created_at': FieldValue.serverTimestamp(),
      });
      for (final entry in stocksByBranch.entries) {
        final inventoryRef = _db.collection('inventory').doc();
        batch.set(inventoryRef, {
          'id_products': productRef.id,
          'id_branches': entry.key,
          'base_unit': baseUnit,
          'base_unit_symbol': baseUnitSymbol,
          'stock': entry.value,
          'entry_date': Timestamp.fromDate(
            DateTime(
              _entryDate.year,
              _entryDate.month,
              _entryDate.day,
            ),
          ),
          'expiry_date': _expiryDate == null
              ? null
              : Timestamp.fromDate(
                  DateTime(
                    _expiryDate!.year,
                    _expiryDate!.month,
                    _expiryDate!.day,
                  ),
                ),
          'inventory_status': true,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('Error al registrar producto: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      _showError(
        'No se pudo registrar el producto. Verifica Firebase y Storage.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }
  void _showSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
  }
  void _clearMessages() {
    if (_errorMessage != null || _successMessage != null) {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }

  Widget _messages() {
    if (_errorMessage == null && _successMessage == null) {
      return const SizedBox.shrink();
    }
    final error = _errorMessage != null;
    final message = _errorMessage ?? _successMessage!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? const Color(0xFFFDECEA)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error
              ? _red.withValues(alpha: 0.45)
              : const Color(0xFF81C784),
        ),
      ),
      child: Row(
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline,
            color: error ? _red : const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFF1B5E20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _clearMessages,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _botonVolver() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          foregroundColor: _teal,
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

  Widget _formularioCampos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo(
          titulo: 'Nombre del producto',
          controller: _nameController,
          hint: 'Ej. Café de olla',
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),
        _campo(
          titulo: 'Código de barras',
          controller: _barcodeController,
          hint: 'Escanea o escribe el código',
          capitalization: TextCapitalization.none,
        ),
        const SizedBox(height: 20),
        _campo(
          titulo: 'Descripción',
          controller: _descriptionController,
          hint: 'Descripción del producto',
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        _campoCategoria(),
        const SizedBox(height: 25),
        _campoModalidades(),
        const SizedBox(height: 25),
        _campoImagen(),
        const SizedBox(height: 24),
        _campoInventario(),
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
                titulo: 'Nombre del producto',
                controller: _nameController,
                hint: 'Ej. Café de olla',
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 25),
              _campo(
                titulo: 'Código de barras',
                controller: _barcodeController,
                hint: 'Escanea o escribe el código',
                capitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 25),
              _campo(
                titulo: 'Descripción',
                controller: _descriptionController,
                hint: 'Descripción del producto',
                maxLines: 3,
              ),
              const SizedBox(height: 25),
              _campoCategoria(),
              const SizedBox(height: 25),
              _campoModalidades(),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _campoImagen(),
              const SizedBox(height: 24),
              _campoInventario(),
            ],
          ),
        ),
      ],
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
          controller: _scrollController,
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
                  _messages(),
                  _botonVolver(),
                  const SizedBox(height: 12),
                  Text(
                    'Registrar producto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 25 : 32,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completa los datos del nuevo producto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                  const SizedBox(height: 34),
                  if (_loadingOptions)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _teal,
                        ),
                      ),
                    )
                  else if (isMobile)
                    _formularioCampos()
                  else
                    _formularioDesktop(),
                  const SizedBox(height: 36),
                  Center(
                    child: SizedBox(
                      width: isMobile ? double.infinity : 420,
                      height: 52,
                      child: PrimaryButton(
                        text: _saving
                            ? 'Registrando...'
                            : 'Registrar producto',
                        onPressed: _saving || _loadingOptions
                            ? null
                            : _saveProduct,
                      ),
                    ),
                  ),
                  if (_saving) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: _green),
                          SizedBox(height: 10),
                          Text(
                            'Guardando producto, espera un momento...',
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    const radius = 12.0;
    const dashWidth = 7.0;
    const dashSpace = 5.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            0.75,
            0.75,
            size.width - 1.5,
            size.height - 1.5,
          ),
          const Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(
          0.0,
          metric.length,
        );
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }
  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
