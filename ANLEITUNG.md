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

---

## 4. Projektstruktur

```
lib/
├── main.dart                    # Einstiegspunkt + Provider-Setup
├── theme/
│   └── app_theme.dart           # Dunkles Gold-Theme
├── models/
│   └── user_model.dart          # Benutzer-Datenmodell
├── providers/
│   ├── user_provider.dart       # Coin-System + Speicherung
│   └── calculator_provider.dart # Rechenlogik
├── screens/
│   ├── splash_screen.dart       # Startscreen (3 Sekunden)
│   ├── home_shell.dart          # Haupt-Navigation (Bottom Nav)
│   ├── calculator_screen.dart   # Rechner + Coin-Button
│   ├── profile_screen.dart      # Benutzerprofil
│   └── leaderboard_screen.dart  # Rangliste
└── widgets/
    ├── calculator_button.dart   # Stil-Button
    └── coin_display.dart        # Coin-Anzeige in AppBar
```

---

## 5. Wie die App funktioniert

1. **Startscreen** — 3 Sekunden Splash mit Luxus-Willkommen
2. **Profil anlegen** — Gehe zu „Profil", gib deinen Namen ein
3. **Rechnen** — Tippe eine Rechnung ein, z.B. `2 + 2`
4. **Resultat kaufen** — Drücke `=` und dann „RESULTAT ANZEIGEN"
   - Das kostet Coins: 1 → 2 → 4 → 8 → 16 → ... (verdoppelt sich)
5. **Rangliste** — Wer hat am meisten Coins ausgegeben?

---

## 6. Coin-System

| Resultat | Kosten |
|----------|--------|
| 1.       | 1 Coin |
| 2.       | 2 Coins |
| 3.       | 4 Coins |
| 4.       | 8 Coins |
| 5.       | 16 Coins |
| 10.      | 512 Coins |
| 20.      | 524'288 Coins |

Jeder Benutzer startet mit **100 Coins**.

---

## 7. Häufige Fehler

| Fehler | Lösung |
|--------|--------|
| `flutter` nicht gefunden | Flutter-SDK zu PATH hinzufügen |
| `Gradle build failed` | `flutter doctor` ausführen, Android SDK prüfen |
| Gerät nicht erkannt | USB-Debugging aktivieren |
| `pub get` schlägt fehl | Internetverbindung prüfen |
