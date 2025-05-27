import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/cart/application/cart_service.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({required this.productId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsyncValue = ref.watch(productDetailProvider(productId));
    final theme = Theme.of(context);

    // Используем when для всего Scaffold, чтобы AppBar создавался с нужными данными
    return productAsyncValue.when(
      loading: () => Scaffold(
          appBar: AppBar(title: const Text('Загрузка...')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(child: Text('Ошибка загрузки товара: $error')),
      ),
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ошибка')),
             body: const Center(child: Text('Товар не найден.')),
          );
        }
        
        // Если товар найден, билдим Scaffold с AppBar и телом
        final bool isInStock = product.stockQuantity > 0;
        return Scaffold(
          appBar: AppBar(title: Text(product.name)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 // Большое изображение товара
                AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (context, error, stack) => const Center(
                        child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  product.category.replaceAll('/', ' > '),
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                 // Статус наличия
                 Text(
                    isInStock ? 'В наличии (${product.stockQuantity} шт.)' : 'Нет в наличии',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isInStock ? Colors.green.shade700 : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 16),
                // Цена
                Text(
                  '${product.price.toStringAsFixed(2)} ₽',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Кнопка добавления в корзину
                ElevatedButton.icon(
                   icon: Icon(isInStock ? Icons.add_shopping_cart : Icons.remove_shopping_cart),
                   label: Text(isInStock ? 'В корзину' : 'Нет в наличии'),
                   style: ElevatedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     backgroundColor: isInStock ? theme.colorScheme.primary : Colors.grey,
                     foregroundColor: isInStock ? theme.colorScheme.onPrimary : Colors.white,
                   ),
                   onPressed: isInStock ? () {
                        ref.read(cartNotifierProvider.notifier).addItem(product.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} добавлен в корзину'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      } : null,
                ),
                const SizedBox(height: 24),
                // Описание товара
                Text('Описание', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(product.description, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        );
      },
    );
  }
} 