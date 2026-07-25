# MS_pointing

`MS_pointing` startet beim Drücken der Standardtaste `B` eine synchronisierte
RedM-Zeigegeste mit dem Finger. Alternativ kann `/point` verwendet werden.

## Konfiguration

Alle Einstellungen befinden sich in `config.lua`:

- Command und frei belegbare Standardtaste
- RedM-Emote-Kit und Emote-Variante
- Cooldown und geschätzte Gestendauer
- Charakter-, Waffen-, Fahrzeug-, Pferde-, Ragdoll- und NUI-Prüfungen
- Benachrichtigungen und Chat-Command-Vorschlag

Die Taste kann jeder Spieler zusätzlich in den RedM-Tastatureinstellungen
ändern.

## Client-Exporte

```lua
local success, reason = exports.MS_pointing:StartPointing()
local allowed, pedOrReason = exports.MS_pointing:CanPoint()
local active = exports.MS_pointing:IsPointing()
```

Nach dem erfolgreichen Start wird außerdem das lokale Event
`MS_pointing:client:started` ausgelöst.
