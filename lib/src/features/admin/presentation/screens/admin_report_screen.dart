import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/admin/application/admin_report_service.dart';
import 'package:intl/intl.dart';

class AdminReportScreen extends ConsumerWidget {
  const AdminReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsyncValue = ref.watch(adminReportProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчет по продажам'),
      ),
      body: reportAsyncValue.when(
        data: (reportData) {
          if (reportData.popularProducts.isEmpty && reportData.totalSales == 0) {
             return const Center(child: Text('Нет данных для отчета. Заказов пока не было.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Общая сумма продаж: ${currencyFormatter.format(reportData.totalSales)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Text(
                  'Популярные товары:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (reportData.popularProducts.isEmpty)
                  const Text('Нет проданных товаров.')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), // Отключаем скролл внутри ListView
                    itemCount: reportData.popularProducts.length,
                    itemBuilder: (context, index) {
                      final productId = reportData.popularProducts.keys.elementAt(index);
                      final quantity = reportData.popularProducts.values.elementAt(index);
                      final productName = reportData.productNames[productId] ?? 'Неизвестный товар';
                      return ListTile(
                        title: Text(productName),
                        trailing: Text('Продано: $quantity шт.'),
                      );
                    },
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Ошибка загрузки отчета: $error'),
        ),
      ),
    );
  }
} 