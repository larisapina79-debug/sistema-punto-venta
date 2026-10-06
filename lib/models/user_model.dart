import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String idUser;
  final String password;
  final String nameUser;
  final String lastNameUser;
  final String userName;
  final String phoneNumber;
  final String roleUser;
  final bool statusUser;
  final List<DocumentReference> idBranches;

  UserModel({
    required this.idUser,
    required this.password,
    required this.nameUser,
    required this.lastNameUser,
    required this.userName,
    required this.phoneNumber,
    required this.roleUser,
    required this.statusUser,
    required this.idBranches,
  });

  String get fullName => '$nameUser $lastNameUser';

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      idUser: doc.id,
      password: d['password'] ?? '',
      nameUser: d['name'] ?? '',
      lastNameUser: d['lastName'] ?? '',
      userName: d['userName'] ?? '',
      phoneNumber: d['phone_number'] ?? '',
      roleUser: d['role'] ?? '',
      statusUser: d['status'] ?? false,
      idBranches: ((d['id_branches'] as List?) ?? [])
          .whereType<DocumentReference>()
          .toList(),
    );
  }
}