import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kursovoi/firebase_options.dart';
import 'package:kursovoi/src/core/router/app_router.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  // Инициализируем Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Запускаем приложение с ProviderScope для Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Получаем конфигурацию роутера из провайдера
    final router = ref.watch(goRouterProvider);

    // Используем MaterialApp.router для интеграции с go_router
    return MaterialApp.router(
      title: 'Доставка Продуктов',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // TODO: Добавить более детальные настройки темы (шрифты, кнопки и т.д.)
      ),
      routerConfig: router,
    );
  }
}

