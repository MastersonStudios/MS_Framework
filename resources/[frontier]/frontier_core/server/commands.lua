local function notify(source, message)
    TriggerClientEvent('frontier:client:notify', source, message)
end

RegisterCommand('characters', function(source)
    if source == 0 then return end
    TriggerClientEvent('frontier:client:showCharacters', source)
end)

RegisterCommand('cash', function(source)
    local player = exports.frontier_core:GetPlayer(source)
    if player then notify(source, ('$%d Bargeld | $%d Bank'):format(player.money.cash, player.money.bank)) end
end)

RegisterCommand('setjob', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'frontier.admin') then return end
    local target = tonumber(args[1])
    local player = target and exports.frontier_core:GetPlayer(target)
    if not player then return print('Spieler nicht online.') end
    if not player:setJob(args[2], tonumber(args[3]) or 0) then return print('Job/Grad ungültig.') end
    notify(target, ('Neuer Job: %s (Grad %d)'):format(player.job, player.jobGrade))
end, false)

RegisterCommand('givemoney', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'frontier.admin') then return end
    local target, amount = tonumber(args[1]), tonumber(args[3])
    local player = target and exports.frontier_core:GetPlayer(target)
    if not player or not player:addMoney(args[2], amount, 'admin') then
        return print('Verwendung: givemoney [id] [cash|bank] [positiver ganzzahliger Betrag]')
    end
    notify(target, ('$%d zu %s hinzugefügt.'):format(amount, args[2]))
end, false)
