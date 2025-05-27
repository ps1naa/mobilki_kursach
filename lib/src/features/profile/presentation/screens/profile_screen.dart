import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:kursovoi/src/features/auth/application/auth_service.dart';
import 'package:kursovoi/src/features/orders/application/order_service.dart';
import 'package:kursovoi/src/features/orders/domain/order.dart' as domain;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    final ordersAsyncValue = ref.watch(userOrdersStreamProvider);
    final theme = Theme.of(context);
    
    // Получаем размеры экрана и ориентацию для адаптивности
    final size = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isLandscape && size.width > 600
                ? _buildLandscapeLayout(context, theme, user, ordersAsyncValue, authService)
                : _buildPortraitLayout(context, theme, user, ordersAsyncValue, authService),
          ),
        ),
      ),
    );
  }
  
  // Горизонтальная ориентация для больших экранов - используем Row
  Widget _buildLandscapeLayout(
    BuildContext context, 
    ThemeData theme, 
    dynamic user, 
    AsyncValue<List<domain.Order>> ordersAsyncValue,
    dynamic authService
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Левая часть - профиль и кнопка выхода
        Expanded(
          flex: 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Профиль', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  Text('Email: ${user?.email ?? "Неизвестно"}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showChangePasswordDialog(context),
                    child: const Text('Изменить пароль'),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () async {
                      await authService.signOut();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                    child: const Text('Выйти из аккаунта'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Правая часть - история заказов
        Expanded(
          flex: 3,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('История заказов', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 500, // Фиксированная высота для отображения списка заказов
                    child: _buildOrdersList(context, ordersAsyncValue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Вертикальная ориентация или маленький экран - используем Column
  Widget _buildPortraitLayout(
    BuildContext context, 
    ThemeData theme, 
    dynamic user, 
    AsyncValue<List<domain.Order>> ordersAsyncValue,
    dynamic authService
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Профиль
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Профиль', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text('Email: ${user?.email ?? "Неизвестно"}'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _showChangePasswordDialog(context),
                  child: const Text('Изменить пароль'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // История заказов
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('История заказов', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300, // Фиксированная высота для отображения списка заказов
                  child: _buildOrdersList(context, ordersAsyncValue),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Кнопка выхода внизу
        ElevatedButton(
          onPressed: () async {
            await authService.signOut();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
          child: const Text('Выйти из аккаунта'),
        ),
      ],
    );
  }
  
  // Выделяем построение списка заказов в отдельный метод
  Widget _buildOrdersList(BuildContext context, AsyncValue<List<domain.Order>> ordersAsyncValue) {
    return ordersAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Ошибка загрузки заказов: $error'),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(child: Text('У вас пока нет заказов.'));
        }
        
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                onTap: () => context.push('/order/${order.id}'),
                title: Text('Заказ №${order.id.substring(0, 8)}...'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt.toDate())}'),
                    Text('Статус: ${_getOrderStatusText(order.status)}'),
                    Text('Сумма: ${order.totalAmount.toStringAsFixed(2)} ₽'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  // Вспомогательная функция для получения текста статуса
  String _getOrderStatusText(domain.OrderStatus status) {
    switch (status) {
      case domain.OrderStatus.pending:
        return 'Ожидает подтверждения';
      case domain.OrderStatus.processing:
        return 'В обработке';
      case domain.OrderStatus.shipped:
        return 'Отправлен';
      case domain.OrderStatus.delivered:
        return 'Доставлен';
      case domain.OrderStatus.cancelled:
        return 'Отменен';
      default:
        return 'Неизвестный статус';
    }
  }

  // Диалог изменения пароля
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    bool isLoading = false;
    String? errorMessage;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    
    // Проверка требований к новому паролю
    bool isPasswordEightCharacters = false;
    bool hasPasswordOneNumber = false;
    bool hasPasswordOneUppercase = false;
    bool hasPasswordOneSpecialChar = false;
    
    void checkNewPassword() {
      final password = newPasswordController.text;
      isPasswordEightCharacters = password.length >= 8;
      hasPasswordOneNumber = RegExp(r'[0-9]').hasMatch(password);
      hasPasswordOneUppercase = RegExp(r'[A-Z]').hasMatch(password);
      hasPasswordOneSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    }
    
    // Валидация текущего пароля
    String? validateCurrentPassword(String? value) {
      if (value == null || value.isEmpty) {
        return 'Введите текущий пароль';
      }
      return null;
    }
    
    // Валидация нового пароля
    String? validateNewPassword(String? value) {
      if (value == null || value.isEmpty) {
        return 'Введите новый пароль';
      }
      
      List<String> requirements = [];
      
      if (value.length < 8) {
        requirements.add('минимум 8 символов');
      }
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        requirements.add('хотя бы одну цифру');
      }
      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        requirements.add('хотя бы одну заглавную букву');
      }
      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
        requirements.add('хотя бы один специальный символ');
      }
      
      if (requirements.isNotEmpty) {
        return 'Пароль должен содержать ${requirements.join(', ')}';
      }
      
      if (value == currentPasswordController.text) {
        return 'Новый пароль должен отличаться от текущего';
      }
      
      return null;
    }
    
    // Валидация подтверждения пароля
    String? validateConfirmPassword(String? value) {
      if (value == null || value.isEmpty) {
        return 'Подтвердите новый пароль';
      }
      
      if (value != newPasswordController.text) {
        return 'Пароли не совпадают';
      }
      
      return null;
    }
    
    // Виджет для отображения проверки требований пароля
    Widget buildPasswordCheckRow(bool isValid, String text) {
      return Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.check_circle_outline,
            color: isValid ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isValid ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Обновляем состояние проверки пароля при изменении текста
          void updatePasswordChecks() {
            setState(() {
              checkNewPassword();
            });
          }
          
          return AlertDialog(
            title: const Text('Изменение пароля'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Текущий пароль
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Текущий пароль',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrentPassword 
                              ? Icons.visibility 
                              : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: obscureCurrentPassword,
                      validator: validateCurrentPassword,
                    ),
                    const SizedBox(height: 16),
                    
                    // Новый пароль
                    TextFormField(
                      controller: newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Новый пароль',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword 
                              ? Icons.visibility 
                              : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: obscureNewPassword,
                      validator: validateNewPassword,
                      onChanged: (value) {
                        updatePasswordChecks();
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    // Индикаторы валидности пароля
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildPasswordCheckRow(
                            isPasswordEightCharacters, 
                            'Минимум 8 символов'
                          ),
                          const SizedBox(height: 4),
                          buildPasswordCheckRow(
                            hasPasswordOneNumber, 
                            'Содержит как минимум 1 цифру'
                          ),
                          const SizedBox(height: 4),
                          buildPasswordCheckRow(
                            hasPasswordOneUppercase, 
                            'Содержит как минимум 1 заглавную букву'
                          ),
                          const SizedBox(height: 4),
                          buildPasswordCheckRow(
                            hasPasswordOneSpecialChar, 
                            'Содержит как минимум 1 специальный символ'
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Подтверждение нового пароля
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Подтвердите новый пароль',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword 
                              ? Icons.visibility 
                              : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: obscureConfirmPassword,
                      validator: validateConfirmPassword,
                    ),
                    
                    // Сообщение об ошибке
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() ?? false) {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          
                          try {
                            // Сначала повторно аутентифицируем пользователя с текущим паролем
                            final authService = ref.read(authServiceProvider);
                            await authService.reauthenticateWithCredential(
                              currentPasswordController.text.trim(),
                            );
                            
                            // Затем меняем пароль на новый
                            await authService.updatePassword(
                              newPasswordController.text.trim(),
                            );
                            
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Пароль успешно изменен'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = e.toString();
                            });
                          } finally {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Изменить пароль'),
              ),
            ],
          );
        },
      ),
    );
  }
} 