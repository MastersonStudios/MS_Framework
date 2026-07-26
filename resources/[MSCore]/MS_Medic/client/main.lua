local Config = MSMedicConfig
local RESURRECT_PED = 0x71BC8E838B9C6035
local INPUT_SPRINT = 0x8FFC75D6
local MenuOpen = false
local DiseaseCache = {}
local FractureMoveEffectActive = false
local FractureMoveEffectMethod = nil
local FracturePainUntil = 0
local NextFracturePainAt = 0

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function fractureEffect()
    local definition = type(Config.Diseases) == 'table' and Config.Diseases.bone_fracture or nil
    local settings = type(definition) == 'table' and definition.effects or nil
    if type(settings) ~= 'table' then return nil end

    for _, disease in ipairs(DiseaseCache) do
        if disease.key == 'bone_fracture' then
            local severity = math.max(1, math.floor(tonumber(disease.severity) or 1))
            local baseMultiplier = clamp(tonumber(settings.movementMultiplier) or 0.78, 0.1, 1.0)
            local penalty = math.max(0.0, tonumber(settings.movementPenaltyPerSeverity) or 0.0)
            local minimum = clamp(tonumber(settings.minimumMovementMultiplier) or 0.5, 0.1, 1.0)

            return {
                severity = severity,
                movementMultiplier = clamp(baseMultiplier - ((severity - 1) * penalty), minimum, 1.0),
                disableSprint = settings.disableSprint ~= false,
                painIntervalMs = math.max(5000, math.floor(tonumber(settings.painIntervalMs) or 30000)),
                painChance = clamp(tonumber(settings.painChance) or 0.65, 0.0, 1.0),
                painDurationMs = math.max(500, math.floor(tonumber(settings.painDurationMs) or 2500)),
                painMovementMultiplier = clamp(tonumber(settings.painMovementMultiplier) or 0.6, 0.1, 1.0),
                painMessages = type(settings.painMessages) == 'table' and settings.painMessages or {}
            }
        end
    end

    return nil
end

local function setMoveRate(ped, multiplier)
    if type(SetPedMoveRateOverride) == 'function' then
        SetPedMoveRateOverride(ped, multiplier)
        return 'rate'
    end

    if type(SetPedMaxMoveBlendRatio) == 'function' then
        SetPedMaxMoveBlendRatio(ped, multiplier)
        return 'blend'
    end

    return nil
end

local function restoreMoveRate(ped)
    if FractureMoveEffectMethod == 'rate' and type(SetPedMoveRateOverride) == 'function' then
        SetPedMoveRateOverride(ped, 1.0)
    elseif FractureMoveEffectMethod == 'blend' and type(SetPedMaxMoveBlendRatio) == 'function' then
        SetPedMaxMoveBlendRatio(ped, 3.0)
    end
end

local function resetFractureEffect()
    if FractureMoveEffectActive then
        restoreMoveRate(PlayerPedId())
    end
    FractureMoveEffectActive = false
    FractureMoveEffectMethod = nil
    FracturePainUntil = 0
    NextFracturePainAt = 0
end

local function canApplyFractureMovement(ped)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    if type(IsPedInAnyVehicle) == 'function' and IsPedInAnyVehicle(ped, false) then return false end
    if type(IsPedOnMount) == 'function' and IsPedOnMount(ped) then return false end
    return true
end

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
    if revive == true and IsEntityDead(ped) then
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

CreateThread(function()
    while true do
        local effect = fractureEffect()
        local ped = PlayerPedId()

        if effect and canApplyFractureMovement(ped) then
            local multiplier = effect.movementMultiplier
            if GetGameTimer() < FracturePainUntil then
                multiplier = multiplier * effect.painMovementMultiplier
            end

            FractureMoveEffectMethod = setMoveRate(ped, clamp(multiplier, 0.1, 1.0))
            FractureMoveEffectActive = FractureMoveEffectMethod ~= nil
            if effect.disableSprint then
                DisableControlAction(0, INPUT_SPRINT, true)
            end
            Wait(0)
        else
            if FractureMoveEffectActive then
                restoreMoveRate(ped)
                FractureMoveEffectActive = false
                FractureMoveEffectMethod = nil
            end
            Wait(effect and 200 or 500)
        end
    end
end)

CreateThread(function()
    while true do
        local effect = fractureEffect()
        if not effect then
            FracturePainUntil = 0
            NextFracturePainAt = 0
            Wait(1000)
        else
            local now = GetGameTimer()
            if NextFracturePainAt == 0 then
                NextFracturePainAt = now + effect.painIntervalMs
            elseif now >= NextFracturePainAt then
                NextFracturePainAt = now + effect.painIntervalMs
                local ped = PlayerPedId()

                if not IsEntityDead(ped) and math.random() <= effect.painChance then
                    FracturePainUntil = now + effect.painDurationMs
                    if #effect.painMessages > 0 then
                        TriggerEvent(
                            'mscore:client:notify',
                            effect.painMessages[math.random(1, #effect.painMessages)]
                        )
                    end
                end
            end
            Wait(250)
        end
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
    resetFractureEffect()
    closeMenu(true)
    SendNUIMessage({ action = 'reset' })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    resetFractureEffect()
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
