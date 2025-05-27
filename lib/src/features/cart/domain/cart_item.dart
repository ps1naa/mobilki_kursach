import 'dart:convert';

class CartItem {
  final String productId;
  int quantity;

  CartItem({required this.productId, required this.quantity});

  void increment() => quantity++;
  void decrement() {
    if (quantity > 0) quantity--;
  }

  CartItem copyWith({
    String? productId,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
      };

  // Фабричный конструктор для создания из Map (из JSON)
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] as String,
      quantity: json['quantity'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          productId == other.productId;


  @override
  int get hashCode => productId.hashCode;
} 