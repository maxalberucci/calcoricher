# Calcoricher Product Loop Design

## Goal

Turn Calcoricher from a local satirical calculator demo into a backend-ready social product loop: users reveal paid answers, receive shareable receipt cards, compete globally and in rooms, see a live feed, manage profile status, and stay protected by clear spending guardrails.

## Scope

This design covers the full requested feature set, implemented incrementally without external human input:

- Global backend: auth, users, leaderboard, purchase records, comments, moderation, account deletion.
- Shareable receipt cards after each unlock.
- No-account first run, with account/payment requested only when revealing.
- Daily rich question.
- Private rooms.
- Public feed.
- Spending guardrails.
- Profile flex: badges, frames, titles, receipt gallery.
- Creator/streamer challenge links.
- Charity mode.

The current pass can build all repo-local software and tests. It cannot provision production hosting, real Stripe keys, domains, app-store billing products, legal review, or charity partner accounts. Those will be exposed as configuration points rather than faked as completed external operations.

## Product Shape

The product is a satirical status game disguised as a calculator. The first screen should let anyone type a calculation immediately. The result stays locked. Reveal requires an account and a payment path. After reveal, the user gets a receipt card designed for sharing and their action appears in the feed, leaderboard, profile gallery, and any active room/challenge.

The primary loop is:

1. User enters a calculation.
2. App evaluates it privately and shows a locked result.
3. App explains the next price, daily limit, and satire/refund disclosures.
4. User signs in or registers only if needed.
5. Payment completes in sandbox or Stripe-backed mode.
6. Backend records the purchase and emits feed, leaderboard, receipt, badges, room/challenge, and optional charity effects.

## Architecture

Use the existing Flutter app as the client and expand the existing Node server into a backend API with durable JSON storage for local development. The backend owns auth, global user state, purchases, feed, comments, rooms, challenges, daily questions, guardrails, moderation, receipts, and account deletion. This keeps security-sensitive and social-global logic out of `SharedPreferences`.

Flutter should move toward an API-backed repository layer while keeping a local fallback for development. The first backend slice provides the API contract and tests. Later app slices can replace `UserProvider` persistence calls with backend calls while preserving existing UI behavior.

## Backend Units

- `server/index.js`: Express app factory, API routes, startup wiring.
- `server/data/`: runtime JSON database directory, ignored by git.
- `server/test/product-api.test.js`: API contract tests for the social product loop.

## Data Model

- User: id, username, email, password hash/salt, role, banned/deleted flags, profile, totals, badges, receipts.
- Purchase: id, userId, expression, result, amountMinor, context, timestamp, receiptId.
- Feed item: purchase summary suitable for public display.
- Comment: profile comments and owner replies with report data.
- Room: invite code, title, owner, members, leaderboard scope.
- Challenge: creator slug, room-like leaderboard, optional prompt.
- Daily question: deterministic per date, with daily leaderboard.
- Guardrail: daily spend cap, price ladder, disclosures, refund/help links.
- Receipt: server-rendered SVG plus structured metadata.
- Charity campaign: optional purchase allocation metadata.

## Error Handling

API routes return JSON errors with stable `code` values. Auth failures use 401, banned/deleted users use 403, validation failures use 400, missing resources use 404, guardrail limits use 429, and unexpected errors use 500 without stack traces.

## Testing

Use Node's built-in `node:test` for backend contract tests. Each feature starts with a failing test, then implementation. Flutter-side wiring should keep `flutter analyze`, targeted widget/provider tests, and `flutter build web` green.

## Constraints

- No production payment provider credentials are available, so real payment capture remains configurable.
- App Store and Play Store billing cannot be completed without store setup; web-first Stripe remains the viable autonomous path.
- The backend can be global once hosted, but this repo pass can only deliver local/deployable backend code and configuration.
