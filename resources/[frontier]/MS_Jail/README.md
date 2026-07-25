# MS_Jail

`MS_Jail` ermöglicht eine persistente Inhaftierung aktiver Charaktere im
Sisika Penitentiary.

## Funktionen

- konfigurierbare Sisika-Zellen und Entlassungskoordinaten
- Haftstrafen von 1 bis standardmäßig 1440 Minuten
- persistente Haftzeit, die auch bei Reconnect weiterläuft
- sichtbare Restzeit, Begründung und inhaftierender Admin
- automatische Entlassung nach Ablauf
- serverseitige Grenzprüfung gegen Fluchtversuche
- ACE-geschützte Adminbefehle
- Exporte und Events für andere Resources

## Befehle

| Befehl | Recht | Beschreibung |
| --- | --- | --- |
| `/jail <Server-ID> <Minuten> [Grund]` | `frontier.admin.jail` | Inhaftiert einen aktiven Charakter in Sisika. |
| `/unjail <Server-ID> [Grund]` | `frontier.admin.jail` | Entlässt einen aktiven Gefangenen vorzeitig. |
| `/jailstatus` | Spieler | Zeigt die eigene verbleibende Haftzeit. |
| `/jailstatus <Server-ID>` | `frontier.admin.jail` | Zeigt den Haftstatus eines anderen Spielers. |

Die Befehle können auch in der Serverkonsole verwendet werden. Bei
`jailstatus` ist dort eine Server-ID erforderlich.

## Konfiguration

Alle Einstellungen befinden sich in `config.lua`. Dort können Zellen,
Entlassungsposition, Gefängnismittelpunkt, erlaubter Radius, Strafzeitgrenzen,
HUD und ACE-Recht angepasst werden.

## Server-Exporte

```lua
local jailed, state = exports.MS_Jail:IsJailed(source), exports.MS_Jail:GetJailState(source)
exports.MS_Jail:JailPlayer(source, 30, 'Gerichtsurteil', adminSource)
exports.MS_Jail:ReleasePlayer(source, 'Begnadigt', adminSource)
```

Zusätzlich werden `ms_jail:server:jailed` und `ms_jail:server:released`
serverseitig ausgelöst.
