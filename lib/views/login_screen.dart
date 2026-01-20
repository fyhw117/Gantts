import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/auth_repository.dart';
import '../repositories/firestore_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  final _firestoreRepository = FirestoreRepository();
  String _errorMessage = '';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await _authRepository.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Main navigation handled by StreamBuilder in main.dart
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました: $e';
      });
    } finally {
      setState(() {
        if (mounted) _isLoading = false;
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await _authRepository.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // ユーザー登録成功にサンプルデータを作成
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Create default data (Critical)
        await _firestoreRepository.createDefaultProject(user.uid);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました: $e';
      });
    } finally {
      setState(() {
        if (mounted) _isLoading = false;
      });
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'user-disabled':
        return 'このユーザーは無効化されています。';
      case 'user-not-found':
        return 'ユーザーが見つかりません。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています。';
      case 'operation-not-allowed':
        return 'この操作は許可されていません。';
      case 'weak-password':
        return 'パスワードが弱すぎます。6文字以上で設定してください。';
      case 'invalid-credential':
        return '認証情報が無効です。再度お試しください。';
      default:
        return 'エラーが発生しました: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gantts')),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ログイン / 新規登録',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'メールアドレス'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showPasswordResetDialog,
                      child: const Text('パスワードを忘れた場合'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty) ...[
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _signIn,
                            child: const Text('ログイン'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _signUp,
                            child: const Text('新規登録'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPasswordResetDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('パスワード再設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('登録したメールアドレスを入力してください。\n再設定用のリンクを送信します。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    decoration: const InputDecoration(labelText: 'メールアドレス'),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        isLoading = true;
                        dialogError = null;
                      });

                      try {
                        await _authRepository.sendPasswordResetEmail(
                          resetEmailController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context); // input dialog close
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('送信完了'),
                                content: const Text(
                                  'パスワード再設定メールを送信しました。\nメールボックスをご確認ください。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        if (context.mounted) {
                          setState(() {
                            isLoading = false;
                            dialogError = _getErrorMessage(e);
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() {
                            isLoading = false;
                            dialogError = 'エラーが発生しました: $e';
                          });
                        }
                      }
                    },
                    child: const Text('送信'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
