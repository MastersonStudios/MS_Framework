local ActiveOnboardings = {}
local BeachNotifications = {}

local function notify(source, message)
    if source == 0 then
        print(('[MSCore Guarma] %s'):format(message))
        return
    end
    TriggerClientEvent('mscore:client:notify', source, message)
end

local function isAdmin(source)
    return source == 0 or IsPlayerAceAllowed(source, GuarmaConfig.AdminPermission)
end

local function distanceTo(source, target)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return math.huge end
    local coords = GetEntityCoords(ped)
    local dx, dy, dz = coords.x - target.x, coords.y - target.y, coords.z - target.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function adminLocations()
    local result = {}
    for _, location in ipairs(GuarmaConfig.AdminLocations) do
        result[#result + 1] = { id = location.id, label = location.label }
    end
    return result
end

local function newcomerRows()
    local rows = {}
    for source, entry in pairs(ActiveOnboardings) do
        if GetPlayerName(source) then
            rows[#rows + 1] = {
                source = source,
                name = GetPlayerName(source),
                characterId = entry.characterId,
                characterName = entry.characterName,
                stage = entry.stage
            }
        end
    end
    table.sort(rows, function(a, b) return a.source < b.source end)
    return rows
end

local function sendAdminAlert(playerSource, characterName)
    if not GuarmaConfig.NotifyAdmins then return end
    for _, adminId in ipairs(GetPlayers()) do
        adminId = tonumber(adminId)
        if adminId and IsPlayerAceAllowed(adminId, GuarmaConfig.AdminPermission) then
            TriggerClientEvent('ms_guarma:client:adminAlert', adminId, {
                source = playerSource,
                name = GetPlayerName(playerSource),
                characterName = characterName
            })
        end
    end
end

local function isOnGuarma(coords)
    if type(coords) ~= 'table' then return false end
    local bounds = GuarmaConfig.IslandBounds
    local x, y = tonumber(coords.x), tonumber(coords.y)
    return x and y
        and x >= bounds.minX and x <= bounds.maxX
        and y >= bounds.minY and y <= bounds.maxY
end

local function startForPlayer(source, player)
    if not GuarmaConfig.Enabled or not player then return end
    if player.metadata.guarmaOnboardingComplete then
        if isOnGuarma(player.coords) then
            TriggerClientEvent('ms_guarma:client:setIslandMode', source, true)
        end
        return
    end
    local resume = player.metadata.guarmaOnboardingStage == 'tutorial'
    ActiveOnboardings[source] = {
        characterId = player.characterId,
        characterName = player:getName(),
        stage = resume and 'tutorial' or 'intro'
    }
    TriggerClientEvent('ms_guarma:client:start', source, resume)
end

AddEventHandler('mscore:server:playerLoaded', function(source, player)
    startForPlayer(source, player)
end)

RegisterNetEvent('ms_guarma:server:beachArrived', function()
    local source = source
    local entry = ActiveOnboardings[source]
    local player = exports.MSCore:GetPlayer(source)
    if not entry or not player or player.characterId ~= entry.characterId then return end
    if distanceTo(source, GuarmaConfig.BeachSpawn) > 35.0 then return end

    entry.stage = 'tutorial'
    player:setMetadata('guarmaOnboardingStage', 'tutorial')
    if not BeachNotifications[source] then
        BeachNotifications[source] = true
        sendAdminAlert(source, player:getName())
    end
end)

RegisterNetEvent('ms_guarma:server:complete', function()
    local source = source
    local entry = ActiveOnboardings[source]
    local player = exports.MSCore:GetPlayer(source)
    if not entry or not player or player.characterId ~= entry.characterId then return end
    if distanceTo(source, GuarmaConfig.Port) > GuarmaConfig.CompletionRadius then
        TriggerClientEvent('ms_guarma:client:completionRejected', source)
        return notify(source, 'Erreiche zuerst den Hafen.')
    end

    player:setMetadata('guarmaOnboardingComplete', true)
    player:setMetadata('guarmaOnboardingStage', nil)
    local coords = GetEntityCoords(GetPlayerPed(source))
    player:save({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(GetPlayerPed(source)) })
    ActiveOnboardings[source] = nil
    BeachNotifications[source] = nil
    TriggerClientEvent('ms_guarma:client:completeConfirmed', source)
    notify(source, 'Tutorial abgeschlossen. Willkommen auf Guarma!')
    TriggerEvent('mscore:server:onboardingCompleted', source, player)
end)

RegisterNetEvent('ms_guarma:server:teleportAdmin', function(locationId)
    local source = source
    if not isAdmin(source) or type(locationId) ~= 'string' then return end
    for _, location in ipairs(GuarmaConfig.AdminLocations) do
        if location.id == locationId then
            TriggerClientEvent('ms_guarma:client:teleport', source, location.coords)
            print(('[MSCore Guarma] %s (%d) teleportiert nach %s.'):format(
                GetPlayerName(source) or 'Admin', source, location.label
            ))
            return
        end
    end
end)

local function openAdminMenu(source)
    if source == 0 then return notify(source, 'Dieser Command ist nur ingame verfügbar.') end
    if not isAdmin(source) then return notify(source, 'Keine Berechtigung für das Guarma-Menü.') end
    TriggerClientEvent('ms_guarma:client:openAdminMenu', source, {
        locations = adminLocations(),
        newcomers = newcomerRows()
    })
end

RegisterCommand(GuarmaConfig.AdminMenuCommand, function(source)
    openAdminMenu(source)
end, false)

RegisterCommand(GuarmaConfig.ResetCommand, function(source, args)
    if not isAdmin(source) then return notify(source, 'Keine Berechtigung.') end
    local target = tonumber(args[1])
    if not target then
        if source == 0 then return notify(source, 'Verwendung: guarmareset [Server-ID]') end
        target = source
    end
    local player = exports.MSCore:GetPlayer(target)
    if not player then return notify(source, 'Spieler nicht gefunden oder ohne aktiven Charakter.') end

    player:setMetadata('guarmaOnboardingComplete', nil)
    player:setMetadata('guarmaOnboardingStage', nil)
    BeachNotifications[target] = nil
    TriggerClientEvent('ms_guarma:client:forceStop', target)
    SetTimeout(250, function()
        local currentPlayer = exports.MSCore:GetPlayer(target)
        if currentPlayer and currentPlayer.characterId == player.characterId then
            startForPlayer(target, currentPlayer)
        end
    end)
    notify(source, ('Guarma-Tutorial für %s gestartet.'):format(player:getName()))
end, false)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    ActiveOnboardings[playerSource] = nil
    BeachNotifications[playerSource] = nil
    TriggerClientEvent('ms_guarma:client:forceStop', playerSource)
end)

AddEventHandler('playerDropped', function()
    ActiveOnboardings[source] = nil
    BeachNotifications[source] = nil
end)

CreateThread(function()
    Wait(1500)
    for source, player in pairs(exports.MSCore:GetPlayers()) do
        startForPlayer(source, player)
    end
end)
