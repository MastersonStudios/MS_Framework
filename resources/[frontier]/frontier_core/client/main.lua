local PlayerData = {}
local Callbacks, NextRequest = {}, 0

function Frontier.TriggerCallback(name, callback, ...)
    NextRequest = NextRequest + 1
    Callbacks[NextRequest] = callback
    TriggerServerEvent('frontier:server:callback', NextRequest, name, ...)
end
exports('TriggerCallback', Frontier.TriggerCallback)

function Frontier.GetPlayerData() return PlayerData end
exports('GetPlayerData', Frontier.GetPlayerData)

RegisterNetEvent('frontier:client:callback', function(requestId, ...)
    local callback = Callbacks[requestId]
    if not callback then return end
    Callbacks[requestId] = nil
    callback(...)
end)

RegisterNetEvent('frontier:client:setPlayerData', function(data)
    PlayerData = data
    TriggerEvent('frontier:client:playerDataChanged', data)
end)

RegisterNetEvent('frontier:client:notify', function(message)
    TriggerEvent('chat:addMessage', { color = { 219, 176, 93 }, args = { 'Frontier', tostring(message) } })
end)

RegisterNetEvent('frontier:client:spawn', function(coords)
    local ped = PlayerPedId()
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, tonumber(coords.w) or 0.0)
    FreezeEntityPosition(ped, true)
    Wait(1000)
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(500)
end)

RegisterNetEvent('frontier:client:showCharacters', function()
    Frontier.TriggerCallback('frontier:getCharacters', function(characters, err)
        if not characters then
            return TriggerEvent('frontier:client:notify', err or 'Fehler beim Laden.')
        end
        TriggerEvent('chat:addMessage', { args = { 'Frontier', 'Charaktere:' } })
        for _, character in ipairs(characters) do
            TriggerEvent('chat:addMessage', {
                args = { ('[%d]'):format(character.id), ('%s %s – /selectchar %d'):format(character.firstname, character.lastname, character.id) }
            })
        end
    end)
end)

RegisterCommand('selectchar', function(_, args)
    local id = tonumber(args[1])
    if not id then return end
    Frontier.TriggerCallback('frontier:selectCharacter', function(success, err)
        if not success then TriggerEvent('frontier:client:notify', err or 'Auswahl fehlgeschlagen.') end
    end, id)
end)

RegisterCommand('newchar', function(_, args)
    local firstname, lastname, sex = args[1], args[2], args[3] or 'male'
    if not firstname or not lastname then
        return TriggerEvent('frontier:client:notify', 'Verwendung: /newchar Vorname Nachname male|female')
    end
    Frontier.TriggerCallback('frontier:createCharacter', function(success, err)
        if not success then TriggerEvent('frontier:client:notify', err or 'Erstellung fehlgeschlagen.') end
    end, { firstname = firstname, lastname = lastname, sex = sex })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)
    TriggerEvent('frontier:client:showCharacters')
    while true do
        Wait(30000)
        if PlayerData.characterId then
            local ped, coords = PlayerPedId(), GetEntityCoords(PlayerPedId())
            TriggerServerEvent('frontier:server:updatePosition', {
                x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped)
            }, GetEntityHealth(ped))
        end
    end
end)
