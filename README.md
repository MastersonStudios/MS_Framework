# Frontier Framework

Ein schlankes, eigenständiges Roleplay-Framework für RedM.

## Enthalten

- persistente Benutzer und mehrere Charaktere
- grafische Charakterauswahl und Charaktererstellung
- Geldkonten (`cash`, `bank`) mit serverseitiger Validierung
- Jobs, Gruppen und Metadaten
- server- und clientseitige Player-API
- Callback-System zwischen Client und Server
- Admin- und Spieler-Commands
- Spawn/Respawn-Grundablauf
- SQL-Schema und Beispiel-Resource
- persistenter Ingame-Mapeditor mit Objekt-Streaming
- Admin-Logout zurück zur Charakterauswahl
- Guarma-Onboarding mit Sturm-Cinematic und Bewegungstutorial
- grafisches Adminmenü mit Wetter-, Spieler-, Geld- und Itemverwaltung

## Voraussetzungen

- aktueller RedM/FXServer Artifact
- MariaDB 10.5+ oder MySQL 8
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. `database/schema.sql` in eine leere Datenbank importieren.
2. Die Ordner aus `resources/` in den `resources`-Ordner des Servers kopieren.
3. `server.cfg.example` nach `server.cfg` kopieren und Connection-String sowie
   Lizenzschlüssel anpassen.
4. In der Konsole zuerst `ensure frontier_core` und danach
   `ensure frontier_adminmenu`, `ensure frontier_guarma_onboarding`,
   `ensure frontier_mapeditor`, `ensure frontier_adminlogout` sowie
   `ensure frontier_example` ausführen (oder den Server neu starten).
5. Zum Testen verbinden und `/characters` verwenden.

Beim ersten Beitritt öffnet sich die Charaktererstellung. In
`frontier_core/config.lua` kann optional die automatische Erstellung eines
Platzhalter-Charakters aktiviert werden.

## Wichtige API

```lua
local player = exports.frontier_core:GetPlayer(source)
player:addMoney('cash', 10, 'mission_reward')
player:addItem('water', 1, 'mission_reward')
player:setJob('sheriff', 0)

local player = exports.frontier_core:GetPlayerFromCharacterId(characterId)
```

Weitere Beispiele stehen in `resources/[frontier]/frontier_example`.

Items werden serverseitig anhand von `frontier_core/config.lua` validiert und
im Charakter-Inventar innerhalb der persistenten Metadaten gespeichert.

## Mapeditor

Administratoren mit dem ACE-Recht `frontier.mapeditor` können persistente
Map-Objekte direkt im Spiel bearbeiten:

```text
/mapeditor [modell]   Neues Objekt platzieren
/mapedit [id]         Objekt nach ID oder das nächste Objekt bearbeiten
/mapdelete [id]       Objekt nach ID oder das nächste Objekt löschen
/mapobjects           IDs der nahen Objekte anzeigen
/mapcatalog           vorkonfigurierte Modelle anzeigen
/mapundo              letzte Änderung zurücknehmen
```

Während der Bearbeitung bewegen `W/A/S/D` das Objekt, `Bild hoch/runter` ändern
die Höhe, `Q/E` drehen um Z, `R/F` kippen um X und `Z/X` kippen um Y. `Shift`
beschleunigt, `G` setzt das Objekt auf den Boden, `Enter` speichert und
`Backspace` bricht ab. Die vorkonfigurierten Modelle sowie Reichweiten stehen
in `frontier_mapeditor/config.lua`.

## Admin-Logout

Die Resource `frontier_adminlogout` speichert und entlädt einen aktiven
Charakter, bevor sie den Spieler zur Charakterauswahl zurückbringt.

```text
/logout             eigenen Charakter als Admin abmelden
/logout [Server-ID] einen Spieler abmelden
/charlogout [ID]    Alias
```

Benötigt wird das ACE-Recht `frontier.admin.logout`. Ob Admins andere Spieler
abmelden dürfen, kann in `frontier_adminlogout/config.lua` eingestellt werden.

## Grafisches Adminmenü

Die Resource `frontier_adminmenu` öffnet mit `F10` oder `/adminmenu` eine
grafische Spieler- und Serververwaltung. Enthalten sind:

- serverweit synchronisierter Wetterkonfigurator mit Übergangszeit
- Bargeld- und Bankgutschriften mit konfigurierbarem Betragslimit
- persistente Itemvergabe aus dem Core-Itemkatalog
- Goto, Bring, Heilen, Wiederbeleben, Einfrieren und Kick
- Noclip sowie Teleport zu frei eingegebenen Koordinaten
- serverseitige Validierung und Konsolenprotokollierung aller Aktionen

Benötigt wird das ACE-Recht `frontier.admin.menu`. Wettertypen,
Betragsgrenzen, Standardtaste und weitere Einstellungen stehen in
`frontier_adminmenu/config.lua`. Der Itemkatalog und die Stack-Limits befinden
sich in `frontier_core/config.lua`.

## Guarma-Onboarding

Neue Charaktere erleben einmalig eine geskriptete Sturm- und
Schiffbruch-Cinematic. Danach beginnt am Strand von Bahia de la Paz ein
Bewegungstutorial für Laufen, Sprinten, Springen und Ducken, das am Hafen endet.
Der Abschluss wird in den Charakter-Metadaten gespeichert.

Admins mit dem ACE-Recht `frontier.admin.guarma` werden bei der Strandankunft
benachrichtigt. `/guarmaadmin` öffnet das Teleportmenü, dessen Ziele vollständig
in `frontier_guarma_onboarding/config.lua` konfiguriert werden. Mit
`/guarmareset [Server-ID]` kann das Tutorial für Support oder Tests neu gestartet
werden. Strand, Hafen, Kamerafahrten, Tutorialpunkte, Inselgrenzen und sämtliche
Admin-Teleportziele lassen sich in derselben Konfigurationsdatei ändern.

## Sicherheit

Geld, Jobs und Charakterdaten werden ausschließlich serverseitig geändert.
Client-Events nehmen keine frei gewählten Geldbeträge entgegen. Für Produktion
sollten ACE-Rechte, Backups und zusätzliche Gameplay-spezifische Prüfungen
eingerichtet werden.
