import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';

class CategorySelectionBottomSheet extends ConsumerWidget {
  const CategorySelectionBottomSheet({super.key});

  // TODO: Загружать категории/подкатегории динамически, а не хардкодить
  final Map<String, List<String>> _categories = const {
    "Молочные продукты": ["Молоко", "Сыр", "Йогурт", "Масло", "Сметана", "Творог"],
    "Мясо и птица": ["Говядина", "Свинина", "Курица", "Индейка", "Фарш", "Колбасы"],
    "Рыба и морепродукты": ["Рыба свежая", "Рыба замороженная", "Креветки", "Икра"],
    "Овощи и фрукты": ["Картофель", "Томаты", "Огурцы", "Яблоки", "Бананы", "Апельсины"],
    "Бакалея": ["Крупы", "Макароны", "Мука", "Сахар", "Соль", "Консервы", "Масло растительное"],
    "Заморозка": ["Пельмени", "Овощные смеси", "Мороженое", "Полуфабрикаты"],
    "Напитки": ["Вода", "Соки", "Газировка", "Чай", "Кофе"],
    "Хлеб и выпечка": ["Хлеб", "Булки", "Лаваш", "Печенье"],
    "Кондитерские изделия": ["Шоколад", "Конфеты", "Торты", "Пирожные"],
    "Детское питание": ["Пюре", "Смеси", "Каши"],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.only(top: 16.0),
           decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                ),
            ),
          child: Column(
            children: [
              // Заголовок и кнопка сброса
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text(
                        'Выберите категорию',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                         onPressed: () {
                              // Сброс фильтров
                             ref.read(productCategoryFilterProvider.notifier).state = null;
                             ref.read(productSubcategoryFilterProvider.notifier).state = null;
                             Navigator.pop(context); // Закрыть лист
                         },
                         child: const Text('Сбросить все'),
                      )
                  ],
                ),
              ),
              const Divider(height: 20, thickness: 1),
              // Список категорий
              Expanded(
                child: ListView.builder(
                  controller: scrollController, // Передаем контроллер для скролла внутри листа
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories.keys.elementAt(index);
                    final subcategories = _categories[category] ?? [];

                    return ExpansionTile(
                      title: Text(category, style: const TextStyle(fontWeight: FontWeight.w500)),
                      childrenPadding: const EdgeInsets.only(left: 16.0), // Отступ для подкатегорий
                      children: subcategories.map((subcategory) {
                        return ListTile(
                          title: Text(subcategory),
                          dense: true,
                          onTap: () {
                            ref.read(productCategoryFilterProvider.notifier).state = category;
                            ref.read(productSubcategoryFilterProvider.notifier).state = subcategory;
                            Navigator.pop(context); // Закрыть лист
                          },
                        );
                      }).toList(),
                      onExpansionChanged: (isExpanded) {
                         // Можно добавить логику, например, скролл к элементу
                      },
                      // initiallyExpanded: category == ref.read(productCategoryFilterProvider),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 