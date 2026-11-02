# 할일앱 — 개발 규칙

Flutter 한 벌로 웹(PC·모바일)과 안드로이드 앱을 만든다. 서버는 Supabase.

## 1. 문서와 진실의 기준

| 문서 | 다루는 것 |
|---|---|
| `docs/spec.md` | 핵심 기능 규칙 §0~§11 |
| `docs/spec-ext.md` | 확장 기능 규칙 §12~§19 |
| `docs/00-shared-backend.md` | 서버(테이블·RLS·트리거·RPC·동기화), 클라이언트 공통 정책 1차 구현(§10, §11.8) |
| `docs/B-flutter.md` | Flutter 구조·모듈 배치·플랫폼 처리·개발 단계 |
| `docs/open-questions.md` | 명세에 없거나 모순인 것, 결정을 기다리는 것 |

- **명세가 진실의 기준이다. 코드는 명세를 따른다.** 코드와 명세가 다르면 코드를 고친다. 명세를 고쳐야 할 것 같으면 `docs/open-questions.md` 에 적고 묻는다. `docs/` 의 명세 파일은 사용자 허락 없이 고치지 않는다.
- 충돌을 푸는 우선순위:
  1. `spec-ext.md` §19.2 의 **"제안"** 칸
  2. `spec.md`·`spec-ext.md` 본문
  3. 플랫폼 문서(`00-shared-backend.md`, `B-flutter.md`)
- 화면 문구는 spec 에 적힌 원본 문구를 그대로 쓴다(B-flutter §0). 문구 속 `{앱 이름}` 은 임시로 **"할일앱"** 으로 둔다.

## 2. 태그 처리

| spec 표시 | 처리 |
|---|---|
| [확인], [확인: 보조 도구(…)], [확인: 웹 기준] | 규칙 그대로 구현한다. 그 규칙을 쓰는 모듈 안에 둔다 |
| [추정], [추정: smali 단서], [미확인], "앱에서 확인 필요" | 값·갈래를 **`app/lib/core/rules/policies/policies.dart` 한 곳**에 상수로 모은다. 각 상수 옆에 spec 위치(§번호)와 표시를 주석으로 단다 |
| (새로 정함) | 문서에 적힌 대로 구현한다 |

- 정책 상수의 1차 값은 `00-shared-backend.md` §10 표(§11.8 로 바뀐 줄 포함)를 따른다.
- 정책 값은 규칙 코드에 숫자·문자열로 다시 적지 않는다. 늘 `policies.dart` 의 상수를 가져다 쓴다.
- 주석 형식: `/// §5.13.4 체험 기간 [미확인] — 앱에서 확인 필요. 00 §10.`

## 3. 구조 (B-flutter.md §2)

```
app/                    Flutter 프로젝트 (안드로이드·웹)
  lib/app/              시작, 라우팅, 테마, 반응형 틀
  lib/core/rules/       공통 규칙 — 순수 Dart
  lib/core/rules/policies/policies.dart   바뀔 수 있는 값 한 곳
  lib/core/clock/       지금 시각·시간대 주입
  lib/core/errors/      spec §7.1 오류 코드
  lib/data/             remote(Supabase) · local(drift) · sync
  lib/features/         화면. 플랫폼을 모른다
  lib/platform/         플랫폼 차이는 여기서만 나눈다 (android/ · web/)
  lib/dev/              0단계 위험 확인용 임시 화면. 확인이 끝나면 지운다
  test/                 단위·위젯 테스트 (lib 와 같은 경로)
  integration_test/     F1~F13 흐름
supabase/               migrations, seed.sql, tests, functions (00 §1.1)
shared-testdata/        spec 예시표를 옮긴 테스트 케이스 JSON (00 §1.1)
shared-data/            holidays-kr.json 등 (00 §1.1)
```

- `lib/core/rules/` 는 Flutter·Supabase·drift·Riverpod·`dart:ui` 를 가져오지 않는다. `test/architecture/rules_purity_test.dart` 가 검사한다.
- 규칙 코드는 시계를 직접 읽지 않는다(`DateTime.now()` 금지). 시각은 인자로 받거나 `core/clock` 의 `Clock` 을 주입받는다.

## 4. 테스트

- 공통 규칙(반복·알림·필터 엔진·습관·디데이·정렬 등)은 **규칙마다 단위 테스트**를 둔다.
- 테스트 이름(또는 group 이름)에 **spec § 번호**를 넣는다. 예: `test('§5.2 예: 100ms 간격으로 계속 타이핑 → 150·300·…·2500', …)`
- spec 의 예시·표는 테스트 데이터로 옮긴다. 값은 spec 에서 그대로 가져오고 케이스마다 근거 §(예: `§5.9.6 A`)를 단다. 여러 클라이언트가 같이 쓸 표는 `shared-testdata/` JSON 으로 둔다(2단계부터).
- 공통 규칙 테스트는 Dart VM 과 Chrome 둘 다에서 돌린다(B-flutter §5.2). 날짜 테스트는 `Asia/Seoul` 과 서머타임이 있는 시간대 하나로 두 번 돌린다(시간대 패키지를 넣는 2단계부터).

명령 (`app/` 에서):

```sh
flutter analyze
flutter test                                   # VM
flutter test --platform chrome test/core       # 공통 규칙을 Chrome 에서
```

## 5. 작업 단위

- **B-flutter.md §6 의 단계 하나씩** 한다.
- 단계가 끝나면: `flutter analyze` 경고 0 → `flutter test` 통과 → git 커밋 → **멈추고 보고**한다.
- 다음 단계는 사용자가 **"go"** 라고 할 때 시작한다.
- 커밋 메시지: `N단계: 한 줄 요약` + 빈 줄 + 한 일 목록.
- 보고에 넣을 것: 만든·바꾼 파일, 실행 명령, 확인 방법, 남은 일·막힌 일, `open-questions.md` 에 새로 적은 것.

## 6. 금지

- `../myapp` 의 `analysis/`, `evidence/` 등 원본 분석 자료를 읽지 않는다.
- REA(리버스 엔지니어링 도구)를 쓰지 않는다.
- 원본 앱의 이름·로고·아이콘·그림·소리 파일을 쓰지 않는다. 새로 만들거나 무료 라이선스 자산을 쓰고 출처·라이선스를 남긴다.

## 7. 비밀값

- Supabase URL·키·DB 비밀번호는 `.env` 에만 둔다. `.env` 는 git 에 올리지 않는다(`.gitignore`). 예시는 `.env.example` 에 값 없이 둔다.
  - `app/.env` — 앱이 쓰는 값(URL, anon 키)만. `flutter run --dart-define-from-file=.env` 로 넣는다.
  - `.env`(저장소 맨 위) — 서버 작업에만 쓰는 값(DB 비밀번호 등). **앱 빌드에 넣지 않는다.**
- 값이 필요하면 사용자에게 넣어 달라고 말한다. 비밀값을 코드·로그·커밋 메시지에 적지 않는다.

## 8. 패키지·도구

- `B-flutter.md` 에 적힌 것(Riverpod, go_router, supabase_flutter, drift, workmanager, flutter_local_notifications, 포그라운드 서비스 플러그인, timezone, 표준 RRULE 패키지(테스트 비교용), flutter_test, integration_test 등)은 바로 써도 된다. 필요한 단계에서 넣는다.
- 그 밖의 패키지나 도구 설치는 **먼저 묻는다**. (`flutter create` 기본 템플릿의 `flutter_lints` 는 린트용으로 쓴다.)

## 9. 명세에 없거나 모순일 때

- 추측해서 진행하지 않는다. `docs/open-questions.md` 에 번호·출처(§)·내용·막히는지를 적는다.
- 진행에 막히면 멈추고 묻는다. 막히지 않으면(다른 일을 먼저 할 수 있으면) 그 일을 하고 보고 때 알린다.
