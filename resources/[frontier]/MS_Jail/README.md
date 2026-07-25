# MS_Jail

`MS_Jail` ermöglicht eine persistente Inhaftierung aktiver Charaktere im
Sisika Penitentiary.

## Funktionen

- konfigurierbare Sisika-Zellen und Entlassungskoordinaten
- Haftstrafen von 1 bis standardmäßig 1440 Minuten
- persistente Haftzeit mit 50 % Fortschritt während der Spieler offline ist
- reduziertes Haft-HUD ausschließlich mit Restzeit und Begründung
- automatische Entlassung nach Ablauf
- serverseitige Grenzprüfung gegen Fluchtversuche
- Befehle für ACE-Admins und konfigurierbare Sheriff-Jobgrade
- Exporte und Events für andere Resources

## Befehle

| Befehl | Recht | Beschreibung |
| --- | --- | --- |
| `/jail <Server-ID> <Minuten> [Grund]` | ACE oder Job `sheriff` | Inhaftiert einen aktiven Charakter in Sisika. |
| `/unjail <Server-ID> [Grund]` | ACE oder Job `sheriff` | Entlässt einen aktiven Gefangenen vorzeitig. |
| `/jailstatus` | Spieler | Zeigt die eigene verbleibende Haftzeit. |
| `/jailstatus <Server-ID>` | ACE oder Job `sheriff` | Zeigt den Haftstatus eines anderen Spielers. |

Die Befehle können auch in der Serverkonsole verwendet werden. Bei
`jailstatus` ist dort eine Server-ID erforderlich.

## Konfiguration

Alle Einstellungen befinden sich in `config.lua`. Dort können Zellen,
Entlassungsposition, Gefängnismittelpunkt, erlaubter Radius, Strafzeitgrenzen,
HUD, ACE-Recht, Sheriff-Jobgrade, Speicherintervall und
`OfflineProgressMultiplier` angepasst werden. Der Standardwert `0.5` bedeutet,
dass zehn reale Offline-Minuten nur fünf Haftminuten abbauen. Inhaftierte
Sheriffs können ihre Jobrechte nicht verwenden.

## Server-Exporte

```lua
local jailed, state = exports.MS_Jail:IsJailed(source), exports.MS_Jail:GetJailState(source)
exports.MS_Jail:JailPlayer(source, 30, 'Gerichtsurteil', adminSource)
exports.MS_Jail:ReleasePlayer(source, 'Begnadigt', adminSource)
```

Zusätzlich werden `ms_jail:server:jailed` und `ms_jail:server:released`
serverseitig ausgelöst.
