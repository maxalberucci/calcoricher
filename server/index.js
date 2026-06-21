const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const Stripe = require('stripe');

const DEFAULT_ADMIN_EMAILS = ['max.alberucci@gmail.com'];
const DATE_LENGTH = 10;

class JsonStore {
  constructor(filePath) {
    this.filePath = filePath;
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    if (!fs.existsSync(filePath)) {
      this.write(this.empty());
    }
  }

  empty() {
    return {
      users: [],
      sessions: {},
      purchases: [],
      feed: [],
      rooms: [],
      challenges: [],
      receipts: [],
    };
  }

  read() {
    try {
      return { ...this.empty(), ...JSON.parse(fs.readFileSync(this.filePath, 'utf8')) };
    } catch (error) {
      if (error.code === 'ENOENT') return this.empty();
      throw error;
    }
  }

  write(data) {
    fs.writeFileSync(this.filePath, `${JSON.stringify(data, null, 2)}\n`);
  }

  update(mutator) {
    const data = this.read();
    const result = mutator(data);
    this.write(data);
    return result;
  }
}

function createApp(options = {}) {
  const dataDir = options.dataDir || path.join(__dirname, 'data');
  const store = options.store || new JsonStore(path.join(dataDir, 'db.json'));
  const now = options.now || (() => new Date());
  const app = express();
  const config = readConfig();

  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(express.json({ limit: '32kb' }));
  installCors(app, config);
  installRateLimit(app, config);
  installProductRoutes(app, store, config, now);
  installStripeRoutes(app, config);
  installErrorHandler(app);
  return app;
}

function readConfig() {
  const adminEmails = (process.env.ADMIN_EMAILS || DEFAULT_ADMIN_EMAILS.join(','))
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean);
  const basePriceMinor = positiveInt(process.env.BASE_PRICE_MINOR, 100);
  const usernameChangePriceMinor = positiveInt(
    process.env.USERNAME_CHANGE_PRICE_MINOR,
    100000,
  );
  const maxResultUnlocks = boundedInt(process.env.MAX_RESULT_UNLOCKS, 20, 0, 30);
  const dailySpendLimitMinor = positiveInt(process.env.DAILY_SPEND_LIMIT_MINOR, 10000);
  return {
    adminEmails,
    allowedOrigins: (process.env.ALLOWED_ORIGINS || '')
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean),
    basePriceMinor,
    usernameChangePriceMinor,
    maxResultUnlocks,
    dailySpendLimitMinor,
    currencyCode: (process.env.CHECKOUT_CURRENCY || 'chf').toLowerCase(),
    currencySymbol: process.env.CURRENCY_SYMBOL || 'CHF',
    helpUrl: process.env.HELP_URL || 'mailto:support@example.com',
    refundUrl: process.env.REFUND_URL || 'mailto:refunds@example.com',
    satireDisclosure:
      process.env.SATIRE_DISCLOSURE ||
      'Calcoricher is satire. You are paying to reveal a calculated result for entertainment.',
    rateLimitPerMinute: positiveInt(process.env.RATE_LIMIT_PER_MIN, 60),
  };
}

function positiveInt(raw, fallback) {
  const value = Number.parseInt(raw || `${fallback}`, 10);
  if (!Number.isInteger(value) || value <= 0) return fallback;
  return value;
}

function boundedInt(raw, fallback, min, max) {
  const value = Number.parseInt(raw || `${fallback}`, 10);
  if (!Number.isInteger(value) || value < min || value > max) return fallback;
  return value;
}

function installCors(app, config) {
  app.use((req, res, next) => {
    const origin = req.get('origin');
    if (origin && (config.allowedOrigins.length === 0 || config.allowedOrigins.includes(origin))) {
      res.header('Access-Control-Allow-Origin', origin);
      res.header('Vary', 'Origin');
    }
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.header('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    return next();
  });
}

function installRateLimit(app, config) {
  const hits = new Map();
  const windowMs = 60_000;
  app.use((req, res, next) => {
    const nowMs = Date.now();
    const ip = req.ip || 'unknown';
    const entry = hits.get(ip);
    if (!entry || nowMs > entry.resetAt) {
      hits.set(ip, { count: 1, resetAt: nowMs + windowMs });
      return next();
    }
    entry.count += 1;
    if (entry.count > config.rateLimitPerMinute) {
      return res.status(429).json({
        code: 'rate_limited',
        message: 'Too many requests. Try again later.',
      });
    }
    return next();
  });
  setInterval(() => {
    const nowMs = Date.now();
    for (const [ip, entry] of hits) {
      if (nowMs > entry.resetAt) hits.delete(ip);
    }
  }, windowMs).unref();
}

function installProductRoutes(app, store, config, now) {
  app.get('/api/health', (req, res) => res.json({ ok: true }));

  app.get('/api/guardrails', (req, res) => {
    res.json(guardrails(config));
  });

  app.get('/api/daily-question', (req, res) => {
    res.json(dailyQuestion(now()));
  });

  app.get('/api/daily-question/:date/leaderboard', (req, res) => {
    const data = store.read();
    res.json({ date: req.params.date, users: scopedLeaderboard(data, { dailyDate: req.params.date }) });
  });

  app.get('/api/weekly/:weekKey/leaderboard', (req, res) => {
    const weekKey = normalizeWeekKey(req.params.weekKey);
    if (!weekKey) return jsonError(res, 400, 'invalid_week', 'Week must use YYYY-Www format.');
    const data = store.read();
    const leaders = competitionLeaders(data, { weekKey });
    return res.json({ weekKey, users: leaders.spent, leaders });
  });

  app.post('/api/auth/register', (req, res) => {
    const { username, email, password } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    const cleanName = clampText(username, 80);
    if (!cleanName || !cleanEmail || typeof password !== 'string' || password.length < 4) {
      return jsonError(res, 400, 'invalid_registration', 'Username, email, and password are required.');
    }

    return store.update((data) => {
      if (data.users.some((user) => user.email === cleanEmail)) {
        return jsonError(res, 409, 'email_taken', 'This email is already registered.');
      }

      const user = createUser(cleanName, cleanEmail, password, config);
      const token = createToken();
      data.users.push(user);
      data.sessions[token] = user.id;
      return res.status(201).json({
        token,
        user: publicUser(user, data, config),
        guardrails: guardrails(config),
      });
    });
  });

  app.post('/api/auth/login', (req, res) => {
    const { email, password } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    return store.update((data) => {
      const user = data.users.find((entry) => entry.email === cleanEmail);
      if (!user || !verifyPassword(user, password || '')) {
        return jsonError(res, 401, 'invalid_credentials', 'Invalid email or password.');
      }
      if (user.deletedAt) {
        return jsonError(res, 403, 'account_deleted', 'This account has been deleted.');
      }
      if (user.isBanned) {
        return jsonError(res, 403, 'account_banned', 'This account has been banned.');
      }

      const token = createToken();
      data.sessions[token] = user.id;
      return res.json({ token, user: publicUser(user, data, config) });
    });
  });

  app.get('/api/me', requireAuth(store), (req, res) => {
    const data = store.read();
    res.json({ user: publicUser(req.user, data, config), guardrails: guardrails(config) });
  });

  app.delete('/api/me', requireAuth(store), (req, res) => {
    const token = bearerToken(req);
    return store.update((data) => {
      const user = data.users.find((entry) => entry.id === req.user.id);
      user.deletedAt = new Date().toISOString();
      user.username = 'Deleted Account';
      user.profile.bio = '';
      user.profile.links = [];
      user.profileComments = [];
      delete data.sessions[token];
      return res.json({ deleted: true });
    });
  });

  app.get('/api/users/:userId', (req, res) => {
    const data = store.read();
    const user = data.users.find((entry) => entry.id === req.params.userId && !entry.deletedAt);
    if (!user) return jsonError(res, 404, 'user_not_found', 'User not found.');
    return res.json({ user: publicUser(user, data, config, { includeComments: true }) });
  });

  app.post('/api/users/:userId/comments', requireAuth(store), (req, res) => {
    const text = clampText(req.body?.text, 500);
    if (!text) return jsonError(res, 400, 'invalid_comment', 'Comment text is required.');

    return store.update((data) => {
      const target = data.users.find((entry) => entry.id === req.params.userId && !entry.deletedAt);
      if (!target) return jsonError(res, 404, 'user_not_found', 'User not found.');
      const comment = {
        id: createId('comment'),
        targetUserId: target.id,
        authorId: req.user.id,
        authorName: req.user.username,
        text,
        reports: [],
        ownerReply: null,
        timestamp: new Date().toISOString(),
      };
      target.profileComments.unshift(comment);
      return res.status(201).json({ comment });
    });
  });

  app.post('/api/users/:userId/comments/:commentId/report', requireAuth(store), (req, res) => {
    const reason = clampText(req.body?.reason, 200) || 'Reported';
    return store.update((data) => {
      const comment = findComment(data, req.params.commentId);
      if (!comment || comment.targetUserId !== req.params.userId) {
        return jsonError(res, 404, 'comment_not_found', 'Comment not found.');
      }
      if (!comment.reports.some((report) => report.reporterId === req.user.id)) {
        comment.reports.push({
          reporterId: req.user.id,
          reporterName: req.user.username,
          reason,
          timestamp: new Date().toISOString(),
        });
      }
      return res.json({ comment });
    });
  });

  app.get('/api/admin/reports', requireAuth(store), requireAdmin, (req, res) => {
    const data = store.read();
    const reports = [];
    for (const user of data.users) {
      for (const comment of user.profileComments || []) {
        if (comment.reports?.length) reports.push({ profileOwner: publicUser(user, data, config), comment });
      }
    }
    reports.sort((a, b) => b.comment.reports.length - a.comment.reports.length);
    res.json({ reports });
  });

  app.post('/api/admin/comments/:commentId/dismiss-reports', requireAuth(store), requireAdmin, (req, res) => {
    return store.update((data) => {
      const comment = findComment(data, req.params.commentId);
      if (!comment) return jsonError(res, 404, 'comment_not_found', 'Comment not found.');
      comment.reports = [];
      return res.json({ comment });
    });
  });

  app.delete('/api/admin/comments/:commentId', requireAuth(store), requireAdmin, (req, res) => {
    return store.update((data) => {
      for (const user of data.users) {
        const before = user.profileComments.length;
        user.profileComments = user.profileComments.filter((comment) => comment.id !== req.params.commentId);
        if (user.profileComments.length !== before) return res.json({ deleted: true });
      }
      return jsonError(res, 404, 'comment_not_found', 'Comment not found.');
    });
  });

  app.post('/api/purchases', requireAuth(store), (req, res) => {
    const expression = clampText(req.body?.expression, 120);
    const result = clampText(req.body?.result, 120);
    const amountMinor = Number.parseInt(req.body?.amountMinor, 10);
    const durationMs = normalizeDurationMs(req.body?.durationMs);
    const context = normalizeContext(req.body?.context || {});

    if (!expression || !result || !Number.isInteger(amountMinor) || amountMinor <= 0) {
      return jsonError(res, 400, 'invalid_purchase', 'Expression, result, and amount are required.');
    }

    return store.update((data) => {
      const user = data.users.find((entry) => entry.id === req.user.id);
      const date = isoDate(now());
      const spentToday = data.purchases
        .filter((purchase) => purchase.userId === user.id && purchase.timestamp.slice(0, DATE_LENGTH) === date)
        .reduce((sum, purchase) => sum + purchase.amountMinor, 0);
      if (spentToday + amountMinor > config.dailySpendLimitMinor) {
        return jsonError(
          res,
          429,
          'daily_spend_limit',
          `This would exceed the daily spending limit of ${formatMoney(config.dailySpendLimitMinor, config)}.`,
        );
      }

      if (context.roomCode) addRoomMember(data, context.roomCode, user.id);
      if (context.challengeSlug) ensureChallenge(data, context.challengeSlug, user.id);

      const timestamp = now().toISOString();
      const purchase = {
        id: createId('purchase'),
        userId: user.id,
        expression,
        result,
        amountMinor,
        durationMs,
        ridiculousScore: ridiculousScore(expression),
        weekKey: isoWeekKey(new Date(timestamp)),
        context,
        timestamp,
      };

      data.purchases.unshift(purchase);
      user.totalSpentMinor += amountMinor;
      user.unlockedResultsCount += 1;
      user.highestUnlockMinor = Math.max(user.highestUnlockMinor, amountMinor);

      const receipt = createReceipt(purchase, user, config, leaderboardRank(data, user.id, config));
      purchase.receiptId = receipt.id;
      const feedItem = createFeedItem(purchase, user, receipt);

      data.receipts.unshift(receipt);
      user.receipts.unshift(receipt.id);
      user.badges = computeBadges(user);
      user.titles = computeTitles(user);
      data.feed.unshift(feedItem);
      data.feed = data.feed.slice(0, 100);

      return res.status(201).json({
        purchase,
        receipt: publicReceipt(receipt),
        feedItem,
        user: publicUser(user, data, config),
      });
    });
  });

  app.get('/api/receipts/:receiptId.svg', (req, res) => {
    const data = store.read();
    const receipt = data.receipts.find((entry) => entry.id === req.params.receiptId);
    if (!receipt) return res.status(404).type('text/plain').send('Receipt not found');
    res.type('image/svg+xml').send(renderReceiptSvg(receipt, config));
  });

  app.get('/api/leaderboard', (req, res) => {
    const data = store.read();
    res.json({ users: leaderboardUsers(data, config) });
  });

  app.get('/api/feed', (req, res) => {
    const data = store.read();
    res.json({ items: data.feed.slice(0, 50) });
  });

  app.post('/api/rooms', requireAuth(store), (req, res) => {
    const title = clampText(req.body?.title, 80) || 'Private Rich Room';
    return store.update((data) => {
      const room = {
        id: createId('room'),
        code: uniqueRoomCode(data),
        title,
        ownerId: req.user.id,
        members: [req.user.id],
        createdAt: new Date().toISOString(),
      };
      data.rooms.push(room);
      return res.status(201).json({ room });
    });
  });

  app.post('/api/rooms/:code/join', requireAuth(store), (req, res) => {
    return store.update((data) => {
      const room = data.rooms.find((entry) => entry.code === req.params.code.toUpperCase());
      if (!room) return jsonError(res, 404, 'room_not_found', 'Room not found.');
      if (!room.members.includes(req.user.id)) room.members.push(req.user.id);
      return res.json({ room });
    });
  });

  app.get('/api/rooms/:code/leaderboard', (req, res) => {
    const data = store.read();
    const room = data.rooms.find((entry) => entry.code === req.params.code.toUpperCase());
    if (!room) return jsonError(res, 404, 'room_not_found', 'Room not found.');
    res.json({ room, users: scopedLeaderboard(data, { roomCode: room.code }) });
  });

  app.get('/api/rooms/:code/competition', (req, res) => {
    const data = store.read();
    const room = data.rooms.find((entry) => entry.code === req.params.code.toUpperCase());
    if (!room) return jsonError(res, 404, 'room_not_found', 'Room not found.');
    return res.json({ room, leaders: competitionLeaders(data, { roomCode: room.code }) });
  });

  app.post('/api/challenges', requireAuth(store), (req, res) => {
    const slug = slugify(req.body?.slug);
    const title = clampText(req.body?.title, 80) || 'Creator Challenge';
    if (!slug) return jsonError(res, 400, 'invalid_challenge', 'Challenge slug is required.');
    return store.update((data) => {
      let challenge = data.challenges.find((entry) => entry.slug === slug);
      if (!challenge) {
        challenge = {
          id: createId('challenge'),
          slug,
          title,
          ownerId: req.user.id,
          members: [req.user.id],
          createdAt: new Date().toISOString(),
        };
        data.challenges.push(challenge);
      }
      return res.status(201).json({ challenge });
    });
  });

  app.get('/api/challenges/:slug', (req, res) => {
    const data = store.read();
    const challenge = data.challenges.find((entry) => entry.slug === slugify(req.params.slug));
    if (!challenge) return jsonError(res, 404, 'challenge_not_found', 'Challenge not found.');
    res.json({ challenge });
  });

  app.get('/api/challenges/:slug/leaderboard', (req, res) => {
    const data = store.read();
    const slug = slugify(req.params.slug);
    const challenge = data.challenges.find((entry) => entry.slug === slug);
    if (!challenge) return jsonError(res, 404, 'challenge_not_found', 'Challenge not found.');
    res.json({ challenge, users: scopedLeaderboard(data, { challengeSlug: slug }) });
  });

  app.get('/api/challenges/:slug/competition', (req, res) => {
    const data = store.read();
    const slug = slugify(req.params.slug);
    const challenge = data.challenges.find((entry) => entry.slug === slug);
    if (!challenge) return jsonError(res, 404, 'challenge_not_found', 'Challenge not found.');
    return res.json({ challenge, leaders: competitionLeaders(data, { challengeSlug: slug }) });
  });
}

function installStripeRoutes(app, config) {
  app.post('/create-checkout-session', async (req, res) => {
    try {
      const stripe = createStripeClient();
      const successUrl = requiredEnv('CHECKOUT_SUCCESS_URL');
      const cancelUrl = requiredEnv('CHECKOUT_CANCEL_URL');
      const { amount, description } = req.body || {};
      const allowedAmounts = allowedPaymentAmounts(config);
      if (!Number.isInteger(amount) || !allowedAmounts.has(amount)) {
        return jsonError(res, 400, 'invalid_amount', 'Invalid amount.');
      }
      const safeDescription = clampText(description, 200) || 'Result unlock';
      const session = await stripe.checkout.sessions.create({
        mode: 'payment',
        payment_method_types: ['card'],
        line_items: [
          {
            quantity: 1,
            price_data: {
              currency: config.currencyCode,
              unit_amount: amount,
              product_data: {
                name: 'Calcoricher Result',
                description: safeDescription,
              },
            },
          },
        ],
        success_url: successUrl,
        cancel_url: cancelUrl,
      });
      return res.json({ id: session.id, url: session.url });
    } catch (error) {
      console.error('create-checkout-session failed', error);
      return jsonError(res, 500, 'checkout_failed', 'Checkout could not be created.');
    }
  });

  app.get('/session-status', async (req, res) => {
    try {
      const { id } = req.query;
      if (typeof id !== 'string' || !/^cs_(test|live)_[A-Za-z0-9]+$/.test(id)) {
        return jsonError(res, 400, 'invalid_session', 'Invalid session.');
      }
      const session = await createStripeClient().checkout.sessions.retrieve(id);
      let status = 'open';
      if (session.payment_status === 'paid') status = 'paid';
      else if (session.status === 'expired') status = 'expired';
      return res.json({ status });
    } catch (error) {
      console.error('session-status failed', error);
      return jsonError(res, 500, 'session_status_failed', 'Status could not be checked.');
    }
  });
}

function createStripeClient() {
  return Stripe(requiredEnv('STRIPE_SECRET_KEY'));
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} must be set`);
  return value;
}

function allowedPaymentAmounts(config) {
  const amounts = new Set([config.usernameChangePriceMinor]);
  for (let i = 0; i <= config.maxResultUnlocks; i += 1) {
    amounts.add(config.basePriceMinor * 2 ** i);
  }
  return amounts;
}

function requireAuth(store) {
  return (req, res, next) => {
    const token = bearerToken(req);
    if (!token) return jsonError(res, 401, 'missing_token', 'Authorization is required.');
    const data = store.read();
    const userId = data.sessions[token];
    const user = data.users.find((entry) => entry.id === userId);
    if (!user) return jsonError(res, 401, 'invalid_token', 'Invalid token.');
    if (user.deletedAt) return jsonError(res, 403, 'account_deleted', 'This account has been deleted.');
    if (user.isBanned) return jsonError(res, 403, 'account_banned', 'This account has been banned.');
    req.user = user;
    return next();
  };
}

function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return jsonError(res, 403, 'admin_required', 'Admin access is required.');
  }
  return next();
}

function bearerToken(req) {
  const header = req.get('authorization') || '';
  return header.startsWith('Bearer ') ? header.slice('Bearer '.length).trim() : '';
}

function createUser(username, email, password, config) {
  const salt = crypto.randomBytes(16).toString('base64url');
  return {
    id: createId('user'),
    username,
    email,
    role: config.adminEmails.includes(email) ? 'admin' : 'user',
    passwordSalt: salt,
    passwordHash: hashPassword(password, salt),
    isBanned: false,
    deletedAt: null,
    profile: {
      title: '',
      bio: '',
      links: [],
      accent: 'gold',
      frame: 'classic',
    },
    totalSpentMinor: 0,
    unlockedResultsCount: 0,
    highestUnlockMinor: 0,
    badges: [],
    titles: [],
    receipts: [],
    profileComments: [],
    createdAt: new Date().toISOString(),
  };
}

function hashPassword(password, salt) {
  return crypto.pbkdf2Sync(password, salt, 120000, 32, 'sha256').toString('base64');
}

function verifyPassword(user, password) {
  const computed = hashPassword(password, user.passwordSalt);
  const a = Buffer.from(computed);
  const b = Buffer.from(user.passwordHash);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function publicUser(user, data, config, options = {}) {
  const purchases = data.purchases.filter((purchase) => purchase.userId === user.id);
  const rank = leaderboardUsers(data, config).findIndex((entry) => entry.id === user.id) + 1;
  return {
    id: user.id,
    username: user.username,
    email: user.email,
    role: user.role,
    isBanned: user.isBanned,
    profile: user.profile,
    totalSpentMinor: user.totalSpentMinor,
    unlockedResultsCount: user.unlockedResultsCount,
    highestUnlockMinor: user.highestUnlockMinor,
    currentResultPriceMinor: config.basePriceMinor * 2 ** user.unlockedResultsCount,
    rank,
    badges: computeBadges(user),
    titles: computeTitles(user),
    receipts: (user.receipts || [])
      .map((id) => data.receipts.find((receipt) => receipt.id === id))
      .filter(Boolean)
      .map(publicReceipt),
    profileComments: options.includeComments ? user.profileComments || [] : undefined,
    recentPurchases: purchases.slice(0, 10),
  };
}

function publicReceipt(receipt) {
  return {
    id: receipt.id,
    purchaseId: receipt.purchaseId,
    expression: receipt.expression,
    result: receipt.result,
    amountMinor: receipt.amountMinor,
    rank: receipt.rank,
    shareText: receipt.shareText,
    imageUrl: `/api/receipts/${receipt.id}.svg`,
    timestamp: receipt.timestamp,
  };
}

function guardrails(config) {
  return {
    dailySpendLimitMinor: config.dailySpendLimitMinor,
    currencyCode: config.currencyCode,
    currencySymbol: config.currencySymbol,
    satireDisclosure: config.satireDisclosure,
    helpUrl: config.helpUrl,
    refundUrl: config.refundUrl,
    priceLadder: Array.from({ length: 8 }, (_, index) => ({
      unlock: index + 1,
      amountMinor: config.basePriceMinor * 2 ** index,
      label: formatMoney(config.basePriceMinor * 2 ** index, config),
    })),
  };
}

function dailyQuestion(date) {
  const iso = isoDate(date);
  const seed = Number.parseInt(iso.replaceAll('-', ''), 10);
  const left = 10 + (seed % 41);
  const right = 2 + (Math.floor(seed / 7) % 17);
  return {
    date: iso,
    expression: `${left} * ${right}`,
    title: 'Daily Rich Question',
  };
}

function leaderboardUsers(data, config) {
  return data.users
    .filter((user) => !user.deletedAt)
    .map((user) => publicLeaderboardUser(user, data, config, user.totalSpentMinor))
    .sort((a, b) => b.totalSpentMinor - a.totalSpentMinor || b.unlockedResultsCount - a.unlockedResultsCount);
}

function leaderboardRank(data, userId, config) {
  const index = leaderboardUsers(data, config).findIndex((user) => user.id === userId);
  return index === -1 ? null : index + 1;
}

function scopedLeaderboard(data, scope) {
  return competitionLeaders(data, scope).spent;
}

function competitionLeaders(data, scope) {
  const aggregates = new Map();
  for (const purchase of scopedPurchases(data, scope)) {
    const user = data.users.find((entry) => entry.id === purchase.userId && !entry.deletedAt);
    if (!user) continue;
    if (!aggregates.has(user.id)) {
      aggregates.set(user.id, {
        id: user.id,
        username: user.username,
        totalSpentMinor: 0,
        unlockedResultsCount: 0,
        highestUnlockMinor: 0,
        ridiculousScore: 0,
        fastestRevealMs: null,
      });
    }
    const entry = aggregates.get(user.id);
    entry.totalSpentMinor += purchase.amountMinor;
    entry.unlockedResultsCount += 1;
    entry.highestUnlockMinor = Math.max(entry.highestUnlockMinor, purchase.amountMinor);
    entry.ridiculousScore = Math.max(
      entry.ridiculousScore,
      Number.isInteger(purchase.ridiculousScore)
        ? purchase.ridiculousScore
        : ridiculousScore(purchase.expression),
    );
    if (Number.isInteger(purchase.durationMs) && purchase.durationMs > 0) {
      entry.fastestRevealMs =
        entry.fastestRevealMs == null
          ? purchase.durationMs
          : Math.min(entry.fastestRevealMs, purchase.durationMs);
    }
  }

  const users = Array.from(aggregates.values());
  return {
    spent: [...users].sort(
      (a, b) =>
        b.totalSpentMinor - a.totalSpentMinor ||
        b.unlockedResultsCount - a.unlockedResultsCount ||
        a.username.localeCompare(b.username),
    ),
    highestUnlock: [...users].sort(
      (a, b) =>
        b.highestUnlockMinor - a.highestUnlockMinor ||
        b.totalSpentMinor - a.totalSpentMinor ||
        a.username.localeCompare(b.username),
    ),
    ridiculous: [...users].sort(
      (a, b) =>
        b.ridiculousScore - a.ridiculousScore ||
        b.totalSpentMinor - a.totalSpentMinor ||
        a.username.localeCompare(b.username),
    ),
    fastest: users
      .filter((user) => user.fastestRevealMs != null)
      .sort(
        (a, b) =>
          a.fastestRevealMs - b.fastestRevealMs ||
          b.totalSpentMinor - a.totalSpentMinor ||
          a.username.localeCompare(b.username),
      ),
  };
}

function scopedPurchases(data, scope) {
  return data.purchases.filter((purchase) => {
    if (scope.roomCode && purchase.context?.roomCode !== scope.roomCode) return false;
    if (scope.challengeSlug && purchase.context?.challengeSlug !== scope.challengeSlug) return false;
    if (scope.dailyDate && purchase.context?.dailyQuestionDate !== scope.dailyDate) return false;
    if (scope.weekKey && purchaseWeekKey(purchase) !== scope.weekKey) return false;
    return true;
  });
}

function publicLeaderboardUser(user, data, config, scopedTotal) {
  return {
    id: user.id,
    username: user.username,
    totalSpentMinor: scopedTotal,
    unlockedResultsCount: user.unlockedResultsCount,
    highestUnlockMinor: user.highestUnlockMinor,
    badges: computeBadges(user),
    titles: computeTitles(user),
    currentResultPriceMinor: config.basePriceMinor * 2 ** user.unlockedResultsCount,
  };
}

function createReceipt(purchase, user, config, rank) {
  const amount = formatMoney(purchase.amountMinor, config);
  return {
    id: createId('receipt'),
    purchaseId: purchase.id,
    userId: user.id,
    username: user.username,
    expression: purchase.expression,
    result: purchase.result,
    amountMinor: purchase.amountMinor,
    amount,
    rank,
    shareText: `I paid ${amount} for this answer.`,
    timestamp: purchase.timestamp,
  };
}

function createFeedItem(purchase, user, receipt) {
  return {
    id: createId('feed'),
    purchaseId: purchase.id,
    receiptId: receipt.id,
    by: user.username,
    userId: user.id,
    expression: purchase.expression,
    result: purchase.result,
    amountMinor: purchase.amountMinor,
    durationMs: purchase.durationMs,
    ridiculousScore: purchase.ridiculousScore,
    shareText: receipt.shareText,
    roomCode: purchase.context?.roomCode || null,
    challengeSlug: purchase.context?.challengeSlug || null,
    charityCampaignId: purchase.context?.charityCampaignId || null,
    timestamp: purchase.timestamp,
  };
}

function renderReceiptSvg(receipt) {
  const expression = escapeXml(receipt.expression);
  const result = escapeXml(receipt.result);
  const username = escapeXml(receipt.username);
  const shareText = escapeXml(receipt.shareText);
  const rankText = receipt.rank ? `Rank #${receipt.rank}` : 'Rank pending';
  const date = escapeXml(new Date(receipt.timestamp).toUTCString());
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" role="img" aria-label="Calcoricher receipt">
  <defs>
    <linearGradient id="bg" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0%" stop-color="#080807"/>
      <stop offset="55%" stop-color="#16120a"/>
      <stop offset="100%" stop-color="#2b210e"/>
    </linearGradient>
    <linearGradient id="gold" x1="0" x2="1">
      <stop offset="0%" stop-color="#b8872d"/>
      <stop offset="50%" stop-color="#f6d779"/>
      <stop offset="100%" stop-color="#8b611f"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect x="70" y="60" width="1060" height="510" rx="30" fill="#11100d" stroke="url(#gold)" stroke-width="4"/>
  <text x="105" y="130" fill="#f6d779" font-family="Georgia, serif" font-size="44" font-weight="700">CALCORICHER RECEIPT</text>
  <text x="105" y="180" fill="#a89f8b" font-family="Arial, sans-serif" font-size="24">Luxury arithmetic unlocked by ${username}</text>
  <text x="105" y="285" fill="#f2efe6" font-family="Arial, sans-serif" font-size="58">${expression}</text>
  <text x="105" y="365" fill="#f6d779" font-family="Georgia, serif" font-size="76">= ${result}</text>
  <rect x="105" y="410" width="990" height="1" fill="#6f5728"/>
  <text x="105" y="465" fill="#f6d779" font-family="Arial, sans-serif" font-size="38">${shareText}</text>
  <text x="105" y="515" fill="#f2efe6" font-family="Arial, sans-serif" font-size="28">${escapeXml(rankText)}</text>
  <text x="105" y="550" fill="#a89f8b" font-family="Arial, sans-serif" font-size="22">${date}</text>
</svg>`;
}

function computeBadges(user) {
  const badges = [];
  if (user.unlockedResultsCount >= 1) badges.push({ id: 'first-reveal', title: 'First Reveal' });
  if (user.unlockedResultsCount >= 10) badges.push({ id: 'habit', title: 'Calculating Habit' });
  if (user.totalSpentMinor >= 10000) badges.push({ id: 'patron', title: 'Patron' });
  if (user.highestUnlockMinor >= 1000) badges.push({ id: 'high-roller', title: 'High Roller' });
  if ((user.receipts || []).length >= 1) badges.push({ id: 'receipt-flex', title: 'Receipt Flex' });
  return badges;
}

function computeTitles(user) {
  const titles = [];
  if ((user.receipts || []).length >= 1) titles.push('Receipt Collector');
  if (user.totalSpentMinor >= 10000) titles.push('Patron of Pointless Math');
  if (user.unlockedResultsCount >= 10) titles.push('Serial Revealer');
  return titles;
}

function addRoomMember(data, code, userId) {
  const room = data.rooms.find((entry) => entry.code === code.toUpperCase());
  if (room && !room.members.includes(userId)) room.members.push(userId);
}

function ensureChallenge(data, slug, userId) {
  const cleanSlug = slugify(slug);
  if (!cleanSlug) return;
  let challenge = data.challenges.find((entry) => entry.slug === cleanSlug);
  if (!challenge) {
    challenge = {
      id: createId('challenge'),
      slug: cleanSlug,
      title: cleanSlug.replaceAll('-', ' '),
      ownerId: userId,
      members: [],
      createdAt: new Date().toISOString(),
    };
    data.challenges.push(challenge);
  }
  if (!challenge.members.includes(userId)) challenge.members.push(userId);
}

function findComment(data, commentId) {
  for (const user of data.users) {
    const comment = (user.profileComments || []).find((entry) => entry.id === commentId);
    if (comment) return comment;
  }
  return null;
}

function normalizeContext(context) {
  return {
    roomCode: context.roomCode ? clampText(context.roomCode, 12).toUpperCase() : null,
    challengeSlug: context.challengeSlug ? slugify(context.challengeSlug) : null,
    dailyQuestionDate: context.dailyQuestionDate ? clampText(context.dailyQuestionDate, 10) : null,
    charityCampaignId: context.charityCampaignId ? slugify(context.charityCampaignId) : null,
  };
}

function normalizeDurationMs(value) {
  if (value == null) return null;
  const duration = Number.parseInt(value, 10);
  if (!Number.isInteger(duration) || duration <= 0) return null;
  return Math.min(duration, 86_400_000);
}

function ridiculousScore(expression) {
  const compact = clampText(expression, 120).replace(/\s+/g, '');
  const digits = compact.match(/\d/g)?.length || 0;
  const operators = compact.match(/[+\-*/^%]/g)?.length || 0;
  const parens = compact.match(/[()]/g)?.length || 0;
  const longNumbers = compact.match(/\d{4,}/g)?.reduce((sum, run) => sum + run.length, 0) || 0;
  const repeatedDigits =
    compact.match(/(\d)\1{2,}/g)?.reduce((sum, run) => sum + run.length, 0) || 0;
  return compact.length + digits + operators * 6 + parens * 4 + longNumbers * 2 + repeatedDigits * 2;
}

function purchaseWeekKey(purchase) {
  if (purchase.weekKey) return purchase.weekKey;
  return isoWeekKey(new Date(purchase.timestamp));
}

function normalizeWeekKey(value) {
  const match = /^(\d{4})-W(\d{1,2})$/i.exec(`${value || ''}`.trim());
  if (!match) return '';
  const week = Number.parseInt(match[2], 10);
  if (!Number.isInteger(week) || week < 1 || week > 53) return '';
  return `${match[1]}-W${`${week}`.padStart(2, '0')}`;
}

function uniqueRoomCode(data) {
  let code = '';
  do {
    code = crypto.randomBytes(4).toString('base64url').replace(/[^A-Z0-9]/gi, '').toUpperCase().slice(0, 6);
  } while (code.length < 6 || data.rooms.some((room) => room.code === code));
  return code;
}

function createToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function createId(prefix) {
  return `${prefix}_${crypto.randomUUID()}`;
}

function normalizeEmail(email) {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

function clampText(value, max) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, max);
}

function slugify(value) {
  return clampText(value, 80)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function isoDate(value) {
  return value.toISOString().slice(0, DATE_LENGTH);
}

function isoWeekKey(value) {
  const date = new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((date - yearStart) / 86_400_000) + 1) / 7);
  return `${date.getUTCFullYear()}-W${`${week}`.padStart(2, '0')}`;
}

function formatMoney(minor, config) {
  const whole = Math.trunc(minor / 100);
  const cents = `${minor % 100}`.padStart(2, '0');
  return `${config.currencySymbol} ${whole}.${cents}`;
}

function escapeXml(value) {
  return `${value}`
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function jsonError(res, status, code, message) {
  return res.status(status).json({ code, message });
}

function installErrorHandler(app) {
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err.type === 'entity.too.large') {
      return jsonError(res, 413, 'request_too_large', 'Request body is too large.');
    }
    if (err.type === 'entity.parse.failed' || err instanceof SyntaxError) {
      return jsonError(res, 400, 'invalid_json', 'Invalid JSON.');
    }
    console.error('Unhandled error', err);
    return jsonError(res, 500, 'server_error', 'Server error.');
  });
}

function start() {
  const port = process.env.PORT || 4242;
  const app = createApp();
  app.listen(port, () => console.log(`Calcoricher backend listening on port ${port}`));
}

if (require.main === module) {
  start();
}

module.exports = {
  JsonStore,
  createApp,
};
