local Config = MSCrimeConfig
local ActiveSearches = {}
local TargetSearches = {}
local RestraintStates = {}
local LastActions = {}
local SearchSequence = 0
local clearSearch

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_Crime] ' .. message):format(...))
end

local function notify(playerSource, message)
    TriggerClientEvent('mscore:client:notify', playerSource, message)
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function isCrimePlayer(player)
    return player and player.job == tostring(Config.JobName or 'crime')
end

local function distanceBetween(firstSource, secondSource)
    local firstPed = GetPlayerPed(firstSource)
    local secondPed = GetPlayerPed(secondSource)
    if not firstPed or firstPed == 0 or not secondPed or secondPed == 0 then return math.huge end

    local first = GetEntityCoords(firstPed)
    local second = GetEntityCoords(secondPed)
    if not first or not second then return math.huge end

    local dx = first.x - second.x
    local dy = first.y - second.y
    local dz = first.z - second.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function actionAmount(value)
    value = tonumber(value)
    local maximum = math.max(1, math.floor(tonumber(Config.MaxRobAmount) or 100))
    if not value or value % 1 ~= 0 or value < 1 or value > maximum then return nil end
    return math.floor(value)
end

local function onCooldown(playerSource, action)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local cooldown = math.max(0, math.floor(tonumber(Config.ActionCooldownMs) or 500))
    local last = LastActions[key]
    if last and now - last < cooldown then return true end
    LastActions[key] = now
    return false
end

function IsRestrained(playerSource)
    playerSource = tonumber(playerSource)
    local state = playerSource and RestraintStates[playerSource]
    if not state then return false end
    if state.external ~= nil then return state.external == true end

    local maximumAge = math.max(
        500,
        math.floor(tonumber(Config.RestraintStateMaxAgeMs) or 2500)
    )
    return state.client == true
        and state.clientUpdatedAt ~= nil
        and GetGameTimer() - state.clientUpdatedAt <= maximumAge
end

function SetRestrained(playerSource, restrained)
    playerSource = tonumber(playerSource)
    if not playerSource or not getPlayer(playerSource) then return false end

    local state = RestraintStates[playerSource] or {}
    if restrained == nil then
        state.external = nil
    else
        state.external = restrained == true
    end
    RestraintStates[playerSource] = state
    if not IsRestrained(playerSource) then
        local robberSource = TargetSearches[playerSource]
        if robberSource then clearSearch(robberSource, 'Die Person ist nicht mehr gefesselt.', true) end
    end
    return true
end

local function itemView(item, amount)
    return {
        name = item.name,
        label = item.label,
        description = item.description,
        category = item.category,
        rarity = item.rarity,
        amount = math.max(0, math.floor(tonumber(amount) or 0)),
        weight = math.max(0, tonumber(item.weight) or 0),
        tradable = item.tradable == true,
        image = item.image
    }
end

local function lootPayload(session)
    local target = getPlayer(session.targetSource)
    if not target then return nil end

    local items = {}
    for itemName, rawAmount in pairs(target:getInventory()) do
        local amount = math.max(0, math.floor(tonumber(rawAmount) or 0))
        local item = amount > 0 and exports.MSCore:GetItem(itemName)
        if item then items[#items + 1] = itemView(item, amount) end
    end
    table.sort(items, function(left, right)
        if left.label == right.label then return left.name < right.name end
        return left.label < right.label
    end)

    return {
        target = {
            source = session.targetSource,
            name = target:getName()
        },
        items = items,
        remainingMs = math.max(0, (session.expiresAt or GetGameTimer()) - GetGameTimer()),
        maxAmount = math.max(1, math.floor(tonumber(Config.MaxRobAmount) or 100))
    }
end

clearSearch = function(playerSource, message, closeUi)
    playerSource = tonumber(playerSource)
    local session = playerSource and ActiveSearches[playerSource]
    if not session then return end

    ActiveSearches[playerSource] = nil
    if TargetSearches[session.targetSource] == playerSource then
        TargetSearches[session.targetSource] = nil
    end

    if getPlayer(playerSource) then
        TriggerClientEvent('ms_crime:client:sessionEnded', playerSource, {
            message = message,
            close = closeUi ~= false
        })
    end
end

local function validateSession(playerSource, session, phase)
    local robber = getPlayer(playerSource)
    local target = session and getPlayer(session.targetSource)
    if not session or not robber or not target then return false, 'Der Spieler ist nicht mehr verfügbar.' end
    if not isCrimePlayer(robber) then return false, 'Nur der Crime-Job darf Personen ausrauben.' end

    local distance = phase == 'search'
        and math.max(0.5, tonumber(Config.SearchDistance) or 3.0)
        or math.max(0.5, tonumber(Config.LootDistance) or 3.5)
    if distanceBetween(playerSource, session.targetSource) > distance then
        return false, 'Die gefesselte Person ist zu weit entfernt.'
    end
    if not IsRestrained(session.targetSource) then
        return false, 'Die Person ist nicht mehr gefesselt.'
    end
    return true, robber, target
end

local function openLootWindow(playerSource, token)
    local session = ActiveSearches[playerSource]
    if not session or session.token ~= token or session.phase ~= 'searching' then return end

    local valid, reason = validateSession(playerSource, session, 'search')
    if not valid then return clearSearch(playerSource, reason, true) end

    session.phase = 'looting'
    session.expiresAt = GetGameTimer()
        + math.max(10000, math.floor(tonumber(Config.LootWindowMs) or 120000))
    local payload = lootPayload(session)
    if not payload then return clearSearch(playerSource, 'Das Zielinventar konnte nicht geladen werden.', true) end

    TriggerClientEvent('ms_crime:client:openLoot', playerSource, payload)
    SetTimeout(math.max(10000, math.floor(tonumber(Config.LootWindowMs) or 120000)), function()
        local current = ActiveSearches[playerSource]
        if current and current.token == token and current.phase == 'looting' then
            clearSearch(playerSource, 'Das Zeitfenster zum Durchsuchen ist abgelaufen.', true)
        end
    end)
end

RegisterNetEvent('ms_crime:server:restraintState', function(restrained)
    local playerSource = source
    local state = RestraintStates[playerSource] or {}
    state.client = restrained == true
    state.clientUpdatedAt = GetGameTimer()
    RestraintStates[playerSource] = state

    if restrained ~= true and not IsRestrained(playerSource) then
        local robberSource = TargetSearches[playerSource]
        if robberSource then clearSearch(robberSource, 'Die Person ist nicht mehr gefesselt.', true) end
    end
end)

RegisterNetEvent('ms_crime:server:beginSearch', function(rawTarget)
    local playerSource = source
    local targetSource = tonumber(rawTarget)
    local robber = getPlayer(playerSource)
    local target = targetSource and getPlayer(targetSource)
    if not isCrimePlayer(robber) then return notify(playerSource, 'Nur der Crime-Job darf Personen durchsuchen.') end
    if not target or targetSource == playerSource then return notify(playerSource, 'Keine durchsuchbare Person gefunden.') end
    if ActiveSearches[playerSource] then return notify(playerSource, 'Du durchsuchst bereits eine Person.') end
    if TargetSearches[targetSource] then return notify(playerSource, 'Diese Person wird bereits durchsucht.') end
    if distanceBetween(playerSource, targetSource) > math.max(0.5, tonumber(Config.SearchDistance) or 3.0) then
        return notify(playerSource, 'Die Person ist zu weit entfernt.')
    end
    if not IsRestrained(targetSource) then return notify(playerSource, 'Die Person ist nicht gefesselt.') end

    SearchSequence = SearchSequence + 1
    if SearchSequence > 2147483647 then SearchSequence = 1 end
    local duration = math.max(1000, math.floor(tonumber(Config.SearchDurationMs) or 60000))
    local session = {
        token = SearchSequence,
        targetSource = targetSource,
        phase = 'searching',
        startedAt = GetGameTimer(),
        completesAt = GetGameTimer() + duration
    }
    ActiveSearches[playerSource] = session
    TargetSearches[targetSource] = playerSource

    notify(playerSource, 'Du durchsuchst die Person.')
    notify(targetSource, ('Du wirst von %s durchsucht.'):format(robber:getName()))
    TriggerClientEvent('ms_crime:client:startSearch', playerSource, {
        text = 'Du durchsuchst die Person.',
        targetName = target:getName(),
        durationMs = duration
    })

    SetTimeout(duration, function()
        openLootWindow(playerSource, session.token)
    end)
end)

RegisterNetEvent('ms_crime:server:refreshLoot', function()
    local playerSource = source
    local session = ActiveSearches[playerSource]
    if not session or session.phase ~= 'looting' or onCooldown(playerSource, 'refresh') then return end

    local valid, reason = validateSession(playerSource, session, 'loot')
    if not valid then return clearSearch(playerSource, reason, true) end
    if GetGameTimer() >= session.expiresAt then
        return clearSearch(playerSource, 'Das Zeitfenster zum Durchsuchen ist abgelaufen.', true)
    end

    TriggerClientEvent('ms_crime:client:refreshLoot', playerSource, lootPayload(session))
end)

RegisterNetEvent('ms_crime:server:robItem', function(itemName, rawAmount)
    local playerSource = source
    local session = ActiveSearches[playerSource]
    if not session or session.phase ~= 'looting' then return end
    if onCooldown(playerSource, 'rob') then return notify(playerSource, 'Bitte warte einen Moment.') end

    local valid, robberOrReason, target = validateSession(playerSource, session, 'loot')
    if not valid then return clearSearch(playerSource, robberOrReason, true) end
    if GetGameTimer() >= session.expiresAt then
        return clearSearch(playerSource, 'Das Zeitfenster zum Durchsuchen ist abgelaufen.', true)
    end

    local robber = robberOrReason
    itemName = type(itemName) == 'string' and itemName or nil
    local amount = actionAmount(rawAmount)
    local item = itemName and exports.MSCore:GetItem(itemName)
    if not item or not amount then return notify(playerSource, 'Item oder Menge ist ungültig.') end
    if item.tradable ~= true then return notify(playerSource, 'Dieses Item kann nicht geraubt werden.') end
    if (tonumber(target:getInventory()[itemName]) or 0) < amount then
        return notify(playerSource, 'Die Person besitzt nicht genügend davon.')
    end
    if not robber:canCarryItem(itemName, amount) then
        return notify(playerSource, 'Dein Inventar hat nicht genügend Platz.')
    end

    if not target:removeItem(itemName, amount, ('crime_robbed_by:%d'):format(playerSource)) then
        return notify(playerSource, 'Das Item konnte nicht entnommen werden.')
    end
    if not robber:addItem(itemName, amount, ('crime_robbed_from:%d'):format(session.targetSource)) then
        target:addItem(itemName, amount, 'crime_robbery_rollback')
        return notify(playerSource, 'Der Raub wurde zurückgesetzt.')
    end

    robber:save()
    target:save()
    notify(playerSource, ('%dx %s geraubt.'):format(amount, item.label))
    notify(session.targetSource, ('%dx %s wurde dir geraubt.'):format(amount, item.label))
    TriggerClientEvent('ms_crime:client:refreshLoot', playerSource, lootPayload(session))
    TriggerEvent('MS_Crime:server:itemRobbed', {
        robberSource = playerSource,
        robberCharacterId = robber.characterId,
        targetSource = session.targetSource,
        targetCharacterId = target.characterId,
        item = itemName,
        amount = amount
    })
    debugLog('%d raubte %dx %s von %d.', playerSource, amount, itemName, session.targetSource)
end)

RegisterNetEvent('ms_crime:server:closeLoot', function()
    clearSearch(source, nil, false)
end)

local function clearPlayer(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return end

    clearSearch(playerSource, nil, true)
    local robberSource = TargetSearches[playerSource]
    if robberSource then clearSearch(robberSource, 'Die Person ist nicht mehr verfügbar.', true) end
    RestraintStates[playerSource] = nil
    for key in pairs(LastActions) do
        if key:match(('^%d+:'):format(playerSource)) then LastActions[key] = nil end
    end
end

AddEventHandler('mscore:server:playerUnloaded', clearPlayer)
AddEventHandler('playerDropped', function()
    clearPlayer(source)
end)

AddEventHandler('mscore:server:jobChanged', function(playerSource)
    local session = ActiveSearches[tonumber(playerSource)]
    if session and not isCrimePlayer(getPlayer(playerSource)) then
        clearSearch(playerSource, 'Du gehörst nicht mehr zum Crime-Job.', true)
    end
end)

exports('IsRestrained', IsRestrained)
exports('SetRestrained', SetRestrained)
