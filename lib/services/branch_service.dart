import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class BranchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection('branches');
  Future<List<Map<String, dynamic>>> getBranches() async {
    final snapshot = await _branches.get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }
  Future<List<Map<String, dynamic>>> getActiveBranches() async {
    final snapshot = await _branches.where('branch_status', isEqualTo: true).get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }
  Future<Map<String, dynamic>?> getBranchById(String id) async {
    final doc = await _branches.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return {
      'id': doc.id,
      ...doc.data()!,
    };
  }

  Future<String> createBranch({
    required String name,
    required String address,
    String logo = '',
    bool status = true,
  }) async {
    final doc = await _branches.add({
      'branch_name': name.trim(),
      'branch_address': address.trim(),
      'branch_logo': logo.trim(),
      'branch_status': status,
    });
    return doc.id;
  }
  Future<void> updateBranch({
    required String id,
    required String name,
    required String address,
    String logo = '',
  }) async {
    await _branches.doc(id).update({
      'branch_name': name.trim(),
      'branch_address': address.trim(),
      'branch_logo': logo.trim(),
    });
  }
  Future<void> updateBranchStatus({
    required String id,
    required bool status,
  }) async {
    await _branches.doc(id).update({
      'branch_status': status,
    });
  }
   Future<String> prepareLogo(
    XFile image, {
    Uint8List? imageBytes,
  }) async {
    final Uint8List bytes = imageBytes ?? await image.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('La imagen está vacía.');
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
        : Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    final String mime = conTransparencia ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(output)}';
  }
  
  Stream<List<Map<String, dynamic>>> watchBranches() {
    return _branches.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }
}