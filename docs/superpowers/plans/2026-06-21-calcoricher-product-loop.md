# Calcoricher Product Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Calcoricher's backend-ready social product loop and wire the Flutter app toward it in autonomous, verifiable slices.

**Architecture:** Expand the existing Node server into a JSON-persisted API that owns global state, then adapt Flutter providers/screens to consume that product model. Keep sandbox payments and local fallback available so the app remains runnable without external credentials.

**Tech Stack:** Flutter/Dart, Provider, Express, Node built-in `node:test`, JSON file persistence, Stripe Checkout configuration.

---

## File Structure

- Modify `server/index.js`: Express app factory, JSON store, auth, product routes, receipt SVG endpoint.
- Modify `server/package.json`: add `test` script.
- Create `server/test/product-api.test.js`: backend API contract tests.
- Later modify `lib/providers/user_provider.dart`: API-backed repository integration and no-account reveal gating.
- Later create `lib/services/product_api.dart`: typed HTTP client for backend routes.
- Later create `lib/models/receipt_model.dart`, `lib/models/feed_item.dart`, `lib/models/room_model.dart`, `lib/models/daily_question.dart`: client models.
- Later modify `lib/screens/calculator_screen.dart`, `lib/screens/home_shell.dart`, `lib/screens/leaderboard_screen.dart`, `lib/screens/profile_screen.dart`, `lib/screens/public_profile_screen.dart`: visible product loop.
- Later create feed, rooms, receipt, guardrail, creator, and charity widgets/screens.

## Task 1: Backend Product API Contract

**Files:**
- Create: `server/test/product-api.test.js`
- Modify: `server/package.json`
- Modify: `server/index.js`

- [ ] **Step 1: Write failing tests**

Create tests that register users, login, fetch `/api/me`, record purchases with receipt generation, enforce daily spending caps, list leaderboard/feed/daily question, create rooms/challenges, comment/report/moderate, and delete an account.

- [ ] **Step 2: Run red test**

Run: `npm test --prefix server`

Expected: FAIL because the API app factory and routes are not implemented.

- [ ] **Step 3: Implement backend**

Refactor `server/index.js` to export `createApp` and `JsonStore`, preserve existing Stripe routes, and add `/api/*` product routes with file-backed persistence.

- [ ] **Step 4: Run green test**

Run: `npm test --prefix server`

Expected: PASS.

## Task 2: Flutter API Client and Models

**Files:**
- Create: `lib/services/product_api.dart`
- Create: `lib/models/receipt_model.dart`
- Create: `lib/models/feed_item.dart`
- Create: `lib/models/room_model.dart`
- Create: `lib/models/daily_question.dart`
- Test: `test/product_api_test.dart`

- [ ] **Step 1: Write failing Dart tests**

Tests cover JSON parsing and request mapping without a live backend by using a fake HTTP client.

- [ ] **Step 2: Implement models and API client**

Add typed models and a small client surface for auth, user, purchase, leaderboard, feed, rooms, daily question, guardrails, and account deletion.

- [ ] **Step 3: Verify**

Run: `flutter test test/product_api_test.dart`

Expected: PASS.

## Task 3: No-Account First Run and Reveal Gate

**Files:**
- Modify: `lib/screens/splash_screen.dart`
- Modify: `lib/screens/calculator_screen.dart`
- Modify: `lib/screens/login_screen.dart`
- Modify: `lib/providers/user_provider.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing widget/provider tests**

Tests prove the calculator can be used without an account, the result locks after evaluation, and reveal routes to auth/payment only when needed.

- [ ] **Step 2: Implement guest calculator path**

Allow unauthenticated calculator access, keep profile/leaderboard actions gated, and return to reveal after auth.

- [ ] **Step 3: Verify**

Run: `flutter test`

Expected: PASS.

## Task 4: Feed, Rooms, Daily, Receipts, Guardrails UI

**Files:**
- Create screens/widgets for feed, rooms, daily question, receipt gallery, guardrail disclosure, creator challenge, and charity campaign.
- Modify `lib/screens/home_shell.dart` navigation.
- Modify profile and public profile screens for badges, frames, titles, receipt gallery.

- [ ] **Step 1: Write failing widget tests for each visible surface**

Tests verify expected labels and state transitions.

- [ ] **Step 2: Implement visible surfaces**

Add feature-complete but compact screens that call `ProductApi` or local fallback.

- [ ] **Step 3: Verify**

Run: `flutter analyze && flutter test && flutter build web`

Expected: PASS.

## Task 5: Production Readiness Pass

**Files:**
- Modify docs, env examples, README, server README, legal copy, and tests.

- [ ] **Step 1: Add deployment and env documentation**

Document backend env vars, Stripe mode, web deployment, spending cap, refund/help links, and store billing constraints.

- [ ] **Step 2: Verify full repo**

Run: `npm test --prefix server && flutter analyze && flutter test && flutter build web`

Expected: PASS.

## Current Autonomous Execution Choice

The user requested no human-in-the-loop. Execute inline in this session, starting with Task 1.
