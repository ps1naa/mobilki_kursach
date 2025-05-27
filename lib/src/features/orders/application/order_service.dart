import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// Используем префикс для нашей модели Order
import 'package:kursovoi/src/features/orders/domain/order.dart' as domain;
import 'package:kursovoi/src/features/auth/application/auth_service.dart';

// Провайдер для OrderService
final orderServiceProvider = Provider<OrderService>((ref) {
  final firestore = FirebaseFirestore.instance;
  return OrderService(firestore);
});

class OrderService {
  final FirebaseFirestore _firestore;
  late final CollectionReference<domain.Order> _ordersRef;

  OrderService(this._firestore) {
    _ordersRef = _firestore.collection('orders').withConverter<domain.Order>(
          fromFirestore: domain.Order.fromFirestore,
          toFirestore: (domain.Order order, _) => order.toFirestore(),
        );
  }

  Future<DocumentReference<domain.Order>?> createOrder(domain.Order order) async {
    try {
      final docRef = await _ordersRef.add(order);
      return docRef;
    } catch (e) {
      print('Ошибка создания заказа: $e');
      return null;
    }
  }

  Stream<List<domain.Order>> getUserOrdersStream(String userId) {
    return _ordersRef
        .where('userId', isEqualTo: userId) // Фильтруем по ID пользователя
        .orderBy('createdAt', descending: true) // Сортируем по дате (сначала новые)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList())
        .handleError((error) {
           print("Ошибка получения потока заказов пользователя: $error");
           return <domain.Order>[];
        });
  }

  Stream<domain.Order?> getOrderByIdStream(String orderId) {
    return _ordersRef
        .doc(orderId)
        .snapshots()
        .map((snapshot) => snapshot.data())
        .handleError((error) {
           print("Ошибка получения потока заказа $orderId: $error");
           return null;
        });
  }

  Stream<List<domain.Order>> getAllOrdersStream() {
     return _ordersRef
        .orderBy('createdAt', descending: true) // Сортируем по дате
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList())
        .handleError((error) {
           print("Ошибка получения потока ВСЕХ заказов: $error");
           return <domain.Order>[];
        });
  }

  Future<void> updateOrderStatus(String orderId, domain.OrderStatus newStatus) async {
     await _ordersRef.doc(orderId).update({
       'status': newStatus.name
     });
  }
}

final userOrdersStreamProvider = StreamProvider<List<domain.Order>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orderService = ref.watch(orderServiceProvider);

  final userId = authState.asData?.value?.uid;

  if (userId != null) {
    return orderService.getUserOrdersStream(userId);
  } else {
    return Stream.value([]);
  }
});

final orderDetailProvider = StreamProvider.family<domain.Order?, String>((ref, orderId) {
  final authState = ref.watch(authStateProvider);
  final orderService = ref.watch(orderServiceProvider);

  final user = authState.asData?.value;
  if (user == null) {
      return Stream.value(null);
  }
  
  return orderService.getOrderByIdStream(orderId);
});

final allOrdersStreamProvider = StreamProvider<List<domain.Order>>((ref) {
   final orderService = ref.watch(orderServiceProvider);
   return orderService.getAllOrdersStream();
}); 