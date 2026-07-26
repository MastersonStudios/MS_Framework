# MS_Permadeath

`MS_Permadeath` verwaltet ein dauerhaftes Todesrisiko pro MSCore-Charakter.
Jeder serverseitig bestätigte Tod erhöht den Wert zufällig um `1–3`
Prozentpunkte. Standardmäßig tritt der permanente Charaktertod erst beim
Überschreiten von `60 %` ein, also ab `61 %`.

Die Todeserkennung prüft den RedM-Ped eigenständig. Kompatible
`baseevents:onPlayerDied`- und `baseevents:onPlayerKilled`-Events werden
optional mitverwendet, sind aber keine Abhängigkeit.

Beim Überschreiten wird der Charakter sofort über `is_deleted = 1` aus der
Charakterauswahl gesperrt. Anschließend läuft eine Finalszene und MSCore meldet
den Charakter ab. Der Datensatz wird nicht hart gelöscht und bleibt dadurch für
Datenbank-Backups oder eine manuelle Notfallwiederherstellung erhalten.

## Cutscene

Da Story-Cutscene-Assets zwischen RDR2-Builds und Storyzuständen variieren,
enthält `config.lua` unter `Finale.NativeCutscene.Name` ein konfigurierbares
Asset. Ist es leer oder nicht verfügbar, läuft automatisch eine geskriptete,
von Arthur Morgans Sonnenaufgangs-Finale inspirierte Kamerasequenz.

Mit `permadeath testscene [Server-ID]` kann die Szene sicher getestet werden.
Dabei werden weder Risiko noch Charakterstatus verändert.

## Befehle

- `deathrisk` zeigt Spielern Risiko, Todesanzahl und Schwellwert.
- `permadeath status [Server-ID]` zeigt Admins den gespeicherten Zustand.
- `permadeath set <Server-ID> <0-100>` setzt das Risiko; ausgelöst wird erst
  beim nächsten bestätigten Tod.
- `permadeath reset <Server-ID>` setzt Risiko und Todeszähler zurück.
- `permadeath testscene [Server-ID]` spielt die Finalszene ohne Datenänderung.

Adminaktionen benötigen `mscore.admin.permadeath` oder `mscore.admin`.

## Integration

Die Resource exportiert serverseitig:

- `exports.MS_Permadeath:GetRisk(serverId)`
- `exports.MS_Permadeath:IsFinalDeath(serverId)`

`MS_Medic` und das ACP verwenden `IsFinalDeath`, um Wiederbelebung oder Heilung
während einer bereits ausgelösten Finalsequenz zu verhindern.
