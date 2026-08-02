local spawnSequence = 0

local function waitForFade(fadedOut, timeoutMs)
    local startedAt = GetGameTimer()
    while GetGameTimer() - startedAt < timeoutMs do
        if fadedOut and IsScreenFadedOut() then return end
        if not fadedOut and IsScreenFadedIn() then return end
        Wait(0)
    end
end

local function cleanupCameraAndFocus()
    if type(ShutdownLoadingScreen) == 'function' then ShutdownLoadingScreen() end
    if type(ShutdownLoadingScreenNui) == 'function' then ShutdownLoadingScreenNui() end
    if type(SetNuiFocus) == 'function' then SetNuiFocus(false, false) end
    if type(ClearFocus) == 'function' then ClearFocus() end
    if type(RenderScriptCams) == 'function' then RenderScriptCams(false, false, 0, true, true) end
end

RegisterNetEvent('mscore:client:spawn', function(coords, data)
    spawnSequence = spawnSequence + 1
    local thisSequence = spawnSequence
    coords = type(coords) == 'table' and coords or {}
    local fallback = Config.DefaultCharacter.spawn
    local x = tonumber(coords.x) or fallback.x
    local y = tonumber(coords.y) or fallback.y
    local z = tonumber(coords.z) or fallback.z
    local heading = tonumber(coords.w or coords.heading) or fallback.w

    CreateThread(function()
        cleanupCameraAndFocus()
        if type(DoScreenFadeOut) == 'function' then
            DoScreenFadeOut(300)
            waitForFade(true, 1500)
        end

        local ped = PlayerPedId()
        if not ped or ped == 0 then
            cleanupCameraAndFocus()
            if type(DoScreenFadeIn) == 'function' then DoScreenFadeIn(500) end
            return
        end

        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, true)
        if type(ResetEntityAlpha) == 'function' then ResetEntityAlpha(ped) end
        RequestCollisionAtCoord(x, y, z)
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, heading)

        local startedAt = GetGameTimer()
        local timeout = math.max(1000, tonumber(Config.SpawnStreamingTimeoutMs) or 8000)
        while GetGameTimer() - startedAt < timeout do
            if thisSequence ~= spawnSequence then return end
            RequestCollisionAtCoord(x, y, z)
            if type(HasCollisionLoadedAroundEntity) ~= 'function' or HasCollisionLoadedAroundEntity(ped) then break end
            Wait(50)
        end

        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, heading)
        if type(ClearPedTasksImmediately) == 'function' then ClearPedTasksImmediately(ped) end
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true)
        if type(SetPlayerControl) == 'function' then SetPlayerControl(PlayerId(), true, 0) end

        cleanupCameraAndFocus()
        if type(DisplayHud) == 'function' then DisplayHud(true) end
        if type(DisplayRadar) == 'function' then DisplayRadar(true) end
        if type(DoScreenFadeIn) == 'function' then
            DoScreenFadeIn(750)
            waitForFade(false, 2500)
            if not IsScreenFadedIn() then DoScreenFadeIn(0) end
        end

        TriggerEvent('mscore:client:spawned', MSUtils.Copy(data), { x = x, y = y, z = z, w = heading })
    end)
end)

CreateThread(function()
    while true do
        Wait(math.max(5000, tonumber(Config.PositionUpdateMs) or 30000))
        if MSCore.IsPlayerLoaded() then TriggerServerEvent('mscore:server:updatePosition') end
    end
end)
