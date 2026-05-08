import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_user.dart';

class AuthRemoteDatasource {
  static const _rememberLoginKey = 'remember_login';
  static const _rememberedEmailKey = 'remembered_email';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn? _googleSignIn;

  AuthRemoteDatasource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = kIsWeb ? null : (googleSignIn ?? GoogleSignIn());

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _configurePersistence(bool rememberLogin) async {
    if (!kIsWeb) return;
    await _auth.setPersistence(
      rememberLogin ? Persistence.LOCAL : Persistence.SESSION,
    );
  }

  Future<void> setRememberLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberLoginKey, value);
  }

  Future<bool> getRememberLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberLoginKey) ?? true;
  }

  Future<void> setRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailKey, email);
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberedEmailKey)?.trim();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
  }

  Future<AppUser?> signIn({
    required String email,
    required String password,
    bool rememberLogin = true,
  }) async {
    await _configurePersistence(rememberLogin);
    await setRememberLogin(rememberLogin);
    if (rememberLogin) {
      await setRememberedEmail(email);
    } else {
      await clearRememberedEmail();
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) return null;
    final profile = await _fetchUser(credential.user!.uid);
    final user = profile ?? _fromFirebaseUser(credential.user!);
    _saveFcmToken(credential.user!.uid);
    _setupTokenRefreshListener(credential.user!.uid);
    return user;
  }

  Future<AppUser?> signInWithGoogle({bool rememberLogin = true}) async {
    await _configurePersistence(rememberLogin);
    await setRememberLogin(rememberLogin);

    UserCredential credential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      credential = await _auth.signInWithPopup(provider);
    } else {
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final authCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(authCredential);
    }

    final firebaseUser = credential.user;
    if (firebaseUser == null) return null;
    if (rememberLogin) {
      await setRememberedEmail(firebaseUser.email ?? '');
    } else {
      await clearRememberedEmail();
    }
    final user = await _ensureUserDocument(firebaseUser);
    _saveFcmToken(firebaseUser.uid);
    _setupTokenRefreshListener(firebaseUser.uid);
    return user;
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AuthDS] _saveFcmToken error: $e');
    }
  }

  void _setupTokenRefreshListener(String userId) {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[AuthDS] token refresh update error: $e');
      }
    });
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final profile = await _fetchUser(user.uid);
    return profile ?? _fromFirebaseUser(user);
  }

  Future<AppUser?> _fetchUser(String uid) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (!doc.exists || doc.data() == null) return null;
        return AppUser.fromMap(doc.data()!, doc.id);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') return null;

        final isTransient = e.code == 'unavailable' || e.code == 'deadline-exceeded';
        final isLastAttempt = attempt == maxAttempts;
        if (!isTransient || isLastAttempt) {
          if (isTransient) return null;
          rethrow;
        }

        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    return null;
  }

  Future<AppUser?> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    bool rememberLogin = true,
  }) async {
    await _configurePersistence(rememberLogin);
    await setRememberLogin(rememberLogin);
    if (rememberLogin) {
      await setRememberedEmail(email);
    } else {
      await clearRememberedEmail();
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    final appUser = AppUser(
      id: credential.user!.uid,
      name: name,
      email: email,
      role: role,
      isActive: true,
      createdAt: DateTime.now(),
    );
    try {
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(appUser.toMap());
    } on FirebaseException catch (e) {
      // Se a regra do Firestore estiver bloqueando escrita, não quebramos o cadastro.
      if (e.code != 'permission-denied') rethrow;
    }
    return appUser;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Sessao invalida para trocar senha.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<AppUser> _ensureUserDocument(User firebaseUser) async {
    final existing = await _fetchUser(firebaseUser.uid);
    if (existing != null) return existing;

    final appUser = AppUser(
      id: firebaseUser.uid,
      name: firebaseUser.displayName?.trim().isNotEmpty == true
          ? firebaseUser.displayName!.trim()
          : (firebaseUser.email?.split('@').first ?? 'Novo usuario'),
      email: firebaseUser.email ?? '',
      role: UserRole.consulta,
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore.collection('users').doc(firebaseUser.uid).set(appUser.toMap());
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    return appUser;
  }

  AppUser _fromFirebaseUser(User user) {
    return AppUser(
      id: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Usuario'),
      email: user.email ?? '',
      role: UserRole.consulta,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }
}
