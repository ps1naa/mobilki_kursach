import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kursovoi/src/features/orders/application/order_service.dart';
import 'package:kursovoi/src/features/orders/domain/order.dart' as domain;
import 'package:kursovoi/src/features/profile/presentation/screens/profile_screen.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsyncValue = ref.watch(allOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление заказами'),
        // TODO: Добавить фильтр по статусу?
      ),
      body: ordersAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Ошибка: $error')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('Заказов пока нет.'));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                 margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                 child: ListTile(
                   title: Text('Заказ №${order.id.substring(0, 8)}...'),
                   subtitle: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt.toDate())}'),
                       Text('Пользователь: ${order.userId.substring(0, 6)}...'), // Показываем часть ID юзера
                       Text('Сумма: ${order.totalAmount.toStringAsFixed(2)} ₽'),
                       Text('Статус: ${_getOrderStatusText(order.status)}',
                           style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(order.status))),
                     ],
                   ),
                   trailing: const Icon(Icons.chevron_right),
                   onTap: () {
                     context.push('/order/${order.id}');
                   },
                 ),
              );
            },
          );
        },
      ),
    );
  }

  String _getOrderStatusText(domain.OrderStatus status) {
    switch (status) {
      case domain.OrderStatus.pending: return 'Ожидает';
      case domain.OrderStatus.processing: return 'В обработке';
      case domain.OrderStatus.shipped: return 'Отправлен';
      case domain.OrderStatus.delivered: return 'Доставлен';
      case domain.OrderStatus.cancelled: return 'Отменен';
      default: return 'Неизвестно';
    }
  }

  // Вспомогательная функция для цвета статуса
   Color _getStatusColor(domain.OrderStatus status) {
    switch (status) {
      case domain.OrderStatus.pending: return Colors.orange.shade700;
      case domain.OrderStatus.processing: return Colors.blue.shade700;
      case domain.OrderStatus.shipped: return Colors.purple.shade700;
      case domain.OrderStatus.delivered: return Colors.green.shade700;
      case domain.OrderStatus.cancelled: return Colors.red.shade700;
      default: return Colors.grey;
    }
  }
} 