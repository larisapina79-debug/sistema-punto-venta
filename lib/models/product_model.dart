
import 'package:cloud_firestore/cloud_firestore.dart';
class ProductModel {
  final String idProduct;
  final String nameProduct;
  final String barcode;
  final String descriptionProduct;
  final String idCategories;
  final String imageUrl;
  final double prince;
  final String typeProduct;
  final bool statusProduct;
  final String baseUnit;
  final String baseUnitSymbol;
  final List<SaleTypeModel> saleTypes;
  final DateTime? createdAt;
  ProductModel({
    required this.idProduct,
    required this.nameProduct,
    required this.barcode,
    required this.descriptionProduct,
    required this.idCategories,
    this.imageUrl = '',
    required this.prince,
    required this.typeProduct,
    this.statusProduct = true,
    this.baseUnit = '',
    this.baseUnitSymbol = '',
    this.saleTypes = const [],
    this.createdAt,
  });
  factory ProductModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    final modalidades = map['sale_types'];
    return ProductModel(
      idProduct: id.isNotEmpty
          ? id
          : (map['id'] ?? '').toString(),
      nameProduct: (map['name_product'] ?? '').toString(),
      barcode: (map['barcode'] ?? '').toString(),
      descriptionProduct:
          (map['description_product'] ?? '').toString(),
      idCategories: (map['id_categories'] ?? '').toString(),
      imageUrl: (map['image_url'] ?? '').toString(),
      prince: _toDouble(map['prince']),
      typeProduct: (map['typeProduct'] ?? '').toString(),
      statusProduct: map['status_product'] != false,
      baseUnit: (map['base_unit'] ?? '').toString(),
      baseUnitSymbol:
          (map['base_unit_symbol'] ?? '').toString(),
      saleTypes: modalidades is List
          ? modalidades
              .whereType<Map>()
              .map(
                (item) => SaleTypeModel.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : [],
      createdAt: _toDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name_product': nameProduct,
      'barcode': barcode,
      'description_product': descriptionProduct,
      'id_categories': idCategories,
      'image_url': imageUrl,
      'prince': prince,
      'typeProduct': typeProduct,
      'status_product': statusProduct,
      'base_unit': baseUnit,
      'base_unit_symbol': baseUnitSymbol,
      'sale_types': saleTypes.map((tipo) => tipo.toMap()).toList(),
      if (createdAt != null)
        'created_at': Timestamp.fromDate(createdAt!),
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
}

class SaleTypeModel {
  final String idType;
  final String nameType;
  final double price;
  final bool allowsDecimal;
  final double unitsPerSale;
  final bool status;
  SaleTypeModel({
    required this.idType,
    required this.nameType,
    required this.price,
    this.allowsDecimal = false,
    this.unitsPerSale = 1,
    this.status = true,
  });

  factory SaleTypeModel.fromMap(Map<String, dynamic> map) {
    return SaleTypeModel(
      idType: (map['id_type'] ?? '').toString(),
      nameType: (map['name_type'] ?? '').toString(),
      price: _toDouble(map['price']),
      allowsDecimal: map['allows_decimal'] == true,
      unitsPerSale: _toDouble(
        map['units_per_sale'],
        fallback: 1,
      ),
      status: map['status'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_type': idType,
      'name_type': nameType,
      'price': price,
      'allows_decimal': allowsDecimal,
      'units_per_sale': unitsPerSale,
      'status': status,
    };
  }
  static double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '',
        ) ??
        fallback;
  }
}
