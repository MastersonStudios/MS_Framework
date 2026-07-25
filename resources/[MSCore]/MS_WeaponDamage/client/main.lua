local Config = MSWeaponDamageConfig
local SET_PLAYER_WEAPON_TYPE_DAMAGE_MODIFIER = 0xD04AD186CE8BB129
local WeaponModifiers = {}
local Revision = 0

local function debugLog(message, ...)
    if not Config.Debug then return end
    print(('[MS_WeaponDamage] ' .. message):format(...))
end

local function resetAppliedModifiers()
    local player = PlayerId()
    for weaponHash in pairs(WeaponModifiers) do
        Citizen.InvokeNative(SET_PLAYER_WEAPON_TYPE_DAMAGE_MODIFIER, player, weaponHash, 1.0)
    end
    WeaponModifiers = {}
end

local function applyModifier(weaponHash, multiplier)
    Citizen.InvokeNative(
        SET_PLAYER_WEAPON_TYPE_DAMAGE_MODIFIER,
        PlayerId(),
        weaponHash,
        multiplier
    )
end

local function synchronize(payload)
    if type(payload) ~= 'table' then return end

    local incomingRevision = tonumber(payload.revision) or 0
    if incomingRevision < Revision then return end

    resetAppliedModifiers()
    Revision = incomingRevision

    if payload.enabled == false or type(payload.weapons) ~= 'table' then
        TriggerEvent('MS_WeaponDamage:client:updated', Revision, 0)
        return
    end

    local count = 0
    for _, entry in ipairs(payload.weapons) do
        if type(entry) == 'table'
            and type(entry.name) == 'string'
            and type(entry.damage) == 'number'
        then
            local weaponHash = GetHashKey(entry.name)
            WeaponModifiers[weaponHash] = {
                name = entry.name,
                category = tostring(entry.category or 'other'),
                damage = entry.damage
            }
            applyModifier(weaponHash, entry.damage)
            count = count + 1
        end
    end

    debugLog('%d Waffenmodifikatoren angewendet (Revision %d).', count, Revision)
    TriggerEvent('MS_WeaponDamage:client:updated', Revision, count)
end

RegisterNetEvent('MS_WeaponDamage:client:sync', synchronize)

CreateThread(function()
    Wait(0)
    TriggerServerEvent('MS_WeaponDamage:server:request')

    while true do
        Wait(math.max(tonumber(Config.ReapplyIntervalMs) or 1000, 250))

        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local hasWeapon, weaponHash = GetCurrentPedWeapon(ped)
            local entry = hasWeapon and WeaponModifiers[weaponHash] or nil
            if entry then applyModifier(weaponHash, entry.damage) end
        end
    end
end)

AddEventHandler('playerSpawned', function()
    TriggerServerEvent('MS_WeaponDamage:server:request')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    resetAppliedModifiers()
end)

exports('GetWeaponDamageMultiplier', function(weapon)
    local weaponHash = type(weapon) == 'string' and GetHashKey(weapon) or tonumber(weapon)
    local entry = weaponHash and WeaponModifiers[weaponHash] or nil
    return entry and entry.damage or tonumber(Config.DefaultMultiplier) or 1.0
end)

exports('GetWeaponDamageConfig', function()
    local copy = {}
    for weaponHash, entry in pairs(WeaponModifiers) do
        copy[weaponHash] = {
            name = entry.name,
            category = entry.category,
            damage = entry.damage
        }
    end
    return copy, Revision
end)
