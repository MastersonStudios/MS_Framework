# MS_HUD

`MS_HUD` ist die zentrale Statusanzeige des MSCore Frameworks. Es zeigt die
aktuelle Gesundheit, Hunger, Durst und die berechnete Umgebungstemperatur.

## Funktionen

- Gesundheit direkt vom aktuellen Spieler-Ped
- Hunger und Durst aus der serverautoritativen Resource `MS_BasicNeeds`
- Temperatur anhand von Region, Uhrzeit, Wetter, Höhe und Wasser
- Celsius oder Fahrenheit
- kritische Farben für Gesundheit, Hunger, Durst, Kälte und Hitze
- horizontale oder vertikale Darstellung
- frei konfigurierbare Bildschirmposition, Abstände und Skalierung
- automatisches Ausblenden ohne aktiven Charakter und im Pausenmenü

## Konfiguration

Alle Einstellungen stehen in `config.lua`. Temperaturzonen können über
Mittelpunkt, Radius und Basistemperatur ergänzt oder verändert werden. Die
Wetterkorrekturen verwenden die Wetter-IDs des ACP:

`sunny`, `overcast`, `fog`, `thunderstorm` und `snow`.

Die Temperatur ist eine konfigurierbare Umgebungssimulation und keine
persistente Körpertemperatur.

## Client-Exporte

```lua
local status = exports.MS_HUD:GetHudStatus()
exports.MS_HUD:SetHudVisible(false)
local visible = exports.MS_HUD:IsHudVisible()
```

Bei jeder Aktualisierung wird außerdem das lokale Event
`MS_HUD:client:statusChanged` mit dem vollständigen HUD-Status ausgelöst.
