import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kursovoi/src/features/cart/application/cart_service.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';

class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({required this.product, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Проверяем наличие товара
    final bool isInStock = product.stockQuantity > 0;

    return Card(
      clipBehavior: Clip.antiAlias, // Обрезаем изображение по границам
      elevation: 2.0,
      // Оборачиваем Card в InkWell для обработки нажатия
      child: InkWell(
        onTap: () {
          // Переход на страницу деталей товара
          context.push('/product/${product.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Используем обычный Image.network с эффектом чернил
                    Material(
                      color: Colors.transparent,
                      child: Image.network(
                        product.imageUrl, 
                        fit: BoxFit.cover,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) {
                            return child;
                          }
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                            child: child,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(Icons.image_not_supported, 
                                color: Colors.grey[500], 
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Эффект чернил для брызг
                    Ink(
                      height: double.infinity,
                      width: double.infinity,
                    ),
                    // Обработчик нажатия
                    InkWell(
                      onTap: () => context.push('/product/${product.id}'),
                      child: Container(), // Пустой контейнер, чтобы InkWell сработал
                    ),
                  ],
                ),
              ),
            ),
            // Информация о товаре и кнопка
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Отображаем категорию
                    product.category.split('/').first,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                     maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isInStock ? 'В наличии' : 'Нет в наличии',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isInStock ? Colors.green.shade700 : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(2)} ₽', // Форматируем цену
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      // кнопка добавления в корзину
                      IconButton(
                        icon: Icon(
                          isInStock ? Icons.add_shopping_cart_outlined : Icons.remove_shopping_cart_outlined,
                          color: isInStock ? theme.colorScheme.primary : Colors.grey,
                        ),
                        onPressed: isInStock ? () {
                          ref.read(cartNotifierProvider.notifier).addItem(product.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} добавлен в корзину'),
                              duration: const Duration(seconds: 1), // Короткое уведомление
                            ),
                          );
                        } : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
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
} 