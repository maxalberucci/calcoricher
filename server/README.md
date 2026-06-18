# Stripe-Backend für den Reichen-Rechner

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
3. Secret Key setzen und starten (Test-Modus-Key `sk_test_...` zum Ausprobieren):
   ```bash
   STRIPE_SECRET_KEY=sk_test_xxx npm start
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
| POST | `/create-checkout-session` | `{amount, currency, description}` → `{id, url}` |
| GET  | `/session-status?id=...`    | → `{status: "paid" \| "open" \| "expired"}` |

## Hinweis zu App Stores

Werden Resultate als **digitale Inhalte** in einer iOS-/Android-App verkauft,
verlangen Apple und Google ihre **In-App-Käufe** (nicht Stripe). Für
Web/Desktop/Sideload ist Stripe der richtige Weg. Kläre das vor einer
Store-Veröffentlichung.
