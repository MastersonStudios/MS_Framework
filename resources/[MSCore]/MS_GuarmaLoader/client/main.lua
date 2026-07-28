local GUARMA_ZONE_HASH = 1935063277
local WORLD_ZONE_HASH = -1868977180
local GUARMA_WATER_TYPE = 1
local WORLD_WATER_TYPE = 0

local SET_GUARMA_WORLDHORIZON_ACTIVE = 0x74E2261D2A66849A
local SET_FOW_UPDATE_PLAYER_OVERRIDE = 0x63E7279D04160477
local SET_MINIMAP_ZONE = 0xA657EC9DBC6CC900
local SET_WORLD_WATER_TYPE = 0xE8770EE02AEE45C2

local GuarmaActive = false
local PreparingSpawn = false
local RecoveryToken = 0

local function debugLog(message)
    if MSGuarmaLoaderConfig.Debug then
        print(('[MS_GuarmaLoader] %s'):format(tostring(message)))
    end
end

local function coordinate(value, key, index)
    if type(value) ~= 'table' and type(value) ~= 'vector3'
        and type(value) ~= 'vector4'
    then
        return nil
    end
    return tonumber(value[key]) or tonumber(value[index])
end

local function isGuarmaCoords(coords)
    local x = coordinate(coords, 'x', 1)
    local y = coordinate(coords, 'y', 2)
    local bounds = MSGuarmaLoaderConfig.Bounds
    return x ~= nil and y ~= nil
        and x >= bounds.minX and x <= bounds.maxX
        and y >= bounds.minY and y <= bounds.maxY
end

local function setGuarmaMode(enabled)
    enabled = enabled == true

    -- Rockstar verwendet für den Guarma-Modus den umgekehrten Wert beim
    -- World-Horizon-Schalter. Die übrigen Natives schalten FOW, Karte und
    -- Wasser explizit auf die Insel bzw. die Hauptwelt.
    Citizen.InvokeNative(SET_GUARMA_WORLDHORIZON_ACTIVE, not enabled)
    Citizen.InvokeNative(SET_FOW_UPDATE_PLAYER_OVERRIDE, enabled)
    Citizen.InvokeNative(SET_MINIMAP_ZONE, enabled and GUARMA_ZONE_HASH or WORLD_ZONE_HASH)
    Citizen.InvokeNative(SET_WORLD_WATER_TYPE, enabled and GUARMA_WATER_TYPE or WORLD_WATER_TYPE)

    GuarmaActive = enabled
    debugLog(enabled and 'Guarma aktiviert.' or 'Hauptwelt aktiviert.')
    return true
end

local function stopLoadingScreens()
    if type(ShutdownLoadingScreen) == 'function' then
        pcall(ShutdownLoadingScreen)
    end
    if type(ShutdownLoadingScreenNui) == 'function' then
        pcall(ShutdownLoadingScreenNui)
    end
end

local function scheduleScreenRecovery()
    RecoveryToken = RecoveryToken + 1
    local token = RecoveryToken
    SetTimeout(2500, function()
        if token ~= RecoveryToken then return end
        local ped = PlayerPedId()
        if not isGuarmaCoords(GetEntityCoords(ped)) then return end

        stopLoadingScreens()
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        if IsScreenFadedOut() then DoScreenFadeIn(0) end
    end)
end

local function prepareSpawn(coords)
    local x = coordinate(coords, 'x', 1)
    local y = coordinate(coords, 'y', 2)
    local z = coordinate(coords, 'z', 3)
    if not x or not y or not z then
        return false, 'Ungültige Spawnkoordinaten.'
    end

    if not isGuarmaCoords(coords) then
        if GuarmaActive then setGuarmaMode(false) end
        return true
    end
    if PreparingSpawn then
        return false, 'Ein Guarma-Spawn wird bereits vorbereitet.'
    end

    PreparingSpawn = true
    local ped = PlayerPedId()
    local timeout = math.max(
        1000,
        math.floor(tonumber(MSGuarmaLoaderConfig.StreamingTimeoutMs) or 12000)
    )
    local success, collisionLoaded = xpcall(function()
        setGuarmaMode(true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)

        if type(SetFocusPosAndVel) == 'function' then
            SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
        end
        RequestCollisionAtCoord(x, y, z)
        SetEntityCoords(ped, x, y, z, false, false, false, false)
        SetEntityHeading(ped, coordinate(coords, 'w', 4) or 0.0)

        local minimum = math.max(
            0,
            math.min(timeout, math.floor(tonumber(MSGuarmaLoaderConfig.MinimumStreamingMs) or 1200))
        )
        local interval = math.max(
            0,
            math.floor(tonumber(MSGuarmaLoaderConfig.CollisionRequestIntervalMs) or 50)
        )
        local startedAt = GetGameTimer()

        while GetGameTimer() - startedAt < timeout do
            RequestCollisionAtCoord(x, y, z)
            if GetGameTimer() - startedAt >= minimum then
                if type(HasCollisionLoadedAroundEntity) ~= 'function'
                    or HasCollisionLoadedAroundEntity(ped)
                then
                    return true
                end
            end
            Wait(interval)
        end
        return false
    end, function(errorMessage)
        if type(debug) == 'table' and type(debug.traceback) == 'function' then
            return debug.traceback(tostring(errorMessage), 2)
        end
        return tostring(errorMessage)
    end)

    if type(ClearFocus) == 'function' then ClearFocus() end
    stopLoadingScreens()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    PreparingSpawn = false
    scheduleScreenRecovery()

    if not success then
        print(('[MS_GuarmaLoader] Guarma konnte nicht vollständig vorbereitet werden:\n%s')
            :format(tostring(collisionLoaded)))
        return false, tostring(collisionLoaded)
    end

    if not collisionLoaded then
        print(('[MS_GuarmaLoader] Kollisions-Timeout nach %d ms; '
            .. 'der Spawn wird freigegeben, um einen Blackscreen zu verhindern.'):format(timeout))
    end
    return collisionLoaded
end

RegisterNetEvent('ms_guarma_loader:client:setMode', function(enabled)
    setGuarmaMode(enabled == true)
end)

RegisterNetEvent('ms_guarma_loader:client:prepareSpawn', function(coords)
    prepareSpawn(coords)
end)

exports('IsGuarmaCoords', isGuarmaCoords)
exports('IsGuarmaActive', function() return GuarmaActive end)
exports('SetGuarmaMode', setGuarmaMode)
exports('PrepareSpawn', prepareSpawn)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(500)
    if isGuarmaCoords(GetEntityCoords(PlayerPedId())) then
        setGuarmaMode(true)
    end

    local interval = math.max(
        500,
        math.floor(tonumber(MSGuarmaLoaderConfig.PositionCheckIntervalMs) or 2000)
    )
    while true do
        Wait(interval)
        if not PreparingSpawn then
            local shouldBeActive = isGuarmaCoords(GetEntityCoords(PlayerPedId()))
            if shouldBeActive ~= GuarmaActive then
                setGuarmaMode(shouldBeActive)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if type(ClearFocus) == 'function' then ClearFocus() end
    PreparingSpawn = false
end)
