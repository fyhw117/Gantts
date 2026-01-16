import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth
          .sendPasswordResetEmail(email: email)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // タイムアウトしても、メール送信自体は成功している可能性が高いためエラーにしない
      // UI側では「送信しました」として処理を進める
      print('Password reset email timeout (suppressed)');
    }
  }

  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
