local Config = MSMedicConfig
local RESURRECT_PED = 0x71BC8E838B9C6035
local MenuOpen = false
local DiseaseCache = {}

local function playerLoaded()
    local playerData = exports.MSCore:GetPlayerData()
    return type(playerData) == 'table' and tonumber(playerData.characterId) ~= nil
end

local function closeMenu(tellServer)
    if not MenuOpen then return end
    MenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if tellServer ~= false then TriggerServerEvent('ms_medic:server:closeMenu') end
end

local function openMedicMenu()
    if not playerLoaded() then
        return TriggerEvent('mscore:client:notify', 'Wähle zuerst einen Charakter.')
    end
    if MenuOpen then return closeMenu(true) end
    TriggerServerEvent('ms_medic:server:openMenu')
end

RegisterCommand(Config.MedicCommand or 'medic', openMedicMenu, false)
RegisterKeyMapping(
    Config.MedicCommand or 'medic',
    'MS Medic öffnen',
    'keyboard',
    Config.DefaultKey or 'F6'
)

RegisterNetEvent('ms_medic:client:openMenu', function(payload)
    if type(payload) ~= 'table' then return end
    MenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMedic', payload = payload })
end)

RegisterNetEvent('ms_medic:client:refreshMenu', function(payload)
    if not MenuOpen or type(payload) ~= 'table' then return end
    SendNUIMessage({ action = 'refreshMedic', payload = payload })
end)

RegisterNetEvent('ms_medic:client:openHealthStatus', function(payload)
    if type(payload) ~= 'table' then return end
    MenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openHealth', payload = payload })
end)

RegisterNetEvent('ms_medic:client:examination', function(patient)
    if not MenuOpen or type(patient) ~= 'table' then return end
    SendNUIMessage({ action = 'examination', patient = patient })
end)

RegisterNetEvent('ms_medic:client:startTreatment', function(data)
    MenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'treatmentProgress', payload = data or {} })
end)

RegisterNetEvent('ms_medic:client:treatmentFinished', function(data)
    SendNUIMessage({ action = 'treatmentFinished', payload = data or {} })
end)

RegisterNetEvent('ms_medic:client:forceClose', function()
    closeMenu(false)
end)

RegisterNetEvent('ms_medic:client:syncDiseases', function(payload)
    DiseaseCache = type(payload) == 'table' and type(payload.diseases) == 'table'
        and payload.diseases
        or {}
    TriggerEvent('MS_Medic:client:diseasesChanged', DiseaseCache)
end)

RegisterNetEvent('ms_medic:client:restoreHealth', function(revive, rawHealth)
    local ped = PlayerPedId()
    local health = math.max(1, math.min(200, math.floor(tonumber(rawHealth) or 100)))
    if revive == true then
        Citizen.InvokeNative(RESURRECT_PED, ped)
        ClearPedTasksImmediately(ped)
    end
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, health)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('ms_medic:client:applySymptoms', function(data)
    if type(data) ~= 'table' then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    local health = tonumber(data.health)
    if health then SetEntityHealth(ped, math.max(0, math.min(200, math.floor(health)))) end
    if type(data.message) == 'string' and data.message ~= '' then
        TriggerEvent('mscore:client:notify', data.message)
    end
end)

RegisterNUICallback('close', function(_, callback)
    closeMenu(true)
    callback({ ok = true })
end)

RegisterNUICallback('refresh', function(_, callback)
    if MenuOpen then TriggerServerEvent('ms_medic:server:openMenu') end
    callback({ ok = MenuOpen })
end)

RegisterNUICallback('examine', function(data, callback)
    local target = type(data) == 'table' and tonumber(data.target)
    if MenuOpen and target then TriggerServerEvent('ms_medic:server:examine', target) end
    callback({ ok = MenuOpen and target ~= nil })
end)

RegisterNUICallback('treat', function(data, callback)
    local target = type(data) == 'table' and tonumber(data.target)
    local actionType = type(data) == 'table' and tostring(data.actionType or '') or ''
    local actionKey = type(data) == 'table' and tostring(data.actionKey or '') or ''
    if MenuOpen and target and actionType ~= '' and actionKey ~= '' then
        TriggerServerEvent('ms_medic:server:treat', target, actionType, actionKey)
    end
    callback({ ok = MenuOpen and target ~= nil and actionType ~= '' and actionKey ~= '' })
end)

CreateThread(function()
    TriggerEvent(
        'chat:addSuggestion',
        '/' .. tostring(Config.MedicCommand or 'medic'),
        'Öffnet das Behandlungsmenü für Medics.'
    )
    TriggerEvent(
        'chat:addSuggestion',
        '/' .. tostring(Config.HealthCommand or 'healthstatus'),
        'Zeigt den eigenen Gesundheits- und Krankheitsstatus.'
    )
end)

AddEventHandler('mscore:client:prepareLogout', function()
    DiseaseCache = {}
    closeMenu(true)
    SendNUIMessage({ action = 'reset' })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeMenu(true)
    TriggerEvent('chat:removeSuggestion', '/' .. tostring(Config.MedicCommand or 'medic'))
    TriggerEvent('chat:removeSuggestion', '/' .. tostring(Config.HealthCommand or 'healthstatus'))
end)

function GetDiseases()
    return DiseaseCache
end

function HasDisease(diseaseKey)
    diseaseKey = tostring(diseaseKey or '')
    for _, disease in ipairs(DiseaseCache) do
        if disease.key == diseaseKey then return true, disease end
    end
    return false
end

function IsMedicMenuOpen()
    return MenuOpen
end

exports('GetDiseases', GetDiseases)
exports('HasDisease', HasDisease)
exports('IsMedicMenuOpen', IsMedicMenuOpen)
