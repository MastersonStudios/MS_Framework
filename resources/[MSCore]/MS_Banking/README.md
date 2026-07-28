# MS Banking

Aktuelle Resource-Version: `1.3.0`

`MS_Banking` ergänzt MSCore um persönliche Charakterkonten und konfigurierbare
Banker-NPCs. Das vorhandene MSCore-Guthaben `bank` bleibt die zentrale
Geldquelle, sodass Jobgehälter, Admin-Gutschriften und Bankgeschäfte immer
denselben Saldo verwenden.

## Funktionen

- automatische, eindeutige Kontonummer pro Charakter
- Einzahlungen von Bargeld auf das Bankkonto
- Auszahlungen vom Bankkonto als Bargeld an jeder Filiale
- Überweisungen an Kontonummern von Online- und Offline-Charakteren
- persistenter Buchungsverlauf mit Kontostand nach jeder Transaktion
- gemeinsame Firmenkonten für alle konfigurierten Jobs
- Firmen-Einzahlungen und ranggeschützte Firmen-Auszahlungen
- eigener Firmenkontoauszug mit ausführendem Charakter
- zentrales Adminkonto mit konfigurierbarer Transaktionssteuer
- schreibgeschützte Adminansicht mit vollständiger Steuerhistorie
- serverseitige Distanz-, Betrags-, Guthaben- und Kontoprüfung
- unmittelbare Speicherung erfolgreicher Geldbewegungen
- grafische Bankoberfläche und Interaktion über `E`
- gesicherte Firmenkonto-Sitzungen für die Boss-Punkte von `MS_BossMenu`

## Konfiguration

Banker werden in `config.lua` unter `MSBankingConfig.Bankers` eingetragen:

```lua
valentine = {
    label = 'Valentine Bank',
    npc = {
        model = 'u_m_m_valbanker_01',
        scenario = 'GENERIC_STANDING_SCENARIO',
        x = -308.42,
        y = 776.08,
        z = 118.70,
        heading = 10.0
    }
}
```

Interaktionstaste, Kontonummer-Präfix, Maximallimit, Reichweiten,
Streaming-Distanzen und Länge des Buchungsverlaufs sind ebenfalls
konfigurierbar. Alle eingetragenen Banker greifen auf dasselbe Konto eines
Charakters zu.

Firmenkonten stehen unter `MSBankingConfig.CompanyAccounts`. Grad `0` darf
standardmäßig einzahlen; Auszahlungen benötigen den pro Job eingetragenen
`minWithdrawGrade`. Vorkonfiguriert sind `sheriff`, `medic`, `native`,
`gunsmith` und `law`. Arbeitslose und der Job `crime` besitzen kein
Firmenkonto.
Neue, später ergänzte Jobs erhalten über `CompanyAccountDefaults` automatisch
ein Firmenkonto; Ausnahmen können unter `excludedJobs` eingetragen werden.

| Job | Firmenkonto | Auszahlungen ab Grad |
| --- | --- | ---: |
| `sheriff` | Sheriff Office | `1` |
| `medic` | Medic | `2` |
| `native` | Stammeskonto | `1` |
| `gunsmith` | Büchsenmacher | `1` |
| `law` | Law | `1` |

## Adminkonto und Transaktionssteuer

Private und geschäftliche Ein- sowie Auszahlungen werden standardmäßig mit
`1 %` besteuert. Die Steuer wird vom eingegebenen Bruttobetrag abgezogen und
automatisch dem persistenten `Administrationskonto` gutgeschrieben. Beispiel:
Bei `$100` werden `$1` Steuer gebucht und `$99` gutgeschrieben beziehungsweise
ausgezahlt. Überweisungen zwischen persönlichen Konten sind standardmäßig
steuerfrei.

MSCore speichert Geld in ganzen Dollarbeträgen. Deshalb verwendet die
Standardkonfiguration `ceil` und rundet eine positive Steuer auf den nächsten
vollen Dollar auf. Vorgänge, deren Steuer den gesamten Betrag aufbrauchen
würde, werden abgelehnt.

Prozentsatz, Mindeststeuer, Rundung und betroffene Vorgänge befinden sich in
`MSBankingConfig.TransactionTax`. Bezeichnung, Kontoschlüssel, ACE-Recht und
zulässige Admin-Gruppen stehen unter `MSBankingConfig.AdminAccount`.
Berechtigte Admins sehen in der Bank einen schreibgeschützten Tab mit
Gesamtsaldo, Steuersatz und den letzten Steuerbuchungen.

## Installation

`ensure MS_Banking` muss nach `oxmysql` und `MSCore` gestartet werden. Die
benötigten Tabellen werden beim Start automatisch angelegt und sind für neue
Installationen zusätzlich in `database/schema.sql` enthalten.

Der Befehl `/bank` öffnet das Menü beim nächsten erreichbaren Banker.
