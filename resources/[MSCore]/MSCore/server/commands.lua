local function notify(playerSource, message, notificationType)
    if playerSource == 0 then
        print(('[MSCore] %s'):format(message))
    else
        MSCore.Notify(playerSource, message, notificationType)
    end
end

local function requireAdmin(playerSource)
    if MSCore.IsAdmin(playerSource) then return true end
    notify(playerSource, 'Dafür fehlen dir die Adminrechte.', 'error')
    return false
end

local function ensurePlayer(playerSource)
    local player, errorMessage = MSCore.EnsurePlayer(playerSource)
    if not player then notify(playerSource, errorMessage or 'Spieler konnte nicht geladen werden.', 'error') end
    return player
end

RegisterCommand('mscharacters', function(playerSource)
    if playerSource == 0 then return notify(0, 'Dieser Befehl ist nur im Spiel verfügbar.') end
    local player = ensurePlayer(playerSource)
    if not player then return end
    player:UnloadCharacter('command')
    player:SetSelectionBucket()
    TriggerClientEvent('mscore:client:characters', playerSource, player:GetCharacters(), player.maxCharacters, 'command')
end, false)

RegisterCommand('mscreate', function(playerSource, arguments)
    if playerSource == 0 then return notify(0, 'Dieser Befehl ist nur im Spiel verfügbar.') end
    if not arguments[1] or not arguments[2] then
        return notify(playerSource, 'Verwendung: /mscreate Vorname Nachname [male|female] [JJJJ-MM-TT]', 'error')
    end
    local player = ensurePlayer(playerSource)
    if not player then return end
    local character, errorMessage = player:CreateCharacter({
        firstname = arguments[1],
        lastname = arguments[2],
        sex = arguments[3] or 'male',
        dateOfBirth = arguments[4]
    })
    if not character then return notify(playerSource, errorMessage, 'error') end
    local success, selectError = player:SelectCharacter(character.id)
    notify(playerSource, success and 'Charakter wurde erstellt.' or selectError, success and 'success' or 'error')
end, false)

RegisterCommand('msselect', function(playerSource, arguments)
    if playerSource == 0 then return notify(0, 'Dieser Befehl ist nur im Spiel verfügbar.') end
    local player = ensurePlayer(playerSource)
    if not player then return end
    local success, result = player:SelectCharacter(arguments[1])
    notify(playerSource, success and 'Charakter ausgewählt.' or result, success and 'success' or 'error')
end, false)

RegisterCommand('msdelete', function(playerSource, arguments)
    if playerSource == 0 then return notify(0, 'Dieser Befehl ist nur im Spiel verfügbar.') end
    local player = ensurePlayer(playerSource)
    if not player then return end
    local success, errorMessage = player:DeleteCharacter(arguments[1])
    notify(playerSource, success and 'Charakter gelöscht.' or errorMessage, success and 'success' or 'error')
    if success then TriggerClientEvent('mscore:client:characters', playerSource, player:GetCharacters(), player.maxCharacters, 'deleted') end
end, false)

RegisterCommand('mslogout', function(playerSource)
    if playerSource == 0 then return notify(0, 'Dieser Befehl ist nur im Spiel verfügbar.') end
    local player = MSCore.GetPlayer(playerSource)
    if not player then return notify(playerSource, 'Spieler ist nicht geladen.', 'error') end
    local success, errorMessage = player:UnloadCharacter('command')
    if success then TriggerClientEvent('mscore:client:characters', playerSource, player:GetCharacters(), player.maxCharacters, 'logout') end
    notify(playerSource, success and 'Charakter wurde abgemeldet.' or errorMessage, success and 'success' or 'error')
end, false)

RegisterCommand('mssetgroup', function(playerSource, arguments)
    if not requireAdmin(playerSource) then return end
    local target = tonumber(arguments[1])
    local groupName = arguments[2]
    local player = target and MSCore.GetPlayer(target) or nil
    if not player or not groupName then return notify(playerSource, 'Verwendung: /mssetgroup Server-ID Gruppe', 'error') end
    local success, errorMessage = player:SetGroup(groupName)
    notify(playerSource, success and 'Gruppe aktualisiert.' or errorMessage, success and 'success' or 'error')
end, false)

RegisterCommand('mssetjob', function(playerSource, arguments)
    if not requireAdmin(playerSource) then return end
    local target = tonumber(arguments[1])
    local player = target and MSCore.GetPlayer(target) or nil
    local character = player and player:GetActiveCharacter() or nil
    if not character or not arguments[2] or arguments[3] == nil then
        return notify(playerSource, 'Verwendung: /mssetjob Server-ID Job Grad', 'error')
    end
    local success, errorMessage = character:SetJob(arguments[2], arguments[3], ('admin:%s'):format(playerSource))
    notify(playerSource, success and 'Job aktualisiert.' or errorMessage, success and 'success' or 'error')
end, false)

RegisterCommand('msmoney', function(playerSource, arguments)
    if not requireAdmin(playerSource) then return end
    local target = tonumber(arguments[1])
    local operation = tostring(arguments[2] or ''):lower()
    local currency = tostring(arguments[3] or ''):lower()
    local amount = tonumber(arguments[4])
    local player = target and MSCore.GetPlayer(target) or nil
    local character = player and player:GetActiveCharacter() or nil
    if not character or not amount or (operation ~= 'add' and operation ~= 'remove' and operation ~= 'set') then
        return notify(playerSource, 'Verwendung: /msmoney Server-ID add|remove|set money|gold Betrag', 'error')
    end

    local success, result
    if operation == 'add' then
        success, result = character:AddMoney(currency, amount, ('admin:%s'):format(playerSource))
    elseif operation == 'remove' then
        success, result = character:RemoveMoney(currency, amount, ('admin:%s'):format(playerSource))
    else
        success, result = character:SetMoney(currency, amount, ('admin:%s'):format(playerSource))
    end
    notify(playerSource, success and 'Kontostand aktualisiert.' or result, success and 'success' or 'error')
end, false)
