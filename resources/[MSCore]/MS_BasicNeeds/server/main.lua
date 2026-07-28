local Config = MSBasicNeedsConfig
local TickCounts = {}
local WarningCounts = {}
local LastRequests = {}

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_BasicNeeds] ' .. message):format(...))
end

local function limits()
    local minimum = tonumber(Config.Minimum) or 0.0
    local maximum = tonumber(Config.Maximum) or 100.0
    if maximum <= minimum then maximum = minimum + 100.0 end
    return minimum, maximum
end

local function clamp(value)
    local minimum, maximum = limits()
    value = tonumber(value) or maximum
    value = math.max(minimum, math.min(maximum, value))
    return math.floor(value * 100 + 0.5) / 100
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function normalizedNeeds(player)
    if not player then return nil end
    local metadata = type(player.metadata) == 'table' and player.metadata or {}
    local defaults = type(Config.Defaults) == 'table' and Config.Defaults or {}
    local hunger = clamp(metadata.hunger ~= nil and metadata.hunger or defaults.hunger)
    local thirst = clamp(metadata.thirst ~= nil and metadata.thirst or defaults.thirst)
    return {
        hunger = hunger,
        thirst = thirst
    }
end

local function clientPayload(needs)
    local minimum, maximum = limits()
    return {
        hunger = needs.hunger,
        thirst = needs.thirst,
        minimum = minimum,
        maximum = maximum,
        criticalThreshold = clamp(
            type(Config.Critical) == 'table' and Config.Critical.Threshold or 20
        )
    }
end

local function publish(playerSource, player, needs, saveNow, reason)
    if not player or not needs then return false end
    needs.hunger = clamp(needs.hunger)
    needs.thirst = clamp(needs.thirst)

    if not player:setMetadataValues({
        hunger = needs.hunger,
        thirst = needs.thirst
    }) then
        return false
    end
    if saveNow == true then player:save() end

    local payload = clientPayload(needs)
    TriggerClientEvent('ms_basicneeds:client:update', playerSource, payload)
    TriggerEvent('ms_basicneeds:server:needsChanged', playerSource, payload, reason or 'unknown')
    debugLog(
        '%d -> hunger %.2f, thirst %.2f (%s)',
        playerSource,
        needs.hunger,
        needs.thirst,
        reason or 'unknown'
    )
    return true, payload
end

local function initializePlayer(playerSource, player)
    player = player or getPlayer(playerSource)
    if not player then return false end

    local needs = normalizedNeeds(player)
    local missing = player.metadata.hunger == nil or player.metadata.thirst == nil
    TickCounts[playerSource] = 0
    WarningCounts[playerSource] = 0
    return publish(playerSource, player, needs, missing, 'player_loaded')
end

function GetNeeds(playerSource)
    local needs = normalizedNeeds(getPlayer(playerSource))
    return needs and clientPayload(needs) or nil
end

function SetNeeds(playerSource, hunger, thirst, reason)
    playerSource = tonumber(playerSource)
    local player = playerSource and getPlayer(playerSource)
    local current = normalizedNeeds(player)
    if not player or not current then return false, 'Kein aktiver Charakter.' end
    if hunger ~= nil and tonumber(hunger) == nil then return false, 'Hungerwert ist ungültig.' end
    if thirst ~= nil and tonumber(thirst) == nil then return false, 'Durstwert ist ungültig.' end

    local updated = {
        hunger = hunger ~= nil and clamp(hunger) or current.hunger,
        thirst = thirst ~= nil and clamp(thirst) or current.thirst
    }
    return publish(playerSource, player, updated, true, reason or 'export_set')
end

function AddNeed(playerSource, needName, amount, reason)
    playerSource = tonumber(playerSource)
    needName = tostring(needName or ''):lower()
    amount = tonumber(amount)
    local player = playerSource and getPlayer(playerSource)
    local current = normalizedNeeds(player)
    if not player or not current then return false, 'Kein aktiver Charakter.' end
    if needName ~= 'hunger' and needName ~= 'thirst' then
        return false, 'Need muss hunger oder thirst sein.'
    end
    if not amount then return false, 'Betrag ist ungültig.' end

    current[needName] = clamp(current[needName] + amount)
    return publish(playerSource, player, current, true, reason or ('export_' .. needName))
end

exports('GetNeeds', GetNeeds)
exports('SetNeeds', SetNeeds)
exports('AddNeed', AddNeed)

RegisterNetEvent('ms_basicneeds:server:request', function()
    local playerSource = source
    local now = GetGameTimer()
    local cooldown = math.max(0, math.floor(tonumber(Config.RequestCooldownMs) or 1000))
    if LastRequests[playerSource] and now - LastRequests[playerSource] < cooldown then return end
    LastRequests[playerSource] = now

    local player = getPlayer(playerSource)
    if not player then return end
    local needs = normalizedNeeds(player)
    TriggerClientEvent('ms_basicneeds:client:update', playerSource, clientPayload(needs))
end)

AddEventHandler('ms_inventory:server:itemUsed', function(playerSource, itemName)
    if Config.Enabled ~= true then return end
    local effect = type(Config.Consumables) == 'table' and Config.Consumables[itemName]
    local player = effect and getPlayer(playerSource)
    local needs = normalizedNeeds(player)
    if not player or not needs or type(effect) ~= 'table' then return end

    needs.hunger = needs.hunger + (tonumber(effect.hunger) or 0)
    needs.thirst = needs.thirst + (tonumber(effect.thirst) or 0)
    publish(playerSource, player, needs, true, 'consumable:' .. tostring(itemName))
end)

AddEventHandler('mscore:server:playerLoaded', function(playerSource, player)
    initializePlayer(tonumber(playerSource), player)
end)

local function clearPlayer(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    TickCounts[playerSource] = nil
    WarningCounts[playerSource] = nil
    LastRequests[playerSource] = nil
    TriggerClientEvent('ms_basicneeds:client:reset', playerSource)
end

AddEventHandler('mscore:server:playerUnloaded', clearPlayer)
AddEventHandler('playerDropped', function()
    TickCounts[source] = nil
    WarningCounts[source] = nil
    LastRequests[source] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(500, function()
        for playerSource, player in pairs(exports.MSCore:GetPlayers() or {}) do
            initializePlayer(tonumber(playerSource), player)
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(math.max(1000, math.floor(tonumber(Config.TickIntervalMs) or 60000)))
        if Config.Enabled == true then
            for playerSource, player in pairs(exports.MSCore:GetPlayers() or {}) do
                playerSource = tonumber(playerSource)
                local needs = normalizedNeeds(player)
                if playerSource and needs then
                    local drain = type(Config.Drain) == 'table' and Config.Drain or {}
                    needs.hunger = needs.hunger - math.max(0, tonumber(drain.hunger) or 0)
                    needs.thirst = needs.thirst - math.max(0, tonumber(drain.thirst) or 0)

                    TickCounts[playerSource] = (TickCounts[playerSource] or 0) + 1
                    local saveEvery = math.max(0, math.floor(tonumber(Config.SaveEveryTicks) or 0))
                    local saveNow = saveEvery > 0 and TickCounts[playerSource] % saveEvery == 0
                    local _, payload = publish(playerSource, player, needs, saveNow, 'tick')

                    local critical = type(Config.Critical) == 'table' and Config.Critical or {}
                    local threshold = clamp(critical.Threshold or 20)
                    local hungerCritical = needs.hunger <= threshold
                    local thirstCritical = needs.thirst <= threshold
                    if hungerCritical or thirstCritical then
                        WarningCounts[playerSource] = (WarningCounts[playerSource] or 0) + 1
                        local interval = math.max(1, math.floor(
                            tonumber(critical.WarningIntervalTicks) or 5
                        ))
                        if WarningCounts[playerSource] == 1
                            or WarningCounts[playerSource] % interval == 0 then
                            local message = hungerCritical and thirstCritical and critical.BothMessage
                                or (hungerCritical and critical.HungerMessage or critical.ThirstMessage)
                            if type(message) == 'string' and message ~= '' then
                                TriggerClientEvent('mscore:client:notify', playerSource, message)
                            end
                        end
                    else
                        WarningCounts[playerSource] = 0
                    end

                    local damage = type(Config.Damage) == 'table' and Config.Damage or {}
                    local damageThreshold = clamp(damage.Threshold or 0)
                    if damage.Enabled == true
                        and (needs.hunger <= damageThreshold or needs.thirst <= damageThreshold) then
                        TriggerClientEvent('ms_basicneeds:client:damage', playerSource, {
                            amount = math.max(0, math.floor(tonumber(damage.AmountPerTick) or 0)),
                            canKill = damage.CanKill == true,
                            minimumHealth = math.max(
                                1,
                                math.floor(tonumber(damage.MinimumHealth) or 25)
                            ),
                            message = damage.Message,
                            needs = payload
                        })
                    end
                end
            end
        end
    end
end)
