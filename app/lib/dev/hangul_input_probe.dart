import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/clock/clock.dart';
import '../core/rules/autosave/autosave.dart';

/// 0단계 위험 확인용 임시 화면 (B-flutter.md §6 0단계, §7 첫 줄).
///
/// Flutter 웹·안드로이드에서 한글 입력(조합 중 글자, 띄어쓰기, 백스페이스,
/// 엔터로 저장)과 조합 중 자동 저장 예약(spec.md §5.2)을 눈으로 확인한다.
/// 확인이 끝나면 `lib/dev/` 째로 지운다.
class HangulInputProbePage extends StatefulWidget {
  const HangulInputProbePage({super.key, this.clock = const SystemClock()});

  final Clock clock;

  @override
  State<HangulInputProbePage> createState() => _HangulInputProbePageState();
}

class _SaveRecord {
  const _SaveRecord({
    required this.trigger,
    required this.title,
    required this.body,
    required this.titleComposing,
    required this.bodyComposing,
  });

  final String trigger;
  final String title;
  final String body;
  final bool titleComposing;
  final bool bodyComposing;
}

const String _steps = '''
1. 조합: 제목에 "안녕하세요 반갑습니다" — 조합 중 글자가 칸 안에 바로 보이고, 커서가 그 글자 뒤에 있는가.
2. 띄어쓰기: "가 나" — 앞 글자가 확정되고 빈칸이 한 번만 들어가는가.
3. 백스페이스: "한글"의 '글'을 조합하는 중(ㄱ→그→글)에 누르기 — 낱자 단위로 지워지는가(글→그→ㄱ→없음). 확정된 글자는 한 글자씩 지워지는가.
4. 엔터로 저장: 마지막 글자를 조합 중인 채로 엔터 — '저장 기록'에 마지막 글자까지 들어갔는가. 글자가 두 번 들어가거나 빠지지 않았는가.
5. 저장 뒤 비우기(켜짐): 엔터 뒤 칸이 비고, 다음에 친 첫 글자가 앞 글자와 섞이지 않는가.
6. 조합 중 자동 저장: 한 글자를 조합하다 멈추기 — '자동 저장' 기록이 [조합 중]으로 남아도 칸의 글자가 깨지지 않는가.
7. 본문: 엔터 = 줄바꿈. 조합 중 엔터에서 글자를 잃지 않는가.
8. 가운데 끼워 넣기, 글자를 골라 덮어쓰기, 한/영 전환 직후 입력.''';

class _HangulInputProbePageState extends State<HangulInputProbePage> {
  static const int _logLimit = 200;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final AutosaveDelay _autosaveDelay = AutosaveDelay();
  final List<_SaveRecord> _saves = [];
  final List<String> _log = [];

  Timer? _pendingAutosave;
  String _lastTitleText = '';
  String _lastBodyText = '';
  bool _clearAfterEnter = true;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => _onValueChanged(isTitle: true));
    _body.addListener(() => _onValueChanged(isTitle: false));
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _pendingAutosave?.cancel();
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  // ── 기록 ────────────────────────────────────────────────────────────

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final repeat = event is KeyRepeatEvent ? ' (반복)' : '';
      _addLog('키 ${_keyName(event.logicalKey)}$repeat');
    }
    return false; // 입력 처리는 막지 않는다.
  }

  void _onValueChanged({required bool isTitle}) {
    final value = isTitle ? _title.value : _body.value;
    final last = isTitle ? _lastTitleText : _lastBodyText;
    final changed = value.text != last;
    _addLog(
      '${isTitle ? '제목' : '본문'} ${_describe(value)}'
      '${changed ? '' : ' — 글자 그대로(커서·조합만 바뀜)'}',
    );
    if (!changed) {
      return;
    }
    if (isTitle) {
      _lastTitleText = value.text;
    } else {
      _lastBodyText = value.text;
    }
    _requestAutosave();
  }

  /// spec.md §5.2: 바뀌었을 때만 예약, 이미 예약돼 있으면 새로 예약하지 않음,
  /// 실행 때 그 시점의 값을 저장(정책 autosaveSavesValueAtRunTime).
  void _requestAutosave() {
    final delay = _autosaveDelay.next(widget.clock.now());
    if (_pendingAutosave != null) {
      _addLog('  자동 저장 요청 ${delay.inMilliseconds}ms — 이미 예약돼 있어 새로 예약하지 않음');
      return;
    }
    _addLog('  자동 저장 예약: ${delay.inMilliseconds}ms 뒤');
    _pendingAutosave = Timer(delay, () {
      _pendingAutosave = null;
      _record('자동 저장');
    });
  }

  void _onTitleSubmitted(String _) {
    _record('엔터');
    if (_clearAfterEnter) {
      // 저장한 뒤의 빈 칸은 "바뀜"으로 치지 않는다(새 할 일을 시작하는 것과 같다).
      _lastTitleText = '';
      _title.clear();
    }
    _titleFocus.requestFocus();
  }

  void _record(String trigger) {
    if (!mounted) {
      return;
    }
    final record = _SaveRecord(
      trigger: trigger,
      title: _title.text,
      body: _body.text,
      titleComposing: _isComposing(_title.value),
      bodyComposing: _isComposing(_body.value),
    );
    setState(() => _saves.insert(0, record));
    _addLog('★ $trigger: 제목 "${record.title}"${record.titleComposing ? ' [조합 중]' : ''}');
  }

  void _addLog(String line) {
    if (!mounted) {
      return;
    }
    final t = widget.clock.now();
    final stamp = '${_two(t.minute)}:${_two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    setState(() {
      _log.insert(0, '$stamp  $line');
      if (_log.length > _logLimit) {
        _log.removeRange(_logLimit, _log.length);
      }
    });
  }

  void _clearRecords() {
    setState(() {
      _saves.clear();
      _log.clear();
    });
  }

  // ── 표시 도우미 ──────────────────────────────────────────────────────

  static String _two(int n) => n.toString().padLeft(2, '0');

  static bool _isComposing(TextEditingValue v) =>
      v.composing.isValid && !v.composing.isCollapsed;

  static String _keyName(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label == ' ') {
      return 'Space';
    }
    if (label.isNotEmpty) {
      return label;
    }
    return key.debugName ?? '0x${key.keyId.toRadixString(16)}';
  }

  static String _describe(TextEditingValue v) {
    final sel = v.selection;
    final cursor = sel.isCollapsed ? '${sel.baseOffset}' : '${sel.start}~${sel.end}';
    var composing = '없음';
    if (_isComposing(v)) {
      final c = v.composing;
      final inside = c.end <= v.text.length ? c.textInside(v.text) : '(범위 밖!)';
      composing = '${c.start}~${c.end} "$inside"';
    }
    return '"${v.text}" (${v.text.length}자) 커서 $cursor 조합 $composing';
  }

  /// 완성형 음절과 낱자(자모)의 개수. 조합이 끝났는데 낱자가 남으면 문제다.
  static String _composition(String s) {
    var syllables = 0;
    var jamo = 0;
    var other = 0;
    for (final r in s.runes) {
      if (r >= 0xAC00 && r <= 0xD7A3) {
        syllables++;
      } else if ((r >= 0x1100 && r <= 0x11FF) || (r >= 0x3130 && r <= 0x318F)) {
        jamo++;
      } else {
        other++;
      }
    }
    return '완성형 $syllables · 낱자 $jamo · 그 밖 $other';
  }

  static String _codePoints(String s) => s.runes
      .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
      .join(' ');

  // ── 화면 ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    final titleValue = _title.value;
    final bodyValue = _body.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('0단계 · 한글 입력 확인'),
        actions: [
          IconButton(
            tooltip: '기록 지우기',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearRecords,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('해 볼 것', style: theme.textTheme.titleMedium),
            initiallyExpanded: true,
            children: const [Align(alignment: Alignment.centerLeft, child: Text(_steps))],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            focusNode: _titleFocus,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '제목 (엔터 = 저장)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _onTitleSubmitted,
            onEditingComplete: () {}, // 엔터 뒤에도 입력칸에 머문다.
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('엔터로 저장한 뒤 제목 칸 비우기'),
            value: _clearAfterEnter,
            onChanged: (v) => setState(() => _clearAfterEnter = v),
          ),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: '본문 (엔터 = 줄바꿈)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('지금 상태', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          SelectableText(
            '제목  ${_describe(titleValue)}\n'
            '      ${_composition(titleValue.text)}\n'
            '      ${_codePoints(titleValue.text)}\n'
            '본문  ${_composition(bodyValue.text)} · 줄 ${'\n'.allMatches(bodyValue.text).length + 1}'
            ' · 조합 ${_isComposing(bodyValue) ? '중' : '없음'}',
            style: mono,
          ),
          const SizedBox(height: 16),
          Text('저장 기록 (${_saves.length})', style: theme.textTheme.titleMedium),
          if (_saves.isEmpty) const Text('아직 없음'),
          for (final s in _saves)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(s.trigger == '엔터' ? Icons.keyboard_return : Icons.save_outlined),
              title: Text('${s.trigger} · 제목 "${s.title}"'),
              subtitle: Text(
                '${_composition(s.title)} · 본문 ${s.body.length}자'
                ' · 조합 중: 제목 ${s.titleComposing ? '예' : '아니오'}, 본문 ${s.bodyComposing ? '예' : '아니오'}',
              ),
            ),
          const SizedBox(height: 16),
          Text('입력 기록 (최근 $_logLimit줄, 새 것이 위)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          SelectableText(_log.isEmpty ? '아직 없음' : _log.join('\n'), style: mono),
        ],
      ),
    );
  }
}
