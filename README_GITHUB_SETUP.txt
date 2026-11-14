SCOUTLAB SPORTS – IN-APP-UPDATER (EINMALIGE EINRICHTUNG)
========================================================

WICHTIG
- Diese Einrichtung ist nur einmal nötig.
- Danach prüft ScoutLab beim Start automatisch auf Updates.
- Neue Versionen werden direkt in der App heruntergeladen; es gibt keine ZIP-Datei pro Update.

EINMALIGE EINRICHTUNG
1. Ein kostenloses GitHub-Konto und ein öffentliches, leeres Repository anlegen.
2. Die Datei github-update-template.zip einmal entpacken.
3. Alle enthaltenen Dateien direkt in den Stamm des GitHub-Repositories hochladen.
   update-manifest.json muss direkt im Repository-Stamm liegen.
4. In ScoutLab Einstellungen > Updates Besitzer/Repository im Format owner/repo sowie den Branch (normalerweise main) eintragen.
5. „Quelle speichern“ und „Updates prüfen“ wählen.

SPÄTERE VERSIONEN
1. Neue ScoutLab-Dateien im Update-Repository ersetzen/hochladen.
2. MAKE_UPDATE_MANIFEST.ps1 -Version 0.8.2 ausführen (Versionsnummer bei jedem Release erhöhen).
3. Die neu erzeugte update-manifest.json ebenfalls hochladen.
4. ScoutLab erkennt die neue Version automatisch beim nächsten Start bzw. spätestens bei der nächsten Updateprüfung.
5. In ScoutLab auf „Jetzt installieren“ klicken. Download, SHA-256-Prüfung und Installation laufen mit Fortschrittsanzeige in der App.

SICHERHEIT UND DATEN
- Dateien werden ausschließlich per HTTPS von raw.githubusercontent.com geladen.
- Vor dem Austausch wird jede Datei mit SHA-256 geprüft.
- Die Installation erfolgt dateiweise mit Backup/Rollback bei Fehlern.
- update_config.json, Favoriten und lokale Browserdaten werden nicht überschrieben.
- SHA-256 schützt vor Übertragungsfehlern, ersetzt aber keine Herausgeber-Signatur. Verwende nur ein Repository, dessen Besitzer und Zugriffe du kontrollierst.
- GitHub-Passwörter oder persönliche Zugriffstoken werden nicht in ScoutLab gespeichert.
