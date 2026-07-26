# MS_RestrictedAreas

`MS_RestrictedAreas` verwaltet beliebig viele kreisförmige oder polygonale
Gebiete. MSCore entscheidet serverseitig anhand von Job, Rang und ACE-Bypass,
ob ein Spieler das aktuelle Gebiet betreten darf.

## Gebietsmodi

### `jobs`

Nur Jobs aus `AllowedJobs` erhalten Zutritt. Unberechtigte Spieler werden mit
einer Nachricht an den nächsten sicheren Punkt außerhalb des Gebiets
zurückgesetzt.

```lua
{
    Id = 'medic_station',
    Enabled = true,
    Label = 'Ärztebereich',
    Mode = 'jobs',
    Shape = 'circle',
    Center = vector3(-282.0, 809.0, 119.0),
    Radius = 20.0,
    AllowedJobs = {
        medic = true,
        sheriff = 1
    }
}
```

`true` erlaubt jeden Rang. Eine Zahl legt den Mindestrang fest. Alternativ
können `MinGrade` und `MaxGrade` in einer Tabelle angegeben werden.

### `locked`

Ein vollständig gesperrtes Gebiet erlaubt keinen Job. Pro Eindringling werden
standardmäßig fünf lokale mexikanische Banditen erzeugt und ausschließlich
gegen diesen Spieler eingesetzt. Bei zwei Eindringlingen entstehen damit
insgesamt zehn getrennte Wachen – weiterhin im Verhältnis fünf zu eins.

```lua
{
    Id = 'locked_mine',
    Enabled = true,
    Label = 'Gesperrte Mine',
    Mode = 'locked',
    Shape = 'polygon',
    MinZ = 10.0,
    MaxZ = 80.0,
    Points = {
        { x = -100.0, y = 100.0 },
        { x = -50.0, y = 100.0 },
        { x = -50.0, y = 150.0 },
        { x = -100.0, y = 150.0 }
    },
    Guards = {
        RatioPerIntruder = 5
    }
}
```

Die NPCs sind absichtlich nicht netzwerksynchronisiert. Jeder Eindringling
sieht nur seine eigenen fünf Angreifer; dadurch wechseln die Wachen nicht auf
berechtigte oder unbeteiligte Spieler.

## Konfiguration

Alle Einstellungen befinden sich in `config.lua`:

- Kreis- und Polygonkoordinaten, Höhenbereiche und Priorität
- erlaubte Jobs und Ranggrenzen
- eigene Ausgangskoordinate über `Exit`
- Warntexte
- Verhältnis, maximale Wächterzahl und Respawnzeit
- mexikanische NPC-Modelle, Waffen, Gesundheit, Rüstung und Genauigkeit

Überlappende Gebiete werden anhand von `Priority` aufgelöst. Die mitgelieferten
Beispiele sind deaktiviert und müssen nach dem Anpassen der Koordinaten mit
`Enabled = true` aktiviert werden.

Das ACE-Recht `mscore.restrictedareas.bypass` umgeht die Sperren für
Administration und Tests. Wird `BypassAce` auf einen leeren String gesetzt,
existiert kein ACE-Bypass.

## Exporte

```lua
local area = exports.MS_RestrictedAreas:GetPlayerArea(playerSource)
local allowed = exports.MS_RestrictedAreas:IsPlayerAreaAuthorized(playerSource)
exports.MS_RestrictedAreas:RefreshPlayerArea(playerSource)
```

Clientseitig stehen `GetCurrentArea` und `IsCurrentAreaAuthorized` zur Verfügung.
