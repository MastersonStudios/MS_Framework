# MSCore

MSCore ist ein eigenständiges, modulares Core-Framework für RedM. Version `0.1.0` enthält Account- und Multicharakterverwaltung, persistente Charakterdaten, Jobs, Geldkonten, Metadaten, State-Bag-Synchronisierung, Client-/Server-Callbacks, Autosave und einen sicheren Spawnablauf. Die separate Resource `MS_Char` ergänzt eine grafische Charakterauswahl und -erstellung.

Die Architektur orientiert sich an bewährten Core-Grenzen aus dem RedM-Ökosystem – Manifest-Ladereihenfolge, Core-Export, Spieler-/Charakterobjekte, Callback-Schicht und klarer Ladezyklus. Die Implementierung wurde jedoch eigenständig für MSCore geschrieben. Es wurde kein VORP-Quellcode übernommen.

## Voraussetzungen

- aktueller RedM-Server-Artefaktstand
- OneSync (`set onesync on`)
- MariaDB 10.4+ oder MySQL 8
- [oxmysql](https://github.com/CommunityOx/oxmysql)

## Installation über txAdmin

MSCore kann als Remote-URL-Template installiert werden. Verwende im txAdmin Recipe Deployer diese URL:

```text
https://raw.githubusercontent.com/MastersonStudios/MS_Framework/main/mscore_recipe.yaml
```

Das Recipe führt folgende Schritte aus:

1. lädt die offiziellen `citizenfx/cfx-server-data`-Resources,
2. installiert das fest gepinnte oxmysql-Release `v2.12.3`,
3. lädt MSCore aus diesem Repository,
4. erzeugt die `server.cfg` aus der txAdmin-Vorlage,
5. verbindet die in txAdmin konfigurierte Datenbank und importiert das Schema,
6. verschiebt die MSCore-Resource nach `resources/[MSCore]` und entfernt temporäre Dateien.

Wähle bei der Einrichtung eine leere Datenbank, beispielsweise `mscore`. Die Recipe-Konfiguration startet `oxmysql` immer vor `MSCore`. `sessionmanager-rdr3` wird nicht ausdrücklich gestartet; die aktuellen offiziellen Basisresources verwalten die erforderliche Sitzung selbst.

## Manuelle Installation

1. Kopiere den Ordner `resources/[MSCore]` mit `MSCore` und `MS_Char` in den Resources-Ordner deines Servers.
2. Installiere `oxmysql`.
3. Lege eine leere Datenbank an und setze `mysql_connection_string`.
4. Übernimm die relevanten Einträge aus `server.cfg.example`.
5. Starte zuerst `oxmysql`, danach `MSCore` und anschließend `MS_Char`.

MSCore legt seine Tabellen standardmäßig automatisch an. Wenn `Config.Database.AutoMigrate = false` gesetzt ist, importiere vorher `database/schema.sql`.

## Aufbau

```text
.
├── mscore_recipe.yaml           txAdmin Remote-URL-Recipe
├── txadmin/server.cfg           server.cfg mit txAdmin-Platzhaltern
├── server.cfg.example           Vorlage für manuelle Installationen
├── database/schema.sql          manuell importierbares Datenbankschema
└── resources/[MSCore]/
    ├── MSCore/                   Framework und Daten-Lifecycle
    │   ├── fxmanifest.lua       RedM-Metadaten und feste Ladereihenfolge
    │   ├── config.lua           Core-, Spawn-, Limit- und Jobkonfiguration
    │   ├── shared/utils.lua     gemeinsame Validierung und Hilfsfunktionen
    │   ├── server/              Datenbank, Klassen, Lifecycle und Befehle
    │   └── client/              Core-API, Callbacks und Valentine-Spawn
    └── MS_Char/                 grafische Charakterauswahl und -erstellung
        ├── config.lua           Alter, Namen, Vorschau und Outfit-Presets
        ├── server/main.lua      serverseitige Validierung und MSCore-Aufrufe
        ├── client/main.lua      Kamera, Metaped-Vorschau und NUI-Brücke
        └── ui/                  mausfähige HTML/CSS/JavaScript-Oberfläche
```

Der grafische Creator ist bewusst als separate Resource `MS_Char` umgesetzt. Ohne `MS_Char` lässt sich ein erster Charakter weiterhin über `/mscreate` anlegen.

## MS_Char

`MS_Char` öffnet sich automatisch, wenn MSCore eine Charakterauswahl anfordert oder noch kein Charakter existiert. Die NUI unterstützt die Maus vollständig und bietet:

- Auswahl mit Job, Geburtsdatum, Geld und Charakterbeschreibung
- Creator mit Vorname, Nachname, Geburtsdatum und Geschlecht
- konfigurierbare Startbekleidungs-Presets mit direkter Ped-Vorschau
- drehbare Vorschau am Bahnhof von Valentine
- serverseitige Alters-, Namens-, Slot- und Besitzprüfung
- zweistufig bestätigtes Löschen
- automatisches Anwenden des gespeicherten Aussehens nach jedem Spawn

Alter, verbotene Namen, Vorschauposition und Presets stehen in `resources/[MSCore]/MS_Char/config.lua`. `/mscharacters` meldet den aktiven Charakter ab und öffnet die Auswahl erneut.

## Konfiguration

Die wichtigsten Werte stehen in `resources/[MSCore]/MSCore/config.lua`:

- `Config.IdentifierType`: Standard `license`
- `Config.MaxCharacters`: maximale Charakterslots pro Account
- `Config.AutoSelectSingleCharacter`: einzelnen Charakter direkt laden
- `Config.DefaultCharacter`: Startgeld, Job, Werte und Spawn am Bahnhof Valentine
- `Config.SaveIntervalMs`: serverseitiges Speicherintervall
- `Config.Jobs`: statische Jobs und Grade
- `Config.AdminAce`: ACE für administrative Befehle

## Befehle

| Befehl | Berechtigung | Beschreibung |
| --- | --- | --- |
| `/mscharacters` | Spieler | aktiven Charakter abmelden und Auswahl öffnen |
| `/mscreate Vorname Nachname male\|female [JJJJ-MM-TT]` | Spieler | Charakter ohne grafischen Creator anlegen |
| `/msselect ID` | Spieler | eigenen Charakter auswählen |
| `/msdelete ID` | Spieler | inaktiven eigenen Charakter löschen |
| `/mslogout` | Spieler | aktiven Charakter abmelden |
| `/mssetgroup Server-ID Gruppe` | `mscore.admin` | Accountgruppe setzen |
| `/mssetjob Server-ID Job Grad` | `mscore.admin` | Job des aktiven Charakters setzen |
| `/msmoney Server-ID add\|remove\|set money\|gold Betrag` | `mscore.admin` | Geldkonto ändern |

Die Adminrechte werden über ACE vergeben:

```cfg
add_ace group.admin mscore.admin allow
add_principal identifier.license:DEINE_LICENSE group.admin
```

## Server-API

```lua
local Core = exports.MSCore:GetCore()
local player = Core.GetPlayer(source)
local character = player and player:GetActiveCharacter()

if character then
    character:AddMoney('money', 10.00, 'mission-reward')
    character:SetMetadata('example', true)
end
```

Verfügbare Server-Exports:

- `GetCore()`
- `GetPlayer(source)`
- `GetPlayers()`
- `RegisterJob(jobName, definition)`

Ein Job kann zur Laufzeit registriert werden:

```lua
local success, job = exports.MSCore:RegisterJob('law', {
    label = 'Gesetzeshüter',
    grades = {
        [0] = { label = 'County Sheriff', salary = 12.00 },
        [1] = { label = 'Marschall', salary = 20.00 }
    }
})
```

## Client-API und Charakter-Callbacks

```lua
local Core = exports.MSCore:GetCore()

Core.CreateCharacter({
    firstname = 'Jane',
    lastname = 'Morgan',
    sex = 'female',
    dateOfBirth = '1872-04-15'
}, function(success, result)
    if not success then print(result) end
end)
```

Clientmethoden:

- `GetPlayerData()` und `IsPlayerLoaded()`
- `GetCharacters()`
- `CreateCharacter(data, callback)`
- `SelectCharacter(characterId, callback)`
- `DeleteCharacter(characterId, callback)`
- `Logout(callback)`
- `TriggerCallback(name, callback, ...)` und `AwaitCallback(name, ...)`
- `RegisterClientCallback(name, callback)`

Wichtige lokale Clientevents:

- `mscore:client:playerLoaded`
- `mscore:client:playerUnloaded`
- `mscore:client:playerDataChanged`
- `mscore:client:charactersAvailable`
- `mscore:client:noCharacters`
- `mscore:client:spawned`
- `mscore:client:notification`

Wichtige Serverevents:

- `mscore:server:playerReady`
- `mscore:server:playerUnloaded`
- `mscore:server:characterCreated`
- `mscore:server:characterSelected`
- `mscore:server:characterUnloaded`
- `mscore:server:characterDeleted`
- `mscore:server:moneyChanged`
- `mscore:server:jobChanged`

Netzwerkereignisse mit sensiblen Daten werden serverseitig immer an die auslösende Spielerquelle gebunden. Geld-, Job-, Slot- und Charakterbesitzprüfungen finden nicht im Client statt.

## Lizenz und Referenz

MSCore steht unter der MIT-Lizenz. Als Architekturstudien dienten unter anderem [VORPCORE/vorp_core](https://github.com/VORPCORE/vorp_core) und der Installationsaufbau von [VORPCORE/VORP_txAdmin](https://github.com/VORPCORE/VORP_txAdmin). MSCore ist keine Abspaltung, übernimmt keinen VORP-Quellcode und benötigt VORP nicht.
