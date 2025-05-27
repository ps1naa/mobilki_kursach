import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kursovoi/src/features/auth/application/auth_service.dart';
import 'package:kursovoi/src/features/products/presentation/widgets/product_card.dart';
import 'package:kursovoi/src/features/home/application/user_product_list_notifier.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/home/presentation/widgets/category_selection_bottom_sheet.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:kursovoi/src/features/products/domain/product.dart';

// Провайдер для сохранения состояния скролла и загруженных товаров
final homeScreenStateProvider = StateNotifierProvider<HomeScreenStateNotifier, HomeScreenState>((ref) {
  return HomeScreenStateNotifier();
});

class HomeScreenState {
  final double scrollPosition;
  final List<Product> loadedProducts;
  final bool isLoading;
  final bool hasMore;
  final String searchQuery;

  HomeScreenState({
    this.scrollPosition = 0.0,
    this.loadedProducts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.searchQuery = '',
  });

  HomeScreenState copyWith({
    double? scrollPosition,
    List<Product>? loadedProducts,
    bool? isLoading,
    bool? hasMore,
    String? searchQuery,
  }) {
    return HomeScreenState(
      scrollPosition: scrollPosition ?? this.scrollPosition,
      loadedProducts: loadedProducts ?? this.loadedProducts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class HomeScreenStateNotifier extends StateNotifier<HomeScreenState> {
  HomeScreenStateNotifier() : super(HomeScreenState());

  void updateScrollPosition(double position) {
    state = state.copyWith(scrollPosition: position);
  }

  void updateProducts(List<Product> products, bool hasMore) {
    state = state.copyWith(
      loadedProducts: products,
      hasMore: hasMore,
    );
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }
  
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

// провайдер для сохранения позиции скролла
final scrollPositionProvider = StateProvider<double>((ref) => 0.0);

final userRoleProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);

  // Получаем пользователя из текущего состояния AsyncValue
  final user = authState.asData?.value;

  if (user != null) {
    return await authService.getUserRole(user.uid);
  }
  return null;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  // Переменная для отслеживания текущего индекса баннера (для индикаторов)
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Восстанавливаем состояние после инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedState = ref.read(homeScreenStateProvider);
      
      // Восстанавливаем позицию скролла
      if (savedState.scrollPosition > 0) {
        _scrollController.jumpTo(savedState.scrollPosition);
      }
      
      // Восстанавливаем состояние поиска
      final savedSearchQuery = savedState.searchQuery;
      if (savedSearchQuery.isNotEmpty) {
        // Восстанавливаем значение в провайдере поиска, который будет использоваться для фильтрации товаров
        ref.read(productSearchQueryProvider.notifier).state = savedSearchQuery;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentPosition = _scrollController.position.pixels;
    ref.read(homeScreenStateProvider.notifier).updateScrollPosition(currentPosition);
    
    if (currentPosition >= _scrollController.position.maxScrollExtent - 200 &&
        ref.read(userProductListProvider).hasMore &&
        !ref.read(userProductListProvider).isLoading)
    {
      ref.read(userProductListProvider.notifier).fetchNextPage().then((_) {
        // После загрузки восстанавливаем позицию
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.jumpTo(currentPosition);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRoleAsyncValue = ref.watch(userRoleProvider);
    final homeScreenState = ref.watch(homeScreenStateProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);
    
    // Сохраняем текущее состояние поиска для будущего восстановления
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeScreenStateProvider.notifier).updateSearchQuery(searchQuery);
    });
    
    return userRoleAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Ошибка загрузки роли: $error'),
      ),
      data: (role) {
        if (role == 'admin') {
          return Scaffold(
             appBar: AppBar(
               title: const Text('Панель Админа'),
               actions: [ _LogoutButton() ],
             ),
             body: _buildAdminDashboard(context, ref),
          );
        } else {
          return _buildUserProductLayout(context, ref);
        }
      },
    );
  }

  // Панель администратора
  Widget _buildAdminDashboard(BuildContext context, WidgetRef ref) {
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Растягиваем кнопки
          children: [
            const Text('Добро пожаловать, Администратор!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            // Кнопка Управления Товарами
            ElevatedButton.icon(
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Управление товарами'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => context.push('/admin/products'),
            ),
             const SizedBox(height: 15),
             ElevatedButton.icon(
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Добавить новый товар'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => context.push('/admin/add-product'),
            ),
             const SizedBox(height: 15),
             // TODO: Кнопка Управления Заказами
              ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Управление заказами'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () {
                 // Переход на новый маршрут
                 context.push('/admin/orders'); 
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProductLayout(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userProductListProvider);
    final notifier = ref.read(userProductListProvider.notifier);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Используем Stack, чтобы разместить кнопку поверх списка
    return Stack(
      children: [
        // Основной контент с полной прокруткой
        SafeArea(
          child: CustomScrollView(
            controller: _scrollController, // Используем основной контроллер для всего скролла
            slivers: [
              // Общий макет для любой ориентации
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Карусель баннеров для любой ориентации
                    _buildBannerCarousel(context),
                    const SizedBox(height: 16),
                    // Шорткаты категорий
                    _buildCategoryShortcutsPlaceholder(context, ref),
                    const SizedBox(height: 16),
                    // Заголовок раздела товаров
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Каталог товаров",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Список товаров с пагинацией
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: _buildPaginatedProductGridSliver(context, ref, state, notifier),
              ),
            ],
          ),
        ),

        // Кнопка возврата к началу списка
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            heroTag: 'scrollToTopButton',
            mini: true,
            elevation: 4,
            onPressed: () {
              // Плавно прокручиваем к началу списка
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
            tooltip: 'Наверх',
            child: const Icon(Icons.keyboard_arrow_up),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCarousel(BuildContext context) {
    final List<String> bannerImageUrls = [
      'https://thumbs.dreamstime.com/b/supermarket-shopping-cart-groceries-store-aisle-copy-space-banner-concept-grocery-315608951.jpg',
      'https://previews.123rf.com/images/kritchanut/kritchanut1811/kritchanut181100357/114004200-black-shopping-basket-full-of-food-and-groceries-in-suppermarket-aisle-banner-background-with-copy.jpg',
      'https://media.istockphoto.com/id/1051652114/photo/food-and-groceries-in-shopping-basket-on-kitchen-table-banner-background.jpg?s=1024x1024&w=is&k=20&c=YwTQ45EM5YwbxhsJfwOOkwhXOmYkiog8huLoEEwuOuY=',
    ];

    if (bannerImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Получаем размеры экрана для адаптивности
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Адаптивная высота карусели
    final double carouselHeight = 150; // Фиксированная высота как была изначально

    return Column(
      children: [
        cs.CarouselSlider.builder(
          itemCount: bannerImageUrls.length,
          itemBuilder: (context, index, realIdx) {
            final url = bannerImageUrls[index];
            return _buildBannerItem(context, url);
          },
          options: cs.CarouselOptions(
            height: carouselHeight,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            viewportFraction: 0.9, // Стандартное значение как было
            enlargeCenterPage: true,
            aspectRatio: 16 / 9,
            onPageChanged: (index, reason) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
          ),
        ),
        // Индикаторы карусели
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: bannerImageUrls.asMap().entries.map((entry) {
            return GestureDetector(
              child: Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black)
                        .withOpacity(_currentBannerIndex == entry.key ? 0.9 : 0.4)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Виджет для одного элемента баннера
  Widget _buildBannerItem(BuildContext context, String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(12.0)),
        child: RepaintBoundary(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: 1000.0, // Большая ширина, чтобы Image заполнил контейнер
            // Обработка ошибки загрузки
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade300,
              child: const Center(child: Icon(Icons.error_outline, color: Colors.red)),
            ),
            // Индикатор загрузки (опционально)
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Заглушка для шорткатов категорий
  Widget _buildCategoryShortcutsPlaceholder(BuildContext context, WidgetRef ref) {
    final categories = [
        'Молочные продукты', 
        'Мясо и птица', 
        'Овощи и фрукты', 
        'Бакалея', 
        'Напитки', 
        'Заморозка',
        'Еще...'
    ]; 
    final selectedCategory = ref.watch(productCategoryFilterProvider);
    
    // Получаем ориентацию для адаптивности
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // В горизонтальной ориентации можем показать больше категорий в одном ряду
    final double categoryHeight = isLandscape ? 36 : 40;

    return SizedBox(
      height: categoryHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          
          VoidCallback? onTap = () {
            if (category == 'Еще...') {
               showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                     borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => const CategorySelectionBottomSheet(),
               );
            } else if (isSelected) {
              ref.read(productCategoryFilterProvider.notifier).state = null;
              ref.read(productSubcategoryFilterProvider.notifier).state = null;
            } else {
               ref.read(productCategoryFilterProvider.notifier).state = category;
               ref.read(productSubcategoryFilterProvider.notifier).state = null;
            }
          };

          if (category == 'Еще...') {
             return ActionChip(
               avatar: const Icon(Icons.arrow_drop_down, size: 18),
               label: Text(category),
               onPressed: onTap,
               backgroundColor: Colors.grey.shade200,
             );
          }

          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (selected) {
              if (onTap != null) onTap(); 
            },
            selectedColor: Theme.of(context).primaryColor,
            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          );
        },
      ),
    );
  }

  // --- Новый метод для построения сетки товаров как Sliver ---
  Widget _buildPaginatedProductGridSliver(BuildContext context, WidgetRef ref, UserProductListState state, UserProductListNotifier notifier) {
    // Обработка ошибок и пустых состояний
    if (state.products.isEmpty && state.error != null && !state.isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: ${state.error}'),
              ElevatedButton(onPressed: notifier.fetchFirstPage, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    
    if (state.products.isEmpty && state.isLoadingFirstPage) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (state.products.isEmpty && !state.isLoading && !state.hasMore) {
      return const SliverFillRemaining(
        child: Center(child: Text('Товаров по вашему запросу не найдено.')),
      );
    }

    // Обновляем состояние в провайдере после построения виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeScreenStateProvider.notifier).updateProducts(state.products, state.hasMore);
      ref.read(homeScreenStateProvider.notifier).setLoading(state.isLoading);
    });

    // Получаем размеры экрана для адаптивности
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Определяем количество колонок в зависимости от размера экрана и ориентации
    int crossAxisCount;
    double childAspectRatio;
    
    if (isLandscape) {
      // В горизонтальной ориентации увеличиваем количество колонок
      if (screenWidth < 600) {
        crossAxisCount = 3; // Телефон в горизонтальной ориентации
        childAspectRatio = 0.8;
      } else if (screenWidth < 900) {
        crossAxisCount = 4; // Планшет малого размера
        childAspectRatio = 0.85;
      } else {
        crossAxisCount = 5; // Планшет большого размера или десктоп
        childAspectRatio = 0.9;
      }
    } else {
      // В вертикальной ориентации
      if (screenWidth < 360) {
        crossAxisCount = 1; // Очень маленький экран
        childAspectRatio = 0.9;
      } else if (screenWidth < 600) {
        crossAxisCount = 2; // Телефон
        childAspectRatio = 0.7;
      } else if (screenWidth < 900) {
        crossAxisCount = 3; // Планшет малого размера
        childAspectRatio = 0.8;
      } else {
        crossAxisCount = 4; // Планшет большого размера или десктоп
        childAspectRatio = 0.85;
      }
    }

    // Отображение сетки как SliverGrid
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Индикатор загрузки в конце списка
          if (index == state.products.length && state.hasMore) {
            // Загружаем следующую страницу, когда дошли до конца
            if (!state.isLoadingNextPage) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                notifier.fetchNextPage();
              });
            }
            return state.isLoadingNextPage
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox.shrink();
          }

          // Выход за пределы (на всякий случай)
          if (index >= state.products.length) return const SizedBox.shrink();

          final product = state.products[index];
          return ProductCard(product: product);
        },
        childCount: state.products.length + (state.hasMore ? 1 : 0),
      ),
    );
  }

  // Сохраняем оригинальный метод для обратной совместимости, теперь он вызывает только для просмотра
  Widget _buildPaginatedProductGrid(BuildContext context, WidgetRef ref, UserProductListState state, UserProductListNotifier notifier) {
    // Обработка ошибок и пустых состояний
    if (state.products.isEmpty && state.error != null && !state.isLoading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Ошибка: ${state.error}'),
          ElevatedButton(onPressed: notifier.fetchFirstPage, child: const Text('Повторить')),
        ]),
      );
    }
    if (state.products.isEmpty && state.isLoadingFirstPage) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.products.isEmpty && !state.isLoading && !state.hasMore) {
      return const Center(child: Text('Товаров по вашему запросу не найдено.'));
    }

    // Обновляем состояние в провайдере после построения виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeScreenStateProvider.notifier).updateProducts(state.products, state.hasMore);
      ref.read(homeScreenStateProvider.notifier).setLoading(state.isLoading);
    });

    // Получаем размеры экрана для адаптивности
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Определяем количество колонок в зависимости от размера экрана и ориентации
    int crossAxisCount;
    double childAspectRatio;
    
    if (isLandscape) {
      // В горизонтальной ориентации увеличиваем количество колонок
      if (screenWidth < 600) {
        crossAxisCount = 3; // Телефон в горизонтальной ориентации
        childAspectRatio = 0.8;
      } else if (screenWidth < 900) {
        crossAxisCount = 4; // Планшет малого размера
        childAspectRatio = 0.85;
      } else {
        crossAxisCount = 5; // Планшет большого размера или десктоп
        childAspectRatio = 0.9;
      }
    } else {
      // В вертикальной ориентации
      if (screenWidth < 360) {
        crossAxisCount = 1; // Очень маленький экран
        childAspectRatio = 0.9;
      } else if (screenWidth < 600) {
        crossAxisCount = 2; // Телефон
        childAspectRatio = 0.7;
      } else if (screenWidth < 900) {
        crossAxisCount = 3; // Планшет малого размера
        childAspectRatio = 0.8;
      } else {
        crossAxisCount = 4; // Планшет большого размера или десктоп
        childAspectRatio = 0.85;
      }
    }

    // Отображение сетки
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: state.products.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Индикатор загрузки в конце списка
        if (index == state.products.length && state.hasMore) {
          return state.isLoadingNextPage
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        // Выход за пределы (на всякий случай)
        if (index >= state.products.length) return const SizedBox.shrink();

        final product = state.products[index];
        return ProductCard(product: product);
      },
    );
  }
}

// Кнопка выхода (без изменений)
class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
     final authService = ref.read(authServiceProvider);
    return IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () async {
              await authService.signOut();
            },
          );
  }
} 