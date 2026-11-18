# Premia Backend — Developer Handover, Changelog & Complete API Reference

**Project:** Premia Backend (Movie Streaming & Digital Premiere Platform for Nigerian Producers)  
**Stack:** Node.js (ESM), Express 5, MongoDB (Mongoose 9), Redis 5, Socket.IO 4, Cloudflare Stream (RS256 Signed Playback), TransactPay (RSA + REST), Cloudinary, Resend / Nodemailer / SendGrid.

---

## Table of Contents

1. [Platform Overview & Core Business Rules](#1-platform-overview--core-business-rules)
2. [What Changed (Major Architecture & Security Upgrades)](#2-what-changed-major-architecture--security-upgrades)
3. [Complete API Endpoints Reference](#3-complete-api-endpoints-reference)
   - [3.1 System & Diagnostics](#31-system--diagnostics)
   - [3.2 Authentication (`/api/auth`)](#32-authentication-apiauth)
   - [3.3 Film Catalogue (`/api/films`)](#33-film-catalogue-apifilms)
   - [3.4 Tickets & Checkout (`/api/tickets`)](#34-tickets--checkout-apitickets)
   - [3.5 Playback & Theater Access (`/api/playback`)](#35-playback--theater-access-apiplayback)
   - [3.6 Watch Parties (`/api/parties`)](#36-watch-parties-apiparties)
   - [3.7 Admin Portal (`/api/admin`)](#37-admin-portal-apiadmin)
   - [3.8 Analytics & Financials (`/api/analytics`)](#38-analytics--financials-apianalytics)
   - [3.9 Waitlist (`/api/waitlist`)](#39-waitlist-apiwaitlist)
   - [3.10 Payment Webhooks (`/api/webhooks`)](#310-payment-webhooks-apiwebhooks)
   - [3.11 Support / Contact Module (`src/routes/contact.js`)](#311-support--contact-module-srcroutescontactjs)
4. [Real-Time Watch Party Socket.IO Specification](#4-real-time-watch-party-socketio-specification)
5. [Database Models & Schema Changes](#5-database-models--schema-changes)
6. [Module-by-Module Codebase Changelog](#6-module-by-module-codebase-changelog)
7. [Audit Findings Reference Table](#7-audit-findings-reference-table)
8. [Environment Variables & Configuration](#8-environment-variables--configuration)
9. [Test Suite & Utility Scripts](#9-test-suite--utility-scripts)

---

## 1. Platform Overview & Core Business Rules

**Premia** is a digital cinema platform where Nigerian film producers premiere new movies during fixed **48-to-72-hour premiere windows**.

Key domain mechanics every developer on the codebase should know:

- **Passwordless Viewers & Magic Links:** Standard viewers do not register with passwords. When a viewer buys a ticket (`single`, `bundle_2`, or `bundle_4`), the TransactPay webhook mints a `Ticket` and emails a reusable **Magic Link** (`GET /api/auth/verify?token=...`) that remains valid until `premiereEnd`. Clicking the magic link upserts the `User`, links their tickets, and sets an `httpOnly` session cookie (`token`) that expires when the premiere ends.
- **Dual-Market Pricing (`NGN` vs `USD`) & 7.5% VAT:**
  - Viewers in Nigeria are billed in **NGN**; diaspora/international viewers are billed in **USD**.
  - Base prices stored on `Film` documents are **VAT-exclusive**. At checkout, the backend applies **7.5% VAT** (`VAT_MULTIPLIER = 1.075`, rounded to 2 decimal places) so the payment gateway, receipt, webhook fraud check, and analytics ledger all operate on reconciled gross/VAT figures.
- **Single-Viewing Cinema Clock:**
  - Once a viewer starts watching (`POST /api/playback/authorize`), the backend stamps `startedAt` in Redis (`playback_session:<ticketId>:<userId>`) bound to their `deviceId`.
  - That timestamp is **immutable**: reloading the page or re-authorizing never resets the clock. Access locks permanently once `now > startedAt + (film.duration * 60 + 45 seconds)`.
- **Watch Parties (Bundle Tickets):**
  - `bundle_2` (host + 1 guest) and `bundle_4` (host + 3 guests) tickets allow the host to invite guests by email when entering the theater.
  - Guests receive an `inviteToken` link (`/watch?inviteToken=...&filmId=...`) and synchronize playback, emoji reactions, and quick-chat messages with the host over Socket.IO + Redis.

---

## 2. What Changed (Major Architecture & Security Upgrades)

This version of the backend introduces major improvements across security, payments, real-time synchronization, and admin tooling compared to the previous codebase:

### 1. Payment Security, 7.5% VAT & Auto-Refunds
- **Server-to-Server Webhook Verification:** `POST /api/webhooks` no longer trusts incoming webhook payloads directly. It calls TransactPay's `/payment/order/verify` endpoint using `TRANSACTPAY_SECRET_KEY` (with a fallback to `TRANSACTPAY_PUBLIC_KEY` on `401`) and verifies `statusId === 5` and `status === 'Successful'`.
- **7.5% VAT Model:** Added `resolveTicketPrice()` and `vatComponentOf()` in `src/controllers/ticketController.js`. All checkout amounts now include 7.5% VAT, and `Ticket.vat` is populated on every purchase.
- **Price & Currency Fraud Guard:** Webhooks verify that the amount and currency confirmed by TransactPay match the expected VAT-inclusive film price (`paymentMatchesFilm()`).
- **Region Arbitrage Prevention:** Re-enabled live GeoIP detection (`detectUserCountry(req)`). Non-Nigerian IPs attempting to pass `currency: 'NGN'` to buy at Naira prices are rejected with `400 Currency not available for your region`.
- **Automatic Post-Premiere Refunds:** If a payment webhook arrives *after* `film.premiereEnd`, the ticket is minted with `status: 'refund_due'`, an automatic refund is triggered via `src/utils/transactpayRefund.js` (`POST /payment/refund`), and the ticket is marked `status: 'refunded'` without sending a magic link.

### 2. Authentication, Sessions & Role Hierarchy
- **Token Role Whitelist (`SESSION_ROLES`):** Both `src/middleware/authenticate.js` and `src/controllers/playbackController.js` now enforce `SESSION_ROLES = ['user', 'Operations_Admin', 'Super_Admin']`. Special-purpose JWTs (`reset_token`, `invited_guest`) can no longer be replayed as session cookies or bearer tokens.
- **Server-Side Session Revocation (`sessionVersion`):** Added `sessionVersion` to the `User` model and JWT payload. Calling `POST /api/auth/logout` increments `user.sessionVersion` in MongoDB and clears the `token` cookie, immediately invalidating any active JWTs.
- **Redis Magic Link Tracking:** Removed the MongoDB `AuthToken` model. Magic links now embed a `jti` UUID stored in Redis (`magiclink:<jti>`) with a TTL matching `premiereEnd`.
- **Hardened Admin OTP & Password Reset:**
  - Upgraded admin reset OTPs from 4-digit `Math.random()` codes to **6-digit `crypto.randomInt(100000, 1000000)`** codes.
  - Added a per-account failed attempt counter in Redis (`otp_attempts:<userId>`): 5 failed attempts cancel the OTP immediately.
  - Enforced a minimum password length of 8 characters (`MIN_PASSWORD_LENGTH = 8`) and rate-limited `POST /api/auth/admin/reset-password`.
  - Blocked admins with `requiresPasswordChange: true` inside `requireRole` middleware so they cannot use the dashboard until they reset their password.
- **Admin Role Hierarchy & Last-Admin Protection:**
  - Enforced `ROLE_HIERARCHY = { user: 1, Operations_Admin: 2, Super_Admin: 3 }`.
  - Admins cannot suspend or modify accounts at or above their own rank, cannot modify their own account, and cannot suspend or demote the last active `Super_Admin` (`409 Conflict`).

### 3. Distributed Rate Limiting & Proxy Trust
- **Redis-Backed Limiters:** All limiters in `src/middleware/rateLimiter.js` now use `rate-limit-redis` (`RedisStore`) instead of local memory.
- **Signed Proxy IP Resolution (`PREMIA_PROXY_KEY`):** Requests carrying a valid `x-premia-proxy-key` header from the Next.js proxy are rate-limited by the real client IP in `x-forwarded-for` (with IPv6 `/56` subnet grouping via `ipKeyGenerator`), preventing all users behind the proxy from sharing a single rate-limit bucket.
- **Higher Per-Visitor Allowance:** Increased `apiLimiter` from `20 req/min` to `120 req/min` per IP to accommodate Nigerian carrier-grade NAT (CGNAT).

### 4. Playback & Watch Party Reliability
- **Lagos Timezone (`+01:00`) Scheduling:** Naive datetime strings (`YYYY-MM-DDTHH:mm`) submitted when creating or updating films are now explicitly parsed in Lagos time (`+01:00`, WAT) rather than the server host's local timezone.
- **Mandatory Film Duration:** `Film.duration` is now required (`min: 1`), and `playbackController` refuses to open a stream (`500`) if a film lacks a valid duration instead of defaulting to 2 hours (`7200s`).
- **Cross-Origin Socket Token (`socketToken`):** `POST /api/playback/authorize` now returns a signed `socketToken` and `partyId` so the frontend can authenticate Socket.IO connections via `handshake.auth.token` without relying on cross-origin cookies.
- **Redis-Backed Watch Party Teardowns:** Moved the 30-second host disconnect grace timer out of local process memory into Redis (`party_teardown:<partyId>`) with a 10-second `scanIterator` reconciler loop across server instances.

### 5. Multi-Currency Analytics & Email Failover
- **Per-Currency Analytics:** Financial endpoints (`/api/analytics/*`) no longer sum `NGN` and `USD` into a single combined number. All revenue figures are grouped by currency (`byCurrency` / `revenueByCurrency`), and refunded tickets (`refund_due`, `refunded`) are excluded.
- **3-Tier Email Failover & Dark Cinema Templates:** `src/services/emailService.js` now attempts delivery via **Resend REST API** first (when `SMTP_PASS` starts with `re_`), then **Nodemailer SMTP**, and finally **SendGrid**, using a redesigned dark cinema email template with Google Calendar and Outlook/iOS calendar links.

---

## 3. Complete API Endpoints Reference

### Summary of All Endpoints

| Method | Endpoint | Status | Auth / Permission | Rate Limiter(s) |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/health` | **NEW** | Public | None (for uptime monitors) |
| `GET` | `/debug/webhook-status` | **NEW** | Public (Diagnostic) | None |
| `GET` | `/api/test-email/film-check` | **NEW** | Public (Diagnostic) | `apiLimiter` |
| `GET` | `/api/auth/verify` | **UPDATED** | Public (Magic Link JWT) | `apiLimiter` |
| `POST` | `/api/auth/resend-magic-link` | **NEW** | Public | `apiLimiter`, `resendMagicLinkLimiter`, `resendMagicLinkEmailLimiter` |
| `POST` | `/api/auth/logout` | **NEW** | Public (Reads cookie/Bearer) | `apiLimiter` |
| `POST` | `/api/auth/admin/login` | **UPDATED** | Public | `apiLimiter`, `adminLoginLimiter` |
| `POST` | `/api/auth/admin/forgot-password` | **UPDATED** | Public | `apiLimiter`, `emailLimiter` |
| `POST` | `/api/auth/admin/verify-otp` | **UPDATED** | Public | `apiLimiter`, `otpLimiter` |
| `POST` | `/api/auth/admin/reset-password` | **UPDATED** | Bearer (`reset_token`) | `apiLimiter`, `otpLimiter` |
| `POST` | `/api/auth/admin/staff` | **UPDATED** | `Super_Admin` | `apiLimiter` |
| `GET` | `/api/films` | **UPDATED** | Public | `apiLimiter` |
| `GET` | `/api/films/now-showing` | **UPDATED** | Public | `apiLimiter` |
| `GET` | `/api/films/:id` | **UPDATED** | Public | `apiLimiter` |
| `GET` | `/api/tickets/price-breakdown` | **NEW** | Public | `apiLimiter` |
| `POST` | `/api/tickets/initiate` | **UPDATED** | Public | `apiLimiter` |
| `POST` | `/api/playback/authorize` | **UPDATED** | Cookie (`token`) or `inviteToken` | `apiLimiter` |
| `GET` | `/api/parties/quick-messages` | **EXISTING** | Public | `apiLimiter` |
| `GET` | `/api/parties/:partyId/sync` | **EXISTING** | Public | `apiLimiter` |
| `POST` | `/api/admin/films` | **UPDATED** | `Operations_Admin` | `apiLimiter` |
| `PUT` | `/api/admin/films/:id` | **UPDATED** | `Operations_Admin` | `apiLimiter` |
| `GET` | `/api/admin/users` | **UPDATED** | `Operations_Admin` | `apiLimiter` |
| `GET` | `/api/admin/users/export` | **NEW** | `Operations_Admin` | `apiLimiter` |
| `PATCH` | `/api/admin/users/:id/status` | **UPDATED** | `Operations_Admin` | `apiLimiter` |
| `PATCH` | `/api/admin/users/:id/role` | **UPDATED** | `Super_Admin` | `apiLimiter` |
| `GET` | `/api/admin/tickets` | **NEW** | `Operations_Admin` | `apiLimiter` |
| `GET` | `/api/admin/tickets/export` | **NEW** | `Operations_Admin` | `apiLimiter` |
| `POST` | `/api/admin/tickets/:id/resend` | **NEW** | `Operations_Admin` | `apiLimiter` |
| `GET` | `/api/analytics/films/:id` | **UPDATED** | `Operations_Admin` | `apiLimiter` |
| `GET` | `/api/analytics/platform` | **UPDATED** | `Operations_Admin` | `apiLimiter` |
| `GET` | `/api/analytics/financials` | **UPDATED** | `Operations_Admin` | `apiLimiter` |
| `POST` | `/api/waitlist` | **NEW** | Public | `apiLimiter` |
| `POST` | `/api/webhooks` | **UPDATED** | Public (Server-Verified) | `webhookLimiter`, `webhookReferenceLimiter` |
| `POST` | `src/routes/contact.js` (`/`) | **NEW (Unmounted)** | Public | `contactFormLimiter` |

---

### 3.1 System & Diagnostics

#### `GET /health` — **[NEW]**
- **File:** `server.js`
- **Description:** Unthrottled health check endpoint for load balancers and uptime monitors. Verifies MongoDB connection state (`readyState === 1`) and pings Redis (`PING -> PONG`).
- **Responses:**
  - `200 OK` (when both Mongo and Redis are healthy) or `503 Service Unavailable` (when either is down):
    ```json
    {
      "status": "ok",
      "mongo": true,
      "redis": true,
      "uptime": 3620
    }
    ```

#### `GET /debug/webhook-status` — **[NEW]**
- **File:** `server.js`
- **Description:** Temporary diagnostic endpoint returning the last webhook error/payload status, last email delivery error, environment configuration flags, and the 3 most recent tickets.

#### `GET /api/test-email/film-check` — **[NEW]**
- **File:** `src/routes/test-email.js`
- **Description:** Diagnostic endpoint returning the most recently created film's `title`, `streamId`, `trailerId`, and booleans indicating whether `CLOUDFLARE_KEY_ID` and `CLOUDFLARE_PRIVATE_KEY` are configured.

---

### 3.2 Authentication (`/api/auth`)

**Files:** `src/routes/auth.js`, `src/controllers/authController.js`

#### `GET /api/auth/verify?token=<magic_link_jwt>` — **[UPDATED]**
- **Description:** Verifies a viewer's magic link JWT from their ticket receipt email, upserts the `User`, links all unclaimed tickets for that email, and sets the `httpOnly` `token` cookie until `premiereEnd`.
- **What Changed:**
  - Checks `redisClient.get('magiclink:' + decoded.jti)` when `jti` is present on the token (`401 This link has expired.` if missing).
  - Normalizes email to lowercase (`normalizeEmail`) and claims unlinked tickets using case-insensitive collation (`{ locale: 'en', strength: 2 }`).
  - Embeds `sessionVersion: user.sessionVersion` inside the issued session cookie JWT.
  - Added `filmId` to the JSON response so the frontend routes directly to the film associated with the ticket.
- **Response (`200 OK`):**
  ```json
  {
    "message": "Logged in successfully",
    "userId": "6512f2a1...",
    "claimedTicketId": "6512f2b2...",
    "filmId": "6512f2c3...",
    "ticketType": "single"
  }
  ```

#### `POST /api/auth/resend-magic-link` — **[NEW]**
- **Rate Limiters:** `resendMagicLinkLimiter` (3/hr per IP) + `resendMagicLinkEmailLimiter` (3/hr per IP+email).
- **Description:** Self-service recovery endpoint for buyers who paid for a ticket on an active premiere but did not receive their email.
- **Request Body:**
  ```json
  {
    "email": "viewer@example.com",
    "filmId": "6512f2c3..."
  }
  ```
- **Behavior:** Looks up a `paid` ticket for `{ filmId, buyerEmail: email }` (case-insensitive), verifies the premiere has not ended, mints a new magic link JWT with a fresh Redis `jti`, sends the magic link email, and resets `ticket.emailDeliveryFailed = false`.
- **Responses:**
  - `200 OK`: `{ "message": "A fresh access link is on its way to your inbox." }`
  - `400 Bad Request`: Invalid email or `filmId`.
  - `403 Forbidden`: Premiere has already ended.
  - `404 Not Found`: Film or paid ticket not found.

#### `POST /api/auth/logout` — **[NEW]**
- **Description:** Ends the caller's session by incrementing `user.sessionVersion` in MongoDB (if a valid token is present in cookies or `Authorization` header) and clearing the `httpOnly` `token` cookie.
- **Response (`200 OK`):** `{ "message": "Logged out successfully." }`

#### `POST /api/auth/admin/login` — **[UPDATED]**
- **Rate Limiter:** `adminLoginLimiter` (5 attempts / 15 min).
- **Request Body:** `{ "email": "admin@watchpremia.com", "password": "..." }`
- **What Changed:** Normalizes email via `normalizeEmail()` and includes `sessionVersion: admin.sessionVersion` in the 24h admin JWT. If `admin.requiresPasswordChange === true`, still returns `{ message, requiresPasswordChange: true, resetToken }` (10-minute `reset_token`) without setting a session cookie.

#### `POST /api/auth/admin/forgot-password` — **[UPDATED]**
- **Rate Limiter:** `emailLimiter` (3 requests / hour).
- **Request Body:** `{ "email": "admin@watchpremia.com" }`
- **What Changed:**
  - Normalizes email via `normalizeEmail()`.
  - Generates a **6-digit** OTP using `crypto.randomInt(100000, 1000000)` (previously 4 digits via `Math.random()`).
  - Resets the Redis failed-attempt counter `otp_attempts:<admin._id>`.

#### `POST /api/auth/admin/verify-otp` — **[UPDATED]**
- **Rate Limiter:** `otpLimiter` (5 attempts / 15 min).
- **Request Body:** `{ "email": "admin@watchpremia.com", "otp": "123456" }`
- **What Changed:**
  - Validates that `otp` is a non-empty string before calling `bcrypt.compare`.
  - Tracks failed attempts per admin account in Redis (`otp_attempts:<admin._id>`, 15m TTL). After **5 failed attempts**, invalidates `admin.resetOtp` and `admin.otpExpiresAt` and returns `400 { "error": "Too many incorrect codes. This code has been cancelled — request a new one." }`.

#### `POST /api/auth/admin/reset-password` — **[UPDATED]**
- **Rate Limiter:** `otpLimiter` (5 attempts / 15 min — **newly added to this route**).
- **Headers:** `Authorization: Bearer <resetToken>`
- **Request Body:** `{ "newPassword": "newSecurePassword123" }`
- **What Changed:**
  - Enforces a minimum length of **8 characters** (`400 Your new password must be at least 8 characters long.`).
  - Clears `otp_attempts:<admin._id>` in Redis on success.

#### `POST /api/auth/admin/staff` — **[UPDATED]**
- **Auth:** `authenticate`, `requireRole('Super_Admin')`
- **Request Body:** `{ "fullName": "...", "email": "...", "role": "Operations_Admin" }`
- **What Changed:** Normalizes `email` via `normalizeEmail()` before checking uniqueness and creating the admin account.

---

### 3.3 Film Catalogue (`/api/films`)

**Files:** `src/routes/films.js`, `src/controllers/filmController.js`

#### `GET /api/films` — **[UPDATED]**
- **Description:** Lists all films (`upcoming`, `live`, `ended`) sorted by `premiereStart` ascending, excluding `streamingProviderVideoId`.
- **What Changed:** Detects the caller's currency (`NGN` or `USD`) via `detectUserCountry(req)` and includes `detectedCurrency` both on the response envelope and on each film object.
- **Response (`200 OK`):**
  ```json
  {
    "count": 1,
    "detectedCurrency": "NGN",
    "films": [
      {
        "_id": "...",
        "title": "...",
        "detectedCurrency": "NGN"
      }
    ]
  }
  ```

#### `GET /api/films/now-showing` — **[UPDATED]**
- **Description:** Returns the currently active premiere (`premiereStart <= now < premiereEnd`, `isActive: true`).
- **What Changed:**
  - Filters by `premiereStatus: { $in: ['live', 'upcoming'] }` and sorts by `.sort({ createdAt: -1 })`.
  - Attaches `detectedCurrency` to both the top-level response and the `film` object.

#### `GET /api/films/:id` — **[UPDATED]**
- **Description:** Fetches details for a single film by ObjectId.
- **What Changed:** Attaches `detectedCurrency` to both the top-level response and the `film` object.

---

### 3.4 Tickets & Checkout (`/api/tickets`)

**Files:** `src/routes/tickets.js`, `src/controllers/ticketController.js`

#### `GET /api/tickets/price-breakdown` — **[NEW]**
- **Query Params:** `?filmId=<id>&ticketType=<single|bundle_2|bundle_4>&currency=<NGN|USD>`
- **Description:** Returns the VAT-exclusive base price, 7.5% VAT amount, and gross total for a given film, ticket type, and currency.
- **Responses:**
  - `200 OK`:
    ```json
    {
      "baseAmount": 5000,
      "vatAmount": 375,
      "grossAmount": 5375,
      "currency": "NGN"
    }
    ```
  - `400 Bad Request`: `{ "error": "This ticket type is not on sale." }`
  - `404 Not Found`: `{ "error": "Film not found." }`

#### `POST /api/tickets/initiate` — **[UPDATED]**
- **Description:** Initiates a ticket purchase via TransactPay (`/payment/create` with RSA-encrypted payload).
- **Request Body:**
  ```json
  {
    "filmId": "6512f2c3...",
    "ticketType": "single",
    "email": "buyer@example.com",
    "currency": "NGN"
  }
  ```
- **What Changed:**
  - Checks `film.isActive === true` (`400 Ticket sales are not open for this premiere.`).
  - Uses live GeoIP detection (`detectUserCountry(req)`) instead of hardcoded `'NG'` / `'NGN'`.
  - **Region Lock:** Rejects `currency: 'NGN'` when `geo.countryCode !== 'NG'` (`400 Currency not available for your region.`).
  - Charges the **gross VAT-inclusive amount** (`base * 1.075`, rounded to 2 decimal places) and rejects with `400` if `grossAmount <= 0`.
  - Changed `payment.RedirectUrl` from `${APP_URL}/` to `${APP_URL}/success`.
  - Uses `getClientIp(req)` for `paymentMeta.ipAddress` and sets an `8000ms` timeout on the TransactPay request.
  - Removed `developerDetails` from `500` error responses so internal gateway errors are not exposed to clients.
- **Response (`200 OK`):**
  ```json
  {
    "paymentUrl": "https://checkout.transactpay.ai/...",
    "reference": "6512f2c3...__single__1726000000000",
    "currency": "NGN",
    "amount": 5375,
    "vat": 375
  }
  ```

---

### 3.5 Playback & Theater Access (`/api/playback`)

**Files:** `src/routes/playback.js`, `src/controllers/playbackController.js`

#### `POST /api/playback/authorize` — **[UPDATED]**
- **Description:** Omni-endpoint that authorizes stream playback for a ticket holder (via `ticketId` + `token` cookie) or a watch party guest (via `inviteToken`), optionally creates a watch party and dispatches guest invites, locks the session to a single `deviceId` in Redis, and mints a Cloudflare Stream RS256 playback token plus a Watch Party `socketToken`.
- **Request Body:**
  ```json
  {
    "deviceId": "browser-uuid",
    "ticketId": "6512f2b2...",
    "guestEmails": ["friend1@example.com"],
    "inviteToken": "optional-jwt-for-guests"
  }
  ```
- **What Changed:**
  1. **Strict Cookie Validation (Host/Single Path):** Verifies `SESSION_ROLES.includes(decodedUser.role)` and `mongoose.isValidObjectId(decodedUser.userId)` before querying `Ticket.findOne({ _id: ticketId, userId })`.
  2. **Refunded/Revoked Ticket Check:** Blocks tickets with `status` in `['refund_due', 'refunded', 'revoked']` (`403`).
  3. **Watch Party Deduplication:** Checks `WatchParty.findOne({ ticketId: activeTicketId, status: 'active' })` before creating a new party so page reloads do not create duplicate rooms or re-email guests.
  4. **Atomic Guest Capacity Check:** Uses `WatchParty.findOneAndUpdate({ _id: party._id, $expr: { $lt: [{ $size: "$participants" }, "$maxCapacity"] } }, { $addToSet: { participants: String(user._id) } })` and returns `409 This watch party is full.` when full.
  5. **Invite URL `filmId` Parameter:** Appends `&filmId=${film._id}` to guest invite links.
  6. **Strict Film Duration Check:** Requires `film.duration >= 1` (`500 This premiere is misconfigured` if missing/invalid instead of defaulting to 2 hours).
  7. **Immutable `startedAt` & 1-Second TTL Floor:** Never overwrites `startedAt` on re-authorization, and floors Redis `setEx` TTL and Cloudflare token duration at `1` second (`Math.max(..., 1)`).
  8. **Socket Token & Party ID in Response:** Added `partyId` and `socketToken` to the `200 OK` response.
- **Response (`200 OK`):**
  ```json
  {
    "playbackToken": "eyJhbGciOiJSUzI1NiIs...",
    "streamId": "cf-stream-video-id",
    "ticketType": "bundle_2",
    "elapsedTime": 142,
    "partyId": "6512f2d4...",
    "socketToken": "eyJhbGciOiJIUzI1NiIs..."
  }
  ```

---

### 3.6 Watch Parties (`/api/parties`)

**Files:** `src/routes/parties.js`, `src/controllers/partyController.js`

#### `GET /api/parties/quick-messages` — **[EXISTING]**
- **Description:** Returns the predefined quick-chat messages (`ALLOWED_QUICK_MESSAGES`) and emoji reactions (`ALLOWED_REACTIONS`).
- **Response (`200 OK`):** `{ "messages": [...], "reactions": [...] }`

#### `GET /api/parties/:partyId/sync` — **[EXISTING]**
- **Description:** Reads `party:${partyId}:time` from Redis to give late joiners the host's current playback timestamp in seconds.
- **Response (`200 OK`):** `{ "timestamp": 742.5 }`

---

### 3.7 Admin Portal (`/api/admin`)

**Files:** `src/routes/admin.js`, `src/controllers/adminController.js`, `src/controllers/filmController.js`  
*(All routes require `authenticate` middleware + `requireRole(...)`)*

#### `POST /api/admin/films` — **[UPDATED]** (`Operations_Admin`+)
- **Content-Type:** `multipart/form-data` (`thumbnail` file upload via Cloudinary or `thumbnailUrl` text field).
- **What Changed:** Parses `premiereStart` and `premiereEnd` through `normalizePremiereWindow()` so offset-less datetimes are interpreted as Lagos time (`+01:00`). Requires `duration >= 1`.

#### `PUT /api/admin/films/:id` — **[UPDATED]** (`Operations_Admin`+)
- **What Changed:**
  - Normalizes `premiereStart` and `premiereEnd` via `normalizePremiereWindow()`.
  - Replaced `Film.findByIdAndUpdate` with `Film.findById` → `film.set(req.body)` → `await film.save()` so the `Film` model's `pre('save')` 48–72h duration and schedule overlap checks always execute on edits.

#### `GET /api/admin/users` — **[UPDATED]** (`Operations_Admin`+)
- **Query Params:** `?page=1&limit=25&query=<search_email>`
- **What Changed:**
  - Added server-side pagination (`page` defaults to `1`; `limit` defaults to `25`, max `100`) and regex-escaped case-insensitive email search (`query`).
  - Strips sensitive fields via `SAFE_USER_FIELDS` (`-password -resetOtp -otpExpiresAt -__v`).
- **Response (`200 OK`):**
  ```json
  {
    "users": [...],
    "total": 137,
    "page": 1,
    "limit": 25,
    "pages": 6
  }
  ```

#### `GET /api/admin/users/export` — **[NEW]** (`Operations_Admin`+)
- **Description:** Downloads a CSV export (`premia-users-export-YYYY-MM-DD.csv`) of all users with fields `name, email, createdAt, role, suspended`.

#### `PATCH /api/admin/users/:id/status` — **[UPDATED]** (`Operations_Admin`+)
- **Request Body:** `{ "suspended": true }`
- **What Changed:**
  - Enforces `authorizeTargeting()`: blocks invalid ObjectIds (`400`), blocks self-suspension (`403`), and blocks acting on a user at or above the caller's DB role (`403`).
  - Enforces `wouldStrandPlatform()`: returns `409 Conflict` if suspending the last active `Super_Admin`.
  - Applies `SAFE_USER_FIELDS` projection on the returned user.

#### `PATCH /api/admin/users/:id/role` — **[UPDATED]** (`Super_Admin`)
- **Request Body:** `{ "role": "Operations_Admin" }`
- **What Changed:**
  - Reads valid roles directly from `User.schema.path('role').enumValues` (`['user', 'Operations_Admin', 'Super_Admin']`) instead of the old mismatched `['user', 'admin', 'super_admin']` array.
  - Enforces `authorizeTargeting()`, blocks granting a role at or above the actor's own rank (`403`), and blocks demoting the last active `Super_Admin` (`409`).

#### `GET /api/admin/tickets` — **[NEW]** (`Operations_Admin`+)
- **Query Params:** `?page=1&limit=50&search=<buyerEmail_or_paymentRef>`
- **Description:** Returns a paginated list of tickets populated with `filmId` (`title`), sorted newest first.
- **Response (`200 OK`):**
  ```json
  {
    "tickets": [...],
    "total": 42,
    "page": 1,
    "totalPages": 1
  }
  ```

#### `GET /api/admin/tickets/export` — **[NEW]** (`Operations_Admin`+)
- **Query Params:** `?filmId=<optional_film_id>`
- **Description:** Downloads a CSV export (`premia-tickets-export-YYYY-MM-DD.csv`) of tickets (optionally filtered by `filmId`) with columns `filmTitle, premiereDate, ticketType, vatAmount, grossAmount, currency, purchaseDate, paymentReference`.

#### `POST /api/admin/tickets/:id/resend` — **[NEW]** (`Operations_Admin`+)
- **Request Body:** `{ "newEmail": "optional-corrected-email@example.com" }`
- **Description:** Optionally updates `ticket.buyerEmail` (normalized), mints a new magic link JWT with a Redis `jti`, resends the ticket receipt email, and updates `ticket.emailDeliveryFailed`.

---

### 3.8 Analytics & Financials (`/api/analytics`)

**Files:** `src/routes/analytics.js`, `src/controllers/analyticsController.js`  
*(All routes require `authenticate` + `requireRole('Operations_Admin')`)*

All analytics aggregations now filter by `REVENUE_MATCH = { paymentStatus: 'paid', status: { $nin: ['refund_due', 'refunded'] } }` and separate monetary totals by currency (`NGN` and `USD`).

#### `GET /api/analytics/financials?filmId=<optional_id>` — **[UPDATED]**
- **Response (`200 OK`):**
  ```json
  {
    "totalTicketsSold": 5,
    "ngTickets": 3,
    "intTickets": 2,
    "byCurrency": [
      {
        "currency": "NGN",
        "tickets": 3,
        "grossRevenue": 16125,
        "processingFees": 0,
        "vatCollected": 1125,
        "netRevenue": 15000,
        "producerShare": 9000,
        "platformShare": 6000
      },
      {
        "currency": "USD",
        "tickets": 2,
        "grossRevenue": 10.76,
        "processingFees": 0,
        "vatCollected": 0.76,
        "netRevenue": 10,
        "producerShare": 6,
        "platformShare": 4
      }
    ]
  }
  ```

#### `GET /api/analytics/films/:id` — **[UPDATED]**
- **Response (`200 OK`):**
  ```json
  {
    "totalTickets": 5,
    "ngTickets": 3,
    "intTickets": 2,
    "byCurrency": [
      { "currency": "NGN", "tickets": 3, "grossRevenue": 16125, "processingFees": 0, "vatCollected": 1125, "netRevenue": 15000, "producerShare": 9000, "platformShare": 6000 },
      { "currency": "USD", "tickets": 2, "grossRevenue": 10.76, "processingFees": 0, "vatCollected": 0.76, "netRevenue": 10, "producerShare": 6, "platformShare": 4 }
    ],
    "watchPartyCount": 1
  }
  ```

#### `GET /api/analytics/platform` — **[UPDATED]**
- **What Changed:** Returns `stats.revenueByCurrency` instead of a mixed `grossRevenue` sum, and calculates `activeViewers` from Redis `playback_session:*` keys (counting both solo viewers and watch party guests).
- **Response (`200 OK`):**
  ```json
  {
    "stats": {
      "totalTickets": 5,
      "ngTickets": 3,
      "diasporaTickets": 2,
      "revenueByCurrency": [
        { "currency": "NGN", "tickets": 3, "grossRevenue": 16125 },
        { "currency": "USD", "tickets": 2, "grossRevenue": 10.76 }
      ]
    },
    "trends": {
      "ticketGrowthPercent": 25.0,
      "thisWeekTickets": 5,
      "lastWeekTickets": 4
    },
    "activeViewers": 12
  }
  ```

---

### 3.9 Waitlist (`/api/waitlist`)

**Files:** `src/routes/waitlist.js`, `src/controllers/waitlistController.js`

#### `POST /api/waitlist` — **[NEW]**
- **Description:** Captures leads from the homepage empty state between premieres. Accepts either an email address or a phone number (E.164 format, 7–15 digits).
- **Request Body:** `{ "email": "fan@example.com" }` or `{ "phone": "+2348012345678" }`
- **Responses:**
  - `200 OK` (new lead): `{ "message": "You're on the list. We'll alert you first." }`
  - `200 OK` (duplicate lead): `{ "message": "You're already on the list." }`
  - `400 Bad Request`: `{ "error": "Enter a valid email address or phone number." }`

---

### 3.10 Payment Webhooks (`/api/webhooks`)

**Files:** `src/routes/webhooks.js`, `src/controllers/webhookController.js`

#### `POST /api/webhooks` — **[UPDATED]**
- **Rate Limiters:** `webhookLimiter` (60/min per IP) + `webhookReferenceLimiter` (5/min per IP + `orderReference`).
- **Processing Pipeline:**
  1. Ignores non-successful events (`req.body?.status !== 'success' || data?.status !== 'Successful'`) with `200 OK`.
  2. Checks idempotency (`Ticket.exists({ paymentRef })`) before making external API calls.
  3. Parses `orderReference` (`${filmId}__${ticketType}__${timestamp}`) and loads the `Film`.
  4. **Server-to-Server Verification (`verifyOrder`):** Calls `POST ${TRANSACTPAY_BASE_URL}${VERIFY_PATH}` using `TRANSACTPAY_SECRET_KEY` (falling back to `TRANSACTPAY_PUBLIC_KEY` on `401`). Returns `500` on transient verification failure so TransactPay retries.
  5. Verifies `Number(verified?.statusId) === 5 && verified.status === 'Successful'`.
  6. **Fraud Guard (`paymentMatchesFilm`):** Verifies the paid currency and base amount match `resolveTicketPrice(film, ticketType, paidCurrency)`.
  7. **Post-Premiere Auto-Refund:** If `film.premiereEnd < new Date()`, creates the ticket with `status: 'refund_due'`, calls `transactpayRefund(paymentReference)`, and updates the ticket to `status: 'refunded'`.
  8. **Active Ticket Creation & Email Dispatch:** Creates the ticket with `status: 'active'` and `vat: vatComponentOf(paidAmount)`, stores `magiclink:${jti}` in Redis, and sends the receipt email. If email delivery fails, sets `ticket.emailDeliveryFailed = true` while still returning `200 OK`.

---

### 3.11 Support / Contact Module (`src/routes/contact.js`)

- **Files:** `src/routes/contact.js`, `src/controllers/contactController.js`, `src/models/ContactSubmission.js`
- **Status:** **NEW (Currently unmounted in `server.js`, written in CommonJS)**
- **Description:** Implements `POST /` with `multer` upload (`attachment`, max 5MB), verifies file magic bytes via `file-type` (`JPEG`, `PNG`, `WebP`, `PDF`), uploads attachments to Cloudinary (`premia_contact_attachments`), saves a `ContactSubmission` document, and emails `hello@watchpremia.com` via SendGrid.
- **Note for Developer:** Because `package.json` uses `"type": "module"`, convert these 3 files from CommonJS (`require`/`module.exports`) to ES Modules (`import`/`export default`) before mounting `/api/contact` in `server.js`.

---

## 4. Real-Time Watch Party Socket.IO Specification

**File:** `src/sockets/watchParty.js`

### Connection & Authentication
- Clients connect using the `socketToken` returned by `POST /api/playback/authorize`:
  ```js
  const socket = io(BACKEND_URL, {
    auth: { token: socketToken },
    withCredentials: true
  });
  ```
- Cookie-based socket authentication has been removed because cross-origin `SameSite=Lax` cookies are dropped during WebSocket handshakes.

### Client → Server Events
| Event | Payload | Sender | Behavior |
| :--- | :--- | :--- | :--- |
| `joinParty` | `{ partyId }` | Host / Guest | Verifies party is `active` and `party.ticketId === socket.ticketId`. Adds `String(socket.userId)` to `participants`, cancels any pending Redis host teardown if `socket.isHost`, and emits `syncTimestamp` with the current Redis time. |
| `videoAction` | `{ action, timestamp }` | Host only | Validates `timestamp > 0`, saves `party:${partyId}:time` in Redis (12h TTL) and `hostTimestamp` in MongoDB, and broadcasts `syncVideo` to the room. |
| `timeUpdate` | `{ timestamp }` | Host only | Validates `timestamp > 0`, updates `party:${partyId}:time` in Redis, and broadcasts `syncTimestamp` to the room. |
| `sendQuickMessage` | `{ text }` | Host / Guest | Validates `text` is in `ALLOWED_QUICK_MESSAGES`, enforces rate limit (**max 5 per 10s per socket**), and broadcasts `receiveQuickMessage` to *other* members in the room (`socket.to(partyId)`). |
| `sendReaction` | `{ emoji }` | Host / Guest | Validates `emoji` is in `ALLOWED_REACTIONS`, enforces rate limit (**max 5 per 10s per socket**), and broadcasts `receiveReaction` to *other* members in the room (`socket.to(partyId)`). |
| `disconnect` | *(none)* | Host / Guest | Removes `String(socket.userId)` from `WatchParty.participants` via `$pull`. If `socket.isHost`, schedules a 30-second teardown deadline in Redis (`party_teardown:<partyId>`). |

*(Note: The legacy `hostReconnect` client event and `cancelHostTimer` cross-server event were removed; re-emitting `joinParty` on reconnect now automatically cancels the Redis teardown key across all instances.)*

---

## 5. Database Models & Schema Changes

| Model (`src/models/`) | Status | Key Changes |
| :--- | :--- | :--- |
| `Film.js` | **UPDATED** | • Removed `unique: true, sparse: true` from `streamingProviderVideoId` (`server.js` runs `Film.syncIndexes()` on boot).<br>• Made `duration` required with `min: 1`.<br>• Updated `pre('save')` hook to run on `this.isNew`, validate finite timestamps, and ignore `ended` films (`premiereStatus: { $ne: 'ended' }`) when checking for overlapping premieres. |
| `Ticket.js` | **UPDATED** | • Added `'refund_due'` and `'refunded'` to `status` enum (`['active', 'used', 'revoked', 'refund_due', 'refunded']`).<br>• Added `emailDeliveryFailed: { type: Boolean, default: false }`. |
| `User.js` | **UPDATED** | • Added `lowercase: true` and `pre('save')` email normalization via `normalizeEmail()`.<br>• Added case-insensitive unique index `email_1_ci` with `{ locale: 'en', strength: 2 }` collation.<br>• Added `sessionVersion: { type: Number, default: 0 }`. |
| `WatchParty.js` | **UPDATED** | • Added compound index `{ ticketId: 1, status: 1 }` and single-field index `{ status: 1 }`. |
| `AuthToken.js` | **REMOVED** | • Deleted. Magic links now use JWT `jti` claims stored in Redis (`magiclink:<jti>`). |
| `Waitlist.js` | **NEW** | • Stores lead capture entries with `email` (unique, sparse, lowercase) and `phone` (unique, sparse). |
| `ContactSubmission.js` | **NEW** | • Stores support form inquiries (`name`, `email`, `category`, `subject`, `ticketRef`, `message`, `attachmentUrl`, `ipAddress`, `status`). |

---

## 6. Module-by-Module Codebase Changelog

- **`server.js`:**
  - Enforces mandatory `process.env.APP_URL` on boot and restricts `localhost` CORS origins to non-production environments.
  - Syncs `Film` indexes on startup (`Film.syncIndexes()`).
  - Adds `GET /health`, `GET /debug/webhook-status`, `/api/test-email`, `/api/waitlist`, and `webhookLimiter` on `/api/webhooks`.
- **`src/config/redis.js`:**
  - Calls `process.exit(1)` if Redis fails to connect on boot instead of continuing in a broken state.
- **`src/middleware/authenticate.js`:**
  - Exports `SESSION_ROLES = ['user', 'Operations_Admin', 'Super_Admin']`, rejects non-session token roles, and verifies `user.sessionVersion === decoded.sessionVersion` against MongoDB on every request.
- **`src/middleware/rbac.js`:**
  - Validates both the JWT role claim and the database `user.role` against `ROLE_HIERARCHY`, and blocks admins whose `requiresPasswordChange` flag is `true`.
- **`src/middleware/rateLimiter.js`:**
  - Connects all limiters to `RedisStore`, introduces `clientKey()` verifying `x-premia-proxy-key`, raises `apiLimiter` to `120/min`, and adds `resendMagicLinkLimiter`, `resendMagicLinkEmailLimiter`, `webhookLimiter`, `webhookReferenceLimiter`, and `contactFormLimiter`.
- **`src/services/emailService.js`:**
  - Adds 3-tier email delivery (**Resend REST API** → **Nodemailer SMTP** → **SendGrid**), dark cinema HTML templates, and Google/Outlook calendar links on ticket receipts.
- **`src/services/filmStatusJob.js`:**
  - Stops mutating `Film.isActive` during cron status transitions and removes the 60-second lookahead window so films flip to `live` at exact `premiereStart`.
- **`src/utils/geoDetector.js`:**
  - Exports `getClientIp(req)` and converts `detectUserCountry(req)` to an `async` function returning `{ countryCode, country, currency }` using Cloudflare headers, `geoip-lite`, Redis cache (`geoip:<ip>`), and an `ip-api.com` fallback.
- **`src/utils/email.js` (NEW):**
  - Exports `normalizeEmail()` and `CI_COLLATION`.
- **`src/utils/transactpayCrypto.js` & `src/utils/transactpayRefund.js` (NEW):**
  - Centralizes TransactPay RSA XML payload encryption (`encryptForge`) and automated refund requests (`transactpayRefund`).

---

## 7. Audit Findings Reference Table

Comments in the codebase reference audit IDs (`C*`, `H*`, `M*`). Use this table to look up the context of any audit tag:

| ID | Summary | Primary Files |
| :--- | :--- | :--- |
| **C1** | Prevent `invited_guest` JWT from bypassing ticket ownership check; verify webhooks server-to-server | `src/controllers/playbackController.js`, `src/controllers/webhookController.js`, `src/middleware/authenticate.js` |
| **C2** | Key rate limiters by real client IP via signed proxy header; authenticate sockets via `socketToken` | `src/middleware/rateLimiter.js`, `src/sockets/watchParty.js` |
| **C3** | Apply 7.5% VAT consistently across checkout, webhook verification, `Ticket.vat`, and analytics | `src/controllers/ticketController.js`, `src/controllers/webhookController.js`, `src/controllers/analyticsController.js` |
| **C4** | Block `reset_token` from acting as a session token; lock dashboard when `requiresPasswordChange` is true | `src/middleware/authenticate.js`, `src/middleware/rbac.js` |
| **C5** | Stamp `startedAt` once per playback session; strip password/OTP hashes from admin user responses | `src/controllers/playbackController.js`, `src/controllers/adminController.js` |
| **C6** | Parse offset-less premiere datetimes as Lagos time (`+01:00`) rather than server host timezone | `src/controllers/filmController.js`, `src/models/Film.js` |
| **C8** | Flag failed receipt emails (`emailDeliveryFailed`) and provide magic link resend endpoints | `src/controllers/webhookController.js`, `src/controllers/authController.js`, `src/models/Ticket.js` |
| **H1** | Block non-NG buyers from purchasing in `NGN`; stop cron job from mutating `Film.isActive` | `src/controllers/ticketController.js`, `src/services/filmStatusJob.js` |
| **H3** | Run `Film` `pre('save')` hooks on `updateFilm`; remove `developerDetails` from 500 payment responses | `src/controllers/filmController.js`, `src/controllers/ticketController.js` |
| **H4** | Read valid user roles dynamically from `User.schema.path('role').enumValues` | `src/controllers/adminController.js` |
| **H6** | Enforce `ROLE_HIERARCHY` and prevent stranding the platform with zero active `Super_Admin`s | `src/controllers/adminController.js` |
| **H7** | Paginate and search admin user list; add `POST /api/auth/logout` to clear `httpOnly` cookie | `src/controllers/adminController.js`, `src/controllers/authController.js` |
| **H8** | Group financial analytics by currency (`NGN` vs `USD`) instead of summing mixed currencies | `src/controllers/analyticsController.js` |
| **H9** | Require `APP_URL` and strip `localhost` CORS in production; normalize all emails to lowercase | `server.js`, `src/models/User.js`, `src/utils/email.js` |
| **H11** | Return `filmId` on `/api/auth/verify` and include `filmId` in watch party invite URLs | `src/controllers/authController.js`, `src/controllers/playbackController.js` |
| **H14** | Implement `POST /api/waitlist` lead capture endpoint and `Waitlist` model | `src/controllers/waitlistController.js`, `src/models/Waitlist.js` |
| **H20** | Automatically refund webhook payments that settle after `premiereEnd` (`refund_due` → `refunded`) | `src/controllers/webhookController.js`, `src/utils/transactpayRefund.js`, `src/models/Ticket.js` |
| **H21** | Require `Film.duration >= 1` and refuse to guess a 2-hour fallback playback window | `src/models/Film.js`, `src/controllers/playbackController.js` |
| **M9** | Store watch party host disconnect teardown deadlines in Redis (`party_teardown:*`) | `src/sockets/watchParty.js` |
| **M10** | Remove disconnecting participants from `WatchParty.participants` via `$pull` | `src/sockets/watchParty.js` |
| **M11** | Rate-limit `sendQuickMessage` and `sendReaction` events per socket (5 per 10s) | `src/sockets/watchParty.js` |
| **M12** | Validate `timestamp` is a positive finite number in `videoAction` and `timeUpdate` | `src/sockets/watchParty.js` |
| **M13** | Add `{ ticketId: 1, status: 1 }` and `{ status: 1 }` indexes to `WatchParty` | `src/models/WatchParty.js` |
| **M14** | Remove 60-second lookahead in `filmStatusJob` so `live` status matches `premiereStart` | `src/services/filmStatusJob.js` |
| **M15** | Fail fast (`process.exit(1)`) on Redis boot failure and expose `GET /health` | `src/config/redis.js`, `server.js` |
| **M16** | Floor Redis session TTL and Cloudflare token duration at 1 second (`Math.max(..., 1)`) | `src/controllers/playbackController.js` |
| **M17** | Enforce `MIN_PASSWORD_LENGTH = 8` and rate-limit `/api/auth/admin/reset-password` | `src/controllers/authController.js`, `src/routes/auth.js` |
| **M18** | Use 6-digit `crypto.randomInt` OTPs and cap failed OTP attempts at 5 per account in Redis | `src/controllers/authController.js` |

---

## 8. Environment Variables & Configuration

Copy `.env.example` to `.env` and configure the following variables:

```ini
# Core & Database
NODE_ENV=production
PORT=3000
MONGO_URI=
REDIS_URL=
JWT_SECRET=

# CORS Origins (APP_URL is required; server aborts boot if missing)
APP_URL=https://watchpremia.com
ADMIN_URL=https://admin.watchpremia.com

# Next.js Proxy Shared Secret (must match PREMIA_PROXY_KEY on the frontend)
PREMIA_PROXY_KEY=

# Cloudflare Stream (RS256 Signed Playback)
CLOUDFLARE_KEY_ID=
CLOUDFLARE_PRIVATE_KEY=

# TransactPay Payment Gateway
TRANSACTPAY_PUBLIC_KEY=
TRANSACTPAY_ENCRYPTION_KEY=
TRANSACTPAY_SECRET_KEY=
TRANSACTPAY_BASE_URL=https://payment-api-service.transactpay.ai
TRANSACTPAY_VERIFY_PATH=/payment/order/verify
TRANSACTPAY_REFUND_PATH=/payment/refund

# Email Delivery (3-Tier Failover: Resend -> SMTP -> SendGrid)
EMAIL_FROM=
SENDGRID_API_KEY=
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=          # If set to a Resend key (starts with "re_"), Resend REST API is used as primary

# Cloudinary Media Uploads
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
```

---

## 9. Test Suite & Utility Scripts

The `test/` directory contains **13 self-contained verification scripts** (plus `src/utils/geo.check.mjs`) that use Node's built-in `node:assert/strict` and require no live MongoDB or Redis connection:

```bash
node src/utils/geo.check.mjs
node test/admin-auth.test.js
node test/admin-hierarchy.test.js
node test/admin-role.test.js
node test/analytics-currency.test.js
node test/email-normalization.test.js
node test/logout-cookie.test.js
node test/playback-clock.test.js
node test/premiere-window.test.js
node test/rate-limit-key.test.js
node test/ticket-pricing.test.js
node test/waitlist-contact.test.js
node test/watch-party-socket.test.js
node test/webhook-verification.test.js
```

| Test File | What It Verifies |
| :--- | :--- |
| `src/utils/geo.check.mjs` | IP extraction (`getClientIp`), GeoIP country/currency resolution, and fallback rules. |
| `test/admin-auth.test.js` | `SESSION_ROLES` whitelist in `authenticate`, role checks in `requireRole`, and `SAFE_USER_FIELDS`. |
| `test/admin-hierarchy.test.js` | `ROLE_HIERARCHY` enforcement, peer/self-action blocks, last-`Super_Admin` guard, and `listUsers` pagination/search. |
| `test/admin-role.test.js` | Dynamic schema enum validation in `PATCH /api/admin/users/:id/role`. |
| `test/analytics-currency.test.js` | Per-currency aggregation (`$group._id = '$currency'`) and `splitByCurrency` zero-filling. |
| `test/email-normalization.test.js` | `normalizeEmail`, `User` lowercase setter, and case-insensitive `email_1_ci` index. |
| `test/logout-cookie.test.js` | `POST /api/auth/logout` `Set-Cookie` eviction header attributes in dev and production. |
| `test/playback-clock.test.js` | Single-stamp `startedAt` immutability, `duration + 45s` lockout, invalid duration handling, 1s minimum TTL, and refunded ticket blocking. |
| `test/premiere-window.test.js` | Lagos (`+01:00`) naive datetime parsing and required `Film.duration >= 1` validation. |
| `test/rate-limit-key.test.js` | `PREMIA_PROXY_KEY` verification, IPv6 `/56` grouping, spoofed header rejection, and 120/min per-visitor limit. |
| `test/ticket-pricing.test.js` | 7.5% VAT calculation, 2-decimal rounding, `NGN` region lock, and error response sanitization. |
| `test/waitlist-contact.test.js` | `buildWaitlistEntry` email/phone validation and `Waitlist` sparse unique indexes. |
| `test/watch-party-socket.test.js` | `socketToken` handshake auth, room ticket ownership, Redis teardown sweeps, `$pull` on disconnect, and chat rate limiting. |
| `test/webhook-verification.test.js` | `paymentMatchesFilm` fraud guard against underpayments and cross-currency mismatches. |
