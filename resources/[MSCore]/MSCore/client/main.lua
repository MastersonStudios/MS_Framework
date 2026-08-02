MSCore = MSCore or {}

local playerData = nil
local availableCharacters = {}
local maximumCharacters = Config.MaxCharacters
local bootstrapped = false

function MSCore.GetPlayerData()
    return MSUtils.Copy(playerData)
end

function MSCore.IsPlayerLoaded()
    return playerData ~= nil
end

function MSCore.GetCharacters()
    return MSUtils.Copy(availableCharacters), maximumCharacters
end

function MSCore.SelectCharacter(characterId, callback)
    MSCore.TriggerCallback('mscore:selectCharacter', callback, characterId)
end

function MSCore.CreateCharacter(characterData, callback)
    MSCore.TriggerCallback('mscore:createCharacter', callback, characterData)
end

function MSCore.DeleteCharacter(characterId, callback)
    MSCore.TriggerCallback('mscore:deleteCharacter', callback, characterId)
end

function MSCore.Logout(callback)
    MSCore.TriggerCallback('mscore:logout', callback)
end

function MSCore.Notify(message, notificationType, duration)
    TriggerEvent('mscore:client:notify', message, notificationType, duration)
end

exports('GetCore', function() return MSCore end)

AddEventHandler('mscore:getCore', function(callback)
    if type(callback) == 'function' then callback(MSCore) end
end)

RegisterNetEvent('mscore:client:setPlayerData', function(data)
    local wasLoaded = playerData ~= nil
    playerData = type(data) == 'table' and data or nil
    TriggerEvent('mscore:client:playerDataChanged', MSUtils.Copy(playerData))
    if playerData and not wasLoaded then TriggerEvent('mscore:client:playerLoaded', MSUtils.Copy(playerData)) end
end)

RegisterNetEvent('mscore:client:clearPlayerData', function()
    local previous = playerData
    playerData = nil
    TriggerEvent('mscore:client:playerDataChanged', nil)
    if previous then TriggerEvent('mscore:client:playerUnloaded', MSUtils.Copy(previous)) end
end)

RegisterNetEvent('mscore:client:characters', function(characters, maximum, reason)
    availableCharacters = type(characters) == 'table' and characters or {}
    maximumCharacters = math.max(1, tonumber(maximum) or Config.MaxCharacters)
    TriggerEvent('mscore:client:charactersAvailable', MSUtils.Copy(availableCharacters), maximumCharacters, reason)
end)

RegisterNetEvent('mscore:client:characterRequired', function(maximum)
    maximumCharacters = math.max(1, tonumber(maximum) or Config.MaxCharacters)
    TriggerEvent('mscore:client:noCharacters', maximumCharacters)
    MSCore.Notify('Erstelle mit /mscreate Vorname Nachname male|female JJJJ-MM-TT deinen ersten Charakter.', 'info', 10000)
end)

RegisterNetEvent('mscore:client:notify', function(message, notificationType, duration)
    message = tostring(message or '')
    TriggerEvent('chat:addMessage', {
        color = notificationType == 'error' and { 220, 70, 70 } or notificationType == 'success' and { 70, 190, 100 } or { 230, 200, 120 },
        multiline = true,
        args = { 'MSCore', message }
    })
    TriggerEvent('mscore:client:notification', message, notificationType or 'info', duration or 5000)
end)

local function stopLoadingScreens()
    if type(ShutdownLoadingScreen) == 'function' then ShutdownLoadingScreen() end
    if type(ShutdownLoadingScreenNui) == 'function' then ShutdownLoadingScreenNui() end
    if type(SetNuiFocus) == 'function' then SetNuiFocus(false, false) end
    if type(ClearFocus) == 'function' then ClearFocus() end
    if type(RenderScriptCams) == 'function' then RenderScriptCams(false, false, 0, true, true) end
    if type(IsScreenFadedOut) == 'function' and IsScreenFadedOut() and type(DoScreenFadeIn) == 'function' then
        DoScreenFadeIn(500)
    end
end

local function bootstrap()
    if bootstrapped then return end
    bootstrapped = true
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
        stopLoadingScreens()
        TriggerServerEvent('mscore:server:bootstrap')
    end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then bootstrap() end
end)

CreateThread(bootstrap)
