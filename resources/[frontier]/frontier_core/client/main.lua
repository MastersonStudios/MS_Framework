local PlayerData = {}
local Callbacks, NextRequest = {}, 0
local SelectorOpen = false

function Frontier.TriggerCallback(name, callback, ...)
    NextRequest = NextRequest + 1
    Callbacks[NextRequest] = callback
    TriggerServerEvent('frontier:server:callback', NextRequest, name, ...)
end
exports('TriggerCallback', Frontier.TriggerCallback)

function Frontier.GetPlayerData() return PlayerData end
exports('GetPlayerData', Frontier.GetPlayerData)

local function setSelectorVisible(visible)
    SelectorOpen = visible
    SetNuiFocus(visible, visible)
    if not visible then
        SendNUIMessage({ action = 'close' })
        FreezeEntityPosition(PlayerPedId(), false)
    end
end

local function openCharacterSelector()
    if SelectorOpen then
        SendNUIMessage({ action = 'loading' })
    else
        SelectorOpen = true
        FreezeEntityPosition(PlayerPedId(), true)
        if not PlayerData.characterId then SetEntityVisible(PlayerPedId(), false, false) end
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'loading' })
    end

    Frontier.TriggerCallback('frontier:getCharacters', function(characters, err)
        if not characters then
            SendNUIMessage({ action = 'error', message = err or 'Charaktere konnten nicht geladen werden.' })
            return
        end
        SendNUIMessage({
            action = 'open',
            characters = characters,
            maxCharacters = Config.MaxCharacters,
            canClose = PlayerData.characterId ~= nil,
            activeCharacterId = PlayerData.characterId,
            minBirthDate = Config.CharacterBirthDateMin,
            maxBirthDate = Config.CharacterBirthDateMax
        })
    end)
end

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

RegisterNetEvent('frontier:client:clearPlayerData', function()
    PlayerData = {}
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    TriggerEvent('frontier:client:playerDataChanged', PlayerData)
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
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, true)
    Wait(1000)
    setSelectorVisible(false)
    DoScreenFadeIn(500)
end)

RegisterNetEvent('frontier:client:showCharacters', openCharacterSelector)

RegisterNUICallback('selectCharacter', function(data, cb)
    local id = tonumber(data and data.id)
    if not id then return cb({ ok = false, error = 'Ungültiger Charakter.' }) end
    Frontier.TriggerCallback('frontier:selectCharacter', function(success, err)
        cb({ ok = success == true, error = err })
        if success then setSelectorVisible(false) end
    end, id)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    Frontier.TriggerCallback('frontier:createCharacter', function(success, err)
        cb({ ok = success == true, error = err })
        if success then setSelectorVisible(false) end
    end, {
        firstname = data and data.firstname,
        lastname = data and data.lastname,
        dateOfBirth = data and data.dateOfBirth,
        sex = data and data.sex
    })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    local id = tonumber(data and data.id)
    if not id then return cb({ ok = false, error = 'Ungültiger Charakter.' }) end
    Frontier.TriggerCallback('frontier:deleteCharacter', function(success, charactersOrError)
        if not success then return cb({ ok = false, error = charactersOrError }) end
        cb({ ok = true, characters = charactersOrError })
    end, id)
end)

RegisterNUICallback('closeCharacters', function(_, cb)
    if not PlayerData.characterId then
        return cb({ ok = false, error = 'Wähle zuerst einen Charakter.' })
    end
    setSelectorVisible(false)
    cb({ ok = true })
end)

RegisterCommand('selectchar', function(_, args)
    local id = tonumber(args[1])
    if not id then return end
    Frontier.TriggerCallback('frontier:selectCharacter', function(success, err)
        if not success then
            TriggerEvent('frontier:client:notify', err or 'Auswahl fehlgeschlagen.')
        else
            setSelectorVisible(false)
        end
    end, id)
end)

RegisterCommand('newchar', function(_, args)
    local firstname, lastname, sex = args[1], args[2], args[3] or 'male'
    if not firstname or not lastname then
        return TriggerEvent('frontier:client:notify', 'Verwendung: /newchar Vorname Nachname male|female')
    end
    Frontier.TriggerCallback('frontier:createCharacter', function(success, err)
        if not success then
            TriggerEvent('frontier:client:notify', err or 'Erstellung fehlgeschlagen.')
        else
            setSelectorVisible(false)
        end
    end, { firstname = firstname, lastname = lastname, sex = sex })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)
    openCharacterSelector()
end)

CreateThread(function()
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityVisible(PlayerPedId(), true, false)
end)
