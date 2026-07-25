RegisterNetEvent('frontier:client:playerDataChanged', function(data)
    if data and data.name then
        print(('[Frontier Example] Spieler synchronisiert: %s'):format(data.name))
    end
end)
