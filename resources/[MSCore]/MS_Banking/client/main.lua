local PlatformRegisterKeyMapping = RegisterKeyMapping
local RegisterKeyMapping = type(PlatformRegisterKeyMapping) == 'function'
    and PlatformRegisterKeyMapping
    or function(...) return exports.MSCore:RegisterKeyMappingCompat(...) end

local BankerEntities = {}
local BankerLoading = {}
local BankerFailures = {}
local NearestBanker = nil
local LastPromptBanker = false
local BankOpen = false

local TASK_START_SCENARIO = 0x524B54361229154F
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE

local function distance(coords, point)
    local dx = coords.x - (tonumber(point.x) or 0.0)
    local dy = coords.y - (tonumber(point.y) or 0.0)
    local dz = coords.z - (tonumber(point.z) or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local expires = GetGameTimer() + MSBankingConfig.ModelLoadTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function deleteEntitySafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function deleteBanker(bankerId)
    deleteEntitySafe(BankerEntities[bankerId])
    BankerEntities[bankerId] = nil
end

local function spawnBanker(bankerId, banker)
    if BankerEntities[bankerId] or BankerLoading[bankerId] or BankerFailures[bankerId] then return end
    BankerLoading[bankerId] = true

    CreateThread(function()
        local npc = banker.npc
        local hash = loadModel(npc.model)
        if not hash then
            BankerLoading[bankerId] = nil
            BankerFailures[bankerId] = true
            return print(('[MS_Banking] NPC-Modell "%s" konnte nicht geladen werden.'):format(
                tostring(npc.model)
            ))
        end

        local ped = CreatePed(
            hash,
            npc.x,
            npc.y,
            npc.z,
            npc.heading or 0.0,
            false,
            false,
            false,
            false
        )
        SetModelAsNoLongerNeeded(hash)
        if not DoesEntityExist(ped) then
            BankerLoading[bankerId] = nil
            BankerFailures[bankerId] = true
            return
        end

        Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
        SetEntityAsMissionEntity(ped, true, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        FreezeEntityPosition(ped, true)
        if npc.scenario and npc.scenario ~= '' then
            Citizen.InvokeNative(
                TASK_START_SCENARIO,
                ped,
                GetHashKey(npc.scenario),
                -1,
                true,
                false,
                false,
                1.0,
                false
            )
        end

        BankerEntities[bankerId] = ped
        BankerLoading[bankerId] = nil
    end)
end

local function conflictingUiIsOpen()
    if GetResourceState('MS_Inventory') == 'started' then
        local success, open = pcall(function() return exports.MS_Inventory:IsUiOpen() end)
        if success and open == true then return true end
    end
    if GetResourceState('MS_ClothingShop') == 'started' then
        local success, open = pcall(function() return exports.MS_ClothingShop:IsShopOpen() end)
        if success and open == true then return true end
    end
    if GetResourceState('MS_Telegrams') == 'started' then
        local success, open = pcall(function() return exports.MS_Telegrams:IsTelegramOpen() end)
        if success and open == true then return true end
    end
    if GetResourceState('MS_AdminMenu') == 'started' then
        local success, open = pcall(function() return exports.MS_AdminMenu:IsUiOpen() end)
        if success and open == true then return true end
    end
    if GetResourceState('MS_BossMenu') == 'started' then
        local success, open = pcall(function() return exports.MS_BossMenu:IsBossMenuOpen() end)
        if success and open == true then return true end
    end
    return false
end

local function closeBank(notifyServer)
    if not BankOpen then return end
    BankOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if notifyServer ~= false then TriggerServerEvent('ms_banking:server:close') end
end

local function openNearestBank()
    if BankOpen then return closeBank(true) end
    if conflictingUiIsOpen() then
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst das andere Menü.')
    end
    if not NearestBanker then
        return TriggerEvent('mscore:client:notify', 'Du bist bei keinem Banker.')
    end
    TriggerServerEvent('ms_banking:server:open', NearestBanker)
end

RegisterCommand(MSBankingConfig.Command, openNearestBank, false)
RegisterCommand('+ms_banking_interact', function()
    if not BankOpen and NearestBanker and not conflictingUiIsOpen() then
        TriggerServerEvent('ms_banking:server:open', NearestBanker)
    end
end, false)
RegisterCommand('-ms_banking_interact', function() end, false)
RegisterKeyMapping(
    '+ms_banking_interact',
    'Bank benutzen',
    'keyboard',
    MSBankingConfig.InteractionKey
)

function IsBankOpen()
    return BankOpen
end

exports('IsBankOpen', IsBankOpen)

RegisterNetEvent('ms_banking:client:open', function(data)
    if type(data) ~= 'table' or BankOpen then return end
    if conflictingUiIsOpen() then
        TriggerServerEvent('ms_banking:server:close')
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst das andere Menü.')
    end
    BankOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('ms_banking:client:refresh', function(data)
    if BankOpen and type(data) == 'table' then
        SendNUIMessage({ action = 'refresh', data = data })
    end
end)

RegisterNetEvent('ms_banking:client:result', function(data)
    local message = data and data.message or 'Bankauftrag verarbeitet.'
    if BankOpen then
        SendNUIMessage({
            action = 'result',
            success = data and data.success == true,
            message = message
        })
    else
        TriggerEvent('mscore:client:notify', message)
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeBank(true)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if BankOpen then TriggerServerEvent('ms_banking:server:refresh') end
    cb({ ok = true })
end)

RegisterNUICallback('deposit', function(data, cb)
    if not BankOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_banking:server:deposit', data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('withdraw', function(data, cb)
    if not BankOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_banking:server:withdraw', data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('companyDeposit', function(data, cb)
    if not BankOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_banking:server:companyDeposit', data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('companyWithdraw', function(data, cb)
    if not BankOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_banking:server:companyWithdraw', data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('transfer', function(data, cb)
    if not BankOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_banking:server:transfer', data.accountNumber, data.amount)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for bankerId, banker in pairs(MSBankingConfig.Bankers) do
            local bankerDistance = distance(coords, banker.npc)
            if bankerDistance <= MSBankingConfig.BankerStreamDistance then
                spawnBanker(bankerId, banker)
            elseif bankerDistance > MSBankingConfig.BankerDespawnDistance then
                deleteBanker(bankerId)
                BankerFailures[bankerId] = nil
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        if BankOpen then
            NearestBanker = nil
            if LastPromptBanker ~= false then
                SendNUIMessage({ action = 'prompt', visible = false })
                LastPromptBanker = false
            end
            Wait(250)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for bankerId, banker in pairs(MSBankingConfig.Bankers) do
                local currentDistance = distance(coords, banker.npc)
                if currentDistance <= MSBankingConfig.InteractionDistance
                    and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = bankerId
                    nearestDistance = currentDistance
                end
            end

            NearestBanker = nearest
            if LastPromptBanker ~= nearest then
                SendNUIMessage({
                    action = 'prompt',
                    visible = nearest ~= nil,
                    key = MSBankingConfig.InteractionKey,
                    label = nearest and MSBankingConfig.Bankers[nearest].label or nil
                })
                LastPromptBanker = nearest or false
            end
            Wait(nearest and 100 or 350)
        end
    end
end)

RegisterNetEvent('mscore:client:prepareLogout', function()
    closeBank(false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    for bankerId in pairs(BankerEntities) do deleteBanker(bankerId) end
end)
