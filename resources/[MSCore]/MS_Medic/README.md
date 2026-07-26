# MS_Medic

`MS_Medic` ergänzt das MSCore Framework um persistente Krankheiten,
regelmäßige Symptome, ein grafisches Behandlungsmenü für den Job `medic` und
einen serverautoritativen Bewusstlos-Zustand mit Notruf.

Aktuelle Resource-Version: `1.1.0`

## Befehle

```text
/medic
/healthstatus
/medicdisease <Server-ID> <add|remove|clear|list> [Krankheit] [Schweregrad]
```

Das Medic-Menü kann standardmäßig auch mit `F6` geöffnet werden. Der
Adminbefehl benötigt `mscore.admin` und funktioniert ebenfalls in der
Serverkonsole.

## Bewusstlosigkeit und Notruf

Bei einem normalen Tod öffnet sich automatisch der Bewusstlos-Screen. Der
serverseitige Timer startet standardmäßig bei `10:00` Minuten. Über die
Schaltfläche `Notruf senden` werden alle diensthabenden Medics alarmiert und
erhalten auf ihrer Karte einen Einsatzmarker mit `15` Metern Radius. Der
Bewusstlos-Timer wird dabei auf `20:00` Minuten gesetzt.

Der Zustand wird in den Charakter-Metadaten gespeichert. Ausloggen oder ein
Resource-Neustart setzt die verbleibende Zeit daher nicht zurück. Wird der
Spieler nicht rechtzeitig wiederbelebt, wacht er automatisch in der von seinem
Todesort aus nächstgelegenen konfigurierten Stadt auf. Inhaftierte Charaktere
wachen stattdessen weiter in ihrer Sisika-Zelle auf. Ein von `MS_Permadeath`
bestätigter permanenter Charaktertod wird niemals automatisch wiederbelebt.

Timer, Aufwachgesundheit, Kartenradius, Blipdarstellung und Stadtpositionen
lassen sich unter `MSMedicConfig.Unconscious` in `config.lua` anpassen.

## Krankheiten und Wahrscheinlichkeiten

Jede Krankheit in `config.lua` besitzt eine eigene Ansteckungs- und
Verschlimmerungswahrscheinlichkeit. `0.01` entspricht einer Chance von einem
Prozent pro Prüfintervall. Intervall, erster Prüfzeitpunkt, maximal gleichzeitig
aktive Krankheiten, Symptome und Gesundheitsschaden sind ebenfalls
konfigurierbar.

Vorkonfiguriert sind:

- Grippe
- Lungenentzündung
- Vergiftung
- Wundinfektion
- Knochenbruch
- Schusswunde

## Medic-Behandlungen

Medics können nahe Spieler untersuchen, Wunden versorgen, einzelne Krankheiten
behandeln und verstorbene Spieler wiederbeleben. Job, Grad, Entfernung,
Patientenzustand, Behandlungsdauer, benötigte Items und Heilungschance werden
serverseitig geprüft.

Ein aktiver `bone_fracture` reduziert die Gehgeschwindigkeit abhängig vom
Schweregrad, verhindert Sprinten und löst konfigurierbare Schmerzschübe aus.
Medics behandeln den Knochenbruch mit zwei Verbänden und einer Medizin. Alle
Werte befinden sich unter `MSMedicConfig.Diseases.bone_fracture`.

`food_poisoning` löst in zufälligen, konfigurierbaren Abständen eine
Erbrechensreaktion aus. Jeder Anfall reduziert den Versorgungswert `thirst`
über den serverseitigen Export von `MS_BasicNeeds` um einen Prozentpunkt.

Eine `gunshot_wound` wird bei einem Treffer durch eine konfigurierte
Schusswaffe automatisch angelegt. Weitere Treffer können die persistente
Schwere erhöhen. Blutung, Gesundheitsschaden, Zeitabstände und
Schmerzreaktion sind vollständig konfigurierbar.

Ein Klick auf einen Patienten öffnet das Kontextmenü `Patient untersuchen`.
Nach der serverseitig geprüften Untersuchung erscheinen die Symptome in einem
separaten Fenster; von dort kann der Medic zu den Behandlungsoptionen wechseln.

Die Resource verwendet `bandage`, `medicine`, `herbal_tonic` und `revive_kit`.
Die zusätzlichen Items sowie der Job `medic` sind in `MSCore/config.lua`
eingetragen.

## Exporte

```lua
local diseases = exports.MS_Medic:GetDiseases(source)
local success, reason = exports.MS_Medic:AddDisease(source, 'influenza', 1)
exports.MS_Medic:RemoveDisease(source, 'influenza')
local isMedic = exports.MS_Medic:IsMedic(source)
local unconscious = exports.MS_Medic:GetUnconsciousState(source)
local isUnconscious = exports.MS_Medic:IsUnconscious(source)
```
