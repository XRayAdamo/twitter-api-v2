// Copyright 2022 Kato Shinya. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided the conditions.

// Dart imports:
import 'dart:math' as math;

// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:twitter_api_v2/src/client/retry_policy.dart';
import 'package:twitter_api_v2/src/config/retry_config.dart';

void main() {
  group('.shouldRetry', () {
    test('when RetryConfig is null', () {
      final policy = RetryPolicy(null);

      expect(policy.shouldRetry(0), isFalse);
      expect(policy.shouldRetry(1), isFalse);
    });

    test('when max attempt is 0', () {
      final policy = RetryPolicy(
        RetryConfig(maxAttempts: 0),
      );

      expect(policy.shouldRetry(0), isFalse);
      expect(policy.shouldRetry(1), isFalse);
    });

    test('when max attempt is 10', () {
      final policy = RetryPolicy(
        RetryConfig(maxAttempts: 10),
      );

      expect(policy.shouldRetry(0), isTrue);
      expect(policy.shouldRetry(1), isTrue);

      expect(policy.shouldRetry(9), isTrue);
      expect(policy.shouldRetry(10), isFalse);
      expect(policy.shouldRetry(11), isFalse);
    });

    test('when retryCount is less than 0', () {
      final policy = RetryPolicy(
        RetryConfig(maxAttempts: 10),
      );

      expect(
        () => policy.shouldRetry(-1),
        throwsA(
          allOf(
            isA<ArgumentError>(),
            predicate((e) =>
                e.toString() ==
                'Invalid argument (retryCount): must be greater than or'
                    ' equal to 0: -1'),
          ),
        ),
      );
    });
  });

  group('.waitWithExponentialBackOff', () {
    test('when RetryConfig is null', () async {
      final policy = RetryPolicy(null);

      final startAt = DateTime.now();
      await policy.waitWithExponentialBackOff(0);
      final endAt = DateTime.now();

      // This means that waitWithBackOff was not executed.
      expect(endAt.difference(startAt).inSeconds == 0, isTrue);
    });

    test('when RetryConfig is not null', () async {
      final policy = RetryPolicy(
        RetryConfig(maxAttempts: 10),
      );

      final startAt = DateTime.now();
      await policy.waitWithExponentialBackOff(0);
      final endAt = DateTime.now();

      expect(endAt.difference(startAt).inSeconds, 10);
    });

    test('when interval is 5 seconds', () async {
      final policy = RetryPolicy(
        RetryConfig(
          maxAttempts: 10,
          intervalInSeconds: 5,
        ),
      );

      final startAt = DateTime.now();
      await policy.waitWithExponentialBackOff(0);
      final endAt = DateTime.now();

      expect(endAt.difference(startAt).inSeconds, 5);
    });

    test('when retryCount is less than 0', () async {
      final policy = RetryPolicy(
        RetryConfig(maxAttempts: 10),
      );

      expect(
        () => policy.waitWithExponentialBackOff(-1),
        throwsA(
          allOf(
            isA<ArgumentError>(),
            predicate((e) =>
                e.toString() ==
                'Invalid argument (retryCount): must be greater than or'
                    ' equal to 0: -1'),
          ),
        ),
      );
    });

    test('when retryCount is 3 without exponential back off', () async {
      final policy = RetryPolicy(
        RetryConfig(
          maxAttempts: 10,
          intervalInSeconds: 3,
        ),
      );

      final startAt = DateTime.now();
      await policy.waitWithExponentialBackOff(3);
      final endAt = DateTime.now();

      expect(endAt.difference(startAt).inSeconds, 3);
    });

    test('when retryCount is 3 with exponential back off', () async {
      final policy = RetryPolicy(
        RetryConfig(
          maxAttempts: 10,
          intervalInSeconds: 3,
          useExponentialBackOff: true,
        ),
      );

      final startAt = DateTime.now();

      //! intervalInSeconds(3) + retryCount(3) ^ 2 = 12
      await policy.waitWithExponentialBackOff(3);

      final endAt = DateTime.now();

      expect(endAt.difference(startAt).inSeconds, 12);
    });

    test('with complex case without exponential back off', () async {
      final int intervalInSeconds = 3;

      final policy = RetryPolicy(
        RetryConfig(
          maxAttempts: 10,
          intervalInSeconds: intervalInSeconds,
        ),
      );

      for (int retryCount = 0; retryCount < 4; retryCount++) {
        final startAt = DateTime.now();
        await policy.waitWithExponentialBackOff(retryCount);
        final endAt = DateTime.now();

        expect(endAt.difference(startAt).inSeconds, intervalInSeconds);
      }
    });

    test('with complex case with exponential back off', () async {
      final int intervalInSeconds = 3;

      final policy = RetryPolicy(
        RetryConfig(
          maxAttempts: 10,
          intervalInSeconds: intervalInSeconds,
          useExponentialBackOff: true,
        ),
      );

      for (int retryCount = 0; retryCount < 4; retryCount++) {
        final startAt = DateTime.now();
        await policy.waitWithExponentialBackOff(retryCount);
        final endAt = DateTime.now();

        expect(
          endAt.difference(startAt).inSeconds,
          intervalInSeconds + math.pow(retryCount, 2),
        );
      }
    });
  });
}
