# MS_BasicNeeds

`MS_BasicNeeds` ergänzt das MSCore Framework um charaktergebundenen Hunger
und Durst. Beide Werte werden in den vorhandenen Charaktermetadaten gespeichert,
serverseitig reduziert und an `MS_HUD` übergeben.

## Funktionen

- frei konfigurierbare Start-, Minimal- und Maximalwerte
- getrennt konfigurierbarer Hunger- und Durstabbau
- konfigurierbares Tick- und Speicherintervall
- kritische Warnungen und optionaler, wahlweise nicht tödlicher Gesundheitsschaden
- optionales eigenständiges Needs-HUD mit Positionierung und Skalierung
- Essen und Getränke über die Itembenutzung von `MS_Inventory`
- serverseitige Exporte für andere Resources

## Konfiguration

Alle Einstellungen stehen in `config.lua`. Die Standarditems sind:

| Item | Effekt |
| --- | --- |
| `water` | +25 Durst |
| `bread` | +20 Hunger |

Weitere Items können unter `MSBasicNeedsConfig.Consumables` ergänzt werden.
Das Item muss zusätzlich im Core-Itemkatalog als `usable = true` und für einen
einmaligen Verbrauch als `consumable = true` konfiguriert sein.

Im vollständigen Framework ist `MSBasicNeedsConfig.Hud.Enabled` deaktiviert,
weil `MS_HUD` die zentrale Anzeige übernimmt. Für einen eigenständigen Betrieb
ohne `MS_HUD` kann das kleine Needs-HUD wieder aktiviert werden.

## Server-Exporte

```lua
local needs = exports.MS_BasicNeeds:GetNeeds(source)

exports.MS_BasicNeeds:SetNeeds(source, 100, 100, 'admin_reset')
exports.MS_BasicNeeds:AddNeed(source, 'hunger', 15, 'meal_reward')
exports.MS_BasicNeeds:AddNeed(source, 'thirst', -10, 'desert_effect')
```

Das serverseitige Event `ms_basicneeds:server:needsChanged` erhält
`playerSource`, den aktuellen Status und den Änderungsgrund. Clientseitig wird
`MS_BasicNeeds:client:needsChanged` mit dem aktuellen Status ausgelöst.
