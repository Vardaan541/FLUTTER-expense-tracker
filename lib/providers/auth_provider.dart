import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _authSubscription = _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<bool> signIn({required String email, required String password}) async {
    return _runAuthAction(() async {
      await _authService.signIn(email: email, password: password);
    });
  }

  Future<bool> signUp({required String email, required String password}) async {
    return _runAuthAction(() async {
      await _authService.signUp(email: email, password: password);
    });
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = error.message ?? 'Authentication failed';
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
