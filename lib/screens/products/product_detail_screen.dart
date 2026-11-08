import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart';
import '../../../services/product_service.dart';
import '../../../widgets/save.dart';
import '../../../widgets/cancel.dart';

const Color _green = Color(0xFF0F6B1F);
const Color _red = Color(0xFFF4512A);
const Color _borderGrey = Color(0xFFBDBDBD);
const Color _teal = Color(0xFF63B7C4);
const Color _textDark = Color(0xFF212121);
const Color _hintGrey = Color(0xFF9E9E9E);
const Color _mutedGrey = Color(0xFF757575);
const Color _cancel = Color(0xFFF4512A);
const Color _disabledFill = Color(0xFFF7F8F9);

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductService _service = ProductService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _newTypeController = TextEditingController();
  final TextEditingController _newUnitController = TextEditingController();
  final TextEditingController _stockController =  TextEditingController(text: '0');
  final FocusNode _stockFocusNode = FocusNode();
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _unitsControllers = {};
  List<Map<String, dynamic>> _allBranches = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _unidadHuerfana;

  String? _selectedBranchId;
  final Set<String> _selectedBranchIds = {};
  final Map<String, TextEditingController> _stockControllersByBranch = {};
  final Map<String, String> _inventoryIdsByBranch = {};
  String? _selectedCategoryId;
  String? _selectedUnitId;
  List<Map<String, dynamic>> _saleTypes = [];
  DateTime? _entryDate;
  DateTime? _expiryDate;
  String _baseUnitStored = '';
  String _baseUnitSymbolStored = '';
  String _imagenUrl = '';
  XFile? _nuevaImagen;
  Uint8List? _nuevaImagenBytes;
  bool _quitarImagen = false;
  String _nombreOriginal = '';
  String _codigoOriginal = '';
  String _descripcionOriginal = '';
  String _stockOriginal = '0';
  String _imagenOriginal = '';
  String? _categoriaOriginal;
  String? _unidadOriginal;
  String? _sucursalOriginal;
  Set<String> _sucursalesOriginales = {};
  Map<String, String> _stocksOriginalesPorSucursal = {};
  DateTime? _fechaEntradaOriginal;
  DateTime? _fechaCaducidadOriginal;
  List<Map<String, dynamic>> _saleTypesOriginales = [];
  bool _editando = false;
  bool _cargando = true;
  bool _guardando = false;
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
      (Session.user?.roleUser ?? '').toString().trim().toLowerCase() ==
      'empleado';
  bool get _puedeModificarPrecios {
    final rol =
        (Session.user?.roleUser ?? '').toString().trim().toLowerCase();
    return rol == 'administrador' || rol == 'supervisor';
  }
  bool get _bloqueado => !_editando || _guardando;
  ButtonStyle get _cancelStyle => OutlinedButton.styleFrom(
        foregroundColor: _cancel,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _cancel, width: 1.5),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );
  ButtonStyle get _acceptStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: _teal.withValues(alpha: 0.12),
        side: const BorderSide(color: _teal, width: 1.5),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );
  @override
  void initState() {
    super.initState();
    _inicializar();
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
    _stockFocusNode.dispose();
    _scrollController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _unitsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _loadOptions();
    await _cargarProducto();
  }
  num _numero(dynamic valor) {
    if (valor is num) return valor;
    return num.tryParse(
          valor?.toString().replaceAll(',', '.') ?? '',
        ) ??
        0;
  }
  String _fmtNum(num valor) {
    final d = valor.toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }
  String _claveTipo(Map<String, dynamic> item) =>
      (item['_key'] ?? item['id_type'] ?? '').toString();

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        _db.collection('categories').get(),
        _db.collection('product_types').get(),
        _db.collection('branches').get(),
        _db.collection('inventory').get(),
      ]);
      final categories = results[0].docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList()
        ..sort((a, b) => (a['name_category'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name_category'] ?? '').toString().toLowerCase()));
      final types = results[1].docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList()
        ..sort((a, b) => (a['name_type'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name_type'] ?? '').toString().toLowerCase()));
      final unitsMap = <String, Map<String, dynamic>>{};
      for (final doc in results[3].docs) {
        final d = doc.data();
        final name = (d['base_unit'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        unitsMap.putIfAbsent(
          name.toLowerCase(),
          () => <String, dynamic>{
            'id': name.toLowerCase(),
            'name_unit': name,
            'symbol_unit': (d['base_unit_symbol'] ?? '').toString().trim(),
            'status_unit': true,
          },
        );
      }
      for (final u in _units) {
        unitsMap.putIfAbsent(u['id'].toString(), () => u);
      }
      final units = unitsMap.values.toList()
        ..sort((a, b) => (a['name_unit'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name_unit'] ?? '').toString().toLowerCase()));
      final todasSucursales = results[2].docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList();
      final allBranches = todasSucursales
          .where((branch) => branch['branch_status'] != false)
          .toList();
      final user = Session.user;
      final role = (user?.roleUser ?? '').toString().trim().toLowerCase();
      final assignedIds = <String>[];
      final dynamic assigned = user?.idBranches;
      String idDe(dynamic item) {
        if (item == null) return '';
        if (item is DocumentReference) return item.id;
        if (item is Map) return idDe(item['id'] ?? item['id_branches']);
        final text = item.toString().trim();
        return text.contains('/') ? text.split('/').last : text;
      }
      if (assigned is Iterable) {
        for (final item in assigned) {
          final id = idDe(item);
          if (id.isNotEmpty) assignedIds.add(id);
        }
      } else {
        final id = idDe(assigned);
        if (id.isNotEmpty) assignedIds.add(id);
      }
      final branches = allBranches.where((branch) {
        if (role == 'administrador') return true;
        if (role == 'supervisor' || role == 'empleado') {
          return assignedIds.contains(branch['id'].toString());
        }
        return false;
      }).toList()
        ..sort((a, b) => (a['branch_name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['branch_name'] ?? '').toString().toLowerCase()));
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _types = types;
        _units = units;
        _allBranches = todasSucursales;
        _branches = branches;
        if (_selectedUnitId != null &&
            _unidadHuerfana != null &&
            !_units.any((u) => u['id'].toString() == _selectedUnitId)) {
          _units.add(_unidadHuerfana!);
        }
      });
    } catch (e) {
      debugPrint('Error al cargar opciones: $e');
      if (!mounted) return;
      _showError('No se pudieron cargar las opciones del formulario.');
    }
  }

  Future<void> _cargarProducto() async {
    try {
      final doc =
          await _db.collection('products').doc(widget.productId).get();
      if (!doc.exists) {
        if (!mounted) return;
        setState(() => _cargando = false);
        _showError('No se encontró el producto.');
        return;
      }
      final data = doc.data() ?? {};
      _nameController.text = (data['name_product'] ?? '').toString();
      _barcodeController.text = (data['barcode'] ?? '').toString();
      _descriptionController.text = (data['description_product'] ?? '').toString();
      final categoria = (data['id_categories'] ?? '').toString();
      _selectedCategoryId = categoria.isEmpty ? null : categoria;
      _baseUnitStored = (data['base_unit'] ?? '').toString().trim();
      _baseUnitSymbolStored = (data['base_unit_symbol'] ?? '').toString();
      _selectedUnitId =
      _baseUnitStored.isEmpty ? null : _baseUnitStored.toLowerCase();
      _imagenUrl = (data['image_url'] ?? '').toString();
      _saleTypes = _normalizarSaleTypes(data['sale_types']);
      if (_saleTypes.isEmpty &&
          (data['typeProduct'] ?? '').toString().trim().isNotEmpty) {
        _saleTypes = [
          {
            'id_type': '',
            'name_type': data['typeProduct'].toString(),
            'price': _numero(data['prince']).toDouble(),
            'allows_decimal': true,
            'units_per_sale': 1.0,
            'status': true,
          }
        ];
      }
      await _cargarInventario();
      if (_selectedUnitId != null &&
          !_units.any((u) => u['id'].toString() == _selectedUnitId)) {
        _unidadHuerfana = {
          'id': _selectedUnitId,
          'name_unit': _baseUnitStored,
          'symbol_unit': _baseUnitSymbolStored,
          'status_unit': true,
        };
        _units.add(_unidadHuerfana!);
      }
      if (_esEmpleado && _branches.isNotEmpty) {
        _selectedBranchId = _branches.first['id'].toString();
        _selectedBranchIds..clear()..add(_selectedBranchId!);
        _stockControllersByBranch.putIfAbsent(_selectedBranchId!, () => TextEditingController(text: '0'));
      } else {
        _selectedBranchIds.removeWhere((id) => !_branches.any((b) => b['id'].toString() == id));
        if (_selectedBranchIds.isEmpty && _branches.isNotEmpty) {
        _selectedBranchIds.add(_branches.first['id'].toString());
        _stockControllersByBranch.putIfAbsent(_branches.first['id'].toString(), () => TextEditingController(text: '0'));
        }
        _selectedBranchId = _selectedBranchIds.isEmpty ? null : _selectedBranchIds.first;
      }
      _prepararControlesTipos();
      _guardarOriginales();
      if (!mounted) return;
      setState(() => _cargando = false);
    } catch (e) {
      debugPrint('Error al cargar el producto: $e');
      if (!mounted) return;
      setState(() => _cargando = false);
      _showError('Error al cargar el producto.');
    }
  }

  Future<void> _cargarInventario() async {
    try {
      final consulta = await _db.collection('inventory').where('id_products', isEqualTo: widget.productId).get();
      _inventoryIdsByBranch.clear();
      _selectedBranchIds.clear();
      if (consulta.docs.isEmpty) {
        _stockController.text = '0';
        _entryDate = null;
        _expiryDate = null;
        return;
      }
      for (final doc in consulta.docs) {
        final data = doc.data();
        final branchId = (data['id_branches'] ?? '').toString();
        if (branchId.isEmpty) continue;
        _inventoryIdsByBranch[branchId] = doc.id;
        _selectedBranchIds.add(branchId);
        final controller = _stockControllersByBranch.putIfAbsent(branchId, () => TextEditingController());
        controller.text = _fmtNum(_numero(data['stock']));
      }
      if (_selectedBranchIds.isNotEmpty) {
        _selectedBranchId = _selectedBranchIds.first;
        _stockController.text = _stockControllersByBranch[_selectedBranchId]?.text ?? '0';
      }
      final data = consulta.docs.first.data();
      final baseUnit = (data['base_unit'] ?? '').toString().trim();
      if (baseUnit.isNotEmpty) { _baseUnitStored = baseUnit; _selectedUnitId = baseUnit.toLowerCase(); }
      final simbolo = (data['base_unit_symbol'] ?? '').toString();
      if (simbolo.isNotEmpty) _baseUnitSymbolStored = simbolo;
      final entrada = data['entry_date'];
      _entryDate = entrada is Timestamp ? entrada.toDate() : null;
      final caducidad = data['expiry_date'];
      _expiryDate = caducidad is Timestamp ? caducidad.toDate() : null;
    } catch (e) {
      debugPrint('Error al cargar el inventario: $e');
      _showError('Error al cargar el inventario.');
    }
  }

  List<Map<String, dynamic>> _normalizarSaleTypes(dynamic valor) {
    if (valor is! List) return [];
    return valor.whereType<Map>().map((elemento) {
      final mapa = Map<String, dynamic>.from(elemento);
      final ups = _numero(mapa['units_per_sale']).toDouble();
      return <String, dynamic>{
        'id_type': (mapa['id_type'] ?? '').toString(),
        'name_type': (mapa['name_type'] ?? '').toString(),
        'price': _numero(mapa['price']).toDouble(),
        'allows_decimal': true,
        'units_per_sale': ups > 0 ? ups : 1.0,
        'status': mapa['status'] != false,
      };
    }).toList();
  }

  void _prepararControlesTipos() {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _unitsControllers.values) {
      controller.dispose();
    }
    _priceControllers.clear();
    _unitsControllers.clear();
    for (final tipo in _saleTypes) {
      final id = (tipo['id_type'] ?? '').toString();
      final nombre = (tipo['name_type'] ?? '').toString();
      final clave = id.isNotEmpty
          ? id
          : 'legacy_${nombre.toLowerCase().replaceAll(' ', '_')}';
      tipo['_key'] = clave;
      final partes = _numero(tipo['price'])
      .toDouble()
      .toStringAsFixed(2)
      .split('.');
      final entero = partes[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
      _priceControllers[clave] = TextEditingController(
        text: '$entero.${partes[1]}',
      );
      _unitsControllers[clave] = TextEditingController(
        text: _fmtNum(_numero(tipo['units_per_sale'])),
      );
    }
  }

  void _guardarOriginales() {
    _nombreOriginal = _nameController.text;
    _codigoOriginal = _barcodeController.text;
    _descripcionOriginal = _descriptionController.text;
    _stockOriginal = _stockController.text;
    _imagenOriginal = _imagenUrl;
    _categoriaOriginal = _selectedCategoryId;
    _unidadOriginal = _selectedUnitId;
    _sucursalOriginal = _selectedBranchId;
    _sucursalesOriginales = Set<String>.from(_selectedBranchIds);
    _stocksOriginalesPorSucursal = {for (final id in _selectedBranchIds) id: _stockControllersByBranch[id]?.text ?? '0'};
    _fechaEntradaOriginal = _entryDate;
    _fechaCaducidadOriginal = _expiryDate;
    _saleTypesOriginales = _saleTypes
        .map((tipo) => Map<String, dynamic>.from(tipo))
        .toList();
  }

  Future<void> _createCategory() async {
    if (_bloqueado || _creatingCategory) return;
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      _showError('Escribe el nombre de la categoría.');
      return;
    }
    setState(() => _creatingCategory = true);
    try {
      final snapshot = await _db.collection('categories').get();
      final matches = snapshot.docs.where((doc) =>
          (doc.data()['name_category'] ?? '')
              .toString()
              .trim()
              .toLowerCase() ==
          name.toLowerCase());
      String id;
      if (matches.isNotEmpty) {
        final existing = matches.first;
        id = existing.id;
        if (existing.data()['status_category'] == false) {
          await existing.reference.update({'status_category': true});
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
      if (mounted) setState(() => _creatingCategory = false);
    }
  }

  Map<String, dynamic>? get _unidadSeleccionada {
    for (final unit in _units) {
      if (unit['id'].toString() == _selectedUnitId) return unit;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Crear unidad de inventario',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unidad: $nombre',
                style: const TextStyle(
                    color: _textDark, fontWeight: FontWeight.w600)),
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
                  borderSide: const BorderSide(color: _teal, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: _cancelStyle,
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () {
              final symbol = controller.text.trim();
              if (symbol.isNotEmpty) Navigator.of(dialogContext).pop(symbol);
            },
            style: _acceptStyle,
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
  Future<void> _createUnit() async {
    if (_bloqueado || _creatingUnit) return;
    final name = _newUnitController.text.trim();
    if (name.isEmpty) {
      _showError('Escribe el nombre de la unidad de inventario.');
      return;
    }
    setState(() => _creatingUnit = true);
    try {
      final key = name.toLowerCase();
      final existing = _units.where((u) => u['id'].toString() == key);
      if (existing.isEmpty) {
        final symbol = await _pedirSimboloUnidad(name);
        if (symbol == null || symbol.trim().isEmpty) return;
        _units.add(<String, dynamic>{
          'id': key,
          'name_unit': name,
          'symbol_unit': symbol.trim(),
          'status_unit': true,
        });
      }
      if (!mounted) return;
      setState(() {
        _selectedUnitId = key;
        _unidadAbierta = false;
      });
      _newUnitController.clear();
      _showSuccess('Unidad de inventario seleccionada correctamente.');
    } catch (e) {
      debugPrint('Error al crear unidad: $e');
      _showError('No se pudo crear la unidad de inventario.');
    } finally {
      if (mounted) setState(() => _creatingUnit = false);
    }
  }
  Future<void> _createType() async {
    if (_bloqueado || _creatingType) return;
    final name = _newTypeController.text.trim();
    if (name.isEmpty) {
      _showError('Escribe el nombre de la forma de venta.');
      return;
    }
    setState(() => _creatingType = true);
    try {
      final snapshot = await _db.collection('product_types').get();
      final matches = snapshot.docs.where((doc) =>
          (doc.data()['name_type'] ?? '')
              .toString()
              .trim()
              .toLowerCase() ==
          name.toLowerCase());
      String id;
      if (matches.isNotEmpty) {
        final existing = matches.first;
        id = existing.id;
        if (existing.data()['status_type'] == false) {
          await existing.reference.update({'status_type': true});
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
      final type = _types.where((item) => item['id'].toString() == id);
      if (type.isNotEmpty) _toggleSaleType(type.first, true);
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
      if (mounted) setState(() => _creatingType = false);
    }
  }
  bool _typeIsSelected(String id) =>
      _saleTypes.any((item) => item['id_type'].toString() == id);
  void _toggleSaleType(Map<String, dynamic> type, bool selected) {
    if (_bloqueado) return;
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
          '_key': id,
        });
        _errorMessage = null;
        _successMessage = null;
      });
    } else if (!selected && _typeIsSelected(id)) {
      _quitarTipoPorClave(id);
    }
  }

  void _quitarTipoPorClave(String clave) {
    if (_bloqueado) return;
    setState(() {
      _saleTypes.removeWhere((item) => _claveTipo(item) == clave);
      _priceControllers.remove(clave)?.dispose();
      _unitsControllers.remove(clave)?.dispose();
      _errorMessage = null;
      _successMessage = null;
    });
  }

  void _updateSalePrice(String clave, String value) {
    if (!_puedeModificarPrecios) return;
    final normalized = value.replaceAll(',', '');
    final price = double.tryParse(normalized);
    final index = _saleTypes.indexWhere((item) => _claveTipo(item) == clave);
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

  void _changeSalePrice(String clave, double change) {
    if (_bloqueado || !_puedeModificarPrecios) return;
    final controller = _priceControllers[clave];
    if (controller == null) return;
    final actual = double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;
    final next = (actual + change).clamp(0.0, 999999999.0);
    final partes = next.toStringAsFixed(2).split('.');
    final entero = partes[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    final text = '$entero.${partes[1]}';
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _updateSalePrice(clave, text);
        setState(() {});
      }

  Widget _priceField(String clave, String typeName) {
    final controller = _priceControllers[clave];
    if (controller == null) return const SizedBox.shrink();
    void normalizarPrecio() {
    final valor = double.tryParse(
      controller.text.trim().replaceAll(',', ''),
    ) ?? 0.0;
    final precio = valor.isFinite && valor >= 0 ? valor : 0.0;
    final partes = precio.toStringAsFixed(2).split('.');
    final entero = partes[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    final texto = '$entero.${partes[1]}';
    controller.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
    _updateSalePrice(clave, texto);
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
        enabled: !_bloqueado,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onTapOutside: (_) {
          normalizarPrecio();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        onEditingComplete: () {
         normalizarPrecio();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          LengthLimitingTextInputFormatter(10),
        ],
          onChanged: (value) => _updateSalePrice(clave, value),
          style: const TextStyle(fontSize: 15, color: _textDark),
          decoration: InputDecoration(
            hintText: 'Ej. 25.00',
            hintStyle: const TextStyle(color: _hintGrey, fontSize: 14),
            prefixText: '\$ ',
            filled: true,
            fillColor: _bloqueado ? _disabledFill : Colors.white,
            suffixIcon: SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap:
                        _bloqueado || !_puedeModificarPrecios
                        ? null
                        : () => _changeSalePrice(clave, 1),
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
                    onTap:
                        _bloqueado || !_puedeModificarPrecios
                        ? null
                        : () => _changeSalePrice(clave, -1),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
              borderSide: const BorderSide(color: _teal, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  void _updateUnitsPerSale(String clave, String value) {
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    final index = _saleTypes.indexWhere((item) => _claveTipo(item) == clave);
    if (index < 0) return;
    _saleTypes[index]['units_per_sale'] =
        n != null && n.isFinite && n > 0 ? n : 1.0;
  }

  void _changeUnitsPerSale(String clave, double change) {
    if (_bloqueado) return;
    final controller = _unitsControllers[clave];
    if (controller == null) return;
    final actual = double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 1;
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
    if (controller == null) return const SizedBox.shrink();
    void normalizarUnidades() {
    final valor = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    ) ?? 1.0;

    final unidades = valor.isFinite && valor >= 1 ? valor : 1.0;

    final texto = unidades == unidades.roundToDouble()
        ? unidades.toInt().toString()
        : unidades.toString();

    controller.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );

    _updateUnitsPerSale(clave, texto);
    setState(() {});
  }
    final cantidad =
        double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 1;
    final cantidadTexto = cantidad == cantidad.roundToDouble()
        ? cantidad.toInt().toString()
        : cantidad.toString();
    final unidad = _unidadSeleccionada == null ? 'unidades' : _simboloUnidad;
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
          style: const TextStyle(color: _hintGrey, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_bloqueado,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onTapOutside: (_) {
            normalizarUnidades();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          onEditingComplete: () {
            normalizarUnidades();
            FocusManager.instance.primaryFocus?.unfocus();
          },
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
          style: const TextStyle(fontSize: 15, color: _textDark),
          decoration: InputDecoration(
            hintText: 'Ej. 12',
            hintStyle: const TextStyle(color: _hintGrey, fontSize: 14),
            filled: true,
            fillColor: _bloqueado ? _disabledFill : Colors.white,
            suffixIcon: SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: _bloqueado
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
                    onTap: _bloqueado
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
              borderSide: const BorderSide(color: _teal, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF757575), size: 18),
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
          style: TextStyle(color: _hintGrey, fontSize: 13, height: 1.4),
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
                onTap: _bloqueado
                    ? null
                    : () => setState(() => _tiposAbiertos = !_tiposAbiertos),
              ),
              if (_tiposAbiertos && !_bloqueado) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    controller: _newTypeController,
                    enabled: !_bloqueado && !_creatingType,
                    onChanged: (value) =>
                        setState(() => _typeQuery = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Buscar o crear forma de venta...',
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: _teal),
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
                        borderSide:
                            const BorderSide(color: _teal, width: 1.5),
                      ),
                    ),
                  ),
                ),
                if (_typeQuery.isNotEmpty &&
                    !options.any((item) =>
                        (item['name_type'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase() ==
                        _typeQuery)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _bloqueado || _creatingType ? null : _createType,
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
                          side: const BorderSide(color: _teal, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
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
                return ListTile(
                      minLeadingWidth: 0,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? _teal : Colors.white,
                          border: selected
                              ? null
                              : Border.all(
                                  color: _borderGrey,
                                  width: 2.7,
                                ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      title: Text(
                        (type['name_type'] ?? '').toString(),
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 15,
                        ),
                      ),
                      onTap: _bloqueado
                          ? null
                          : () => _toggleSaleType(type, !selected),
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
              style: TextStyle(color: _hintGrey, height: 1.4),
            ),
          )
        else
          ..._saleTypes.map((item) {
            final clave = _claveTipo(item);
            final name = (item['name_type'] ?? '').toString();
            final active = item['status'] == true;
            return Container(
              key: ValueKey(clave),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: active ? _teal : _borderGrey),
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
                        child: const Icon(Icons.sell_outlined, color: _teal),
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
                        enabled: !_bloqueado,
                        onSelected: (value) {
                          if (value == 'toggle') {
                            setState(() {
                              item['status'] = item['status'] != true;
                            });
                          } else if (value == 'remove') {
                            _quitarTipoPorClave(clave);
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
                  _priceField(clave, name),
                  const SizedBox(height: 8),
                  _unitsField(clave, name),
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
  bool get _tieneImagen =>
      !_quitarImagen &&
      (_nuevaImagenBytes != null || _imagenUrl.trim().isNotEmpty);
  Future<void> _selectImage() async {
    if (_bloqueado) return;
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
          List<int>.generate(signature.length, (i) => bytes[i]).toString() ==
              signature.toString();
      if (!valid) {
        _showError('El archivo seleccionado no es una imagen PNG válida.');
        return;
      }
      setState(() {
        _nuevaImagen = selected;
        _nuevaImagenBytes = bytes;
        _quitarImagen = false;
      });
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      _showError('No se pudo seleccionar la imagen.');
    }
  }
  void _removeImage() {
    if (_bloqueado) return;
    setState(() {
      _quitarImagen = true;
      _nuevaImagen = null;
      _nuevaImagenBytes = null;
    });
  }

  Widget _imagenGuardada(String valor, BoxFit fit, Widget vacio) {
    final imagen = valor.trim();
    if (imagen.isEmpty) return vacio;
    if (imagen.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(imagen.split(',').last),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => vacio,
        );
      } catch (_) {
        return vacio;
      }
    }
    return Image.network(
      imagen,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => vacio,
    );
  }

  Widget _iconoSinImagen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: _teal,
            size: 35,
          ),
          SizedBox(height: 6),
          Text(
            'Sin imagen',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _hintGrey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderAgregarImagen() {
    return const Column(
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
    );
  }

  Widget _campoImagen() {
    final tiene = _tieneImagen;
    final vacio = _editando ? _placeholderAgregarImagen() : _iconoSinImagen();
    Widget contenido;
    if (_nuevaImagenBytes != null) {
      contenido = Padding(
        padding: const EdgeInsets.all(8),
        child: Image.memory(
          _nuevaImagenBytes!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        ),
      );
    } else if (tiene) {
      contenido = Padding(
        padding: const EdgeInsets.all(8),
        child: _imagenGuardada(
          _imagenUrl,
          BoxFit.contain,
          vacio,
        ),
      );
    } else {
      contenido = vacio;
    }
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
          foregroundPainter: const _DashedBorderPainter(
            color: _teal,
          ),
          child: Container(
            width: double.infinity,
            height: 210,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _bloqueado ? _disabledFill : const Color(0xFFFAFCFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  contenido,
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _bloqueado ? null : _selectImage,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  if (tiene && !_bloqueado)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Quitar imagen',
                          onPressed: _removeImage,
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
    FocusNode? focusNode,
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
          focusNode: focusNode,
          enabled: !_bloqueado,
          maxLines: maxLines,
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onTapOutside: focusNode == null ? null : (_) => focusNode.unfocus(),
          onChanged: (_) => _clearMessages(),
          style: const TextStyle(fontSize: 15, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _hintGrey, fontSize: 14),
            filled: true,
            fillColor: _bloqueado ? _disabledFill : Colors.white,
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
              borderSide: const BorderSide(color: _teal, width: 1.6),
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
    final abiertoReal = abierto && !_bloqueado;
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
          onTap: _bloqueado ? null : onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _bloqueado ? _disabledFill : Colors.white,
              border: Border.all(
                color: abiertoReal ? _teal : _borderGrey,
                width: abiertoReal ? 1.6 : 1,
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
                      color: textoSeleccionado == null ? _hintGrey : _textDark,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  abiertoReal
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: abiertoReal ? _teal : _hintGrey,
                ),
              ],
            ),
          ),
        ),
        if (abiertoReal) ...[
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
                  enabled: !_bloqueado && !creando,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: _teal),
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
                      borderSide: const BorderSide(color: _teal, width: 1.5),
                    ),
                  ),
                ),
                if (query.isNotEmpty && !exacta) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _bloqueado || creando ? null : onCreate,
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
                        side: const BorderSide(color: _teal, width: 1.5),
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
                            ? const Icon(Icons.check_circle_rounded,
                                color: _teal)
                            : const Icon(Icons.chevron_right_rounded,
                                color: _hintGrey),
                        onTap: _bloqueado ? null : () => onSelect(item),
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
    final exacta = _categories.any((item) =>
        (item['name_category'] ?? '').toString().trim().toLowerCase() ==
            query &&
        query.isNotEmpty &&
        item['status_category'] != false);
    final matches =
        _categories.where((item) => item['id'] == _selectedCategoryId);
    return _selectorLista(
      titulo: 'Categoría',
      textoSeleccionado: matches.isEmpty
          ? null
          : (matches.first['name_category'] ?? '').toString(),
      placeholder: 'Selecciona una categoría',
      abierto: _categoriaAbierta,
      onToggle: () => setState(() => _categoriaAbierta = !_categoriaAbierta),
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
      return item['status_unit'] != false &&
          (name.contains(query) || symbol.contains(query));
    }).toList();
    final exacta = _units.any((item) =>
        (item['name_unit'] ?? '').toString().trim().toLowerCase() == query &&
        query.isNotEmpty &&
        item['status_unit'] != false);
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
        if (!_unidadAbierta) _newUnitController.clear();
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
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: _cancelStyle,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(seleccion),
                        style: _acceptStyle,
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
          onTap: _bloqueado ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: _bloqueado ? _disabledFill : Colors.white,
              suffixIcon: onClear == null || _bloqueado
                  ? const Icon(Icons.calendar_month_outlined, color: _teal)
                  : IconButton(
                      icon: const Icon(Icons.close, color: _hintGrey),
                      onPressed: onClear,
                    ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    if (_bloqueado) return;
    final controller = _stockControllersByBranch.putIfAbsent(branchId, () => TextEditingController(text: '0'));
    final actual = double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    final nuevo = (actual + cambio).clamp(0.0, 999999999.0);
    final texto = nuevo == nuevo.roundToDouble() ? nuevo.toInt().toString() : nuevo.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    controller.value = TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
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
          const Text('Sucursales del producto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textDark)),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _bloqueado ? null : () => setState(() => _sucursalAbierta = !_sucursalAbierta),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: _bloqueado ? _disabledFill : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _sucursalAbierta ? _teal : _borderGrey, width: _sucursalAbierta ? 1.5 : 1)),
              child: Row(children: [Expanded(child: Text(_selectedBranchIds.isEmpty ? 'Selecciona una o varias sucursales' : '${_selectedBranchIds.length} sucursal(es) seleccionada(s)', style: const TextStyle(color: _textDark, fontSize: 14))), Icon(_sucursalAbierta ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _teal)]),
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
                  return ListTile(
                    dense: true,
                    minLeadingWidth: 0,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                   leading: Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? _teal : Colors.white,
                        border: selected
                            ? null
                            : Border.all(
                                color: _borderGrey,
                                width: 2.7,
                              ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    title: Text(
                      (branch['branch_name'] ?? 'Sucursal').toString(),
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 15,
                      ),
                    ),
                    onTap: _bloqueado
                        ? null
                        : () {
                            setState(() {
                              if (!selected) {
                                _selectedBranchIds.add(id);
                                _stockControllersByBranch.putIfAbsent(
                                  id,
                                  () => TextEditingController(text: '0'),
                                );
                              } else if (_selectedBranchIds.length > 1 &&
                                  !_inventoryIdsByBranch.containsKey(id)) {
                                _selectedBranchIds.remove(id);
                              }
                              _selectedBranchId = _selectedBranchIds.isEmpty
                                  ? null
                                  : _selectedBranchIds.first;
                            });
                            _clearMessages();
                          },
                  );
                }).toList(),
              ),
            ),
        ],
        const SizedBox(height: 16),
        ..._selectedBranchIds.map((id) {
          final branch = (_allBranches.where((b) => b['id'].toString() == id).isEmpty ? null : _allBranches.firstWhere((b) => b['id'].toString() == id));
          final branchName = (branch?['branch_name'] ?? 'Sucursal').toString();
          final controller = _stockControllersByBranch.putIfAbsent(id, () => TextEditingController(text: '0'));
          final stockLabel = _unidadSeleccionada == null ? 'Stock - $branchName' : 'Stock - $branchName ($_simboloUnidad)';
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: _campo(
            titulo: stockLabel, controller: controller, hint: 'Ej. 1.5', keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')), LengthLimitingTextInputFormatter(15)],
            suffixIcon: SizedBox(width: 38, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              InkWell(onTap: _bloqueado ? null : () => _cambiarExistenciasSucursal(id, 1), child: const SizedBox(height: 23, width: 36, child: Icon(Icons.keyboard_arrow_up_rounded, color: _teal, size: 21))),
              InkWell(onTap: _bloqueado ? null : () => _cambiarExistenciasSucursal(id, -1), child: const SizedBox(height: 23, width: 36, child: Icon(Icons.keyboard_arrow_down_rounded, color: _teal, size: 21))),
            ])),
          ));
        }),
        Text(_unidadSeleccionada == null ? 'Indica las existencias de cada sucursal. Selecciona una unidad de inventario.' : 'Indica las existencias de cada sucursal en $_nombreUnidad ($_simboloUnidad).', style: const TextStyle(color: _hintGrey, fontSize: 12, height: 1.4)),
        const SizedBox(height: 16),
        _dateField(
          label: 'Fecha de entrada',
          value: _entryDate,
          onTap: () async {
            if (_bloqueado) return;
            final date = await _mostrarCalendario(
              fechaInicial: _entryDate ?? DateTime.now(),
              fechaMinima: DateTime(2000),
              fechaMaxima: DateTime(2100),
            );
            if (date == null || !mounted) return;
            setState(() {
              _entryDate = date;
              if (_expiryDate != null &&
                  _expiryDate!
                      .isBefore(DateTime(date.year, date.month, date.day))) {
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
            if (_bloqueado) return;
            final entrada = _entryDate;
            final date = await _mostrarCalendario(
              fechaInicial: _expiryDate ?? entrada ?? DateTime.now(),
              fechaMinima: entrada == null
                  ? DateTime(2000)
                  : DateTime(entrada.year, entrada.month, entrada.day),
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

  void _regresar() {
    Navigator.of(context).maybePop();
  }
  void _editar() {
    setState(() {
      _editando = true;
      _quitarImagen = false;
      _errorMessage = null;
      _successMessage = null;
    });
  }
  void _cancelar() {
    setState(() {
      _nameController.text = _nombreOriginal;
      _barcodeController.text = _codigoOriginal;
      _descriptionController.text = _descripcionOriginal;
      _stockController.text = _stockOriginal;
      _selectedCategoryId = _categoriaOriginal;
      _selectedUnitId = _unidadOriginal;
      _selectedBranchId = _sucursalOriginal;
      _selectedBranchIds..clear()..addAll(_sucursalesOriginales);
      for (final entry in _stocksOriginalesPorSucursal.entries) {
      _stockControllersByBranch.putIfAbsent(entry.key, () => TextEditingController()).text = entry.value;
      }
      _entryDate = _fechaEntradaOriginal;
      _expiryDate = _fechaCaducidadOriginal;
      _imagenUrl = _imagenOriginal;
      _saleTypes = _saleTypesOriginales
          .map((tipo) => Map<String, dynamic>.from(tipo))
          .toList();
      _prepararControlesTipos();
      _newCategoryController.clear();
      _newTypeController.clear();
      _newUnitController.clear();
      _typeQuery = '';
      _categoriaAbierta = false;
      _unidadAbierta = false;
      _sucursalAbierta = false;
      _tiposAbiertos = false;
      _nuevaImagen = null;
      _nuevaImagenBytes = null;
      _quitarImagen = false;
      _editando = false;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<bool> _confirmChanges(String name) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    color: _teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: _teal,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Confirmar cambios',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      color: _textDark,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            '¿Estás seguro de que deseas guardar los cambios del producto ',
                      ),
                      TextSpan(
                        text: '"$name"',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
                        style: _cancelStyle,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: _acceptStyle,
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

  Future<void> _guardar() async {
    if (_guardando || !_editando) return;
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
    final baseUnitSymbol = (unidad['symbol_unit'] ?? '').toString().trim();
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
      final clave = _claveTipo(item);
      final price = double.tryParse(
        (_priceControllers[clave]?.text ?? '').trim().replaceAll(',', '.'),
      );
      if (price == null || !price.isFinite || price < 0) {
        _showError('Ingresa un precio válido para "${item['name_type']}".');
        return;
      }
      final ups = double.tryParse(
        (_unitsControllers[clave]?.text ?? '').trim().replaceAll(',', '.'),
      );
      if (ups == null || !ups.isFinite || ups <= 0) {
        _showError(
          'Las unidades por venta de "${item['name_type']}" deben ser mayores a 0.',
        );
        return;
      }
      item['price'] = price;
      item['units_per_sale'] = ups;
    }
    if (!_saleTypes.any((item) => item['status'] == true)) {
      _showError('Activa al menos una forma de venta.');
      return;
    }
    if (_selectedBranchIds.isEmpty || _selectedBranchIds.any((id) => !_allBranches.any((b) => b['id'].toString() == id))) {
      _showError('Selecciona al menos una sucursal válida.');
      return;
    }
    if (_entryDate == null) {
      _showError('Selecciona la fecha de entrada.');
      return;
    }
    final stocksByBranch = <String, double>{};
    for (final id in _selectedBranchIds) {
      final value = double.tryParse((_stockControllersByBranch[id]?.text ?? '0').trim().replaceAll(',', '.'));
      if (value == null || !value.isFinite || value < 0) {
        final branchName = (_allBranches.where((b) => b['id'].toString() == id).isEmpty ? 'sucursal' : _allBranches.firstWhere((b) => b['id'].toString() == id)['branch_name'] ?? 'sucursal');
        _showError('Ingresa un stock válido para $branchName.');
        return;
      }
      stocksByBranch[id] = value;
    }
    final entrada = DateTime(
      _entryDate!.year,
      _entryDate!.month,
      _entryDate!.day,
    );
    if (_expiryDate != null && _expiryDate!.isBefore(entrada)) {
      _showError(
        'La fecha de caducidad no puede ser anterior a la fecha de entrada.',
      );
      return;
    }
    final confirmed = await _confirmChanges(name);
    if (!confirmed || !mounted) return;
    setState(() {
      _guardando = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      String imagenFinal = _quitarImagen ? '' : _imagenUrl;
      if (!_quitarImagen &&
          _nuevaImagen != null &&
          _nuevaImagenBytes != null) {
        imagenFinal = await _service.prepareImage(
          _nuevaImagen!,
          imageBytes: _nuevaImagenBytes,
        );
      }
      final primeraModalidad = _saleTypes.firstWhere(
        (item) => item['status'] == true,
      );
      final saleTypesGuardar = _saleTypes.map((item) {
        return <String, dynamic>{
          'id_type': item['id_type'],
          'name_type': item['name_type'],
          'price': item['price'],
          'allows_decimal': true,
          'status': item['status'] != false,
          'units_per_sale': item['units_per_sale'] ?? 1,
        };
      }).toList();
      final productRef = _db.collection('products').doc(widget.productId);
      final batch = _db.batch();
      batch.update(productRef, {
        'name_product': name,
        'barcode': barcode,
        'description_product': description,
        'id_categories': _selectedCategoryId,
        'base_unit': baseUnit,
        'base_unit_symbol': baseUnitSymbol,
        'prince': primeraModalidad['price'],
        'typeProduct': primeraModalidad['name_type'],
        'sale_types': saleTypesGuardar,
        'image_url': imagenFinal,
      });
      for (final entry in stocksByBranch.entries) {
        final existingId = _inventoryIdsByBranch[entry.key];
        final inventoryRef = existingId == null
            ? _db.collection('inventory').doc()
            : _db.collection('inventory').doc(existingId);
        final inventoryData = <String, dynamic>{
          'id_products': widget.productId,
          'id_branches': entry.key,
          'base_unit': baseUnit,
          'base_unit_symbol': baseUnitSymbol,
          'stock': entry.value,
          'entry_date': Timestamp.fromDate(entrada),
          'expiry_date': _expiryDate == null ? null : Timestamp.fromDate(DateTime(_expiryDate!.year, _expiryDate!.month, _expiryDate!.day)),
          'inventory_status': true,
        };
        if (existingId == null) {
          inventoryData['created_at'] = FieldValue.serverTimestamp();
          batch.set(inventoryRef, inventoryData);
        } else {
          inventoryData['id_inventory_units'] = FieldValue.delete();
          batch.update(inventoryRef, inventoryData);
        }
      }
      await batch.commit();
      if (!mounted) return;
      _imagenUrl = imagenFinal;
      _baseUnitStored = baseUnit;
      _baseUnitSymbolStored = baseUnitSymbol;
      await _cargarInventario();
      _prepararControlesTipos();
      _nuevaImagen = null;
      _nuevaImagenBytes = null;
      _quitarImagen = false;
      _guardarOriginales();
      setState(() {
        _editando = false;
        _guardando = false;
        _categoriaAbierta = false;
        _unidadAbierta = false;
        _sucursalAbierta = false;
        _tiposAbiertos = false;
      });
      _showSuccess('Producto actualizado correctamente.');
    } catch (e, stackTrace) {
      debugPrint('Error al guardar los cambios: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _guardando = false);
      _showError('No se pudieron guardar los cambios. Verifica Firebase.');
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_successMessage == message) {
        setState(() => _successMessage = null);
      }
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
    final color = error ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final bg = error ? const Color(0xFFFDECEA) : const Color(0xFFE8F5E9);
    final border = error ? const Color(0xFFF5B5AE) : const Color(0xFFA5D6A7);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle,
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

  Widget _imagenEncabezado() {
    return Column(
      children: [
        Container(
          width: 180,
          height: 140,
          decoration: BoxDecoration(
            color: _disabledFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderGrey),
          ),
          clipBehavior: Clip.antiAlias,
          child: _imagenGuardada(
            _imagenOriginal,
            BoxFit.contain,
            _iconoSinImagen(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Imagen del producto',
          style: TextStyle(
            color: _mutedGrey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _encabezado(bool esMovil) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _guardando ? null : _regresar,
            style: TextButton.styleFrom(
              foregroundColor: _teal,
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text(
              'Regresar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _imagenEncabezado(),
        const SizedBox(height: 16),
        const Text(
          'Detalles del producto',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _mutedGrey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _nombreOriginal.trim().isEmpty ? 'Producto' : _nombreOriginal.trim(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: esMovil ? 25 : 32,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
      ],
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
    final ancho = MediaQuery.of(context).size.width;
    final esMovil = ancho < 700;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: _teal),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: esMovil ? 20 : 40,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _messages(),
                        _encabezado(esMovil),
                        const SizedBox(height: 34),
                        if (esMovil)
                          _formularioCampos()
                        else
                          _formularioDesktop(),
                        const SizedBox(height: 30),
                        const Divider(
                          color: Color(0xFFEEEEEE),
                          height: 1,
                        ),
                        const SizedBox(height: 24),
                        if (!_editando)
                          Center(
                            child: SizedBox(
                              width: esMovil ? double.infinity : 420,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _editar,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 19,
                                ),
                                label: const Text('Editar producto'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textDark,
                                  backgroundColor: const Color(0xFFEAF7F9),
                                  side: const BorderSide(
                                    color: _teal,
                                    width: 1.6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_editando) ...[
                          if (_guardando)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(color: _green),
                                    SizedBox(height: 10),
                                    Text(
                                      'Guardando cambios, espera un momento...',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (esMovil)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 50,
                                  child: GuardarButton(
                                    onPressed: _guardar,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 50,
                                  child: CancelButton(
                                    onPressed: _cancelar,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 200,
                                  height: 50,
                                  child: CancelButton(
                                    onPressed: _cancelar,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 200,
                                  height: 50,
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
                ),
              ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({
    required this.color,
  });
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
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }
  @override
  bool shouldRepaint(
    covariant _DashedBorderPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}