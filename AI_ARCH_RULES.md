# AI_ARCH_RULES

> SYSTEM INSTRUCTION FOR AI AGENTS: When generating, modifying, or refactoring code in this project, you MUST strictly adhere to the patterns defined in `architecture_template.md`. Do not introduce MVC, MVVM, or other architectural patterns not explicitly defined in the template. Every feature must be strictly compartmentalized into `domain`, `data`, and `application` layers. Do not create or modify any `presentation` (UI/Screens) layers unless explicitly authorized by the human user. Every edit MUST also be logged in `CHANGELOG.md` under the date of modification with explanations of what was added/modified and how it affects the general project. Failure to follow this layered architecture and changelog tracking will break the project's structural integrity.

## Project-specific clarifications (authorized by the human user)

These refine `architecture_template.md` for this project. Where they conflict with the template, **this section wins**.

0. **Scope:** this is the consumer (ticket-holder) app only. Admin functionality (admin login, staff, film CRUD, analytics) is intentionally **not** in the app; do not add it. The payment provider is **TransactPay** (the backend owns the checkout and webhooks; the app only opens `paymentUrl`).

1. **Layers per feature:** `domain/`, `data/`, `application/`. A `presentation/` folder exists ONLY for the screens the human user has authorized: the **single-ticket flow** (Marquee, film details, upcoming film, waitlist, checkout, payment pending, enter-link, player). Do not add or change any other screens without explicit authorization. Presentation depends on `application/` (and domain entities) only; it never imports `data/` or performs HTTP.
2. **domain/** — entities (`equatable`), repository **interfaces** (abstract classes), use cases. Pure Dart; may import only `dart:*`, `equatable`, and `core/` pure-Dart types (e.g. `ApiException`). Never imports `data/`, `application/`, Flutter, Dio or Riverpod.
3. **data/** — repository implementations, DTOs (`data/models/*_dto.dart`, JSON ⇄ entity mapping), API clients. Depends on `domain/` and `core/network`. API naming (snake_case, `_id`, …) stops here.
4. **application/** — Riverpod notifiers/state, use-case providers. Depends on `domain/` only. It declares `xRepositoryProvider` typed to the domain interface (throws `UnimplementedError` by default).
5. **Composition root:** `lib/composition_root.dart` is the _only_ place that binds data implementations to domain interfaces (via provider overrides passed to `ProviderScope` in `main.dart`).
6. Only `HttpService` (`core/network`) performs HTTP requests. Repositories throw `ApiException`; notifiers `on ApiException catch`.
7. Notifiers only mutate `state`; they never navigate or show UI.
8. Features must not import another feature's `data/` or `application/`. Sharing domain entities (e.g. `Film`) across features is allowed.
9. Style: single quotes, trailing commas, `///` docs on services/repositories/notifiers, relative imports.
10. **Security plumbing lives in `core/` only** (`core/security/`): keystore-backed cookie jar, per-install device id (`X-Device-Id`), certificate pinning (`--dart-define=PINNED_CERT_SHA256`), screen protection. Never log requests/cookies/tokens; keep HTTPS-only in release. Debug logs for endpoint payloads/responses use `PrettyDioLogger` guarded under `assert`.
11. **Mandatory Change Tracking in `CHANGELOG.md`:** Every AI agent that modifies, adds, or refactors code in this codebase MUST record the changes in `CHANGELOG.md` under the date of the change (format: `DD/MM/YY` or `YYYY-MM-DD`). Every entry must explicitly include:
    - **What was added / modified / removed:** Specific files, classes, endpoints, or models touched.
    - **Explanation:** Why the change was made and what functionality it introduces.
    - **General Project Impact:** How this change affects the broader codebase, architectural layering, dependencies, security posture, or downstream features.

## Adding a feature

1. `domain/` entities → repository interface → use cases.
2. `data/` DTOs → repository implementation.
3. `application/` repository provider (abstract) → use-case providers → notifier + state.
4. Register the implementation in `lib/composition_root.dart`.
5. Document all additions in `CHANGELOG.md`.
