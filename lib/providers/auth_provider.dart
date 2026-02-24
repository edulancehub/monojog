import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineMode = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isOfflineMode => _isOfflineMode;

  AuthProvider() {
    _ensureGoogleInitialized();
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    } catch (e) {
      debugPrint('Google Sign-In init error: $e');
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      clearError();

      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        _error = 'Google sign-in failed. Missing Google token.';
        _setLoading(false);
        return false;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final googleName = googleUser.displayName?.trim();
      final currentName = userCredential.user?.displayName?.trim();
      if ((currentName == null || currentName.isEmpty) &&
          googleName != null &&
          googleName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(googleName);
        await userCredential.user?.reload();
      }

      _isOfflineMode = false;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _setLoading(false);
      return false;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _error = null;
      } else {
        _error = 'Google sign-in failed. Please try again.';
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Google sign-in failed. Please try again.';
      debugPrint('Google Sign-In Error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      clearError();

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Login failed.';
      debugPrint('Email Sign-In Error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    try {
      _setLoading(true);
      clearError();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (name.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(name.trim());
        await credential.user?.reload();
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Sign up failed.';
      debugPrint('Email Sign-Up Error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      _setLoading(true);
      clearError();
      await _auth.sendPasswordResetEmail(email: email.trim());
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Could not reset password.';
      debugPrint('Reset Password Error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInAsGuest() async {
    try {
      _setLoading(true);
      clearError();
      await _auth.signInAnonymously();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Guest login failed.';
      debugPrint('Guest Sign-In Error: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _isOfflineMode = false;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  /// Enter offline mode — no Firebase, all data local
  void enterOfflineMode() {
    _isOfflineMode = true;
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Operation failed. Please try again.';
    }
  }
}
