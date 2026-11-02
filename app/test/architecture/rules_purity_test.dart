@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B-flutter §5.1 core/rules 는 Flutter·Supabase·drift·Riverpod·dart:ui 를 가져오지 않는다', () {
    final banned = RegExp(
      r'''^\s*(import|export)\s+['"](dart:ui|package:(flutter|flutter_test|flutter_riverpod|riverpod|supabase|supabase_flutter|drift|go_router)/)''',
      multiLine: true,
    );
    final files = Directory('lib/core/rules')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final offenders = [
      for (final f in files)
        if (banned.hasMatch(f.readAsStringSync())) f.path,
    ];

    expect(files, isNotEmpty);
    expect(offenders, isEmpty, reason: 'core/rules 는 순수 Dart 여야 한다 (CLAUDE.md §3)');
  });

  test('CLAUDE.md §3 core/rules 는 시계를 직접 읽지 않는다 (DateTime.now 금지)', () {
    final files = Directory('lib/core/rules')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final offenders = [
      for (final f in files)
        if (f.readAsStringSync().contains('DateTime.now(')) f.path,
    ];

    expect(offenders, isEmpty);
  });
}
