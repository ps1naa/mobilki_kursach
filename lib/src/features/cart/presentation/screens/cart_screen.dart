import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kursovoi/src/features/cart/application/cart_service.dart';
import 'package:kursovoi/src/features/cart/domain/cart_item.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:intl/intl.dart';
import 'package:kursovoi/src/features/address/application/address_service.dart';

final cartProductsDetailsProvider = FutureProvider<List<Product>>((ref) async {
  final cartItems = ref.watch(cartNotifierProvider);
  final productIds = cartItems.map((item) => item.productId).toList();

  if (productIds.isEmpty) {
    return []; // Возвращаем пустой список, если корзина пуста
  }

  final productService = ref.read(productServiceProvider);
  return await productService.getProductsByIds(productIds);
});

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartNotifierProvider);
    final totalAmount = ref.watch(cartTotalProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productsDetailsAsync = ref.watch(cartProductsDetailsProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');
    final uniqueItemCount = cartItems.length;
    final savedAddressAsync = ref.watch(savedAddressProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          cartItems.isEmpty
            ? 'Корзина пуста'
            : 'Товаров: $uniqueItemCount на ${currencyFormatter.format(totalAmount)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Очистить корзину',
              onPressed: () => _confirmClearCart(context, ref),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                savedAddressAsync.when(
                   data: (address) => _buildDeliveryInfo(context, ref, address),
                   loading: () => const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                   ),
                   error: (err, stack) => Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Center(child: Text('Ошибка загрузки адреса: $err')),
                   ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ваш заказ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                // --- Список товаров --- 
                Container(
                  height: MediaQuery.of(context).orientation == Orientation.landscape 
                      ? MediaQuery.of(context).size.height * 0.4
                      : null,
                  child: productsDetailsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('Ошибка загрузки деталей: $error')),
                    data: (productsDetails) {
                      if (cartItems.isEmpty) {
                        return const Center(child: Text('Ваша корзина пуста.'));
                      }
                      final productsMap = {for (var p in productsDetails) p.id: p};

                      return ListView.separated(
                        shrinkWrap: MediaQuery.of(context).orientation == Orientation.portrait,
                        physics: MediaQuery.of(context).orientation == Orientation.portrait 
                            ? const NeverScrollableScrollPhysics() 
                            : const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        itemCount: cartItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final cartItem = cartItems[index];
                          final product = productsMap[cartItem.productId];
                          final quantity = cartItem.quantity;

                          if (product == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                 print('Удаление отсутствующего товара ${cartItem.productId} из корзины');
                                 cartNotifier.removeProduct(cartItem.productId);
                            });
                            return ListTile(title: Text('Товар ${cartItem.productId} не найден...'));
                          }
                          return _buildCartItemCard(context, ref, product, quantity);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // --- Нижняя кнопка "Оформить заказ" --- 
      bottomNavigationBar: cartItems.isEmpty
          ? null // Не показываем кнопку, если корзина пуста
          : BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text('Оформить заказ (${currencyFormatter.format(totalAmount)})'),
                  style: ElevatedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),

                  ),
                  onPressed: () {
                    context.push('/checkout');
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildDeliveryInfo(BuildContext context, WidgetRef ref, String? currentAddress) {
    final bool hasAddress = currentAddress != null && currentAddress.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(Icons.local_shipping_outlined, color: Colors.green.shade700),
        title: Text(
          hasAddress ? currentAddress : 'Адрес доставки не указан',
          style: hasAddress 
             ? const TextStyle(fontWeight: FontWeight.bold) 
             : TextStyle(color: Colors.grey.shade600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: hasAddress ? const Text('Нажмите, чтобы изменить') : null,
        trailing: Icon(hasAddress ? Icons.edit_outlined : Icons.add_circle_outline, size: 20),
        onTap: () {
          // Показываем диалог для ввода/изменения адреса
          _showAddressInputDialog(context, ref, currentAddress);
        },
      ),
    );
  }

  // --- Диалог для ввода/изменения адреса ---
  Future<void> _showAddressInputDialog(BuildContext context, WidgetRef ref, String? initialAddress) async {
    final addressController = TextEditingController(text: initialAddress);
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(initialAddress == null || initialAddress.isEmpty 
              ? 'Добавить адрес доставки' 
              : 'Изменить адрес доставки'),
          content: Form(
             key: formKey,
             child: TextFormField(
                controller: addressController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                   hintText: 'Введите ваш адрес...',
                   border: OutlineInputBorder(),
                ),
                validator: (value) {
                   if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите адрес';
                   }
                   return null;
                },
             ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Сохранить'),
              onPressed: () {
                 if (formKey.currentState!.validate()) {
                    final newAddress = addressController.text.trim();
                    ref.read(savedAddressProvider.notifier).updateAddress(newAddress);
                    Navigator.of(dialogContext).pop(); // Закрываем диалог
                 }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCartItemCard(BuildContext context, WidgetRef ref, Product product, int quantity) {
     final currencyFormatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');
     final cartNotifier = ref.read(cartNotifierProvider.notifier);

     return Card(
       elevation: 1,
       margin: EdgeInsets.zero,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
       child: Padding(
         padding: const EdgeInsets.all(8.0),
         child: Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Изображение товара
             ClipRRect(
               borderRadius: BorderRadius.circular(4.0),
               child: RepaintBoundary(
                 child: Image.network(
                   product.imageUrl,
                   width: 60,
                   height: 60,
                   fit: BoxFit.cover,
                   errorBuilder: (context, error, stackTrace) =>
                     Container(width: 60, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
                 ),
               ),
             ),
             const SizedBox(width: 12),
             // Информация о товаре и кнопки
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     product.name,
                     style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 8),
                   // Цена товара (за все количество)
                   Text(
                     currencyFormatter.format(product.price * quantity),
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                   ),
                   const SizedBox(height: 8),
                   // Кнопки управления количеством
                   Row(
                     children: [
                       _buildQuantityButton(
                         onPressed: () {
                           if (quantity > 1) {
                             cartNotifier.removeItem(product.id);
                           } else {
                             // Покажем подтверждение удаления, если осталась 1 шт
                             _showRemoveConfirmation(context, ref, product);
                           }
                         },
                         icon: Icons.remove,
                         color: Colors.red.shade600,
                       ),
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 12.0),
                         child: Text(
                           '$quantity шт',
                           style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                         ),
                       ),
                       _buildQuantityButton(
                         onPressed: () => cartNotifier.addItem(product.id),
                         icon: Icons.add,
                         color: Colors.green.shade600,
                       ),
                       const Spacer(),
                       // Кнопка удаления всего товара
                       _buildQuantityButton(
                         onPressed: () => _showRemoveConfirmation(context, ref, product),
                         icon: Icons.delete_outline,
                         color: Colors.grey.shade700,
                       ),
                     ],
                   ),
                 ],
               ),
             ),
           ],
         ),
       ),
     );
  }

  Widget _buildQuantityButton({
    required VoidCallback onPressed, 
    required IconData icon, 
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  // Диалог подтверждения удаления товара
  Future<void> _showRemoveConfirmation(BuildContext context, WidgetRef ref, Product product) async {
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Удалить товар'),
          content: Text('Вы уверены, что хотите удалить ${product.name} из корзины?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Удалить'),
              onPressed: () {
                cartNotifier.removeProduct(product.id);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Диалог подтверждения очистки корзины
  Future<void> _confirmClearCart(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Очистить корзину'),
          content: const Text('Вы уверены, что хотите удалить все товары из корзины?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Очистить'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      ref.read(cartNotifierProvider.notifier).clearCart();
    }
  }
} 