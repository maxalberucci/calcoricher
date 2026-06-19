// Minimaler Stripe-Checkout-Backend für den Reichen-Rechner.
//
// Erstellt Checkout-Sessions (Karte · Apple Pay · Google Pay laufen über die
// gehostete Stripe-Seite) und liefert deren Bezahlstatus zurück.
//
// WICHTIG: Der geheime Stripe-Key (STRIPE_SECRET_KEY) lebt NUR hier auf dem
// Server – niemals in der Flutter-App.

const express = require('express');
const Stripe = require('stripe');

const requiredEnv = (name) => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set`);
  }
  return value;
};

const stripe = Stripe(requiredEnv('STRIPE_SECRET_KEY'));
const app = express();
// Express-Version nicht preisgeben und IP hinter genau einem Proxy
// (ngrok/Railway/Render …) korrekt ermitteln – wichtig fürs Rate-Limit.
app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(express.json({ limit: '16kb' }));

// Einfaches In-Memory-Rate-Limit pro IP (ohne zusätzliche Abhängigkeit).
// Verhindert Missbrauch/Kosten durch massenhaftes Anlegen von Sessions.
const rateWindowMs = 60_000;
const rateMax = Number.parseInt(process.env.RATE_LIMIT_PER_MIN || '30', 10);
const rateHits = new Map(); // ip -> { count, resetAt }

app.use((req, res, next) => {
  const now = Date.now();
  const ip = req.ip || 'unknown';
  const entry = rateHits.get(ip);
  if (!entry || now > entry.resetAt) {
    rateHits.set(ip, { count: 1, resetAt: now + rateWindowMs });
    return next();
  }
  entry.count += 1;
  if (entry.count > rateMax) {
    return res
      .status(429)
      .json({ error: 'Zu viele Anfragen. Bitte später erneut versuchen.' });
  }
  next();
});

// Abgelaufene Einträge regelmäßig entfernen, damit die Map nicht wächst.
setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateHits) {
    if (now > entry.resetAt) rateHits.delete(ip);
  }
}, rateWindowMs).unref();

const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const successUrl = requiredEnv('CHECKOUT_SUCCESS_URL');
const cancelUrl = requiredEnv('CHECKOUT_CANCEL_URL');
const currency = (process.env.CHECKOUT_CURRENCY || 'chf').toLowerCase();
const basePriceMinor = Number.parseInt(process.env.BASE_PRICE_MINOR || '100', 10);
const usernameChangePriceMinor = Number.parseInt(
  process.env.USERNAME_CHANGE_PRICE_MINOR || '100000',
  10,
);
const maxResultUnlocks = Number.parseInt(process.env.MAX_RESULT_UNLOCKS || '20', 10);

if (!Number.isInteger(basePriceMinor) || basePriceMinor <= 0) {
  throw new Error('BASE_PRICE_MINOR must be a positive integer');
}
if (!Number.isInteger(usernameChangePriceMinor) || usernameChangePriceMinor <= 0) {
  throw new Error('USERNAME_CHANGE_PRICE_MINOR must be a positive integer');
}
if (!Number.isInteger(maxResultUnlocks) || maxResultUnlocks < 0 || maxResultUnlocks > 30) {
  throw new Error('MAX_RESULT_UNLOCKS must be an integer between 0 and 30');
}

const allowedAmounts = new Set([usernameChangePriceMinor]);
for (let i = 0; i <= maxResultUnlocks; i += 1) {
  allowedAmounts.add(basePriceMinor * (2 ** i));
}

const isValidSessionId = (id) =>
  typeof id === 'string' && /^cs_(test|live)_[A-Za-z0-9]+$/.test(id);

// Erlaubt Aufrufe aus der App (bei Bedarf Domain einschränken).
app.use((req, res, next) => {
  const origin = req.get('origin');
  if (origin && allowedOrigins.includes(origin)) {
    res.header('Access-Control-Allow-Origin', origin);
    res.header('Vary', 'Origin');
  }
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  res.header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// 1) Checkout-Session erstellen.
app.post('/create-checkout-session', async (req, res) => {
  try {
    const { amount, description } = req.body;
    if (!Number.isInteger(amount) || !allowedAmounts.has(amount)) {
      return res.status(400).json({ error: 'Ungültiger Betrag.' });
    }
    const safeDescription = typeof description === 'string'
      ? description.trim().slice(0, 200)
      : 'Freischaltung eines Resultats';

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      // Karte deckt automatisch Apple Pay & Google Pay ab (sofern aktiviert).
      payment_method_types: ['card'],
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency,
            unit_amount: amount, // Minor-Units (Rappen/Cent)
            product_data: {
              name: 'Reichen-Rechner Resultat',
              description: safeDescription || 'Freischaltung eines Resultats',
            },
          },
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
    });

    res.json({ id: session.id, url: session.url });
  } catch (e) {
    console.error('create-checkout-session failed', e);
    res.status(500).json({ error: 'Checkout konnte nicht erstellt werden.' });
  }
});

// 2) Bezahlstatus abfragen (die App pollt diesen Endpoint).
app.get('/session-status', async (req, res) => {
  try {
    const { id } = req.query;
    if (!isValidSessionId(id)) {
      return res.status(400).json({ error: 'Ungültige Session.' });
    }
    const session = await stripe.checkout.sessions.retrieve(id);
    // payment_status: 'paid' | 'unpaid' | 'no_payment_required'
    // status:         'open' | 'complete' | 'expired'
    let status = 'open';
    if (session.payment_status === 'paid') status = 'paid';
    else if (session.status === 'expired') status = 'expired';
    res.json({ status });
  } catch (e) {
    console.error('session-status failed', e);
    res.status(500).json({ error: 'Status konnte nicht geprüft werden.' });
  }
});

// Zentraler Fehler-Handler: saubere Antworten statt Stacktraces/Crashes
// (z. B. bei ungültigem JSON oder zu großem Body).
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Anfrage zu gross.' });
  }
  if (err.type === 'entity.parse.failed' || err instanceof SyntaxError) {
    return res.status(400).json({ error: 'Ungültiges JSON.' });
  }
  console.error('Unhandled error', err);
  return res.status(500).json({ error: 'Serverfehler.' });
});

const port = process.env.PORT || 4242;
app.listen(port, () => console.log(`Stripe-Backend läuft auf Port ${port}`));
