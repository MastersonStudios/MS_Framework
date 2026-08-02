# MSCore Framework

Ein schlankes, eigenständiges Roleplay-Framework für RedM.

Aktuelle Framework-Version: `0.0.2`

## Enthalten

- persistente Benutzer und mehrere Charaktere
- grafische Charakterauswahl mit vollständigem Charakter-Creator und Live-Vorschau
- Geldkonten (`cash`, `bank`) mit serverseitiger Validierung
- `MS_Banking` mit Privat-, Firmen- und Adminkonten sowie konfigurierbarer Transaktionssteuer
- `MS_BossMenu` mit Dienstzeiterfassung, Job-Punkten, Neueinstellungen, Entlassungen und Firmenkonto
- Jobs, Gruppen und Metadaten
- server- und clientseitige Player-API
- Callback-System zwischen Client und Server
- Admin- und Spieler-Commands
- Spawn/Respawn-Grundablauf
- SQL-Schema und Beispiel-Resource
- persistenter Ingame-Mapeditor mit Objekt-Streaming
- Admin-Logout zurück zur Charakterauswahl
- Charakterspawn am Bahnhof von Valentine
- grafisches ACP mit Rechte-, Wetter-, Spieler-, Geld- und Itemverwaltung
- Support Admin mit persistenten Verbindungs-, Spawn-, Schadens- und Tötungslogs
- persistentes ACP-Adminlog für administrative Aktionen mit Admin, Ziel und Details
- Admin-Bereich für serverweite Announcements mit Banner- und Chat-Ausgabe
- passiver KI-Ressourcenwächter mit Gesundheitsanalyse und sicherer Quarantäne
- grafischer World Builder für NPCs, Storages und sperrbare Türen
- persistente Crafting-Rezepte und frei platzierbare Crafting-Punkte
- Data Admin mit Datenbank-Itemcreator und durchsuchbarem Prop-Katalog
- serverautoritatives Spieler-Presence-Sync für bis zu 64 Slots
- `MS_mechat` mit räumlichem `/me`-Chat und 3D-Text über dem Charakter
- `MS_pointing` mit frei belegbarer Finger-Zeigegeste auf der Taste `B`
- `MS_Medic` mit Krankheiten, Behandlungen, Bewusstlos-Screen, Medic-Notruf und Wiederbelebung
- `MS_Crime` mit gefesselter Spielersuche, Raubinventar und geschützter Crime-Stadt Van Horn
- `MS_RestrictedAreas` mit Jobgebieten, Komplettsperren und mexikanischen 5:1-Wachen
- `MS_Permadeath` mit dauerhaftem Todesrisiko und filmischer Finalszene
- `MS_WeaponDamage` mit einzeln konfigurierbarem Schaden für sämtliche Waffen
- `MS_Inventory` mit konfigurierbarer Kapazität, Kontextaktionen und Outfit-Drag-and-Drop
- `MS_BasicNeeds` mit konfigurierbarem Hunger und Durst
- `MS_HUD` mit Gesundheit, Hunger, Durst und berechneter Umgebungstemperatur
- `MS_Jail` mit persistenter Inhaftierung im Sisika Penitentiary
- `MS_ClothingShop` mit Charaktervorschau und gemeinsamer Einkaufsliste
- `MS_Stables` mit Pferde-, Ausrüstungs-, Fellfarben- und Kutschenhandel
- `MS_Trains` mit fahrbaren Zügen und konfigurierbaren Bahnhof-NPCs
- `MS_Telegrams` mit persönlichen Telegrammnummern und persistenten Nachrichten
- `MS_LoadingScreen` mit statischem Verbindungsbildschirm, Fortschritt und Hinweisen

## Voraussetzungen

- aktueller RedM/FXServer Artifact
- MariaDB 10.5+ oder MySQL 8
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

### txAdmin-Installation per URL

Für eine neue Installation kann das Framework direkt im txAdmin Recipe
Deployer über folgende URL installiert werden:

```text
https://raw.githubusercontent.com/MastersonStudios/MS_Framework/main/recipe.yaml
```

1. Einen aktuellen RedM-FXServer ohne `+exec server.cfg` starten und den
   txAdmin-Ersteinrichtungsassistenten öffnen.
2. Im Recipe Deployer `Remote URL` auswählen und die oben stehende URL
   einfügen.
3. Servername, Cfx-Lizenzschlüssel, Slotanzahl und MySQL-/MariaDB-Zugangsdaten
   eintragen.
4. Das Recipe ausführen und den Server nach erfolgreichem Abschluss starten.

Das Recipe installiert die offiziellen RedM-Basisresources isoliert unter
`resources/[cfx-default]`, die gepinnte `oxmysql`-Release `2.14.1`, sämtliche
aktiven MSCore-Resources, die
[txAdmin-Serverkonfiguration](server.cfg.txadmin) und das vollständige
Datenbankschema. Größere Downloads besitzen feste Zeitlimits.
Die Platzhalter für Endpoints, Slots, Lizenz, Datenbank und den ersten
Master-Admin werden ausschließlich durch txAdmin ausgefüllt.

Der Deployment-Aufbau wurde mit der
[Rexshack-RedM-Recipe](https://github.com/Rexshack-RedM/txAdminRecipe)
abgeglichen. MSCore übernimmt daraus die frühe Bereitstellung der
`server.cfg`, die Trennung von CFX-, Standalone- und Framework-Resources, den
automatischen Datenbankimport und das Aufräumen des temporären Downloads.
RSG-spezifische Ressourcen, `ox_lib`, `ox_target`, Mapmods und Voice-Skripte
werden nicht installiert, weil MSCore diese Abhängigkeiten nicht verwendet.
Anders als die aus vielen Einzel-Repositories zusammengesetzte Rexshack-
Installation wird MSCore einmalig als zusammenpassender Stand geladen; das
reduziert GitHub-Anfragen und verhindert gemischte Resource-Versionen.

Die alte Resource `MS_GuarmaLoader` wird bei einer txAdmin-Neuinstallation
explizit entfernt. Neue Charaktere verwenden damit ausschließlich den in
MSCore konfigurierten Spawn am Bahnhof von Valentine. Die Serverliste weist
Framework, Version und Repository aus; der txAdmin-Noclip-Partikeleffekt ist
standardmäßig deaktiviert und kann über `txAdminMenuPtfxDisable` in
`recipe.yaml` umgestellt werden.

In der erzeugten `server.cfg` werden SQL-Abfragen ab `500` Millisekunden als
langsam protokolliert. Der Grenzwert stammt aus `mysqlSlowQueryWarning` in
`recipe.yaml` und kann dort vor der Installation oder anschließend direkt in
der `server.cfg` angepasst werden.

Die URL-Installation ist für eine neue MSCore-Datenbank vorgesehen. Für eine
bestehende Frontier-Installation gilt weiterhin der nachfolgend beschriebene
Migrationsweg.

Alle mitgelieferten RedM-Resources enthalten die von aktuellen FXServer-
Artifacts verlangte `rdr3_warning`-Bestätigung. Erscheint beim Aktualisieren
dennoch `Resource MSCore does not contain the RedM pre-release warning`, liegt
auf dem Server noch eine ältere Kopie der Resource. In diesem Fall den
Resource-Ordner vollständig durch die aktuelle Version ersetzen und den
Server neu starten.

### Manuelle Installation

1. `database/schema.sql` in eine leere Datenbank importieren.
2. Die Ordner aus `resources/` in den `resources`-Ordner des Servers kopieren.
3. `server.cfg.example` nach `server.cfg` kopieren und Connection-String sowie
   Lizenzschlüssel anpassen.
4. In der Konsole zuerst `ensure MS_LoadingScreen` und `ensure MSCore`,
   danach
   `ensure MS_Banking`, `ensure MS_BossMenu`, `ensure MS_PlayerSync`, `ensure MS_mechat`, `ensure MS_pointing`,
   `ensure MS_Permadeath`, `ensure MS_Inventory`, `ensure MS_Crime`,
   `ensure MS_RestrictedAreas`, `ensure MS_BasicNeeds`,
   `ensure MS_Medic`, `ensure MS_WeaponDamage`, `ensure MS_HUD`, `ensure MS_Jail`,
   `ensure MS_ClothingShop`, `ensure MS_Stables`, `ensure MS_Trains`,
   `ensure MS_Telegrams`,
   `ensure MS_WorldBuilder`, `ensure MS_ResourceGuard`,
   `ensure MS_AdminMenu`, `ensure MS_MapEditor`,
   `ensure MS_AdminLogout` sowie `ensure MS_Example` ausführen
   (oder den Server neu starten).
5. Zum Testen verbinden und `/characters` verwenden.

Beim ersten Beitritt öffnet sich die Charaktererstellung. In
`MSCore/config.lua` kann optional die automatische Erstellung eines
Platzhalter-Charakters aktiviert werden.

### Charakter-Creator

Über `Neuer Charakter` öffnet sich der Creator automatisch. Neben Vorname,
Nachname, Spitzname, Geburtsdatum, Beschreibung und Geschlecht können Herkunft,
Körperbau, Haare, Bart, Augen, Größe und ein Startoutfit ausgewählt werden. Die
Spielfigur wird bereits in der Charakterauswahl live angezeigt und kann im
Creator gedreht und gezoomt werden. Beim Abschluss validiert der Server
sämtliche Eingaben, begrenzt Profiltexte, prüft gesperrte Namen und schützt die
Erstellung mit einer kurzen Wiederholungssperre.

MSCore speichert Profil und Aussehen versioniert unter `metadata.profile` und
`metadata.appearance`. Das gewählte Startoutfit wird zusätzlich als
itembezogene Ausrüstung unter `metadata.outfit` angelegt und anschließend vom
Bekleidungsinventar verwaltet. Dadurch lassen sich die Startteile später normal
ablegen, wechseln oder ersetzen.

Modelle, Komponenten, Profilgrenzen, gesperrte Namen, Standardwerte,
Vorschaustandort, Kamera und Outfit-Presets werden unter
`Config.CharacterCreator` in `resources/[MSCore]/MSCore/config.lua`
konfiguriert. Komponenten dürfen als RedM-Modellname oder numerischer Hash
eingetragen werden. Die Outfit-Presets referenzieren vorhandene Kleidungsitems
aus `Config.Items`, sodass deren `metadata.componentHash` zentral gepflegt
bleibt. Eine zusätzliche Datenbankmigration ist nicht erforderlich. Vorhandene
Charaktere werden beim nächsten Laden automatisch auf die aktuelle
Metadatenstruktur ergänzt.

Die manuelle Beispielkonfiguration enthält die offiziellen RedM-Systemresources
und feste Beispielwerte. Für txAdmin darf sie nicht anstelle von
`server.cfg.txadmin` verwendet werden, da nur die txAdmin-Datei die benötigten
`{{...}}`-Platzhalter besitzt.

### Aktualisierung einer bestehenden Frontier-Installation

Vor der Umstellung den Server stoppen und die Datenbank sichern. Danach
`database/migrate_frontier_to_mscore.sql` einmalig auf der bestehenden
Datenbank ausführen. Das Skript benennt die bisherigen Tabellen verlustfrei
in den `mscore_*`-Namensraum um und bricht ab, falls alte und neue Tabellen
gleichzeitig vorhanden sind. Bei einer bestehenden Installation darf
`database/schema.sql` nicht vorher erneut importiert werden.

Anschließend die Resource-Namen und ACE-Rechte in der eigenen `server.cfg`
anhand von `server.cfg.example` aktualisieren. Eigene Resources müssen ihre
Exporte auf `exports.MSCore`, Core-Events auf `mscore:*` und die umbenannten
Komponenten auf deren neue `MS_*`-Resource-Namen umstellen.

## Befehlsübersicht

Chatbefehle werden ingame mit `/` eingegeben. In der Serverkonsole entfällt
der Schrägstrich. `<Wert>` kennzeichnet ein Pflichtargument, `[Wert]` ein
optionales Argument.

Stand Framework `0.0.2`: 40 öffentliche Befehle. Interne Keymapping-Befehle
werden hier nicht aufgeführt.

### Spielerbefehle

| Befehl | Kurzbeschreibung |
| --- | --- |
| `/characters` | Öffnet die Charakterauswahl. |
| `/selectchar <Charakter-ID>` | Wählt einen eigenen Charakter anhand seiner Datenbank-ID aus. |
| `/newchar <Vorname> <Nachname> [male\|female]` | Erstellt einen Charakter; ohne Geschlechtsangabe wird `male` verwendet. |
| `/cash` | Zeigt Bargeld und Bankguthaben des aktiven Charakters an. |
| `/bank` | Öffnet das Banksystem beim nächsten erreichbaren Banker. |
| `/daily` | Holt einmal pro UTC-Tag den Beispielbonus von `$10` ab; benötigt `MS_Example`. |
| `/frameworkversion` | Zeigt die installierte Framework-Version und den letzten Update-Status. |
| `/me <Aktion>` | Zeigt eine Roleplay-Aktion im nahen Chat und als 3D-Text über dem Charakter. |
| `/point` | Führt die Finger-Zeigegeste aus; alternativ kann `B` verwendet werden. |
| `/healthstatus` | Öffnet die eigene Gesundheitsakte mit aktiven Krankheiten. |
| `/deathrisk` | Zeigt das persistente permanente Todesrisiko, die Todesanzahl und den Schwellwert. |
| `/medic` | Öffnet mit dem Job `medic` das Behandlungsmenü. |
| `/jailstatus` | Zeigt die eigene verbleibende Haftzeit und den Haftgrund. |
| `/inventory` | Öffnet `MS_Inventory`. |
| `/durchsuchen` | Durchsucht als Crime-Mitglied nach 60 Sekunden die nächste gefesselte Person. |
| `/clothingshop` | Öffnet den nächsten erreichbaren Bekleidungshändler. |
| `/stables` | Öffnet den nächsten erreichbaren Stall. |
| `/trains` | Öffnet das Menü des nächsten erreichbaren Bahnhof-NPCs. |
| `/trainreturn` | Gibt den eigenen aktiven Zug zurück. |
| `/telegrams` | Öffnet das nächste erreichbare Telegrafenamt. |

### Administration

| Befehl | ACE-Recht | Kurzbeschreibung |
| --- | --- | --- |
| `/setjob <Server-ID> <Job> [Grad]` | `mscore.admin` | Setzt Job und Grad eines Spielers; der Grad ist standardmäßig `0`. |
| `/givemoney <Server-ID> <cash\|bank> <Betrag>` | `mscore.admin` | Schreibt einem Spieler einen positiven ganzzahligen Betrag gut. |
| `/acp` | `mscore.admin.menu` | Öffnet oder schließt das Administration Control Panel. |
| `/adminmenu` | `mscore.admin.menu` | Alias für `/acp`. |
| `/worldbuilder` | `mscore.worldbuilder` | Öffnet oder schließt den World Builder. |
| `/logout [Server-ID]` | `mscore.admin.logout` | Meldet den eigenen oder angegebenen Charakter ab und öffnet dessen Charakterauswahl. |
| `/charlogout [Server-ID]` | `mscore.admin.logout` | Alias für `/logout`. |
| `/frameworkversion check` | `mscore.version.check` | Erzwingt unter Beachtung des konfigurierten Mindestintervalls eine neue Versionsabfrage. |
| `/resourceguard status` | `mscore.resourceguard` | Führt eine Prüfung aus und zeigt die Resource-Zusammenfassung im Chat beziehungsweise in der Serverkonsole. |
| `/resourceguard enable\|disable` | `mscore.resourceguard` | Aktiviert oder pausiert die passive Resource-Überwachung. |
| `/resourceguard quarantine <Resource>` | `mscore.resourceguard` | Stoppt eine nicht geschützte Resource und setzt sie unter Quarantäne. |
| `/resourceguard release <Resource>` | `mscore.resourceguard` | Hebt die Quarantäne auf; ein automatischer Start erfolgt bewusst nicht. |
| `/medicdisease <Server-ID> <add\|remove\|clear\|list> [Krankheit] [Schweregrad]` | `mscore.admin` | Verwaltet Krankheiten eines aktiven Charakters. |
| `/permadeath <status\|set\|reset\|testscene> [Server-ID] [Prozent]` | `mscore.admin.permadeath` | Prüft oder setzt das Todesrisiko und startet eine sichere Testszene. |
| `/jail <Server-ID> <Minuten> [Grund]` | `mscore.admin.jail` oder Job `sheriff` | Inhaftiert einen aktiven Charakter persistent in Sisika. |
| `/unjail <Server-ID> [Grund]` | `mscore.admin.jail` oder Job `sheriff` | Entlässt einen Gefangenen vorzeitig. |
| `/jailstatus <Server-ID>` | `mscore.admin.jail` oder Job `sheriff` | Zeigt den Haftstatus eines anderen Spielers. |
| `/weapondamage status` | `mscore.weapon.damage` | Zeigt Waffenanzahl, Laufzeitänderungen und Revision. |
| `/weapondamage set <WEAPON_NAME> <Multiplikator>` | `mscore.weapon.damage` | Setzt den Schaden einer Waffe bis zum nächsten Resource-Neustart. |
| `/weapondamage reset <WEAPON_NAME>` | `mscore.weapon.damage` | Entfernt die Laufzeitänderung einer Waffe. |
| `/weapondamage resetall` | `mscore.weapon.damage` | Entfernt alle Laufzeitänderungen am Waffenschaden. |

`setjob`, `givemoney`, `logout`, `charlogout`,
`frameworkversion`, `medicdisease`, `permadeath`, `jail`, `unjail`, `jailstatus` und
`weapondamage` können auch in der Serverkonsole
verwendet werden. Bei `logout` und `charlogout` ist dort eine
Server-ID erforderlich; bei `permadeath` und `jailstatus` ebenfalls.
Beispielzuweisungen für
alle ACE-Rechte stehen in `server.cfg.example`.

### Medic-Befehlsbeispiele

`/medicdisease` akzeptiert die Krankheitsschlüssel `influenza` (Grippe),
`pneumonia` (Lungenentzündung), `food_poisoning`
(Vergiftung), `wound_infection` (Wundinfektion), `bone_fracture`
(Knochenbruch) und `gunshot_wound` (Schusswunde). Wird beim Hinzufügen kein
Schweregrad angegeben, verwendet das System Stufe `1`.

| Beispiel | Wirkung |
| --- | --- |
| `/setjob 12 medic 0` | Weist Spieler 12 den Medic-Job als Sanitäter zu. Die Grade `1` und `2` entsprechen Arzt und Chefarzt. |
| `/medicdisease 12 list` | Listet alle aktiven Krankheiten des Spielers auf. |
| `/medicdisease 12 add influenza 1` | Fügt Grippe mit Schweregrad 1 hinzu. |
| `/medicdisease 12 add bone_fracture 2` | Fügt einen Knochenbruch mit Schweregrad 2 hinzu. |
| `/medicdisease 12 add gunshot_wound 2` | Fügt eine Schusswunde mit Schweregrad 2 hinzu. |
| `/medicdisease 12 remove influenza` | Entfernt Grippe. |
| `/medicdisease 12 clear` | Entfernt alle Krankheiten des Spielers. |

### Stündliche Jobgehälter

Die folgenden Jobgehälter werden nach jeweils 60 Minuten aktiv erfasster
Dienstzeit serverseitig auf das Bankkonto ausgezahlt. Spieler melden sich am
konfigurierten Dienstpunkt mit `E` im Bereich `Dienst` an oder ab:

| Job | Grad | Rang | Stundenlohn |
| --- | ---: | --- | ---: |
| `medic` | `0` | Sanitäter | `$8` |
| `medic` | `1` | Arzt | `$10` |
| `medic` | `2` | Chefarzt | `$15` |
| `sheriff` | `0` | Deputy | `$10` |
| `sheriff` | `1` | Sheriff | `$12` |

Beim Charakter-Logout oder Serverstopp endet der Dienst automatisch. Die
bereits geleistete Zeit bleibt am Charakter gespeichert und läuft erst nach
der nächsten Dienstanmeldung weiter. Ein Job- oder Rangwechsel setzt den
Auszahlungszeitraum zurück. Intervall, Zielkonto und Löhne befinden sich in
`resources/[MSCore]/MSCore/config.lua`.

### Native-Job

Der Jobschlüssel `native` besitzt zwei Ränge:

| Grad | Rang | Standardgehalt |
| ---: | --- | ---: |
| `0` | Stammesmitglied | `$0` |
| `1` | Häuptling | `$0` |

Admins weisen den Job beispielsweise mit `/setjob 12 native 0` zu. Für einen
Häuptling wird Grad `1` verwendet: `/setjob 12 native 1`. Die Ranggehälter
können in `resources/[MSCore]/MSCore/config.lua` angepasst werden.

### Büchsenmacher-Job

Der Jobschlüssel `gunsmith` besitzt zwei Ränge:

| Grad | Rang | Standardgehalt |
| ---: | --- | ---: |
| `0` | Lehrling | `$0` |
| `1` | Meister | `$0` |

Admins weisen den Job beispielsweise mit `/setjob 12 gunsmith 0` zu. Für
einen Meister wird Grad `1` verwendet: `/setjob 12 gunsmith 1`. Die
Ranggehälter können in `resources/[MSCore]/MSCore/config.lua` angepasst werden.

### Law-Job

Der Jobschlüssel `law` besitzt zwei stündlich bezahlte Ränge:

| Grad | Rang | Stundenlohn |
| ---: | --- | ---: |
| `0` | Countysheriff | `$12` |
| `1` | Marschall | `$20` |

Admins weisen den Job mit `/setjob 12 law 0` beziehungsweise
`/setjob 12 law 1` zu. Nach jeweils 60 Minuten aktiv erfasster Dienstzeit wird
der Ranglohn serverseitig auf das Bankkonto überwiesen. Logout und Serverstopp
beenden den Dienst, ohne die bereits geleistete Zeit zu löschen. Ein Job- oder
Rangwechsel setzt den Auszahlungszeitraum zurück. Intervall, Zielkonto und
Löhne befinden sich in `resources/[MSCore]/MSCore/config.lua`.

### Crime-Job

Der Jobschlüssel `crime` besitzt den Rang `0` **Krimineller**. Der Job erhält
weder Lohnzahlungen noch ein Firmenkonto. Admins weisen ihn beispielsweise mit
`/setjob 12 crime 0` zu.

Crime-Mitglieder können gefesselte Personen durchsuchen und ausrauben. Van Horn
ist als geschützte Crime-Stadt eingerichtet; nur die Jobs `crime` und `medic`
werden dort nicht von den konfigurierten Wachen angegriffen.

### Mapeditor-Befehle

Alle Mapeditor-Befehle sind nur ingame verfügbar und benötigen das ACE-Recht
`mscore.mapeditor`.

| Befehl | Kurzbeschreibung |
| --- | --- |
| `/mapeditor [Modell]` | Startet die Platzierung; ohne Modell wird das erste Modell aus dem Katalog verwendet. |
| `/mapedit [Objekt-ID]` | Bearbeitet das angegebene oder nächste erreichbare Objekt. |
| `/mapdelete [Objekt-ID]` | Löscht das angegebene oder nächste erreichbare Objekt. |
| `/mapobjects` | Zeigt IDs und Entfernung der nächsten Map-Objekte. |
| `/mapcatalog` | Zeigt alle vorkonfigurierten Objektmodelle. |
| `/mapundo` | Macht die letzte eigene Mapeditor-Änderung rückgängig. |

### Standardtasten

RedM stellt `RegisterKeyMapping` nicht bereit. MSCore registriert die
konfigurierten Standardtasten deshalb zentral über `RegisterRawKeymap`.
Tasten werden in der jeweiligen `config.lua` geändert und nach einem
Resource- oder Serverneustart übernommen.

| Taste | Funktion |
| --- | --- |
| `F2` | ACP öffnen oder schließen. |
| `F6` | Medic-Behandlungsmenü öffnen. |
| `F9` | World Builder öffnen oder schließen. |
| `I` | Inventar öffnen oder schließen. |
| `H` | Als Crime-Mitglied die nächste gefesselte Person durchsuchen. |
| `B` | Mit dem Finger nach vorne zeigen. |
| `E` | Händler, Dienst-/Boss-Punkt, Stall, Bahnhof, Telegrafenamt, Crafting-Punkt, Storage oder Tür benutzen. |
| `W` / `S` | Zug beschleunigen oder bremsen. |
| `R` / `Leertaste` | Zug im Stand wenden oder Notbremsung auslösen. |

Die vollständige Mapeditor-Steuerung steht im Abschnitt
[Mapeditor](#mapeditor).

## Versionsabfrage

`MSCore` prüft nach dem Serverstart automatisch die zentrale
`version.json` auf GitHub. Die lokale Version stammt aus dem
Resource-Manifest und ist aktuell auf `0.0.2` gesetzt. Netzwerk- oder
GitHub-Fehler werden nur protokolliert und blockieren den Serverstart nicht.

```text
/frameworkversion
/frameworkversion check
```

Die einfache Abfrage ist für alle Spieler verfügbar. Eine neue GitHub-Abfrage
benötigt das ACE-Recht `mscore.version.check`. URL, Verzögerung,
Mindestintervall und Aktivierung befinden sich in
`resources/[MSCore]/MSCore/config.lua`.

Andere Server-Resources können Version und Prüfstatus abfragen:

```lua
local version = exports.MSCore:GetFrameworkVersion()
local state = exports.MSCore:GetFrameworkVersionState()
exports.MSCore:CheckFrameworkVersion()
```

Nach jeder abgeschlossenen Prüfung wird zusätzlich das Serverevent
`mscore:server:versionChecked` mit dem aktuellen Status ausgelöst.

## Wichtige API

```lua
local player = exports.MSCore:GetPlayer(source)
player:addMoney('cash', 10, 'mission_reward')
player:addItem('water', 1, 'mission_reward')
player:setJob('sheriff', 0)
player:setMetadataValues({
    hunger = 100,
    thirst = 100
})

local player = exports.MSCore:GetPlayerFromCharacterId(characterId)
```

Die Player-Methoden sind an das kanonische Core-Objekt gebunden und können
deshalb sicher aus anderen Server-Resources sowie aus Core-Event-Handlern
aufgerufen werden. Mehrere Metadatenwerte sollten mit `setMetadataValues`
gemeinsam aktualisiert werden; dadurch erfolgen Synchronisierung und
Dirty-Markierung nur einmal.

Weitere Beispiele stehen in `resources/[MSCore]/MS_Example`.

Items werden serverseitig anhand von `MSCore/config.lua` validiert und
im Charakter-Inventar innerhalb der persistenten Metadaten gespeichert.

## MS Inventory

Die Resource `MS_Inventory` ersetzt die reine Metadatenablage durch ein
grafisches Slot- und Gewichtsinventar. Standardmäßig wird es mit `I` oder
`/inventory` geöffnet.

- Die Kapazität wird zentral über `Config.Inventory.Slots` und
  `Config.Inventory.MaxWeight` in
  `resources/[MSCore]/MSCore/config.lua` konfiguriert.
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
`resources/[MSCore]/MS_Inventory/config.lua`. Neue Kleidungsitems lassen
sich damit direkt über **ACP → Data Admin → Itemcreator** anlegen.

## MS Crime

`MS_Crime` stellt den unbezahlten Job `crime`, die Durchsuchung gefesselter
Spieler und die Zugangskontrolle für Van Horn bereit.

- Mit `H` oder `/durchsuchen` wird die nächste gefesselte Person in Reichweite
  ausgewählt. Während der serverseitig gemessenen 60 Sekunden erscheint
  **„Du durchsuchst die Person.“**
- Ziel, Entfernung, Fesselstatus und Job werden beim Start, nach Ablauf der
  Suchzeit und bei jeder Entnahme erneut auf dem Server geprüft.
- Anschließend zeigt ein separates Beuteinventar die Gegenstände des Ziels.
  Nur handelbare Items können in zulässiger Menge geraubt werden; Kapazität und
  Besitz werden serverseitig validiert.
- Van Horn ist standardmäßig um `2981.65, 561.72, 44.85` mit einem Radius von
  `235.0` geschützt. Für andere Jobs als `crime` und `medic` erscheinen lokale,
  bewaffnete Wachen, die ausschließlich den unberechtigten Spieler angreifen.

Suchdauer, Reichweiten, Taste, erlaubte Jobs, Stadtmittelpunkt, Radius,
NPC-Modelle, Waffen und Wachpositionen befinden sich in
`resources/[MSCore]/MS_Crime/config.lua`. Andere Fesselscripts können den
serverseitigen Export `SetRestrained(playerSource, true|false|nil)` oder einen
der dokumentierten State-Bag-Schlüssel verwenden. Weitere Hinweise stehen in
`resources/[MSCore]/MS_Crime/README.md`.

## MS Restricted Areas

`MS_RestrictedAreas` erstellt beliebig viele kreisförmige oder polygonale
Zugangsgebiete. Job und Rang werden von MSCore auf dem Server geprüft.

- Im Modus `jobs` dürfen nur die konfigurierten Jobs und Ränge eintreten.
  Unberechtigte Charaktere werden an einen sicheren Punkt außerhalb des
  Gebiets zurückgesetzt.
- Im Modus `locked` ist das Gebiet vollständig gesperrt. Für jeden
  Eindringling erscheinen standardmäßig fünf mexikanische Banditen, die nur
  diesen Spieler angreifen. Zwei Eindringlinge lösen somit zehn getrennte
  Wachen aus.
- Überlappungen werden über eine Gebietspriorität aufgelöst. Kreisradius,
  Polygonpunkte, Höhenbereich, Ausgang, Texte, NPC-Modell, Waffen, Stärke und
  das Verhältnis sind vollständig konfigurierbar.
- Die Wachen sind lokal und nicht netzwerksynchronisiert. Dadurch greifen sie
  keine berechtigten oder unbeteiligten Spieler auf anderen Clients an.

Die Beispiele in `resources/[MSCore]/MS_RestrictedAreas/config.lua` sind
vorsorglich deaktiviert. Nach dem Eintragen der gewünschten Koordinaten werden
sie über `Enabled = true` aktiviert. Admins besitzen über
`mscore.restrictedareas.bypass` den konfigurierbaren Test-Bypass. Eine
vollständige Anleitung steht in
`resources/[MSCore]/MS_RestrictedAreas/README.md`.

## MS Basic Needs

`MS_BasicNeeds` verwaltet Hunger und Durst serverseitig und speichert beide
Werte charaktergebunden in den vorhandenen Metadaten. Bei kritischen Werten
werden konfigurierbare Warnungen ausgegeben.

- Startwerte, Wertebereich, Tickintervall und Abbau pro Tick sind frei
  konfigurierbar.
- Warnschwelle, Warntexte, Schaden, tödlicher Schaden und Speicherintervall
  können getrennt eingestellt werden.
- Das eigenständige kleine Needs-HUD kann optional aktiviert werden; im
  vollständigen Framework übernimmt `MS_HUD` die Anzeige.
- `water` füllt standardmäßig 25 Durst und `bread` 20 Hunger auf. Weitere
  nutzbare Items können mit eigenen Hunger- und Dursteffekten ergänzt werden.

Alle Einstellungen befinden sich in
`resources/[MSCore]/MS_BasicNeeds/config.lua`. Die Resource wird nach
`MS_Inventory` gestartet. Andere Server-Resources können die Werte über
`GetNeeds`, `SetNeeds` und `AddNeed` lesen oder ändern.

## MS HUD

`MS_HUD` bündelt den aktuellen Spielerstatus in einer grafischen Anzeige:

- Gesundheit wird direkt vom aktuellen Spieler-Ped gelesen.
- Hunger und Durst kommen aus dem serverautoritativen `MS_BasicNeeds`.
- Die Umgebungstemperatur wird aus Region, Tageszeit, ACP-Wetter, Höhe und
  Aufenthalt im Wasser berechnet.
- Gesundheit, Hunger, Durst, Kälte und Hitze besitzen eigene kritische
  Darstellungen.

Position, Skalierung, horizontale oder vertikale Ausrichtung, Beschriftungen,
Aktualisierungsintervalle, Celsius/Fahrenheit, Temperaturzonen und sämtliche
Temperaturkorrekturen befinden sich in
`resources/[MSCore]/MS_HUD/config.lua`. Das HUD wird ohne aktiven Charakter
und optional im Pausenmenü ausgeblendet.

## MS Jail

`MS_Jail` inhaftiert aktive Charaktere persistent im Sisika Penitentiary.
Admins verwenden `/jail <Server-ID> <Minuten> [Grund]` und
`/unjail <Server-ID> [Grund]`; das benötigte ACE-Recht lautet
`mscore.admin.jail`. Alternativ dürfen konfigurierbare Grade des Jobs
`sheriff` diese Befehle verwenden. Standardmäßig sind Deputy und Sheriff
freigeschaltet; inhaftierte Sheriffs verlieren ihre Jobrechte bis zur
Entlassung.

Haftzeit, Begründung und verantwortlicher Admin werden in
`ms_jail_sentences` gespeichert. Online läuft die Restzeit normal, offline mit
dem Faktor `0.5`: Zehn reale Offline-Minuten reduzieren die Haft um fünf
Minuten. Nach Ablauf wird der Charakter automatisch entlassen. Verlässt ein
Gefangener den konfigurierten Sisika-Bereich, bringt ihn die serverseitige
Grenzprüfung zurück in seine Zelle.

Zellen, Entlassungsposition, Gefängnismittelpunkt, Radius, erlaubte Strafzeiten,
HUD, Sheriff-Jobgrade, Offline-Faktor und Rechte befinden sich in
`resources/[MSCore]/MS_Jail/config.lua`. Das reduzierte HUD zeigt
ausschließlich Restzeit und Haftgrund; der Status kann zusätzlich mit
`/jailstatus` abgefragt werden.

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
`resources/[MSCore]/MS_ClothingShop/config.lua`. Standardmäßig wird der
nächste Händler mit `E` oder `/clothingshop` geöffnet.

Die zehn Beispielartikel für männliche und weibliche Charaktere liegen in
`MSCore/config.lua`. Für eigene Artikel sind mindestens diese
Item-Metadaten notwendig:

```json
{"clothingSlot":"coat","componentHash":331167570,"sex":"male"}
```

Erlaubte Geschlechtswerte sind `male`, `female` und `unisex`. Der
Bekleidungsshop zeigt nur passende Produkte, und `MS_Inventory` prüft diese
Angabe erneut beim Ausrüsten.

## Spielersynchronisation

Die Resource `MS_PlayerSync` ergänzt OneSync um einen serverautoritativ
verwalteten Presence- und Charakterdaten-Cache für bis zu 64 Spieler. OneSync
bleibt für Peds, Bewegung und andere Netzwerk-Entities zuständig; die Resource
verteilt nur Änderungen an öffentlichen Framework-Daten und Routing-Buckets.
Geld, Inventar, Geburtsdatum und Metadaten werden nicht an andere Spieler
übertragen.

```lua
-- Client: alle geladenen Charaktere
local players = exports.MS_PlayerSync:GetPlayers()

-- Client: aktuell gestreamte Spieler im Umkreis von 25 Metern
local nearby = exports.MS_PlayerSync:GetNearbyPlayers(25.0, false)

-- Server oder Client: öffentliche Daten anhand der Server-ID
local player = exports.MS_PlayerSync:GetPlayerState(serverId)
```

Die Beispielkonfiguration aktiviert OneSync, strikte serverseitige State Bags
und `sv_maxclients 64`. Mehr als 48 Slots setzen einen passenden Tarif im
Cfx.re-Portal voraus.

## MS Me Chat

Die Resource `MS_mechat` stellt den Roleplay-Befehl `/me <Aktion>` bereit. Die
serverseitig geprüfte Aktion erscheint im normalen Chat und für eine begrenzte
Zeit als 3D-Text über dem Charakter.

- Nur geladene Charaktere im gleichen Routing-Bucket und innerhalb der
  eingestellten Reichweite erhalten die Nachricht.
- Textlänge, Spam-Cooldown, Reichweite und Anzeigedauer werden serverseitig
  erzwungen.
- Mehrere Aktionen werden über dem Charakter gestapelt und zum Ende weich
  ausgeblendet.
- Chat-Ausgabe, 3D-Text, Farbe, Schrift, Zeilenlänge, Sichtprüfung und
  Konsolenprotokollierung sind einzeln konfigurierbar.

Alle Einstellungen befinden sich in
`resources/[MSCore]/MS_mechat/config.lua`. Die Resource benötigt OneSync und
`MSCore`; `server.cfg.example` startet sie deshalb direkt nach
`MS_PlayerSync`.

## MS Pointing

`MS_pointing` führt mit der Standardtaste `B` oder `/point` die native
RedM-Zeigegeste `KIT_EMOTE_ACTION_POINT_1` aus. Die Animation des eigenen
Netzwerk-Peds wird dadurch für andere Spieler synchronisiert.

Vor dem Start prüft die Resource den aktiven Charakter, Tod, Ragdoll, NUI-Fokus,
Fahrzeug, Pferd, ausgerüstete Waffe und Cooldown. Standardmäßig muss der Spieler
zu Fuß, unbewaffnet und außerhalb eines Menüs sein. Command, Taste, Emote-Kit,
Cooldown, geschätzte Gestendauer und sämtliche Sperren befinden sich in
`resources/[MSCore]/MS_pointing/config.lua`. Spieler können die Taste in den
RedM-Tastatureinstellungen neu belegen.

## MS Medic

`MS_Medic` ergänzt persistente Krankheiten, Symptome und ein grafisches
Behandlungsmenü. Jeder Charakter kann mit `/healthstatus` seine Gesundheitsakte
öffnen. Spieler mit dem Job `medic` verwenden `F6` oder `/medic`, um nahe
Patienten zu untersuchen, Wunden zu versorgen, Krankheiten zu behandeln oder
verstorbene Spieler wiederzubeleben.

Bei einem normalen Tod erscheint ein eigener Bewusstlos-Screen mit einem
serverseitigen Countdown von standardmäßig zehn Minuten. Der Notruf-Button
alarmiert alle diensthabenden Medics, setzt den Countdown auf zwanzig Minuten
und legt ihnen einen Einsatzmarker mit 15 Metern Radius auf die Karte. Der
Zustand bleibt beim Ausloggen erhalten. Nach Ablauf des Countdowns wacht der
Charakter in der vom Todesort aus nächstgelegenen konfigurierten Stadt auf.
Inhaftierte Charaktere bleiben dabei in Sisika; permanente Charaktertode
werden nicht wiederbelebt.

Die vorkonfigurierten Krankheiten und Verletzungen Grippe, Lungenentzündung,
Vergiftung, Wundinfektion, Knochenbruch und Schusswunde besitzen jeweils eigene
Wahrscheinlichkeiten, Schweregrade, Symptome und Behandlungen. Ein Wert von
`0.01` entspricht einem Prozent pro konfiguriertem Prüfintervall. Krankheiten
bleiben in `ms_medic_diseases` charaktergebunden gespeichert.

Eine Vergiftung löst in unregelmäßigen Abständen Erbrechen aus und senkt den
BasicNeeds-Durstwert pro Anfall um einen Prozentpunkt. Schusswaffentreffer
erzeugen automatisch eine persistente Schusswunde; weitere Treffer können den
Schweregrad erhöhen. Unregelmäßige Blutungen verursachen Gesundheitsschaden
und eine Schmerzreaktion. Beim Anklicken eines nahen Patienten öffnet sich für
Medics ein Kontextmenü mit `Patient untersuchen`. Die festgestellten Symptome
erscheinen in einem separaten Untersuchungsfenster, bevor die
Behandlungsoptionen geöffnet werden.

Behandlungen prüfen Medic-Job und -Grad, Routing-Bucket, Entfernung,
Patientenzustand, benötigte Items, Behandlungsdauer und Heilungschance
serverseitig. Enthalten sind die zusätzlichen Items `medicine`,
`herbal_tonic` und `revive_kit`; der bestehende `bandage` wird ebenfalls
verwendet. Der Job besitzt die Grade Sanitäter, Arzt und Chefarzt. Ein Admin
kann ihn beispielsweise mit `/setjob 12 medic 0` vergeben.

Sämtliche Krankheiten, Wahrscheinlichkeiten, Intervalle, Mindestgesundheit,
Medic-Jobs, Reichweiten, Items und Behandlungswerte befinden sich in
`resources/[MSCore]/MS_Medic/config.lua`. Der Test- und Supportbefehl
`/medicdisease` benötigt `mscore.admin`. Timer, Notrufradius,
Aufwachgesundheit, Kartenmarker und Stadtpositionen werden im Abschnitt
`MSMedicConfig.Unconscious` derselben Datei konfiguriert.

## MS Permadeath

`MS_Permadeath` speichert für jeden Charakter ein dauerhaftes Todesrisiko.
Jeder vom Server bestätigte Tod erhöht es zufällig um `1–3` Prozentpunkte.
Der Standardschwellwert beträgt `60 %`; weil standardmäßig die echte
Überschreitung zählt, löst der permanente Tod ab `61 %` aus. Bereich,
Schwellwert, Cooldowns und Befehle stehen in
`resources/[MSCore]/MS_Permadeath/config.lua`.

Optionale Death-Events und die eigene RedM-Clientprüfung werden entprellt und am Server
gegen den tatsächlichen Ped-Gesundheitszustand validiert. Sobald der Schwellwert
überschritten wurde, setzt die Resource `mscore_characters.is_deleted = 1`.
Der Charakter verschwindet damit aus der normalen Auswahl, sein Datensatz wird
aber nicht hart gelöscht. Ein Disconnect oder Resource-Neustart kann den
bereits ausgelösten Charaktertod nicht aufheben.

Die Finalsequenz versucht auf Wunsch ein in `Finale.NativeCutscene.Name`
eingetragenes natives Story-Asset. Weil solche Assets vom RDR2-Build und
Storyzustand abhängen, läuft bei leerem oder nicht ladbarem Namen automatisch
eine integrierte, von Arthur Morgans Sonnenaufgangs-Finale inspirierte
Kamerasequenz. `/permadeath testscene [Server-ID]` testet sie ohne
Datenänderung.

`MS_Medic` und das ACP sperren Heilung sowie Wiederbelebung, sobald der
permanente Tod ausgelöst ist. Die übrigen Admin-Unterbefehle sind
`/permadeath status [Server-ID]`, `/permadeath set <Server-ID> <0-100>` und
`/permadeath reset <Server-ID>`. Sie benötigen
`mscore.admin.permadeath` oder das übergeordnete `mscore.admin`.

Die Tabelle `ms_permadeath_states` wird beim Resource-Start automatisch
angelegt und ist auch in `database/schema.sql` enthalten. `MS_Permadeath` muss
vor `MS_Medic` gestartet werden; die passende Reihenfolge steht in
`server.cfg.example`. Die Todeserkennung benötigt keine GTA-spezifische
`baseevents`-Resource.

## MS Boss Menu

Aktuelle Resource-Version: `1.1.0`

`MS_BossMenu` stellt für `law`, `sheriff` und `medic` konfigurierbare
Dienst- und Leitungspunkte bereit. Alle konfigurierten Jobränge können sich im
Bereich `Dienst` an- und abmelden. Die aktive Dienstzeit wird serverseitig
erfasst und löst erst nach dem vollständigen Gehaltsintervall eine Auszahlung
aus. Leitungsrechte liegen standardmäßig bei Marschall, Sheriff und Chefarzt;
nur diese Ränge sehen zusätzlich `Einstellen`, `Entlassen` und `Firmenkonto`.

Beim Einstellen werden standardmäßig nur arbeitslose Spieler innerhalb von
fünf Metern angeboten und mit Jobgrad `0` übernommen. Die Mitarbeiterliste
enthält auch Offline-Charaktere. Entlassungen wirken deshalb ohne erneute
Anmeldung; Selbstentlassungen und Eingriffe in gleich- oder höherrangige
Mitarbeiter sind standardmäßig gesperrt.

Das Firmenkonto verwendet direkt `MS_Banking`. Saldo, Sperren, sofortige
Speicherung, Transaktionshistorie und die konfigurierte Steuer bleiben damit
identisch zur Bankfiliale. Dienstgrade, Leitungsgrade, Einstiegsgrade,
beliebig viele Dienstpositionen, Reichweiten, Marker und Verwaltungsregeln befinden sich in
`resources/[MSCore]/MS_BossMenu/config.lua`.

`MS_BossMenu` wird nach `MS_Banking` gestartet. Die Reihenfolge ist bereits in
beiden Serverkonfigurationen und im txAdmin-Recipe berücksichtigt.

## MS Banking

Aktuelle Resource-Version: `1.3.0`

`MS_Banking` erstellt für jeden Charakter beim ersten Bankbesuch automatisch
ein persönliches Konto mit eindeutiger Kontonummer. Der Saldo verwendet direkt
das MSCore-Bankguthaben, sodass Jobgehälter und Admin-Gutschriften ohne
zusätzliche Umbuchung an jeder Bankfiliale verfügbar sind.

| Kontotyp | Besitzer | Funktionen |
| --- | --- | --- |
| Privatkonto | einzelner Charakter | Bargeld einzahlen und abheben, Überweisungen senden, Buchungen einsehen |
| Firmenkonto | alle Mitglieder eines Jobs | gemeinsamer Saldo, rangabhängige Ein- und Auszahlungen, eigener Kontoauszug |
| Adminkonto | Serveradministration | automatische Steuereinnahmen und schreibgeschützte Steuerhistorie |

Bei jedem konfigurierten Banker können Spieler Bargeld einzahlen, Guthaben
abheben, Geld an andere Kontonummern überweisen und ihre letzten Buchungen
einsehen. Überweisungen erreichen auch Offline-Charaktere. Beträge, Guthaben,
Konten, aktive Charaktere und die Entfernung zum Banker werden ausschließlich
serverseitig geprüft; erfolgreiche Buchungen werden sofort gespeichert.

Die Jobs `sheriff`, `medic`, `native`, `gunsmith` und `law` besitzen außerdem
je ein gemeinsames Firmenkonto. Alle Jobmitglieder können Bargeld einzahlen;
Auszahlungen sind standardmäßig auf die konfigurierten Leitungsgrade begrenzt.
Das Firmenkonto und sein separater Buchungsverlauf sind an jeder Filiale
verfügbar. Arbeitslose und der Job `crime` erhalten kein Firmenkonto.

| Job | Firmenkonto | Einzahlung ab Grad | Auszahlung ab Grad |
| --- | --- | ---: | ---: |
| `sheriff` | Sheriff Office | `0` | `1` |
| `medic` | Medic | `0` | `2` |
| `native` | Stammeskonto | `0` | `1` |
| `gunsmith` | Büchsenmacher | `0` | `1` |
| `law` | Law | `0` | `1` |

Neue Jobs erhalten über `CompanyAccountDefaults` automatisch ein Firmenkonto.
`unemployed` und `crime` sind standardmäßig ausgeschlossen. Für einen Job
können Label und Mindestränge jederzeit in `CompanyAccounts` überschrieben
werden.

Private und geschäftliche Ein- und Auszahlungen besitzen standardmäßig eine
konfigurierbare Steuer von `1 %`. Sie wird vom Bruttobetrag abgezogen und auf
dem persistenten Administrationskonto gesammelt. Berechtigte Admins sehen
Saldo, Steuersatz und Steuerhistorie in einem schreibgeschützten Bank-Tab.
Überweisungen zwischen persönlichen Konten bleiben standardmäßig steuerfrei.

Da MSCore Geld in ganzen Dollarbeträgen speichert, wird die Steuer
standardmäßig mit `ceil` auf den nächsten vollen Dollar aufgerundet:

| Vorgang | Bruttobetrag | Steuer | Nettobetrag |
| --- | ---: | ---: | ---: |
| Ein- oder Auszahlung | `$100` | `$1` | `$99` |
| Ein- oder Auszahlung | `$250` | `$3` | `$247` |
| Persönliche Überweisung | `$100` | `$0` | `$100` |

Ein Vorgang wird abgelehnt, wenn die konfigurierte Mindeststeuer den gesamten
Betrag aufbrauchen würde. Der Standardbetrag von `$1` kann deshalb nicht ein-
oder ausgezahlt werden.

NPC-Modelle, Positionen, Interaktionstaste, Kontonummer-Präfix,
Transaktionslimit und Verlaufslänge befinden sich in
`resources/[MSCore]/MS_Banking/config.lua`. Die Oberfläche wird mit `E` oder
beim nächsten Banker mit `/bank` geöffnet. Alle Filialen greifen auf dasselbe
Charakterkonto zu.

Wichtige Konfigurationsbereiche:

| Einstellung | Zweck |
| --- | --- |
| `Bankers` | NPC-Modelle, Szenarien, Filialnamen und Koordinaten |
| `CompanyAccounts` | feste Firmenkonten und Mindestränge pro Job |
| `CompanyAccountDefaults` | automatische Konten für später ergänzte Jobs |
| `AdminAccount` | Kontoschlüssel, Label, ACE-Recht und erlaubte Admin-Gruppen |
| `TransactionTax` | Aktivierung, Prozentsatz, Mindeststeuer, Rundung und steuerpflichtige Vorgänge |
| `MaxTransactionAmount` | maximaler Betrag eines einzelnen Bankvorgangs |

Die Tabellen `ms_bank_accounts`, `ms_bank_transactions`,
`ms_bank_company_accounts`, `ms_bank_company_transactions`,
`ms_bank_admin_accounts` und `ms_bank_admin_transactions` werden beim Start
automatisch angelegt. Für neue Installationen sind sie außerdem in
`database/schema.sql` enthalten. Das Adminkonto benötigt standardmäßig das
ACE-Recht `mscore.admin` oder eine in `AdminAccount.allowedGroups`
freigeschaltete Gruppe.

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
in `resources/[MSCore]/MS_Stables/config.lua`. Jeder Stall besitzt getrennte
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
`resources/[MSCore]/MS_Trains/config.lua`. Ein Spawnpunkt muss direkt auf
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
`resources/[MSCore]/MS_Telegrams/config.lua`. Standardmäßig wird das nächste
Telegrafenamt mit `E` oder `/telegrams` geöffnet. Die benötigten Tabellen
werden beim Resource-Start automatisch erstellt und sind zusätzlich in
`database/schema.sql` enthalten.

## MS Loading Screen

`MS_LoadingScreen` zeigt beim Verbinden ausschließlich einen ruhigen statischen
MSCore-Bildschirm mit echtem RedM-Ladefortschritt und wechselnden Hinweisen.
Video, Musik, Mute-Funktion sowie die frühere Sturm- und Schiffbruchszene wurden
vollständig entfernt. Titel, Servername, Untertitel und Hinweise werden in
`resources/[MSCore]/MS_LoadingScreen/html/config.js` konfiguriert.
Die Resource muss vor den Framework-Resources mit `ensure MS_LoadingScreen`
gestartet werden. Direkt danach folgt `ensure MSCore`; die
`server.cfg.example` enthält die passende Reihenfolge.

## MS Weapon Damage

`MS_WeaponDamage` konfiguriert den ausgeteilten Schaden für jede RedM-Waffe
einzeln. Basiswaffen, Story-Varianten und die später hinzugefügten
Red-Dead-Online-Waffen sind in
`resources/[MSCore]/MS_WeaponDamage/config.lua` eingetragen.

Der Wert `1.00` verwendet den originalen Waffenschaden, `0.50` halbiert ihn
und `2.00` verdoppelt ihn. Die serverseitig geprüfte Konfiguration wird an alle
Spieler verteilt und beim Waffenwechsel erneut angewendet. Verschiedene
Munitionstypen derselben Waffe verwenden denselben Waffenmultiplikator.

Admins mit dem ACE-Recht `mscore.weapon.damage` können Werte bis zum nächsten
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

Administratoren mit dem ACE-Recht `mscore.mapeditor` können persistente
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
in `MS_MapEditor/config.lua`.

## Admin-Logout

Die Resource `MS_AdminLogout` speichert und entlädt einen aktiven
Charakter, bevor sie den Spieler zur Charakterauswahl zurückbringt.

```text
/logout             eigenen Charakter als Admin abmelden
/logout [Server-ID] einen Spieler abmelden
/charlogout [ID]    Alias
```

Benötigt wird das ACE-Recht `mscore.admin.logout`. Ob Admins andere Spieler
abmelden dürfen, kann in `MS_AdminLogout/config.lua` eingestellt werden.

## Administration Control Panel

Die Resource `MS_AdminMenu` öffnet mit `F2`, `/acp` oder dem
Kompatibilitätsalias `/adminmenu` das zentrale Administration Control Panel.
Enthalten sind:

- serverweit synchronisierter Wetterkonfigurator mit Übergangszeit
- Admin-Unterpunkt **Announcement** für serverweite Banner- und Chatnachrichten
- Admin-Unterpunkt **KI Ressourcenwächter** für Status, Diagnose und Quarantäne
- Bargeld- und Bankgutschriften mit konfigurierbarem Betragslimit
- persistente Itemvergabe aus dem Core-Itemkatalog
- Goto, Bring, Heilen, Wiederbeleben, Einfrieren und Kick
- serverweit synchronisierter Ghost Mode für unsichtbares Herumlaufen
- Noclip sowie Teleport zu frei eingegebenen Koordinaten
- vollständig integrierter World Builder für NPCs, Storages und Türen
- persistente, lizenzgebundene ACP-Rechte mit getrennten Funktionsbereichen
- Crafting-Rezepteditor mit mehreren Zutaten, Ergebnis, Menge und Herstellzeit
- frei platzierbare Crafting-Punkte mit Rezeptauswahl und optionalem Jobzugriff
- Data Admin zum vollständigen Konfigurieren und direkten Speichern neuer Items
- durchsuchbarer Prop-Katalog mit Übernahme in den Itemcreator
- geschützte Löschfunktion für benutzerdefinierte Items
- Support Admin mit getrennten, filterbaren Unterpunkten **Support-Logs** und
  **Admin-Logs**
- eingehende Verbindungen und geladene Charakter-/Playerspawns
- ausgeteilter Spielerschaden mit Waffenhash, Schadenswert, Akteur und Ziel
- separate **Getötet von**-Einträge für tödliche Spielertreffer
- persistentes Auditlog aller über das ACP und den World Builder ausgeführten
  Adminaktionen

Das ACE-Recht `mscore.admin.menu` dient als Root-Zugriff und kann im ACP
weitere Administratoren freischalten. Vergebene Rechte werden anhand der
Rockstar-Lizenz in `mscore_admin_permissions` gespeichert und bleiben nach
einem Neustart erhalten. Ein Root-Admin besitzt immer alle Rechte. Wettertypen,
Betragsgrenzen, Standardtaste, Crafting-Limits, Log-Aufbewahrungsdauer und
weitere Einstellungen stehen
in `MS_AdminMenu/config.lua`. Der Itemkatalog und die Stack-Limits befinden
sich in der Tabelle `mscore_items`. Die Einträge aus
`MSCore/config.lua` werden beim ersten Start als geschützte Systemitems
in die Tabelle übernommen.

Der Ghost Mode benötigt die ACP-Berechtigung `players`. Er macht den
Administrator für alle verbundenen Spieler unsichtbar, lässt die normale
Laufbewegung aktiv und wird bei Rechteentzug, Charakter-Logout, Disconnect
oder Resource-Stopp automatisch beendet. Das Aktualisierungsintervall ist über
`AdminMenuConfig.GhostRefreshIntervalMs` konfigurierbar.

Der Menüpunkt **Admin** enthält den Unterpunkt **Announcement**. Nachrichten
werden nach serverseitiger Berechtigungs- und Längenprüfung an alle verbundenen
Spieler gesendet, als Banner angezeigt, zusätzlich im Chat ausgegeben und in
der Serverkonsole protokolliert. Die Berechtigung `announcements` sowie
Maximallänge, Anzeigedauer und Sendepause sind konfigurierbar.

Der Menüpunkt **Data Admin** konfiguriert technischen Namen, Anzeigenamen,
Beschreibung, Kategorie, Seltenheit, Stack-Limit, Gewicht, Benutzbarkeit,
Verbrauch, Einzigartigkeit, Handelbarkeit, Prop-Modell, Bildpfad und
Standard-Metadaten. Neue Items stehen ohne Resource-Neustart unmittelbar für
Adminvergabe, Storages und Crafting zur Verfügung. Benutzerdefinierte Items
können gelöscht werden, wenn sie nicht mehr in Inventaren, Storages oder
Crafting-Rezepten referenziert sind. Systemitems bleiben geschützt. Der
Prop-Katalog ist in `MS_AdminMenu/config.lua` erweiterbar; zusätzlich
können gültige eigene RedM-Modellnamen eingegeben werden.

Support-Logs werden in `mscore_support_logs` gespeichert. Die Berechtigung
`support` kann wie alle anderen ACP-Rechte über **Adminrechte** verteilt werden.
Anzahl der angezeigten Einträge, Aufbewahrungsdauer, Mindestschaden,
Batchgröße und Warteschlangenlimit sind konfigurierbar. Lizenzkennungen und
Charakternamen werden als Momentaufnahme gespeichert, damit Einträge auch nach
einem Disconnect nachvollziehbar bleiben.

Adminaktionen werden als fortlaufende, im ACP nicht bearbeitbare Einträge in
`mscore_admin_logs` gespeichert. Das Log enthält Kategorie, Aktion,
ausführende Resource, Administrator samt Rockstar-Lizenz und Charakter-ID,
optionales Ziel sowie strukturierte Aktionsdetails. Erfasst werden
Spielerverwaltung, Wirtschaft, Announcements, Wetter, Resource-Wächter,
World Builder, Crafting- und Datenverwaltung sowie Rechteänderungen. Die
Ansicht benötigt die getrennt verteilbare Berechtigung `adminlogs`.
`AdminMenuConfig.AdminLogLimit` und
`AdminMenuConfig.AdminLogRetentionDays` steuern Anzeige und automatische
Aufbewahrung.

Spieler benutzen einen nahen Crafting-Punkt standardmäßig mit `E`. Zutaten,
Inventarplatz, Entfernung und Jobzugriff werden bei jeder Herstellung
serverseitig erneut geprüft. Die Tabellen für Rechte, Support-Logs, Admin-Logs,
Rezepte und Crafting-Punkte werden automatisch erstellt und sind zusätzlich in
`database/schema.sql` enthalten.

## KI-Ressourcenwächter

Die Resource `MS_ResourceGuard` prüft passiv alle vom Server erkannten
Resources sowie die in `MS_ResourceGuard/config.lua` erwarteten
Framework-Resources. Die lokale Zustandsanalyse arbeitet ohne externen
KI-Dienst: Sie bewertet Startstatus, kritische Abhängigkeiten, festhängende
Start-/Stop-Zustände und ungewöhnlich viele Zustandswechsel mit einem
Gesundheitswert von 0 bis 100.

Eine automatische Abschaltung erfolgt nur nach der konfigurierten Startschutzzeit
und mehreren bestätigten Prüfungen. Geschützte Core-Resources werden immer nur
gemeldet und niemals durch den Wächter oder das ACP gestoppt. Auffällige
nicht geschützte Resources können automatisch oder im ACP unter
**Admin → KI Ressourcenwächter** gestoppt und in Quarantäne gehalten werden.
Das Aufheben einer Quarantäne startet die Resource aus Sicherheitsgründen nicht
automatisch.

Prüfintervall, erwartete, kritische und geschützte Resources, Flapping-Grenze,
Bestätigungsanzahl, Timeout, Sperr- und Freigabelisten sowie alle
Auto-Stop-Regeln sind in `MS_ResourceGuard/config.lua` konfigurierbar. Für das
ACP wird die Berechtigung `resources`, für die Konsolen- und Chatbefehle das
ACE-Recht `mscore.resourceguard` benötigt.

## World Builder

Mit `F9` oder `/worldbuilder` öffnet die Resource `MS_WorldBuilder` ein
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
ACE-Recht lautet `mscore.worldbuilder`; Limits, Tasten, NPC-Vorlagen und
Streamingdistanzen stehen in `MS_WorldBuilder/config.lua`. Die Resource
erstellt ihre Tabellen bei Bedarf selbst; sie sind zusätzlich in
`database/schema.sql` enthalten.

## Charakterspawn

Neue Charaktere spawnen am Bahnhof von Valentine bei
`vector4(-169.47, 629.38, 114.03, 236.72)`. Das frühere
`MS_GuarmaOnboarding` wurde vollständig entfernt. Charaktere mit einer
gespeicherten Position innerhalb der alten Guarma-Grenzen werden beim nächsten
Laden einmalig zum Bahnhof versetzt; dabei werden auch die veralteten
Onboarding-Metadaten entfernt. Die Migration kann über
`Config.LegacySpawnMigration.Enabled` in `MSCore/config.lua` deaktiviert werden.

Die Erstellung läuft in drei Schritten: Charakterdaten und Aussehen eingeben,
die Zusammenfassung bestätigen und anschließend kurz den Ladebildschirm
„Charakter wird erstellt“ anzeigen. Erst nachdem Modell, Position und Kollision
vorbereitet sind, wird die Charakteroberfläche geschlossen und der Spieler am
Bahnhof eingeblendet. Die Mindestdauer dieser Ladephase wird über
`Config.CharacterCreator.SpawnLoadingMs` konfiguriert.

## Sicherheit

Geld, Jobs und Charakterdaten werden ausschließlich serverseitig geändert.
Client-Events nehmen keine frei gewählten Geldbeträge entgegen. Für Produktion
sollten ACE-Rechte, Backups und zusätzliche Gameplay-spezifische Prüfungen
eingerichtet werden.
