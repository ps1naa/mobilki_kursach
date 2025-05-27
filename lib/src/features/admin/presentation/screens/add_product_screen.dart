import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kursovoi/src/features/products/domain/product.dart';

// Провайдер для Firestore
final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _stockQuantityController = TextEditingController(); // Контроллер для количества

  // Определяем категории и подкатегории
  final Map<String, List<String>> _categories = {
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

  String? _selectedCategory;
  String? _selectedSubcategory;
  List<String> _currentSubcategories = []; // Список подкатегорий для выбранной основной

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _stockQuantityController.dispose(); // Очищаем
    super.dispose();
  }

  Future<void> _addProduct() async {
    // Добавляем проверку, что категория и подкатегория выбраны
    if ((_formKey.currentState?.validate() ?? false) &&
        _selectedCategory != null &&
        _selectedSubcategory != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final firestore = ref.read(firestoreProvider);
        final categoryString = '$_selectedCategory/$_selectedSubcategory';

        final newProduct = Product(
          id: '', //firestore сам сгенерирует
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.tryParse(_priceController.text.trim()) ?? 0.0,
          imageUrl: _imageUrlController.text.trim(),
          category: categoryString, // Используем сформированную строку
          // Получаем количество из контроллера
          stockQuantity: int.tryParse(_stockQuantityController.text.trim()) ?? 0,
        );

        await firestore.collection('products').add(newProduct.toFirestore());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Товар успешно добавлен!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Ошибка добавления товара: ${e.toString()}';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (_selectedCategory == null || _selectedSubcategory == null) {
       // Показываем ошибку, если категория/подкатегория не выбраны
       setState(() {
         _errorMessage = 'Пожалуйста, выберите категорию и подкатегорию';
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить товар'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название товара', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? 'Введите название' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder()),
                maxLines: 3,
                 validator: (value) => (value == null || value.isEmpty) ? 'Введите описание' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Цена', prefixText: '₽ ', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                   FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Разрешает цифры и точку (макс 2 знака после)
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Введите цену';
                  if (double.tryParse(value) == null) return 'Неверный формат цены';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Выпадающий список для Основной Категории
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                hint: const Text('Выберите категорию'),
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
                    _selectedSubcategory = null;
                    _currentSubcategories = _categories[newValue] ?? [];
                  });
                },
                validator: (value) => value == null ? 'Выберите категорию' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSubcategory,
                hint: const Text('Выберите подкатегорию'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _currentSubcategories.map((String subcategory) {
                  return DropdownMenuItem<String>(
                    value: subcategory,
                    child: Text(subcategory),
                  );
                }).toList(),
                onChanged: _selectedCategory == null ? null : (String? newValue) { // Неактивен, если нет основной категории
                  setState(() {
                    _selectedSubcategory = newValue;
                  });
                },
                 validator: (value) => _selectedCategory != null && value == null ? 'Выберите подкатегорию' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'URL изображения', border: OutlineInputBorder()),
                keyboardType: TextInputType.url,
                 validator: (value) {
                   if (value == null || value.isEmpty) return 'Введите URL изображения';
                   final uri = Uri.tryParse(value);
                   if (uri == null || !uri.hasAbsolutePath || !uri.isScheme("HTTP") && !uri.isScheme("HTTPS")) {
                     return 'Введите корректный HTTP/HTTPS URL';
                   }
                   return null;
                 }
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockQuantityController,
                decoration: const InputDecoration(labelText: 'Количество на складе', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Введите количество';
                  if (int.tryParse(value) == null) return 'Неверный формат числа';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _addProduct,
                       style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      child: const Text('Добавить товар'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
} 