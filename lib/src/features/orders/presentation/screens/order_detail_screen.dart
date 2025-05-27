import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kursovoi/src/features/auth/application/auth_service.dart';
import 'package:kursovoi/src/features/orders/application/order_service.dart';
import 'package:kursovoi/src/features/orders/domain/order.dart' as domain;
import 'package:kursovoi/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:kursovoi/src/features/home/presentation/screens/home_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({required this.orderId, super.key});

  // Функция для отображения диалога смены статуса
  void _showStatusChangeDialog(BuildContext context, WidgetRef ref, domain.Order currentOrder) {
    domain.OrderStatus? selectedStatus = currentOrder.status;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Изменить статус заказа'),
              content: DropdownButton<domain.OrderStatus>(
                value: selectedStatus,
                isExpanded: true,
                items: domain.OrderStatus.values.map((domain.OrderStatus status) {
                  return DropdownMenuItem<domain.OrderStatus>(
                    value: status,
                    child: Text(_getOrderStatusText(status)),
                  );
                }).toList(),
                onChanged: (domain.OrderStatus? newValue) {
                  if (newValue != null) {
                     setStateDialog(() => selectedStatus = newValue);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedStatus != null && selectedStatus != currentOrder.status) {
                      try {
                        await ref.read(orderServiceProvider).updateOrderStatus(orderId, selectedStatus!);
                        Navigator.of(context).pop(); // Закрыть диалог
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Статус заказа обновлен на "${_getOrderStatusText(selectedStatus!)}"')),
                        );
                      } catch (e) {
                         Navigator.of(context).pop(); // Закрыть диалог
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Ошибка обновления статуса: $e')),
                        );
                      }
                    } else {
                       Navigator.of(context).pop(); // Просто закрыть, если статус не изменился
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(orderDetailProvider(orderId));
    final userRole = ref.watch(userRoleProvider).asData?.value; // Получаем роль пользователя
    final bool isAdmin = userRole == 'admin';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Детали заказа №${orderId.substring(0, 8)}...')),
      body: orderAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Ошибка загрузки заказа: $error')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Заказ не найден или у вас нет доступа.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Отображение статуса с возможностью изменения для админа
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: _buildDetailRow(theme, 'Статус:', _getOrderStatusText(order.status))),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Изменить статус',
                        onPressed: () => _showStatusChangeDialog(context, ref, order),
                      ),
                  ],
                ),
                _buildDetailRow(theme, 'Дата:', DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt.toDate())),
                _buildDetailRow(theme, 'Адрес доставки:', order.shippingAddress),
                _buildDetailRow(theme, 'Время доставки:', order.deliveryTime),
                _buildDetailRow(theme, 'Способ оплаты:', order.paymentMethod),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text('Состав заказа:', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text('${item.quantity} шт. x ${item.price.toStringAsFixed(2)} ₽'),
                      trailing: Text('${(item.quantity * item.price).toStringAsFixed(2)} ₽'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Итого: ', style: theme.textTheme.titleMedium),
                    Text(
                      '${order.totalAmount.toStringAsFixed(2)} ₽',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: theme.textTheme.titleMedium),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }

  String _getOrderStatusText(domain.OrderStatus status) {
    switch (status) {
      case domain.OrderStatus.pending: return 'Ожидает подтверждения';
      case domain.OrderStatus.processing: return 'В обработке';
      case domain.OrderStatus.shipped: return 'Отправлен';
      case domain.OrderStatus.delivered: return 'Доставлен';
      case domain.OrderStatus.cancelled: return 'Отменен';
      default: return 'Неизвестный статус';
    }
  }
} 