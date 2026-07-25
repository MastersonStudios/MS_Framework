# MS_mechat

`MS_mechat` stellt den räumlich begrenzten Roleplay-Befehl `/me` bereit.

```text
/me zieht langsam seinen Hut.
```

Die Aktion erscheint im normalen Chat und als zeitlich begrenzter 3D-Text
über dem Charakter. Nur geladene Charaktere im gleichen Routing-Bucket und
innerhalb der konfigurierten Reichweite erhalten die Nachricht.

## Konfiguration

Alle Einstellungen befinden sich in `config.lua`:

- Befehl, maximale Textlänge und Spam-Cooldown
- Reichweite und Anzeigedauer
- 3D-Textfarbe, Schrift, Größe, Zeilenlänge und maximale Nachrichtenanzahl
- optionaler Sichtlinien-Test
- Chat-Ausgabe, Chatfarbe und Command-Vorschlag
- optionale Konsolenprotokollierung

## Server-Export

Andere Server-Resources können eine geprüfte Aktion im Namen eines Spielers
auslösen:

```lua
local success, messageIdOrError = exports.MS_mechat:SendAction(source, 'nickt zustimmend.')
```

Nach einer erfolgreichen Nachricht wird zusätzlich das Event
`MS_mechat:server:message` mit den geprüften Nachrichtendaten ausgelöst.
