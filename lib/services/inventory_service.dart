import 'package:cloud_firestore/cloud_firestore.dart';
class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _inventory =>
      _db.collection('inventory');

  Future<List<Map<String, dynamic>>> getInventory() async {
    final snapshot = await _inventory.get();
    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchInventory() {
    return _inventory.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getActiveInventory() async {
    final snapshot = await _inventory
        .where('inventory_status', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchActiveInventory() {
    return _inventory
        .where('inventory_status', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    });
  }

  Future<int> countOutOfStock() async {
    final inventory = await getActiveInventory();
    return inventory.where((item) {
      return toDouble(item['stock']) <= 0;
    }).length;
  }
  Stream<int> watchOutOfStockCount() {
    return watchActiveInventory().map((inventory) {
      return inventory.where((item) {
        return toDouble(item['stock']) <= 0;
      }).length;
    });
  }

  Future<Map<String, dynamic>?> getInventoryById(String id) async {
    final doc = await _inventory.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return {'id': doc.id, ...doc.data()!};
  }

  Future<Map<String, dynamic>?> getInventoryByProductAndBranch({
    required String productId,
    required String branchId,
  }) async {
    final snapshot = await _inventory
        .where('id_products', isEqualTo: productId)
        .where('id_branches', isEqualTo: branchId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final doc = snapshot.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  Future<String> createInventory({
    required String productId,
    required String branchId,
    required num stock,
    required String unitName,
    required String unitSymbol,
    DateTime? entryDate,
    DateTime? expiryDate,
    bool inventoryStatus = true,
  }) async {
    _validateStock(stock);
    if (unitName.trim().isEmpty || unitSymbol.trim().isEmpty) {
      throw ArgumentError('Debes seleccionar una unidad de inventario.');
    }
    final existing = await getInventoryByProductAndBranch(
      productId: productId,
      branchId: branchId,
    );
    if (existing != null) {
      throw Exception(
        'Este producto ya tiene un registro de inventario en esta sucursal.',
      );
    }

    final data = <String, dynamic>{
      'id_products': productId,
      'id_branches': branchId,
      'stock': _cleanNumber(stock.toDouble()),
      'name_unit': unitName.trim(),
      'symbol_unit': unitSymbol.trim(),
      'inventory_status': inventoryStatus,
      'entry_date':
          entryDate == null ? null : Timestamp.fromDate(entryDate),
      'expiry_date':
          expiryDate == null ? null : Timestamp.fromDate(expiryDate),
      'created_at': FieldValue.serverTimestamp(),
    };
    final doc = await _inventory.add(data);
    return doc.id;
  }

  Future<void> updateInventory({
    required String inventoryId,
    required num stock,
    String? unitName,
    String? unitSymbol,
    DateTime? entryDate,
    DateTime? expiryDate,
    bool? inventoryStatus,
  }) async {
    _validateStock(stock);
    final data = <String, dynamic>{
      'stock': _cleanNumber(stock.toDouble()),
    };
    if (unitName != null && unitName.trim().isNotEmpty) {
      data['name_unit'] = unitName.trim();
    }
    if (unitSymbol != null && unitSymbol.trim().isNotEmpty) {
      data['symbol_unit'] = unitSymbol.trim();
    }
    if (entryDate != null) {
      data['entry_date'] = Timestamp.fromDate(entryDate);
    }
    if (expiryDate != null) {
      data['expiry_date'] = Timestamp.fromDate(expiryDate);
    }
    if (inventoryStatus != null) {
      data['inventory_status'] = inventoryStatus;
    }
    await _inventory.doc(inventoryId).update(data);
  }

  Future<void> decreaseStock({
    required String inventoryId,
    required num quantity,
  }) async {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError(
        'La cantidad a descontar debe ser mayor que cero.',
      );
    }
    final reference = _inventory.doc(inventoryId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('No se encontró el registro de inventario.');
      }
      final data = snapshot.data()!;
      final currentStock = toDouble(data['stock']);
      if (currentStock < quantity) {
        throw Exception('No hay existencias suficientes.');
      }
      final newStock = _cleanNumber(currentStock - quantity);
      transaction.update(reference, {'stock': newStock});
    });
  }

  Future<void> increaseStock({
    required String inventoryId,
    required num quantity,
  }) async {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError(
        'La cantidad a ingresar debe ser mayor que cero.',
      );
    }
    final reference = _inventory.doc(inventoryId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('No se encontró el registro de inventario.');
      }
      final data = snapshot.data()!;
      final currentStock = toDouble(data['stock']);
      transaction.update(reference, {
        'stock': _cleanNumber(currentStock + quantity),
      });
    });
  }
  double toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }
  void _validateStock(num stock) {
    if (!stock.isFinite || stock < 0) {
      throw ArgumentError(
        'Las existencias deben ser un número válido y no negativo.',
      );
    }
  }
  double _cleanNumber(double value) {
    return double.parse(value.toStringAsFixed(6));
  }
}
