import 'dart:convert';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kursovoi/src/features/cart/domain/cart_item.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/auth/application/auth_service.dart';

// Ключ для сохранения в SharedPreferences
String _getCartPrefsKey(String? userId) => 'shoppingCart_${userId ?? 'guest'}';

// Провайдер для SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be obtained asynchronously');
});

// Провайдер для получения текущего пользователя
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).asData?.value?.uid;
});

// Асинхронный провайдер, который сначала загрузит SharedPreferences
final cartNotifierProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return CartNotifier(userId);
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  SharedPreferences? _prefs;
  final String? _userId;

  CartNotifier(this._userId) : super([]) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCart();
  }

  // Загрузка корзины из SharedPreferences
  void _loadCart() {
    if (_prefs == null) return;
    
    final cartString = _prefs?.getString(_getCartPrefsKey(_userId));
    if (cartString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(cartString);
        state = decodedList
            .map((itemJson) => CartItem.fromJson(itemJson as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Ошибка загрузки корзины из SharedPreferences: $e');
        state = [];
      }
    } else {
      state = [];
    }
  }

  // Сохранение корзины в SharedPreferences
  Future<void> _saveCart() async {
    if (_prefs == null) return;
    try {
      final List<Map<String, dynamic>> encodedList = state.map((item) => item.toJson()).toList();
      await _prefs?.setString(_getCartPrefsKey(_userId), jsonEncode(encodedList));
    } catch (e) {
      print('Ошибка сохранения корзины в SharedPreferences: $e');
    }
  }

  // Добавить товар в корзину или увеличить количество
  void addItem(String productId) {
    if (_prefs == null) {
      // Если SharedPreferences еще не загружен, добавляем в состояние напрямую
      final itemIndex = state.indexWhere((item) => item.productId == productId);
      if (itemIndex != -1) {
        final updatedItem = state[itemIndex].copyWith(quantity: state[itemIndex].quantity + 1);
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == itemIndex) updatedItem else state[i],
        ];
      } else {
        state = [...state, CartItem(productId: productId, quantity: 1)];
      }
      // Запускаем сохранение асинхронно
      _saveCart();
      return;
    }

    final itemIndex = state.indexWhere((item) => item.productId == productId);
    if (itemIndex != -1) {
      final updatedItem = state[itemIndex].copyWith(quantity: state[itemIndex].quantity + 1);
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == itemIndex) updatedItem else state[i],
      ];
    } else {
      state = [...state, CartItem(productId: productId, quantity: 1)];
    }
    _saveCart();
  }

  // Уменьшить количество товара или удалить, если количество = 1
  void removeItem(String productId) {
     final itemIndex = state.indexWhere((item) => item.productId == productId);
     if (itemIndex == -1) return; // Товара нет в корзине

     if (state[itemIndex].quantity > 1) {
       // Уменьшаем количество
       final updatedItem = state[itemIndex].copyWith(quantity: state[itemIndex].quantity - 1);
       state = [
        for (int i = 0; i < state.length; i++)
          if (i == itemIndex) updatedItem else state[i],
      ];
     } else {
       // Удаляем товар полностью (количество было 1)
       state = state.where((item) => item.productId != productId).toList();
     }
     _saveCart(); // Сохраняем после изменения
  }

  // Полностью удалить товар из корзины независимо от количества
  void removeProduct(String productId) {
      state = state.where((item) => item.productId != productId).toList();
      _saveCart(); // Сохраняем после изменения
  }

  // Очистить корзину
  void clearCart() {
    state = [];
    _saveCart(); // Сохраняем после изменения (пустой список)
  }
}


// Получить общее количество товаров в корзине (сумма quantity всех CartItem)
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartNotifierProvider);
  return cart.fold<int>(0, (sum, item) => sum + item.quantity);
});


// Провайдер для загрузки деталей товаров в корзине
final cartProductsDetailsProvider = FutureProvider<List<Product>>((ref) async {
  final cartItems = ref.watch(cartNotifierProvider);
  final productIds = cartItems.map((item) => item.productId).toList();

  if (productIds.isEmpty) {
    return []; // Возвращаем пустой список, если корзина пуста
  }

  final productService = ref.read(productServiceProvider);
  return await productService.getProductsByIds(productIds);
});

// Провайдер для расчета общей суммы корзины
final cartTotalProvider = Provider<double>((ref) {
  final cartItems = ref.watch(cartNotifierProvider);
  final productsDetailsData = ref.watch(cartProductsDetailsProvider).asData?.value;

  if (productsDetailsData == null) {
    return 0.0; // Возвращаем 0, если данные о товарах еще не загружены
  }

  final productsMap = {for (var p in productsDetailsData) p.id: p};
  double totalAmount = 0;
  for (var item in cartItems) {
    final product = productsMap[item.productId];
    if (product != null) {
      totalAmount += product.price * item.quantity;
    }
  }
  return totalAmount;
});
