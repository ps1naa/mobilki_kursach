import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kursovoi/src/features/orders/domain/order_item.dart';

enum OrderStatus { pending, processing, shipped, delivered, cancelled }

const String paymentMethodCash = 'Наличными курьеру';
const String paymentMethodCard = 'Картой курьеру';

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final String shippingAddress;
  final Timestamp createdAt;
  final String deliveryTime;
  final String paymentMethod;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.shippingAddress,
    required this.createdAt,
    required this.deliveryTime,
    required this.paymentMethod,
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'items': items.map((item) => item.toJson()).toList(),
        'totalAmount': totalAmount,
        'status': status.name,
        'shippingAddress': shippingAddress,
        'createdAt': createdAt,
        'deliveryTime': deliveryTime,
        'paymentMethod': paymentMethod,
      };

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
     final data = snapshot.data()!;
     final itemsList = (data['items'] as List)
        .map((itemJson) => OrderItem.fromJson(itemJson as Map<String, dynamic>))
        .toList();
     final status = OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending, // Статус по умолчанию
     );

    return Order(
      id: snapshot.id,
      userId: data['userId'] as String,
      items: itemsList,
      totalAmount: (data['totalAmount'] as num).toDouble(),
      status: status,
      shippingAddress: data['shippingAddress'] as String,
      createdAt: data['createdAt'] as Timestamp,
      deliveryTime: data['deliveryTime'] as String? ?? 'Не указано',
      paymentMethod: data['paymentMethod'] as String? ?? 'Не указано',
    );
  }
} 