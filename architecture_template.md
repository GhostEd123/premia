# Flutter App Architecture Template

A project-agnostic blueprint: feature-first, four-layer, Riverpod, Dio, go_router,
secure storage. Replace `<app>` / `<feature>` with real names. Everything here
is derived from a working production-style app; where a rule is a *convention*
rather than a tool-enforced one, it says so.

---

## 1. Stack at a glance

| Concern | Choice | Notes |
|---|---|---|
| Language / SDK | Dart 3.x, Flutter | Material 3 |
| State management | `flutter_riverpod` (2.x) | Hand-written `Notifier` / `AsyncNotifier`; no codegen required |
| Routing | `go_router` | Single `Provider<GoRouter>`, `StatefulShellRoute.indexedStack` for bottom-nav tabs |
| Networking | `dio` + `pretty_dio_logger` | Wrapped by one `HttpService` |
| Secure storage | `flutter_secure_storage` | Tokens, PIN flags, device IDs |
| Plain storage | `shared_preferences` | Non-sensitive flags only (e.g. first launch) |
| Value equality | `equatable` | Domain models |
| Biometrics | `local_auth` | App-lock unlock |
| Utilities | `intl`, `uuid`, `crypto`, `logger`, `device_info_plus` | |
| Linting | `flutter_lints` + stricter rules (§11) | |
| Testing | `flutter_test`, `mocktail` | Providers overridden with fakes |
| Optional (declared, adopt only if needed) | `freezed`, `json_serializable`, `riverpod_generator`, `build_runner` | Default style is hand-written, so nothing to regenerate |

---

## 2. Folder layout

```
lib/
├── main.dart                 # ensureInitialized + ProviderScope + runApp
├── app.dart                  # MaterialApp.router (watches router provider, applies theme)
├── core/                     # shared plumbing — knows NOTHING about features
│   ├── constants/            # app_constants.dart (base URL via --dart-define, app name, global consts)
│   ├── network/              # http_service.dart, api_exception.dart, *_interceptor.dart
│   ├── storage/              # storage_service.dart
│   ├── routing/              # app_router.dart (RoutePaths + appRouterProvider)
│   ├── theme/                # app_colors.dart, app_dimens.dart, app_theme.dart
│   ├── utils/                # pure helper functions (formatting, phone, password strength)
│   └── widgets/              # generic reusable UI (buttons, fields, loaders, snackbar helper)
└── features/
    └── <feature>/
        ├── domain/           # "what things ARE"   — plain models
        ├── data/             # "how to GET things" — repository
        ├── application/      # "what to DO"        — notifiers, state, validators, mailbox providers
        ├── presentation/     # "what it LOOKS like"— screens
        │   └── widgets/      # feature-local reusable widgets (or sibling `widgets/` folder)
        └── (sub-folders in presentation/ when a multi-step flow gets > ~8 screens)
test/
└── features/<feature>/       # mirrors lib/features
assets/
├── images/  icons/  fonts/   # declared in pubspec
```

Features are flat siblings. A feature may be missing layers it does not need
(a purely static feature can be `presentation/` only; a read-only one may skip
`domain/`). A `main_shell` feature owns the bottom-nav scaffold and has only
`presentation/`.

### Dependency rule (the one rule everything else follows)

```
presentation → application → data → domain
                    ↑
        core (imported by anyone, imports no feature*)
```

- Never import backwards (repository ↛ notifier, domain ↛ anything).
- Features should not import another feature's `presentation/`. Cross-feature
  reads go through `application/` providers (e.g. a shared `sessionProvider`) or
  shared domain models.
- *Pragmatic exception to document, not copy blindly: the HTTP provider needs to
  clear session state and redirect on expiry, so it imports the session provider
  and router. Keep this to one place (the `onSessionExpired` callback).

---

## 3. Layers

### domain
Immutable plain Dart classes, `equatable`, enums, tiny derived getters. No
Flutter, no Riverpod, no network. JSON mapping does **not** live here.

### data
One repository class per feature, one `Provider<XRepository>`:

```dart
class XRepository {
  XRepository(this._http, [this._storage]);
  final HttpService _http;

  Future<Thing> fetchThing() async {
    final raw = await _http.get('/things/1');
    return _thingFromJson(_unwrap(raw));
  }
  // private helpers at file bottom: _unwrap, _xFromJson, enum<->API string
}

final xRepositoryProvider = Provider<XRepository>(
  (ref) => XRepository(ref.watch(httpServiceProvider)),
);
```

- Builds paths and request bodies, maps JSON → domain in private helpers
  (tolerant of `{data: ...}` wrapping and key variants).
- API naming (snake_case etc.) stops at this file's edge.
- Concrete class only — no interface/impl pair, no `usecases/`, no DTO layer,
  until there is a second implementation that justifies it.
- Persists session artefacts (e.g. tokens) *inside* the repository before
  returning, so notifiers never touch raw tokens.

### application
- **One notifier per screen/flow step**, plus **one repository shared** by all.
- State class lives in the same file as its notifier: hand-written, immutable,
  `copyWith` with a `_keep` sentinel for nullable fields (§6).
- `StateProvider` "mailboxes" carry values between notifiers (`pendingXProvider`,
  `sessionProvider`). Notifiers never call each other and never read each
  other's state.
- `validators.dart`: pure static functions returning `String?` (null = valid).
- Notifiers **only mutate `state`**. They never navigate and never show UI.

### presentation
- Screens are `ConsumerWidget` (or `ConsumerStatefulWidget` when a
  controller/animation is unavoidable).
- `ref.watch` to draw, `ref.read(...notifier)` for actions, `ref.listen` for
  side effects (navigation, snackbars) guarded with `previous`/`next`
  comparisons.
- Text input lives in the notifier (`onChanged` up, `errorText` down); avoid
  `TextEditingController` unless needed (e.g. formatting, OTP widgets).
- Screens never touch the network or storage directly.

---

## 4. State management (Riverpod)

| Need | Provider type |
|---|---|
| Service / repository / router (built once, no changing state) | `Provider<T>` |
| Screen form state + actions (sync) | `NotifierProvider<N, S>` (or `.autoDispose` for per-visit state) |
| Server data loaded on entry (lists, profile) | `AsyncNotifierProvider.autoDispose<N, S>` — `build()` fetches |
| Tiny derived/fetched value (badge count) | `FutureProvider.autoDispose<T>` that `ref.watch`es its source so invalidation cascades |
| Shared dumb value, no logic | `StateProvider<T?>` (session user, pending flow data) |

Conventions:

- Provider declared at the bottom of the file that defines the class:
  `final xNotifierProvider = NotifierProvider<XNotifier, XState>(XNotifier.new);`
- Dependencies are resolved with `ref.watch(otherProvider)` inside provider
  factories and `ref.read` inside notifier methods.
- `build()` produces the initial state; it must not assign `state` synchronously.
  Timers may be started there, with `ref.onDispose(() => _timer?.cancel())`.
- Derived values are getters on the state class (`canResend`, `unreadCount`) —
  not stored fields.
- Use `AutoDispose` for anything that should reset when the screen is left
  (forms, flows); keep non-auto-dispose for session-lived data.
- Mutations of lists after a server action: optimistic local `copyWith`, or
  `ref.invalidate(...)` to refetch.
- Tests: override `httpServiceProvider` / `storageServiceProvider` /
  repository providers with `mocktail` fakes in a `ProviderContainer`.

### State class template

```dart
const Object _keep = Object();

class XState {
  const XState({this.value = '', this.valueError, this.isSubmitting = false,
      this.success = false, this.submitError});
  final String value;
  final String? valueError;
  final bool isSubmitting;
  final bool success;
  final String? submitError;

  XState copyWith({
    String? value,
    Object? valueError = _keep,
    bool? isSubmitting,
    bool? success,
    Object? submitError = _keep,
  }) => XState(
        value: value ?? this.value,
        valueError: valueError == _keep ? this.valueError : valueError as String?,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        success: success ?? this.success,
        submitError: submitError == _keep ? this.submitError : submitError as String?,
      );
}
```

### Notifier action template

```dart
Future<void> submit() async {
  final err = Validators.something(state.value);
  state = state.copyWith(valueError: err, submitError: null, success: false);
  if (err != null) return;                      // network never touched

  state = state.copyWith(isSubmitting: true);
  try {
    await ref.read(xRepositoryProvider).doIt(state.value);
    state = state.copyWith(isSubmitting: false, success: true);
  } on ApiException catch (e) {
    state = state.copyWith(isSubmitting: false, submitError: e.message);
  }
}
```

### Screen side-effect template

```dart
ref.listen(xNotifierProvider, (prev, next) {
  if (next.success && prev?.success != true) context.push(RoutePaths.next);
  if (next.submitError != null && next.submitError != prev?.submitError) {
    AppSnackbar.show(context, next.submitError!);
  }
});
```

For terminal steps of a flow use `context.go` (not `push`) so Back doesn't
re-enter a half-finished flow.

---

## 5. Networking

**Single choke point:** one `HttpService` is the only class that performs
requests. Public API: `get / post / patch / delete` (+ `postWithIdempotency`)
all funnel into a private `_send`.

`_send` does, once each:
1. Applies base URL (`String.fromEnvironment('API_BASE_URL', defaultValue: …)`,
   override with `--dart-define`).
2. Reads tokens from `StorageService` and attaches headers
   (`Authorization: Bearer`, optional device-token header, optional
   `Idempotency-Key`). Missing token → header omitted, so pre-login calls use
   the same path.
3. Applies timeouts (connect ~15s, receive ~60s).
4. Converts `DioException` → `ApiException`.

Interceptors (registered in `_buildDio`):
- `PrettyDioLogger` inside `assert(() {…; return true;}())` → stripped from
  release builds, so tokens cannot leak via logs.
- `TokenRefreshInterceptor extends QueuedInterceptorsWrapper`: on
  401/403/expired-440 invokes `onSessionExpired` (clear session + tokens +
  redirect to login) and rejects. Queued variant prevents concurrent handlers
  racing. (Can be extended to a real refresh-and-retry.)

`ApiException`:
- The only error type upstream code catches. Carries a user-safe `message`,
  `statusCode`, `body`; `toString()` returns the bare message.
- `fromDioException` maps: timeouts, connection errors, server-provided
  `message`/`error`/`detail`, 401/403, other 4xx/5xx, unknown → fixed friendly strings.
- HTTP status is the success/failure signal: a repository method returning
  normally means success.

---

## 6. Storage

One `StorageService` class is the only code that touches storage. Typed
read/write/delete methods per key; keys are `static const` with an app prefix.

| Data | Where |
|---|---|
| Access / refresh tokens, device ID & token, user identifier, PIN-set flag, biometric flag, local file paths | `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) |
| Non-sensitive flags (first-launch/onboarding seen) | `shared_preferences` |
| Current user object | In memory only (`sessionProvider`), rehydrated from API |
| Everything on logout | `StorageService.clear()` → `deleteAll()` |

Provided via `Provider<StorageService>`; swap with a fake in tests. A helper
can decode a JWT `exp` locally to decide whether a refresh token is worth using
(fails open — the server is the authority).

---

## 7. Routing

- `RoutePaths` abstract class of `static const String` — every path in one place;
  screens never use raw strings.
- `appRouterProvider = Provider<GoRouter>`; `app.dart` watches it.
- `initialLocation` = splash; splash decides onboarding / login / PIN lock /
  home based on stored state.
- Flat `GoRoute` list for pre-auth and flow screens, grouped by comment banners.
- `StatefulShellRoute.indexedStack` with one `StatefulShellBranch` + dedicated
  `navigatorKey` per bottom tab; nested sub-routes under each tab root.
- Complex arguments passed via `state.extra`; simple ones via query params
  (`state.uri.queryParameters`) with `tryParse` fallbacks.
- Paths nest by flow: `/register`, `/register/otp`, `/reset/code`.

---

## 8. Theme & UI system

- `AppColors` (brand constants), `AppDimens` (gutter, control height, radii),
  `AppTheme.light` (single `ThemeData`; buttons, inputs, cards styled once).
- Custom font family declared once in `pubspec.yaml` with all weights under
  one `family` entry.
- `core/widgets/`: primary/secondary button (loading-aware, disabled while
  loading), text/password/phone fields (error-string contract), loader,
  snackbar helper, step progress header, list menu item, banner/notice,
  numpad, success seal, etc. Screens compose these; they do not hard-code styling.
- Generic loading/error states (`LoadingIndicator`, `ErrorState`) for list features.

---

## 9. Security measures

1. **Secrets in secure storage only** — tokens and sensitive flags never in
   `SharedPreferences`, never in Riverpod state visible to widgets (state holds
   the `User`, not the token).
2. **Token attached in one place** (`HttpService`), persisted in one place
   (repository → `StorageService`).
3. **Session expiry handling** — interceptor clears tokens + session state and
   redirects to login on 401/403/expired.
4. **Release-safe logging** — HTTP logger only under `assert`; `avoid_print` lint
   enabled (don't leave `print` of options/headers/tokens in `HttpService`).
5. **Idempotency keys** (UUID v4) on non-repeatable POSTs (OTP send, top-ups);
   reusable across retries of the same operation.
6. **Device binding** — stable per-install device ID (UUID, secure storage)
   registered with the backend; returned device token sent as a header.
7. **App lock** — PIN (set + confirm, trivial-sequence rejection, attempt cap
   that resets the flow) with optional biometric unlock via `local_auth`
   (`pin_lock` route, biometric check deferred to first frame, preference cached
   in secure storage). Hash PINs (`crypto`) before persisting; never store raw.
8. **Input validation** at the notifier before any request (pure validators;
   password-strength util).
9. **Error hygiene** — only `ApiException.message` reaches the UI; no raw
   exception text or stack traces.
10. **Double-submit protection** — buttons disable while `isSubmitting`.
11. **Environment config** via `--dart-define`, not committed secrets.
12. **Full wipe on logout** (`deleteAll`), with logout clearing storage in a
    `finally` so a failed network call can't leave a stale session.
13. **Release hardening to add per project**: certificate pinning, root/jailbreak
    checks, screenshot blocking on sensitive screens, obfuscation
    (`--obfuscate --split-debug-info`).

---

## 10. Code style & conventions

- **Naming:** files `snake_case.dart`; suffixes `_screen`, `_notifier`,
  `_repository`, `_provider`, `_model`/entity name, `_service`. Notifier file
  holds `XState` + `XNotifier` + `xNotifierProvider`.
- **Imports:** relative imports within `lib/`, grouped: dart → package → project;
  sorted.
- **Documentation:** `///` doc comment on every service, repository, notifier and
  non-obvious helper explaining *why* and who reads/writes it. Section banners
  (`// --- Section ---`) in long files. `TODO(area):` tags for placeholders.
- **Immutability:** `const` constructors, `final` fields, `copyWith`, no mutation.
- **Quotes/commas:** single quotes, trailing commas everywhere (formatter-friendly).
- **Private helpers** at bottom of file with leading `_`.
- **Abstract constant holders:** `abstract class X { X._(); static const … }`
  (`AppConstants`, `AppDimens`, `RoutePaths`).
- **Errors:** repositories throw `ApiException`; notifiers `on ApiException catch`.
  No `catch (e)` with raw display.
- **Explicit over clever:** no use-cases, no generic base classes, no DI
  container beyond Riverpod.
- **One responsibility per file**; one notifier per screen.
- **Tolerant parsing** at the data edge, with a single fallback error
  (`Unexpected response from the server.`).

---

## 11. Tooling

`analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    prefer_single_quotes: true
    always_declare_return_types: true
    avoid_print: true
    require_trailing_commas: true
    unawaited_futures: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
analyzer:
  exclude: ["**/*.g.dart", "**/*.freezed.dart", "build/**", android/**, ios/**, web/**, windows/**, macos/**, linux/**]
```

Run: `flutter run --dart-define=API_BASE_URL=https://<env>/api/v1/`.

---

## 12. Startup sequence

```
main(): WidgetsFlutterBinding.ensureInitialized() → runApp(ProviderScope(ChildApp))
ChildApp: ref.watch(appRouterProvider) → MaterialApp.router(theme: AppTheme.light)
Splash: StorageService → first launch? → onboarding
                       → no valid refresh token? → login
                       → has PIN/biometric? → pin-lock → home shell
```

---

## 13. Adding a feature (checklist)

1. `domain/<thing>.dart` — equatable model(s).
2. `data/<feature>_repository.dart` — takes `HttpService`; provider; private mappers.
3. `application/<screen>_notifier.dart` — state + `copyWith(_keep)` + notifier + provider;
   `validators.dart` if needed.
4. `presentation/<screen>_screen.dart` — `ConsumerWidget`, `watch` / `listen`.
5. Add paths to `RoutePaths`, routes to `appRouterProvider` (inside a shell branch if it is a tab).
6. Mailbox provider only if data must cross notifiers.
7. Tests in `test/features/<feature>/` with overridden providers.

Stays in `core/` (never duplicated): HTTP client, exception type, storage, router,
theme, generic widgets, utils. Per feature: repository, notifiers, state, screens.

**Two invariants:** nothing but `HttpService` performs a request;
nothing but a screen navigates or shows a snackbar.

---

## 14. Debugging approach

Every bug lives in one layer. Bisect: **UI** (watch vs read, listen guards) →
**notifier state** (validation, flags) → **repository mapping** (keys, unwrap) →
**raw HTTP** (logger / `_send`). Common traps: assigning `state` inside `build()`,
`ref.read` where `ref.watch` is needed, missing `ProviderScope`, loose
`ref.listen` comparisons causing double navigation/snackbars.
