local function notify(source, message)
    if source == 0 then
        print(('[MSCore Admin] %s'):format(message))
        return
    end
    TriggerClientEvent('mscore:client:notify', source, message)
end

local function canUse(source)
    return source == 0 or IsPlayerAceAllowed(source, AdminLogoutConfig.Permission)
end

local function executeLogout(source, args)
    if not canUse(source) then
        return notify(source, 'Keine Berechtigung für diesen Befehl.')
    end

    local target = tonumber(args[1])
    if not target then
        if source == 0 then return notify(source, 'Verwendung: logout [Server-ID]') end
        target = source
    elseif target ~= source and not AdminLogoutConfig.AllowTargetLogout then
        return notify(source, 'Das Abmelden anderer Spieler ist deaktiviert.')
    end

    if not GetPlayerName(target) then
        return notify(source, 'Spieler nicht gefunden.')
    end

    local player = exports.MSCore:GetPlayer(target)
    if not player then return notify(source, 'Der Spieler hat keinen aktiven Charakter.') end
    local characterId = player.characterId
    local characterName = player:getName()

    local success, err = exports.MSCore:LogoutPlayer(target)
    if not success then return notify(source, err or 'Logout fehlgeschlagen.') end

    if source ~= target then
        notify(source, ('%s wurde zur Charakterauswahl geschickt.'):format(characterName))
    end
    notify(target, 'Du wurdest zur Charakterauswahl zurückgebracht.')

    print(('[MSCore Admin] %s (%d) meldete %s (%d), Charakter #%d, ab.'):format(
        source == 0 and 'Konsole' or GetPlayerName(source),
        source,
        GetPlayerName(target) or 'Spieler',
        target,
        tonumber(characterId) or 0
    ))
    TriggerEvent('mscore:server:adminLogout', source, target, characterId)
end

RegisterCommand(AdminLogoutConfig.Command, executeLogout, false)
for _, alias in ipairs(AdminLogoutConfig.Aliases) do
    RegisterCommand(alias, executeLogout, false)
end
