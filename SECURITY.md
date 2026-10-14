# Sicherheit und private Daten

CareerPilot speichert Bewerbungen, Kontakte, Dokumente und Logos lokal mit SwiftData.
Die App enthält keinen eigenen Backend-Dienst, keine Analytik und keine API-Schlüssel.
Das Öffnen von Stellenanzeigen, Mail-Adressen oder Meeting-Links startet externe Apps;
deren Datenverarbeitung liegt außerhalb von CareerPilot.

## Nicht veröffentlichen

- Echte Bewerbungen, Lebensläufe, Gehälter, Kontaktlisten und Bewerbungsunterlagen.
- JSON-/CSV-Backups und Kalenderexporte mit persönlichen Daten.
- SwiftData-/SQLite-Datenbanken, App-Container und persönliche Xcode-Zustände.
- `.env`-Dateien, Zugangsdaten, private Signierschlüssel und Zertifikatsdateien.

Backups enthalten Klartext und gegebenenfalls eingebettete Dokumente. Sie sind nicht
verschlüsselt. Die App bietet keine eigene Datenbankverschlüsselung. Auch temporäre
Kopien geöffneter PDFs können bis zur Systembereinigung auf dem Mac verbleiben.

## Öffentliche Demo

`scripts/build-demo.sh` baut eine separate Debug-App mit eigener Bundle-ID,
flüchtigem Bewerbungsdatenspeicher und deaktiviertem Benachrichtigungsdienst.
Die Demo zeigt ausschließlich die erfundenen Datensätze aus `SampleData.swift`.
Darstellungspräferenzen können in der separaten Demo-App erhalten bleiben.

## Fehler melden

Bitte keine privaten Bewerbungsdaten oder Zugangsdaten in öffentliche Issues laden.
Für reproduzierbare Fehler reichen meist macOS-/Xcode-Version, Schritte und
anonymisierte Beispieldaten. Bei einem Sicherheitsproblem zunächst ohne vertrauliche
Details um einen privaten Kontaktweg bitten.
