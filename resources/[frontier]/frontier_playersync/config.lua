PlayerSyncConfig = {}

-- The accompanying server.cfg is configured for 64 slots.
PlayerSyncConfig.MaxPlayers = 64

-- Public framework data is replicated as one shallow state-bag value.
PlayerSyncConfig.StateBagKey = 'frontierPlayer'

-- Prevent repeated snapshot requests from producing unnecessary network traffic.
PlayerSyncConfig.SnapshotRequestCooldown = 2000

-- Detect routing-bucket and framework-data changes which do not emit a core event.
PlayerSyncConfig.ReconcileInterval = 2000

-- Default radius used by the client GetNearbyPlayers export.
PlayerSyncConfig.NearbyRadius = 50.0

PlayerSyncConfig.Debug = false
