# KMySync – Benutzerhandbuch (Webseite)

Das Benutzerhandbuch der Android-App [KMySync](https://github.com/PerFermat/KMySync) als statische
Webseite, auf Deutsch (`index.html`) und Englisch (`en/index.html`).

**Alles hier ist generiert, bitte nichts von Hand ändern.** Quelle sind die Handbuch-JSON-Dateien im
KMySync-Repo (dieselben wie für das PDF):

- Texte: `KMySync/docs/handbuch_de.json`, `handbuch_en.json`
- Screenshots: `KMySync/screenshots/{de,en}/`
- Aussehen und Verhalten: `KMySync/docs/web/handbuch.css`, `handbuch.js`

## Neu erzeugen

```bash
python3 ~/git/Ausgaben/docs/build_manual_web.py
```

Das Skript schreibt die Seiten nach `~/git/kmysync-handbuch`. Ein anderes Ziel gibst du mit
`--ziel` an. Screenshots werden als WebP abgelegt (540 px für die Seite, 1080 px für die Lightbox);
unveränderte Bilder überspringt es.

## Ansehen

Die Seite läuft ohne Build-Schritt, lokal zum Beispiel mit

```bash
python3 -m http.server 8000
```

und dann http://localhost:8000. Direkt als Datei geöffnet funktioniert sie auch.

## Layout

- Breite Bildschirme: Inhaltsverzeichnis, Text und ein mitlaufendes Handy mit dem Screenshot zum
  aktuellen Abschnitt.
- Mittlere Breite: Screenshots im Text, abwechselnd links und rechts.
- Schmal: eine Spalte, das Inhaltsverzeichnis öffnet sich als Schublade.

Dazu Volltextsuche, DE/EN-Umschalter (bleibt am selben Abschnitt), Hell/Dunkel.
