
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryModel {
  final String idInventory;
  final String idProducts;
  final String idBranches;
  final double stock;
  final DateTime? entryDate;
  final DateTime? expiryDate;
  final bool inventoryStatus;
  final String baseUnit;
  final String baseUnitSymbol;
  InventoryModel({
    required this.idInventory,
    required this.idProducts,
    required this.idBranches,
    required this.stock,
    this.entryDate,
    this.expiryDate,
    this.inventoryStatus = true,
    this.baseUnit = '',
    this.baseUnitSymbol = '',
  });
  factory InventoryModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return InventoryModel(
      idInventory: id.isNotEmpty
          ? id
          : (map['id'] ?? '').toString(),
      idProducts: (map['id_products'] ?? '').toString(),
      idBranches: (map['id_branches'] ?? '').toString(),
      stock: _toDouble(map['stock']),
      entryDate: _toDateTime(map['entry_date']),
      expiryDate: _toDateTime(map['expiry_date']),
      inventoryStatus: map['inventory_status'] != false,
      baseUnit: (map['base_unit'] ?? '').toString(),
      baseUnitSymbol:
          (map['base_unit_symbol'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_products': idProducts,
      'id_branches': idBranches,
      'stock': stock,
      'entry_date': entryDate != null
          ? Timestamp.fromDate(entryDate!)
          : null,
      'expiry_date': expiryDate != null
          ? Timestamp.fromDate(expiryDate!)
          : null,
      'inventory_status': inventoryStatus,
      'base_unit': baseUnit,
      'base_unit_symbol': baseUnitSymbol,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '',
        ) ??
        0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
  InventoryModel copyWith({
    String? idInventory,
    String? idProducts,
    String? idBranches,
    double? stock,
    DateTime? entryDate,
    DateTime? expiryDate,
    bool? inventoryStatus,
    String? baseUnit,
    String? baseUnitSymbol,
  }) {
    return InventoryModel(
      idInventory: idInventory ?? this.idInventory,
      idProducts: idProducts ?? this.idProducts,
      idBranches: idBranches ?? this.idBranches,
      stock: stock ?? this.stock,
      entryDate: entryDate ?? this.entryDate,
      expiryDate: expiryDate ?? this.expiryDate,
      inventoryStatus: inventoryStatus ?? this.inventoryStatus,
      baseUnit: baseUnit ?? this.baseUnit,
      baseUnitSymbol: baseUnitSymbol ?? this.baseUnitSymbol,
    );
  }
}
