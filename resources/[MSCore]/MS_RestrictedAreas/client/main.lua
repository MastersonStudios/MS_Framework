local Config = MSRestrictedAreasConfig
local Geometry = MSRestrictedAreasGeometry
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE

local CurrentAreaState
local LastSafePosition
local ReturningPlayer = false
local Guards = {}
local GuardGeneration = 0
local GuardSpawning = false
local LastGuardSpawnAt = -1000000

local function notify(message)
    TriggerEvent('mscore:client:notify', message)
end

local function playerData()
    return exports.MSCore:GetPlayerData()
end

local function characterLoaded()
    local data = playerData()
    return type(data) == 'table' and tonumber(data.characterId) ~= nil
end

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_RestrictedAreas] ' .. message):format(...))
end

local function deleteGuard(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
end

local function clearGuards()
    GuardGeneration = GuardGeneration + 1
    for _, ped in ipairs(Guards) do deleteGuard(ped) end
    Guards = {}
    GuardSpawning = false
end

local function guardSetting(zone, key)
    local areaGuards = type(zone and zone.Guards) == 'table' and zone.Guards or {}
    if areaGuards[key] ~= nil then return areaGuards[key] end
    return (Config.MexicanGuards or {})[key]
end

local function desiredGuardCount(zone)
    local ratio = math.max(1, math.floor(tonumber(guardSetting(zone, 'RatioPerIntruder')) or 5))
    local maximum = math.max(1, math.floor(tonumber(guardSetting(zone, 'MaxPerPlayer')) or 10))
    return math.min(ratio, maximum)
end

local function activeGuards(targetPed)
    local active = {}
    for _, ped in ipairs(Guards) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            active[#active + 1] = ped
            if type(IsPedInCombat) ~= 'function' or not IsPedInCombat(ped, targetPed) then
                TaskCombatPed(ped, targetPed, 0, 16)
            end
        else
            deleteGuard(ped)
        end
    end
    Guards = active
    return #active
end

local function loadModel(model, zone)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then
        debugLog('Ungültiges Wächtermodell: %s', tostring(model))
        return nil
    end

    RequestModel(hash, false)
    local timeout = math.max(
        1000,
        math.floor(tonumber(guardSetting(zone, 'ModelLoadTimeoutMs')) or 10000)
    )
    local expiresAt = GetGameTimer() + timeout
    while not HasModelLoaded(hash) and GetGameTimer() < expiresAt do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function groundHeight(x, y, fallbackZ)
    if type(GetGroundZFor_3dCoord) ~= 'function' then return fallbackZ end
    local success, found, z = pcall(GetGroundZFor_3dCoord, x, y, fallbackZ + 30.0, false)
    if success and found and tonumber(z) then return z end
    return fallbackZ
end

local function configureGuard(ped, weaponName, targetPed, zone)
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityAsMissionEntity(ped, true, false)

    local health = math.max(100, math.floor(tonumber(guardSetting(zone, 'Health')) or 250))
    SetEntityMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    if type(SetPedArmour) == 'function' then
        SetPedArmour(ped, math.max(0, math.floor(tonumber(guardSetting(zone, 'Armor')) or 50)))
    end
    SetPedAccuracy(ped, math.max(0, math.min(
        100,
        math.floor(tonumber(guardSetting(zone, 'Accuracy')) or 55)
    )))
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    if type(SetPedCombatAbility) == 'function' then SetPedCombatAbility(ped, 2) end
    if type(SetPedCombatRange) == 'function' then SetPedCombatRange(ped, 2) end
    if type(SetPedSeeingRange) == 'function' then SetPedSeeingRange(ped, 150.0) end
    if type(SetPedHearingRange) == 'function' then SetPedHearingRange(ped, 150.0) end
    if type(SetPedFleeAttributes) == 'function' then SetPedFleeAttributes(ped, 0, false) end

    local weaponHash = GetHashKey(weaponName)
    GiveWeaponToPed(ped, weaponHash, 160, false, true)
    SetCurrentPedWeapon(ped, weaponHash, true)
    if type(SetPedDropsWeaponsWhenDead) == 'function' then SetPedDropsWeaponsWhenDead(ped, false) end
    TaskCombatPed(ped, targetPed, 0, 16)
end

local function spawnMissingGuards(zone, activeCount)
    if GuardSpawning then return end
    local desired = desiredGuardCount(zone)
    local missing = desired - activeCount
    if missing <= 0 then return end

    local cooldown = math.max(
        1000,
        math.floor(tonumber(guardSetting(zone, 'RespawnCooldownMs')) or 15000)
    )
    if GetGameTimer() - LastGuardSpawnAt < cooldown then return end

    local models = guardSetting(zone, 'Models')
    local weapons = guardSetting(zone, 'Weapons')
    if type(models) ~= 'table' or #models == 0 or type(weapons) ~= 'table' or #weapons == 0 then
        return debugLog('Gebiet %s besitzt keine Wächtermodelle oder Waffen.', tostring(zone.Id))
    end

    GuardGeneration = GuardGeneration + 1
    local generation = GuardGeneration
    GuardSpawning = true
    LastGuardSpawnAt = GetGameTimer()

    CreateThread(function()
        local targetPed = PlayerPedId()
        local radiusMinimum = math.max(5.0, tonumber(guardSetting(zone, 'SpawnRadiusMin')) or 18.0)
        local radiusMaximum = math.max(
            radiusMinimum,
            tonumber(guardSetting(zone, 'SpawnRadiusMax')) or 30.0
        )
        local phase = (GetGameTimer() % 6283) / 1000.0

        for offset = 1, missing do
            if generation ~= GuardGeneration
                or not CurrentAreaState
                or CurrentAreaState.id ~= zone.Id
                or CurrentAreaState.authorized == true
                or not DoesEntityExist(targetPed)
                or IsEntityDead(targetPed)
            then
                break
            end

            local index = activeCount + offset
            local model = models[((index - 1) % #models) + 1]
            local hash = loadModel(model, zone)
            if hash then
                local coords = GetEntityCoords(targetPed)
                local angle = phase + (math.pi * 2.0 * (index - 1) / desired)
                local fraction = ((index * 37) % 100) / 100.0
                local radius = radiusMinimum + (radiusMaximum - radiusMinimum) * fraction
                local x = coords.x + math.cos(angle) * radius
                local y = coords.y + math.sin(angle) * radius
                local z = groundHeight(x, y, coords.z)
                local heading = GetHeadingFromVector_2d(coords.x - x, coords.y - y)
                local ped = CreatePed(hash, x, y, z, heading, false, false, false, false)
                SetModelAsNoLongerNeeded(hash)

                if generation ~= GuardGeneration then
                    deleteGuard(ped)
                    break
                elseif DoesEntityExist(ped) then
                    local weapon = weapons[((index - 1) % #weapons) + 1]
                    configureGuard(ped, weapon, targetPed, zone)
                    Guards[#Guards + 1] = ped
                end
            end
        end
        if generation == GuardGeneration then GuardSpawning = false end
    end)
end

local function fadeTeleport(ped, destination)
    local entity = ped
    if type(IsPedInAnyVehicle) == 'function'
        and type(GetVehiclePedIsIn) == 'function'
        and IsPedInAnyVehicle(ped, false)
    then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then entity = vehicle end
    elseif type(GetMount) == 'function' then
        local success, mount = pcall(GetMount, ped)
        if success and mount and mount ~= 0 and DoesEntityExist(mount) then entity = mount end
    end

    local fade = math.max(0, math.floor(tonumber(Config.FadeDurationMs) or 250))
    if fade > 0 then
        DoScreenFadeOut(fade)
        local expiresAt = GetGameTimer() + fade + 1000
        while not IsScreenFadedOut() and GetGameTimer() < expiresAt do Wait(0) end
    end

    FreezeEntityPosition(entity, true)
    SetEntityCoords(entity, destination.x, destination.y, destination.z, false, false, false, false)
    if tonumber(destination.w) then SetEntityHeading(entity, tonumber(destination.w)) end
    SetEntityVelocity(entity, 0.0, 0.0, 0.0)
    FreezeEntityPosition(entity, false)

    if fade > 0 then DoScreenFadeIn(fade) end
end

local function returnFromArea(zone)
    if ReturningPlayer or type(zone) ~= 'table' then return end
    ReturningPlayer = true
    CreateThread(function()
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local current = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                w = GetEntityHeading(ped)
            }
            local destination = Geometry.ExitPoint(current, zone, LastSafePosition)
            if destination then fadeTeleport(ped, destination) end
        end
        ReturningPlayer = false
    end)
end

RegisterNetEvent('ms_restrictedareas:client:zoneState', function(state)
    local previousId = CurrentAreaState and CurrentAreaState.id
    CurrentAreaState = type(state) == 'table' and state or nil
    if previousId ~= (CurrentAreaState and CurrentAreaState.id) then clearGuards() end
    if not CurrentAreaState or CurrentAreaState.authorized == true then
        clearGuards()
        return
    end

    local zone = Geometry.GetZone(CurrentAreaState.id)
    if not zone then
        clearGuards()
        return
    end

    if CurrentAreaState.mode == 'locked' then
        LastGuardSpawnAt = -1000000
        notify(tostring(
            CurrentAreaState.lockedMessage
                or zone.LockedMessage
                or 'Du betrittst ein vollständig gesperrtes Gebiet!'
        ))
    else
        clearGuards()
        notify(tostring(
            CurrentAreaState.deniedMessage
                or zone.DeniedMessage
                or 'Du hast keine Zugangsberechtigung für dieses Gebiet.'
        ))
        returnFromArea(zone)
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('ms_restrictedareas:server:requestState')
    while true do
        if characterLoaded() then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                if not Geometry.FindZone(coords) then
                    LastSafePosition = {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        w = GetEntityHeading(ped)
                    }
                end
            end
        else
            LastSafePosition = nil
        end
        Wait(math.max(250, math.floor(tonumber(Config.SafePositionIntervalMs) or 500)))
    end
end)

CreateThread(function()
    while true do
        local state = CurrentAreaState
        local zone = state and Geometry.GetZone(state.id)
        local ped = PlayerPedId()
        if state
            and state.authorized ~= true
            and state.mode == 'locked'
            and zone
            and DoesEntityExist(ped)
            and not IsEntityDead(ped)
            and Geometry.IsInside(GetEntityCoords(ped), zone)
        then
            spawnMissingGuards(zone, activeGuards(ped))
        elseif #Guards > 0 or GuardSpawning then
            clearGuards()
        end
        Wait(math.max(250, math.floor(tonumber(Config.ClientGuardIntervalMs) or 750)))
    end
end)

AddEventHandler('mscore:client:prepareLogout', function()
    CurrentAreaState = nil
    LastSafePosition = nil
    ReturningPlayer = false
    clearGuards()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearGuards()
end)

function GetCurrentArea()
    if not CurrentAreaState then return nil end
    return {
        id = CurrentAreaState.id,
        label = CurrentAreaState.label,
        mode = CurrentAreaState.mode,
        authorized = CurrentAreaState.authorized
    }
end

function IsCurrentAreaAuthorized()
    return not CurrentAreaState or CurrentAreaState.authorized == true
end

exports('GetCurrentArea', GetCurrentArea)
exports('IsCurrentAreaAuthorized', IsCurrentAreaAuthorized)
