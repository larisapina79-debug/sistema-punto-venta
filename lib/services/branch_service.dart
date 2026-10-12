import 'package:cloud_firestore/cloud_firestore.dart';
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
    final snapshot = await _branches
        .where('branch_status', isEqualTo: true)
        .get();

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
  }) async {
    final doc = await _branches.add({
      'branch_name': name.trim(),
      'branch_address': address.trim(),
      'branch_logo': logo.trim(),
      'branch_status': true,
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
