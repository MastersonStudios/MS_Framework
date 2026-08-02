MSCallbacks = MSCallbacks or {}

local registeredServerCallbacks = {}
local pendingClientCallbacks = {}
local requestCounter = 0

local function nextRequestId()
    requestCounter = requestCounter + 1
    if requestCounter > 2147483647 then requestCounter = 1 end
    return requestCounter
end

local function traceback(errorMessage)
    return type(debug) == 'table' and type(debug.traceback) == 'function'
        and debug.traceback(tostring(errorMessage), 2)
        or tostring(errorMessage)
end

function MSCallbacks.RegisterServer(name, callback)
    assert(type(name) == 'string' and name ~= '', 'Callback-Name muss eine Zeichenkette sein.')
    assert(type(callback) == 'function', 'Callback muss eine Funktion sein.')
    registeredServerCallbacks[name] = {
        callback = callback,
        owner = GetInvokingResource() or GetCurrentResourceName()
    }
end

function MSCallbacks.TriggerClient(source, name, callback, ...)
    source = tonumber(source)
    assert(source and GetPlayerName(source), 'Ungültige Spielerquelle für Client-Callback.')
    assert(type(name) == 'string' and name ~= '', 'Callback-Name muss eine Zeichenkette sein.')

    local requestId = nextRequestId()
    local entry = {
        source = source,
        name = name,
        callback = type(callback) == 'function' and callback or function() end
    }
    pendingClientCallbacks[requestId] = entry
    TriggerClientEvent('mscore:callback:client:request', source, requestId, name, ...)

    SetTimeout(math.max(1000, tonumber(Config.CallbackTimeoutMs) or 15000), function()
        if pendingClientCallbacks[requestId] ~= entry then return end
        pendingClientCallbacks[requestId] = nil
        entry.callback(nil, ('Client-Callback "%s" hat das Zeitlimit überschritten.'):format(name))
    end)
end

RegisterNetEvent('mscore:callback:server:request', function(requestId, name, ...)
    local playerSource = source
    if type(requestId) ~= 'number' or type(name) ~= 'string' then return end

    local registration = registeredServerCallbacks[name]
    if not registration then
        return TriggerClientEvent(
            'mscore:callback:server:result',
            playerSource,
            requestId,
            nil,
            ('Server-Callback "%s" ist nicht registriert.'):format(name)
        )
    end

    local replied = false
    local function reply(...)
        if replied then return end
        replied = true
        TriggerClientEvent('mscore:callback:server:result', playerSource, requestId, ...)
    end

    local arguments = table.pack(...)
    SetTimeout(math.max(1000, tonumber(Config.CallbackTimeoutMs) or 15000), function()
        if replied then return end
        reply(nil, ('Server-Callback "%s" hat das Zeitlimit überschritten.'):format(name))
    end)

    CreateThread(function()
        local ok, errorMessage = xpcall(function()
            registration.callback(playerSource, reply, table.unpack(arguments, 1, arguments.n))
        end, traceback)
        if not ok then
            print(('[MSCore] Server-Callback "%s" fehlgeschlagen:\n%s'):format(name, errorMessage))
            reply(nil, 'Der Server-Callback konnte nicht verarbeitet werden.')
        end
    end)
end)

RegisterNetEvent('mscore:callback:client:result', function(requestId, ...)
    local entry = pendingClientCallbacks[tonumber(requestId)]
    if not entry or entry.source ~= source then return end
    pendingClientCallbacks[requestId] = nil
    entry.callback(...)
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    for requestId, entry in pairs(pendingClientCallbacks) do
        if entry.source == playerSource then
            pendingClientCallbacks[requestId] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    for name, registration in pairs(registeredServerCallbacks) do
        if registration.owner == resourceName then
            registeredServerCallbacks[name] = nil
        end
    end
end)
