import 'package:cloud_firestore/cloud_firestore.dart';
class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const List<String> statuses = ['pendiente', 'entregado', 'cancelado'];
  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }
  static double round2(double value) => (value * 100).roundToDouble() / 100;
  static String statusOf(Map<String, dynamic> data) {
    final s = (data['order_status'] ?? '').toString().trim().toLowerCase();
    return s.isEmpty ? 'pendiente' : s;
  }

  Stream<List<Map<String, dynamic>>> watchOrders() {
    return _orders.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<Map<String, dynamic>?> getOrder(String id) async {
    final doc = await _orders.doc(id).get();
    if (!doc.exists) return null;
    return <String, dynamic>{'id': doc.id, ...?doc.data()};
  }

  Future<String> createOrder(Map<String, dynamic> data) async {
    final ref = _orders.doc();
    await ref.set({
      ...data,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateOrder(String id, Map<String, dynamic> data) {
    return _orders.doc(id).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus(String id, String status) {
    return _orders.doc(id).update({
      'order_status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getBranches() async {
    final snapshot = await _db.collection('branches').get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .where((branch) => branch['branch_status'] != false)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getProductsForBranch(
    String branchId,
  ) async {
    final inventory = await _db
        .collection('inventory')
        .where('id_branches', isEqualTo: branchId)
        .get();
    final productIds = <String>{};
    for (final doc in inventory.docs) {
      final data = doc.data();
      if (data['inventory_status'] == false) continue;
      final productId = (data['id_products'] ?? '').toString().trim();
      if (productId.isNotEmpty) productIds.add(productId);
    }
    if (productIds.isEmpty) return [];
    final products = await _db.collection('products').get();
    final list = products.docs
        .where(
          (doc) =>
              productIds.contains(doc.id) &&
              doc.data()['status_product'] != false,
        )
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList()
      ..sort(
        (a, b) => (a['name_product'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name_product'] ?? '').toString().toLowerCase()),
      );
    return list;
  }
}