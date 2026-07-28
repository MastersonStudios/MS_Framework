local PlatformRegisterKeyMapping = RegisterKeyMapping
local RegisterKeyMapping = type(PlatformRegisterKeyMapping) == 'function'
    and PlatformRegisterKeyMapping
    or function(...) return exports.MSCore:RegisterKeyMappingCompat(...) end

local Config = MSBossMenuConfig
local PlayerData = {}
local MenuOpen = false
local NearestPoint
local PendingPoint
local CurrentPoint
local LastPromptKey = false

local function distance(coords, target)
    local dx = coords.x - (tonumber(target.x) or 0.0)
    local dy = coords.y - (tonumber(target.y) or 0.0)
    local dz = coords.z - (tonumber(target.z) or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function configuredJob()
    local job = type(PlayerData.job) == 'string'
        and type(Config.Jobs) == 'table'
        and Config.Jobs[PlayerData.job]
        or nil
    if not job
        or (tonumber(PlayerData.jobGrade) or -1) < math.max(
            0,
            math.floor(tonumber(job.dutyGrade) or 0)
        ) then
        return nil
    end
    return job
end

local function otherUiIsOpen()
    local checks = {
        { resource = 'MS_Banking', export = 'IsBankOpen' },
        { resource = 'MS_Inventory', export = 'IsUiOpen' },
        { resource = 'MS_AdminMenu', export = 'IsUiOpen' },
        { resource = 'MS_ClothingShop', export = 'IsShopOpen' },
        { resource = 'MS_Telegrams', export = 'IsTelegramOpen' },
        { resource = 'MS_Trains', export = 'IsTrainMenuOpen' },
        { resource = 'MS_Crime', export = 'IsCrimeUiOpen' },
        { resource = 'MS_Medic', export = 'IsMedicMenuOpen' }
    }
    for _, check in ipairs(checks) do
        if GetResourceState(check.resource) == 'started' then
            local success, open = pcall(function()
                return exports[check.resource][check.export]()
            end)
            if success and open == true then return true end
        end
    end
    return false
end

local function setPrompt(point)
    local key = point and ('%s:%d'):format(point.job, point.index) or false
    if LastPromptKey == key then return end
    LastPromptKey = key
    SendNUIMessage({
        action = 'prompt',
        visible = point ~= nil,
        key = tostring(Config.InteractionKey or 'E'),
        label = point and point.label or nil
    })
end

local function closeMenu(notifyServer)
    if not MenuOpen then return end
    MenuOpen = false
    CurrentPoint = nil
    PendingPoint = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if notifyServer ~= false then TriggerServerEvent('ms_bossmenu:server:close') end
end

local function openNearestPoint()
    if MenuOpen then return end
    if not NearestPoint then
        return TriggerEvent('mscore:client:notify', 'Du bist bei keinem Dienstpunkt.')
    end
    if otherUiIsOpen() then
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst das andere Menü.')
    end
    PendingPoint = NearestPoint
    TriggerServerEvent(
        'ms_bossmenu:server:open',
        NearestPoint.job,
        NearestPoint.index
    )
end

RegisterCommand('+ms_bossmenu_interact', openNearestPoint, false)
RegisterCommand('-ms_bossmenu_interact', function() end, false)
RegisterKeyMapping(
    '+ms_bossmenu_interact',
    'Dienst- und Boss-Menü benutzen',
    'keyboard',
    Config.InteractionKey or 'E'
)

RegisterNetEvent('ms_bossmenu:client:open', function(data)
    if type(data) ~= 'table' or MenuOpen then return end
    if otherUiIsOpen() then
        PendingPoint = nil
        TriggerServerEvent('ms_bossmenu:server:close')
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst das andere Menü.')
    end
    MenuOpen = true
    CurrentPoint = PendingPoint
    PendingPoint = nil
    setPrompt(nil)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('ms_bossmenu:client:refresh', function(data)
    if MenuOpen and type(data) == 'table' then
        SendNUIMessage({ action = 'refresh', data = data })
    end
end)

RegisterNetEvent('ms_bossmenu:client:result', function(data)
    local message = type(data) == 'table' and data.message or 'Aktion verarbeitet.'
    if MenuOpen then
        SendNUIMessage({
            action = 'result',
            success = type(data) == 'table' and data.success == true,
            message = message
        })
    else
        TriggerEvent('mscore:client:notify', message)
    end
end)

RegisterNetEvent('ms_bossmenu:client:close', function()
    closeMenu(false)
end)

RegisterNetEvent('mscore:client:setPlayerData', function(data)
    PlayerData = type(data) == 'table' and data or {}
    if MenuOpen and not configuredJob() then closeMenu(true) end
end)

RegisterNetEvent('mscore:client:clearPlayerData', function()
    PlayerData = {}
    NearestPoint = nil
    setPrompt(nil)
    closeMenu(false)
end)

RegisterNetEvent('mscore:client:playerDataChanged', function(data)
    PlayerData = type(data) == 'table' and data or {}
end)

RegisterNUICallback('close', function(_, callback)
    closeMenu(true)
    callback({ ok = true })
end)

RegisterNUICallback('refresh', function(_, callback)
    if MenuOpen then TriggerServerEvent('ms_bossmenu:server:refresh') end
    callback({ ok = MenuOpen })
end)

RegisterNUICallback('toggleDuty', function(data, callback)
    local desiredState = type(data) == 'table' and data.onDuty == true
    if MenuOpen then
        TriggerServerEvent('ms_bossmenu:server:toggleDuty', desiredState)
    end
    callback({ ok = MenuOpen })
end)

RegisterNUICallback('hire', function(data, callback)
    local targetSource = type(data) == 'table' and tonumber(data.source)
    if MenuOpen and targetSource then
        TriggerServerEvent('ms_bossmenu:server:hire', targetSource)
    end
    callback({ ok = MenuOpen and targetSource ~= nil })
end)

RegisterNUICallback('fire', function(data, callback)
    local characterId = type(data) == 'table' and tonumber(data.characterId)
    if MenuOpen and characterId then
        TriggerServerEvent('ms_bossmenu:server:fire', characterId)
    end
    callback({ ok = MenuOpen and characterId ~= nil })
end)

RegisterNUICallback('companyOperation', function(data, callback)
    local operation = type(data) == 'table' and tostring(data.operation or '') or ''
    local amount = type(data) == 'table' and tonumber(data.amount)
    local valid = MenuOpen
        and (operation == 'deposit' or operation == 'withdraw')
        and amount ~= nil
    if valid then
        TriggerServerEvent('ms_bossmenu:server:companyOperation', operation, amount)
    end
    callback({ ok = valid })
end)

CreateThread(function()
    Wait(500)
    local data = exports.MSCore:GetPlayerData()
    PlayerData = type(data) == 'table' and data or {}

    while true do
        local waitTime = 450
        local job = configuredJob()
        if not MenuOpen
            and job
            and type(job.points) == 'table'
            and not IsEntityDead(PlayerPedId()) then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for pointIndex, point in ipairs(job.points) do
                if point and point.coords then
                    local pointDistance = distance(coords, point.coords)
                    if Config.Marker.Enabled == true
                        and pointDistance <= math.max(
                            Config.InteractionDistance,
                            tonumber(Config.DrawDistance) or 18.0
                        ) then
                        local marker = Config.Marker
                        local scale = marker.Scale or vector3(0.45, 0.45, 0.28)
                        local color = marker.Color or {}
                        DrawMarker(
                            tonumber(marker.Type) or -1795314153,
                            point.coords.x,
                            point.coords.y,
                            point.coords.z + (tonumber(marker.HeightOffset) or 0.12),
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            tonumber(scale.x) or 0.45,
                            tonumber(scale.y) or 0.45,
                            tonumber(scale.z) or 0.28,
                            tonumber(color.r) or 199,
                            tonumber(color.g) or 154,
                            tonumber(color.b) or 75,
                            tonumber(color.a) or 175,
                            false, true, 2, false, nil, nil, false
                        )
                        waitTime = 0
                    end
                    if pointDistance <= math.max(
                        0.5,
                        tonumber(Config.InteractionDistance) or 2.0
                    ) and (not nearestDistance or pointDistance < nearestDistance) then
                        nearest = {
                            job = PlayerData.job,
                            index = pointIndex,
                            label = tostring(point.label or job.label or PlayerData.job),
                            coords = point.coords
                        }
                        nearestDistance = pointDistance
                    end
                end
            end
            NearestPoint = nearest
        else
            NearestPoint = nil
        end

        if MenuOpen then
            setPrompt(nil)
            if CurrentPoint and distance(
                GetEntityCoords(PlayerPedId()),
                CurrentPoint.coords
            ) > math.max(1.0, tonumber(Config.ServerInteractionDistance) or 5.0) then
                closeMenu(true)
                TriggerEvent('mscore:client:notify', 'Du hast den Dienstpunkt verlassen.')
            end
            waitTime = math.min(waitTime, 200)
        else
            setPrompt(NearestPoint)
        end
        Wait(waitTime)
    end
end)

AddEventHandler('mscore:client:prepareLogout', function()
    NearestPoint = nil
    setPrompt(nil)
    closeMenu(false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)

function IsBossMenuOpen()
    return MenuOpen
end

exports('IsBossMenuOpen', IsBossMenuOpen)
