# MS_Medic

`MS_Medic` ergänzt das Frontier Framework um persistente Krankheiten,
regelmäßige Symptome sowie ein grafisches Behandlungsmenü für den Job `medic`.

## Befehle

```text
/medic
/healthstatus
/medicdisease <Server-ID> <add|remove|clear|list> [Krankheit] [Schweregrad]
```

Das Medic-Menü kann standardmäßig auch mit `F6` geöffnet werden. Der
Adminbefehl benötigt `frontier.admin` und funktioniert ebenfalls in der
Serverkonsole.

## Krankheiten und Wahrscheinlichkeiten

Jede Krankheit in `config.lua` besitzt eine eigene Ansteckungs- und
Verschlimmerungswahrscheinlichkeit. `0.01` entspricht einer Chance von einem
Prozent pro Prüfintervall. Intervall, erster Prüfzeitpunkt, maximal gleichzeitig
aktive Krankheiten, Symptome und Gesundheitsschaden sind ebenfalls
konfigurierbar.

Vorkonfiguriert sind:

- Grippe
- Lungenentzündung
- Lebensmittelvergiftung
- Wundinfektion

## Medic-Behandlungen

Medics können nahe Spieler untersuchen, Wunden versorgen, einzelne Krankheiten
behandeln und verstorbene Spieler wiederbeleben. Job, Grad, Entfernung,
Patientenzustand, Behandlungsdauer, benötigte Items und Heilungschance werden
serverseitig geprüft.

Die Resource verwendet `bandage`, `medicine`, `herbal_tonic` und `revive_kit`.
Die zusätzlichen Items sowie der Job `medic` sind in `frontier_core/config.lua`
eingetragen.

## Exporte

```lua
local diseases = exports.MS_Medic:GetDiseases(source)
local success, reason = exports.MS_Medic:AddDisease(source, 'influenza', 1)
exports.MS_Medic:RemoveDisease(source, 'influenza')
local isMedic = exports.MS_Medic:IsMedic(source)
```
