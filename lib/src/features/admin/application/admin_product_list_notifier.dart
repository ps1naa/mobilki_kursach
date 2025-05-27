import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';
import 'dart:math';

// --- Опции сортировки --- 
enum AdminProductSortOption {
  nameAsc('По имени (А-Я)', 'name', false),
  nameDesc('По имени (Я-А)', 'name', true),
  priceAsc('По цене (↑)', 'price', false),
  priceDesc('По цене (↓)', 'price', true),
  stockAsc('По остатку (↑)', 'stockQuantity', false),
  stockDesc('По остатку (↓)', 'stockQuantity', true);

  const AdminProductSortOption(this.displayName, this.field, this.descending);
  final String displayName;
  final String field;
  final bool descending;
}

class AdminProductListState {
  final List<Product> products;
  final bool isLoading;
  final Object? error;
  final int currentPage;
  final int totalPages;
  final DocumentSnapshot? firstDocument;
  final DocumentSnapshot? lastDocument;
  final int totalItems;
  final AdminProductSortOption sortOption;

  AdminProductListState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 0,
    this.firstDocument,
    this.lastDocument,
    this.totalItems = 0,
    this.sortOption = AdminProductSortOption.nameAsc,
  });

  // Метод для копирования состояния с изменениями
  AdminProductListState copyWith({
    List<Product>? products,
    bool? isLoading,
    Object? error,
    int? currentPage,
    int? totalPages,
    DocumentSnapshot? firstDocument,
    DocumentSnapshot? lastDocument,
    int? totalItems,
    AdminProductSortOption? sortOption,
    bool clearError = false,
    bool resetPagination = false,
  }) {
    return AdminProductListState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      currentPage: resetPagination ? 1 : currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      // Сбрасываем курсоры при смене сортировки
      firstDocument: resetPagination ? null : firstDocument ?? this.firstDocument,
      lastDocument: resetPagination ? null : lastDocument ?? this.lastDocument,
      totalItems: totalItems ?? this.totalItems,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

// StateNotifier
class AdminProductListNotifier extends StateNotifier<AdminProductListState> {
  final ProductService _productService;
  static const int _itemsPerPage = 20; // Количество товаров на странице

  AdminProductListNotifier(this._productService) : super(AdminProductListState(isLoading: true)) {
    _initialize();
  }

  // Инициализация или перезагрузка первой страницы с текущей сортировкой
  Future<void> _initialize({AdminProductSortOption? initialSortOption}) async {
    final currentSortOption = initialSortOption ?? state.sortOption;
    state = state.copyWith(
        isLoading: true,
        clearError: true,
        resetPagination: true,
        sortOption: currentSortOption
    );

    try {
      final totalItems = await _productService.getTotalProductsCount();
      if (totalItems == 0) {
         state = state.copyWith(isLoading: false, totalPages: 0, totalItems: 0, products: []);
         return;
      }
      final totalPages = (totalItems / _itemsPerPage).ceil();
      
      final result = await _productService.getProductsPaginated(
          limit: _itemsPerPage,
          orderByField: currentSortOption.field,
          descending: currentSortOption.descending,
      );

      state = state.copyWith(
        products: result.products,
        isLoading: false,
        totalPages: totalPages,
        firstDocument: result.firstDocument,
        lastDocument: result.lastDocument,
        totalItems: totalItems,
      );

    } catch (e, stackTrace) {
      print('Ошибка инициализации/перезагрузки списка товаров: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  // Переход на следующую страницу
  Future<void> goToNextPage() async {
    if (state.isLoading || state.currentPage >= state.totalPages) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _productService.getProductsPaginated(
        limit: _itemsPerPage,
        cursor: state.lastDocument, 
        isFetchingForward: true,
        orderByField: state.sortOption.field,
        descending: state.sortOption.descending,
      );

      state = state.copyWith(
        products: result.products,
        isLoading: false,
        currentPage: state.currentPage + 1,
        firstDocument: result.firstDocument,
        lastDocument: result.lastDocument,
      );
    } catch (e, stackTrace) {
      print('Ошибка при переходе на следующую страницу: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  // Переход на предыдущую страницу
  Future<void> goToPreviousPage() async {
    if (state.isLoading || state.currentPage <= 1) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _productService.getProductsPaginated(
        limit: _itemsPerPage,
        cursor: state.firstDocument,
        isFetchingForward: false,
        orderByField: state.sortOption.field,
        descending: state.sortOption.descending,
      );

      state = state.copyWith(
        products: result.products,
        isLoading: false,
        currentPage: state.currentPage - 1,
        firstDocument: result.firstDocument,
        lastDocument: result.lastDocument,
      );
    } catch (e, stackTrace) {
      print('Ошибка при переходе на предыдущую страницу: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> setSortOption(AdminProductSortOption newOption) async {
    if (newOption == state.sortOption) return;
    // Перезагружаем первую страницу с новой сортировкой
    await _initialize(initialSortOption: newOption);
  }

}

// Провайдер для StateNotifier
final adminProductListProvider = StateNotifierProvider<AdminProductListNotifier, AdminProductListState>((ref) {
  final productService = ref.watch(productServiceProvider);
  return AdminProductListNotifier(productService);
}); 