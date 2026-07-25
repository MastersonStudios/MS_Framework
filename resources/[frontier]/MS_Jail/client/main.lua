local Config = MSJailConfig
local JailState = nil
local SentenceEndsAt = nil
local HudVisible = false
local LastDisplayedSecond = nil

local function setHudVisible(visible)
    visible = visible == true
    if HudVisible == visible then return end
    HudVisible = visible
    SendNUIMessage({ action = 'visibility', visible = visible })
end

local function configureHud()
    local hud = type(Config.Hud) == 'table' and Config.Hud or {}
    SendNUIMessage({
        action = 'configure',
        config = {
            position = hud.Position or 'top-center',
            offsetY = tonumber(hud.OffsetY) or 28,
            scale = tonumber(hud.Scale) or 1.0
        }
    })
end

local function teleport(coords)
    if type(coords) ~= 'table' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    TriggerEvent('frontier:client:beforeTeleport')
    local ped = PlayerPedId()
    DoScreenFadeOut(math.max(0, math.floor(tonumber(Config.Teleport.FadeOutMs) or 450)))
    while not IsScreenFadedOut() do Wait(0) end

    ClearPedTasksImmediately(ped)
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, tonumber(coords.w) or 0.0)
    FreezeEntityPosition(ped, true)
    Wait(math.max(0, math.floor(tonumber(Config.Teleport.CollisionWaitMs) or 1000)))
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(math.max(0, math.floor(tonumber(Config.Teleport.FadeInMs) or 600)))
end

local function applyJailState(payload)
    if type(payload) ~= 'table' then return end
    JailState = {
        characterId = tonumber(payload.characterId),
        reason = tostring(payload.reason or 'Keine Begründung angegeben.'),
        jailedBy = tostring(payload.jailedBy or 'System'),
        startedAt = tonumber(payload.startedAt),
        releaseAt = tonumber(payload.releaseAt),
        remainingSeconds = math.max(0, math.floor(tonumber(payload.remainingSeconds) or 0)),
        cell = payload.cell,
        cellIndex = tonumber(payload.cellIndex)
    }
    SentenceEndsAt = GetGameTimer() + JailState.remainingSeconds * 1000
    LastDisplayedSecond = nil
    SendNUIMessage({ action = 'jailed', state = JailState })
end

local function resetJail()
    JailState = nil
    SentenceEndsAt = nil
    LastDisplayedSecond = nil
    setHudVisible(false)
    SendNUIMessage({ action = 'reset' })
end

RegisterNetEvent('ms_jail:client:jailed', function(payload, coords)
    applyJailState(payload)
    teleport(coords or payload.cell)
end)

RegisterNetEvent('ms_jail:client:returnToCell', function(coords, payload)
    if type(payload) == 'table' then applyJailState(payload) end
    teleport(coords)
end)

RegisterNetEvent('ms_jail:client:released', function(payload, coords)
    resetJail()
    teleport(coords)
end)

RegisterNetEvent('ms_jail:client:reset', resetJail)

AddEventHandler('frontier:client:prepareLogout', resetJail)
AddEventHandler('frontier:client:playerDataChanged', function(playerData)
    if type(playerData) ~= 'table' or not tonumber(playerData.characterId) then
        resetJail()
    end
end)

CreateThread(function()
    configureHud()
    while true do
        Wait(250)
        local hud = type(Config.Hud) == 'table' and Config.Hud or {}
        local visible = JailState ~= nil
            and hud.Enabled ~= false
            and not (hud.HideInPauseMenu == true and IsPauseMenuActive())
        setHudVisible(visible)

        if JailState and SentenceEndsAt then
            local remaining = math.max(0, math.ceil((SentenceEndsAt - GetGameTimer()) / 1000))
            if remaining ~= LastDisplayedSecond then
                LastDisplayedSecond = remaining
                JailState.remainingSeconds = remaining
                SendNUIMessage({ action = 'tick', remainingSeconds = remaining })
            end

            if Config.ClearWantedLevel == true and ClearPlayerWantedLevel then
                ClearPlayerWantedLevel(PlayerId())
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    resetJail()
end)

function GetJailState()
    return JailState
end

function IsJailed()
    return JailState ~= nil and (JailState.remainingSeconds or 0) > 0
end

exports('GetJailState', GetJailState)
exports('IsJailed', IsJailed)
