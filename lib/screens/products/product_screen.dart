import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import '../../services/branch_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/new.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'package:intl/intl.dart';

const _red = Color(0xFFF4512A);
const _borderGrey = Color(0xFFE0E0E0);
const _accent = Color(0xFF63B7C4);
const _blueStat = Color(0xFF1565C0);
const _fieldBg = Color(0xFFF8F8F8);
const _green = Color(0xFF1B7A2F);
const _textDark = Color(0xFF171717);
const _muted = Color(0xFF666666);
const _hint = Color(0xFF9E9E9E);

class ProductScreen extends StatefulWidget {
  const ProductScreen({
    super.key,
    this.initialBranchId,
  });
  final String? initialBranchId;
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen>with SingleTickerProviderStateMixin {
  late final AnimationController _stockAlertController;
  static const int _pageSize = 5;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final InventoryService _inventoryService = InventoryService();
  final BranchService _branchService = BranchService();
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _branchKey = GlobalKey();
  final GlobalKey _saleTypeKey = GlobalKey();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _catSub;
  StreamSubscription<List<Map<String, dynamic>>>? _inventorySub;
  StreamSubscription<List<Map<String, dynamic>>>? _branchSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?  _catalogSettingsSub;
  List<Map<String, dynamic>> _inventoryRows = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _saleTypes = [];
  Set<String> _disabledCategories = {};
  Set<String> _disabledSaleTypes = {};
  String? _branchFilter;
  bool _showOnlySelectedBranchProducts = false;
  String _search = '';
  int _page = 0;
  String? _filter;
  String? _categoryFilter;
  String? _saleTypeFilter;

  Map<String, String> _categorias = {};
  Set<String> _branchCategoryIds = {};
  String get _role =>
    (Session.user?.roleUser ?? '').toString().trim().toLowerCase();
  bool get _isAdmin => _role == 'administrador';
  bool get _isSupervisor => _role == 'supervisor';
  bool get _isEmployee => _role == 'empleado';
  bool get _canManageCatalog => _isAdmin || _isSupervisor;

 Set<String> get _assignedBranchIds {
  final branches = Session.user?.idBranches ?? [];

  return branches
      .map((branch) => branch.id)
      .where((id) => id.isNotEmpty)
      .toSet();
}

  bool _canAccessBranch(String branchId) {
  if (_isAdmin) return true;
  return _assignedBranchIds.contains(branchId);
}

  @override
 void initState() {
  super.initState();
  if (widget.initialBranchId != null &&
    widget.initialBranchId!.isNotEmpty) {
    _branchFilter = widget.initialBranchId;
    _showOnlySelectedBranchProducts = true;
  }
  _stockAlertController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
   )..repeat(reverse: true);
    if (_isEmployee && _assignedBranchIds.isNotEmpty) {
      _branchFilter = _assignedBranchIds.first;
      _showOnlySelectedBranchProducts = true;
    }
    _inventorySub = _inventoryService.watchInventory().listen(
      (rows) {
        if (!mounted) return;
        setState(() {
          _inventoryRows = rows;
          _page = 0;
        });
      },
      onError: (e) => debugPrint('Error al cargar inventario: $e'),
    );
    _branchSub = _branchService.watchBranches().listen(
      (rows) {
        if (!mounted) return;
        setState(() {
          final activeBranches = rows
              .where((branch) => branch['branch_status'] == true)
              .toList();
         if (_isAdmin) {
          _branches = activeBranches;
        } else {
          _branches = activeBranches.where((branch) {
            return _assignedBranchIds.contains(_text(branch['id']));
          }).toList();
        }
          if (!_isEmployee &&
              _branchFilter != null &&
              !_branches.any(
                (branch) => _text(branch['id']) == _branchFilter,
              )) {
            _branchFilter = null;
          }
          _page = 0;
        });
        _watchCatalogSettings();
      },
      onError: (e) => debugPrint('Error al cargar sucursales: $e'),
    );

    _catSub = _db.collection('categories').snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _categorias = {
            for (final doc in snapshot.docs)
              doc.id: (doc.data()['name_category'] ?? '').toString(),
          };
          _page = 0;
        });
      },
      onError: (e) => debugPrint('Error al cargar categorías: $e'),
    );
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _inventorySub?.cancel();
    _branchSub?.cancel();
    _catalogSettingsSub?.cancel();
    _stockAlertController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _categoryName(Map<String, dynamic> data) {
    final id = _text(data['id_categories']);
    final name = _categorias[id];
    if (name == null || name.isEmpty) {
      return 'Sin categoría';
    }
    return name;
  }

  String? get _effectiveCategoryFilter {
    final filter = _categoryFilter;
    if (filter == null) return null;
    if (filter == '__none__' || _categorias.containsKey(filter)) {
      return filter;
    }
    return null;
  }

  String _productName(Map<String, dynamic> data) {
    final name = _text(data['name_product']);
    return name.isEmpty ? 'Producto sin nombre' : name;
  }

  bool _isActive(Map<String, dynamic> data) {
    return data['status_product'] == true;
  }

  double _priceValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_text(value).replaceAll(',', '')) ?? 0;
  }

  String _formatNumber(dynamic value) {
  final number = _priceValue(value);
  return NumberFormat('#,##0.00', 'en_US').format(number);
  }
  String _money(dynamic value) {
    return '\$${_formatNumber(value)}';
  }
  bool _matchesSearch(Map<String, dynamic> data) {
    if (_search.isEmpty) return true;
    return [
      _text(data['name_product']),
      _text(data['barcode']),
      _text(data['description_product']),
      _categoryName(data),
      _text(data['typeProduct']),
    ].any((value) => value.toLowerCase().contains(_search));
  }

  String _referenceId(dynamic value) {
    if (value is DocumentReference) return value.id;
    return value?.toString().trim() ?? '';
  }

  String _inventoryProductId(Map<String, dynamic> data) {
    for (final key in [
      'id_product',
      'product_id',
      'id_products',
      'products_id',
      'productId',
      'idProducts',
    ]) {
      final value = _referenceId(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _inventoryBranchId(Map<String, dynamic> data) {
    for (final key in [
      'id_branch',
      'branch_id',
      'id_branches',
      'branches_id',
      'branchId',
      'idBranches',
    ]) {
      final value = _referenceId(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _inventoryMatchesBranch(Map<String, dynamic> item) {
  final branchId = _inventoryBranchId(item);
  if (_isSupervisor || _isEmployee) {
    return _assignedBranchIds.contains(branchId) &&
        (_branchFilter == null || branchId == _branchFilter);
  }
  if (_branchFilter != null) {
    return branchId == _branchFilter && _canAccessBranch(branchId);
  }
  return true;
}

  bool _productBelongsToBranch(String productId) {
    if (_branchFilter == null && !_isSupervisor && !_isEmployee) {
      return true;
    }
    return _inventoryRows.any(
      (item) =>
          item['inventory_status'] == true &&
          _inventoryMatchesBranch(item) &&
          _inventoryProductId(item) == productId,
    );
  }

  int _stockForProduct(String productId) {
    var total = 0;

    for (final item in _inventoryRows) {
      if (item['inventory_status'] != true ||
          !_inventoryMatchesBranch(item)) {
        continue;
      }
      if (_inventoryProductId(item) != productId) continue;
      total += _priceValue(item['stock']).toInt();
    }
    return total;
  }
  int _outOfStockCount() {
    final productIds = _inventoryRows
        .where((item) =>
            item['inventory_status'] == true &&
            _inventoryMatchesBranch(item))
        .map(_inventoryProductId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return productIds
        .where((id) => _stockForProduct(id) <= 10)
        .length;
  }
  String _saleTypeId(Map<String, dynamic> data) {
    for (final key in [
      'id_type',
      'id_sale_type',
      'id',
      'name_type',
      'name',
    ]) {
      final value = _text(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _saleTypeName(Map<String, dynamic> data) {
    for (final key in [
      'name_type',
      'name_sale_type',
      'name',
      'type_name',
    ]) {
      final value = _text(data[key]);
      if (value.isNotEmpty) return value;
    }
    return _saleTypeId(data);
  }

  List<Map<String, dynamic>> _getProductSaleTypes(
    Map<String, dynamic> product,
  ) {
    final raw = product['sale_types'];
    final result = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final id = _saleTypeId(map);
          final name = _saleTypeName(map);
          if (id.isNotEmpty) {
            result.add({
              ...map,
              '_id': id,
              '_name': name,
            });
          }
        } else if (item != null) {
          final value = item.toString().trim();
          if (value.isNotEmpty) {
            result.add({
              '_id': value,
              '_name': value,
            });
          }
        }
      }
    } else if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          final id = _saleTypeId(map).isEmpty
              ? key.toString()
              : _saleTypeId(map);
          result.add({
            ...map,
            '_id': id,
            '_name': _saleTypeName(map).isEmpty
                ? key.toString()
                : _saleTypeName(map),
          });
        } else {
          final id = key.toString();
          result.add({
            '_id': id,
            '_name': value?.toString() ?? id,
          });
        }
      });
    }
    return result;
  }
  void _updateSaleTypes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
  ) {
    final unique = <String, Map<String, dynamic>>{};
    for (final product in products) {
      for (final type in _getProductSaleTypes(product.data())) {
        final id = _text(type['_id']);
        if (id.isNotEmpty) {
          unique[id] = type;
        }
      }
    }
    _saleTypes = unique.values.toList()
      ..sort(
        (a, b) => _text(a['_name'])
            .toLowerCase()
            .compareTo(_text(b['_name']).toLowerCase()),
      );
  }
  bool _productHasSaleType(
    Map<String, dynamic> product,
    String saleTypeId,
  ) {
    return _getProductSaleTypes(product).any(
      (type) => _text(type['_id']) == saleTypeId,
    );
  }
  bool _hasAvailableSaleType(Map<String, dynamic> product) {
    if (_branchFilter == null) return true;
    final types = _getProductSaleTypes(product);
    if (types.isEmpty) return true;
    return types.any(
      (type) => !_disabledSaleTypes.contains(_text(type['_id'])),
    );
  }

  void _watchCatalogSettings() {
    _catalogSettingsSub?.cancel();
    final branchId = _branchFilter;
    if (mounted) {
      setState(() {
        _disabledCategories = {};
        _disabledSaleTypes = {};
      });
    }
    if (branchId == null || branchId.isEmpty) return;
    _catalogSettingsSub = _db
        .collection('branches')
        .doc(branchId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted || _branchFilter != branchId) return;
        final data = snapshot.data() ?? {};
        final disabledCategories = Set<String>.from(
          (data['disabled_categories'] as List?) ?? const [],
        );
        final disabledSaleTypes = Set<String>.from(
          (data['disabled_sale_types'] as List?) ?? const [],
        );
        setState(() {
          _disabledCategories = disabledCategories;
          _disabledSaleTypes = disabledSaleTypes;
          if (_categoryFilter != null &&
              _disabledCategories.contains(_categoryFilter)) {
            _categoryFilter = null;
          }
          if (_saleTypeFilter != null &&
              _disabledSaleTypes.contains(_saleTypeFilter)) {
            _saleTypeFilter = null;
          }
          _page = 0;
        });
      },
      onError: (e) {
        debugPrint('Error al cargar configuración de sucursal: $e');
      },
    );
  }

  Future<void> _toggleCatalogItem({
    required String field,
    required String id,
    required bool active,
  }) async {
    final branchId = _branchFilter;
    if (!_canManageCatalog ||
        branchId == null ||
        branchId.isEmpty ||
        !_canAccessBranch(branchId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona una sucursal para cambiar las activaciones.',
          ),
        ),
      );
      return;
    }

    try {
      final reference = _db.collection('branches').doc(branchId);
      await reference.set(
        {
          field: active
              ? FieldValue.arrayRemove([id])
              : FieldValue.arrayUnion([id]),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error al actualizar catálogo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la activación.'),
        ),
      );
    }
  }

  Future<void> _openBranchMenu() async {
    if (_isEmployee) return;
    final box =
        _branchKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + box.size.height + 6,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _accent, width: 1.2),
      ),
      constraints: BoxConstraints(
        minWidth: box.size.width,
        maxWidth: 300,
      ),
      items: [
        PopupMenuItem<String>(
          value: '',
          height: 44,
          child: Row(
            children: [
              const Expanded(
                child: Text('Todas las sucursales'),
              ),
              if (_branchFilter == null)
                const Icon(Icons.check_rounded, color: _accent),
            ],
          ),
        ),
        ..._branches.map((branch) {
          final id = _text(branch['id']);
          final name = _text(branch['branch_name']).isEmpty
              ? 'Sucursal sin nombre'
              : _text(branch['branch_name']);
          return PopupMenuItem<String>(
            value: id,
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                  maxLines: MediaQuery.sizeOf(context).width < 600 ? 2 : 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_branchFilter == id)
                  const Icon(Icons.check_rounded, color: _accent),
              ],
            ),
          );
        }),
      ],
    );
    if (selected == null || !mounted || _isEmployee) return;
    final selectedBranch = selected.isEmpty ? null : selected;
    if (selectedBranch != null && !_canAccessBranch(selectedBranch)) {
      return;
    }
    setState(() {
      _branchFilter = selectedBranch;
      _showOnlySelectedBranchProducts = selectedBranch != null;
      _categoryFilter = null;
      _saleTypeFilter = null;
      _disabledCategories = {};
      _disabledSaleTypes = {};
      _page = 0;
    });
    _watchCatalogSettings();
  }

  Widget _branchFilterField() {
    Map<String, dynamic>? selected;
    for (final branch in _branches) {
      if (_text(branch['id']) == _branchFilter) {
        selected = branch;
        break;
      }
    }
    final name = selected == null
        ? 'Todas las sucursales'
        : _text(selected['branch_name']);
    return _filterButton(
      key: _branchKey,
      label: name.isEmpty ? 'Sucursal' : name,
      onTap: _openBranchMenu,
    );
  }

  Widget _filterButton({
    Key? key,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: key,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _accent,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(String id) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: size.width > 948 ? 900 : size.width - 32,
            height: size.height * 0.88,
            child: ProductDetailScreen(productId: id),
          ),
        );
      },
    );
  }

  void _openForm() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: size.width > 948 ? 900 : size.width - 32,
            height: size.height * 0.88,
            child: const ProductFormScreen(),
          ),
        );
      },
    );
  }

  Future<void> _setStatus(String id, bool value) async {
    if (!_canManageCatalog || id.isEmpty) return;
    try {
      await _db.collection('products').doc(id).update({
        'status_product': value,
      });
    } catch (e) {
      debugPrint('Error al cambiar estado del producto: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cambiar el estado del producto.'),
        ),
      );
    }
  }

  Widget _titulo(bool compact) {
    return Column(
      children: [
        Text(
          'Productos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 26 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Consulta y administra los productos de tu negocio.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF555555),
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() {
            _search = value.trim().toLowerCase();
            _page = 0;
          });
        },
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black,
        ),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, código o categoría...',
          hintStyle: const TextStyle(
            color: _hint,
            fontSize: 14,
          ),
          filled: true,
          fillColor: _fieldBg,
          prefixIcon: const Icon(Icons.search, color: _accent),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _accent,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _search = '';
                      _page = 0;
                    });
                  },
                ),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: _borderGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _nuevoButton() {
    return SizedBox(
      height: 48,
      child: NuevoButton(onPressed: _openForm),
    );
  }

  Widget _pillSwitch({
    required bool active,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? _green : _red,
          borderRadius: BorderRadius.circular(30),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment:
              active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _circuloSeleccion(bool selected) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _accent : Colors.white,
        border: selected
            ? null
            : Border.all(
                color: const Color(0xFFBDBDBD),
                width: 2.5,
              ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 16,
              color: Colors.white,
            )
          : null,
    );
  }
  Widget _catalogActivationControl({
    required bool active,
    required ValueChanged<bool> onChanged,
  }) {
    final color = active ? _green : _red;
    return SizedBox(
      width: 132,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            active ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 61,
            child: Text(
              active ? 'Activado' : 'Desactivado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _textDark,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!active),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              width: 42,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: active ? _green : _red,
                borderRadius: BorderRadius.circular(24),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment:
                    active ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryMenu(
    Map<String, int> counts,
  ) async {
    final box =
        _categoryKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + box.size.height + 6,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final entries = _categorias.entries.where((entry) {
      if (_isEmployee) {
        return _branchCategoryIds.contains(entry.key) &&
            !_disabledCategories.contains(entry.key);
      }
      return true;
    }).toList()
      ..sort(
        (a, b) => a.value.toLowerCase().compareTo(
              b.value.toLowerCase(),
            ),
      );
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _accent, width: 1.2),
      ),
      constraints: BoxConstraints(
        minWidth: box.size.width,
        maxWidth: 420,
        maxHeight: 420,
      ),
      items: [
        PopupMenuItem<String>(
          value: '',
          height: 44,
          child: Row(
            children: [
              const Expanded(child: Text('Todas las categorías')),
              if (_effectiveCategoryFilter == null)
                const Icon(Icons.check_rounded, color: _accent),
            ],
          ),
        ),
        ...entries.map((entry) {
          final id = entry.key;
          final name = entry.value.isEmpty ? 'Sin nombre' : entry.value;
          final active = !_disabledCategories.contains(id);
          final selectedCategory = _effectiveCategoryFilter == id;
          var itemActive = active;
          return PopupMenuItem<String>(
            enabled: false,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: StatefulBuilder(
              builder: (itemContext, setItemState) {
                return Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: !itemActive
                            ? null
                            : () => Navigator.of(itemContext).pop(id),
                        child: Row(
                          children: [
                            _circuloSeleccion(selectedCategory),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: itemActive ? _textDark : Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_branchFilter != null) ...[
                      const SizedBox(width: 6),
                     _canManageCatalog
                    ? _catalogActivationControl(
                        active: itemActive,
                        onChanged: (newValue) {
                          setItemState(() => itemActive = newValue);
                          _toggleCatalogItem(
                            field: 'disabled_categories',
                            id: id,
                            active: newValue,
                          );
                        },
                      )
                    : const SizedBox(width: 132),
                    ],
                  ],
                );
              },
            ),
          );
        }),
        PopupMenuItem<String>(
          value: '__none__',
          height: 44,
          child: Row(
            children: [
              const Expanded(child: Text('Sin categoría')),
              if (_effectiveCategoryFilter == '__none__')
                const Icon(Icons.check_rounded, color: _accent),
            ],
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _categoryFilter = selected.isEmpty ? null : selected;
      _page = 0;
    });
  }

  Widget _categoryFilterField(Map<String, int> counts) {
    final current = _effectiveCategoryFilter ?? '';
    String label;
    if (current.isEmpty) {
      label = 'Todas las categorías';
    } else if (current == '__none__') {
      label = 'Sin categoría';
    } else {
      label = _categorias[current] ?? 'Categoría';
    }
    return _filterButton(
      key: _categoryKey,
      label: label,
      onTap: () => _openCategoryMenu(counts),
    );
  }

  Future<void> _openSaleTypeMenu() async {
    final box =
        _saleTypeKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + box.size.height + 6,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _accent, width: 1.2),
      ),
      constraints: BoxConstraints(
        minWidth: box.size.width,
        maxWidth: 420,
        maxHeight: 420,
      ),
      items: [
        PopupMenuItem<String>(
          value: '',
          height: 44,
          child: Row(
            children: [
              const Expanded(child: Text('Todas las formas de venta')),
              if (_saleTypeFilter == null)
                const Icon(Icons.check_rounded, color: _accent),
            ],
          ),
        ),
        if (_saleTypes.isEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            height: 48,
            child: Center(
              child: Text(
                'No se encontraron formas de venta.',
                style: TextStyle(color: _muted),
              ),
            ),
          ),
        ..._saleTypes
            .where((type) {
              final id = _text(type['_id']);
              return !_isEmployee || !_disabledSaleTypes.contains(id);
            })
            .map((type) {
          final id = _text(type['_id']);
          final name = _text(type['_name']);
          final active = !_disabledSaleTypes.contains(id);
          final selectedType = _saleTypeFilter == id;
          var itemActive = active;
          return PopupMenuItem<String>(
            enabled: false,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: StatefulBuilder(
              builder: (itemContext, setItemState) {
                return Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: !itemActive
                            ? null
                            : () => Navigator.of(itemContext).pop(id),
                        child: Row(
                          children: [
                           _circuloSeleccion(selectedType),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                name.isEmpty ? id : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: itemActive ? _textDark : Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_branchFilter != null) ...[
                      const SizedBox(width: 6),
                      _canManageCatalog
                      ? _catalogActivationControl(
                          active: itemActive,
                          onChanged: (newValue) {
                            setItemState(() => itemActive = newValue);
                            _toggleCatalogItem(
                              field: 'disabled_sale_types',
                              id: id,
                              active: newValue,
                            );
                          },
                        )
                      : const SizedBox(width: 132),
                    ],
                  ],
                );
              },
            ),
          );
        }),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _saleTypeFilter = selected.isEmpty ? null : selected;
      _page = 0;
    });
  }

  Widget _saleTypeFilterField() {
    var label = 'Formas de venta';
    if (_saleTypeFilter != null) {
      final selected = _saleTypes.where(
        (type) => _text(type['_id']) == _saleTypeFilter,
      );
      if (selected.isNotEmpty) {
        label = _text(selected.first['_name']);
      }
    }
    return _filterButton(
      key: _saleTypeKey,
      label: label,
      onTap: _openSaleTypeMenu,
    );
  }


Widget _barraBusquedaYRegistro(
  Map<String, int> counts,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final mobile = constraints.maxWidth < 600;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchField(),
          const SizedBox(height: 10),
          if (mobile) ...[
            if (!_isEmployee) ...[
              Row(
                children: [
                  Expanded(child: _branchFilterField()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _categoryFilterField(counts),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              _categoryFilterField(counts),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(child: _saleTypeFilterField()),
                const SizedBox(width: 8),
                Expanded(child: _nuevoButton()),
              ],
            ),
          ] else ...[
            Row(
              children: [
                if (!_isEmployee) ...[
                  Expanded(child: _branchFilterField()),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _categoryFilterField(counts),
                ),
                const SizedBox(width: 8),
                Expanded(child: _saleTypeFilterField()),
                const SizedBox(width: 8),
                Expanded(child: _nuevoButton()),
              ],
            ),
          ],
        ],
      );
    },
  );
}


  
Widget _summaryCard({
  required String filtro,
  required Color color,
  required String label,
  required int value,
  required String note,
}) {
  final selected = _filter == filtro;
  final alert = filtro == 'agotados' && value > 0;

  return AnimatedBuilder(
    animation: _stockAlertController,
    builder: (context, _) {
      final pulse = alert ? _stockAlertController.value : 0.0;

      return InkWell(
        borderRadius: BorderRadius.circular(14),
       onTap: () {
          final clearedBranch =
              _showOnlySelectedBranchProducts && !_isEmployee;
          setState(() {
            _filter = selected ? null : filtro;
            if (clearedBranch) {
              _showOnlySelectedBranchProducts = false;
              _branchFilter = null;
              _categoryFilter = null;
              _saleTypeFilter = null;
              _disabledCategories = {};
              _disabledSaleTypes = {};
            }
            _page = 0;
          });
          if (clearedBranch) {
            _watchCatalogSettings();
          }
        },
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            color: alert
                ? Color.lerp(
                    Colors.white,
                    const Color(0xFFFFE0B2),
                    pulse * 0.55,
                  )!
                : Colors.white,
            boxShadow: alert
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6D00)
                          .withValues(alpha: 0.12 + pulse * 0.34),
                      blurRadius: 5 + pulse * 16,
                      spreadRadius: pulse * 2,
                    ),
                  ]
                : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: alert
                  ? const Color(0xFFE65100)
                  : (selected ? color : _borderGrey),
              width: alert ? 1.5 + pulse : (selected ? 1.6 : 1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Row(
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        Text(
                          NumberFormat('#,##0', 'en_US').format(value),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        Text(
                          alert
                              ? '⚠ ¡Revisar! 10 piezas o menos'
                              : note,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}


  Widget _summaryCards(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
    int agotados,
  ) {
    final active = all.where((doc) => _isActive(doc.data())).length;
    final total = all.length;
    final cards = [
      _summaryCard(
        filtro: 'activas',
        color: _green,
        label: 'Productos activos',
        value: active,
        note: 'de $total productos',
      ),
      _summaryCard(
        filtro: 'inactivas',
        color: _red,
        label: 'Productos inactivos',
        value: total - active,
        note: 'de $total productos',
      ),
      _summaryCard(
        filtro: 'todas',
        color: _blueStat,
        label: 'Total de productos',
        value: total,
        note: 'registrados',
      ),
      _summaryCard(
        filtro: 'agotados',
        color: const Color(0xFFE65100),
        label: 'Productos agotados',
        value: agotados,
        note: '10 piezas o menos',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        if (constraints.maxWidth >= 420) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 8),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Icon(
              Icons.add_photo_alternate_outlined,
              color: _accent ,
              size: 35,
            ),
    );
  }

  Widget _productImage(String imageUrl) {
    final value = imageUrl.trim();
    if (value.isEmpty) return _imagePlaceholder();
    if (value.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(value.split(',').last),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _imagePlaceholder(),
        );
      } catch (_) {
        return _imagePlaceholder();
      }
    }
    return Image.network(
      value,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _imagePlaceholder(),
    );
  }

  Widget _productImageBox(String imageUrl) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: _productImage(imageUrl),
    );
  }

  Widget _lineaInfo(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Color(0xFF444444)),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _dato(
    String label,
    String value, {
    double? width,
  }) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
      ],
    );
    return width == null
        ? content
        : SizedBox(width: width, child: content);
  }

  Widget _statusControl(String id, bool active) {
    final color = active ? _green : _red;
    return SizedBox(
      width: 174,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            active ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 76,
            child: Text(
              active ? 'Activado' : 'Desactivado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _textDark,
              ),
            ),
          ),
          const SizedBox(width: 5),
          _pillSwitch(
            active: active,
            onChanged: (value) => _setStatus(id, value),
          ),
        ],
      ),
    );
  }

  
Widget _stockDato(String productId) {
  return _dato(
    'Existencias',
    NumberFormat('#,##0.00', 'en_US')
        .format(_stockForProduct(productId)),
  );
}

Widget _productCard(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  int numero,
  bool mobile,
) {
  final data = doc.data();
  final id = doc.id;
  final name = _productName(data);
  final barcode = _text(data['barcode']);
  final description = _text(data['description_product']);
  final type = _text(data['typeProduct']);
  final category = _categoryName(data);
  final imageUrl = _text(data['image_url']);
  final active = _isActive(data);
  final price = _money(data['prince']);
  final tipo = type.isEmpty ? '—' : _capitalize(type);
  final info = Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textDark,
        ),
      ),
      const SizedBox(height: 5),
      _lineaInfo(
        'Código',
        barcode.isEmpty ? '—' : barcode,
      ),
      const SizedBox(height: 4),
      _lineaInfo(
        'Descripción',
        description.isEmpty ? '—' : description,
      ),
    ],
  );
  return _PressableProductCard(
    onTap: () => _openDetail(id),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1040;
          final isMobile =
              MediaQuery.sizeOf(context).width < 600;
          if (wide) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    54, 12, 12, 12,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      _productImageBox(imageUrl),
                      const SizedBox(width: 20),
                      Expanded(child: info),
                      const SizedBox(width: 16),
                      _dato(
                        'Categoría',
                        category,
                        width: 120,
                      ),
                      const SizedBox(width: 12),
                      _dato(
                        'Precio',
                        price,
                        width: 80,
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 70,
                        child: _stockDato(id),
                      ),
                      const SizedBox(width: 12),
                      _dato(
                        'Tipo',
                        tipo,
                        width: 80,
                      ),
                      const SizedBox(width: 16),
                      _canManageCatalog
                          ? _statusControl(id, active)
                          : const SizedBox(width: 174),
                      const SizedBox(width: 12),
                      const Text(
                        'Ver detalles',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _accent,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 26,
                  top: 24,
                  bottom: 24,
                  width: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: active ? _accent : _red,
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            );
          }
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  30, 12, 12, 12,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        _productImageBox(imageUrl),
                        const SizedBox(width: 12),
                        Expanded(child: info),
                        if (isMobile) ...[
                          InkWell(
                            onTap: () => _openDetail(id),
                            borderRadius:
                                BorderRadius.circular(6),
                            child: const Padding(
                              padding:
                                  EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Text(
                                'Ver detalles',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _accent,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _dato(
                            'Categoría',
                            category,
                          ),
                        ),
                        Expanded(
                          child: _dato(
                            'Precio',
                            price,
                          ),
                        ),
                        Expanded(
                          child: _stockDato(id),
                        ),
                        Expanded(
                          child: _dato(
                            'Tipo',
                            tipo,
                          ),
                        ),
                      ],
                    ),
                    if (_canManageCatalog) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _statusControl(
                          id,
                          active,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                bottom: 12,
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: active ? _accent : _red,
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
  Widget _pageButton(
    String label, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final isArrow = label == '‹' || label == '›';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? _accent
                : isArrow
                    ? _borderGrey
                    : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isArrow
            ? Icon(
                label == '‹'
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 23,
                color: onTap == null
                    ? Colors.black26
                    : Colors.black,
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: Colors.black,
                ),
              ),
      ),
    );
  }

  Widget _pagination(
    int total,
    int totalPages,
    int start,
    int end,
  ) {
    final canPrev = _page > 0;
    final canNext = _page < totalPages - 1;
    const visible = 5;
    final maxStart =
        totalPages > visible ? totalPages - visible : 0;
    final first = (_page - 2).clamp(0, maxStart).toInt();
    final last = (first + visible) < totalPages
        ? first + visible
        : totalPages;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Text(
          total == 0
              ? 'Mostrando 0 productos'
              : 'Mostrando ${start + 1} - $end de $total productos',
          style: const TextStyle(
            color: Color(0xFF8A8A8A),
            fontSize: 13,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pageButton(
              '‹',
              onTap: canPrev ? () => setState(() => _page--) : null,
            ),
            for (int i = first; i < last; i++) ...[
              const SizedBox(width: 5),
              _pageButton(
                '${i + 1}',
                selected: i == _page,
                onTap: () => setState(() => _page = i),
              ),
            ],
            const SizedBox(width: 5),
            _pageButton(
              '›',
              onTap: canNext ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyProducts() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
           Icon(
            Icons.add_photo_alternate_outlined,
            color: _accent ,
            size: 35,
          ),
            SizedBox(height: 12),
            Text(
              'No se encontraron productos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Prueba con otra búsqueda o cambia el filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(currentRoute: '/productos'),
      drawer: AppDrawer(currentRoute: '/productos'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar los productos.\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _red),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }
                final all = snapshot.data!.docs;
                final productsForBranch = all.where(
                  (doc) => _productBelongsToBranch(doc.id),
                ).toList();
                _branchCategoryIds = productsForBranch
                    .map((doc) => _text(doc.data()['id_categories']))
                    .where((id) => id.isNotEmpty)
                    .toSet();
                _updateSaleTypes(productsForBranch);
                final catFilter = _effectiveCategoryFilter;
                final counts = <String, int>{'': all.length};
                var sinCategoria = 0;
                for (final doc in all) {
                  final idCat = _text(doc.data()['id_categories']);
                  if (_categorias.containsKey(idCat)) {
                    counts[idCat] = (counts[idCat] ?? 0) + 1;
                  } else {
                    sinCategoria++;
                  }
                }
                counts['__none__'] = sinCategoria;
                final products = all.where((doc) {
                  if (_showOnlySelectedBranchProducts &&
                  !_productBelongsToBranch(doc.id)) {
                  return false;
                  }
                  final data = doc.data();
                  if (!_matchesSearch(data)) return false;
                  if (!_productBelongsToBranch(doc.id)) {
                    return false;
                  }
                  if (_filter == 'agotados') {
                  final hasInventory = _inventoryRows.any((item) =>
                      item['inventory_status'] == true &&
                      _inventoryMatchesBranch(item) &&
                      _inventoryProductId(item) == doc.id);

                  if (!hasInventory || _stockForProduct(doc.id) > 10) {
                    return false;
                    }
                  }
                  if (_filter == 'activas' && !_isActive(data)) {
                    return false;
                  }
                  if (_filter == 'inactivas' && _isActive(data)) {
                    return false;
                  }
                  final idCat = _text(data['id_categories']);
                  if (_branchFilter != null &&
                      idCat.isNotEmpty &&
                      _disabledCategories.contains(idCat)) {
                    return false;
                  }
                  if (!_hasAvailableSaleType(data)) {
                    return false;
                  }
                  if (_saleTypeFilter != null) {
                    if (!_productHasSaleType(
                      data,
                      _saleTypeFilter!,
                    )) {
                      return false;
                    }
                    if (_branchFilter != null &&
                        _disabledSaleTypes.contains(_saleTypeFilter)) {
                      return false;
                    }
                  }
                  if (catFilter != null) {
                    if (catFilter == '__none__') {
                      if (_categorias.containsKey(idCat)) {
                        return false;
                      }
                    } else if (idCat != catFilter) {
                      return false;
                    }
                  }
                  return true;
                }).toList()
                  ..sort(
                    (a, b) => _productName(a.data())
                        .toLowerCase()
                        .compareTo(
                          _productName(b.data()).toLowerCase(),
                        ),
                  );
                final total = products.length;
                final totalPages =
                    total == 0 ? 1 : (total / _pageSize).ceil();
                if (_page >= totalPages) {
                  _page = totalPages - 1;
                }
                final start = _page * _pageSize;
                final end = start + _pageSize > total
                    ? total
                    : start + _pageSize;
                final pageProducts = products.sublist(start, end);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          isMobile ? 12 : 24,
                          20,
                          isMobile ? 12 : 24,
                          12,
                        ),
                        children: [
                          _titulo(isMobile),
                          const SizedBox(height: 22),
                          _barraBusquedaYRegistro(counts),
                          const SizedBox(height: 18),
                          _summaryCards(
                            all.where(
                              (doc) => _productBelongsToBranch(doc.id),
                            ).toList(),
                            _outOfStockCount(),
                          ),
                          const SizedBox(height: 18),
                          if (pageProducts.isEmpty)
                            _emptyProducts()
                          else
                            ...pageProducts.asMap().entries.map((entry) {
                              return _productCard(
                                entry.value,
                                start + entry.key + 1,
                                isMobile,
                              );
                            }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 12 : 24,
                        8,
                        isMobile ? 12 : 24,
                        14,
                      ),
                      child: _pagination(
                        total,
                        totalPages,
                        start,
                        end,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableProductCard extends StatefulWidget {
  const _PressableProductCard({
    required this.onTap,
    required this.child,
  });
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_PressableProductCard> createState() =>
      _PressableProductCardState();
}
class _PressableProductCardState
    extends State<_PressableProductCard> {
  bool _pressed = false;
  void _set(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed ? _accent : _borderGrey,
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}