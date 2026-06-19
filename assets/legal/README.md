# Rechtstexte (Datenschutz, AGB, Cookies)

Diese drei Markdown-Dateien sind die **einzige Quelle** für die rechtlichen
Texte:

- Sie werden als Flutter-**Assets** geladen und in der App angezeigt
  (Datenschutz-Screen, AGB-Screen, Cookie-/Einwilligungs-Dialog).
- Gleichzeitig kannst du sie **unverändert veröffentlichen** (Website, Store).

So bleiben App-Inhalt und veröffentlichter Text automatisch identisch.

## Vor dem Produktiveinsatz unbedingt erledigen

1. **Alle `[…]`-Platzhalter ersetzen** – Anbieter/Firma, Anschrift, E-Mail,
   Zahlungsdienstleister, Recht/Gerichtsstand, Aufsichtsbehörde.
2. **Anwaltlich prüfen lassen.** Diese Texte sind sorgfältige Vorlagen, aber
   keine Rechtsberatung. Besonders relevant: Preisangabe/Verdopplung,
   Widerrufsrecht bei digitalen Inhalten, Verbraucherschutz EU + revDSG.
3. Bei inhaltlichen Änderungen die **Version hochzählen** – sowohl in der
   Markdown-Kopfzeile als auch in `lib/legal/legal_meta.dart`
   (`LegalMeta.consentVersion`). Dadurch werden bestehende Nutzer erneut um ihre
   Einwilligung gebeten.

## Unterstütztes Markdown (MarkdownLite-Renderer)

Der eingebaute Renderer (`lib/widgets/markdown_lite.dart`) versteht eine bewusst
kleine Teilmenge: `#`/`##`/`###`-Überschriften, `- `-Aufzählungen, `>`-Zitate,
`---`-Trennlinien, ```` ``` ````-Codeblöcke, `**fett**`, ``inline-code`` sowie
`[Text](https://…)`-Links und einfache `| Tabellen |`. Halte dich beim Editieren
an diese Elemente.
