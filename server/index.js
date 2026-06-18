// Minimaler Stripe-Checkout-Backend für den Reichen-Rechner.
//
// Erstellt Checkout-Sessions (Karte · Apple Pay · Google Pay laufen über die
// gehostete Stripe-Seite) und liefert deren Bezahlstatus zurück.
//
// WICHTIG: Der geheime Stripe-Key (STRIPE_SECRET_KEY) lebt NUR hier auf dem
// Server – niemals in der Flutter-App.

const express = require('express');
const Stripe = require('stripe');

const stripe = Stripe(process.env.STRIPE_SECRET_KEY);
const app = express();
app.use(express.json());

// Erlaubt Aufrufe aus der App (bei Bedarf Domain einschränken).
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// 1) Checkout-Session erstellen.
app.post('/create-checkout-session', async (req, res) => {
  try {
    const { amount, currency, description } = req.body;
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Ungültiger Betrag.' });
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      // Karte deckt automatisch Apple Pay & Google Pay ab (sofern aktiviert).
      payment_method_types: ['card'],
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: currency || 'chf',
            unit_amount: amount, // Minor-Units (Rappen/Cent)
            product_data: {
              name: 'Reichen-Rechner Resultat',
              description: description || 'Freischaltung eines Resultats',
            },
          },
        },
      ],
      success_url: 'https://example.com/success?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: 'https://example.com/cancel',
    });

    res.json({ id: session.id, url: session.url });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 2) Bezahlstatus abfragen (die App pollt diesen Endpoint).
app.get('/session-status', async (req, res) => {
  try {
    const session = await stripe.checkout.sessions.retrieve(req.query.id);
    // payment_status: 'paid' | 'unpaid' | 'no_payment_required'
    // status:         'open' | 'complete' | 'expired'
    let status = 'open';
    if (session.payment_status === 'paid') status = 'paid';
    else if (session.status === 'expired') status = 'expired';
    res.json({ status });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const port = process.env.PORT || 4242;
app.listen(port, () => console.log(`Stripe-Backend läuft auf Port ${port}`));
