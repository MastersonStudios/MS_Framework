# Frontier Framework

Ein schlankes, eigenständiges Roleplay-Framework für RedM.

## Enthalten

- persistente Benutzer und mehrere Charaktere
- Geldkonten (`cash`, `bank`) mit serverseitiger Validierung
- Jobs, Gruppen und Metadaten
- server- und clientseitige Player-API
- Callback-System zwischen Client und Server
- Admin- und Spieler-Commands
- Spawn/Respawn-Grundablauf
- SQL-Schema und Beispiel-Resource

## Voraussetzungen

- aktueller RedM/FXServer Artifact
- MariaDB 10.5+ oder MySQL 8
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. `database/schema.sql` in eine leere Datenbank importieren.
2. Die Ordner aus `resources/` in den `resources`-Ordner des Servers kopieren.
3. `server.cfg.example` nach `server.cfg` kopieren und Connection-String sowie
   Lizenzschlüssel anpassen.
4. In der Konsole `ensure frontier_core` und danach `ensure frontier_example`
   ausführen (oder den Server neu starten).
5. Zum Testen verbinden und `/characters` verwenden.

Beim ersten Beitritt wird automatisch ein Charakter erstellt. Das lässt sich in
`frontier_core/config.lua` abschalten.

## Wichtige API

```lua
local player = exports.frontier_core:GetPlayer(source)
player:addMoney('cash', 10, 'mission_reward')
player:setJob('sheriff', 0)

local player = exports.frontier_core:GetPlayerFromCharacterId(characterId)
```

Weitere Beispiele stehen in `resources/[frontier]/frontier_example`.

## Sicherheit

Geld, Jobs und Charakterdaten werden ausschließlich serverseitig geändert.
Client-Events nehmen keine frei gewählten Geldbeträge entgegen. Für Produktion
sollten ACE-Rechte, Backups und zusätzliche Gameplay-spezifische Prüfungen
eingerichtet werden.
