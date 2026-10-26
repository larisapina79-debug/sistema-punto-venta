import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'products';

  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final snapshot = await _db.collection(_collection).get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerProductosActivos() async {
    final snapshot = await _db
        .collection(_collection)
        .where('status_product', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> obtenerProductoPorId(
    String idProducto,
  ) async {
    final doc = await _db.collection(_collection).doc(idProducto).get();
    if (!doc.exists) {
      return null;
    }
    return {
      'id': doc.id,
      ...doc.data()!,
    };
  }

  Future<int> contarProductos() async {
    final snapshot = await _db.collection(_collection).count().get();
    return snapshot.count ?? 0;
  }

  Future<int> contarProductosActivos() async {
    final snapshot = await _db
        .collection(_collection)
        .where('status_product', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<List<Map<String, dynamic>>> buscarProductos(
    String nombre,
  ) async {
    final snapshot = await _db.collection(_collection).get();
    final busqueda = nombre.trim().toLowerCase();
    return snapshot.docs
        .where((doc) {
          final nombreProducto =
              (doc.data()['name_product'] ?? '').toString().toLowerCase();
          return nombreProducto.contains(busqueda);
        })
        .map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        })
        .toList();
  }
}
