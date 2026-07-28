# MS_BossMenu

`MS_BossMenu` stellt den Jobs `law`, `sheriff` und `medic` ein grafisches
Dienst- und Boss-Menü an frei konfigurierbaren Punkten bereit.

Aktuelle Resource-Version: `1.1.0`

## Funktionen

- serverseitig geschützte An- und Abmeldung zum Dienst
- persistente Erfassung der aktiven Dienstzeit bis zur nächsten Auszahlung
- Gehaltszahlung erst nach dem vollständig geleisteten Dienstintervall
- nahe, arbeitslose Spieler mit dem konfigurierten Einstiegsgrad einstellen
- Online- und Offline-Mitarbeiter aus dem eigenen Job entlassen
- Schutz vor Selbstentlassung sowie vor Eingriffen in gleich- oder
  höherrangige Charaktere
- gemeinsames Firmenkonto einsehen
- Bargeld auf das Firmenkonto einzahlen oder davon auszahlen
- bestehende Banksteuer, Kontosperren und Transaktionsprotokolle verwenden
- client- und serverseitige Prüfung von Job, Dienstgrad, Bossgrad und Entfernung

## Dienst- und Boss-Punkte konfigurieren

Alle Positionen befinden sich in `config.lua` unter
`MSBossMenuConfig.Jobs`. Ein Job kann beliebig viele Punkte besitzen:

```lua
sheriff = {
    label = 'Sheriff Office',
    dutyGrade = 0,
    bossGrade = 1,
    hireGrade = 0,
    points = {
        {
            label = 'Valentine Sheriff Office',
            coords = vector3(-278.17, 814.88, 119.28)
        }
    }
}
```

`dutyGrade` legt den niedrigsten Rang fest, der den Punkt und die
Dienstzeiterfassung verwenden darf. `bossGrade` schaltet die
Personalverwaltung und das Firmenkonto frei. `hireGrade` ist der Grad, den ein
neuer Mitarbeiter erhält. Interaktionstaste, Reichweiten, Marker,
Aktionsabstand und Verwaltungsregeln sind ebenfalls vollständig
konfigurierbar. Standardmäßig wird das Menü mit `E` geöffnet.

## Dienstzeit und Gehalt

Im Bereich `Dienst` meldet sich der Spieler an oder ab. Nur die Zeit im Status
`Im Dienst` zählt für das in `MSCore/config.lua` konfigurierte
Gehaltsintervall. Beim Logout oder Serverstopp wird der Spieler automatisch
außer Dienst gesetzt; die bereits geleistete Zeit bleibt am Charakter
gespeichert. Ein Job- oder Rangwechsel setzt den Abrechnungszeitraum zurück.
Die eigentliche Zeitmessung und Auszahlung erfolgen vollständig serverseitig
in `MSCore`.

## Firmenkonto

Das Menü nutzt direkt `MS_Banking`. Ein- und Auszahlungen werden daher mit
derselben konfigurierten Steuer belastet, sofort gespeichert und im normalen
Firmenkontoauszug protokolliert. `MS_BossMenu` muss nach `MS_Banking`
gestartet werden.
