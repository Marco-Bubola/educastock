import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../products/domain/entities/product.dart';

class CategorySetting {
  final String key;
  final String label;
  final bool isActive;

  const CategorySetting({
    required this.key,
    required this.label,
    required this.isActive,
  });

  factory CategorySetting.fromMap(String key, Map<String, dynamic> map) {
    return CategorySetting(
      key: key,
      label: map['label'] as String? ?? key,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'isActive': isActive,
      };
}

class AlertsConfig {
  final int criticalDays;
  final int warningDays;
  final bool expiryEnabled;

  const AlertsConfig({
    required this.criticalDays,
    required this.warningDays,
    required this.expiryEnabled,
  });

  factory AlertsConfig.fromMap(Map<String, dynamic> map) {
    final critical = (map['criticalDays'] as num?)?.toInt() ?? 7;
    final warning = (map['warningDays'] as num?)?.toInt() ?? 30;
    return AlertsConfig(
      criticalDays: critical,
      warningDays: warning < critical ? critical + 1 : warning,
      expiryEnabled: map['expiryEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'criticalDays': criticalDays,
        'warningDays': warningDays,
        'expiryEnabled': expiryEnabled,
      };
}

class StockRulesConfig {
  final int negativeAdjustmentApprovalLimit;

  const StockRulesConfig({
    required this.negativeAdjustmentApprovalLimit,
  });

  factory StockRulesConfig.fromMap(Map<String, dynamic> map) {
    return StockRulesConfig(
      negativeAdjustmentApprovalLimit:
          (map['negativeAdjustmentApprovalLimit'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toMap() => {
        'negativeAdjustmentApprovalLimit': negativeAdjustmentApprovalLimit,
      };
}

class UserAdminDatasource {
  final FirebaseFirestore _db;

  UserAdminDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Stream<List<AppUser>> watchUsers() {
    return _users.snapshots().map((snap) {
      final users = snap.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList();
      users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return users;
    });
  }

  Future<void> updateUserRole({
    required String userId,
    required UserRole role,
  }) {
    return _users.doc(userId).update({'role': role.name});
  }

  Future<void> setUserActive({
    required String userId,
    required bool isActive,
  }) {
    return _users.doc(userId).update({'isActive': isActive});
  }
}

class CategorySettingsDatasource {
  final FirebaseFirestore _db;

  CategorySettingsDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('settings_categories');

  Future<void> ensureSeed() async {
    for (final category in ProductCategory.values) {
      final ref = _col.doc(category.name);
      final doc = await ref.get();
      if (!doc.exists) {
        final label = Product(
          id: '',
          name: '',
          category: category,
          unit: '',
          isPerishable: true,
          createdAt: DateTime.now(),
          createdBy: '',
        ).categoryLabel;
        await ref.set({'label': label, 'isActive': true});
      }
    }
  }

  Stream<List<CategorySetting>> watchCategories() {
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => CategorySetting.fromMap(d.id, d.data()))
          .toList();
      items.sort((a, b) => a.label.compareTo(b.label));
      return items;
    });
  }

  Future<void> setCategoryActive(String key, bool isActive) {
    return _col.doc(key).set({'isActive': isActive}, SetOptions(merge: true));
  }
}

class AlertsSettingsDatasource {
  final FirebaseFirestore _db;

  AlertsSettingsDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('settings').doc('alerts');

  Future<void> ensureSeed() async {
    final doc = await _doc.get();
    if (!doc.exists) {
      await _doc.set(const AlertsConfig(
        criticalDays: 7,
        warningDays: 30,
        expiryEnabled: true,
      ).toMap());
    }
  }

  Stream<AlertsConfig> watchConfig() {
    return _doc.snapshots().map((d) {
      final data = d.data();
      if (data == null) {
        return const AlertsConfig(
          criticalDays: 7,
          warningDays: 30,
          expiryEnabled: true,
        );
      }
      return AlertsConfig.fromMap(data);
    });
  }

  Future<void> saveConfig(AlertsConfig config) {
    return _doc.set(config.toMap(), SetOptions(merge: true));
  }
}

class StockRulesSettingsDatasource {
  final FirebaseFirestore _db;

  StockRulesSettingsDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('settings').doc('stock_rules');

  Future<void> ensureSeed() async {
    final doc = await _doc.get();
    if (!doc.exists) {
      await _doc.set(
        const StockRulesConfig(
          negativeAdjustmentApprovalLimit: 50,
        ).toMap(),
      );
    }
  }

  Stream<StockRulesConfig> watchConfig() {
    return _doc.snapshots().map((d) {
      final data = d.data();
      if (data == null) {
        return const StockRulesConfig(
          negativeAdjustmentApprovalLimit: 50,
        );
      }
      return StockRulesConfig.fromMap(data);
    });
  }
}

final userAdminDatasourceProvider = Provider<UserAdminDatasource>(
  (_) => UserAdminDatasource(),
);

final usersManagementProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userAdminDatasourceProvider).watchUsers();
});

class UserManagementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateRole({
    required String userId,
    required UserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(userAdminDatasourceProvider).updateUserRole(
            userId: userId,
            role: role,
          );
    });
  }

  Future<void> setActive({
    required String userId,
    required bool isActive,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(userAdminDatasourceProvider).setUserActive(
            userId: userId,
            isActive: isActive,
          );
    });
  }
}

final userManagementNotifierProvider =
    AsyncNotifierProvider<UserManagementNotifier, void>(
        UserManagementNotifier.new);

final categorySettingsDatasourceProvider = Provider<CategorySettingsDatasource>(
  (_) => CategorySettingsDatasource(),
);

final categorySettingsProvider = StreamProvider<List<CategorySetting>>((ref) {
  return ref.watch(categorySettingsDatasourceProvider).watchCategories();
});

class CategorySettingsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    await ref.read(categorySettingsDatasourceProvider).ensureSeed();
  }

  Future<void> setCategoryActive({
    required String key,
    required bool isActive,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(categorySettingsDatasourceProvider)
          .setCategoryActive(key, isActive);
    });
  }
}

final categorySettingsNotifierProvider =
    AsyncNotifierProvider<CategorySettingsNotifier, void>(
        CategorySettingsNotifier.new);

final activeProductCategoriesProvider = Provider<List<ProductCategory>>((ref) {
  final asyncItems = ref.watch(categorySettingsProvider);
  return asyncItems.maybeWhen(
    data: (items) {
      if (items.isEmpty) return ProductCategory.values;
      final enabled = items.where((e) => e.isActive).map((e) => e.key).toSet();
      final categories = ProductCategory.values
          .where((c) => enabled.contains(c.name))
          .toList();
      return categories.isEmpty ? ProductCategory.values : categories;
    },
    orElse: () => ProductCategory.values,
  );
});

final alertsSettingsDatasourceProvider = Provider<AlertsSettingsDatasource>(
  (_) => AlertsSettingsDatasource(),
);

final stockRulesSettingsDatasourceProvider =
    Provider<StockRulesSettingsDatasource>(
  (_) => StockRulesSettingsDatasource(),
);

final alertsConfigProvider = StreamProvider<AlertsConfig>((ref) {
  return ref.watch(alertsSettingsDatasourceProvider).watchConfig();
});

final stockRulesConfigProvider = StreamProvider<StockRulesConfig>((ref) {
  return ref.watch(stockRulesSettingsDatasourceProvider).watchConfig();
});

class AlertsConfigNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    await ref.read(alertsSettingsDatasourceProvider).ensureSeed();
  }

  Future<void> save(AlertsConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(alertsSettingsDatasourceProvider).saveConfig(config);
    });
  }
}

final alertsConfigNotifierProvider =
    AsyncNotifierProvider<AlertsConfigNotifier, void>(AlertsConfigNotifier.new);

class StockRulesConfigNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    await ref.read(stockRulesSettingsDatasourceProvider).ensureSeed();
  }
}

final stockRulesConfigNotifierProvider =
    AsyncNotifierProvider<StockRulesConfigNotifier, void>(
  StockRulesConfigNotifier.new,
);
