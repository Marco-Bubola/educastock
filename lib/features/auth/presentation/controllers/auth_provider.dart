import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/app_user.dart';

final authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (_) => AuthRemoteDatasource(),
);

final authStateProvider = StreamProvider<AppUser?>((ref) async* {
  final ds = ref.watch(authDatasourceProvider);
  await for (final firebaseUser in ds.authStateChanges) {
    if (firebaseUser == null) {
      yield null;
    } else {
      yield await ds.getCurrentUser();
    }
  }
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

// Auth notifier para login/logout
class AuthNotifier extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() {
    return const AsyncValue.loading();
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(authDatasourceProvider);
      return ds.signIn(email: email, password: password);
    });
  }

  Future<void> signOut() async {
    final ds = ref.read(authDatasourceProvider);
    await ds.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<AppUser?>>(() => AuthNotifier());
