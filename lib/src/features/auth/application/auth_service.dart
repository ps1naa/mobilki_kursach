import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider), FirebaseFirestore.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Ошибки аутентификации с русскими сообщениями
class AuthException implements Exception {
  final String message;
  final String code;
  
  AuthException(this.code, this.message);
  
  @override
  String toString() => message;
  
  // Преобразование ошибок Firebase в понятные пользователю сообщения
  static AuthException fromFirebaseException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException(e.code, 'Пользователь с таким email не найден');
      case 'wrong-password':
        return AuthException(e.code, 'Неверный пароль');
      case 'email-already-in-use':
        return AuthException(e.code, 'Этот email уже используется');
      case 'weak-password':
        return AuthException(e.code, 'Слишком слабый пароль');
      case 'invalid-email':
        return AuthException(e.code, 'Некорректный email');
      case 'user-disabled':
        return AuthException(e.code, 'Аккаунт отключен');
      case 'operation-not-allowed':
        return AuthException(e.code, 'Операция не разрешена');
      case 'too-many-requests':
        return AuthException(e.code, 'Слишком много попыток. Попробуйте позже');
      default:
        return AuthException(e.code, 'Ошибка: ${e.message}');
    }
  }
}

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  late final GoogleSignIn _googleSignIn;

  AuthService(this._firebaseAuth, this._firestore) {
    _googleSignIn = GoogleSignIn(
      // Запрашиваем только базовые разрешения
      scopes: [
        'email',
        'profile',
      ],
      // Для веб-платформ можно указать clientId, но для Android и iOS это не требуется
      // clientId: "YOUR_WEB_CLIENT_ID", // Используется только на веб
    );
  }

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Получение текущего пользователя
  User? get currentUser => _firebaseAuth.currentUser;

  // Вход по Email и паролю
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // Устанавливаем русский язык для сообщений об ошибках
      _firebaseAuth.setLanguageCode("ru");
      
      // Метод setPersistence доступен только на веб-платформе
      // Для мобильных платформ используем стандартный вызов
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseException(e);
    } catch (e) {
      throw AuthException('unknown', 'Неизвестная ошибка при входе: $e');
    }
  }

  // Вход через Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Настройка для веб и мобильных платформ
      if (kIsWeb) {
        // Для веб используем другой метод
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({
          'prompt': 'select_account'
        });
        return await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        // Запускаем процесс входа через Google с указанием scopes и serverClientId
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        // Если пользователь отменил вход
        if (googleUser == null) {
          throw AuthException('cancelled', 'Вход через Google был отменен');
        }
        
        try {
          // Получаем данные аутентификации
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          
          // Создаем учетные данные для Firebase
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          
          // Входим в Firebase с учетными данными Google
          final userCredential = await _firebaseAuth.signInWithCredential(credential);
          
          // Если пользователь новый, создаем документ в Firestore
          if (userCredential.additionalUserInfo?.isNewUser ?? false) {
            await _createUserDocument(
              userCredential.user!.uid, 
              userCredential.user!.email ?? 'неизвестный email',
            );
          }
          
          return userCredential;
        } catch (e) {
          // Выход из Google при ошибке, чтобы не оставлять активную сессию
          await _googleSignIn.signOut();
          throw e;
        }
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseException(e);
    } catch (e) {
      throw AuthException('unknown', 'Ошибка при входе через Google: $e');
    }
  }

  // Регистрация по Email и паролю
  Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      // Устанавливаем русский язык для сообщений об ошибках
      _firebaseAuth.setLanguageCode("ru");
      
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!.uid, email);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseException(e);
    } catch (e) {
      throw AuthException('unknown', 'Неизвестная ошибка при регистрации: $e');
    }
  }

  // Создание документа пользователя в Firestore
  Future<void> _createUserDocument(String userId, String email) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'email': email,
        'role': 'user', // По умолчанию роль 'user'
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Ошибка создания документа пользователя: $e');
    }
  }

  // Выход из системы
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Выход из Google, если был вход через него
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('sign-out-error', 'Ошибка при выходе из системы: $e');
    }
  }

  Future<String?> getUserRole(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Ошибка получения роли пользователя: $e');
      return null;
    }
  }

  // Метод для сброса пароля
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseException(e);
    } catch (e) {
      throw AuthException('unknown', 'Ошибка при отправке сброса пароля: $e');
    }
  }

  // Метод для обновления пароля текущего пользователя
  Future<void> updatePassword(String newPassword) async {
    try {
      User? user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException('not-logged-in', 'Пользователь не авторизован');
      }
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseException(e);
    } catch (e) {
      throw AuthException('unknown', 'Ошибка при обновлении пароля: $e');
    }
  }

  // Метод для повторной аутентификации (нужен для изменения пароля)
  Future<void> reauthenticateWithCredential(String password) async {
    try {
      User? user = _firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw AuthException('not-logged-in', 'Пользователь не авторизован');
      }
      
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseException(e);
    } catch (e) {
      throw AuthException('unknown', 'Ошибка при повторной аутентификации: $e');
    }
  }
} 