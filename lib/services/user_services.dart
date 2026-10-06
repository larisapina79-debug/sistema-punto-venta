import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import '../models/user_model.dart';

class UsersService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');

  Stream<List<UserModel>> getUsers() {
    return _users.snapshots().map(
          (s) => s.docs.map(UserModel.fromDoc).toList(),
        );
  }

  Future<void> createUser({
    required String name,
    required String lastName,
    required String userName,
    required String password,
    required String role,
    required List<String> branchIds,
  }) async {
    final user = userName.trim().toLowerCase();
    final passwordHash = BCrypt.hashpw(
      password,
      BCrypt.gensalt(),
    );

    await _users.add({
      'id_branches': branchIds
          .map(
            (id) => _db.collection('branches').doc(id),
          )
          .toList(),
      'lastName': lastName.trim(),
      'name': name.trim(),
      'phone_number': '',
      'role': role,
      'status': true,
      'userName': user,
      'passwordHash': passwordHash,
    });
  }

  Future<bool> verificarPassword({
    required String password,
    required String passwordHash,
  }) async {
    try {
      return BCrypt.checkpw(
        password,
        passwordHash,
      );
    } catch (e) {
      return false;
    }
  }

  Future<UserModel?> login({
    required String userName,
    required String password,
  }) async {
    final user = userName.trim().toLowerCase();
    final q = await _users
        .where('userName', isEqualTo: user)
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      return null;
    }
    final doc = q.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    final passwordHash = data['passwordHash'];
    if (passwordHash == null ||
        passwordHash.toString().trim().isEmpty) {
      return null;
    }
    final passwordCorrecta = await verificarPassword(
      password: password,
      passwordHash: passwordHash.toString(),
    );
    if (!passwordCorrecta) {
      return null;
    }
    final status = data['status'];
    if (status == false) {
      return null;
    }
    return UserModel.fromDoc(doc);
  }

  Future<void> updateUser(
    String idUser,
    Map<String, dynamic> data,
  ) async {
    final datos = Map<String, dynamic>.from(data);
    if (datos.containsKey('password')) {
      final password = datos['password'];
      if (password != null &&
          password.toString().trim().isNotEmpty) {
        final passwordHash = BCrypt.hashpw(
          password.toString(),
          BCrypt.gensalt(),
        );
        datos.remove('password');
        datos['passwordHash'] = passwordHash;
      }
    }

    await _users.doc(idUser).update(datos);
  }

  Future<void> updatePassword(
    String idUser,
    String newPassword,
  ) async {
    if (newPassword.trim().isEmpty) {
      throw Exception(
        'La contraseña no puede estar vacía',
      );
    }
    final passwordHash = BCrypt.hashpw(
      newPassword,
      BCrypt.gensalt(),
    );

    await _users.doc(idUser).update({
      'passwordHash': passwordHash,
    });
  }
  
  Future<void> setStatus(
    String idUser,
    bool status,
  ) {
    return _users.doc(idUser).update({
      'status': status,
    });
  }
}