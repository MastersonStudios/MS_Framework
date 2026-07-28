# MS_GuarmaLoader

Diese eigenständige Client-Resource aktiviert Guarmas Welt-Horizont, Fog of
War, Minimap-Zone und Wassertyp, bevor MSCore einen Charakter auf der Insel
sichtbar macht. Anschließend fordert sie die Kollision am Ziel an und beendet
den Ladebildschirm auch bei einem Streaming-Timeout kontrolliert.

Startreihenfolge:

```cfg
ensure MS_LoadingScreen
ensure MS_GuarmaLoader
ensure MSCore
```

In `config.lua` können Inselgrenzen, Streaming-Timeout und Prüfintervall
angepasst werden. `PrepareSpawn(coords)` steht anderen Client-Resources als
Export zur Verfügung. Die Resource ist unabhängig von einem Onboarding und
wird nur aktiv, wenn ein Ziel tatsächlich innerhalb der Guarma-Grenzen liegt.
