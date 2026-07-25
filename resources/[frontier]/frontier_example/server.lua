RegisterCommand('daily', function(source)
    if source == 0 then return end
    local player = exports.frontier_core:GetPlayer(source)
    if not player then return end

    local today = os.date('!%Y-%m-%d')
    if player.metadata.lastDaily == today then
        return TriggerClientEvent('frontier:client:notify', source, 'Heute bereits abgeholt.')
    end

    player:setMetadata('lastDaily', today)
    player:addMoney('cash', 10, 'daily_reward')
    TriggerClientEvent('frontier:client:notify', source, 'Tagesbonus: $10')
end)
