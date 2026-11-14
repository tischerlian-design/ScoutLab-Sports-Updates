SCOUTLAB SPORTS 0.8.1 – WINDOWS APP
===================================

INSTALLATION (EINMALIG)
1. Die ZIP-Datei mit „Alle extrahieren“ vollständig in einen normalen Ordner entpacken. Nicht aus der ZIP-Vorschau / einem Temp-Ordner starten.
2. INSTALL_SCOUTLAB.bat doppelklicken (der neue PowerShell-Installer ermittelt die Windows-Ordner automatisch).
3. Der Installer kopiert ScoutLab dauerhaft nach %LOCALAPPDATA%\Programs\ScoutLab Sports.
4. Desktop- und Startmenü-Verknüpfungen mit eigenem ScoutLab-Symbol werden eingerichtet. Pfade mit Leerzeichen/Sonderzeichen werden unterstützt.
5. Danach ScoutLab über das Desktop-/Startmenü-Symbol starten.

WICHTIGER STARTFIX 0.8.1
- Installer und Desktop-Verknüpfung verwenden START_SCOUTLAB.bat bzw. server.ps1 direkt.
- Für den normalen Start wird START_SCOUTLAB.vbs nicht mehr benötigt.
- Dadurch hängt der Programmstart nicht mehr an einem kurzlebigen ZIP-/Temp-Ordner oder einer zweiten VBS-Datei.
- INSTALL_SCOUTLAB.vbs und START_SCOUTLAB.vbs bleiben nur als Kompatibilitätsstarter für ältere Anleitungen enthalten.
- Bei „Datei nicht gefunden“ bitte die ZIP vollständig entpacken und INSTALL_SCOUTLAB.bat aus dem entpackten Ordner starten.

APP-FENSTER
- ScoutLab öffnet sich im eigenständigen Edge-/Chrome-App-Modus ohne Tabs und Adressleiste.
- Windows-Verknüpfungen verwenden app-icon.ico; die PWA nutzt app-icon-192.png und app-icon-512.png.
- START_SCOUTLAB_DEBUG.bat öffnet den Helfer sichtbar für Fehlersuche.
- Windows PowerShell 5.1 sowie Microsoft Edge oder Google Chrome werden vorausgesetzt. Python ist nicht nötig.
- Installationsordner: %LOCALAPPDATA%\Programs\ScoutLab Sports

FEATURES
- Minimalistisches Matchcenter mit hellem/dunklem Design, Favoriten und Favoritenfilter.
- Schnellwahl für gestern/heute/morgen; Tastatur: / Suche, R Aktualisieren, Pfeiltasten Tag wechseln.
- Länder-, Sport-, Wettbewerbs- und Statusfilter; Teamwappen und Sender-Favicons sofern Bildadressen vorhanden sind.
- Kalenderexport, lokale Benachrichtigungen und Live-Spielplan-Aktualisierung.
- Lokale TV-/Rechte-Datenbank bleibt offline verfügbar.

SPIELDATEN & STREAMING-RECHTE
Die Datenbank umfasst rund 630 Länder-/Gebiets-Zuordnungen für sieben Wettbewerbe. Rechtepartner, Highlights-only-Einträge und sekundäre Verzeichnisse werden getrennt gekennzeichnet. Ein Eintrag garantiert nicht, dass ein bestimmtes Einzelspiel verfügbar ist. Saison, Sublizenzen, Abos und Geoblocking können abweichen.
Live-Spielpläne stammen aus SportScore; OpenLigaDB ergänzt ausgewählte Fußball-Ligen. Vollständige weltweite Abdeckung sämtlicher Ligen ist mit den verwendeten kostenlosen Quellen nicht garantiert.

GITHUB-UPDATES – EINMALIG EINRICHTEN
1. In ScoutLab oben „Updates“ öffnen.
2. Ein öffentliches, leeres GitHub-Repository erstellen. Empfohlener Name: ScoutLab-Sports-Updates.
3. In ScoutLab die Update-Vorlage herunterladen und vollständig entpacken.
4. Alle Dateien aus dem Vorlagenordner direkt in den Stamm des GitHub-Repositories hochladen.
5. In ScoutLab Besitzer/Repository eintragen, z. B. benutzername/ScoutLab-Sports-Updates; Branch: main.
6. „Quelle speichern“ und „Updates prüfen“.
7. Updates werden erst nach deiner Bestätigung installiert. Dateien werden vor der Übernahme per SHA-256 geprüft.

SPÄTERE UPDATES
- Neue App-Dateien in deinem Update-Repository ersetzen.
- MAKE_UPDATE_MANIFEST.ps1 mit einer höheren Versionsnummer ausführen, z. B. .\MAKE_UPDATE_MANIFEST.ps1 -Version 0.8.1
- Auch update-manifest.json hochladen.
- ScoutLab erkennt das Update. In der App „Update installieren“ wählen.
- Wenn server.ps1 aktualisiert wurde, ScoutLab danach schließen und erneut starten.

DATENSCHUTZ & SICHERHEIT
- Lokaler Helfer bindet nur an 127.0.0.1.
- Externe API-Anfragen sind auf SportScore, OpenLigaDB und Open-Meteo (Wetterprognose) beschränkt.
- Updates werden über HTTPS geladen und mit SHA-256 geprüft. Das ist eine Integritätsprüfung, keine digitale Herausgebersignatur. Nutze nur ein Repository, dessen Zugriff du kontrollierst.
- Favoriten und Einstellungen liegen lokal im App-Browserprofil.
- Diagnoseprotokoll: %LOCALAPPDATA%\ScoutLabSports\scoutlab.log

FEHLERSUCHE
- Installationsfehler 123 / ungültiger Pfad: Die neue Version nutzt Windows-Spezialordner statt zusammengesetzter C:\Users-Pfade. ZIP vollständig entpacken und INSTALL_SCOUTLAB.bat erneut starten.
- App startet nicht: START_SCOUTLAB_DEBUG.bat im installierten Ordner öffnen.
- „Datei nicht gefunden“: ZIP vollständig entpacken; nicht aus ZIP-Vorschau starten.
- Port 8765 belegt: Prüfen, ob bereits eine ScoutLab-Instanz läuft.
- Keine Live-Spiele: Internetzugang, Firewall und API-Verfügbarkeit prüfen; Rechte-Datenbank bleibt offline nutzbar.
- Updatequelle nicht erreichbar: Repository öffentlich machen; update-manifest.json muss im Repository-Stamm liegen.

DATENQUELLEN
https://sportscore.com/developers/
https://api.openligadb.de/index.html
https://open-meteo.com/
https://www.uefa.com/uefachampionsleague/
https://www.uefa.com/uefaeuropaleague/
https://www.uefa.com/uefaconferenceleague/
https://www.premierleague.com/en/news/3703577/premier-league-broadcast-deals-for-2025-2028/
https://www.championsleague.basketball/en/where-to-watch


NEU IN 0.8.1
- Länder & Wettbewerbe: Länderübersicht mit Flaggen, Liga- und Pokal-Emblemen.
- Spielanalyse: Spiel anklicken für Mannschaftsvergleich, Form, letzte Spiele, Aufstellungsdaten, Spielstätte, Stadt, Anstoßzeit, Wetterprognose, Tabelle und Topscorer.
- Angaben werden nur angezeigt, wenn sie von der jeweiligen Datenquelle geliefert werden; fehlende Daten werden gekennzeichnet.
- Wettquoten sind nicht Bestandteil der App.
