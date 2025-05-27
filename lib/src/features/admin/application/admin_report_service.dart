import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/orders/application/order_service.dart';
import 'package:kursovoi/src/features/orders/domain/order.dart' as app_order;
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';

// Класс для хранения данных отчета
class AdminReportData {
  final double totalSales;
  final Map<String, int> popularProducts; // productId -> quantitySold
  final Map<String, String> productNames; // productId -> productName

  AdminReportData({
    required this.totalSales,
    required this.popularProducts,
    required this.productNames,
  });
}

// Провайдер для данных отчета
final adminReportProvider = FutureProvider<AdminReportData>((ref) async {
  final orders = await ref.watch(allOrdersStreamProvider.future);
  final products = await ref.watch(rawProductsStreamProvider.future);


  double totalSales = 0.0;
  final Map<String, int> popularProductsCount = {};
  final Map<String, String> productNamesMap = {
    for (var product in products) product.id: product.name
  };

  for (final order in orders) {
    // print('[AdminReportProvider] Обработка заказа ID: ${order.id}, Статус: ${order.status.name}');

    if (order.status == app_order.OrderStatus.delivered) {

       totalSales += order.totalAmount;
       for (final item in order.items) {
         popularProductsCount.update(
           item.productId,
           (value) => value + item.quantity,
           ifAbsent: () => item.quantity,
         );
       }
    }
  }

  // print('[AdminReportProvider] Итоговая сумма продаж: $totalSales');
  // print('[AdminReportProvider] Популярные товары (до сортировки): $popularProductsCount');

  final sortedPopularProducts = Map.fromEntries(
      popularProductsCount.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value)),
  );


  return AdminReportData(
    totalSales: totalSales,
    popularProducts: sortedPopularProducts,
    productNames: productNamesMap,
  );
}); 