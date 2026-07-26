local Config = MSMedicConfig
local DiseaseStates = {}
local SourceCharacters = {}
local LastActions = {}
local BusyMedics = {}
local BusyTargets = {}
local ActiveTreatments = {}
local TreatmentSequence = 0
local OpenMenus = {}
local DatabaseReady = false

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_Medic] ' .. message):format(...))
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function notify(playerSource, message)
    if playerSource == 0 then
        print(('[MS_Medic] %s'):format(message))
        return
    end
    TriggerClientEvent('mscore:client:notify', playerSource, message)
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function diseaseDefinition(diseaseKey)
    return type(diseaseKey) == 'string' and Config.Diseases[diseaseKey] or nil
end

local function countEntries(value)
    local count = 0
    for _ in pairs(type(value) == 'table' and value or {}) do count = count + 1 end
    return count
end

local function itemLabel(itemName)
    local item = exports.MSCore:GetItem(itemName)
    return item and item.label or itemName
end

local function itemRequirements(items)
    local rows = {}
    for itemName, amount in pairs(type(items) == 'table' and items or {}) do
        amount = math.max(1, math.floor(tonumber(amount) or 1))
        rows[#rows + 1] = {
            item = itemName,
            label = itemLabel(itemName),
            amount = amount
        }
    end
    table.sort(rows, function(left, right) return left.label < right.label end)
    return rows
end

local function diseaseView(diseaseKey, state)
    local definition = diseaseDefinition(diseaseKey)
    if not definition or type(state) ~= 'table' then return nil end

    local maximum = math.max(1, math.floor(tonumber(definition.maxSeverity) or 1))
    return {
        key = diseaseKey,
        label = tostring(definition.label or diseaseKey),
        description = tostring(definition.description or ''),
        severity = clamp(math.floor(tonumber(state.severity) or 1), 1, maximum),
        maxSeverity = maximum,
        contractedAt = state.contractedAt,
        symptoms = type(definition.symptoms) == 'table' and definition.symptoms or {},
        treatment = {
            label = tostring(definition.treatment and definition.treatment.label or 'Behandeln'),
            durationMs = math.max(500, math.floor(
                tonumber(definition.treatment and definition.treatment.durationMs) or 5000
            )),
            items = itemRequirements(definition.treatment and definition.treatment.items)
        }
    }
end

local function diseaseViewsForCharacter(characterId)
    local rows = {}
    for diseaseKey, state in pairs(DiseaseStates[tonumber(characterId)] or {}) do
        local row = diseaseView(diseaseKey, state)
        if row then rows[#rows + 1] = row end
    end
    table.sort(rows, function(left, right) return left.label < right.label end)
    return rows
end

local function careActionViews()
    local rows = {}
    for actionKey, action in pairs(Config.CareActions or {}) do
        rows[#rows + 1] = {
            key = actionKey,
            label = tostring(action.label or actionKey),
            description = tostring(action.description or ''),
            durationMs = math.max(500, math.floor(tonumber(action.durationMs) or 5000)),
            items = itemRequirements(action.items)
        }
    end
    table.sort(rows, function(left, right) return left.label < right.label end)
    return rows
end

local function syncDiseases(playerSource)
    local player = getPlayer(playerSource)
    if not player then return end

    TriggerClientEvent('ms_medic:client:syncDiseases', playerSource, {
        diseases = diseaseViewsForCharacter(player.characterId)
    })
end

local function persistDisease(characterId, diseaseKey, state)
    if not DatabaseReady then return false end
    MySQL.update.await([[
        INSERT INTO ms_medic_diseases
            (character_id, disease_key, severity, contracted_at)
        VALUES (?, ?, ?, FROM_UNIXTIME(?))
        ON DUPLICATE KEY UPDATE
            severity = VALUES(severity),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        characterId,
        diseaseKey,
        math.max(1, math.floor(tonumber(state.severity) or 1)),
        math.max(1, math.floor(tonumber(state.contractedUnix) or os.time()))
    })
    return true
end

local function deleteDisease(characterId, diseaseKey)
    if not DatabaseReady then return false end
    MySQL.update.await(
        'DELETE FROM ms_medic_diseases WHERE character_id = ? AND disease_key = ?',
        { characterId, diseaseKey }
    )
    return true
end

local function loadDiseases(playerSource, player)
    if not DatabaseReady then return false end
    playerSource = tonumber(playerSource)
    player = player or getPlayer(playerSource)
    if not playerSource or not player then return false end

    local rows = MySQL.query.await([[
        SELECT disease_key, severity, UNIX_TIMESTAMP(contracted_at) AS contracted_unix,
               contracted_at
        FROM ms_medic_diseases
        WHERE character_id = ?
    ]], { player.characterId }) or {}

    local state = {}
    for _, row in ipairs(rows) do
        local definition = diseaseDefinition(row.disease_key)
        if definition then
            local maximum = math.max(1, math.floor(tonumber(definition.maxSeverity) or 1))
            state[row.disease_key] = {
                severity = clamp(math.floor(tonumber(row.severity) or 1), 1, maximum),
                contractedUnix = tonumber(row.contracted_unix) or os.time(),
                contractedAt = tostring(row.contracted_at or '')
            }
        end
    end

    DiseaseStates[player.characterId] = state
    SourceCharacters[playerSource] = player.characterId
    syncDiseases(playerSource)
    debugLog('%d Krankheiten für Charakter %d geladen.', countEntries(state), player.characterId)
    return true
end

local function addDiseaseInternal(playerSource, diseaseKey, severity, announce)
    local player = getPlayer(playerSource)
    local definition = diseaseDefinition(diseaseKey)
    if not player then return false, 'Spieler ohne aktiven Charakter.' end
    if not definition then return false, 'Unbekannte Krankheit.' end

    local state = DiseaseStates[player.characterId] or {}
    DiseaseStates[player.characterId] = state
    if state[diseaseKey] then return false, 'Diese Krankheit ist bereits aktiv.' end

    local maximumActive = math.max(1, math.floor(tonumber(Config.MaxActiveDiseases) or 2))
    if countEntries(state) >= maximumActive then
        return false, 'Die maximale Anzahl aktiver Krankheiten ist erreicht.'
    end

    local maximumSeverity = math.max(1, math.floor(tonumber(definition.maxSeverity) or 1))
    local contractedUnix = os.time()
    local entry = {
        severity = clamp(math.floor(tonumber(severity) or 1), 1, maximumSeverity),
        contractedUnix = contractedUnix,
        contractedAt = os.date('%Y-%m-%d %H:%M:%S', contractedUnix)
    }
    state[diseaseKey] = entry
    persistDisease(player.characterId, diseaseKey, entry)
    syncDiseases(playerSource)

    if announce ~= false then
        notify(playerSource, ('Du bist an %s erkrankt.'):format(definition.label or diseaseKey))
    end
    TriggerEvent('MS_Medic:server:diseaseAdded', playerSource, player.characterId, diseaseKey, entry.severity)
    return true
end

local function removeDiseaseInternal(playerSource, diseaseKey, announce)
    local player = getPlayer(playerSource)
    local definition = diseaseDefinition(diseaseKey)
    if not player then return false, 'Spieler ohne aktiven Charakter.' end
    if not definition then return false, 'Unbekannte Krankheit.' end

    local state = DiseaseStates[player.characterId] or {}
    if not state[diseaseKey] then return false, 'Diese Krankheit ist nicht aktiv.' end

    state[diseaseKey] = nil
    DiseaseStates[player.characterId] = state
    deleteDisease(player.characterId, diseaseKey)
    syncDiseases(playerSource)

    if announce == true then
        notify(playerSource, ('%s wurde erfolgreich behandelt.'):format(definition.label or diseaseKey))
    end
    TriggerEvent('MS_Medic:server:diseaseRemoved', playerSource, player.characterId, diseaseKey)
    return true
end

function GetDiseases(playerSource)
    local player = getPlayer(playerSource)
    return player and diseaseViewsForCharacter(player.characterId) or {}
end

function AddDisease(playerSource, diseaseKey, severity)
    return addDiseaseInternal(tonumber(playerSource), tostring(diseaseKey or ''), severity, true)
end

function RemoveDisease(playerSource, diseaseKey)
    return removeDiseaseInternal(tonumber(playerSource), tostring(diseaseKey or ''), true)
end

function IsMedic(playerSource)
    local player = getPlayer(playerSource)
    if not player then return false end

    local minimumGrade = Config.MedicJobs and Config.MedicJobs[player.job]
    return minimumGrade ~= nil and (tonumber(player.jobGrade) or 0) >= (tonumber(minimumGrade) or 0)
end

local function playerPosition(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    if not coords then return nil end
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function distanceBetween(firstSource, secondSource)
    if GetPlayerRoutingBucket(firstSource) ~= GetPlayerRoutingBucket(secondSource) then
        return math.huge
    end

    local first = playerPosition(firstSource)
    local second = playerPosition(secondSource)
    if not first or not second then return math.huge end

    local x = first.x - second.x
    local y = first.y - second.y
    local z = first.z - second.z
    return math.sqrt(x * x + y * y + z * z)
end

local function healthState(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return 0, true end
    local health = math.max(0, math.floor(tonumber(GetEntityHealth(ped)) or 0))
    return health, health <= 0
end

local function permadeathBlocksRevive(playerSource)
    if GetResourceState('MS_Permadeath') ~= 'started' then return false end
    local success, blocked = pcall(function()
        return exports.MS_Permadeath:IsFinalDeath(playerSource)
    end)
    return success and blocked == true
end

local function patientRow(playerSource)
    local player = getPlayer(playerSource)
    if not player then return nil end
    local health, dead = healthState(playerSource)
    return {
        source = playerSource,
        name = player:getName(),
        health = health,
        dead = dead
    }
end

local function nearbyPatients(medicSource)
    local rows = {}
    local maximumDistance = math.max(1.0, tonumber(Config.SearchDistance) or 8.0)
    for targetSource in pairs(exports.MSCore:GetPlayers()) do
        targetSource = tonumber(targetSource)
        if targetSource and targetSource ~= medicSource
            and distanceBetween(medicSource, targetSource) <= maximumDistance
        then
            local row = patientRow(targetSource)
            if row then rows[#rows + 1] = row end
        end
    end
    table.sort(rows, function(left, right) return left.source < right.source end)
    return rows
end

local function menuPayload(medicSource)
    return {
        medic = {
            source = medicSource,
            name = getPlayer(medicSource):getName()
        },
        patients = nearbyPatients(medicSource),
        careActions = careActionViews(),
        treatmentDistance = tonumber(Config.TreatmentDistance) or 3.0
    }
end

local function sendMenu(medicSource, refresh)
    if not IsMedic(medicSource) then
        notify(medicSource, 'Du hast nicht den benötigten Medic-Job.')
        TriggerClientEvent('ms_medic:client:forceClose', medicSource)
        return false
    end

    OpenMenus[medicSource] = true
    TriggerClientEvent(
        refresh and 'ms_medic:client:refreshMenu' or 'ms_medic:client:openMenu',
        medicSource,
        menuPayload(medicSource)
    )
    return true
end

local function examinationPayload(targetSource)
    local row = patientRow(targetSource)
    local player = getPlayer(targetSource)
    if not row or not player then return nil end
    row.diseases = diseaseViewsForCharacter(player.characterId)
    return row
end

local function actionOnCooldown(playerSource)
    local now = GetGameTimer()
    local cooldown = math.max(0, math.floor(tonumber(Config.ActionCooldownMs) or 1000))
    local last = LastActions[playerSource]
    if last and now - last < cooldown then return true end
    LastActions[playerSource] = now
    return false
end

local function validateTarget(medicSource, targetSource, distance)
    targetSource = tonumber(targetSource)
    if not IsMedic(medicSource) then return nil, 'Du hast nicht den benötigten Medic-Job.' end
    if not targetSource or targetSource == medicSource then return nil, 'Ungültiger Patient.' end
    if not getPlayer(targetSource) then return nil, 'Patient nicht gefunden.' end
    if distanceBetween(medicSource, targetSource) > distance then
        return nil, 'Der Patient ist zu weit entfernt.'
    end
    return targetSource
end

local function requirementsAvailable(player, items)
    local inventory = player:getInventory()
    for itemName, amount in pairs(type(items) == 'table' and items or {}) do
        amount = math.max(1, math.floor(tonumber(amount) or 1))
        if (tonumber(inventory[itemName]) or 0) < amount then
            return false, ('Benötigt: %dx %s.'):format(amount, itemLabel(itemName))
        end
    end
    return true
end

local function consumeRequirements(player, items, reason)
    local removed = {}
    for itemName, amount in pairs(type(items) == 'table' and items or {}) do
        amount = math.max(1, math.floor(tonumber(amount) or 1))
        if not player:removeItem(itemName, amount, reason) then
            for _, rollback in ipairs(removed) do
                player:addItem(rollback.item, rollback.amount, reason .. '_rollback')
            end
            return false
        end
        removed[#removed + 1] = { item = itemName, amount = amount }
    end
    return true
end

local function clearBusy(medicSource, targetSource)
    if BusyMedics[medicSource] == targetSource then
        BusyMedics[medicSource] = nil
        ActiveTreatments[medicSource] = nil
    end
    if BusyTargets[targetSource] == medicSource then BusyTargets[targetSource] = nil end
end

local function treatmentDefinition(actionType, actionKey)
    if actionType == 'care' then
        return Config.CareActions and Config.CareActions[actionKey]
    end
    if actionType == 'disease' then
        local disease = diseaseDefinition(actionKey)
        return disease and disease.treatment
    end
end

local function abortTreatment(medicSource, targetSource, message)
    clearBusy(medicSource, targetSource)
    if not getPlayer(medicSource) then return end

    notify(medicSource, message)
    TriggerClientEvent('ms_medic:client:treatmentFinished', medicSource, {
        success = false,
        message = message
    })
end

local function completeTreatment(medicSource, targetSource, actionType, actionKey, treatmentId)
    if ActiveTreatments[medicSource] ~= treatmentId then return end

    local medic = getPlayer(medicSource)
    local target = getPlayer(targetSource)
    local action = treatmentDefinition(actionType, actionKey)
    local maximumDistance = math.max(0.5, tonumber(Config.TreatmentDistance) or 3.0)

    if not medic or not target or not action or not IsMedic(medicSource)
        or distanceBetween(medicSource, targetSource) > maximumDistance
    then
        abortTreatment(medicSource, targetSource, 'Die Behandlung wurde abgebrochen.')
        return
    end

    local health, dead = healthState(targetSource)
    if (actionType == 'care' and actionKey == 'revive' and not dead)
        or (actionType ~= 'care' or actionKey ~= 'revive') and dead
    then
        abortTreatment(medicSource, targetSource, 'Der Zustand des Patienten hat sich verändert.')
        return
    end
    if actionType == 'care' and actionKey == 'revive' and permadeathBlocksRevive(targetSource) then
        abortTreatment(medicSource, targetSource, 'Dieser Charakter befindet sich im permanenten Tod.')
        return
    end

    if actionType == 'disease' then
        local state = DiseaseStates[target.characterId] or {}
        if not state[actionKey] then
            abortTreatment(medicSource, targetSource, 'Die Krankheit ist nicht mehr aktiv.')
            return
        end
    end

    local available, itemError = requirementsAvailable(medic, action.items)
    if not available then
        abortTreatment(medicSource, targetSource, itemError)
        return
    end

    if not consumeRequirements(medic, action.items, ('medic:%s:%s'):format(actionType, actionKey)) then
        abortTreatment(
            medicSource,
            targetSource,
            'Die benötigten Gegenstände konnten nicht verbraucht werden.'
        )
        return
    end

    local resultMessage
    if actionType == 'care' and actionKey == 'stabilize' then
        local newHealth = clamp(
            math.max(1, health) + math.max(1, math.floor(tonumber(action.healAmount) or 60)),
            1,
            200
        )
        target:setMetadata('health', newHealth)
        TriggerClientEvent('ms_medic:client:restoreHealth', targetSource, false, newHealth)
        notify(targetSource, ('Du wurdest von %s medizinisch versorgt.'):format(medic:getName()))
        resultMessage = ('%s wurde medizinisch versorgt.'):format(target:getName())
    elseif actionType == 'care' and actionKey == 'revive' then
        local newHealth = clamp(math.floor(tonumber(action.reviveHealth) or 100), 1, 200)
        target:setMetadata('health', newHealth)
        TriggerClientEvent('ms_medic:client:restoreHealth', targetSource, true, newHealth)
        notify(targetSource, ('Du wurdest von %s wiederbelebt.'):format(medic:getName()))
        resultMessage = ('%s wurde wiederbelebt.'):format(target:getName())
    elseif actionType == 'disease' then
        local disease = diseaseDefinition(actionKey)
        local successChance = clamp(tonumber(action.successChance) or 1.0, 0.0, 1.0)
        if math.random() <= successChance then
            removeDiseaseInternal(targetSource, actionKey, true)
            resultMessage = ('%s wurde von %s geheilt.'):format(
                target:getName(),
                disease.label or actionKey
            )
        else
            local state = DiseaseStates[target.characterId][actionKey]
            if state.severity > 1 then
                state.severity = state.severity - 1
                persistDisease(target.characterId, actionKey, state)
                syncDiseases(targetSource)
            end
            notify(targetSource, 'Die Behandlung hat die Beschwerden nur gelindert.')
            resultMessage = ('Die Behandlung von %s war nur teilweise erfolgreich.'):format(
                disease.label or actionKey
            )
        end
    end

    medic:save()
    target:save()
    clearBusy(medicSource, targetSource)
    notify(medicSource, resultMessage or 'Behandlung abgeschlossen.')
    TriggerClientEvent('ms_medic:client:treatmentFinished', medicSource, {
        success = true,
        message = resultMessage or 'Behandlung abgeschlossen.',
        patient = examinationPayload(targetSource)
    })
    TriggerEvent('MS_Medic:server:treatmentCompleted', {
        medicSource = medicSource,
        medicCharacterId = medic.characterId,
        targetSource = targetSource,
        targetCharacterId = target.characterId,
        actionType = actionType,
        actionKey = actionKey
    })
    if OpenMenus[medicSource] then sendMenu(medicSource, true) end
end

RegisterNetEvent('ms_medic:server:openMenu', function()
    sendMenu(source, OpenMenus[source] == true)
end)

RegisterNetEvent('ms_medic:server:closeMenu', function()
    OpenMenus[source] = nil
end)

RegisterNetEvent('ms_medic:server:examine', function(rawTarget)
    local medicSource = source
    if actionOnCooldown(medicSource) then return end
    local targetSource, targetError = validateTarget(
        medicSource,
        rawTarget,
        math.max(0.5, tonumber(Config.TreatmentDistance) or 3.0)
    )
    if not targetSource then return notify(medicSource, targetError) end

    TriggerClientEvent(
        'ms_medic:client:examination',
        medicSource,
        examinationPayload(targetSource)
    )
end)

RegisterNetEvent('ms_medic:server:treat', function(rawTarget, actionType, actionKey)
    local medicSource = source
    if actionOnCooldown(medicSource) then
        return notify(medicSource, 'Bitte warte einen Moment.')
    end
    if BusyMedics[medicSource] then return notify(medicSource, 'Du behandelst bereits einen Patienten.') end

    local targetSource, targetError = validateTarget(
        medicSource,
        rawTarget,
        math.max(0.5, tonumber(Config.TreatmentDistance) or 3.0)
    )
    if not targetSource then return notify(medicSource, targetError) end
    if BusyTargets[targetSource] then return notify(medicSource, 'Dieser Patient wird bereits behandelt.') end

    actionType = tostring(actionType or '')
    actionKey = tostring(actionKey or '')
    if actionType ~= 'care' and actionType ~= 'disease' then
        return notify(medicSource, 'Ungültige Behandlungsart.')
    end

    local action = treatmentDefinition(actionType, actionKey)
    if not action then return notify(medicSource, 'Unbekannte Behandlung.') end

    local target = getPlayer(targetSource)
    local health, dead = healthState(targetSource)
    if actionType == 'care' and actionKey == 'revive' then
        if not dead then return notify(medicSource, 'Der Patient ist nicht verstorben.') end
        if permadeathBlocksRevive(targetSource) then
            return notify(medicSource, 'Dieser Charakter kann nicht mehr wiederbelebt werden.')
        end
    elseif dead then
        return notify(medicSource, 'Ein verstorbener Patient muss zuerst wiederbelebt werden.')
    end

    if actionType == 'disease' then
        local state = DiseaseStates[target.characterId] or {}
        if not state[actionKey] then return notify(medicSource, 'Diese Krankheit ist nicht aktiv.') end
    end

    local medic = getPlayer(medicSource)
    local available, itemError = requirementsAvailable(medic, action.items)
    if not available then return notify(medicSource, itemError) end

    local duration = math.max(500, math.floor(tonumber(action.durationMs) or 5000))
    TreatmentSequence = TreatmentSequence + 1
    if TreatmentSequence > 2147483647 then TreatmentSequence = 1 end
    local treatmentId = TreatmentSequence
    BusyMedics[medicSource] = targetSource
    BusyTargets[targetSource] = medicSource
    ActiveTreatments[medicSource] = treatmentId
    OpenMenus[medicSource] = nil
    TriggerClientEvent('ms_medic:client:startTreatment', medicSource, {
        label = tostring(action.label or 'Behandlung'),
        patientName = target:getName(),
        durationMs = duration
    })
    notify(targetSource, ('%s beginnt eine Behandlung.'):format(medic:getName()))

    SetTimeout(duration, function()
        completeTreatment(medicSource, targetSource, actionType, actionKey, treatmentId)
    end)
end)

RegisterCommand(Config.HealthCommand or 'healthstatus', function(playerSource)
    if playerSource == 0 then return notify(playerSource, 'Dieser Befehl ist nur ingame verfügbar.') end
    local player = getPlayer(playerSource)
    if not player then return notify(playerSource, 'Wähle zuerst einen Charakter.') end

    local health, dead = healthState(playerSource)
    TriggerClientEvent('ms_medic:client:openHealthStatus', playerSource, {
        patient = {
            source = playerSource,
            name = player:getName(),
            health = health,
            dead = dead,
            diseases = diseaseViewsForCharacter(player.characterId)
        }
    })
end, false)

local function adminAllowed(playerSource)
    return playerSource == 0
        or IsPlayerAceAllowed(playerSource, tostring(Config.AdminAce or 'mscore.admin'))
end

RegisterCommand(Config.AdminDiseaseCommand or 'medicdisease', function(playerSource, args)
    if not adminAllowed(playerSource) then return notify(playerSource, 'Keine Berechtigung.') end

    local targetSource = tonumber(args[1])
    local action = tostring(args[2] or ''):lower()
    local diseaseKey = tostring(args[3] or '')
    if not targetSource or not getPlayer(targetSource) then
        return notify(playerSource, 'Verwendung: medicdisease <Server-ID> <add|remove|clear|list> [Krankheit] [Schweregrad]')
    end

    if action == 'list' then
        local diseases = GetDiseases(targetSource)
        local labels = {}
        for _, disease in ipairs(diseases) do
            labels[#labels + 1] = ('%s (Stufe %d)'):format(disease.label, disease.severity)
        end
        return notify(playerSource, #labels > 0 and table.concat(labels, ', ') or 'Keine aktive Krankheit.')
    end

    if action == 'clear' then
        local player = getPlayer(targetSource)
        local state = DiseaseStates[player.characterId] or {}
        local keys = {}
        for key in pairs(state) do keys[#keys + 1] = key end
        for _, key in ipairs(keys) do removeDiseaseInternal(targetSource, key, false) end
        notify(targetSource, 'Alle Krankheiten wurden administrativ entfernt.')
        return notify(playerSource, 'Alle Krankheiten wurden entfernt.')
    end

    local success, message
    if action == 'add' then
        success, message = addDiseaseInternal(targetSource, diseaseKey, tonumber(args[4]), true)
    elseif action == 'remove' then
        success, message = removeDiseaseInternal(targetSource, diseaseKey, true)
    else
        return notify(playerSource, 'Verwendung: medicdisease <Server-ID> <add|remove|clear|list> [Krankheit] [Schweregrad]')
    end

    notify(playerSource, success and 'Krankheitsstatus geändert.' or message)
end, false)

AddEventHandler('mscore:server:playerLoaded', function(playerSource, player)
    if DatabaseReady then
        loadDiseases(playerSource, player)
    else
        SetTimeout(1000, function()
            if DatabaseReady then loadDiseases(playerSource, getPlayer(playerSource)) end
        end)
    end
end)

local function clearPlayerState(playerSource, player)
    playerSource = tonumber(playerSource)
    local characterId = player and player.characterId or SourceCharacters[playerSource]
    if characterId then DiseaseStates[characterId] = nil end
    SourceCharacters[playerSource] = nil
    LastActions[playerSource] = nil
    OpenMenus[playerSource] = nil

    local targetSource = BusyMedics[playerSource]
    if targetSource then clearBusy(playerSource, targetSource) end
    local medicSource = BusyTargets[playerSource]
    if medicSource then clearBusy(medicSource, playerSource) end
end

AddEventHandler('mscore:server:playerUnloaded', clearPlayerState)
AddEventHandler('playerDropped', function()
    clearPlayerState(source, nil)
end)

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_medic_diseases (
            character_id BIGINT UNSIGNED NOT NULL,
            disease_key VARCHAR(64) NOT NULL,
            severity TINYINT UNSIGNED NOT NULL DEFAULT 1,
            contracted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (character_id, disease_key),
            KEY idx_ms_medic_diseases_key (disease_key),
            CONSTRAINT fk_ms_medic_diseases_character
                FOREIGN KEY (character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    DatabaseReady = true

    for playerSource, player in pairs(exports.MSCore:GetPlayers()) do
        loadDiseases(tonumber(playerSource), player)
    end
    debugLog('Datenbank bereit.')
end)

CreateThread(function()
    Wait(math.max(10000, math.floor(tonumber(Config.InitialRollDelayMs) or 120000)))
    while true do
        for playerSource, player in pairs(exports.MSCore:GetPlayers()) do
            playerSource = tonumber(playerSource)
            local state = DiseaseStates[player.characterId] or {}
            DiseaseStates[player.characterId] = state
            local changed = false

            for diseaseKey, entry in pairs(state) do
                local definition = diseaseDefinition(diseaseKey)
                if definition then
                    local maximum = math.max(1, math.floor(tonumber(definition.maxSeverity) or 1))
                    local chance = clamp(tonumber(definition.progressionChance) or 0.0, 0.0, 1.0)
                    if entry.severity < maximum and math.random() <= chance then
                        entry.severity = entry.severity + 1
                        persistDisease(player.characterId, diseaseKey, entry)
                        notify(playerSource, ('%s hat sich verschlimmert.'):format(definition.label or diseaseKey))
                        changed = true
                    end
                end
            end

            local maximumActive = math.max(1, math.floor(tonumber(Config.MaxActiveDiseases) or 2))
            if countEntries(state) < maximumActive then
                for diseaseKey, definition in pairs(Config.Diseases or {}) do
                    if not state[diseaseKey] and countEntries(state) < maximumActive then
                        local chance = clamp(tonumber(definition.chance) or 0.0, 0.0, 1.0)
                        if math.random() <= chance then
                            addDiseaseInternal(playerSource, diseaseKey, 1, true)
                            changed = true
                        end
                    end
                end
            end

            if changed then syncDiseases(playerSource) end
        end
        Wait(math.max(10000, math.floor(tonumber(Config.DiseaseRollIntervalMs) or 600000)))
    end
end)

CreateThread(function()
    while true do
        Wait(math.max(10000, math.floor(tonumber(Config.SymptomIntervalMs) or 60000)))
        for playerSource, player in pairs(exports.MSCore:GetPlayers()) do
            playerSource = tonumber(playerSource)
            local state = DiseaseStates[player.characterId] or {}
            local totalDrain = 0
            local messages = {}

            for diseaseKey, entry in pairs(state) do
                local definition = diseaseDefinition(diseaseKey)
                if definition then
                    totalDrain = totalDrain
                        + math.max(0, tonumber(definition.healthDrainPerSeverity) or 0)
                        * math.max(1, tonumber(entry.severity) or 1)
                    if type(definition.messages) == 'table' and #definition.messages > 0 then
                        messages[#messages + 1] = definition.messages[math.random(1, #definition.messages)]
                    end
                end
            end

            if totalDrain > 0 then
                local health, dead = healthState(playerSource)
                if not dead then
                    local minimum = Config.DiseasesCanKill == true
                        and 0
                        or math.max(1, math.floor(tonumber(Config.MinimumDiseaseHealth) or 25))
                    local newHealth = health > minimum
                        and math.max(minimum, health - math.floor(totalDrain))
                        or health
                    if newHealth ~= health or #messages > 0 then
                        player:setMetadata('health', newHealth)
                        TriggerClientEvent('ms_medic:client:applySymptoms', playerSource, {
                            health = newHealth,
                            message = #messages > 0 and messages[math.random(1, #messages)] or nil
                        })
                    end
                end
            end
        end
    end
end)

exports('GetDiseases', GetDiseases)
exports('AddDisease', AddDisease)
exports('RemoveDisease', RemoveDisease)
exports('IsMedic', IsMedic)
