# Calcoricher

Calcoricher ist ein satirischer Premium-Rechner: Die App kann rechnen, aber das
Resultat wird erst nach einer Zahlung freigeschaltet. Je mehr Resultate ein User
freischaltet, desto teurer wird das nächste Resultat. Dadurch entsteht eine
Rangliste, in der sichtbar wird, wer am meisten ausgegeben hat.

## Wofür ist die App?

Die App verbindet einen einfachen Taschenrechner mit Gamification, Profilen und
einer Rangliste. Sie ist als humorvolle Demo gedacht, wie sich Bezahlen,
Fortschritt, Statussymbole und soziale Funktionen in einer Flutter-App
kombinieren lassen.

User können:

- sich lokal registrieren und anmelden
- Rechnungen eingeben und Ergebnisse freischalten
- Ausgaben, freigeschaltete Resultate und Ränge sammeln
- Achievements freischalten
- ein persönliches Profil mit Avatar, Foto, Bio, Links und Akzentfarbe gestalten
- Profile anderer User über die Rangliste ansehen
- Profile kommentieren
- als Profilinhaber auf Kommentare antworten

## Kernfunktionen

- **Rechner mit Paywall:** Ergebnisse bleiben verborgen, bis sie freigeschaltet
  werden.
- **Steigende Preise:** Der Preis verdoppelt sich mit jedem freigeschalteten
  Resultat.
- **Leaderboard:** User werden nach ausgegebenem Betrag sortiert.
- **Profile:** Öffentliche Profile zeigen Personalisierung, Stats, Rang und
  freigeschaltete Auszeichnungen.
- **Kommentare:** Besucher können Profile kommentieren; Profilinhaber können
  direkt antworten.
- **Zahlungsmodus:** Standardmäßig läuft die App im Sandbox-Modus. Echte
  Zahlungen können über das Stripe-Backend aktiviert werden.

## Projektstruktur

```text
lib/
├── models/       # User, Verlauf und Profil-Kommentare
├── providers/    # Login, Speicherung, Käufe und Profilaktionen
├── screens/      # Rechner, Rangliste, eigenes und öffentliches Profil
├── widgets/      # Wiederverwendbare UI-Komponenten
├── payments/     # Zahlungs-Konfiguration und Stripe/Sandbox-Service
└── theme/        # Dunkles Gold-Theme

server/           # Optionales Stripe-Backend für echte Zahlungen
```

## Starten

```bash
flutter pub get
flutter run 
```
### Start for Linux

```bash
flutter run -d linux
``

Weitere Setup-Hinweise stehen in `ANLEITUNG.md`. Das Stripe-Backend ist in
`server/README.md` dokumentiert.
