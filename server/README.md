# Calcoricher Backend

Dieses Backend stellt zwei Dinge bereit:

1. die Calcoricher-Produkt-API für globale Nutzer, Leaderboards, Feed,
   Räume, Challenges, Moderation, Account-Löschung, Guardrails und Receipt-SVGs
2. den bestehenden Stripe-Checkout für echte Zahlungen

Die lokale Entwicklung nutzt eine JSON-Datei unter `server/data/db.json`
(`data/` ist gitignored). Für Produktion sollte dieselbe API hinter einer
echten Datenbank betrieben werden.

## Schnellstart

```bash
cd server
npm install
npm test
npm start
```

Standard-Port: `4242`

Healthcheck:

```bash
curl http://127.0.0.1:4242/api/health
```

## Produkt-API

| Methode | Pfad | Zweck |
|--------|------|-------|
| GET | `/api/guardrails` | Tageslimit, Preisleiter, Hilfe/Refund, Satire-Hinweis |
| GET | `/api/daily-question` | Tagesfrage |
| GET | `/api/daily-question/:date/leaderboard` | Tagesfrage-Leaderboard |
| GET | `/api/weekly/:weekKey/leaderboard` | ISO-Wochen-Leaderboard, z. B. `2026-W25` |
| POST | `/api/auth/register` | Konto erstellen |
| POST | `/api/auth/login` | Einloggen |
| GET | `/api/me` | Aktueller Nutzer |
| DELETE | `/api/me` | Konto löschen |
| POST | `/api/purchases` | Freischaltung verbuchen, Receipt und Feed erzeugen |
| GET | `/api/receipts/:id.svg` | Shareable Receipt Card als SVG |
| GET | `/api/leaderboard` | Globales Leaderboard |
| GET | `/api/feed` | Öffentlicher Feed |
| POST | `/api/rooms` | Privaten Raum erstellen |
| POST | `/api/rooms/:code/join` | Raum beitreten |
| GET | `/api/rooms/:code/leaderboard` | Raum-Leaderboard |
| GET | `/api/rooms/:code/competition` | Raum-Wettbewerbe: Spend, Highest Unlock, Most Ridiculous, Fastest Reveal |
| POST | `/api/challenges` | Creator/Streamer-Challenge erstellen |
| GET | `/api/challenges/:slug/leaderboard` | Challenge-Leaderboard |
| GET | `/api/challenges/:slug/competition` | Challenge-Wettbewerbe: Spend, Highest Unlock, Most Ridiculous, Fastest Reveal |
| POST | `/api/users/:id/comments` | Profil kommentieren |
| POST | `/api/users/:id/comments/:commentId/report` | Kommentar melden |
| GET | `/api/admin/reports` | Admin-Report-Center |
| POST | `/api/admin/comments/:commentId/dismiss-reports` | Reports verwerfen |
| DELETE | `/api/admin/comments/:commentId` | Kommentar löschen |

Geschützte Routen erwarten:

```http
Authorization: Bearer <token>
```

Admin ist per `ADMIN_EMAILS` konfigurierbar. Ohne Variable ist
`max.alberucci@gmail.com` Admin.

`POST /api/purchases` akzeptiert optional `durationMs`. Der Server berechnet
pro Purchase zusätzlich einen `ridiculousScore`; beide Werte treiben die
Competition-Endpunkte.

## Produkt-Variablen

```bash
ADMIN_EMAILS=max.alberucci@gmail.com
BASE_PRICE_MINOR=100
USERNAME_CHANGE_PRICE_MINOR=100000
DAILY_SPEND_LIMIT_MINOR=10000
CURRENCY_SYMBOL=CHF
CHECKOUT_CURRENCY=chf
HELP_URL=mailto:support@example.com
REFUND_URL=mailto:refunds@example.com
SATIRE_DISCLOSURE="Calcoricher is satire..."
ALLOWED_ORIGINS=https://deinedomain.ch
RATE_LIMIT_PER_MIN=60
```

## Stripe-Checkout

Dieses kleine Backend erstellt Stripe-Checkout-Sessions und meldet deren
Bezahlstatus zurück. Es ist nötig, weil der **geheime Stripe-Key niemals in der
Flutter-App** liegen darf.

## Warum ein Backend?

- Der Secret Key (`sk_...`) darf nur serverseitig verwendet werden. Läge er in
  der App, könnte ihn jeder auslesen und beliebig Zahlungen auslösen.
- Apple Pay & Google Pay erscheinen **automatisch** auf der gehosteten
  Stripe-Checkout-Seite – man muss sie nicht einzeln integrieren. Für Apple Pay
  im Web ist eine einmalige Domain-Verifizierung im Stripe-Dashboard nötig.

## Einrichten

1. Stripe-Konto erstellen und unter **Entwickler → API-Keys** die Keys holen.
2. Abhängigkeiten installieren:
   ```bash
   cd server
   npm install
   ```
3. Secret Key, Redirect-URLs und erlaubte Origins setzen und starten
   (Test-Modus-Key `sk_test_...` zum Ausprobieren):
   ```bash
   STRIPE_SECRET_KEY=sk_test_xxx \
   CHECKOUT_SUCCESS_URL=https://deinedomain.ch/success?session_id={CHECKOUT_SESSION_ID} \
   CHECKOUT_CANCEL_URL=https://deinedomain.ch/cancel \
   ALLOWED_ORIGINS=https://deinedomain.ch \
   npm start
   ```
4. Server öffentlich erreichbar machen (z. B. via `ngrok http 4242`,
   Railway, Render, Fly.io, Cloud Run …).

## Mit der App verbinden

In `lib/payments/payment_config.dart`:

```dart
static const bool sandbox = false;                  // echte Zahlungen
static const String backendBaseUrl = 'https://DEINE-URL'; // ohne / am Ende
static const String currencyCode = 'chf';           // muss zum Betrag passen
static const String currencySymbol = 'CHF';
```

## Endpunkte

| Methode | Pfad | Zweck |
|--------|------|-------|
| POST | `/create-checkout-session` | `{amount, description}` → `{id, url}` |
| GET  | `/session-status?id=...`    | → `{status: "paid" \| "open" \| "expired"}` |

Der Server akzeptiert nur konfigurierte Beträge: `BASE_PRICE_MINOR * 2^n`
bis `MAX_RESULT_UNLOCKS` sowie `USERNAME_CHANGE_PRICE_MINOR`. Die App darf
Preise anzeigen, aber nicht frei bestimmen, was Stripe abrechnet.

## Sicherheit

- **Rate-Limit:** Pro IP sind standardmäßig 60 Anfragen/Minute erlaubt
  (`429` darüber). Anpassbar über `RATE_LIMIT_PER_MIN`. Hinter einem Proxy
  (ngrok/Railway/Render …) wird `trust proxy` genutzt, damit die echte IP zählt.
- **Beträge:** Es werden ausschließlich die konfigurierten Beträge akzeptiert –
  die App kann nicht frei bestimmen, was Stripe abrechnet.
- **Robustheit:** Ungültiges JSON/zu große Bodies werden sauber abgewiesen,
  die Express-Version wird nicht preisgegeben (`x-powered-by` aus).

## Hinweis zu App Stores

Werden Resultate als **digitale Inhalte** in einer iOS-/Android-App verkauft,
verlangen Apple und Google ihre **In-App-Käufe** (nicht Stripe). Für
Web/Desktop/Sideload ist Stripe der richtige Weg. Kläre das vor einer
Store-Veröffentlichung.
