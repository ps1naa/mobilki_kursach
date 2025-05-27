import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';
import 'package:kursovoi/src/features/auth/application/auth_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:kursovoi/src/features/products/application/product_service.dart';

// Провайдер для ProductService
final productServiceProvider = Provider<ProductService>((ref) {
  // Возможно, лучше вынести firestoreProvider в core/providers
  final firestore = FirebaseFirestore.instance; // Пока используем напрямую
  return ProductService(firestore);
});

// Класс для результата пагинации
class PaginatedProductsResult {
  final List<Product> products;
  final DocumentSnapshot? firstDocument;
  final DocumentSnapshot? lastDocument;


  PaginatedProductsResult({
    required this.products,
    this.firstDocument,
    this.lastDocument,

  });
}

class ProductService {
  final FirebaseFirestore _firestore;
  final CollectionReference<Product> _productsRef;

  ProductService(this._firestore) :
    // Создаем ссылку на коллекцию с конвертером один раз
    _productsRef = _firestore.collection('products').withConverter<Product>(
          fromFirestore: Product.fromFirestore,
          toFirestore: (Product product, _) => product.toFirestore(),
        );

  Future<int> getTotalProductsCount() async {
    try {
      // Получаем агрегированный снимок с количеством
      AggregateQuerySnapshot snapshot = await _productsRef.count().get();
      print('Общее количество товаров: ${snapshot.count}');
      return snapshot.count ?? 0;
    } catch (e) {
      print('Ошибка получения общего количества товаров: $e');
      return 0; // Возвращаем 0 в случае ошибки
    }
  }

  // Получить поток всех товаров
  Stream<List<Product>> getProductsStream() {
    // Используем _productsRef
    return _productsRef
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<List<Product>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    try {
      final snapshot = await _productsRef
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Ошибка получения товаров по IDs: $e');
      return [];
    }
  }

  Stream<Product?> getProductByIdStream(String productId) {
    return _productsRef
        .doc(productId)
        .snapshots() // Получаем поток одного документа
        .map((snapshot) => snapshot.data()) // Преобразуем в Product?
        .handleError((error) {
           print("Ошибка получения потока товара $productId: $error");
           return null;
        });
  }

  // Метод для обновления товара
  Future<void> updateProduct(String productId, Product productData) async {
      await _productsRef.doc(productId).update(productData.toFirestore());
  }

  //  Метод для удаления товара
  Future<void> deleteProduct(String productId) async {
      await _productsRef.doc(productId).delete();
  }

  // Метод для получения товаров постранично admin
  Future<PaginatedProductsResult> getProductsPaginated({
    required int limit,
    String orderByField = 'name', 
    bool descending = false,
    DocumentSnapshot? cursor, 
    bool isFetchingForward = true,
    String? categoryFilter, 
    String? subcategoryFilter,
  }) async {
    Query<Product> query = _productsRef;

    // Фильтрация по категории
    if (categoryFilter != null) {
      if (subcategoryFilter != null) {
        // Фильтр по категории и подкатегории
        final categoryPath = '$categoryFilter/$subcategoryFilter';
        print('Фильтр по категории/подкатегории: $categoryPath'); // Лог
        query = query.where('category', isEqualTo: categoryPath);
      } else {
        // Фильтр только по основной категории
        print('Фильтр по категории: $categoryFilter/'); // Лог
        query = query.where('category', isGreaterThanOrEqualTo: '$categoryFilter/')
                     .where('category', isLessThan: '${categoryFilter}0');
      }
    }
    query = query.orderBy(orderByField, descending: isFetchingForward ? descending : !descending);

    // Применяем курсор
    if (cursor != null) {
      if (isFetchingForward) {
        query = query.startAfterDocument(cursor);
      } else {
        query = query.endBeforeDocument(cursor);
      }
    }

    // Применяем лимит
    query = query.limit(limit);

    try {
       final snapshot = await query.get();
       List<Product> products = snapshot.docs.map((doc) => doc.data()).toList();

       if (!isFetchingForward) {
         products = products.reversed.toList();
       }

       // Получаем первый и последний документы для следующего/предыдущего запроса
       final DocumentSnapshot? firstDocument = snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
       final DocumentSnapshot? lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

       return PaginatedProductsResult(
         products: products,
         firstDocument: firstDocument, // Добавляем первый документ
         lastDocument: lastDocument,
       );

    } catch (e) {
       print('Ошибка получения товаров постранично: $e');
       throw Exception('Не удалось загрузить товары: $e');
    }
  }

  Future<List<Product>> searchAllProducts(String searchQuery) async {
    if (searchQuery.isEmpty) {
      return []; // Возвращаем пустой список, если запрос пустой
    }
    
    try {
      // Загружаем все товары для поиска
      final snapshot = await _productsRef.get();
      List<Product> allProducts = snapshot.docs.map((doc) => doc.data()).toList();
      
      // Фильтруем товары по поисковому запросу
      final lowerQuery = searchQuery.toLowerCase();
      return allProducts.where((p) => 
        p.name.toLowerCase().contains(lowerQuery) || 
        p.description.toLowerCase().contains(lowerQuery)
      ).toList();
    } catch (e) {
      print('Ошибка при глобальном поиске товаров: $e');
      throw Exception('Не удалось выполнить поиск товаров: $e');
    }
  }

}

// Провайдеры для Фильтрации/Сортировки/Поиска

// Поисковый запрос
final productSearchQueryProvider = StateProvider<String>((_) => '');

// Критерий сортировки
enum ProductSortCriteria { none, priceAsc, priceDesc, nameAsc }
final productSortProvider = StateProvider<ProductSortCriteria>((_) => ProductSortCriteria.none);

// Выбранная категория для фильтра
final productCategoryFilterProvider = StateProvider<String?>((_) => null);
// Выбранная подкатегория для фильтра
final productSubcategoryFilterProvider = StateProvider<String?>((_) => null);

//  Модифицированный провайдер списка товаров

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final searchQuery = ref.watch(productSearchQueryProvider);
  final sortCriteria = ref.watch(productSortProvider);
  final categoryFilter = ref.watch(productCategoryFilterProvider);
  final subcategoryFilter = ref.watch(productSubcategoryFilterProvider);
  // Получаем базовый поток товаров
  final baseProductsStream = ref.watch(productServiceProvider).getProductsStream();

  // Применяем фильтрацию и сортировку к каждому событию из базового потока
  return baseProductsStream.map((products) {
    List<Product> filteredProducts = products;
    
    // Фильтрация по категории/подкатегории
    if (categoryFilter != null) {
        filteredProducts = filteredProducts.where((p) {
            final parts = p.category.split('/');
            if (parts.isEmpty) return false;
            if (subcategoryFilter == null) {
                 return parts[0] == categoryFilter;
            } else {
                 return parts[0] == categoryFilter && parts.length > 1 && parts[1] == subcategoryFilter;
            }
        }).toList();
    }

    // Фильтрация по поисковому запросу
    if (searchQuery.isNotEmpty) {
      final lowerCaseQuery = searchQuery.toLowerCase();
      filteredProducts = filteredProducts.where((product) {
        return product.name.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    }

    // Сортировка
    List<Product> sortedProducts = List.from(filteredProducts);
    switch (sortCriteria) {
      case ProductSortCriteria.priceAsc:
        sortedProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortCriteria.priceDesc:
        sortedProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSortCriteria.nameAsc:
        sortedProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ProductSortCriteria.none:
        break;
    }
    return sortedProducts;
  });
});

// Провайдер для потока деталей одного товара
final productDetailProvider = StreamProvider.family<Product?, String>((ref, productId) {
  final authState = ref.watch(authStateProvider);
  final productService = ref.watch(productServiceProvider);
  
  final user = authState.asData?.value;
  if (user == null) {
      return Stream.value(null); // Или Stream.error
  }
  
  return productService.getProductByIdStream(productId);
});

final rawProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  final productService = ref.watch(productServiceProvider);
  return productService.getProductsStream();
}); 