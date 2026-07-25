local Config = MSBasicNeedsConfig
local CurrentNeeds = nil
local HudVisible = false
local CharacterId = nil

local function configureHud()
    local hud = type(Config.Hud) == 'table' and Config.Hud or {}
    SendNUIMessage({
        action = 'configure',
        config = {
            position = hud.Position or 'bottom-right',
            offsetX = tonumber(hud.OffsetX) or 32,
            offsetY = tonumber(hud.OffsetY) or 36,
            scale = tonumber(hud.Scale) or 1.0,
            showLabels = hud.ShowLabels ~= false,
            showValues = hud.ShowValues ~= false
        }
    })
end

local function setHudVisible(visible)
    visible = visible == true
    if HudVisible == visible then return end
    HudVisible = visible
    SendNUIMessage({ action = 'visibility', visible = visible })
end

local function resetNeeds()
    CurrentNeeds = nil
    setHudVisible(false)
    SendNUIMessage({ action = 'reset' })
end

RegisterNetEvent('ms_basicneeds:client:update', function(payload)
    if type(payload) ~= 'table' then return end
    CurrentNeeds = {
        hunger = tonumber(payload.hunger) or 0,
        thirst = tonumber(payload.thirst) or 0,
        minimum = tonumber(payload.minimum) or 0,
        maximum = tonumber(payload.maximum) or 100,
        criticalThreshold = tonumber(payload.criticalThreshold) or 20
    }
    SendNUIMessage({ action = 'update', needs = CurrentNeeds })
    TriggerEvent('MS_BasicNeeds:client:needsChanged', CurrentNeeds)
end)

RegisterNetEvent('ms_basicneeds:client:reset', resetNeeds)

RegisterNetEvent('ms_basicneeds:client:damage', function(data)
    if type(data) ~= 'table' then return end
    local amount = math.max(0, math.floor(tonumber(data.amount) or 0))
    local ped = PlayerPedId()
    if amount < 1 or ped == 0 or IsEntityDead(ped) then return end

    local minimumHealth = data.canKill == true
        and 0
        or math.max(1, math.floor(tonumber(data.minimumHealth) or 25))
    local currentHealth = GetEntityHealth(ped)
    SetEntityHealth(ped, math.max(minimumHealth, currentHealth - amount))

    if type(data.message) == 'string' and data.message ~= '' then
        TriggerEvent('mscore:client:notify', data.message)
    end
end)

AddEventHandler('mscore:client:playerDataChanged', function(playerData)
    local nextCharacterId = type(playerData) == 'table' and tonumber(playerData.characterId) or nil
    if not nextCharacterId then
        CharacterId = nil
        return resetNeeds()
    end
    if nextCharacterId ~= CharacterId then
        CharacterId = nextCharacterId
        TriggerServerEvent('ms_basicneeds:server:request')
    end
end)

AddEventHandler('mscore:client:prepareLogout', function()
    CharacterId = nil
    resetNeeds()
end)

CreateThread(function()
    configureHud()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)
    local playerData = exports.MSCore:GetPlayerData()
    CharacterId = type(playerData) == 'table' and tonumber(playerData.characterId) or nil
    if CharacterId then TriggerServerEvent('ms_basicneeds:server:request') end
end)

CreateThread(function()
    while true do
        Wait(250)
        local hud = type(Config.Hud) == 'table' and Config.Hud or {}
        local hideForPause = hud.HideInPauseMenu ~= false and IsPauseMenuActive()
        setHudVisible(
            Config.Enabled == true
            and hud.Enabled ~= false
            and CharacterId ~= nil
            and CurrentNeeds ~= nil
            and not hideForPause
        )
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    resetNeeds()
end)

function GetNeeds()
    if not CurrentNeeds then return nil end
    return {
        hunger = CurrentNeeds.hunger,
        thirst = CurrentNeeds.thirst,
        minimum = CurrentNeeds.minimum,
        maximum = CurrentNeeds.maximum,
        criticalThreshold = CurrentNeeds.criticalThreshold
    }
end

function IsHudVisible()
    return HudVisible
end

exports('GetNeeds', GetNeeds)
exports('IsHudVisible', IsHudVisible)
