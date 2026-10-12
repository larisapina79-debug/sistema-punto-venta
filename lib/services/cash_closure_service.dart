import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cash_closure_model.dart';

class CashClosureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('cash_closures');
  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('sales');

  Future<String> openCashRegister({
    required String idBranch,
    required String idUser,
    required double initialCash,
    required DateTime openingDate,
  }) async {
    final branch = idBranch.trim();
    final user = idUser.trim();

    if (branch.isEmpty || user.isEmpty) {
      throw Exception('No se identificó al usuario o la sucursal.');
    }
    if (!initialCash.isFinite || initialCash < 0) {
      throw Exception('El efectivo inicial no es válido.');
    }
    final existing = await getOpenCashRegister(
      idBranch: branch,
      idUser: user,
    );
    if (existing != null) {
      throw Exception(
        'Ya tienes una caja abierta. Ciérrala antes de abrir otra.',
      );
    }
    final doc = _ref.doc();
    final closure = CashClosureModel(
      idClosure: doc.id,
      openingDate: openingDate,
      initialCash: initialCash,
      expectedCash: initialCash,
      idBranch: branch,
      idUsers: user,
      statusClosing: false,
      saleCount: 0,
    );
    await doc.set(closure.toMap());
    return doc.id;
  }

  Future<CashClosureModel?> getOpenCashRegister({
    required String idBranch,
    required String idUser,
  }) async {
    final branch = idBranch.trim();
    final user = idUser.trim();

    if (branch.isEmpty || user.isEmpty) return null;
    final snapshot = await _ref
        .where('status_closing', isEqualTo: false)
        .get();

    final matches = snapshot.docs.where((doc) {
      final data = doc.data();
      final savedBranch = data['id_branch']?.toString() ?? '';
      final savedUser =
          (data['id_users'] ?? data['id_user'])?.toString() ?? '';
      return savedBranch == branch && savedUser == user;
    }).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final dateA = a.data()['opening_date'];
      final dateB = b.data()['opening_date'];
      final millisA = dateA is Timestamp
          ? dateA.millisecondsSinceEpoch
          : 0;
      final millisB = dateB is Timestamp
          ? dateB.millisecondsSinceEpoch
          : 0;
      return millisB.compareTo(millisA);
    });
    return CashClosureModel.fromFirestore(matches.first);
  }

  Future<String?> getOpenClosureId({
    required String idBranch,
    required String idUser,
  }) async {
    final closure = await getOpenCashRegister(
      idBranch: idBranch,
      idUser: idUser,
    );
    return closure?.idClosure;
  }

  Future<CashClosureModel?> getCashClosureById(
    String idClosure,
  ) async {
    if (idClosure.trim().isEmpty) return null;
    final doc = await _ref.doc(idClosure.trim()).get();
    if (!doc.exists) return null;
    return CashClosureModel.fromFirestore(doc);
  }
  Stream<List<CashClosureModel>> getCashClosures({
    String? idBranch,
  }) {
    return _ref.snapshots().map((snapshot) {
      final list = snapshot.docs
          .where((doc) {
            if (idBranch == null || idBranch.trim().isEmpty) {
              return true;
            }
            return doc.data()['id_branch']?.toString() ==
                idBranch.trim();
          })
          .map((doc) => CashClosureModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.openingDate.compareTo(a.openingDate));
      return list;
    });
  }

  Future<Map<String, dynamic>> calculateSalesSummary(
    String idClosure,
  ) async {
    final id = idClosure.trim();
    if (id.isEmpty) {
      throw Exception('No se identificó la caja.');
    }
    final snapshot = await _sales
        .where('id_cash_closures', isEqualTo: id)
        .where('sale_status', isEqualTo: true)
        .get();
    double totalSale = 0;
    double cashSale = 0;
    int saleCount = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalSale +=
          (data['total_sale'] as num?)?.toDouble() ?? 0;
      final received =
          (data['cash_received'] as num?)?.toDouble() ?? 0;
      final change =
          (data['change'] as num?)?.toDouble() ?? 0;
      if (received > 0) {
        cashSale += received - change;
      }
      saleCount++;
    }
    return {
      'total_sale': totalSale,
      'cash_sale': cashSale,
      'sale_count': saleCount,
    };
  }

  Future<void> closeCashRegister({
    required String idClosure,
    required double recordedCash,
  }) async {
    final id = idClosure.trim();
    if (id.isEmpty) {
      throw Exception('No se identificó la caja que deseas cerrar.');
    }
    if (!recordedCash.isFinite || recordedCash < 0) {
      throw Exception('El efectivo contado no es válido.');
    }
    final docRef = _ref.doc(id);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) {
        throw Exception('La caja no existe.');
      }
      final data = doc.data()!;
      if (data['status_closing'] == true) {
        throw Exception('Esta caja ya fue cerrada.');
      }
      final salesSnapshot = await _sales
          .where('id_cash_closures', isEqualTo: id)
          .where('sale_status', isEqualTo: true)
          .get();
      double totalSale = 0;
      double cashSale = 0;
      int saleCount = 0;
      for (final saleDoc in salesSnapshot.docs) {
        final sale = saleDoc.data();
        totalSale +=
            (sale['total_sale'] as num?)?.toDouble() ?? 0;
        final received =
            (sale['cash_received'] as num?)?.toDouble() ?? 0;
        final change =
            (sale['change'] as num?)?.toDouble() ?? 0;
        if (received > 0) {
          cashSale += received - change;
        }
        saleCount++;
      }
      final initialCash =
          (data['initial_cash'] as num?)?.toDouble() ?? 0;
      final expectedCash = initialCash + cashSale;
      final difference = recordedCash - expectedCash;
      transaction.update(docRef, {
        'closing_date': Timestamp.now(),
        'total_sale': totalSale,
        'cash_sale': cashSale,
        'sale_count': saleCount,
        'expected_cash': expectedCash,
        'recorded_cash': recordedCash,
        'difference': difference,
        'status_closing': true,
      });
    });
  }
}
