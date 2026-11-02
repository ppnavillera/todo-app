/// spec.md §5.2 자동 저장 지연 [확인].
///
/// - 첫 요청은 150ms.
/// - 직전 요청과 간격이 500ms 이하면 지연을 두 배로, 2500ms 이상이 되면 2500ms 로 고정.
/// - 직전 요청과 간격이 500ms 를 넘으면 150ms 로 되돌린다.
///
/// "요청"은 제목이나 본문이 실제로 바뀐 때마다 한 번이다(§5.2). 이미 예약된
/// 저장이 있어 새로 예약하지 않는 요청도 간격 계산에는 든다
/// (docs/open-questions.md Q1).
class AutosaveDelay {
  static const Duration initial = Duration(milliseconds: 150);
  static const Duration burstGap = Duration(milliseconds: 500);
  static const Duration max = Duration(milliseconds: 2500);

  DateTime? _lastRequestAt;
  Duration _delay = initial;

  /// [at] 에 들어온 요청의 지연을 돌려준다.
  Duration next(DateTime at) {
    final last = _lastRequestAt;
    _lastRequestAt = at;
    if (last == null || at.difference(last) > burstGap) {
      _delay = initial;
    } else {
      final doubled = _delay * 2;
      _delay = doubled >= max ? max : doubled;
    }
    return _delay;
  }
}
