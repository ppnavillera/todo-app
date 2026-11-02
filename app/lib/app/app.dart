import 'package:flutter/material.dart';

import '../dev/hangul_input_probe.dart';

/// 앱 뿌리. 라우팅(go_router)·반응형 틀은 4단계에서 붙인다.
///
/// 0단계에서는 한글 입력 확인 화면만 띄운다.
class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '할일앱',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HangulInputProbePage(),
    );
  }
}
