local PlatformRegisterKeyMapping = RegisterKeyMapping
local RegisterKeyMapping = type(PlatformRegisterKeyMapping) == 'function'
    and PlatformRegisterKeyMapping
    or function(...) return exports.MSCore:RegisterKeyMappingCompat(...) end

local Config = MSCrimeConfig
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE
local CrimeUiOpen = false
local SearchProgressActive = false
local GuardPeds = {}
local GuardSpawning = false
local GuardGeneration = 0
local LastGuardSpawnAt = -1000000
local VanHornWarningShown = false

local function notify(message)
    TriggerEvent('mscore:client:notify', message)
end

local function playerData()
    return exports.MSCore:GetPlayerData()
end

local function hasCrimeJob()
    local data = playerData()
    return type(data) == 'table' and data.job == tostring(Config.JobName or 'crime')
end

local function nativeBoolean(native, ped)
    if type(native) ~= 'function' then return false end
    local success, result = pcall(native, ped)
    return success and result == true
end

local function isLocallyRestrained()
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    if nativeBoolean(IsPedHogtied, ped)
        or nativeBoolean(IsPedCuffed, ped)
        or nativeBoolean(IsPedBeingHogtied, ped)
    then
        return true
    end

    local state = LocalPlayer and LocalPlayer.state
    if state then
        for _, key in ipairs(Config.RestraintStateKeys or {}) do
            if state[key] == true or state[key] == 1 then return true end
        end
    end
    return false
end

local function nearestPlayer(maximumDistance)
    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) then return nil end
    local playerCoords = GetEntityCoords(playerPed)
    local nearestSource
    local nearestDistance = tonumber(maximumDistance) or 3.0

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() and NetworkIsPlayerActive(player) then
            local ped = GetPlayerPed(player)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                local dx = playerCoords.x - coords.x
                local dy = playerCoords.y - coords.y
                local dz = playerCoords.z - coords.z
                local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                if distance <= nearestDistance then
                    nearestDistance = distance
                    nearestSource = GetPlayerServerId(player)
                end
            end
        end
    end
    return nearestSource
end

local function closeCrimeUi(tellServer)
    CrimeUiOpen = false
    SearchProgressActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if tellServer == true then TriggerServerEvent('ms_crime:server:closeLoot') end
end

local function startSearch()
    if CrimeUiOpen or SearchProgressActive then
        return notify('Du durchsuchst bereits eine Person.')
    end
    if not hasCrimeJob() then return notify('Nur der Crime-Job darf Personen durchsuchen.') end

    local targetSource = nearestPlayer(math.max(0.5, tonumber(Config.SearchDistance) or 3.0))
    if not targetSource then return notify('Keine Person in Reichweite gefunden.') end
    TriggerServerEvent('ms_crime:server:beginSearch', targetSource)
end

RegisterCommand(Config.SearchCommand or 'durchsuchen', startSearch, false)
RegisterKeyMapping(
    Config.SearchCommand or 'durchsuchen',
    'Gefesselte Person durchsuchen (Crime)',
    'keyboard',
    Config.DefaultKey or 'H'
)

RegisterNetEvent('ms_crime:client:startSearch', function(payload)
    SearchProgressActive = true
    CrimeUiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'startSearch', payload = payload or {} })
end)

RegisterNetEvent('ms_crime:client:openLoot', function(payload)
    if type(payload) ~= 'table' then return end
    SearchProgressActive = false
    CrimeUiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openLoot', payload = payload })
end)

RegisterNetEvent('ms_crime:client:refreshLoot', function(payload)
    if not CrimeUiOpen or type(payload) ~= 'table' then return end
    SendNUIMessage({ action = 'refreshLoot', payload = payload })
end)

RegisterNetEvent('ms_crime:client:sessionEnded', function(payload)
    local message = type(payload) == 'table' and payload.message or nil
    closeCrimeUi(false)
    if type(message) == 'string' and message ~= '' then notify(message) end
end)

RegisterNUICallback('robItem', function(data, callback)
    if CrimeUiOpen and type(data) == 'table' then
        TriggerServerEvent('ms_crime:server:robItem', data.item, data.amount)
    end
    callback({ ok = CrimeUiOpen })
end)

RegisterNUICallback('refresh', function(_, callback)
    if CrimeUiOpen then TriggerServerEvent('ms_crime:server:refreshLoot') end
    callback({ ok = CrimeUiOpen })
end)

RegisterNUICallback('close', function(_, callback)
    closeCrimeUi(true)
    callback({ ok = true })
end)

CreateThread(function()
    TriggerEvent(
        'chat:addSuggestion',
        '/' .. tostring(Config.SearchCommand or 'durchsuchen'),
        'Durchsucht als Crime-Mitglied die nächste gefesselte Person.'
    )
    while true do
        TriggerServerEvent('ms_crime:server:restraintState', isLocallyRestrained())
        Wait(math.max(250, math.floor(tonumber(Config.RestraintPollMs) or 500)))
    end
end)

local function distanceToVanHorn(coords)
    local zone = Config.VanHorn
    local center = zone and zone.Center
    if not center then return math.huge end
    local dx = coords.x - center.x
    local dy = coords.y - center.y
    local dz = coords.z - center.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function deleteGuard(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
end

local function clearGuards()
    GuardGeneration = GuardGeneration + 1
    for _, ped in ipairs(GuardPeds) do deleteGuard(ped) end
    GuardPeds = {}
    GuardSpawning = false
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end

    RequestModel(hash, false)
    local timeout = math.max(
        1000,
        math.floor(tonumber(Config.VanHorn.ModelLoadTimeoutMs) or 10000)
    )
    local expiresAt = GetGameTimer() + timeout
    while not HasModelLoaded(hash) and GetGameTimer() < expiresAt do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function groundHeight(x, y, fallbackZ)
    if type(GetGroundZFor_3dCoord) ~= 'function' then return fallbackZ end
    local success, found, z = pcall(GetGroundZFor_3dCoord, x, y, fallbackZ + 25.0, false)
    if success and found and tonumber(z) then return z end
    return fallbackZ
end

local function configureGuard(ped, weaponName, targetPed)
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityAsMissionEntity(ped, true, false)
    SetEntityMaxHealth(ped, math.max(100, math.floor(tonumber(Config.VanHorn.GuardHealth) or 250)))
    SetEntityHealth(ped, math.max(100, math.floor(tonumber(Config.VanHorn.GuardHealth) or 250)))
    if type(SetPedArmour) == 'function' then
        SetPedArmour(ped, math.max(0, math.floor(tonumber(Config.VanHorn.GuardArmor) or 50)))
    end
    SetPedAccuracy(ped, math.max(0, math.min(100, math.floor(
        tonumber(Config.VanHorn.GuardAccuracy) or 55
    ))))
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    if type(SetPedCombatAbility) == 'function' then SetPedCombatAbility(ped, 2) end
    if type(SetPedCombatRange) == 'function' then SetPedCombatRange(ped, 2) end
    if type(SetPedSeeingRange) == 'function' then SetPedSeeingRange(ped, 120.0) end
    if type(SetPedHearingRange) == 'function' then SetPedHearingRange(ped, 120.0) end
    if type(SetPedFleeAttributes) == 'function' then SetPedFleeAttributes(ped, 0, false) end

    local weaponHash = GetHashKey(weaponName)
    GiveWeaponToPed(ped, weaponHash, 120, false, true)
    SetCurrentPedWeapon(ped, weaponHash, true)
    if type(SetPedDropsWeaponsWhenDead) == 'function' then SetPedDropsWeaponsWhenDead(ped, false) end
    TaskCombatPed(ped, targetPed, 0, 16)
end

local function spawnGuards()
    if GuardSpawning or #GuardPeds > 0 then return end
    GuardGeneration = GuardGeneration + 1
    local generation = GuardGeneration
    GuardSpawning = true
    LastGuardSpawnAt = GetGameTimer()

    CreateThread(function()
        local zone = Config.VanHorn or {}
        local models = type(zone.GuardModels) == 'table' and zone.GuardModels or {}
        local weapons = type(zone.GuardWeapons) == 'table' and zone.GuardWeapons or {}
        local offsets = type(zone.GuardOffsets) == 'table' and zone.GuardOffsets or {}
        local targetPed = PlayerPedId()
        local coords = GetEntityCoords(targetPed)

        if #models == 0 or #weapons == 0 or #offsets == 0 then
            GuardSpawning = false
            return
        end

        for index, offset in ipairs(offsets) do
            if generation ~= GuardGeneration
                or not DoesEntityExist(targetPed)
                or IsEntityDead(targetPed)
            then
                break
            end

            local model = models[((index - 1) % #models) + 1]
            local hash = loadModel(model)
            if hash then
                local x = coords.x + (tonumber(offset.x) or 0.0)
                local y = coords.y + (tonumber(offset.y) or 0.0)
                local z = groundHeight(x, y, coords.z)
                local heading = GetHeadingFromVector_2d(coords.x - x, coords.y - y)
                local ped = CreatePed(hash, x, y, z, heading, false, false, false, false)
                SetModelAsNoLongerNeeded(hash)

                if generation ~= GuardGeneration then
                    deleteGuard(ped)
                    break
                elseif DoesEntityExist(ped) then
                    configureGuard(ped, weapons[((index - 1) % #weapons) + 1], targetPed)
                    GuardPeds[#GuardPeds + 1] = ped
                end
            end
        end
        if generation == GuardGeneration then GuardSpawning = false end
    end)
end

local function activeGuardCount(targetPed)
    local active = {}
    for _, ped in ipairs(GuardPeds) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            active[#active + 1] = ped
            if type(IsPedInCombat) ~= 'function' or not IsPedInCombat(ped, targetPed) then
                TaskCombatPed(ped, targetPed, 0, 16)
            end
        else
            deleteGuard(ped)
        end
    end
    GuardPeds = active
    return #active
end

CreateThread(function()
    while true do
        local zone = Config.VanHorn or {}
        local data = playerData()
        local ped = PlayerPedId()
        local characterLoaded = type(data) == 'table' and tonumber(data.characterId) ~= nil
        local allowed = characterLoaded
            and type(zone.AllowedJobs) == 'table'
            and zone.AllowedJobs[data.job] == true
        local inside = false

        if zone.Enabled == true and characterLoaded and DoesEntityExist(ped) then
            inside = distanceToVanHorn(GetEntityCoords(ped))
                <= math.max(1.0, tonumber(zone.Radius) or 235.0)
        end

        if inside and not allowed and not IsEntityDead(ped) then
            if not VanHornWarningShown then
                VanHornWarningShown = true
                notify(tostring(zone.Warning or 'Du hast keinen Zugang zu Van Horn.'))
            end

            local count = activeGuardCount(ped)
            local cooldown = math.max(
                1000,
                math.floor(tonumber(zone.RespawnCooldownMs) or 30000)
            )
            if count == 0 and not GuardSpawning and GetGameTimer() - LastGuardSpawnAt >= cooldown then
                spawnGuards()
            end
        else
            if #GuardPeds > 0 or GuardSpawning then clearGuards() end
            VanHornWarningShown = false
            if not inside then LastGuardSpawnAt = -1000000 end
        end

        Wait(math.max(250, math.floor(tonumber(zone.CheckIntervalMs) or 750)))
    end
end)

AddEventHandler('mscore:client:prepareLogout', function()
    closeCrimeUi(false)
    clearGuards()
    VanHornWarningShown = false
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeCrimeUi(true)
    clearGuards()
    TriggerEvent('chat:removeSuggestion', '/' .. tostring(Config.SearchCommand or 'durchsuchen'))
end)

function IsCrimeUiOpen()
    return CrimeUiOpen or SearchProgressActive
end

exports('IsCrimeUiOpen', IsCrimeUiOpen)
