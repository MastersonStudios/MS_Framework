# MS Banking

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
- serverseitige Distanz-, Betrags-, Guthaben- und Kontoprüfung
- unmittelbare Speicherung erfolgreicher Geldbewegungen
- grafische Bankoberfläche und Interaktion über `E`

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

## Installation

`ensure MS_Banking` muss nach `oxmysql` und `MSCore` gestartet werden. Die
benötigten Tabellen werden beim Start automatisch angelegt und sind für neue
Installationen zusätzlich in `database/schema.sql` enthalten.

Der Befehl `/bank` öffnet das Menü beim nächsten erreichbaren Banker.
