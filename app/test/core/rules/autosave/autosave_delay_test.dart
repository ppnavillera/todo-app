import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/rules/autosave/autosave_delay.dart';

/// [gapsMs] 간격으로 요청을 넣고 요청마다 받은 지연(ms)을 돌려준다.
List<int> delaysFor(List<int> gapsMs) {
  final delay = AutosaveDelay();
  var at = DateTime.utc(2026, 11, 2, 9);
  final result = <int>[];
  for (final gap in gapsMs) {
    at = at.add(Duration(milliseconds: gap));
    result.add(delay.next(at).inMilliseconds);
  }
  return result;
}

void main() {
  group('§5.2 자동 저장 지연', () {
    test('§5.2 예: 100ms 간격으로 계속 타이핑 → 150·300·600·1200·2400·2500(상한)', () {
      // spec.md §5.2 의 예 (손 계산) 그대로.
      expect(
        delaysFor([0, 100, 100, 100, 100, 100]),
        [150, 300, 600, 1200, 2400, 2500],
      );
    });

    test('§5.2 2500ms 에 닿으면 계속 2500ms 로 고정', () {
      expect(delaysFor([0, 100, 100, 100, 100, 100, 100, 100]).skip(5), [2500, 2500, 2500]);
    });

    test('§5.2 첫 요청은 150ms', () {
      expect(delaysFor([0]), [150]);
    });

    test('§5.2 간격이 500ms 이하면 두 배 — 경계 500ms 는 두 배', () {
      expect(delaysFor([0, 500]), [150, 300]);
    });

    test('§5.2 간격이 500ms 를 넘으면 150ms 로 되돌린다 — 경계 501ms', () {
      expect(delaysFor([0, 100, 100, 501]), [150, 300, 600, 150]);
    });
  });
}
