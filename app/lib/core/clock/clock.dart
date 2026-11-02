/// 지금 시각 주입 (B-flutter.md §5.1).
///
/// 규칙 코드는 `DateTime.now()` 를 직접 부르지 않고 [Clock] 을 받는다.
/// 시간대 주입은 timezone 패키지를 넣는 2단계에서 더한다.
abstract interface class Clock {
  DateTime now();
}

/// 기기 시계.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// 테스트용 고정 시계. [advance] 로 앞으로 돌린다.
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration by) => _now = _now.add(by);
}
