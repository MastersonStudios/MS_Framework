MSGuarmaLoaderConfig = {}

-- Koordinaten innerhalb dieses Bereichs werden als Guarma-Spawn behandelt.
MSGuarmaLoaderConfig.Bounds = {
    minX = 0.0,
    maxX = 2500.0,
    minY = -8000.0,
    maxY = -5000.0
}

-- Maximale Wartezeit auf die Kollision. Nach dem Timeout wird der Spawn
-- trotzdem freigegeben, damit der Spieler niemals in einem Blackscreen hängt.
MSGuarmaLoaderConfig.StreamingTimeoutMs = 12000
MSGuarmaLoaderConfig.MinimumStreamingMs = 1200
MSGuarmaLoaderConfig.CollisionRequestIntervalMs = 50

-- Guarma bleibt aktiv, solange sich der Spieler innerhalb der Grenzen befindet.
MSGuarmaLoaderConfig.PositionCheckIntervalMs = 2000
MSGuarmaLoaderConfig.Debug = false
