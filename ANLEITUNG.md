# Der Reichen-Rechner — Startanleitung

## 1. Flutter installieren (falls noch nicht vorhanden)

1. Gehe zu https://docs.flutter.dev/get-started/install/windows
2. Lade das Flutter SDK herunter und entpacke es, z.B. nach `C:\flutter`
3. Füge `C:\flutter\bin` zur PATH-Umgebungsvariable hinzu
4. Öffne ein neues Terminal und prüfe: `flutter doctor`

Android Studio oder VS Code mit Flutter-Extension wird empfohlen.

---

## 2. Projekt initialisieren

```powershell
cd C:\Users\maxal\rich_calculator

# Erstellt die fehlenden Plattform-Dateien (android/, ios/) ohne bestehende zu überschreiben
flutter create . --no-overwrite

# Pakete herunterladen
flutter pub get
```

---

## 3. App starten

### Auf einem Android-Gerät (empfohlen)
```powershell
# USB-Debugging am Gerät aktivieren (Einstellungen > Entwickleroptionen)
flutter devices          # Prüfe ob Gerät erkannt wird
flutter run
```

### Im Android-Emulator
```powershell
# Emulator in Android Studio starten, dann:
flutter run
```

### Schnell-Check ohne Gerät
```powershell
flutter analyze          # Zeigt Code-Fehler
flutter test             # Führt Tests aus (falls vorhanden)
```

### Auf Linux-Desktop (in dieser Umgebung)
```bash
# Einmalig: Build-Tools installieren
sudo apt install -y clang cmake ninja-build libgtk-3-dev pkg-config

# Linux-Plattform anlegen (falls noch nicht vorhanden) und starten
flutter create --platforms=linux .
flutter pub get
flutter run -d linux
```

---

## 4. Projektstruktur

```
lib/
├── main.dart                    # Einstiegspunkt + Provider-Setup
├── theme/
│   └── app_theme.dart           # Dunkles Gold-Theme
├── models/
│   └── user_model.dart          # Benutzer-Datenmodell (echtes Geld)
├── payments/
│   ├── payment_config.dart      # Währung, Basispreis, Backend-URL, Sandbox
│   └── payment_service.dart     # Stripe-Checkout + Sandbox
├── providers/
│   ├── user_provider.dart       # Login/Konten + Speicherung
│   └── calculator_provider.dart # Rechenlogik
├── screens/
│   ├── splash_screen.dart       # Startscreen → Login oder App
│   ├── login_screen.dart        # Login / Registrierung
│   ├── home_shell.dart          # Haupt-Navigation (Bottom Nav)
│   ├── calculator_screen.dart   # Rechner + Freischalten
│   ├── profile_screen.dart      # Profil (Avatar, Stats, Logout)
│   └── leaderboard_screen.dart  # Rangliste
└── widgets/
    ├── calculator_button.dart   # Stil-Button
    ├── locked_result.dart       # Edle, einheitliche Zensur
    ├── payment_sheet.dart       # Bezahl-Oberfläche
    └── luxury_background.dart   # Premium-Hintergrund

server/                          # Stripe-Backend (Node) – siehe server/README.md
```

---

## 5. Wie die App funktioniert

1. **Startscreen** — kurzer Splash, danach Login (oder direkt App, wenn angemeldet)
2. **Anmelden / Registrieren** — E-Mail + Passwort (lokal gespeichert)
3. **Rechnen** — Tippe eine Rechnung ein, z.B. `2 + 2`
4. **Resultat freischalten** — `=` drücken, dann „FREISCHALTEN"
   - Öffnet das Bezahl-Sheet (Karte · Apple Pay · Google Pay via Stripe)
   - Das Resultat bleibt bis zur erfolgreichen Zahlung **zensiert**
5. **Rangliste** — Wer hat am meisten **echtes Geld** ausgegeben?

---

## 6. Bezahlsystem (echtes Geld)

Der Preis verdoppelt sich pro freigeschaltetem Resultat (Basispreis × 1, ×2, ×4 …):

| Resultat | Preis (Basis = CHF 1.00) |
|----------|--------------------------|
| 1.       | CHF 1.00 |
| 2.       | CHF 2.00 |
| 3.       | CHF 4.00 |
| 4.       | CHF 8.00 |
| 5.       | CHF 16.00 |
| 10.      | CHF 512.00 |

- **Sandbox-Modus** (Standard): Zahlungen werden simuliert, es fließt **kein echtes
  Geld** – ideal zum Testen.
- **Echte Zahlungen**: Stripe-Backend aufsetzen (`server/README.md`) und in
  `lib/payments/payment_config.dart` `sandbox = false` + `backendBaseUrl` setzen.
  Währung und Basispreis sind dort ebenfalls konfigurierbar.

---

## 7. Häufige Fehler

| Fehler | Lösung |
|--------|--------|
| `flutter` nicht gefunden | Flutter-SDK zu PATH hinzufügen |
| `Gradle build failed` | `flutter doctor` ausführen, Android SDK prüfen |
| Gerät nicht erkannt | USB-Debugging aktivieren |
| `pub get` schlägt fehl | Internetverbindung prüfen |
