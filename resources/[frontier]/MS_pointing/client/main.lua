local Config = MSPointingConfig
local TASK_EMOTE_NATIVE = 0xB31A277C1AC7B7FF
local UNARMED_WEAPON = GetHashKey('WEAPON_UNARMED')
local LastPointAt = -100000
local PointingUntil = 0

local function notify(message)
    if Config.NotifyWhenBlocked == true then
        TriggerEvent('frontier:client:notify', message)
    end
end

local function activeCharacterLoaded()
    if Config.RequireCharacter ~= true then return true end

    local playerData = exports.frontier_core:GetPlayerData()
    return type(playerData) == 'table' and tonumber(playerData.characterId) ~= nil
end

function CanPoint()
    if not activeCharacterLoaded() then
        return false, 'Wähle zuerst einen Charakter.'
    end

    if Config.BlockWithNuiFocus == true and IsNuiFocused() then
        return false, 'Die Zeigegeste ist in einem geöffneten Menü nicht verfügbar.'
    end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false, 'Dein Charakter ist noch nicht bereit.'
    end

    if IsEntityDead(ped) then
        return false, 'Die Zeigegeste ist im aktuellen Zustand nicht möglich.'
    end

    if Config.BlockWhileRagdoll == true and IsPedRagdoll(ped) then
        return false, 'Während eines Sturzes kannst du nicht zeigen.'
    end

    if Config.AllowInVehicle ~= true and IsPedInAnyVehicle(ped, false) then
        return false, 'Steige zuerst aus dem Fahrzeug aus.'
    end

    if Config.AllowOnMount ~= true and IsPedOnMount(ped) then
        return false, 'Steige zuerst vom Pferd ab.'
    end

    if Config.RequireUnarmed == true then
        local hasWeapon, weaponHash = GetCurrentPedWeapon(ped)
        if hasWeapon and weaponHash ~= UNARMED_WEAPON then
            return false, 'Stecke zuerst deine Waffe weg.'
        end
    end

    local now = GetGameTimer()
    local cooldown = math.max(0, math.floor(tonumber(Config.CooldownMs) or 1200))
    if now - LastPointAt < cooldown then
        return false, 'Die Zeigegeste ist noch im Cooldown.'
    end

    return true, ped
end

function StartPointing()
    local allowed, pedOrError = CanPoint()
    if not allowed then
        notify(pedOrError)
        return false, pedOrError
    end

    local ped = pedOrError
    local emoteKit = tostring(Config.EmoteKit or 'KIT_EMOTE_ACTION_POINT_1')
    if emoteKit == '' then
        local message = 'In MS_pointing ist keine Zeigegeste konfiguriert.'
        notify(message)
        return false, message
    end

    Citizen.InvokeNative(
        TASK_EMOTE_NATIVE,
        ped,
        math.floor(tonumber(Config.EmoteType) or 1),
        math.floor(tonumber(Config.EmoteVariation) or 2),
        GetHashKey(emoteKit),
        0,
        0,
        0,
        0,
        0
    )

    local now = GetGameTimer()
    LastPointAt = now
    PointingUntil = now + math.max(
        250,
        math.floor(tonumber(Config.EstimatedDurationMs) or 3000)
    )

    TriggerEvent('MS_pointing:client:started', ped, emoteKit)
    return true
end

function IsPointing()
    return GetGameTimer() < PointingUntil
end

RegisterCommand(Config.Command or 'point', function()
    StartPointing()
end, false)

RegisterKeyMapping(
    Config.Command or 'point',
    'Mit dem Finger zeigen',
    'keyboard',
    Config.DefaultKey or 'B'
)

CreateThread(function()
    if Config.RegisterChatSuggestion ~= true then return end

    TriggerEvent(
        'chat:addSuggestion',
        '/' .. tostring(Config.Command or 'point'),
        'Zeigt mit dem Finger nach vorne.'
    )
end)

AddEventHandler('frontier:client:prepareLogout', function()
    PointingUntil = 0
    LastPointAt = -100000
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerEvent('chat:removeSuggestion', '/' .. tostring(Config.Command or 'point'))
end)

exports('StartPointing', StartPointing)
exports('CanPoint', CanPoint)
exports('IsPointing', IsPointing)
