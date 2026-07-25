local FrozenPlayers = {}
local OpenMenus = {}
local CurrentWeather = AdminMenuConfig.DefaultWeather
local CurrentTransition = AdminMenuConfig.DefaultTransition

local function notify(source, message)
    if source == 0 then
        print(('[Frontier Admin] %s'):format(message))
        return
    end
    TriggerClientEvent('frontier:client:notify', source, message)
end

local function isAdmin(source)
    return source == 0 or IsPlayerAceAllowed(source, AdminMenuConfig.Permission)
end

local function audit(source, action, target, detail)
    print(('[Frontier Admin] %s (%d) | %s | Ziel: %s | %s'):format(
        source == 0 and 'Konsole' or (GetPlayerName(source) or 'Unbekannt'),
        source,
        action,
        target and tostring(target) or '-',
        detail or '-'
    ))
end

local function weatherById(weatherId)
    if type(weatherId) ~= 'string' then return end
    for _, weather in ipairs(AdminMenuConfig.Weathers) do
        if weather.id == weatherId then return weather end
    end
end

local function playerCoordinates(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(ped)
    }
end

local function inventoryCount(player)
    local count = 0
    local inventory = player.metadata and player.metadata.inventory
    if type(inventory) ~= 'table' then return count end
    for _, amount in pairs(inventory) do
        count = count + math.max(tonumber(amount) or 0, 0)
    end
    return count
end

local function playerRows()
    local rows = {}
    for source, player in pairs(exports.frontier_core:GetPlayers()) do
        source = tonumber(source)
        if source and GetPlayerName(source) then
            local ped = GetPlayerPed(source)
            local health = ped and ped ~= 0 and GetEntityHealth(ped) or 0
            rows[#rows + 1] = {
                source = source,
                serverName = GetPlayerName(source),
                characterName = player:getName(),
                characterId = player.characterId,
                job = player.job,
                jobGrade = player.jobGrade,
                cash = player.money.cash,
                bank = player.money.bank,
                ping = GetPlayerPing(source),
                health = health,
                frozen = FrozenPlayers[source] == true,
                itemCount = inventoryCount(player)
            }
        end
    end
    table.sort(rows, function(a, b) return a.source < b.source end)
    return rows
end

local function weatherRows()
    local rows = {}
    for _, weather in ipairs(AdminMenuConfig.Weathers) do
        rows[#rows + 1] = {
            id = weather.id,
            label = weather.label,
            description = weather.description
        }
    end
    return rows
end

local function payload(source)
    return {
        selfId = source,
        players = playerRows(),
        items = exports.frontier_core:GetItemCatalog(),
        weathers = weatherRows(),
        currentWeather = CurrentWeather,
        currentTransition = CurrentTransition,
        limits = {
            money = AdminMenuConfig.MaxMoneyGrant,
            items = AdminMenuConfig.MaxItemGrant,
            weatherTransition = AdminMenuConfig.MaxWeatherTransition
        }
    }
end

local function refresh(source)
    if source ~= 0 and OpenMenus[source] and isAdmin(source) then
        TriggerClientEvent('frontier_adminmenu:client:refresh', source, payload(source))
    end
end

local function refreshAllMenus()
    for source in pairs(OpenMenus) do refresh(source) end
end

local function result(source, success, message)
    TriggerClientEvent('frontier_adminmenu:client:result', source, {
        success = success == true,
        message = message
    })
    refresh(source)
end

local function positiveInteger(value, maximum)
    value = tonumber(value)
    if not value or value % 1 ~= 0 or value < 1 or value > maximum then return end
    return value
end

local function activeTarget(data)
    local target = type(data) == 'table' and tonumber(data.target)
    local player = target and exports.frontier_core:GetPlayer(target)
    if not target or not player or not GetPlayerName(target) then return end
    return target, player
end

RegisterNetEvent('frontier_adminmenu:server:open', function()
    local source = source
    if not isAdmin(source) then
        return notify(source, 'Keine Berechtigung für das Adminmenü.')
    end
    OpenMenus[source] = true
    TriggerClientEvent('frontier_adminmenu:client:open', source, payload(source))
end)

RegisterNetEvent('frontier_adminmenu:server:close', function()
    OpenMenus[source] = nil
end)

RegisterNetEvent('frontier_adminmenu:server:refresh', function()
    local source = source
    if not isAdmin(source) then return end
    OpenMenus[source] = true
    refresh(source)
end)

RegisterNetEvent('frontier_adminmenu:server:execute', function(action, data)
    local source = source
    if not isAdmin(source) then
        OpenMenus[source] = nil
        TriggerClientEvent('frontier_adminmenu:client:forceClose', source)
        return notify(source, 'Deine Adminberechtigung ist nicht mehr aktiv.')
    end
    if type(action) ~= 'string' then return end
    data = type(data) == 'table' and data or {}

    if action == 'setWeather' then
        local weather = weatherById(data.weather)
        local transition = tonumber(data.transition)
        if not weather or not transition then
            return result(source, false, 'Wetterauswahl ungültig.')
        end
        transition = math.max(0.0, math.min(transition, AdminMenuConfig.MaxWeatherTransition))
        CurrentWeather, CurrentTransition = weather.id, transition
        TriggerClientEvent('frontier_adminmenu:client:applyWeather', -1, {
            id = weather.id,
            hash = weather.hash,
            transition = transition
        })
        audit(source, 'Wetter', nil, ('%s / %.1fs'):format(weather.label, transition))
        refreshAllMenus()
        return result(source, true, ('Wetter auf %s gesetzt.'):format(weather.label))
    end

    if action == 'teleportCoords' then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        local heading = tonumber(data.w) or 0.0
        if not x or not y or not z
            or math.abs(x) > 10000.0 or math.abs(y) > 10000.0
            or z < -500.0 or z > 2000.0 then
            return result(source, false, 'Koordinaten ungültig.')
        end
        TriggerClientEvent('frontier_adminmenu:client:teleport', source, {
            x = x, y = y, z = z, w = heading
        })
        audit(source, 'Koordinaten-Teleport', source, ('%.2f, %.2f, %.2f'):format(x, y, z))
        return result(source, true, 'Teleport ausgeführt.')
    end

    if action == 'noclip' then
        TriggerClientEvent('frontier_adminmenu:client:toggleNoclip', source)
        audit(source, 'Noclip umgeschaltet', source)
        return
    end

    local target, player = activeTarget(data)
    if not target then return result(source, false, 'Spieler nicht gefunden.') end

    if action == 'giveMoney' then
        local amount = positiveInteger(data.amount, AdminMenuConfig.MaxMoneyGrant)
        local account = data.account == 'bank' and 'bank' or data.account == 'cash' and 'cash'
        if not amount or not account then
            return result(source, false, 'Konto oder Betrag ungültig.')
        end
        if not player:addMoney(account, amount, ('admin:%d'):format(source)) then
            return result(source, false, 'Geld konnte nicht hinzugefügt werden.')
        end
        player:save()
        notify(target, ('$%d wurden deinem %s gutgeschrieben.'):format(
            amount,
            account == 'cash' and 'Bargeld' or 'Bankkonto'
        ))
        audit(source, 'Geld hinzugefügt', target, ('%s $%d'):format(account, amount))
        return result(source, true, ('$%d erfolgreich gutgeschrieben.'):format(amount))
    end

    if action == 'giveItem' then
        local amount = positiveInteger(data.amount, AdminMenuConfig.MaxItemGrant)
        local itemName = type(data.item) == 'string' and data.item
        if not amount or not itemName then
            return result(source, false, 'Item oder Anzahl ungültig.')
        end
        if not player:addItem(itemName, amount, ('admin:%d'):format(source)) then
            return result(source, false, 'Item unbekannt oder Stack-Limit überschritten.')
        end
        player:save()
        local itemLabel = itemName
        for _, item in ipairs(exports.frontier_core:GetItemCatalog()) do
            if item.name == itemName then itemLabel = item.label break end
        end
        notify(target, ('%dx %s wurde deinem Inventar hinzugefügt.'):format(amount, itemLabel))
        audit(source, 'Item hinzugefügt', target, ('%s x%d'):format(itemName, amount))
        return result(source, true, ('%dx %s vergeben.'):format(amount, itemLabel))
    end

    if action == 'heal' or action == 'revive' then
        TriggerClientEvent('frontier_adminmenu:client:restorePlayer', target, action == 'revive')
        player:setMetadata('health', 200)
        player:save()
        notify(target, action == 'revive' and 'Du wurdest von einem Admin wiederbelebt.' or 'Du wurdest von einem Admin geheilt.')
        audit(source, action == 'revive' and 'Wiederbelebt' or 'Geheilt', target)
        return result(source, true, action == 'revive' and 'Spieler wiederbelebt.' or 'Spieler geheilt.')
    end

    if action == 'goto' then
        local coords = playerCoordinates(target)
        if not coords then return result(source, false, 'Spielerposition nicht verfügbar.') end
        TriggerClientEvent('frontier_adminmenu:client:teleport', source, coords)
        audit(source, 'Goto', target)
        return result(source, true, 'Zum Spieler teleportiert.')
    end

    if action == 'bring' then
        local coords = playerCoordinates(source)
        if not coords then return result(source, false, 'Adminposition nicht verfügbar.') end
        TriggerClientEvent('frontier_adminmenu:client:teleport', target, coords)
        notify(target, 'Du wurdest von einem Admin teleportiert.')
        audit(source, 'Bring', target)
        return result(source, true, 'Spieler zu dir teleportiert.')
    end

    if action == 'freeze' then
        FrozenPlayers[target] = not FrozenPlayers[target]
        TriggerClientEvent('frontier_adminmenu:client:setFrozen', target, FrozenPlayers[target])
        audit(source, FrozenPlayers[target] and 'Eingefroren' or 'Freigegeben', target)
        return result(source, true, FrozenPlayers[target] and 'Spieler eingefroren.' or 'Spieler freigegeben.')
    end

    if action == 'kick' then
        if target == source then return result(source, false, 'Du kannst dich nicht selbst kicken.') end
        local reason = tostring(data.reason or ''):gsub('[\r\n]', ' '):sub(1, AdminMenuConfig.MaxKickReasonLength)
        if reason:match('^%s*$') then reason = 'Von der Administration vom Server entfernt.' end
        audit(source, 'Kick', target, reason)
        DropPlayer(target, reason)
        refreshAllMenus()
        return result(source, true, 'Spieler vom Server entfernt.')
    end

    result(source, false, 'Unbekannte Adminaktion.')
end)

AddEventHandler('frontier:server:playerLoaded', function(source)
    SetTimeout(1500, function()
        local weather = weatherById(CurrentWeather)
        if weather and GetPlayerName(source) then
            TriggerClientEvent('frontier_adminmenu:client:applyWeather', source, {
                id = weather.id,
                hash = weather.hash,
                transition = CurrentTransition
            })
        end
    end)
    refreshAllMenus()
end)

AddEventHandler('frontier:server:onboardingCompleted', function(source)
    SetTimeout(2500, function()
        local weather = weatherById(CurrentWeather)
        if weather and GetPlayerName(source) then
            TriggerClientEvent('frontier_adminmenu:client:applyWeather', source, {
                id = weather.id,
                hash = weather.hash,
                transition = CurrentTransition
            })
        end
    end)
end)

AddEventHandler('frontier:server:playerUnloaded', function(source)
    FrozenPlayers[source] = nil
    TriggerClientEvent('frontier_adminmenu:client:setFrozen', source, false)
    refreshAllMenus()
end)

AddEventHandler('playerDropped', function()
    FrozenPlayers[source] = nil
    OpenMenus[source] = nil
    refreshAllMenus()
end)

CreateThread(function()
    Wait(1500)
    local weather = weatherById(CurrentWeather)
    if not weather then return end
    TriggerClientEvent('frontier_adminmenu:client:applyWeather', -1, {
        id = weather.id,
        hash = weather.hash,
        transition = CurrentTransition
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for target in pairs(FrozenPlayers) do
        TriggerClientEvent('frontier_adminmenu:client:setFrozen', target, false)
    end
end)
