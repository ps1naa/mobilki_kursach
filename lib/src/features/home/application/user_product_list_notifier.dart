import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';
import 'dart:math';

class DocumentSnapshotWrapper {
  final List<Product> allProducts;
  final int currentIndex;
  
  DocumentSnapshotWrapper(this.allProducts, this.currentIndex);
}

class UserProductListState {
  final List<Product> products;
  final bool isLoadingFirstPage;
  final bool isLoadingNextPage;
  final bool hasMore;
  final Object? error;
  final Object? lastDocument;
  final String? currentCategoryFilter;
  final String? currentSubcategoryFilter;
  final ProductSortCriteria currentSortCriteria;
  final String currentSearchQuery;

  UserProductListState({
    this.products = const [],
    this.isLoadingFirstPage = false,
    this.isLoadingNextPage = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
    this.currentCategoryFilter,
    this.currentSubcategoryFilter,
    this.currentSortCriteria = ProductSortCriteria.none,
    this.currentSearchQuery = '',
  });

  // Метод копирования
  UserProductListState copyWith({
    List<Product>? products,
    bool? isLoadingFirstPage,
    bool? isLoadingNextPage,
    bool? hasMore,
    Object? error,
    Object? lastDocument,
    String? currentCategoryFilter,
    String? currentSubcategoryFilter,
    ProductSortCriteria? currentSortCriteria,
    String? currentSearchQuery,
    bool clearError = false,
  }) {
    return UserProductListState(
      products: products ?? this.products,
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : error ?? this.error,
      lastDocument: lastDocument ?? this.lastDocument,
      currentCategoryFilter: currentCategoryFilter ?? this.currentCategoryFilter,
      currentSubcategoryFilter: currentSubcategoryFilter ?? this.currentSubcategoryFilter,
      currentSortCriteria: currentSortCriteria ?? this.currentSortCriteria,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
    );
  }

  // Геттер для проверки, идет ли любая загрузка
  bool get isLoading => isLoadingFirstPage || isLoadingNextPage;
}

// StateNotifier
class UserProductListNotifier extends StateNotifier<UserProductListState> {
  final ProductService _productService;
  final Ref _ref;
  static const int _itemsPerPage = 10;
  Timer? _debounce; // Таймер для debounce поиска

  UserProductListNotifier(this._productService, this._ref) : super(UserProductListState()) {
    fetchFirstPage();
  }

  ({String field, bool descending}) _getSortParams(ProductSortCriteria criteria) {
    switch (criteria) {
      case ProductSortCriteria.priceAsc: return (field: 'price', descending: false);
      case ProductSortCriteria.priceDesc: return (field: 'price', descending: true);
      case ProductSortCriteria.nameAsc: return (field: 'name', descending: false);
      case ProductSortCriteria.none:
      default:
        return (field: 'name', descending: false); // Сортировка по имени по умолчанию
    }
  }

  Future<void> fetchFirstPage() async {
    if (state.isLoadingFirstPage) return;

    final category = _ref.read(productCategoryFilterProvider);
    final subcategory = _ref.read(productSubcategoryFilterProvider);
    final sortCriteria = _ref.read(productSortProvider);
    final searchQuery = _ref.read(productSearchQueryProvider);
    final sortParams = _getSortParams(sortCriteria);

    state = UserProductListState(
      isLoadingFirstPage: true, 
      currentCategoryFilter: category,
      currentSubcategoryFilter: subcategory,
      currentSortCriteria: sortCriteria,
      currentSearchQuery: searchQuery,
    );

    try {
      // Если есть поисковый запрос, используем глобальный поиск по всем товарам
      if (searchQuery.isNotEmpty) {
        List<Product> searchResults = await _productService.searchAllProducts(searchQuery);
        
        if (category != null) {
          searchResults = searchResults.where((p) {
            final parts = p.category.split('/');
            if (parts.isEmpty) return false;
            if (subcategory == null) {
              return parts[0] == category;
            } else {
              return parts[0] == category && parts.length > 1 && parts[1] == subcategory;
            }
          }).toList();
        }
        
        switch (sortCriteria) {
          case ProductSortCriteria.priceAsc:
            searchResults.sort((a, b) => a.price.compareTo(b.price));
            break;
          case ProductSortCriteria.priceDesc:
            searchResults.sort((a, b) => b.price.compareTo(a.price));
            break;
          case ProductSortCriteria.nameAsc:
            searchResults.sort((a, b) => a.name.compareTo(b.name));
            break;
          default:
            break;
        }
        
        state = state.copyWith(
          products: searchResults.take(_itemsPerPage).toList(),
          isLoadingFirstPage: false,
          hasMore: searchResults.length > _itemsPerPage,
          error: null,
          lastDocument: searchResults.length > _itemsPerPage ?
              DocumentSnapshotWrapper(searchResults, _itemsPerPage) : null,
        );
        return;
      }
      
      PaginatedProductsResult result = await _productService.getProductsPaginated(
        limit: _itemsPerPage,
        orderByField: sortParams.field,
        descending: sortParams.descending,
        categoryFilter: category,
        subcategoryFilter: subcategory,
      );
      
      state = state.copyWith(
        products: result.products,
        isLoadingFirstPage: false,
        hasMore: result.products.length == _itemsPerPage,
        lastDocument: result.lastDocument,
        error: null,
      );
    } catch (e, stackTrace) {
      print('Ошибка загрузки первой страницы (User): $e\n$stackTrace');
      state = state.copyWith(isLoadingFirstPage: false, error: e, hasMore: false);
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoadingNextPage: true, clearError: true);
    
    try {
      if (state.currentSearchQuery.isNotEmpty && state.lastDocument is DocumentSnapshotWrapper) {
        final wrapper = state.lastDocument as DocumentSnapshotWrapper;
        final allSearchResults = wrapper.allProducts;
        final currentIndex = wrapper.currentIndex;
        
        final nextPageProducts = allSearchResults
            .skip(currentIndex)
            .take(_itemsPerPage)
            .toList();
        
        state = state.copyWith(
          products: [...state.products, ...nextPageProducts],
          isLoadingNextPage: false,
          hasMore: currentIndex + _itemsPerPage < allSearchResults.length,
          lastDocument: currentIndex + _itemsPerPage < allSearchResults.length ? 
              DocumentSnapshotWrapper(allSearchResults, currentIndex + _itemsPerPage) : null,
        );
        return;
      }
    
      final sortParams = _getSortParams(state.currentSortCriteria);
      PaginatedProductsResult result = await _productService.getProductsPaginated(
        limit: _itemsPerPage,
        cursor: state.lastDocument is DocumentSnapshot ? state.lastDocument as DocumentSnapshot : null,
        isFetchingForward: true,
        orderByField: sortParams.field,
        descending: sortParams.descending,
        categoryFilter: state.currentCategoryFilter,
        subcategoryFilter: state.currentSubcategoryFilter,
      );

      state = state.copyWith(
        products: [...state.products, ...result.products],
        isLoadingNextPage: false,
        hasMore: result.products.length == _itemsPerPage,
        lastDocument: result.lastDocument,
      );
    } catch (e, stackTrace) {
      print('Ошибка загрузки следующей страницы (User): $e\n$stackTrace');
      state = state.copyWith(isLoadingNextPage: false, error: e, hasMore: false);
    }
  }
  
  void handleFiltersChanged() {
     if (_debounce?.isActive ?? false) _debounce!.cancel();
     _debounce = Timer(const Duration(milliseconds: 500), () {
          print("[UserProductListNotifier] Фильтры изменились, перезагрузка...");
          fetchFirstPage(); 
     });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// Провайдер
final userProductListProvider = StateNotifierProvider<UserProductListNotifier, UserProductListState>((ref) {
  final productService = ref.watch(productServiceProvider);
  final notifier = UserProductListNotifier(productService, ref);

  // Слушаем изменения внешних провайдеров фильтров/сортировки/поиска
  ref.listen(productCategoryFilterProvider, (_, __) => notifier.handleFiltersChanged());
  ref.listen(productSubcategoryFilterProvider, (_, __) => notifier.handleFiltersChanged());
  ref.listen(productSortProvider, (_, __) => notifier.handleFiltersChanged());
  ref.listen(productSearchQueryProvider, (_, __) => notifier.handleFiltersChanged());

  return notifier;
}); 