MSCore = MSCore or {}

local registeredClientCallbacks = {}
local pendingServerCallbacks = {}
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

function MSCore.RegisterClientCallback(name, callback)
    assert(type(name) == 'string' and name ~= '', 'Callback-Name muss eine Zeichenkette sein.')
    assert(type(callback) == 'function', 'Callback muss eine Funktion sein.')
    registeredClientCallbacks[name] = callback
end

function MSCore.TriggerCallback(name, callback, ...)
    assert(type(name) == 'string' and name ~= '', 'Callback-Name muss eine Zeichenkette sein.')
    local requestId = nextRequestId()
    local entry = {
        name = name,
        callback = type(callback) == 'function' and callback or function() end
    }
    pendingServerCallbacks[requestId] = entry
    TriggerServerEvent('mscore:callback:server:request', requestId, name, ...)

    SetTimeout(math.max(1000, tonumber(Config.CallbackTimeoutMs) or 15000), function()
        if pendingServerCallbacks[requestId] ~= entry then return end
        pendingServerCallbacks[requestId] = nil
        entry.callback(nil, ('Server-Callback "%s" hat das Zeitlimit überschritten.'):format(name))
    end)
end

function MSCore.AwaitCallback(name, ...)
    local result = promise.new()
    local arguments = table.pack(...)
    MSCore.TriggerCallback(name, function(...)
        result:resolve(table.pack(...))
    end, table.unpack(arguments, 1, arguments.n))
    local values = Citizen.Await(result)
    return table.unpack(values, 1, values.n)
end

RegisterNetEvent('mscore:callback:server:result', function(requestId, ...)
    local entry = pendingServerCallbacks[tonumber(requestId)]
    if not entry then return end
    pendingServerCallbacks[requestId] = nil
    entry.callback(...)
end)

RegisterNetEvent('mscore:callback:client:request', function(requestId, name, ...)
    if type(requestId) ~= 'number' or type(name) ~= 'string' then return end
    local callback = registeredClientCallbacks[name]
    if not callback then
        return TriggerServerEvent(
            'mscore:callback:client:result',
            requestId,
            nil,
            ('Client-Callback "%s" ist nicht registriert.'):format(name)
        )
    end

    local replied = false
    local function reply(...)
        if replied then return end
        replied = true
        TriggerServerEvent('mscore:callback:client:result', requestId, ...)
    end

    local arguments = table.pack(...)
    local ok, errorMessage = xpcall(function()
        callback(reply, table.unpack(arguments, 1, arguments.n))
    end, traceback)
    if not ok then
        print(('[MSCore] Client-Callback "%s" fehlgeschlagen:\n%s'):format(name, errorMessage))
        reply(nil, 'Der Client-Callback konnte nicht verarbeitet werden.')
    end
end)
