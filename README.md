# Frontier Framework

Ein schlankes, eigenständiges Roleplay-Framework für RedM.

Aktuelle Framework-Version: `0.0.1`

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
- grafisches ACP mit Rechte-, Wetter-, Spieler-, Geld- und Itemverwaltung
- Support Admin mit persistenten Verbindungs-, Spawn-, Schadens- und Tötungslogs
- grafischer World Builder für NPCs, Storages und sperrbare Türen
- persistente Crafting-Rezepte und frei platzierbare Crafting-Punkte
- Data Admin mit Datenbank-Itemcreator und durchsuchbarem Prop-Katalog
- serverautoritatives Spieler-Presence-Sync für bis zu 64 Slots
- `MS_WeaponDamage` mit einzeln konfigurierbarem Schaden für sämtliche Waffen
- `MS_Inventory` mit konfigurierbarer Kapazität, Kontextaktionen und Outfit-Drag-and-Drop
- `MS_ClothingShop` mit Charaktervorschau und gemeinsamer Einkaufsliste
- `MS_Stables` mit Pferde-, Ausrüstungs-, Fellfarben- und Kutschenhandel
- `MS_Trains` mit fahrbaren Zügen und konfigurierbaren Bahnhof-NPCs
- `MS_Telegrams` mit persönlichen Telegrammnummern und persistenten Nachrichten
- `MS_LoadingScreen` mit Video-Cutscene, animierter Ersatzszene und Mute-Funktion

## Voraussetzungen

- aktueller RedM/FXServer Artifact
- MariaDB 10.5+ oder MySQL 8
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. `database/schema.sql` in eine leere Datenbank importieren.
2. Die Ordner aus `resources/` in den `resources`-Ordner des Servers kopieren.
3. `server.cfg.example` nach `server.cfg` kopieren und Connection-String sowie
   Lizenzschlüssel anpassen.
4. In der Konsole zuerst `ensure MS_LoadingScreen` und `ensure frontier_core`,
   danach
   `ensure frontier_playersync`, `ensure MS_WeaponDamage`, `ensure MS_Inventory`,
   `ensure MS_ClothingShop`, `ensure MS_Stables`, `ensure MS_Trains`,
   `ensure MS_Telegrams`,
   `ensure frontier_worldbuilder`,
   `ensure frontier_adminmenu`,
   `ensure frontier_guarma_onboarding`, `ensure frontier_mapeditor`,
   `ensure frontier_adminlogout` sowie `ensure frontier_example` ausführen
   (oder den Server neu starten).
5. Zum Testen verbinden und `/characters` verwenden.

Beim ersten Beitritt öffnet sich die Charaktererstellung. In
`frontier_core/config.lua` kann optional die automatische Erstellung eines
Platzhalter-Charakters aktiviert werden.

## Versionsabfrage

`frontier_core` prüft nach dem Serverstart automatisch die zentrale
`version.json` auf GitHub. Die lokale Version stammt aus dem
Resource-Manifest und ist aktuell auf `0.0.1` gesetzt. Netzwerk- oder
GitHub-Fehler werden nur protokolliert und blockieren den Serverstart nicht.

```text
/frameworkversion
/frameworkversion check
```

Die einfache Abfrage ist für alle Spieler verfügbar. Eine neue GitHub-Abfrage
benötigt das ACE-Recht `frontier.version.check`. URL, Verzögerung,
Mindestintervall und Aktivierung befinden sich in
`resources/[frontier]/frontier_core/config.lua`.

Andere Server-Resources können Version und Prüfstatus abfragen:

```lua
local version = exports.frontier_core:GetFrameworkVersion()
local state = exports.frontier_core:GetFrameworkVersionState()
exports.frontier_core:CheckFrameworkVersion()
```

Nach jeder abgeschlossenen Prüfung wird zusätzlich das Serverevent
`frontier:server:versionChecked` mit dem aktuellen Status ausgelöst.

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

## MS Inventory

Die Resource `MS_Inventory` ersetzt die reine Metadatenablage durch ein
grafisches Slot- und Gewichtsinventar. Standardmäßig wird es mit `I` oder
`/inventory` geöffnet.

- Die Kapazität wird zentral über `Config.Inventory.Slots` und
  `Config.Inventory.MaxWeight` in
  `resources/[frontier]/frontier_core/config.lua` konfiguriert.
- Ein Rechtsklick auf ein Item öffnet die Aktionen **Übergeben**,
  **Wegwerfen** und **Benutzen**. Besitz, Menge, Entfernung, Handelbarkeit und
  Zielkapazität werden auf dem Server geprüft.
- Der Tab **Outfits** zeigt rechts das itembezogene Bekleidungsinventar.
  Kleidungsstücke werden per Drag-and-Drop ausgerüstet und können zurück in
  das Hauptinventar gezogen werden.
- Outfit-Zustand und Inventar werden persistent in den Charaktermetadaten
  gespeichert.

Ein Bekleidungsitem benötigt in den Standard-Metadaten einen gültigen Slot,
beispielsweise `{"clothingSlot":"hat"}`. Optional kann
`componentHash` als numerischer Meta-Ped-Komponentenhash hinterlegt werden,
damit das Kleidungsstück auch am Ped dargestellt wird:

```json
{"clothingSlot":"hat","componentHash":123456789}
```

Gültige Standardslots stehen in
`resources/[frontier]/MS_Inventory/config.lua`. Neue Kleidungsitems lassen
sich damit direkt über **ACP → Data Admin → Itemcreator** anlegen.

## MS Clothing Shop

`MS_ClothingShop` ist ein grafischer Bekleidungsladen mit einer direkten
Vorschau am eigenen Charakter:

- Händler werden an konfigurierbaren Positionen gestreamt.
- Ein Klick auf ein Kleidungsstück zeigt dessen Meta-Ped-Komponente am
  Charakter. Drehung und Zoom der Vorschaukamera sind über das UI steuerbar.
- Mehrere Kleidungsstücke können in einer Sammeleinkaufsliste kombiniert und
  in einer Transaktion bezahlt werden.
- Die gesamte Liste wird vor dem Kauf serverseitig gegen Händlerentfernung,
  Geschlecht, Itemkatalog, Kontostand sowie Slot- und Gewichtskapazität geprüft.
- Nach erfolgreicher Bezahlung wird jedes Kleidungsstück als handelbares,
  persistentes Item in `MS_Inventory` ausgegeben.
- Beim Schließen werden alle Vorschaukomponenten entfernt und das gespeicherte
  Outfit wiederhergestellt.

Die Händlerpositionen, Preise, das verwendete Konto, die maximale Listengröße
und der Produktkatalog befinden sich in
`resources/[frontier]/MS_ClothingShop/config.lua`. Standardmäßig wird der
nächste Händler mit `E` oder `/clothingshop` geöffnet.

Die zehn Beispielartikel für männliche und weibliche Charaktere liegen in
`frontier_core/config.lua`. Für eigene Artikel sind mindestens diese
Item-Metadaten notwendig:

```json
{"clothingSlot":"coat","componentHash":331167570,"sex":"male"}
```

Erlaubte Geschlechtswerte sind `male`, `female` und `unisex`. Der
Bekleidungsshop zeigt nur passende Produkte, und `MS_Inventory` prüft diese
Angabe erneut beim Ausrüsten.

## Spielersynchronisation

Die Resource `frontier_playersync` ergänzt OneSync um einen serverautoritativ
verwalteten Presence- und Charakterdaten-Cache für bis zu 64 Spieler. OneSync
bleibt für Peds, Bewegung und andere Netzwerk-Entities zuständig; die Resource
verteilt nur Änderungen an öffentlichen Framework-Daten und Routing-Buckets.
Geld, Inventar, Geburtsdatum und Metadaten werden nicht an andere Spieler
übertragen.

```lua
-- Client: alle geladenen Charaktere
local players = exports.frontier_playersync:GetPlayers()

-- Client: aktuell gestreamte Spieler im Umkreis von 25 Metern
local nearby = exports.frontier_playersync:GetNearbyPlayers(25.0, false)

-- Server oder Client: öffentliche Daten anhand der Server-ID
local player = exports.frontier_playersync:GetPlayerState(serverId)
```

Die Beispielkonfiguration aktiviert OneSync, strikte serverseitige State Bags
und `sv_maxclients 64`. Mehr als 48 Slots setzen einen passenden Tarif im
Cfx.re-Portal voraus.

## MS Stables

Die Resource `MS_Stables` stellt ein grafisches und persistentes Stallsystem
bereit:

- Pferde mit eigenem Namen kaufen und am Stall abholen
- rassenspezifische Fellfarben kaufen und jederzeit wieder auswählen
- Sättel, Decken und Steigbügel pro Pferd kaufen und ausrüsten
- konfigurierbare Ausrüstungsboni und optionale Meta-Ped-Komponenten
- Kutschen kaufen, abholen und wieder einstellen
- serverseitige Prüfung von Besitz, Preis, Kontostand und Entfernung
- automatische Tabellenanlage sowie Löschung des Besitzes mit dem Charakter

Alle Verkäuferpositionen sowie Pferde- und Kutschen-Spawnpunkte befinden sich
in `resources/[frontier]/MS_Stables/config.lua`. Jeder Stall besitzt getrennte
Blöcke für `seller`, `horseSpawn` und `wagonSpawn`. Dort können außerdem
Modelle, Preise, Fellvarianten, Ausrüstung, Limits, Konto und Interaktionstaste
angepasst werden.

Spieler öffnen den nächsten Stall standardmäßig mit `E` oder `/stables`.
Es kann genau ein eigenes Stallobjekt – Pferd oder Kutsche – gleichzeitig
aktiv sein. Fellwechsel und neu angelegte Ausrüstung werden beim nächsten
Abholen des Pferdes sichtbar beziehungsweise wirksam.

## MS Trains

`MS_Trains` stellt an konfigurierbaren Bahnhof-NPCs fahrbare Züge auf den
vorhandenen RedM-Gleisen bereit:

- grafisches Zugmenü mit Zugkomposition und Fahrtrichtung
- Personenzug, Pacific-Union-Zug und Industriezug als Beispielkonfigurationen
- serverseitige Prüfung von Charakter, NPC-Entfernung, Cooldown, Zuglimit und
  Netzwerk-Entity
- ein aktiver Zug pro Spieler und konfigurierbares serverweites Zuglimit
- synchronisierte Mission-Train-Entities über OneSync
- Fahrer-HUD mit Geschwindigkeit und Fahrtrichtung
- `W` zum Beschleunigen, `S` zum Bremsen, `R` zum Richtungswechsel im Stand
  und `Leertaste` als Notbremse
- sichere Zugrückgabe über das Menü oder `/trainreturn`

NPC-Modelle, NPC-Koordinaten, Szenarien, Gleis-Spawnpunkte,
Zugkompositionen, Geschwindigkeiten, Tasten und Limits befinden sich in
`resources/[frontier]/MS_Trains/config.lua`. Ein Spawnpunkt muss direkt auf
einem vorhandenen Gleis liegen; die Resource prüft dies vor dem Erzeugen mit
der RedM-Gleisnative. Standardmäßig wird das Menü mit `E` beim Zugpersonal
oder `/trains` geöffnet.

Die Missionszug-Physik wird auf dem Client des anfordernden Spielers
initialisiert und anschließend über OneSync synchronisiert. Eine zusätzliche
Entity-Lockdown-Resource darf diese autorisierte clientseitige
Entity-Erzeugung daher nicht blockieren.

## MS Telegrams

`MS_Telegrams` ergänzt ein persistentes Nachrichtensystem für Charaktere:

- Jeder Charakter erhält automatisch eine eindeutige persönliche
  Telegrammnummer.
- Telegramme werden anhand dieser Nummer adressiert und dauerhaft in der
  Datenbank gespeichert.
- Das grafische Telegrafenamt bietet Posteingang, Ungelesenstatus,
  Gesendet-Ordner, Leseansicht, Verfassen und eine getrennte Löschoption je
  Ordner.
- Online-Empfänger werden sofort benachrichtigt; beim nächsten Charakterstart
  wird auf noch ungelesene Telegramme hingewiesen.
- Nummer, Empfänger, Nachrichtslimits, Entfernung, Versandkosten und
  Kontostand werden bei jeder Aktion serverseitig geprüft.

Die NPC-Positionen, Ped-Modelle, Szenarien, Versandkosten, Nummernlänge,
Textlimits, Konto und Interaktionstaste befinden sich in
`resources/[frontier]/MS_Telegrams/config.lua`. Standardmäßig wird das nächste
Telegrafenamt mit `E` oder `/telegrams` geöffnet. Die benötigten Tabellen
werden beim Resource-Start automatisch erstellt und sind zusätzlich in
`database/schema.sql` enthalten.

## MS Loading Screen

`MS_LoadingScreen` zeigt beim Verbinden eine filmische Ladeszene, den echten
RedM-Ladefortschritt, wechselnde Hinweise und eine Mute-Funktion. Der Ton wird
über den Button rechts oben oder die Taste `M` ein- und ausgeschaltet.

Die Original-Cutscene und Musik aus Red Dead Redemption 2 werden nicht
mitgeliefert. Eine rechtmäßig verwendbare, browserkompatible Videodatei kann
als
`resources/[frontier]/MS_LoadingScreen/html/media/ring_dang_doo.mp4`
hinterlegt werden. Ohne diese Datei startet automatisch die integrierte
animierte Sturm- und Schiffszene, sodass die Resource trotzdem vollständig
funktioniert.

Titel, Servername, Untertitel, Videopfad, Lautstärke, Start-Mute und Hinweise
werden in `resources/[frontier]/MS_LoadingScreen/html/config.js` konfiguriert.
Die Resource muss vor den Framework-Resources mit `ensure MS_LoadingScreen`
gestartet werden; `server.cfg.example` enthält die passende Reihenfolge.

## MS Weapon Damage

`MS_WeaponDamage` konfiguriert den ausgeteilten Schaden für jede RedM-Waffe
einzeln. Basiswaffen, Story-Varianten und die später hinzugefügten
Red-Dead-Online-Waffen sind in
`resources/[frontier]/MS_WeaponDamage/config.lua` eingetragen.

Der Wert `1.00` verwendet den originalen Waffenschaden, `0.50` halbiert ihn
und `2.00` verdoppelt ihn. Die serverseitig geprüfte Konfiguration wird an alle
Spieler verteilt und beim Waffenwechsel erneut angewendet. Verschiedene
Munitionstypen derselben Waffe verwenden denselben Waffenmultiplikator.

Admins mit dem ACE-Recht `frontier.weapon.damage` können Werte bis zum nächsten
Resource-Neustart ändern:

```text
/weapondamage status
/weapondamage set WEAPON_REVOLVER_CATTLEMAN 0.75
/weapondamage reset WEAPON_REVOLVER_CATTLEMAN
/weapondamage resetall
```

Dauerhafte Änderungen werden direkt in `config.lua` vorgenommen und mit
`restart MS_WeaponDamage` aktiviert. Unter- und Obergrenze, Prüfintervall,
Debug-Ausgabe und Laufzeitänderungen sind dort ebenfalls konfigurierbar.

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

## Administration Control Panel

Die Resource `frontier_adminmenu` öffnet mit `F2`, `/acp` oder dem
Kompatibilitätsalias `/adminmenu` das zentrale Administration Control Panel.
Enthalten sind:

- serverweit synchronisierter Wetterkonfigurator mit Übergangszeit
- Bargeld- und Bankgutschriften mit konfigurierbarem Betragslimit
- persistente Itemvergabe aus dem Core-Itemkatalog
- Goto, Bring, Heilen, Wiederbeleben, Einfrieren und Kick
- Noclip sowie Teleport zu frei eingegebenen Koordinaten
- vollständig integrierter World Builder für NPCs, Storages und Türen
- persistente, lizenzgebundene ACP-Rechte mit getrennten Funktionsbereichen
- Crafting-Rezepteditor mit mehreren Zutaten, Ergebnis, Menge und Herstellzeit
- frei platzierbare Crafting-Punkte mit Rezeptauswahl und optionalem Jobzugriff
- Data Admin zum vollständigen Konfigurieren und direkten Speichern neuer Items
- durchsuchbarer Prop-Katalog mit Übernahme in den Itemcreator
- geschützte Löschfunktion für benutzerdefinierte Items
- Support Admin mit filterbarem Unterpunkt **Logs**
- eingehende Verbindungen und geladene Charakter-/Playerspawns
- ausgeteilter Spielerschaden mit Waffenhash, Schadenswert, Akteur und Ziel
- separate **Getötet von**-Einträge für tödliche Spielertreffer
- serverseitige Validierung und Konsolenprotokollierung aller Aktionen

Das ACE-Recht `frontier.admin.menu` dient als Root-Zugriff und kann im ACP
weitere Administratoren freischalten. Vergebene Rechte werden anhand der
Rockstar-Lizenz in `frontier_admin_permissions` gespeichert und bleiben nach
einem Neustart erhalten. Ein Root-Admin besitzt immer alle Rechte. Wettertypen,
Betragsgrenzen, Standardtaste, Crafting-Limits, Log-Aufbewahrungsdauer und
weitere Einstellungen stehen
in `frontier_adminmenu/config.lua`. Der Itemkatalog und die Stack-Limits befinden
sich in der Tabelle `frontier_items`. Die Einträge aus
`frontier_core/config.lua` werden beim ersten Start als geschützte Systemitems
in die Tabelle übernommen.

Der Menüpunkt **Data Admin** konfiguriert technischen Namen, Anzeigenamen,
Beschreibung, Kategorie, Seltenheit, Stack-Limit, Gewicht, Benutzbarkeit,
Verbrauch, Einzigartigkeit, Handelbarkeit, Prop-Modell, Bildpfad und
Standard-Metadaten. Neue Items stehen ohne Resource-Neustart unmittelbar für
Adminvergabe, Storages und Crafting zur Verfügung. Benutzerdefinierte Items
können gelöscht werden, wenn sie nicht mehr in Inventaren, Storages oder
Crafting-Rezepten referenziert sind. Systemitems bleiben geschützt. Der
Prop-Katalog ist in `frontier_adminmenu/config.lua` erweiterbar; zusätzlich
können gültige eigene RedM-Modellnamen eingegeben werden.

Support-Logs werden in `frontier_support_logs` gespeichert. Die Berechtigung
`support` kann wie alle anderen ACP-Rechte über **Adminrechte** verteilt werden.
Anzahl der angezeigten Einträge, Aufbewahrungsdauer, Mindestschaden,
Batchgröße und Warteschlangenlimit sind konfigurierbar. Lizenzkennungen und
Charakternamen werden als Momentaufnahme gespeichert, damit Einträge auch nach
einem Disconnect nachvollziehbar bleiben.

Spieler benutzen einen nahen Crafting-Punkt standardmäßig mit `E`. Zutaten,
Inventarplatz, Entfernung und Jobzugriff werden bei jeder Herstellung
serverseitig erneut geprüft. Die Tabellen für Rechte, Support-Logs, Rezepte und
Crafting-Punkte werden automatisch erstellt und sind zusätzlich in
`database/schema.sql` enthalten.

## World Builder

Mit `F9` oder `/worldbuilder` öffnet die Resource `frontier_worldbuilder` ein
grafisches Verwaltungsinterface für persistente Weltfunktionen:

- NPCs mit frei wählbarem Ped-Modell, Position, Ausrichtung und Szenario
- globale Storages mit einem von allen berechtigten Spielern geteilten Bestand
- private Storages mit einem automatisch getrennten Bestand pro Charakter
- Kapazitätsgrenzen und optionaler Jobzugriff für Storages
- Erfassung vorhandener Türmodelle direkt über die Blickrichtung
- sperrbare Türen mit optionaler Jobberechtigung
- Erstellen, Anzeigen, Umschalten und Löschen über die grafische Oberfläche

Spieler öffnen nahe Storages und berechtigte Türen mit `E`. Itemtransfers
werden serverseitig validiert und unmittelbar gespeichert. Das benötigte
ACE-Recht lautet `frontier.worldbuilder`; Limits, Tasten, NPC-Vorlagen und
Streamingdistanzen stehen in `frontier_worldbuilder/config.lua`. Die Resource
erstellt ihre Tabellen bei Bedarf selbst; sie sind zusätzlich in
`database/schema.sql` enthalten.

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
