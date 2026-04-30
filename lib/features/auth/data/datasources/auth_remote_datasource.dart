import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/app_user.dart';

class AuthRemoteDatasource {
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

  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) return null;
    final profile = await _fetchUser(credential.user!.uid);
    return profile ?? _fromFirebaseUser(credential.user!);
  }

  Future<AppUser?> signInWithGoogle() async {
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
    return _ensureUserDocument(firebaseUser);
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final profile = await _fetchUser(user.uid);
    return profile ?? _fromFirebaseUser(user);
  }

  Future<AppUser?> _fetchUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.data()!, doc.id);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  Future<AppUser?> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
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
