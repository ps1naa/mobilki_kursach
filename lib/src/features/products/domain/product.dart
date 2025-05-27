import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final int stockQuantity;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.stockQuantity,
  });

  // Фабричный конструктор для создания экземпляра Product из документа Firestore
  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data()!;
    return Product(
      id: snapshot.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num? ?? 0).toDouble(),
      imageUrl: data['imageUrl'] as String? ?? '',
      category: data['category'] as String? ?? '',
      stockQuantity: data['stockQuantity'] as int? ?? 0,
    );
  }

  // Метод для преобразования экземпляра Product в Map для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'stockQuantity': stockQuantity, // Добавляем в Firestore
      // if (stock != null) 'stock': stock, // Используем stock, если он есть
    };
  }
} 