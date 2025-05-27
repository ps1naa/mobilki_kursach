import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/home/presentation/screens/home_screen.dart';

class UserShell extends ConsumerStatefulWidget {
  final Widget child;

  const UserShell({required this.child, super.key});

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> {
  int _currentIndex = 0;
  bool _isSearching = false; // Флаг для отображения поля поиска
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Слушатель для обновления провайдера поиска с debounce
    _searchController.addListener(() {
       ref.read(productSearchQueryProvider.notifier).state = _searchController.text;
    });
    
    // Восстанавливаем состояние поиска при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final searchQuery = ref.read(homeScreenStateProvider).searchQuery;
      if (searchQuery.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _searchController.text = searchQuery;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Вычисляем индекс на основе текущего маршрута
  void _updateCurrentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/cart')) {
      _currentIndex = 1;
    } else if (location.startsWith('/profile')) {
      _currentIndex = 2;
    } else {
      _currentIndex = 0; // По умолчанию - каталог товаров
    }
  }

  void _onItemTapped(int index, BuildContext context) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
      
      if (_isSearching) {
        _isSearching = false;
        // Сохраняем текущий поисковый запрос в homeScreenStateProvider
        ref.read(homeScreenStateProvider.notifier).updateSearchQuery(_searchController.text);
      }
    });

    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/cart'); break;
      case 2: context.go('/profile'); break;
    }
  }

  // BottomSheet с фильтрами
  void _showFilterSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FilterSortBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateCurrentIndex(context);

    final bool showSearchFilterButtons = _currentIndex == 0;

    // Динамический заголовок AppBar или поле поиска
    Widget appBarTitle = Text('Каталог');
    if (_currentIndex == 1) {
      appBarTitle = const Text('Корзина');
    } else if (_currentIndex == 2) {
      appBarTitle = const Text('Профиль');
    }
    if (_isSearching && _currentIndex == 0) {
       appBarTitle = TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
             hintText: 'Поиск товаров...',
             border: InputBorder.none,
             hintStyle: TextStyle(color: Colors.black.withOpacity(0.6)), 
          ),
          style: TextStyle(
             color: Colors.black, 
             fontSize: Theme.of(context).primaryTextTheme.titleLarge?.fontSize,
             fontWeight: Theme.of(context).primaryTextTheme.titleLarge?.fontWeight,
          ),
          cursorColor: Colors.black,
       );
    }

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle,
        centerTitle: true,
        actions: [ // Кнопки действий в AppBar
            if (showSearchFilterButtons)
              // Кнопка Поиск / Отмена поиска
              IconButton(
                 icon: Icon(_isSearching ? Icons.close : Icons.search),
                 tooltip: _isSearching ? 'Закрыть поиск' : 'Поиск',
                 onPressed: () {
                     setState(() {
                        _isSearching = !_isSearching;
                        // Если закрываем поиск, очищаем запрос полностью
                        if (!_isSearching) {
                            _searchController.clear();
                            ref.read(productSearchQueryProvider.notifier).state = '';
                            // Очищаем также сохраненный запрос
                            ref.read(homeScreenStateProvider.notifier).updateSearchQuery('');
                        }
                        // Если открываем поиск и есть сохраненный запрос, восстанавливаем его
                        if (_isSearching) {
                          final savedQuery = ref.read(homeScreenStateProvider).searchQuery;
                          if (savedQuery.isNotEmpty && _searchController.text.isEmpty) {
                            _searchController.text = savedQuery;
                            ref.read(productSearchQueryProvider.notifier).state = savedQuery;
                          }
                        }
                     });
                 },
              ),
            if (showSearchFilterButtons)
             // Кнопка Фильтры/Сортировка
             IconButton(
               icon: const Icon(Icons.filter_list),
               tooltip: 'Фильтры и сортировка',
               onPressed: () => _showFilterSortSheet(context),
             ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Каталог',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Корзина',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: (index) => _onItemTapped(index, context),
      ),
    );
  }
}

class FilterSortBottomSheet extends ConsumerStatefulWidget {
  const FilterSortBottomSheet({super.key});

  @override
  ConsumerState<FilterSortBottomSheet> createState() => _FilterSortBottomSheetState();
}

class _FilterSortBottomSheetState extends ConsumerState<FilterSortBottomSheet> {
  ProductSortCriteria _selectedSortCriteria = ProductSortCriteria.none;
  String? _selectedCategory;
  String? _selectedSubcategory;
  List<String> _currentSubcategories = [];

  // TODO: Вынести категории в общее место (константы или провайдер)
  final Map<String, List<String>> _categories = {
    'Молочные продукты': ['Молоко', 'Сыр', 'Творог', 'Йогурт', 'Сметана'],
    'Фрукты': ['Яблоки', 'Бананы', 'Апельсины', 'Виноград'],
    'Овощи': ['Картофель', 'Морковь', 'Лук', 'Помидоры', 'Огурцы'],
    'Хлебобулочные изделия': ['Хлеб', 'Батон', 'Булочки'],
  };

  @override
  void initState() {
    super.initState();
    _selectedSortCriteria = ref.read(productSortProvider);
    _selectedCategory = ref.read(productCategoryFilterProvider);
    _selectedSubcategory = ref.read(productSubcategoryFilterProvider);
    if (_selectedCategory != null) {
      _currentSubcategories = _categories[_selectedCategory] ?? [];
    }
  }

  // Функция сброса фильтров и сортировки
  void _resetFilters() {
     // Сбрасываем локальное состояние
    setState(() {
       _selectedCategory = null;
       _selectedSubcategory = null;
       _currentSubcategories = [];
       _selectedSortCriteria = ProductSortCriteria.none;
    });
    // Сбрасываем глобальные провайдеры
    ref.read(productCategoryFilterProvider.notifier).state = null;
    ref.read(productSubcategoryFilterProvider.notifier).state = null;
    ref.read(productSortProvider.notifier).state = ProductSortCriteria.none;
    Navigator.pop(context); // Закрываем BottomSheet
  }

  // Функция применения фильтров и сортировки
  void _applyFilters() {
     // Обновляем глобальные провайдеры значениями из локального состояния
    ref.read(productCategoryFilterProvider.notifier).state = _selectedCategory;
    ref.read(productSubcategoryFilterProvider.notifier).state = _selectedSubcategory;
    ref.read(productSortProvider.notifier).state = _selectedSortCriteria;
    Navigator.pop(context); // Закрываем BottomSheet
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, MediaQuery.of(context).viewInsets.bottom + 16.0),
      child: SingleChildScrollView( // Добавляем прокрутку на случай доисторических телефонов
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Фильтры и Сортировка', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),

            // Фильтр по категориям
            Text('Категория', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
             DropdownButtonFormField<String>(
                value: _selectedCategory,
                hint: const Text('Все категории'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _categories.keys.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                    _selectedSubcategory = null; // Сбрасываем подкатегорию при смене основной
                    _currentSubcategories = _categories[newValue] ?? [];
                  });
                },
              ),
              const SizedBox(height: 16),
              // Фильтр по подкатегориям
               DropdownButtonFormField<String>(
                value: _selectedSubcategory,
                hint: const Text('Все подкатегории'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                // Блокируем, если не выбрана основная категория
                disabledHint: _selectedCategory == null ? const Text('Сначала выберите категорию') : null,
                items: _currentSubcategories.map((String subcategory) {
                  return DropdownMenuItem<String>(
                    value: subcategory,
                    child: Text(subcategory),
                  );
                }).toList(),
                onChanged: _selectedCategory == null ? null : (String? newValue) {
                  setState(() {
                    _selectedSubcategory = newValue;
                  });
                },
              ),
              const SizedBox(height: 24),

            // Сортировка
            Text('Сортировка', style: theme.textTheme.titleMedium),
            RadioListTile<ProductSortCriteria>(
              title: const Text('По умолчанию'),
              value: ProductSortCriteria.none,
              groupValue: _selectedSortCriteria,
               contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _selectedSortCriteria = value!),
            ),
             RadioListTile<ProductSortCriteria>(
              title: const Text('Цена: по возрастанию'),
              value: ProductSortCriteria.priceAsc,
              groupValue: _selectedSortCriteria,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _selectedSortCriteria = value!),
            ),
             RadioListTile<ProductSortCriteria>(
              title: const Text('Цена: по убыванию'),
              value: ProductSortCriteria.priceDesc,
              groupValue: _selectedSortCriteria,
               contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _selectedSortCriteria = value!),
            ),
             RadioListTile<ProductSortCriteria>(
              title: const Text('Название: А-Я'),
              value: ProductSortCriteria.nameAsc,
              groupValue: _selectedSortCriteria,
               contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _selectedSortCriteria = value!),
            ),
            const SizedBox(height: 24),

            // Кнопки управления
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                   onPressed: _resetFilters,
                   child: const Text('Сбросить'),
                ),
                 ElevatedButton(
                    onPressed: _applyFilters,
                    child: const Text('Применить'),
                 ),
              ],
            )
          ],
        ),
      ),
    );
  }
} 