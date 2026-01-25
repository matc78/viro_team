import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/utils/retry_service.dart';

void main() {
  group('RetryService.isRetryableError', () {
    test('SocketException est récupérable', () {
      expect(RetryService.isRetryableError(SocketException('test')), isTrue);
    });

    test('FirebaseException unavailable est récupérable', () {
      expect(
        RetryService.isRetryableError(
          FirebaseException(
            plugin: 'firestore',
            code: 'unavailable',
            message: 'x',
          ),
        ),
        isTrue,
      );
    });

    test('FirebaseException deadline-exceeded est récupérable', () {
      expect(
        RetryService.isRetryableError(
          FirebaseException(
            plugin: 'firestore',
            code: 'deadline-exceeded',
            message: 'x',
          ),
        ),
        isTrue,
      );
    });

    test('FirebaseException permission-denied n\'est pas récupérable', () {
      expect(
        RetryService.isRetryableError(
          FirebaseException(
            plugin: 'firestore',
            code: 'permission-denied',
            message: 'x',
          ),
        ),
        isFalse,
      );
    });

    test('FirebaseAuthException network-request-failed est récupérable', () {
      expect(
        RetryService.isRetryableError(
          FirebaseAuthException(
            code: 'network-request-failed',
            message: 'x',
          ),
        ),
        isTrue,
      );
    });

    test('FirebaseAuthException wrong-password n\'est pas récupérable', () {
      expect(
        RetryService.isRetryableError(
          FirebaseAuthException(code: 'wrong-password', message: 'x'),
        ),
        isFalse,
      );
    });

    test('erreur avec "timeout" dans le message est récupérable', () {
      expect(
        RetryService.isRetryableError(Exception('connection timeout')),
        isTrue,
      );
    });

    test('erreur avec "network" dans le message est récupérable', () {
      expect(
        RetryService.isRetryableError(Exception('network error')),
        isTrue,
      );
    });

    test('erreur générique sans pattern n\'est pas récupérable', () {
      expect(
        RetryService.isRetryableError(Exception('invalid data')),
        isFalse,
      );
    });
  });

  group('RetryService.executeWithRetry', () {
    test('succès au premier essai retourne la valeur', () async {
      final result = await RetryService.executeWithRetry<int>(
        operation: () async => 42,
      );
      expect(result, 42);
    });

    test('échec puis succès après retry', () async {
      var attempts = 0;
      final result = await RetryService.executeWithRetry<int>(
        operation: () async {
          attempts++;
          if (attempts < 2) throw SocketException('test');
          return 99;
        },
        maxRetries: 3,
      );
      expect(result, 99);
      expect(attempts, 2);
    });

    test('onRetry est appelé avant chaque retry', () async {
      final delays = <Duration>[];
      await RetryService.executeWithRetry<int>(
        operation: () async {
          if (delays.isEmpty) throw SocketException('test');
          if (delays.length < 2) throw SocketException('test');
          return 1;
        },
        maxRetries: 4,
        onRetry: (attempt, delay) => delays.add(delay),
      );
      expect(delays.length, 2);
    });

    test('erreur non récupérable relancée immédiatement', () async {
      var attempts = 0;
      expect(
        () async {
          await RetryService.executeWithRetry<int>(
            operation: () async {
              attempts++;
              throw FirebaseAuthException(
                code: 'wrong-password',
                message: 'x',
              );
            },
            maxRetries: 3,
          );
        },
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(attempts, 1);
    });
  });

  group('RetryService constantes', () {
    test('maxRetries par défaut', () {
      expect(RetryService.maxRetries, 3);
    });
    test('initialDelayMs', () {
      expect(RetryService.initialDelayMs, 500);
    });
  });
}
