const assert = require('node:assert/strict');
const { mkdtemp, rm } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

process.env.STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || 'sk_test_local';
process.env.CHECKOUT_SUCCESS_URL =
  process.env.CHECKOUT_SUCCESS_URL || 'https://example.test/success';
process.env.CHECKOUT_CANCEL_URL =
  process.env.CHECKOUT_CANCEL_URL || 'https://example.test/cancel';
process.env.DAILY_SPEND_LIMIT_MINOR = '10000';

const { createApp } = require('../index');

async function withServer(fn, options = {}) {
  const dataDir = await mkdtemp(path.join(tmpdir(), 'calcoricher-api-'));
  const app = createApp({
    dataDir,
    now: options.now || (() => new Date('2026-06-21T12:00:00.000Z')),
  });
  const server = await new Promise((resolve) => {
    const listening = app.listen(0, '127.0.0.1', () => resolve(listening));
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    await fn({
      dataDir,
      request: (method, url, body, token) => request(baseUrl, method, url, body, token),
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await rm(dataDir, { recursive: true, force: true });
  }
}

async function request(baseUrl, method, url, body, token) {
  const headers = { accept: 'application/json' };
  if (body !== undefined) headers['content-type'] = 'application/json';
  if (token) headers.authorization = `Bearer ${token}`;

  const response = await fetch(`${baseUrl}${url}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const contentType = response.headers.get('content-type') || '';
  const payload = contentType.includes('application/json')
    ? await response.json()
    : await response.text();

  return { status: response.status, headers: response.headers, body: payload };
}

test('supports the core global product loop', async () => {
  await withServer(async ({ request }) => {
    const guardrails = await request('GET', '/api/guardrails');
    assert.equal(guardrails.status, 200);
    assert.equal(guardrails.body.dailySpendLimitMinor, 10000);
    assert.match(guardrails.body.satireDisclosure, /satire/i);
    assert.ok(guardrails.body.priceLadder.length >= 6);

    const daily = await request('GET', '/api/daily-question');
    assert.equal(daily.status, 200);
    assert.equal(daily.body.date, '2026-06-21');
    assert.match(daily.body.expression, /\d/);

    const ada = await request('POST', '/api/auth/register', {
      username: 'Ada Gold',
      email: 'ada@example.test',
      password: 'pass1234',
    });
    assert.equal(ada.status, 201);
    assert.ok(ada.body.token);
    assert.equal(ada.body.user.username, 'Ada Gold');
    assert.equal(ada.body.user.totalSpentMinor, 0);

    const login = await request('POST', '/api/auth/login', {
      email: 'ada@example.test',
      password: 'pass1234',
    });
    assert.equal(login.status, 200);
    assert.equal(login.body.user.id, ada.body.user.id);

    const room = await request(
      'POST',
      '/api/rooms',
      { title: 'Sunday Rich Room' },
      ada.body.token,
    );
    assert.equal(room.status, 201);
    assert.match(room.body.room.code, /^[A-Z0-9]{6}$/);

    const challenge = await request(
      'POST',
      '/api/challenges',
      { slug: 'streamer-night', title: 'Streamer Night' },
      ada.body.token,
    );
    assert.equal(challenge.status, 201);
    assert.equal(challenge.body.challenge.slug, 'streamer-night');

    const purchase = await request(
      'POST',
      '/api/purchases',
      {
        expression: '17 * 3',
        result: '51',
        amountMinor: 400,
        context: {
          roomCode: room.body.room.code,
          challengeSlug: 'streamer-night',
          dailyQuestionDate: daily.body.date,
          charityCampaignId: 'math-relief',
        },
      },
      ada.body.token,
    );
    assert.equal(purchase.status, 201);
    assert.equal(purchase.body.purchase.expression, '17 * 3');
    assert.equal(purchase.body.user.totalSpentMinor, 400);
    assert.equal(purchase.body.receipt.shareText, 'I paid CHF 4.00 for this answer.');
    assert.equal(purchase.body.receipt.rank, 1);
    assert.match(purchase.body.receipt.imageUrl, /^\/api\/receipts\//);
    assert.equal(purchase.body.feedItem.by, 'Ada Gold');
    assert.equal(purchase.body.feedItem.charityCampaignId, 'math-relief');

    const receipt = await request('GET', purchase.body.receipt.imageUrl);
    assert.equal(receipt.status, 200);
    assert.match(receipt.headers.get('content-type'), /^image\/svg\+xml/);
    assert.match(receipt.body, /I paid CHF 4\.00 for this answer/);
    assert.match(receipt.body, /Rank #1/);

    const leaderboard = await request('GET', '/api/leaderboard');
    assert.equal(leaderboard.status, 200);
    assert.equal(leaderboard.body.users[0].username, 'Ada Gold');
    assert.equal(leaderboard.body.users[0].totalSpentMinor, 400);

    const roomLeaderboard = await request('GET', `/api/rooms/${room.body.room.code}/leaderboard`);
    assert.equal(roomLeaderboard.status, 200);
    assert.equal(roomLeaderboard.body.users[0].username, 'Ada Gold');

    const challengeLeaderboard = await request(
      'GET',
      '/api/challenges/streamer-night/leaderboard',
    );
    assert.equal(challengeLeaderboard.status, 200);
    assert.equal(challengeLeaderboard.body.users[0].username, 'Ada Gold');

    const feed = await request('GET', '/api/feed');
    assert.equal(feed.status, 200);
    assert.equal(feed.body.items[0].expression, '17 * 3');
    assert.equal(feed.body.items[0].amountMinor, 400);

    const profile = await request('GET', `/api/users/${ada.body.user.id}`);
    assert.equal(profile.status, 200);
    assert.equal(profile.body.user.receipts.length, 1);
    assert.ok(profile.body.user.badges.some((badge) => badge.id === 'first-reveal'));
    assert.ok(profile.body.user.titles.includes('Receipt Collector'));

    const dailyLeaderboard = await request('GET', `/api/daily-question/${daily.body.date}/leaderboard`);
    assert.equal(dailyLeaderboard.status, 200);
    assert.equal(dailyLeaderboard.body.users[0].username, 'Ada Gold');
  });
});

test('supports comments, moderation, and account deletion', async () => {
  await withServer(async ({ request }) => {
    const admin = await request('POST', '/api/auth/register', {
      username: 'Admin',
      email: 'max.alberucci@gmail.com',
      password: 'pass1234',
    });
    const ada = await request('POST', '/api/auth/register', {
      username: 'Ada',
      email: 'ada@example.test',
      password: 'pass1234',
    });
    const bob = await request('POST', '/api/auth/register', {
      username: 'Bob',
      email: 'bob@example.test',
      password: 'pass1234',
    });

    const comment = await request(
      'POST',
      `/api/users/${ada.body.user.id}/comments`,
      { text: 'Absurdly premium.' },
      bob.body.token,
    );
    assert.equal(comment.status, 201);
    assert.equal(comment.body.comment.text, 'Absurdly premium.');

    const report = await request(
      'POST',
      `/api/users/${ada.body.user.id}/comments/${comment.body.comment.id}/report`,
      { reason: 'Testing moderation' },
      ada.body.token,
    );
    assert.equal(report.status, 200);
    assert.equal(report.body.comment.reports.length, 1);

    const reports = await request('GET', '/api/admin/reports', undefined, admin.body.token);
    assert.equal(reports.status, 200);
    assert.equal(reports.body.reports.length, 1);

    const nonAdminReports = await request('GET', '/api/admin/reports', undefined, bob.body.token);
    assert.equal(nonAdminReports.status, 403);
    assert.equal(nonAdminReports.body.code, 'admin_required');

    const dismiss = await request(
      'POST',
      `/api/admin/comments/${comment.body.comment.id}/dismiss-reports`,
      undefined,
      admin.body.token,
    );
    assert.equal(dismiss.status, 200);
    assert.equal(dismiss.body.comment.reports.length, 0);

    const deleteAccount = await request('DELETE', '/api/me', undefined, bob.body.token);
    assert.equal(deleteAccount.status, 200);
    assert.equal(deleteAccount.body.deleted, true);

    const deletedLogin = await request('POST', '/api/auth/login', {
      email: 'bob@example.test',
      password: 'pass1234',
    });
    assert.equal(deletedLogin.status, 403);
    assert.equal(deletedLogin.body.code, 'account_deleted');
  });
});

test('rejects purchases that exceed the daily spending guardrail', async () => {
  await withServer(async ({ request }) => {
    const user = await request('POST', '/api/auth/register', {
      username: 'Ada',
      email: 'ada@example.test',
      password: 'pass1234',
    });

    const first = await request(
      'POST',
      '/api/purchases',
      { expression: '1 + 1', result: '2', amountMinor: 6000 },
      user.body.token,
    );
    assert.equal(first.status, 201);

    const overLimit = await request(
      'POST',
      '/api/purchases',
      { expression: '2 + 2', result: '4', amountMinor: 5000 },
      user.body.token,
    );
    assert.equal(overLimit.status, 429);
    assert.equal(overLimit.body.code, 'daily_spend_limit');
    assert.match(overLimit.body.message, /daily spending limit/i);
  });
});

test('ranks rooms and creator challenges by spend, highest unlock, ridiculousness, and speed', async () => {
  await withServer(async ({ request }) => {
    const ada = await request('POST', '/api/auth/register', {
      username: 'Ada',
      email: 'ada@example.test',
      password: 'pass1234',
    });
    const bob = await request('POST', '/api/auth/register', {
      username: 'Bob',
      email: 'bob@example.test',
      password: 'pass1234',
    });
    const room = await request(
      'POST',
      '/api/rooms',
      { title: 'Ridiculous Math Room' },
      ada.body.token,
    );
    await request(
      'POST',
      '/api/challenges',
      { slug: 'streamer-night', title: 'Streamer Night' },
      ada.body.token,
    );

    const sharedContext = {
      roomCode: room.body.room.code,
      challengeSlug: 'streamer-night',
    };
    await request(
      'POST',
      '/api/purchases',
      {
        expression: '999999999 * (888888 + 7777) / 3 - 1',
        result: '299999666370',
        amountMinor: 900,
        durationMs: 8200,
        context: sharedContext,
      },
      ada.body.token,
    );
    await request(
      'POST',
      '/api/purchases',
      {
        expression: '2 + 2',
        result: '4',
        amountMinor: 500,
        durationMs: 1100,
        context: sharedContext,
      },
      bob.body.token,
    );
    await request(
      'POST',
      '/api/purchases',
      {
        expression: '3 + 3',
        result: '6',
        amountMinor: 500,
        durationMs: 1300,
        context: sharedContext,
      },
      bob.body.token,
    );

    const roomCompetition = await request(
      'GET',
      `/api/rooms/${room.body.room.code}/competition`,
    );
    assert.equal(roomCompetition.status, 200);
    assert.equal(roomCompetition.body.leaders.spent[0].username, 'Bob');
    assert.equal(roomCompetition.body.leaders.highestUnlock[0].username, 'Ada');
    assert.equal(roomCompetition.body.leaders.ridiculous[0].username, 'Ada');
    assert.equal(roomCompetition.body.leaders.fastest[0].username, 'Bob');
    assert.ok(roomCompetition.body.leaders.ridiculous[0].ridiculousScore > 0);
    assert.equal(roomCompetition.body.leaders.fastest[0].fastestRevealMs, 1100);

    const challengeCompetition = await request(
      'GET',
      '/api/challenges/streamer-night/competition',
    );
    assert.equal(challengeCompetition.status, 200);
    assert.equal(challengeCompetition.body.leaders.spent[0].username, 'Bob');
    assert.equal(challengeCompetition.body.leaders.highestUnlock[0].username, 'Ada');
    assert.equal(challengeCompetition.body.leaders.ridiculous[0].username, 'Ada');
    assert.equal(challengeCompetition.body.leaders.fastest[0].username, 'Bob');
  });
});

test('weekly leaderboard scopes purchases to the requested ISO week', async () => {
  let currentNow = '2026-06-21T12:00:00.000Z';
  await withServer(
    async ({ request }) => {
      const ada = await request('POST', '/api/auth/register', {
        username: 'Ada',
        email: 'ada@example.test',
        password: 'pass1234',
      });
      const bob = await request('POST', '/api/auth/register', {
        username: 'Bob',
        email: 'bob@example.test',
        password: 'pass1234',
      });

      await request(
        'POST',
        '/api/purchases',
        { expression: '10 + 1', result: '11', amountMinor: 700 },
        ada.body.token,
      );
      currentNow = '2026-06-22T12:00:00.000Z';
      await request(
        'POST',
        '/api/purchases',
        { expression: '10 + 2', result: '12', amountMinor: 800 },
        bob.body.token,
      );

      const week25 = await request('GET', '/api/weekly/2026-W25/leaderboard');
      assert.equal(week25.status, 200);
      assert.equal(week25.body.weekKey, '2026-W25');
      assert.equal(week25.body.users.length, 1);
      assert.equal(week25.body.users[0].username, 'Ada');

      const week26 = await request('GET', '/api/weekly/2026-W26/leaderboard');
      assert.equal(week26.status, 200);
      assert.equal(week26.body.weekKey, '2026-W26');
      assert.equal(week26.body.users.length, 1);
      assert.equal(week26.body.users[0].username, 'Bob');
    },
    { now: () => new Date(currentNow) },
  );
});
