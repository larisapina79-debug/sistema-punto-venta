import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_model.dart';
import 'cash_closure_service.dart';

class SaleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('sales');

  Future<SaleModel> createSale({
    required String idBranch,
    required String idUser,
    required List<SaleProductModel> products,
    required List<SalePaymentModel> payments,
    double cashReceived = 0,
  }) async {
    if (products.isEmpty) {
      throw Exception('La venta no tiene productos.');
    }

    final idClosure = await CashClosureService().getOpenClosureId(
      idBranch: idBranch,
      idUser: idUser,
    );

    if (idClosure == null) {
      throw Exception('No hay una caja abierta. Inicia la caja para vender.');
    }

    final total = products.fold<double>(0, (acc, p) => acc + p.subtotal);

    double change = 0;
    if (cashReceived > 0) {
      if (cashReceived < total) {
        throw Exception('El efectivo recibido es menor al total.');
      }
      change = cashReceived - total;
    }

    final sale = SaleModel(
      idCashClosure: idClosure,
      idBranch: idBranch,
      idUser: idUser,
      saleDate: DateTime.now(),
      saleStatus: true,
      totalSale: total,
      cashReceived: cashReceived,
      change: change,
      payments: payments,
      products: products,
    );

    final ref = await _sales.add(sale.toMap());

    return SaleModel(
      idSale: ref.id,
      idCashClosure: sale.idCashClosure,
      idBranch: sale.idBranch,
      idUser: sale.idUser,
      saleDate: sale.saleDate,
      saleStatus: sale.saleStatus,
      totalSale: sale.totalSale,
      cashReceived: sale.cashReceived,
      change: sale.change,
      payments: sale.payments,
      products: sale.products,
    );
  }

  Future<List<SaleModel>> getSalesByClosure(String idClosure) async {
    final snapshot =
        await _sales.where('id_cash_closures', isEqualTo: idClosure).get();

    final list = snapshot.docs.map(SaleModel.fromFirestore).toList();
    list.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return list;
  }

  Future<List<SaleModel>> getSalesByDateRange({
    required String idBranch,
    required DateTime from,
    required DateTime to,
  }) async {
    final snapshot = await _sales.where('id_branches', isEqualTo: idBranch).get();

    final list = snapshot.docs
        .map(SaleModel.fromFirestore)
        .where((s) => !s.saleDate.isBefore(from) && s.saleDate.isBefore(to))
        .toList();
    list.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return list;
  }

  Future<double> getTodayTotal(String idBranch) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final sales = await getSalesByDateRange(
      idBranch: idBranch,
      from: start,
      to: end,
    );

    return sales
        .where((s) => s.saleStatus)
        .fold<double>(0, (acc, s) => acc + s.totalSale);
  }

  Future<void> cancelSale(String idSale) async {
    await _sales.doc(idSale).update({'sale_status': false});
  }
}