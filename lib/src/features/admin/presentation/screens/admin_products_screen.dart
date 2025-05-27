import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';
import 'package:kursovoi/src/features/admin/application/admin_product_list_notifier.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';

class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, WidgetRef ref, Product product) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердите удаление'),
        content: Text('Вы уверены, что хотите удалить товар "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProductListProvider);
    final notifier = ref.read(adminProductListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление товарами'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Отчет по продажам',
            onPressed: () => context.push('/admin/report'),
          ),
          PopupMenuButton<AdminProductSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Сортировка',
            onSelected: (AdminProductSortOption result) {
              notifier.setSortOption(result);
            },
            itemBuilder: (BuildContext context) => AdminProductSortOption.values
                .map((option) => PopupMenuItem<AdminProductSortOption>(
                      value: option,
                      child: Text(option.displayName),
                    ))
                .toList(),
            initialValue: state.sortOption,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Добавить товар',
            onPressed: () => context.push('/admin/add-product'),
          ),
        ],
      ),
      body: _buildBody(context, ref, state, notifier),
      bottomNavigationBar: _buildPaginationControls(context, state, notifier),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AdminProductListState state, AdminProductListNotifier notifier) {
    if (state.isLoading && state.error == null) {
      if (state.products.isNotEmpty) {
         return Stack(
           children: [
             _buildProductList(context, ref, state, notifier),
             const Center(child: CircularProgressIndicator()),
           ],
         );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка загрузки: ${state.error}'),
            const SizedBox(height: 10),
            const Text('Пожалуйста, перезапустите приложение или попробуйте позже.'),
          ],
        ),
      );
    }

    if (state.products.isEmpty) {
      return const Center(child: Text('Товаров пока нет.'));
    }

    return _buildProductList(context, ref, state, notifier);
  }

  Widget _buildProductList(BuildContext context, WidgetRef ref, AdminProductListState state, AdminProductListNotifier notifier) {
    // Определяем, какой макет использовать в зависимости от размера и ориентации экрана
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrLarger = screenWidth > 600;
    
    // Для больших экранов и планшетов используем таблицу вместо списка
    if (isTabletOrLarger) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Название')),
              DataColumn(label: Text('Цена')),
              DataColumn(label: Text('Категория')),
              DataColumn(label: Text('Остаток')),
              DataColumn(label: Text('Действия')),
            ],
            rows: state.products.map((product) {
              return DataRow(
                cells: [
                  DataCell(Text(product.name)),
                  DataCell(Text('${product.price.toStringAsFixed(2)} ₽')),
                  DataCell(Text(product.category)),
                  DataCell(Text('${product.stockQuantity}')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                          tooltip: 'Редактировать',
                          onPressed: () {
                            context.push('/admin/edit-product/${product.id}');
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                          tooltip: 'Удалить',
                          onPressed: () async {
                            final confirm = await _showDeleteConfirmationDialog(context, ref, product);
                            if (confirm == true) {
                              try {
                                await ref.read(productServiceProvider).deleteProduct(product.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Товар "${product.name}" удален')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ошибка удаления: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }
    
    // Для мобильных устройств используем списочный вид
    return ListView.builder(
      itemCount: state.products.length,
      itemBuilder: (context, index) {
        final product = state.products[index];
        
        // Адаптивный вид элемента списка в зависимости от ориентации
        if (isLandscape) {
          // В горизонтальной ориентации показываем больше информации в строке
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                        Text('Категория: ${product.category}'),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Цена: ${product.price.toStringAsFixed(2)} ₽'),
                        Text('Остаток: ${product.stockQuantity}'),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                        tooltip: 'Редактировать',
                        onPressed: () {
                          context.push('/admin/edit-product/${product.id}');
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                        tooltip: 'Удалить',
                        onPressed: () async {
                          final confirm = await _showDeleteConfirmationDialog(context, ref, product);
                          if (confirm == true) {
                            try {
                              await ref.read(productServiceProvider).deleteProduct(product.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Товар "${product.name}" удален')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ошибка удаления: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        } else {
          // В вертикальной ориентации используем стандартный ListTile
          return ListTile(
            title: Text(product.name),
            subtitle: Text('Цена: ${product.price.toStringAsFixed(2)} ₽, Остаток: ${product.stockQuantity}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                  tooltip: 'Редактировать',
                  onPressed: () {
                    context.push('/admin/edit-product/${product.id}');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  tooltip: 'Удалить',
                  onPressed: () async {
                    final confirm = await _showDeleteConfirmationDialog(context, ref, product);
                    if (confirm == true) {
                      try {
                        await ref.read(productServiceProvider).deleteProduct(product.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Товар "${product.name}" удален')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка удаления: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget? _buildPaginationControls(BuildContext context, AdminProductListState state, AdminProductListNotifier notifier) {
    if (state.isLoading || state.error != null || state.totalPages <= 1) {
      return null;
    }

    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Предыдущая страница',
              onPressed: state.currentPage > 1
                  ? notifier.goToPreviousPage
                  : null,
            ),
            Text('Стр. ${state.currentPage} из ${state.totalPages}'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Следующая страница',
              onPressed: state.currentPage < state.totalPages
                  ? notifier.goToNextPage
                  : null,
            ),
          ],
        ),
      ),
    );
  }
} 