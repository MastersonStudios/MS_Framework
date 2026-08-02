local loadingPlayers = {}

local function loadAccount(identifier)
    local account = MySQL.single.await('SELECT * FROM `mscore_accounts` WHERE `license` = ? LIMIT 1', { identifier })
    if account then return account end

    MySQL.insert.await([[
        INSERT IGNORE INTO `mscore_accounts` (`license`, `group_name`, `max_characters`)
        VALUES (?, ?, ?)
    ]], {
        identifier,
        tostring(Config.DefaultCharacter.group or 'user'),
        math.max(1, math.floor(tonumber(Config.MaxCharacters) or 3))
    })
    return MySQL.single.await('SELECT * FROM `mscore_accounts` WHERE `license` = ? LIMIT 1', { identifier })
end

function MSCore.EnsurePlayer(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource or not GetPlayerName(playerSource) then return nil, 'Spieler ist nicht verbunden.' end
    if MSCore.Players[playerSource] then return MSCore.Players[playerSource] end

    if loadingPlayers[playerSource] then
        local result = Citizen.Await(loadingPlayers[playerSource])
        return result.player, result.error
    end

    local loadPromise = promise.new()
    loadingPlayers[playerSource] = loadPromise
    local result = {}

    local ok, errorMessage = xpcall(function()
        local databaseReady, databaseError = MSDatabase.AwaitReady()
        if not databaseReady then error(databaseError or 'Datenbank ist nicht bereit.') end

        local identifier = MSCore.GetIdentifier(playerSource)
        if not identifier then error(('Identifier "%s" fehlt.'):format(Config.IdentifierType or 'license')) end

        local existingSource = MSCore.IdentifierOwners[identifier]
        if existingSource and existingSource ~= playerSource and GetPlayerName(existingSource) then
            DropPlayer(playerSource, 'Dieser Rockstar-/Cfx-Account ist bereits mit dem Server verbunden.')
            error('Doppelte Verbindung mit demselben Identifier.')
        end

        local account = loadAccount(identifier)
        if not account then error('Account konnte nicht geladen oder angelegt werden.') end

        local player = MSPlayer.new(playerSource, identifier, account)
        player:LoadCharacters()
        if not GetPlayerName(playerSource) then error('Spieler hat die Verbindung während des Ladens getrennt.') end

        MSCore.Players[playerSource] = player
        MSCore.IdentifierOwners[identifier] = playerSource
        player:SyncState(nil)
        result.player = player
        TriggerEvent('mscore:server:playerReady', playerSource, player)
    end, function(message)
        return type(debug) == 'table' and debug.traceback(tostring(message), 2) or tostring(message)
    end)

    if not ok then
        result.error = tostring(errorMessage)
        MSCore.Log('error', 'Spieler %s konnte nicht geladen werden:\n%s', playerSource, result.error)
    end

    loadingPlayers[playerSource] = nil
    loadPromise:resolve(result)
    return result.player, result.error
end

local function sendCharacterSelection(player, reason)
    player:SetSelectionBucket()
    player:SyncState(nil)
    TriggerClientEvent('mscore:client:characters', player.source, player:GetCharacters(), player.maxCharacters, reason)
    if #player:GetCharacters() == 0 then
        TriggerClientEvent('mscore:client:characterRequired', player.source, player.maxCharacters)
    end
end

local function bootstrap(playerSource)
    local player, errorMessage = MSCore.EnsurePlayer(playerSource)
    if not player then
        return MSCore.Notify(playerSource, 'Dein Account konnte nicht geladen werden.', 'error')
    end

    local activeCharacter = player:GetActiveCharacter()
    if activeCharacter then
        activeCharacter:Sync()
        return TriggerClientEvent('mscore:client:spawn', playerSource, activeCharacter.coords, activeCharacter:ToClientData())
    end

    local characters = player:GetCharacters()
    if Config.AutoSelectSingleCharacter and #characters == 1 then
        local success, selectError = player:SelectCharacter(characters[1].id)
        if success then return end
        MSCore.Log('error', 'Charakterauswahl für Spieler %d fehlgeschlagen: %s', playerSource, selectError)
    end
    sendCharacterSelection(player, errorMessage and 'load-error' or 'join')
end

RegisterNetEvent('mscore:server:bootstrap', function()
    local playerSource = source
    CreateThread(function() bootstrap(playerSource) end)
end)

AddEventHandler('playerJoining', function()
    local playerSource = source
    CreateThread(function() MSCore.EnsurePlayer(playerSource) end)
end)

MSCore.RegisterCallback('mscore:getCharacters', function(playerSource, reply)
    local player, errorMessage = MSCore.EnsurePlayer(playerSource)
    if not player then return reply(false, errorMessage) end
    reply(true, player:GetCharacters(), player.maxCharacters)
end)

MSCore.RegisterCallback('mscore:createCharacter', function(playerSource, reply, data)
    local player, loadError = MSCore.EnsurePlayer(playerSource)
    if not player then return reply(false, loadError) end

    local character, createError = player:CreateCharacter(data)
    if not character then return reply(false, createError) end
    local shouldSelect = type(data) ~= 'table' or data.select ~= false
    if shouldSelect then
        local selected, selectError = player:SelectCharacter(character.id)
        if not selected then return reply(false, selectError) end
    else
        sendCharacterSelection(player, 'created')
    end
    reply(true, character:ToSelectionData())
end)

MSCore.RegisterCallback('mscore:selectCharacter', function(playerSource, reply, characterId)
    local player, loadError = MSCore.EnsurePlayer(playerSource)
    if not player then return reply(false, loadError) end
    local success, characterOrError = player:SelectCharacter(characterId)
    if not success then return reply(false, characterOrError) end
    reply(true, characterOrError:ToClientData())
end)

MSCore.RegisterCallback('mscore:deleteCharacter', function(playerSource, reply, characterId)
    local player, loadError = MSCore.EnsurePlayer(playerSource)
    if not player then return reply(false, loadError) end
    local success, deleteError = player:DeleteCharacter(characterId)
    if not success then return reply(false, deleteError) end
    sendCharacterSelection(player, 'deleted')
    reply(true, player:GetCharacters())
end)

MSCore.RegisterCallback('mscore:logout', function(playerSource, reply)
    local player = MSCore.GetPlayer(playerSource)
    if not player then return reply(false, 'Spieler ist nicht geladen.') end
    local success, unloadError = player:UnloadCharacter('logout')
    if not success then return reply(false, unloadError) end
    sendCharacterSelection(player, 'logout')
    reply(true, player:GetCharacters())
end)

RegisterNetEvent('mscore:server:updatePosition', function()
    local player = MSCore.GetPlayer(source)
    local character = player and player:GetActiveCharacter() or nil
    if not character then return end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    if not coords then return end
    character:SetPosition({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) })
end)

RegisterNetEvent('mscore:server:updateVitals', function(clientHealth, clientStamina, clientDead)
    local player = MSCore.GetPlayer(source)
    local character = player and player:GetActiveCharacter() or nil
    if not character then return end

    local health = tonumber(clientHealth)
    local stamina = tonumber(clientStamina)
    if health then health = MSUtils.Clamp(health, 0, 1000) end
    if stamina then stamina = MSUtils.Clamp(stamina, 0, 1000) end
    character:SetVitals(health, stamina, clientDead == true)
end)

AddEventHandler('playerDropped', function(reason)
    local playerSource = source
    local player = MSCore.Players[playerSource]
    if not player then return end

    local ok, errorMessage = pcall(function() player:Save(reason or 'disconnect') end)
    if not ok then MSCore.Log('error', 'Speichern beim Verlassen fehlgeschlagen: %s', errorMessage) end
    MSCore.IdentifierOwners[player.identifier] = nil
    MSCore.Players[playerSource] = nil
    TriggerEvent('mscore:server:playerUnloaded', playerSource, player, reason)
end)

CreateThread(function()
    while true do
        Wait(math.max(30000, tonumber(Config.SaveIntervalMs) or 300000))
        for playerSource, player in pairs(MSCore.Players) do
            local ok, errorMessage = pcall(function() player:Save('interval') end)
            if not ok then MSCore.Log('error', 'Autosave für Spieler %d fehlgeschlagen: %s', playerSource, errorMessage) end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, player in pairs(MSCore.Players) do
        pcall(function() player:Save('resource-stop') end)
    end
end)
