import 'package:cloud_firestore/cloud_firestore.dart';

class UserModal{
  final String uidAuth;
  final String userName;
  final String nameUser;
  final String lastName;
  final String phoneNumber;
  final String roleUser;
  final String statusUser;
  final List<String> idBranches;
}

UserModel({
  required this.idUser,
  required this.uidAuth,
  required this.userName,
  required this.nameUser,
  required this.lastNameUser,
  required this.phoneNumber,
  required this.roleUser,
  required this.statusUser,
  required this.idBranches,
})

factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserModel(
      idUser: doc.id,
      uidAuth: d['uid_auth'] ?? '',
      userName: d['userName'] ?? '',
      nameUser: d['name'] ?? '',
      lastNameUser: d['lastName'] ?? '',
      phoneNumber: d['phone_number'] ?? '',
      roleUser: d['role'] ?? '',
      statusUser: d['status'] ?? '',
      idBranches: List<String>.from(d['id_branches'] ?? []),
      ultimoAcceso: d['ultimo_acceso'] as Timestamp?,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'uid_auth': uidAuth,
      'userName': userName,
      'name': nameUser,
      'lastName': lastNameUser,
      'phone_number': phoneNumber,
      'role': roleUser,
      'status': statusUser,
      'id_branches': idBranches,
      if (ultimoAcceso != null) 'ultimo_acceso': ultimoAcceso,
    };
  }
}