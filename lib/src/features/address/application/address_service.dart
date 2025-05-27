import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesInstanceProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

const String _deliveryAddressKey = 'deliveryAddress';


class SavedAddressNotifier extends StateNotifier<AsyncValue<String?>> {
  final SharedPreferences _prefs;

  SavedAddressNotifier(this._prefs) : super(const AsyncValue.loading()) {
    _loadAddress();
  }

  // Загрузка адреса при инициализации
  void _loadAddress() {
    try {
      final address = _prefs.getString(_deliveryAddressKey);
      state = AsyncValue.data(address);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Обновление/сохранение адреса
  Future<void> updateAddress(String? newAddress) async {
    state = AsyncValue.data(newAddress);
    try {
      if (newAddress == null || newAddress.isEmpty) {
        await _prefs.remove(_deliveryAddressKey);
      } else {
        await _prefs.setString(_deliveryAddressKey, newAddress);
      }
    } catch (e, st) {
      print("Ошибка сохранения адреса: $e");
      state = AsyncValue.error(e, st);
    }
  }
}

// Провайдер для SavedAddressNotifier
final savedAddressProvider = StateNotifierProvider<SavedAddressNotifier, AsyncValue<String?>>((ref) {
  final prefsAsyncValue = ref.watch(sharedPreferencesInstanceProvider);

  return prefsAsyncValue.maybeWhen(
    data: (prefs) => SavedAddressNotifier(prefs),
    orElse: () => SavedAddressNotifier(DummyPreferences()), // Заглушка, пока prefs грузится
  );
});

// Класс-заглушка для SharedPreferences, чтобы избежать ошибок при первой загрузке
class DummyPreferences implements SharedPreferences {
  @override
  Future<bool> clear() async => true;
  @override
  Future<bool> commit() async => true;
  @override
  bool containsKey(String key) => false;
  @override
  Object? get(String key) => null;
  @override
  bool? getBool(String key) => null;
  @override
  double? getDouble(String key) => null;
  @override
  int? getInt(String key) => null;
  @override
  Set<String> getKeys() => {};
  @override
  String? getString(String key) => null;
  @override
  List<String>? getStringList(String key) => null;
  @override
  Future<void> reload() async {}
  @override
  Future<bool> remove(String key) async => true;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  Future<bool> setDouble(String key, double value) async => true;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  Future<bool> setStringList(String key, List<String> value) async => true;
} 