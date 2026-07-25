RegisterNetEvent('mscore:client:playerDataChanged', function(data)
    if data and data.name then
        print(('[MSCore Example] Spieler synchronisiert: %s'):format(data.name))
    end
end)
