local PlatformRegisterKeyMapping = RegisterKeyMapping
local RegisterKeyMapping = type(PlatformRegisterKeyMapping) == 'function'
    and PlatformRegisterKeyMapping
    or function(...) return exports.MSCore:RegisterKeyMappingCompat(...) end

local InventoryOpen = false
local AppliedComponents = {}

local APPLY_SHOP_ITEM_TO_PED = 0xD3A7B003ED343FD9
local REMOVE_SHOP_ITEM_FROM_PED = 0x0D7FFA1B2F69ED82
local UPDATE_PED_VARIATION = 0xCC8CA3E88256E58F

local function applyShopItem(ped, componentHash, sex)
    local female = sex == 'female'
    Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, ped, componentHash, true, false, female)
    Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, ped, componentHash, true, true, female)
end

local function playerLoaded()
    if GetResourceState('MSCore') ~= 'started' then return false end
    local success, data = pcall(function() return exports.MSCore:GetPlayerData() end)
    return success and type(data) == 'table' and data.characterId ~= nil
end

local function setVisible(visible)
    InventoryOpen = visible == true
    SetNuiFocus(InventoryOpen, InventoryOpen)
    if not InventoryOpen then SendNUIMessage({ action = 'close' }) end
end

local function closeInventory(notifyServer)
    if not InventoryOpen then return end
    setVisible(false)
    if notifyServer ~= false then TriggerServerEvent('ms_inventory:server:close') end
end

local function clothingShopOpen()
    if GetResourceState('MS_ClothingShop') ~= 'started' then return false end
    local success, shopOpen = pcall(function() return exports.MS_ClothingShop:IsShopOpen() end)
    return success and shopOpen == true
end

local function toggleInventory()
    if InventoryOpen then return closeInventory(true) end
    if clothingShopOpen() then
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst den Bekleidungsshop.')
    end
    if playerLoaded() then TriggerServerEvent('ms_inventory:server:open') end
end

RegisterCommand(MSInventoryConfig.Command, toggleInventory, false)
RegisterKeyMapping(
    MSInventoryConfig.Command,
    'Inventar öffnen',
    'keyboard',
    MSInventoryConfig.DefaultKey
)

function IsUiOpen()
    return InventoryOpen
end

exports('IsUiOpen', IsUiOpen)

RegisterNetEvent('ms_inventory:client:open', function(data)
    if type(data) ~= 'table' then return end
    if clothingShopOpen() then
        TriggerServerEvent('ms_inventory:server:close')
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst den Bekleidungsshop.')
    end
    InventoryOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('ms_inventory:client:refresh', function(data)
    if InventoryOpen and type(data) == 'table' then
        SendNUIMessage({ action = 'refresh', data = data })
    end
end)

RegisterNetEvent('ms_inventory:client:result', function(data)
    SendNUIMessage({
        action = 'result',
        success = data and data.success == true,
        message = data and data.message or 'Aktion verarbeitet.'
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeInventory(true)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if InventoryOpen then TriggerServerEvent('ms_inventory:server:refresh') end
    cb({ ok = true })
end)

RegisterNUICallback('give', function(data, cb)
    if not InventoryOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_inventory:server:give', data.item, data.amount, data.target)
    cb({ ok = true })
end)

RegisterNUICallback('discard', function(data, cb)
    if not InventoryOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_inventory:server:discard', data.item, data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('use', function(data, cb)
    if not InventoryOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_inventory:server:use', data.item)
    cb({ ok = true })
end)

RegisterNUICallback('equip', function(data, cb)
    if not InventoryOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_inventory:server:equip', data.item, data.slot)
    cb({ ok = true })
end)

RegisterNUICallback('unequip', function(data, cb)
    if not InventoryOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_inventory:server:unequip', data.slot)
    cb({ ok = true })
end)

local function clearAppliedComponents()
    local ped = PlayerPedId()
    for _, componentHash in pairs(AppliedComponents) do
        Citizen.InvokeNative(REMOVE_SHOP_ITEM_FROM_PED, ped, componentHash, 0, false)
    end
    AppliedComponents = {}
    Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, false, true, true, true, false)
end

RegisterNetEvent('ms_inventory:client:applyOutfit', function(components)
    local ped = PlayerPedId()
    for _, componentHash in pairs(AppliedComponents) do
        Citizen.InvokeNative(REMOVE_SHOP_ITEM_FROM_PED, ped, componentHash, 0, false)
    end
    AppliedComponents = {}

    for _, component in ipairs(type(components) == 'table' and components or {}) do
        local componentHash = tonumber(component.componentHash)
        if componentHash and type(component.slot) == 'string' then
            applyShopItem(ped, componentHash, component.sex)
            AppliedComponents[component.slot] = componentHash
        end
    end
    Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, false, true, true, true, false)
end)

RegisterNetEvent('ms_inventory:client:useEffect', function(effect)
    if type(effect) ~= 'table' or not tonumber(effect.health) then return end
    local ped = PlayerPedId()
    local maximum = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(maximum, GetEntityHealth(ped) + tonumber(effect.health)))
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1500)
    TriggerServerEvent('ms_inventory:server:requestOutfit')
end)

RegisterNetEvent('mscore:client:prepareLogout', function()
    closeInventory(false)
    clearAppliedComponents()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    clearAppliedComponents()
end)
