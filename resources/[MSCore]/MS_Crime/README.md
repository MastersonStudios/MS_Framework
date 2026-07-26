# MS_Crime

`MS_Crime` ergänzt MSCore um den Job `crime`, eine serverautorisierte
Durchsuchung gefesselter Spieler und die zugangsbeschränkte Crime-Stadt
Van Horn.

## Durchsuchen und Rauben

```text
/durchsuchen
```

Der Befehl ist standardmäßig zusätzlich auf `H` gelegt. Nur der Job `crime`
kann ihn verwenden. Das nächste gefesselte Ziel muss sich innerhalb der
konfigurierten Entfernung befinden. Nach dem Start erscheint
`Du durchsuchst die Person.` und eine serverseitig gemessene Wartezeit von
60 Sekunden beginnt.

Nach Ablauf werden Entfernung, Job und Fesselzustand erneut geprüft. Erst
danach öffnet sich das Raubfenster. Übertragungen prüfen serverseitig
Itembestand, `tradable`, Höchstmenge, Tragfähigkeit, Entfernung und den
weiterhin aktiven Fesselzustand.

RedM-Hogtie- und Cuff-Zustände werden automatisch erkannt. Andere
Fesselscripts können einen Schlüssel aus `RestraintStateKeys` setzen oder den
Serverexport verwenden:

```lua
exports.MS_Crime:SetRestrained(playerSource, true)
```

`true` und `false` setzen einen verbindlichen externen Zustand; mit `nil` wird
wieder die automatische Native-/State-Bag-Erkennung verwendet.

## Van Horn

Van Horn ist standardmäßig um `2981.65, 561.72, 44.85` mit einem Radius von
`235.0` Einheiten als Crime-Stadt definiert. Nur `crime` und `medic` sind
zugelassen. Andere aktive Jobs lösen lokale, bewaffnete NPC-Wachen aus, die
ausschließlich den unberechtigten Spieler angreifen.

Position, Radius, erlaubte Jobs, Modelle, Waffen, Stärke, Abstände und
Respawnzeit befinden sich vollständig in `config.lua`.
