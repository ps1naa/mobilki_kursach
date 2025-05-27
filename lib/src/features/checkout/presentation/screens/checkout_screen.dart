import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/cart/application/cart_service.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/orders/application/order_service.dart';
import 'package:kursovoi/src/features/auth/application/auth_service.dart';
import 'package:kursovoi/src/features/orders/domain/order.dart' as domain;
import 'package:kursovoi/src/features/orders/domain/order_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kursovoi/src/features/address/application/address_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  final List<String> _deliveryTimes = [
    'Как можно скорее',
    '10:00 - 12:00',
    '12:00 - 14:00',
    '14:00 - 16:00',
    '16:00 - 18:00',
    '18:00 - 20:00',
  ];
  String? _selectedDeliveryTime;

  final List<String> _paymentMethods = [domain.paymentMethodCash, domain.paymentMethodCard];
  String? _selectedPaymentMethod;

  bool _isLoading = false;
  String? _errorMessage;

  bool _isAddressInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = _paymentMethods[0];
    _selectedDeliveryTime = _deliveryTimes[0];
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedPaymentMethod == null ||
        _selectedDeliveryTime == null) {
      setState(() {
        _errorMessage = 'Пожалуйста, заполните все поля и выберите опции';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cartItems = ref.read(cartNotifierProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productService = ref.read(productServiceProvider);
    final orderService = ref.read(orderServiceProvider);
    final userId = ref.read(authServiceProvider).currentUser?.uid;
    final firestore = FirebaseFirestore.instance; // Получаем экземпляр Firestore

    if (userId == null || cartItems.isEmpty) {
      setState(() {
        _errorMessage = 'Ошибка: пользователь не найден или корзина пуста.';
        _isLoading = false;
      });
      return;
    }

    try {
      final productIds = cartItems.map((item) => item.productId).toList();
      final productsSnapshots = await firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();
      
      final Map<String, Product> productsInStock = {};
      for (var doc in productsSnapshots.docs) {
          // Используем fromFirestore для десериализации
          productsInStock[doc.id] = Product.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
      }

      List<OrderItem> orderItems = [];
      double preliminaryTotalAmount = 0;
      String? stockErrorMessage;

      for (final cartItem in cartItems) {
         final product = productsInStock[cartItem.productId];
         if (product == null) {
             stockErrorMessage = 'Товар с ID ${cartItem.productId} не найден в базе данных.';
             break;
         }
         if (product.stockQuantity < cartItem.quantity) {
             stockErrorMessage = 'Недостаточно товара "${product.name}" на складе (в наличии: ${product.stockQuantity}, запрошено: ${cartItem.quantity}).';
             break;
         }
          // Формируем OrderItem сразу, если проверка пройдена
          orderItems.add(OrderItem(
             productId: cartItem.productId,
             productName: product.name,
             quantity: cartItem.quantity,
             price: product.price,
          ));
          preliminaryTotalAmount += product.price * cartItem.quantity;
      }

      if (stockErrorMessage != null) {
          setState(() {
              _errorMessage = stockErrorMessage;
              _isLoading = false;
          });
          return;
      }

     await firestore.runTransaction((transaction) async {
       // Создаем заказ внутри транзакции
       final newOrder = domain.Order(
         id: '', // Firestore ID будет сгенерирован
         userId: userId,
         items: orderItems,
         totalAmount: preliminaryTotalAmount,
         status: domain.OrderStatus.pending,
         shippingAddress: _addressController.text.trim(),
         createdAt: Timestamp.now(),
         deliveryTime: _selectedDeliveryTime!, 
         paymentMethod: _selectedPaymentMethod!, 
       );

       final newOrderRef = firestore.collection('orders').doc();
       
       transaction.set(newOrderRef.withConverter<domain.Order>(fromFirestore: domain.Order.fromFirestore, toFirestore: (order, _) => order.toFirestore()), newOrder);

       for (final item in orderItems) {
         final productRef = firestore.collection('products').doc(item.productId);
         transaction.update(productRef, {
           'stockQuantity': FieldValue.increment(-item.quantity)
         });
          // final productSnapshot = await transaction.get(productRef);
          // final currentStock = productSnapshot.data()?['stockQuantity'] as int? ?? 0;
          // if (currentStock < 0) { // Проверка, что не ушли в минус после вычитания
          //    throw FirebaseException(plugin: 'Firestore', code: 'out-of-stock', message: 'Недостаточно товара ${item.productName} во время транзакции.');
          // }
       }
     });

      cartNotifier.clearCart();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Заказ успешно оформлен!')),
         );
         context.go('/');
       }

   } catch (e) {
     if (mounted) {
       String displayError = 'Ошибка оформления заказа.';
       if (e is FirebaseException && e.code == 'out-of-stock') {
         displayError = e.message ?? 'Один из товаров закончился во время оформления.';
       } else {
          displayError = 'Ошибка оформления заказа: ${e.toString()}';
       }
       setState(() {
         _errorMessage = displayError;
       });
     }
   } finally {
     if (mounted) {
       setState(() {
         _isLoading = false;
       });
     }
   }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = ref.watch(cartTotalProvider);
    final savedAddressAsync = ref.watch(savedAddressProvider);

    if (!_isAddressInitialized && savedAddressAsync is AsyncData<String?>) {
      final savedAddress = savedAddressAsync.value;
      if (savedAddress != null && savedAddress.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted) {
             _addressController.text = savedAddress;
           }
        });
      }
      _isAddressInitialized = true; // Помечаем, что инициализация прошла
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Оформление заказа')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Адрес доставки',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Введите ваш адрес',
                  hintText: 'Город, улица, дом, квартира',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Пожалуйста, введите адрес доставки';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Text('Желаемое время доставки', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDeliveryTime,
                items: _deliveryTimes.map((String time) {
                  return DropdownMenuItem<String>(
                    value: time,
                    child: Text(time),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDeliveryTime = newValue;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Выберите время доставки',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Пожалуйста, выберите время' : null,
              ),
              const SizedBox(height: 24),

              Text('Способ оплаты', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                items: _paymentMethods.map((String method) {
                  return DropdownMenuItem<String>(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPaymentMethod = newValue;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Выберите способ оплаты',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Пожалуйста, выберите способ оплаты' : null,
              ),
              const SizedBox(height: 24),

              Text(
                'Сумма заказа: ${totalAmount.toStringAsFixed(2)} ₽',
                 style: Theme.of(context).textTheme.titleMedium,
              ),
               const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _placeOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Подтвердить заказ'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
} 