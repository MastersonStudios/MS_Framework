local Config = MSWeaponDamageConfig
local BaseWeapons = {}
local OrderedWeaponNames = {}
local RuntimeOverrides = {}
local RequestTimes = {}
local Revision = 0

local function log(message, ...)
    print(('[MS_WeaponDamage] ' .. message):format(...))
end

local function debugLog(message, ...)
    if Config.Debug then log(message, ...) end
end

local function clamp(value, minimum, maximum)
    return math.min(math.max(value, minimum), maximum)
end

local function normalizeWeaponName(value)
    if type(value) ~= 'string' then return nil end

    local name = value:upper():gsub('^%s+', ''):gsub('%s+$', '')
    if not name:match('^WEAPON_[A-Z0-9_]+$') then return nil end
    return name
end

local function rebuildBaseConfiguration()
    BaseWeapons = {}
    OrderedWeaponNames = {}

    local minimum = tonumber(Config.MinimumMultiplier) or 0.0
    local maximum = tonumber(Config.MaximumMultiplier) or 5.0
    if maximum < minimum then minimum, maximum = maximum, minimum end

    for index, entry in ipairs(Config.Weapons or {}) do
        if type(entry) ~= 'table' then
            log('Ungültiger Eintrag an Position %d wurde übersprungen.', index)
        else
            local name = normalizeWeaponName(entry.name)
            local damage = tonumber(entry.damage)

            if not name then
                log('Ungültiger Waffenname an Position %d wurde übersprungen.', index)
            elseif BaseWeapons[name] then
                log('Doppelter Eintrag %s wurde übersprungen.', name)
            elseif not damage then
                log('Ungültiger Schadenswert für %s wurde übersprungen.', name)
            elseif entry.enabled ~= false then
                BaseWeapons[name] = {
                    name = name,
                    category = tostring(entry.category or 'other'),
                    damage = clamp(damage, minimum, maximum)
                }
                OrderedWeaponNames[#OrderedWeaponNames + 1] = name
            end
        end
    end

    Revision = Revision + 1
    log('%d Waffen geladen (Revision %d).', #OrderedWeaponNames, Revision)
end

local function makePayload()
    local weapons = {}

    if Config.Enabled ~= false then
        for _, name in ipairs(OrderedWeaponNames) do
            local base = BaseWeapons[name]
            weapons[#weapons + 1] = {
                name = name,
                category = base.category,
                damage = RuntimeOverrides[name] or base.damage
            }
        end
    end

    return {
        enabled = Config.Enabled ~= false,
        revision = Revision,
        weapons = weapons
    }
end

local function syncTarget(target)
    TriggerClientEvent('MS_WeaponDamage:client:sync', target, makePayload())
end

local function broadcast()
    Revision = Revision + 1
    syncTarget(-1)
end

local function reply(playerSource, message, isError)
    if playerSource == 0 then
        log('%s', message)
        return
    end

    TriggerClientEvent('chat:addMessage', playerSource, {
        color = isError and { 205, 70, 62 } or { 200, 164, 91 },
        args = { 'MS WeaponDamage', message }
    })
end

local function canAdminister(playerSource)
    return playerSource == 0
        or IsPlayerAceAllowed(playerSource, tostring(Config.AdminAce or 'mscore.weapon.damage'))
end

local function setRuntimeOverride(name, damage)
    name = normalizeWeaponName(name)
    damage = tonumber(damage)

    if not name or not BaseWeapons[name] then
        return false, 'Die Waffe ist nicht in config.lua eingetragen.'
    end

    if not damage then
        return false, 'Der Multiplikator muss eine Zahl sein.'
    end

    local minimum = tonumber(Config.MinimumMultiplier) or 0.0
    local maximum = tonumber(Config.MaximumMultiplier) or 5.0
    if maximum < minimum then minimum, maximum = maximum, minimum end

    RuntimeOverrides[name] = clamp(damage, minimum, maximum)
    broadcast()
    return true, RuntimeOverrides[name]
end

local function clearRuntimeOverride(name)
    name = normalizeWeaponName(name)
    if not name or not BaseWeapons[name] then
        return false, 'Die Waffe ist nicht in config.lua eingetragen.'
    end

    if RuntimeOverrides[name] == nil then
        return true, BaseWeapons[name].damage
    end

    RuntimeOverrides[name] = nil
    broadcast()
    return true, BaseWeapons[name].damage
end

RegisterNetEvent('MS_WeaponDamage:server:request', function()
    local playerSource = source
    local now = GetGameTimer()
    local cooldown = math.max(tonumber(Config.RequestCooldownMs) or 2000, 250)

    if RequestTimes[playerSource] and now - RequestTimes[playerSource] < cooldown then
        return
    end

    RequestTimes[playerSource] = now
    syncTarget(playerSource)
    debugLog('Konfiguration an Spieler %d gesendet.', playerSource)
end)

RegisterCommand('weapondamage', function(playerSource, args)
    if not canAdminister(playerSource) then
        reply(playerSource, 'Keine Berechtigung.', true)
        return
    end

    local action = tostring(args[1] or 'status'):lower()

    if action == 'status' then
        local overrideCount = 0
        for _ in pairs(RuntimeOverrides) do overrideCount = overrideCount + 1 end
        reply(playerSource, ('%d Waffen aktiv, %d Laufzeitänderungen, Revision %d.')
            :format(#OrderedWeaponNames, overrideCount, Revision))
        return
    end

    if Config.AllowRuntimeOverrides == false then
        reply(playerSource, 'Laufzeitänderungen sind in config.lua deaktiviert.', true)
        return
    end

    if action == 'set' then
        local name = args[2]
        local success, result = setRuntimeOverride(name, args[3])
        if not success then
            reply(playerSource, result, true)
            return
        end

        reply(playerSource, ('%s wurde auf %.2f gesetzt.'):format(normalizeWeaponName(name), result))
        return
    end

    if action == 'reset' then
        local name = args[2]
        local success, result = clearRuntimeOverride(name)
        if not success then
            reply(playerSource, result, true)
            return
        end

        reply(playerSource, ('%s verwendet wieder den Config-Wert %.2f.')
            :format(normalizeWeaponName(name), result))
        return
    end

    if action == 'resetall' then
        RuntimeOverrides = {}
        broadcast()
        reply(playerSource, 'Alle Laufzeitänderungen wurden zurückgesetzt.')
        return
    end

    reply(playerSource,
        'Nutzung: /weapondamage status | set WEAPON_NAME MULTIPLIKATOR | reset WEAPON_NAME | resetall',
        true)
end, false)

AddEventHandler('playerDropped', function()
    RequestTimes[source] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    rebuildBaseConfiguration()
end)

exports('GetWeaponDamageConfig', function()
    return makePayload()
end)

exports('SetWeaponDamageOverride', function(name, damage)
    return setRuntimeOverride(name, damage)
end)

exports('ClearWeaponDamageOverride', function(name)
    return clearRuntimeOverride(name)
end)
