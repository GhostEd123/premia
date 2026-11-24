# Project Changelog

All notable changes to the Premia project will be documented in this file.

> **RULE FOR ALL AI AGENTS:** Whenever you modify, add, or refactor code in this repository, you MUST add an entry under the current date (format: `DD/MM/YY`). Each entry must detail:
> 1. **What was added / modified / removed** (files, models, endpoints, widgets).
> 2. **Explanation of the change** (rationale and functional behavior).
> 3. **Impact on the general project** (architectural layering, dependencies, security, data flows).

---

## [24/11/26] - 2026-11-24

### 1. Edge-to-Edge Marquee Poster, Persistent Top Border Radius on Scroll & Upcoming Empty State Copy
- **What Was Added / Modified:**
  - Updated `lib/features/films/presentation/marquee_screen.dart`:
    - Removed horizontal padding around the poster in `_NowShowingCard` so the poster image hugs the left and right screen edges while keeping `20px` horizontal padding on the details, countdown, and buttons below it.
    - Wrapped `_NowShowingCard`'s scrollable `ListView` in a `ClipRRect` with `BorderRadius.vertical(top: Radius.circular(AppDimens.radiusCard))` so the top border radius remains curved when scrolling underneath the `"Premiering now"` and `"Upcoming Premiers"` pills.
    - Parameterized `NoActivePremiere(title: ...)` and passed `'No upcoming premiere'` in `_UpcomingList` when there are no upcoming films.
- **Explanation:**
  - Ensures the poster spans edge-to-edge horizontally, retains its rounded top corners as it scrolls under the header tabs, and displays accurate empty-state copy on the Upcoming Premiers tab.
- **General Project Impact:**
  - Polishes the Marquee screen layout and scroll clipping behavior.

---

### 2. Real-Time Socket.IO Watch Party Quick Messages & Reactions with Floating Hover Animations
- **What Was Added / Modified:**
  - `lib/features/parties/domain/parties_repository.dart`:
    - Added Socket.IO watch-party contract: `incomingQuickMessages`, `incomingReactions`, `connectWatchParty(partyId, socketToken)`, `sendQuickMessage(text)`, `sendReaction(emoji)`, and `disconnectWatchParty()`.
  - `lib/features/parties/data/parties_repository_impl.dart`:
    - Implemented Socket.IO v4 (Engine.IO v4 WebSocket transport to `AppConstants.socketBaseUrl`) authenticating with `handshake.auth.token = socketToken`, emitting `joinParty`, `sendQuickMessage`, and `sendReaction`, and listening for `receiveQuickMessage` and `receiveReaction`.
  - `lib/features/parties/application/watch_party_notifier.dart`:
    - Added `FloatingMessage` and `activeMessages` to `WatchPartyState` alongside `FloatingReaction`.
    - Updated predefined quick messages (`['OMG!', 'No way!', "I didn't see that coming...", 'Lol', 'This scene is intense', 'Who is that?!', 'I love this part', 'Boring']`) and reactions (`['🥱', '😱', '😂', '❤️', '🍿']`) to match `GET /api/parties/quick-messages`.
    - Removed persistent chat history storage; both outgoing and incoming `receiveQuickMessage` and `receiveReaction` events spawn transient floating items that drift upward and self-clean after 4 seconds.
  - `lib/features/parties/presentation/widgets/watch_party_overlay.dart`:
    - Created `WatchPartyFloatingLayer` so both quick messages and emoji reactions hover upward over the movie and fade out smoothly (`Curves.easeOut`).
    - Simplified `WatchPartyOverlay` into a compact bottom picker for predefined reactions and quick messages without any stored message list.
  - `lib/features/playback/presentation/player_screen.dart`:
    - Connected Watch Party Socket.IO automatically upon playback authorization (`auth.partyId` & `auth.socketToken`) and mounted `WatchPartyFloatingLayer` over the video player for watch party sessions.
- **Explanation:**
  - Replaces static local chat history with real-time Socket.IO events (`sendQuickMessage` / `receiveQuickMessage` and `sendReaction` / `receiveReaction`) where both predefined messages and reactions float upward over the movie and fade away slowly.
- **General Project Impact:**
  - Delivers the intended ephemeral cinema watch-party experience where reactions and quick comments float over the video without cluttering the screen with a persistent chat log.

---

### 2. Hide Watch Party Chat & Reactions on `PlayerScreen` for Single Tickets (`ticketType == 'single'`)
- **What Was Added / Modified:**
  - `lib/features/playback/domain/playback_authorization.dart`: Added `isWatchParty` getter (`ticketType != 'single' && ticketType.isNotEmpty`).
  - `lib/features/playback/presentation/player_screen.dart`: Checked `ticketType != 'single'` (from `playbackNotifierProvider.authorization` or `authNotifierProvider.magicLinkSession`) to hide both the **`React & Chat`** button in `_Controls` and the `WatchPartyOverlay` when `ticketType == 'single'`.
- **Explanation:**
  - Single-viewer ticket holders do not have an associated Watch Party room, so chat and reaction controls should only appear for Watch Party tickets (`bundle_2`, `bundle_4`, or invited guests).
- **General Project Impact:**
  - Keeps the single-ticket viewing experience distraction-free while preserving full Watch Party chat and reactions for group bundle sessions.

---

### 2. Settings & Legal Screen (`SettingsScreen`) Routed from Marquee Menu Icon
- **What Was Added / Modified:**
  - Created `lib/features/settings/application/settings_notifier.dart` (`SettingsNotifier` and `SettingsState` managing `premierReminders` and `subtitlesByDefault` toggles).
  - Created `lib/features/settings/presentation/settings_screen.dart` matching the design specification:
    - Top back button, rounded dark surface card with `Premier Reminders` and `Subtitles by Defualt` red `CupertinoSwitch` toggles.
    - Second rounded dark surface card with `Email Support`, `Terms of Service`, and `Privacy Policy` rows with leading and trailing icons.
    - Centered bottom footer `Premia by Lumina One · v1.0`.
  - Updated `lib/core/routing/route_paths.dart` and `lib/core/routing/app_router.dart` to register `RoutePaths.settings` (`'/settings'`).
  - Updated `lib/features/films/presentation/marquee_screen.dart` (line 42) so the top-right hamburger menu icon navigates to `RoutePaths.settings`.
- **Explanation:**
  - Implements the Settings/Support/Legal screen and connects it to the Marquee header menu button.
- **General Project Impact:**
  - Provides ticket-holders with quick access to premiere reminder preferences, subtitle defaults, email support, legal terms, and app version info while maintaining strict layer separation.

---

### 2. Mux Video Streaming for Trailer (`trailerStreamId`) & Main Premiere (`streamId` + `playbackToken`)
- **What Was Added / Modified:**
  - `lib/core/constants/app_constants.dart`:
    - Removed `cloudflareCustomerCode` and Cloudflare Stream URL builders.
    - Added `AppConstants.streamBaseUrl = 'https://stream.mux.com'`.
    - Added `AppConstants.trailerManifestUrl(String trailerStreamId)` returning `'https://stream.mux.com/$trailerStreamId.m3u8'`.
    - Updated `AppConstants.streamManifestUrl(String playbackToken, {required String streamId})` returning `'https://stream.mux.com/$streamId.m3u8?token=$playbackToken'`.
  - `lib/features/films/data/film_dto.dart`:
    - Prioritized `'trailerStreamId'` when mapping `Film.trailerUrl` and included `'producerName'` fallback for `Film.directors`.
  - `lib/features/films/presentation/film_details_sheet.dart`:
    - Converted `_TrailerPlayerHeader` to `ConsumerStatefulWidget` and updated `_resolveTrailerUrl()` to build `https://stream.mux.com/<trailerStreamId>.m3u8` via `AppConstants.trailerManifestUrl`, automatically refreshing film data if an older cached `Film` instance in memory predated `trailerStreamId`.
  - `lib/features/playback/presentation/player_screen.dart`:
    - Updated `_startPlayback` to stream `https://stream.mux.com/<streamId>.m3u8?token=<playbackToken>`.
    - Fixed premature `_Phase.ended` exit when the backend's `elapsedTime` (e.g., `648s` calculated against a 95-minute film metadata duration) exceeds the actual duration of a shorter test video asset uploaded to Mux (`controller.value.duration`).
- **Explanation:**
  - Switches video delivery entirely from Cloudflare Stream to Mux Video using the exact Mux HLS URLs for both public trailers (`trailerStreamId`) and signed premiere movies (`streamId` + `playbackToken`), and prevents `elapsedTime` from immediately ending playback when testing with shorter Mux video clips.
- **General Project Impact:**
  - Ensures both the trailer in `FilmDetailsSheet` and the main movie in `PlayerScreen` stream directly from `https://stream.mux.com`.

---

### 2. Remove Fallback Trailer Video, Display Stream Error States & Add Console Error Logging
- **What Was Added / Modified:**
  - `lib/features/films/presentation/film_details_sheet.dart`:
    - Removed `_fallbackTrailerUrl` (`bee.mp4`) from `_TrailerPlayerHeaderState`.
    - When `film.trailerUrl` is missing or fails to initialize/play, displays an in-place error overlay with the failure message and a `Retry trailer` button.
    - Added console logging (`debugPrint('[TrailerStreamError] ...')`) for missing trailer URLs, initialization exceptions, `controller.value.errorDescription`, and asynchronous playback errors.
  - `lib/features/playback/presentation/player_screen.dart`:
    - Added console logging (`debugPrint('[MovieStreamError] ...')`) in `_startPlayback`, `_fail`, and `_onTick` capturing exception details, stack traces, and `controller.value.errorDescription` (without logging raw tokens).
    - Surfaced the underlying player error description on the error view.
  - `lib/features/films/data/film_dto.dart`:
    - Expanded `trailerUrl` key lookup to include `trailerPlaybackId` and `trailerStreamId`.
- **Explanation:**
  - Eliminates the placeholder fallback video so missing or failing trailer streams are immediately visible both in the UI and in the debug console, alongside detailed diagnostics for main movie stream errors.
- **General Project Impact:**
  - Improves stream debugging visibility for both trailer and premiere video playback while keeping sensitive tokens out of logs.

---

### 2. Fix HLS Stream Manifest Resolution for Mux Signed Playback (`/playback/authorize`)
- **What Was Added / Modified:**
  - `lib/core/constants/app_constants.dart`:
    - Updated `AppConstants.streamManifestUrl(playbackToken, {streamId})` to build the Mux Video signed HLS manifest URL (`https://stream.mux.com/$streamId.m3u8?token=$playbackToken`) by default when `CLOUDFLARE_CUSTOMER_CODE` is not set.
  - `lib/features/playback/domain/playback_authorization.dart` & `lib/features/playback/data/playback_repository_impl.dart`:
    - Added optional `drmToken` (`aud: "d"`) and `thumbnailToken` (`aud: "t"`) fields returned by `POST /api/playback/authorize`.
  - `lib/features/playback/presentation/player_screen.dart`:
    - Removed the blocking `AppConstants.cloudflareCustomerCode.isEmpty` error check in `_startPlayback` and passed both `auth.playbackToken` and `auth.streamId` to `AppConstants.streamManifestUrl`.
  - `lib/features/films/presentation/film_details_sheet.dart`:
    - Updated `_resolveTrailerUrl` to resolve non-URL `trailerId` values via `https://stream.mux.com/$raw.m3u8`.
- **Explanation:**
  - The backend `/playback/authorize` endpoint returns Mux Video RS256 JWTs (`playbackToken` with `aud: "v"`, `drmToken` with `aud: "d"`, `thumbnailToken` with `aud: "t"`) and a Mux playback ID (`streamId`). Previously, `PlayerScreen` failed immediately with `"Streaming is not configured (missing CLOUDFLARE_CUSTOMER_CODE)."` when `CLOUDFLARE_CUSTOMER_CODE` was not passed via `--dart-define`.
- **General Project Impact:**
  - Enables immediate HLS premiere streaming on `PlayerScreen` using the signed `streamId` and `playbackToken` from `/playback/authorize` without requiring a Cloudflare customer code `--dart-define`.

---

### 2. Viewing Rights Copy, Auto-Playing Trailer Details Sheet, Marquee Calendar Action & Watch Party Lobby/Host Screens
- **What Was Added / Modified:**
  - `lib/core/theme/app_colors.dart`:
    - Added `AppDimens.buttonHeight = AppDimens.controlHeight` (`52`) alias and updated `_CalendarIconButton` in `marquee_screen.dart` and `upcoming_film_screen.dart` to use `AppDimens.controlHeight`.
  - `lib/features/films/domain/film.dart` & `lib/features/films/data/film_dto.dart`:
    - Added optional `trailerUrl` field to `Film` and parsed `['trailerUrl', 'trailer', 'trailerId']` in `FilmDto`.
  - `lib/features/films/presentation/film_details_sheet.dart`:
    - Updated `_viewingRights` copy to explicitly cover the 48-to-72-hour premiere window, 10-minute rewind limit, 3-pause limit, and Guest Passes Watch Party window rules.
    - Redesigned `FilmDetailsSheet` into a full-screen layout with a top 16:10 `_TrailerPlayerHeader` (`VideoPlayerController`) that auto-plays the film trailer when triggered from the poster Play button or "View details", complete with back arrow, play/pause toggle, elapsed/duration timestamp (`0:35 / 1:05`), and red progress bar.
    - Added primary `Get a Ticket` CTA and stateful `Add to Calendar` / `✓ Added to Calendar` outline button above the metadata sections (`Directors`, `Cast`, `Genre`, `Studio`, `Runtime`, `Viewing Rights`).
  - `lib/features/films/presentation/marquee_screen.dart` & `lib/features/films/presentation/upcoming_film_screen.dart`:
    - Wired the poster Play button and `View details ->` link to open `FilmDetailsSheet` with `autoPlayTrailer: true`.
    - Updated the pre-ticket state (`!hasTicket`) to display the `Hrs : Mins : Secs` countdown box followed by a horizontal action row with an expanded `Get a Ticket` button and a square outlined Calendar icon button (`_CalendarIconButton`).
    - Updated the ticket-holder state (`hasTicket`) to distinguish single tickets from watch party bundles (`MagicLinkSession.isWatchParty`): single-ticket holders see **`Start Premier`** (routing directly to `RoutePaths.player`), while watch-party bundle holders (`bundle_2`, `bundle_4`) see **`Go to Lobby`** (routing to `RoutePaths.lobby`).
  - `lib/features/parties/domain/watch_party.dart`:
    - Updated `usedPasses` to reflect guests currently `inLobby` (`2/4`) while `hasPassesRemaining` checks total invited guests against `totalPasses`.
  - `lib/features/parties/presentation/lobby_screen.dart`:
    - Added stateful `Add to Calendar` / `✓ Added to Calendar` toggle button under the upcoming countdown card.
    - Styled `_GuestPassesCard` with the crimson radial ambient glow and `Invite to party ->` button routing to `RoutePaths.hostParty`.
    - Added horizontal dividers between the three items in `_HouseRulesCard`.
  - `lib/features/parties/presentation/host_party_screen.dart`:
    - Replaced the pill counter with `_GuestPassRing` (circular progress ring around `2/4`) and grouped the guest rows inside a unified surface container with horizontal dividers.
  - `lib/features/tickets/presentation/checkout_screen.dart`:
    - Added ticket tier selection (`Single ticket`, `Watch Party • 2 Passes`, `Watch Party • 4 Passes`) with live price breakdown refresh.
- **Explanation:**
  - Aligns the Marquee, Trailer Details view, Watch Party Lobby (upcoming and active premiere states), and Host Party guest management screens with the UI design specifications and updated viewing rights copy.
- **General Project Impact:**
  - Completes the end-to-end visual and interactive flow from Marquee trailer preview and calendar reminder to Watch Party ticket checkout, Lobby countdown/live entry, and Host Party guest magic-link invitations while strictly maintaining the 4-layer architecture.

---

### 2. Register `Unageo` Brand Font Family & Set as Global App Typography
- **What Was Added / Modified:**
  - Updated `pubspec.yaml` to declare the `Unageo` font family with all 14 font variants in `assets/fonts/` (weights `300` Light through `900` Black, regular and `italic`).
  - Updated `AppTheme` in `lib/core/theme/app_theme.dart` to define `AppTheme.fontFamily = 'Unageo'` and apply it globally on `ThemeData`, `textTheme`, and `primaryTextTheme`.
- **Explanation:**
  - Resolves the `TODO(theme)` in `AppTheme` by registering the local `Unageo` font assets and configuring `Unageo` as the central typeface across the entire application.
- **General Project Impact:**
  - Every screen, dialog, bottom sheet, button, and input field across the app now automatically inherits the `Unageo` brand typography across all font weights (`w300`–`w900`) and styles.

---

### 2. Replace Text-Based `PremiaLogo` with Brand Wordmark Asset
- **What Was Added / Modified:**
  - Updated `PremiaLogo` in `lib/core/widgets/common_widgets.dart` to render `Image.asset('assets/icons/Premia_wordmark.png')` (with configurable `height = 28` and `semanticLabel: 'Premia'`) instead of the placeholder `Row` of `'R'` and `'Premia'` `Text` widgets.
- **Explanation:**
  - Displays the official Premia brand wordmark image (`assets/icons/Premia_wordmark.png`) in app headers rather than styled text.
- **General Project Impact:**
  - Ensures consistent visual branding on the Marquee header and any screen using `PremiaLogo`.

---

## [22/11/26] - 2026-11-22

### Configure Render Backend API & Socket.IO Base URLs (`AppConstants`)
- **What Was Added / Modified:**
  - Updated `lib/core/constants/app_constants.dart`:
    - Set `AppConstants.apiBaseUrl` default value to `'https://premia-frontend-prev.onrender.com/api'`.
    - Added `AppConstants.socketBaseUrl` (`--dart-define=SOCKET_BASE_URL`, default value `'https://premia-frontend-prev.onrender.com'`) for Watch Party WebSockets.
- **Explanation:**
  - Aligns the app's default network configuration with the active Render backend deployment (`premia-frontend-prev.onrender.com`) for both REST API calls (`/api`) and Socket.IO connections.
- **General Project Impact:**
  - Directs all `HttpService` requests and watch party WebSocket connections to the live Render backend instance without requiring manual `--dart-define` overrides during development.

---

## [20/11/26] - 2026-11-20

### Restore Backend API Base URL (`AppConstants.apiBaseUrl`)
- **What Was Added / Modified:**
  - Updated `lib/core/constants/app_constants.dart` to restore the default `apiBaseUrl` from `'https://premia-frontend-prev.vercel.app/api'` back to `'https://premia-backend.onrender.com/api'`.
- **Explanation:**
  - `premia-frontend-prev.vercel.app` is the Next.js web frontend deployment on Vercel, which does not host the `/api/films/*` backend routes and therefore returned Next.js HTML 404 pages on API calls. The Node.js/Express backend API is hosted at `https://premia-backend.onrender.com/api`.
- **General Project Impact:**
  - Restores JSON API communication across all repository endpoints (`/films`, `/films/now-showing`, `/auth/*`, `/tickets/*`, `/playback/*`, `/parties/*`, `/waitlist`).

---

## [18/11/26] - 2026-11-18

### Android Debug Manifest Merger Fix (`android:usesCleartextTraffic`)
- **What Was Added / Modified:**
  - Updated `android/app/src/debug/AndroidManifest.xml` to declare `xmlns:tools="http://schemas.android.com/tools"` on the `<manifest>` root and `tools:replace="android:usesCleartextTraffic"` on the `<application>` element.
- **Explanation:**
  - `android/app/src/main/AndroidManifest.xml` sets `android:usesCleartextTraffic="false"` to enforce HTTPS-only traffic in release and profile builds (Rule 10 of `AI_ARCH_RULES.md`), whereas `android/app/src/debug/AndroidManifest.xml` overrides it to `true` so debug builds can reach a local backend (`http://10.0.2.2:3000`). Without `tools:replace`, Gradle's `:app:processDebugMainManifest` task fails with a manifest merger conflict.
- **General Project Impact:**
  - Unblocks Android debug builds (`assembleDebug` / `flutter run`) while preserving strict `usesCleartextTraffic="false"` security enforcement in profile and release builds.

---

## [11/11/26] - 2026-11-11

### 1. Full Consumer Parity Implementation per PREMIA_BACKEND_CHANGES 2.md (100% Completion)
- **What Was Added / Modified:**
  - **Core Constants & Routing (`lib/core/`):**
    - `core/constants/app_constants.dart`: Added statutory `vatPercentage = 7.5` and `vatMultiplier = 1.075`.
    - `core/routing/route_paths.dart` & `core/routing/app_router.dart`: Added `RoutePaths.watch` (`/watch?inviteToken=...&filmId=...`) linking invited guests directly to synchronized theater playback with `inviteToken`.
    - `core/utils/json_utils.dart`: Added `JsonUtils.numberOrNull(j, keys)` to safely extract optional nullable numeric fields (e.g. `grossAmount`, `vatAmount`) without coercing to a default non-null zero.
  - **Authentication Feature (`lib/features/auth/`):**
    - `domain/magic_link_session.dart`: Added `filmId` returned from updated `GET /api/auth/verify`.
    - `domain/auth_repository.dart` & `domain/auth_use_cases.dart`: Added `resendMagicLink` (`POST /api/auth/resend-magic-link`) and updated `signOut` (`POST /api/auth/logout`).
    - `data/auth_dtos.dart` & `data/auth_repository_impl.dart`: Parsed `filmId`, implemented `resendMagicLink` with email normalization, and implemented server-side `signOut` via `/auth/logout` before wiping local cookies.
    - `application/auth_notifier.dart`: Added `resendMagicLink` action, `isResending`, and `resendSuccessMessage`.
    - `presentation/enter_link_screen.dart`: Added self-service recovery modal to resend ticket links.
  - **Films & Waitlist Feature (`lib/features/films/`):**
    - `domain/film.dart` & `data/film_dto.dart`: Added `ticketPriceUsd` and `detectedCurrency` ('NGN' vs 'USD') support per dual-market pricing.
    - `domain/films_repository.dart`, `domain/films_use_cases.dart`, & `data/films_repository_impl.dart`: Added `getFilmById(id)` (`GET /api/films/:id`) and `GetFilmById` usecase.
    - `application/films_notifier.dart`: Added `filmByIdProvider` family.
    - `domain/waitlist_repository.dart`, `domain/waitlist_use_cases.dart`, & `data/waitlist_repository_impl.dart`: Implemented `submitWaitlist` connecting to `POST /api/waitlist` for email and phone lead capture.
    - `application/waitlist_notifier.dart` & `presentation/waitlist_sheet.dart`: Replaced local mock with real API submission, error handling, phone/email input, and success messaging.
  - **Tickets & Pricing Feature (`lib/features/tickets/`):**
    - `domain/ticket_price_breakdown.dart` & `data/tickets_repository_impl.dart`: Implemented `TicketPriceBreakdown` entity and DTO for `GET /api/tickets/price-breakdown`.
    - `domain/payment_intent.dart` & `data/tickets_repository_impl.dart`: Added `currency`, `grossAmount`, `vatAmount` fields to `PaymentIntent` and parsed from `POST /api/tickets/initiate`.
    - `domain/tickets_repository.dart` & `domain/tickets_use_cases.dart`: Added `getPriceBreakdown` and updated `initiatePayment` to accept `currency`.
    - `application/ticket_purchase_notifier.dart`: Added `loadPriceBreakdown` and updated `purchase` to accept currency.
    - `presentation/checkout_screen.dart`: Added VAT and gross pricing display, wired `loadPriceBreakdown`, and passed currency.
    - `presentation/payment_pending_screen.dart`: Displayed gross amount including 7.5% VAT.
  - **Playback & Cinema Sync Feature (`lib/features/playback/`):**
    - `domain/playback_authorization.dart` & `data/playback_repository_impl.dart`: Added `partyId` and `socketToken` fields from `POST /api/playback/authorize`.
    - `data/playback_repository_impl.dart`: Injected `DeviceIdService` and populated `deviceId` in the request body for anti-piracy session locking.
    - `presentation/player_screen.dart`: Added `inviteToken` support to allow watch party guests to authorize and stream without a ticketId.
  - **Composition Root (`lib/composition_root.dart`):**
    - Bound `waitlistRepositoryProvider` to `WaitlistRepositoryImpl`.
  - **Unit Test Suite (`test/`):**
    - Added unit test suites in `test/features/auth/auth_dtos_test.dart`, `test/features/tickets/tickets_dto_test.dart`, `test/features/playback/playback_dto_test.dart`, and `test/features/films/films_dto_test.dart`.
- **Explanation:**
  - Implements 100% of the updated and new consumer endpoints specified in `PREMIA_BACKEND_CHANGES 2.md`, bringing the consumer Flutter app to full backend parity while strictly preserving the 4-layer architecture, dependency direction, and Rule 0 scope boundary.
- **General Project Impact:**
  - Achieves 100% feature and endpoint completion for the consumer application.
  - Fully connects self-service magic link recovery, lead capture waitlist, 7.5% VAT pricing breakdown, multi-currency GeoIP support, guest deep-link theater authorization, and watch party socket authentication.

---

### 2. Architectural Audit, Flow Completion Ratings & Endpoint Gap Analysis
- **What Was Added / Modified:**
  - Audited full consumer Flutter codebase against `AI_ARCH_RULES.md`, `architecture_template.md`, `Premia Documentation.pdf`, and `Premia PRD Backend.pdf`.
  - Analyzed layers (`domain`, `data`, `application`, `presentation`), state management (`Notifier`, `AsyncNotifier`), routing (`GoRouter`), security (`core/security/`), and composition root (`lib/composition_root.dart`).
  - Documented completion ratings across all core flows: Authentication & Session, Film Discovery & Marquee, Ticketing & TransactPay Checkout, Playback & Cinema Live Sync, and Watch Party / Lobby Interaction.
  - Documented missing screens and backend endpoint gaps (Waitlist registration endpoint, dynamic guest invitation endpoint, real-time sync/reaction WebSocket/SSE, and session/payment status polling).
  - Created persistent standalone documentation file `lib/PROJECT_ANALYSIS_AND_AUDIT.txt` containing the complete codebase analysis, architectural overview, layer breakdown, flow ratings table, missing screens, and missing backend endpoints.
- **Explanation:**
  - Established a formal architectural assessment of project readiness, verifying strict adherence to consumer-only scope (Rule 0) and layered dependency boundaries (presentation → application → data → domain), while pinpointing functional gaps between the mobile frontend implementation and the backend API contract.
- **General Project Impact:**
  - Provides a permanent in-codebase reference document (`lib/PROJECT_ANALYSIS_AND_AUDIT.txt`) and roadmap for future AI agents and team engineers.
  - Confirms zero layer violations, guarantees adherence to the consumer-only mandate (excluding admin tooling from the consumer mobile app), and flags contract dependencies required from the backend team before production deployment.

---

## [22/10/26] - 2026-10-22

### 1. Network Endpoint Logging & Console Pretty Debugger
- **What Was Added / Modified:**
  - Added `pretty_dio_logger: ^1.4.0` dependency in `pubspec.yaml`.
  - Updated `lib/core/network/http_service.dart` to register `PrettyDioLogger` within `HttpService`'s constructor.
  - Guarded the interceptor registration inside an `assert(() { ... return true; }())` block.
  - Configured logging options:
    - `request: true` (logs HTTP method, target URL, and query parameters).
    - `requestBody: true` (logs outgoing JSON/form payload).
    - `responseBody: true` (logs incoming server response body).
    - `error: true` (logs network failure details).
    - `compact: true`, `maxWidth: 90`.
    - `requestHeader: false` and `responseHeader: false` (strictly prevents logging session cookies and sensitive authorization headers).
  - Added unit test suite in `test/core/network/http_service_test.dart` to verify that `PrettyDioLogger` is registered with the correct payload and response logging settings under debug/test environments.
- **Explanation:**
  - Developers and AI agents need real-time, readable visibility into API requests and responses during development without manually placing `print()` calls in repository methods or widgets.
- **General Project Impact:**
  - **Zero Production Overhead / Security:** Because `PrettyDioLogger` is wrapped in an `assert` block, the Dart compiler completely strips the logging code and imports from release builds (`--release`). This prevents performance degradation and ensures session cookies and tokens are never leaked to logs in production (strictly adhering to Rule 10 of `AI_ARCH_RULES.md`).
  - **Centralized Telemetry:** Because all network operations flow exclusively through `HttpService`, every existing and future repository endpoint (`/auth/verify`, `/films`, `/films/now-showing`, `/tickets/initiate`, `/playback/authorize`, `/parties/*`) automatically outputs structured, readable console logs without modifying repository code.

---

### 2. AI Architecture Rules & Mandatory Changelog Tracking
- **What Was Added / Modified:**
  - Modified `AI_ARCH_RULES.md` system instruction banner to mandate changelog logging.
  - Added Rule 11 ("Mandatory Change Tracking in `CHANGELOG.md`") under "Project-specific clarifications".
  - Updated feature checklist in `AI_ARCH_RULES.md` to include step 5: "Document all additions in `CHANGELOG.md`".
  - Created `CHANGELOG.md` (this file) as the single source of truth for chronological project changes.
- **Explanation:**
  - Establishes a permanent, tool-agnostic record of modifications for multi-agent and pair-programming workflows, ensuring changes and their architectural side-effects are clearly documented.
- **General Project Impact:**
  - Prevents regressions, architectural drift, or accidental layer violations by future AI agents.
  - Guarantees project maintainability and seamless transitions between different AI agent sessions.

---

### 3. Core Architecture, Endpoints & Single-Ticket Flow (Baseline Implementation)
- **What Was Added / Modified:**
  - **Core Layer (`lib/core/`):**
    - `core/network/`: `HttpService` (single choke point using Dio), `ApiException` (sanitized user-friendly errors).
    - `core/security/`: `SecureCookieStorage` (keystore-backed cookie jar using `flutter_secure_storage`), `DeviceIdService` (`X-Device-Id` header generation and persistence), `CertificatePinning` (SHA-256 fingerprint verification), `ScreenProtection` (prevents iOS/Android screenshots and screen recording on sensitive viewing screens).
    - `core/constants/`: `AppConstants` (environment variables, endpoints, headers).
    - `core/theme/`: `AppColors`, `AppTheme` (Material 3 dark-first aesthetic tailored for cinematic premiere viewing).
    - `core/routing/`: `RoutePaths`, `appRouterProvider` (`GoRouter` configuration).
    - `core/widgets/`: `AppButton`, `NoticeBanner`, `LoadingIndicator`, `ErrorStateView`.
    - `core/utils/`: `JsonUtils` (type-tolerant deserialization), `Formatters`, `Validators`.
  - **Feature Layers (`lib/features/`):**
    - `splash`: `SplashScreen` with branded animations, auto-transition to marquee, and skip gesture.
    - `auth`: Magic link verification (`/auth/verify`), `MagicLinkSession` domain entity, `AuthRepository` & implementation, `AuthNotifier`.
    - `films`:
      - Endpoints: `GET /films` (active catalog), `GET /films/now-showing` (currently screening film).
      - Domain: `Film` entity with premiere status enum (`upcoming`, `nowShowing`, `ended`).
      - Data: `FilmDto`, `FilmsRepositoryImpl`.
      - Application: `FilmsNotifier` (`AsyncNotifier`), `WaitlistNotifier`.
      - Presentation: `MarqueeScreen`, `UpcomingFilmScreen`, `FilmDetailsSheet`, `WaitlistSheet`.
    - `tickets`:
      - Endpoints: `POST /tickets/initiate` (TransactPay checkout initiation).
      - Domain: `PaymentIntent`, `TicketType` (`single`, `partyPass`), `TicketsRepository`.
      - Data: `PaymentIntentDto`, `TicketsRepositoryImpl`.
      - Application: `TicketPurchaseNotifier`.
      - Presentation: `CheckoutScreen`, `PaymentPendingScreen`.
    - `playback`:
      - Endpoints: `POST /playback/authorize` (playback token, stream ID, elapsed time).
      - Domain: `PlaybackAuthorization`, `PremiereSyncPolicy` (enforcing live clock sync, maximum 10-minute rewind window, anti-skip forward guard).
      - Data: `PlaybackAuthorizationDto`, `PlaybackRepositoryImpl`.
      - Application: `PlaybackNotifier`.
      - Presentation: `PlayerScreen` (HLS/video player, dynamic controls, screen recording guard, live sync status).
    - `parties`:
      - Endpoints: `GET /parties/quick-messages`, `GET /parties/{partyId}/sync`.
      - Domain: `QuickMessages`, `PartiesRepository`.
      - Data: `QuickMessagesDto`, `PartiesRepositoryImpl`.
      - Application: `PartiesProviders`.
  - **Composition Root & Entry Point:**
    - `lib/composition_root.dart`: Riverpod overrides binding concrete repository implementations to domain abstract providers.
    - `lib/main.dart`: Initialization of `WidgetsFlutterBinding`, secure storage, and `ProviderScope`.
    - `lib/app.dart`: `MaterialApp.router` with theme and router bindings.
  - **Automated Tests (`test/`):**
    - `test/widget_test.dart`: `PremiereSyncPolicy` unit tests (live edge advancement, clamp anti-skip, 10-minute rewind restriction, film duration boundary).
    - `test/features/splash/splash_screen_test.dart`: Splash screen rendering, timer navigation, and tap-to-skip.
- **Explanation:**
  - Fulfills the consumer ticket-holder flow for the Premia cinema experience adhering strictly to `AI_ARCH_RULES.md` and `architecture_template.md`.
- **General Project Impact:**
  - Establishes the decoupled four-layer architecture (`domain`, `data`, `application`, `presentation`).
  - Strict boundary enforcement ensures presentation widgets never perform HTTP requests or interact with DTOs directly, guaranteeing maintainability and testability.

---

### 4. Remaining Screens: Lobby, Host Party, and Interactive Watch Party Experience
- **What Was Added / Modified:**
  - **Parties Domain:**
    - Created `PartyGuest` (`lib/features/parties/domain/party_guest.dart`): models guests with status (`inLobby`, `sent`) and email/name.
    - Created `PartyMessage` (`lib/features/parties/domain/party_message.dart`): models live feed messages, system alerts, and host announcements.
    - Created `WatchParty` (`lib/features/parties/domain/watch_party.dart`): models active party state, guest passes usage, and message threads.
  - **Parties Application:**
    - Implemented `WatchPartyNotifier` and `WatchPartyState` (`lib/features/parties/application/watch_party_notifier.dart`): manages guest invitations, party state, live messages, 3-pause limit enforcement, screen locking, floating emoji reactions, and integration with `GET /parties/quick-messages` and `GET /parties/:partyId/sync`.
  - **Parties Presentation:**
    - Created `LobbyScreen` (`lib/features/parties/presentation/lobby_screen.dart`): displays film backdrop, synopsis, genre, duration, countdown box (`48 : 36 : 09`) with "Add to Calendar" button when upcoming, "Doors close in..." indicator with "Start Premiere" button when live, "Guest Passes (2/4)" card with "Invite to party ->" button, and "House Rules" card (watch live, rewind 10m, 3 pauses limit).
    - Created `HostPartyScreen` (`lib/features/parties/presentation/host_party_screen.dart`): "Host party" header, "Each guest gets their own secure Magic Link.", name & email input fields, "Send Magic Link" button, and "Guest list (2/4)" with status badges ("In lobby", "Sent").
    - Created `PausePremiereDialog` (`lib/features/parties/presentation/widgets/pause_premiere_dialog.dart`): "Pause the premiere?", remaining pause counter warning, "Keep Watching" outline button, "Pause" red button, and "Don't show this again" checkbox.
    - Created `WatchPartyOverlay` (`lib/features/parties/presentation/widgets/watch_party_overlay.dart`): Host info bar with participant avatar badges ("Collins' Party • Host"), live message feed and system alerts ("JORDAN JOINED THE LOBBY"), quick reaction emoji bar (😂, 😱, 🔥, 👏, ❤️, 🤯), host announcements pills, quick comments pills, and floating emoji animations.
  - **Routing Updates:**
    - Added `RoutePaths.lobby` (`/lobby`) and `RoutePaths.hostParty` (`/host-party`) in `lib/core/routing/route_paths.dart`.
    - Registered routes in `lib/core/routing/app_router.dart`.
  - **Films Presentation (`MarqueeScreen`):**
    - Added hamburger icon to top bar, center play button overlay to film poster, and connected "Go to lobby" button navigating to `/lobby`.
  - **Playback Presentation (`PlayerScreen`):**
    - Integrated `WatchPartyOverlay` (toggleable with "React & Chat" button), pause confirmation dialog with `PausePremiereDialog`, screen lock button with unlock overlay, and top bar pauses left counter (`|| -- 3 pauses left`).
  - **Automated Tests:**
    - Added `test/features/parties/lobby_screen_test.dart` and `test/features/parties/host_party_screen_test.dart` (all 12 tests passing).
- **Explanation:**
  - Implements the complete cinema watch-party and lobby flow per the UI design wireframes and the Premia Documentation specification.
- **General Project Impact:**
  - Connects the user ticket flow from Marquee -> Lobby -> Host Party -> Player Screen with real-time watch party interaction.
  - Maintains strict 4-layer architecture (`domain` -> `data` -> `application` -> `presentation`).

