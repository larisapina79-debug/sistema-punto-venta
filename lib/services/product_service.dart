import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'products';
  final String _collectionCategorias = 'categories';
  final String _collectionTiposVenta = 'product_types';

  Map<String, dynamic> _mapDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {
      'id': doc.id,
      ...?doc.data(),
    };
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '',
        ) ??
        fallback;
  }

  List<Map<String, dynamic>> _normalizarTiposVenta(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((tipo) => Map<String, dynamic>.from(tipo))
        .map((tipo) {
          return {
            'id_type': (tipo['id_type'] ?? '').toString(),
            'name_type': (tipo['name_type'] ?? '').toString(),
            'price': _toDouble(tipo['price']),
            'allows_decimal': tipo['allows_decimal'] == true,
            'units_per_sale': _toDouble(
              tipo['units_per_sale'],
              fallback: 1,
            ),
            'status': tipo['status'] != false,
          };
        })
        .toList();
  }

  Future<String> prepareImage(
    XFile image, {
    Uint8List? imageBytes,
  }) async {
    final Uint8List bytes = imageBytes ?? await image.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('La imagen está vacía.');
    }
    final bool isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    if (!isPng) {
      throw Exception('La imagen debe estar en formato PNG.');
    }
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('No se pudo leer la imagen.');
    }
    const int maxSize = 256;
    img.Image resized = decoded;
    if (decoded.width > maxSize || decoded.height > maxSize) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxSize)
          : img.copyResize(decoded, height: maxSize);
    }
    final bool conTransparencia = resized.hasAlpha;
    final Uint8List output = conTransparencia
        ? Uint8List.fromList(img.encodePng(resized))
        : Uint8List.fromList(
            img.encodeJpg(resized, quality: 70),
          );
    final String mime =
        conTransparencia ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(output)}';
  }

  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final snapshot = await _db.collection(_collection).get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerProductosActivos() async {
    final snapshot = await _db
        .collection(_collection)
        .where('status_product', isEqualTo: true)
        .get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  Future<Map<String, dynamic>?> obtenerProductoPorId(
    String idProducto,
  ) async {
    final doc = await _db.collection(_collection).doc(idProducto).get();
    if (!doc.exists) return null;
    return _mapDoc(doc);
  }

  Future<Map<String, dynamic>?> obtenerProductoPorCodigoBarras(
    String barcode,
  ) async {
    final codigo = barcode.trim();
    if (codigo.isEmpty) return null;
    final snapshot = await _db
        .collection(_collection)
        .where('barcode', isEqualTo: codigo)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _mapDoc(snapshot.docs.first);
  }

  Future<Map<String, dynamic>?> buscarProductoPorCodigoBarras(
    String barcode,
  ) {
    return obtenerProductoPorCodigoBarras(barcode);
  }

  Future<List<Map<String, dynamic>>> obtenerProductosPorCategoria(
    String idCategoria,
  ) async {
    final snapshot = await _db
        .collection(_collection)
        .where('id_categories', isEqualTo: idCategoria)
        .get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerProductosActivosPorCategoria(
    String idCategoria,
  ) async {
    final snapshot = await _db
        .collection(_collection)
        .where('status_product', isEqualTo: true)
        .where('id_categories', isEqualTo: idCategoria)
        .get();
    return snapshot.docs.map(_mapDoc).toList();
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
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final nombreProducto =
          (data['name_product'] ?? '').toString().toLowerCase();
      final codigo = (data['barcode'] ?? '').toString().toLowerCase();
      return nombreProducto.contains(busqueda) ||
          codigo.contains(busqueda);
    }).map(_mapDoc).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerModalidadesVenta(
    String idProducto,
  ) async {
    final producto = await obtenerProductoPorId(idProducto);
    if (producto == null) {
      throw Exception('No se encontró el producto.');
    }
    return _normalizarTiposVenta(producto['sale_types']);
  }

  Future<List<Map<String, dynamic>>> obtenerModalidadesVentaActivas(
    String idProducto,
  ) async {
    final modalidades = await obtenerModalidadesVenta(idProducto);
    return modalidades
        .where((tipo) => tipo['status'] == true)
        .toList();
  }

  Future<void> guardarModalidadesVenta({
    required String idProducto,
    required List<Map<String, dynamic>> saleTypes,
  }) async {
    final modalidades = <Map<String, dynamic>>[];
    for (final tipo in saleTypes) {
      final nombre = (tipo['name_type'] ?? '').toString().trim();
      final idTipo = (tipo['id_type'] ?? '').toString().trim();
      final precio = _toDouble(tipo['price']);
      final equivalencia = _toDouble(
        tipo['units_per_sale'],
        fallback: 1,
      );
      if (nombre.isEmpty) {
        throw Exception(
          'Todas las modalidades deben tener un nombre.',
        );
      }
      if (precio < 0) {
        throw Exception(
          'El precio de "$nombre" no puede ser negativo.',
        );
      }
      if (equivalencia <= 0) {
        throw Exception(
          'La equivalencia de "$nombre" debe ser mayor que cero.',
        );
      }
      modalidades.add({
        'id_type': idTipo,
        'name_type': nombre,
        'price': precio,
        'allows_decimal': tipo['allows_decimal'] == true,
        'units_per_sale': equivalencia,
        'status': tipo['status'] != false,
      });
    }
    await _db.collection(_collection).doc(idProducto).update({
      'sale_types': modalidades,
    });
  }

  Future<void> agregarModalidadVenta({
    required String idProducto,
    required Map<String, dynamic> saleType,
  }) async {
    final modalidades = await obtenerModalidadesVenta(idProducto);
    final idTipo = (saleType['id_type'] ?? '').toString().trim();
    final nombre = (saleType['name_type'] ?? '').toString().trim();
    if (nombre.isEmpty) {
      throw Exception('Debes indicar el nombre de la modalidad.');
    }
    final duplicada = modalidades.any((tipo) {
      if (idTipo.isNotEmpty) {
        return tipo['id_type'] == idTipo;
      }
      return (tipo['name_type'] ?? '')
              .toString()
              .toLowerCase() ==
          nombre.toLowerCase();
    });
    if (duplicada) {
      throw Exception(
        'Esta modalidad ya está registrada en el producto.',
      );
    }
    modalidades.add(saleType);
    await guardarModalidadesVenta(
      idProducto: idProducto,
      saleTypes: modalidades,
    );
  }

  Future<void> actualizarPrecioModalidad({
    required String idProducto,
    required String idTipo,
    required num precio,
  }) async {
    if (precio < 0) {
      throw Exception('El precio no puede ser negativo.');
    }
    final modalidades = await obtenerModalidadesVenta(idProducto);
    final indice = modalidades.indexWhere(
      (tipo) => tipo['id_type'] == idTipo,
    );
    if (indice == -1) {
      throw Exception('No se encontró la modalidad de venta.');
    }
    modalidades[indice]['price'] = precio;
    await guardarModalidadesVenta(
      idProducto: idProducto,
      saleTypes: modalidades,
    );
  }

  Future<void> cambiarEstadoModalidadVenta({
    required String idProducto,
    required String idTipo,
    required bool estado,
  }) async {
    final modalidades = await obtenerModalidadesVenta(idProducto);
    final indice = modalidades.indexWhere(
      (tipo) => tipo['id_type'] == idTipo,
    );
    if (indice == -1) {
      throw Exception('No se encontró la modalidad de venta.');
    }
    modalidades[indice]['status'] = estado;
    await guardarModalidadesVenta(
      idProducto: idProducto,
      saleTypes: modalidades,
    );
  }

  Future<num?> obtenerPrecioModalidad({
    required String idProducto,
    required String idTipo,
  }) async {
    final modalidades = await obtenerModalidadesVentaActivas(idProducto);
    for (final tipo in modalidades) {
      if (tipo['id_type'] == idTipo) {
        return tipo['price'] as num;
      }
    }
    return null;
  }

  Future<String> crearProducto({
    required String barcode,
    required String descriptionProduct,
    required String idCategories,
    String imageUrl = '',
    required String nameProduct,
    required num prince,
    required String typeProduct,
    bool statusProduct = true,
    List<Map<String, dynamic>> saleTypes = const [],
  }) async {
    final codigo = barcode.trim();
    if (codigo.isNotEmpty) {
      final existente = await obtenerProductoPorCodigoBarras(codigo);
      if (existente != null) {
        throw Exception(
          'Ya existe un producto con ese código de barras.',
        );
      }
    }

    final nombre = nameProduct.trim();
    if (nombre.isEmpty) {
      throw Exception('El nombre del producto es obligatorio.');
    }
    if (prince < 0) {
      throw Exception('El precio no puede ser negativo.');
    }
    final modalidades = _normalizarTiposVenta(saleTypes);
    final doc = await _db.collection(_collection).add({
      'barcode': codigo,
      'description_product': descriptionProduct.trim(),
      'id_categories': idCategories,
      'image_url': imageUrl,
      'name_product': nombre,
      'prince': prince,
      'typeProduct': typeProduct,
      'sale_types': modalidades,
      'status_product': statusProduct,
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> actualizarProducto({
    required String idProducto,
    required String barcode,
    required String descriptionProduct,
    required String idCategories,
    required String imageUrl,
    required String nameProduct,
    required num prince,
    required String typeProduct,
    List<Map<String, dynamic>>? saleTypes,
  }) async {
    final codigo = barcode.trim();
    if (codigo.isNotEmpty) {
      final existente = await obtenerProductoPorCodigoBarras(codigo);
      if (existente != null && existente['id'] != idProducto) {
        throw Exception(
          'Ya existe otro producto con ese código de barras.',
        );
      }
    }
    if (nameProduct.trim().isEmpty) {
      throw Exception('El nombre del producto es obligatorio.');
    }
    if (prince < 0) {
      throw Exception('El precio no puede ser negativo.');
    }
    final Map<String, dynamic> datos = {
      'barcode': codigo,
      'description_product': descriptionProduct.trim(),
      'id_categories': idCategories,
      'image_url': imageUrl,
      'name_product': nameProduct.trim(),
      'prince': prince,
      'typeProduct': typeProduct,
    };
    if (saleTypes != null) {
      datos['sale_types'] = _normalizarTiposVenta(saleTypes);
    }
    await _db.collection(_collection).doc(idProducto).update(datos);
  }

  Future<void> cambiarEstadoProducto(
    String idProducto,
    bool estado,
  ) async {
    await _db.collection(_collection).doc(idProducto).update({
      'status_product': estado,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerTiposVenta() async {
    final snapshot = await _db.collection(_collectionTiposVenta).get();
    final tipos = snapshot.docs.map(_mapDoc).toList();
    tipos.sort((a, b) {
      final nombreA = (a['name_type'] ?? '').toString().toLowerCase();
      final nombreB = (b['name_type'] ?? '').toString().toLowerCase();
      return nombreA.compareTo(nombreB);
    });
    return tipos;
  }

  Future<List<Map<String, dynamic>>> obtenerTiposVentaActivos() async {
    final snapshot = await _db
        .collection(_collectionTiposVenta)
        .where('status_type', isEqualTo: true)
        .get();
    final tipos = snapshot.docs.map(_mapDoc).toList();
    tipos.sort((a, b) {
      final nombreA = (a['name_type'] ?? '').toString().toLowerCase();
      final nombreB = (b['name_type'] ?? '').toString().toLowerCase();
      return nombreA.compareTo(nombreB);
    });
    return tipos;
  }

  Future<String> crearTipoVenta({
    required String nameType,
    bool statusType = true,
  }) async {
    final nombre = nameType.trim();
    if (nombre.isEmpty) {
      throw Exception('El nombre del tipo de venta es obligatorio.');
    }
    final snapshot = await _db.collection(_collectionTiposVenta).get();
    for (final doc in snapshot.docs) {
      final existente =
          (doc.data()['name_type'] ?? '').toString().trim();
      if (existente.toLowerCase() == nombre.toLowerCase()) {
        await doc.reference.update({
          'name_type': nombre,
          'status_type': statusType,
        });
        return doc.id;
      }
    }
    final doc = await _db.collection(_collectionTiposVenta).add({
      'name_type': nombre,
      'status_type': statusType,
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> actualizarTipoVenta({
    required String idTipo,
    required String nameType,
  }) async {
    final nombre = nameType.trim();
    if (nombre.isEmpty) {
      throw Exception('El nombre del tipo de venta es obligatorio.');
    }
    final snapshot = await _db.collection(_collectionTiposVenta).get();
    for (final doc in snapshot.docs) {
      if (doc.id == idTipo) continue;
      final existente =
          (doc.data()['name_type'] ?? '').toString().trim();
      if (existente.toLowerCase() == nombre.toLowerCase()) {
        throw Exception('Ya existe un tipo de venta con ese nombre.');
      }
    }
    await _db.collection(_collectionTiposVenta).doc(idTipo).update({
      'name_type': nombre,
    });
  }

  Future<void> cambiarEstadoTipoVenta(
    String idTipo,
    bool estado,
  ) async {
    await _db.collection(_collectionTiposVenta).doc(idTipo).update({
      'status_type': estado,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    final snapshot = await _db.collection(_collectionCategorias).get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerCategoriasActivas() async {
    final snapshot = await _db
        .collection(_collectionCategorias)
        .where('status_category', isEqualTo: true)
        .get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  Future<Map<String, dynamic>?> obtenerCategoriaPorId(
    String idCategoria,
  ) async {
    final doc =
        await _db.collection(_collectionCategorias).doc(idCategoria).get();
    if (!doc.exists) return null;

    return _mapDoc(doc);
  }

  Future<Map<String, String>> obtenerMapaCategorias() async {
    final snapshot = await _db.collection(_collectionCategorias).get();
    return {
      for (final doc in snapshot.docs)
        doc.id: (doc.data()['name_category'] ?? '').toString(),
    };
  }

  Future<String> crearCategoria({
    required String nameCategory,
    bool statusCategory = true,
  }) async {
    final nombre = nameCategory.trim();
    if (nombre.isEmpty) {
      throw Exception('El nombre de la categoría es obligatorio.');
    }
    final snapshot = await _db.collection(_collectionCategorias).get();
    for (final doc in snapshot.docs) {
      final existente =
          (doc.data()['name_category'] ?? '').toString().trim();
      if (existente.toLowerCase() == nombre.toLowerCase()) {
        await doc.reference.update({
          'name_category': nombre,
          'status_category': statusCategory,
        });
        return doc.id;
      }
    }
    final doc = await _db.collection(_collectionCategorias).add({
      'name_category': nombre,
      'status_category': statusCategory,
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> actualizarCategoria({
    required String idCategoria,
    required String nameCategory,
  }) async {
    final nombre = nameCategory.trim();
    if (nombre.isEmpty) {
      throw Exception('El nombre de la categoría es obligatorio.');
    }
    final snapshot = await _db.collection(_collectionCategorias).get();
    for (final doc in snapshot.docs) {
      if (doc.id == idCategoria) continue;
      final existente =
          (doc.data()['name_category'] ?? '').toString().trim();
      if (existente.toLowerCase() == nombre.toLowerCase()) {
        throw Exception('Ya existe una categoría con ese nombre.');
      }
    }
    await _db.collection(_collectionCategorias).doc(idCategoria).update({
      'name_category': nombre,
    });
  }

  Future<void> cambiarEstadoCategoria(
    String idCategoria,
    bool estado,
  ) async {
    await _db.collection(_collectionCategorias).doc(idCategoria).update({
      'status_category': estado,
    });
  }

  Future<int> contarCategorias() async {
    final snapshot =
        await _db.collection(_collectionCategorias).count().get();
    return snapshot.count ?? 0;
  }
}
