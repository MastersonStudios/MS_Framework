# MS_Trains

`MS_Trains` stellt Spielern an konfigurierbaren Bahnhof-NPCs fahrbare
RedM-Missionszüge bereit. Die Züge verwenden die vorhandenen Gleise der
Spielwelt und werden über OneSync für andere Spieler synchronisiert.

## Verwendung

- `E` beim Bahnhof-NPC: Zugmenü öffnen
- `W`: Sollgeschwindigkeit erhöhen
- `S`: bremsen
- `R`: Fahrtrichtung im vollständigen Stillstand wechseln
- `Leertaste`: Notbremse
- `/trains`: Menü beim nächsten Bahnhof-NPC öffnen
- `/trainreturn`: eigenen Zug löschen und zurückgeben

Pro Spieler ist genau ein Zug aktiv. Zusätzlich begrenzt
`MSTrainsConfig.MaxActiveTrains` die serverweite Anzahl.

## Konfiguration

Alle Einstellungen befinden sich in `config.lua`.

- `MSTrainsConfig.Stations`: NPC-, Gleis- und Standardrichtungskoordinaten
- `MSTrainsConfig.Trains`: Zugkompositionen und Fahrwerte
- `npc`: frei platzierbarer, lokaler und unverwundbarer Bahnhof-NPC
- `spawn`: Koordinate direkt auf einem vorhandenen Gleis
- `trains`: an diesem Bahnhof angebotene Zug-IDs

Vor dem Spawn prüft die Resource mit der RedM-Gleisnative, ob die konfigurierte
Koordinate für die gewählte Zugkomposition gültig ist. Ein falscher Punkt wird
abgewiesen und in der Spielmeldung erklärt.

## Hinweise

Die Resource erzeugt den Missionszug auf dem Client des anfordernden Spielers,
weil RedM-Zugphysik und Gleisbindung dort initialisiert werden. OneSync muss
aktiv sein. Eine externe Entity-Lockdown-Konfiguration, die sämtliche
clientseitig erzeugten Script-Entities blockiert, muss `MS_Trains` entsprechend
zulassen.
