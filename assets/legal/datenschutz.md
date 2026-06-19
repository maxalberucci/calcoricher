# Datenschutzerklärung

**Stand: 19. Juni 2026 · Version 1.0**

> **Hinweis:** Diese Erklärung ist eine sorgfältig erstellte Vorlage für die App
> **Calcoricher** und beschreibt die tatsächliche Datenverarbeitung der App. Sie
> ersetzt **keine** Rechtsberatung. Bitte ersetze alle `[…]`-Platzhalter durch
> deine echten Angaben und lass das Dokument vor der Veröffentlichung anwaltlich
> prüfen.

---

## 1. Verantwortlicher

Verantwortlich für die Datenverarbeitung im Sinne der EU-Datenschutz-Grundverordnung
(DSGVO) und des Schweizer Bundesgesetzes über den Datenschutz (revDSG) ist:

```
[ANBIETER – Name / Firma]
[Strasse und Hausnummer]
[PLZ, Ort, Land]
E-Mail: [datenschutz@deine-domain.tld]
[Telefon, optional]
```

**Datenschutzbeauftragte/r** (sofern bestellt): [Name / Kontakt oder „nicht
bestellt, da gesetzlich nicht erforderlich"].

**Vertretung in der EU/CH** (Art. 27 DSGVO / Art. 14 revDSG, falls erforderlich):
[Name und Anschrift oder „entfällt"].

---

## 2. Überblick: So funktioniert Calcoricher datenschutzrechtlich

Calcoricher ist eine humoristische Premium-Rechner-App. Du kannst rechnen, das
Ergebnis wird aber erst nach einer Zahlung freigeschaltet.

Das Wichtigste vorab:

- **Deine Konto- und Nutzungsdaten werden in der Standard-Konfiguration
  ausschließlich lokal auf deinem Gerät gespeichert** (im App-Speicher über
  `SharedPreferences`). Sie werden dabei **nicht** an uns oder an Dritte
  übertragen.
- Es findet **kein Tracking, keine Werbung und keine Profilbildung zu
  Werbezwecken** statt.
- Sogenannte „öffentliche" Profile, die Rangliste und Kommentare sind in dieser
  Konfiguration nur für andere Konten sichtbar, die auf **demselben Gerät /
  derselben Installation** angelegt wurden.
- Personenbezogene Daten verlassen dein Gerät nur, wenn du selbst eine Aktion
  auslöst, die einen Drittdienst einbindet – insbesondere bei **echten
  Zahlungen** (Zahlungsdienstleister) oder beim **Öffnen externer Links**.

> **Konfigurationshinweis für Betreiber:** Wird die App mit einem aktiven
> Zahlungs-Backend betrieben (`PaymentConfig.sandbox = false`), werden für die
> Zahlungsabwicklung Daten an den Zahlungsdienstleister und ggf. an dein eigenes
> Backend übertragen (siehe Abschnitt 6). Beschreibe dort dann deine konkrete
> Server-Verarbeitung.

---

## 3. Welche Daten wir verarbeiten

### 3.1 Konto- und Anmeldedaten
- **E-Mail-Adresse** (dient als Login und Konto-Kennung)
- **Benutzername**
- **Passwort** – wird **niemals im Klartext** gespeichert, sondern nur als
  gesalzener Schlüssel-Ableitungswert (PBKDF2-HMAC-SHA256, 120 000 Iterationen).
- technische **Konto-ID** und ein Kennzeichen, ob ein Konto durch die
  Administration gesperrt wurde.

### 3.2 Profil- und Inhaltsdaten (von dir freiwillig angegeben)
- Profiltitel, Bio/Beschreibungstext
- bis zu 4 verlinkte Web-Adressen (nur `http(s)`-Links werden gespeichert)
- gewählte Akzentfarbe und Emoji-Avatar
- ein optionales **Profilfoto** (Kamera/Galerie); das Bild wird **lokal** im
  App-Verzeichnis deines Geräts abgelegt.

### 3.3 Nutzungs- und Spieldaten
- Anzahl freigeschalteter Ergebnisse, insgesamt ausgegebener Betrag, höchster
  Einzelbetrag
- Verlauf der zuletzt freigeschalteten Rechnungen (Rechnung + Ergebnis, max. 50)
- freigeschaltete Auszeichnungen (Achievements) und Häufigkeit genutzter
  Rechenoperatoren
- Anzahl bezahlter Namensänderungen.

### 3.4 Kommentare
- von dir verfasste Kommentare auf Profilen sowie Antworten und Meldungen
  (jeweils mit Autorname, Avatar und Zeitstempel).

### 3.5 Einwilligungs-Daten
- deine Entscheidung im Einwilligungs-Dialog (siehe `cookies.md`), deren Version
  und der Zeitpunkt – damit wir nachweisen und respektieren können, was du
  zugestimmt hast.

Wir erheben **keine** Standortdaten, lesen **keine** Kontakte aus und betreiben
**kein** geräteübergreifendes Tracking.

---

## 4. Zwecke und Rechtsgrundlagen

| Zweck | Daten | Rechtsgrundlage DSGVO | Bezug revDSG |
|---|---|---|---|
| Bereitstellung von Konto & App-Funktionen | 3.1–3.4 | Art. 6 Abs. 1 lit. b (Vertrag) | Art. 31 Abs. 1 (Vertragserfüllung) |
| Sicherheit (Passwort-Hashing, Sperren von Konten, Missbrauchsabwehr) | 3.1, 3.4 | Art. 6 Abs. 1 lit. f (berechtigtes Interesse) | Art. 31 Abs. 1 lit. b/c |
| Zahlungsabwicklung (bei echten Zahlungen) | 3.1, 3.3, Zahlungsdaten | Art. 6 Abs. 1 lit. b | Art. 31 Abs. 1 |
| Nachweis und Beachtung von Einwilligungen | 3.5 | Art. 6 Abs. 1 lit. c / lit. a | Art. 31 / Einwilligung |
| Optionale Dienste, sofern aktiviert | je nach Dienst | Art. 6 Abs. 1 lit. a (Einwilligung) | Art. 6 Abs. 6 / Art. 31 |

Unser **berechtigtes Interesse** liegt im sicheren, funktionsfähigen und
missbrauchsfreien Betrieb der App.

---

## 5. Lokale Speicherung statt Cookies

Die App ist kein Webbrowser und setzt **keine klassischen Cookies**. Stattdessen
nutzt sie den lokalen App-Speicher des Betriebssystems (`SharedPreferences`),
um die App funktionsfähig zu halten. Gespeichert werden u. a.:

- `accounts_v2` – die lokal angelegten Konten samt der oben genannten Daten
- `current_email` – das zuletzt angemeldete Konto (damit du angemeldet bleibst)
- `legal_consent_version`, `legal_consent_optional`, `legal_consent_at` – deine
  Einwilligungs-Entscheidung.

Diese Daten sind **technisch notwendig**, damit die App überhaupt funktioniert.
Du kannst sie jederzeit entfernen, indem du dich abmeldest, dein Konto löschst
oder die App-Daten in den Systemeinstellungen löschst bzw. die App
deinstallierst. Details siehe `cookies.md`.

---

## 6. Zahlungsabwicklung

In der Standard-Konfiguration läuft die App im **Sandbox-Modus**: Zahlungen
werden lediglich simuliert, es fließt kein echtes Geld und es werden **keine**
Zahlungsdaten an Dritte übertragen.

Werden **echte Zahlungen** aktiviert, erfolgt die Abwicklung über den
Zahlungsdienstleister **[Stripe Payments Europe, Ltd. / Stripe, Inc.]**. Dabei
werden die für die Zahlung erforderlichen Daten (z. B. Zahlungsmittel, Betrag,
Transaktions- und ggf. Kontaktdaten) direkt vom Zahlungsdienstleister
verarbeitet. Wir selbst erhalten **keine vollständigen Zahlungsmittel-Daten**
(z. B. keine Kartennummer).

- Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung).
- Datenschutzinformationen des Dienstleisters: [https://stripe.com/privacy].
- Mögliche Übermittlung in Drittländer (z. B. USA) auf Grundlage der
  EU-Standardvertragsklauseln bzw. eines Angemessenheitsbeschlusses; für die
  Schweiz auf Grundlage der vom EDÖB anerkannten Garantien.

> Betreiber-Hinweis: Passe Anbieter, Links und ggf. ein eigenes Backend hier an
> deine reale Einrichtung an (`server/`).

---

## 7. Weitergabe an Dritte und externe Links

Eine Weitergabe deiner Daten erfolgt **nur**:

- an den **Zahlungsdienstleister**, wenn du eine echte Zahlung auslöst
  (Abschnitt 6),
- wenn du **externe Links** (z. B. in fremden Profilen) öffnest – dann gelangst
  du auf eine fremde Website, für deren Datenverarbeitung der jeweilige Betreiber
  verantwortlich ist, oder
- wenn wir **gesetzlich** dazu verpflichtet sind (z. B. behördliche Anordnung).

Ein Verkauf deiner Daten findet **nicht** statt.

---

## 8. Speicherdauer

Lokal gespeicherte Daten bleiben so lange erhalten, bis du sie selbst löschst
(Konto-/App-Daten löschen, App deinstallieren). Einwilligungs-Nachweise
speichern wir, solange dies zum Nachweis erforderlich ist. Zahlungsbezogene
Daten unterliegen ggf. **gesetzlichen Aufbewahrungsfristen** (z. B. handels- und
steuerrechtlich) beim Zahlungsdienstleister bzw. Betreiber.

---

## 9. Deine Rechte

Nach DSGVO (Art. 15–21) und revDSG hast du das Recht auf:

- **Auskunft** über die zu dir gespeicherten Daten,
- **Berichtigung** unrichtiger Daten,
- **Löschung** („Recht auf Vergessenwerden"),
- **Einschränkung** der Verarbeitung,
- **Datenübertragbarkeit**,
- **Widerspruch** gegen Verarbeitungen auf Grundlage berechtigter Interessen,
- **Widerruf** erteilter Einwilligungen mit Wirkung für die Zukunft.

Viele dieser Rechte kannst du **selbst direkt in der App** ausüben (Profil
bearbeiten, Verlauf löschen, abmelden, Konto-/App-Daten löschen, Einwilligung im
Datenschutz-Center widerrufen). Für darüber hinausgehende Anliegen wende dich an
die in Abschnitt 1 genannte Kontaktadresse.

**Beschwerderecht:**
- EU: Du kannst dich bei einer Datenschutz-Aufsichtsbehörde beschweren, z. B. bei
  der für deinen Wohnsitz zuständigen Behörde.
- Schweiz: zuständig ist der **Eidgenössische Datenschutz- und
  Öffentlichkeitsbeauftragte (EDÖB)**, [https://www.edoeb.admin.ch].

---

## 10. Datensicherheit

Wir treffen angemessene technische und organisatorische Maßnahmen. Dazu zählen
u. a. das Speichern von Passwörtern ausschließlich als gesalzene
PBKDF2-Ableitung, ein zeitkonstanter Passwortvergleich sowie eine
Schema-Prüfung, die nur sichere `http(s)`-Links zulässt. Bitte beachte, dass auf
deinem Gerät lokal gespeicherte Daten nur so sicher sind wie der Zugang zu deinem
Gerät selbst.

---

## 11. Minderjährige

Die App kann **echtes Geld** kosten. Sie richtet sich an volljährige bzw. nach
dem jeweils anwendbaren Recht geschäftsfähige Personen. Minderjährige dürfen die
App nur mit Zustimmung der Erziehungsberechtigten und nur im Rahmen der
gesetzlichen Vorgaben nutzen. Wir erheben nicht wissentlich Daten von Kindern.

---

## 12. Änderungen dieser Erklärung

Wir können diese Datenschutzerklärung anpassen, etwa bei Funktions- oder
Rechtsänderungen. Es gilt die jeweils in der App abrufbare aktuelle Fassung. Bei
wesentlichen Änderungen holen wir – soweit erforderlich – deine Einwilligung
erneut ein.

---

## 13. Kontakt

Bei Fragen zum Datenschutz erreichst du uns unter:
**[datenschutz@deine-domain.tld]** · [Anbieter, Anschrift siehe Abschnitt 1].
