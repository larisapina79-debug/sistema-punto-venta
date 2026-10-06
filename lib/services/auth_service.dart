import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

import '../models/user_model.dart';

class Session {
  static UserModel? user;
}

class AuthService {
  final _users = FirebaseFirestore.instance.collection('users');
  Future<UserModel?> login(String userName, String password) async {
    final q = await _users
        .where(
          'userName',
          isEqualTo: userName.trim().toLowerCase(),
        )
        .where('status', isEqualTo: true)
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      return null;
    }

    final doc = q.docs.first;
    final data = doc.data();
    final passwordHash = data['passwordHash']?.toString() ?? '';
    if (passwordHash.isEmpty) {
      return null;
    }
    final passwordCorrecta = BCrypt.checkpw(
      password.trim(),
      passwordHash,
    );
    if (!passwordCorrecta) {
      return null;
    }
    final user = UserModel.fromDoc(doc);
    Session.user = user;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'user_id',
      user.idUser,
    );

    return user;
  }

  Future<void> logout() async {
    Session.user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    if (id == null) return;
    final doc = await _users.doc(id).get();
    if (!doc.exists) return;
    final user = UserModel.fromDoc(doc);
    if (user.statusUser) {
      Session.user = user;
    }
  }
}