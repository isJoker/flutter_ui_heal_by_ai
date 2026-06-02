import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_demo/components/user_card.dart';
import 'package:flutter_demo/ui_heal/compare_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// UserCard Golden Test — Figma 还原度验证
void main() {
  final engine = CompareEngine(
    ssimThreshold: 0.95,
    pixelDiffThreshold: 0.002,
    colorTolerance: 10,
  );

  final projectRoot = Directory.current.path;
  final baselinesDir = '$projectRoot/test/goldens/baselines';
  final actualDir = '$projectRoot/test/goldens/actual';
  final diffDir = '$projectRoot/test/goldens/diff';

  setUpAll(() {
    Directory(actualDir).createSync(recursive: true);
    Directory(diffDir).createSync(recursive: true);
  });

  group('UserCard Figma Fidelity Tests', () {
    testWidgets('Standard user card matches Figma', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserCard(
                name: 'Zhang San',
                email: 'zhangsan@example.com',
                avatarColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(UserCard),
        matchesGoldenFile('test/goldens/actual/user_card_standard.png'),
      );

      final baseline = '$baselinesDir/user_card_standard.png';
      final actual = '$actualDir/user_card_standard.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/user_card_standard_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });

    testWidgets('Long email user card matches Figma', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserCard(
                name: 'Alexander Hamilton',
                email: 'alexander.hamilton.very.long.email@enterprise-company.com',
                avatarColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(UserCard),
        matchesGoldenFile('test/goldens/actual/user_card_long_email.png'),
      );

      final baseline = '$baselinesDir/user_card_long_email.png';
      final actual = '$actualDir/user_card_long_email.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/user_card_long_email_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });
  });
}
