import 'package:cloud_firestore/cloud_firestore.dart';

class SaleProductModel {
  final String idProduct;
  final String nameProduct;
  final int quantity;
  final double unitPrice;

  const SaleProductModel({
    required this.idProduct,
    required this.nameProduct,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  factory SaleProductModel.fromMap(Map<String, dynamic> map) {
    return SaleProductModel(
      idProduct: (map['id_products'] ?? '').toString(),
      nameProduct: (map['name_product'] ?? '').toString(),
      quantity: (map['quantity_product'] as num? ?? 0).toInt(),
      unitPrice: (map['unitPrince_product'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_products': idProduct,
      'name_product': nameProduct,
      'quantity_product': quantity,
      'unitPrince_product': unitPrice,
    };
  }
}
class SalePaymentModel {
  final String idPaymentMethod;
  final double amount;

  const SalePaymentModel({
    required this.idPaymentMethod,
    required this.amount,
  });

  factory SalePaymentModel.fromMap(Map<String, dynamic> map) {
    return SalePaymentModel(
      idPaymentMethod: (map['id_payment_methods'] ?? '').toString(),
      amount: (map['amount'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_payment_methods': idPaymentMethod,
      'amount': amount,
    };
  }
}

class SaleModel {
  final String idSale;
  final String idCashClosure;
  final String idBranch;
  final String idUser;
  final DateTime saleDate;
  final bool saleStatus;
  final double totalSale;
  final double cashReceived;
  final double change;
  final List<SalePaymentModel> payments;
  final List<SaleProductModel> products;

  const SaleModel({
    this.idSale = '',
    required this.idCashClosure,
    required this.idBranch,
    required this.idUser,
    required this.saleDate,
    this.saleStatus = true,
    required this.totalSale,
    this.cashReceived = 0,
    this.change = 0,
    this.payments = const [],
    this.products = const [],
  });

  double get cashAmount => cashReceived - change;
  factory SaleModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawDate = data['sale_data'];
    final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
    final rawPayments = data['payment_method'] as List<dynamic>? ?? [];
    final rawProducts = data['products'] as List<dynamic>? ?? [];
    return SaleModel(
      idSale: doc.id,
      idCashClosure: (data['id_cash_closures'] ?? '').toString(),
      idBranch: (data['id_branches'] ?? '').toString(),
      idUser: (data['id_users'] ?? '').toString(),
      saleDate: date,
      saleStatus: data['sale_status'] as bool? ?? true,
      totalSale: (data['total_sale'] as num? ?? 0).toDouble(),
      cashReceived: (data['cash_received'] as num? ?? 0).toDouble(),
      change: (data['change'] as num? ?? 0).toDouble(),
      payments: rawPayments
          .map((e) => SalePaymentModel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      products: rawProducts
          .map((e) => SaleProductModel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cash_closures': idCashClosure,
      'id_branches': idBranch,
      'id_users': idUser,
      'sale_data': Timestamp.fromDate(saleDate),
      'sale_status': saleStatus,
      'total_sale': totalSale,
      'cash_received': cashReceived,
      'change': change,
      'payment_method': payments.map((p) => p.toMap()).toList(),
      'products': products.map((p) => p.toMap()).toList(),
    };
  }
}
