local ResourceName = GetCurrentResourceName()
local Records = {}
local Enabled = ResourceGuardConfig.Enabled ~= false
local StartedAt = os.time() * 1000
local LastCheckAt = 0
local LastSnapshot = nil

local function nowMs()
    return os.time() * 1000
end

local function clampInteger(value, fallback, minimum, maximum)
    value = tonumber(value)
    if not value then value = fallback end
    value = math.floor(value)
    return math.max(minimum, math.min(maximum, value))
end

local function listMap(values)
    local mapped = {}
    for _, value in ipairs(type(values) == 'table' and values or {}) do
        if type(value) == 'string' and value ~= '' then mapped[value] = true end
    end
    return mapped
end

local Expected = listMap(ResourceGuardConfig.ExpectedResources)
local Critical = listMap(ResourceGuardConfig.CriticalResources)
local Protected = listMap(ResourceGuardConfig.ProtectedResources)
local Allowed = listMap(ResourceGuardConfig.AllowedResources)
local Blocked = listMap(ResourceGuardConfig.BlockedResources)
Protected[ResourceName] = true

local function mapCount(values)
    local count = 0
    for _ in pairs(values) do count = count + 1 end
    return count
end

local function controlsAllowed()
    local invoking = GetInvokingResource and GetInvokingResource() or nil
    return invoking == nil or invoking == 'MS_AdminMenu' or invoking == ResourceName
end

local function configuredAutoStop(option)
    local config = type(ResourceGuardConfig.AutoStop) == 'table' and ResourceGuardConfig.AutoStop or {}
    return config.Enabled == true and config[option] == true
end

local function resourceExists(resource)
    if type(resource) ~= 'string' or resource == '' or #resource > 100 then return false end
    if not resource:match('^[%w_%.%-%[%]]+$') then return false end
    return GetResourceState(resource) ~= 'missing'
end

local function transitionCount(record, currentTime)
    local window = clampInteger(ResourceGuardConfig.TransitionWindowMs, 60000, 10000, 600000)
    local retained = {}
    for _, timestamp in ipairs(record.transitions or {}) do
        if currentTime - timestamp <= window then retained[#retained + 1] = timestamp end
    end
    record.transitions = retained
    return #retained
end

local function emitAlert(record, status, reason, force)
    local currentTime = nowMs()
    local cooldown = clampInteger(ResourceGuardConfig.AlertCooldownMs, 60000, 5000, 3600000)
    if not force
        and record.lastAlertStatus == status
        and currentTime - (record.lastAlertAt or 0) < cooldown then
        return
    end
    record.lastAlertStatus = status
    record.lastAlertAt = currentTime
    local alert = {
        resource = record.name,
        state = record.state,
        status = status,
        reason = reason,
        protected = record.protected == true,
        quarantined = record.quarantined == true,
        timestamp = os.time()
    }
    print(('[MS ResourceGuard] %s | %s | %s'):format(record.name, status, reason or '-'))
    TriggerEvent('ms_resourceguard:server:alert', alert)
end

local function stopResourceSafely(record, reason, actor)
    if record.protected then return false, 'Diese Resource ist geschützt.' end
    record.quarantined = true
    record.quarantineReason = reason or 'Manuell isoliert'
    record.quarantinedAt = os.time()
    record.quarantinedBy = actor or 'KI-Ressourcenwächter'
    record.confirmations = 0
    record.health = 0
    record.status = 'quarantined'
    record.reasons = { record.quarantineReason }
    LastSnapshot = nil

    local state = GetResourceState(record.name)
    if state ~= 'started' and state ~= 'starting' and state ~= 'stopping' then
        emitAlert(record, 'quarantined', record.quarantineReason, true)
        return true, 'Resource wurde in Quarantäne aufgenommen.'
    end

    local success, stopped = pcall(StopResource, record.name)
    if not success or stopped == false then
        record.quarantined = false
        return false, 'Resource konnte nicht gestoppt werden.'
    end
    record.lastAction = ('Gestoppt: %s'):format(record.quarantineReason)
    emitAlert(record, 'quarantined', record.quarantineReason, true)
    return true, 'Resource wurde gestoppt und unter Quarantäne gestellt.'
end

local function evaluate(record, currentTime)
    local reasons = {}
    local score = 100
    local transitionTotal = transitionCount(record, currentTime)
    local threshold = clampInteger(ResourceGuardConfig.TransitionThreshold, 10, 2, 50)
    local timeout = clampInteger(ResourceGuardConfig.StartingTimeoutMs, 45000, 5000, 600000)
    local allowedConfigured = mapCount(Allowed) > 0
    local stoppableReason = nil

    if record.quarantined then
        score = 0
        reasons[#reasons + 1] = record.quarantineReason or 'Resource steht unter Quarantäne.'
        if record.state == 'started' or record.state == 'starting' then
            stoppableReason = 'Aktive Quarantäne'
        end
    end

    if record.expected and record.state ~= 'started' then
        score = score - 45
        reasons[#reasons + 1] = 'Erwartete Resource läuft nicht.'
    end
    if record.critical and record.state ~= 'started' then
        score = score - 30
        reasons[#reasons + 1] = 'Kritische Framework-Resource ist nicht aktiv.'
    end
    if transitionTotal >= threshold then
        score = score - math.min(55, 20 + ((transitionTotal - threshold) * 5))
        reasons[#reasons + 1] = ('Ungewöhnlich viele Zustandswechsel: %d.'):format(transitionTotal)
        if configuredAutoStop('Flapping') and record.state == 'started' then
            stoppableReason = ('Instabile Resource (%d Wechsel)'):format(transitionTotal)
        end
    end
    if (record.state == 'starting' or record.state == 'stopping')
        and currentTime - record.stateSince >= timeout then
        score = score - 50
        reasons[#reasons + 1] = ('Resource hängt seit mindestens %d Sekunden im Zustand %s.'):format(
            math.floor(timeout / 1000),
            record.state
        )
        if configuredAutoStop('StuckTransitions') then
            stoppableReason = ('Festhängender Zustand: %s'):format(record.state)
        end
    end
    if Blocked[record.name] and (record.state == 'started' or record.state == 'starting') then
        score = 0
        reasons[#reasons + 1] = 'Resource ist in der Sperrliste eingetragen.'
        if configuredAutoStop('BlockedResources') then stoppableReason = 'Konfigurierte Sperrliste' end
    end
    if allowedConfigured and not Allowed[record.name] and not record.expected
        and (record.state == 'started' or record.state == 'starting') then
        score = score - 35
        reasons[#reasons + 1] = 'Resource ist nicht in der konfigurierten Freigabeliste.'
        if configuredAutoStop('UnknownResources') then stoppableReason = 'Nicht freigegebene Resource' end
    end

    score = math.max(0, math.min(100, score))
    local status = 'healthy'
    if record.quarantined then
        status = 'quarantined'
    elseif score < 40 then
        status = 'critical'
    elseif score < 80 then
        status = 'warning'
    end

    record.health = score
    record.status = status
    record.reasons = reasons
    record.transitionCount = transitionTotal

    local grace = clampInteger(ResourceGuardConfig.StartupGraceMs, 60000, 0, 600000)
    local mayAct = Enabled and currentTime - StartedAt >= grace and not record.protected
    if stoppableReason and mayAct then
        record.confirmations = (record.confirmations or 0) + 1
        local required = record.quarantined and 1
            or clampInteger(ResourceGuardConfig.UnstableConfirmations, 3, 1, 20)
        if record.confirmations >= required then
            local stopped = stopResourceSafely(record, stoppableReason, 'KI-Ressourcenwächter')
            if stopped then
                score = record.health
                status = record.status
                reasons = record.reasons
            end
        end
    else
        record.confirmations = 0
    end

    if status == 'healthy' then
        record.lastAlertStatus = nil
    elseif Enabled and currentTime - StartedAt >= grace then
        emitAlert(record, status, reasons[1] or 'Anomalie erkannt.', false)
    end
end

local function observeResource(resource, state, currentTime)
    local record = Records[resource]
    if not record then
        record = {
            name = resource,
            state = state,
            stateSince = currentTime,
            transitions = {},
            confirmations = 0
        }
        Records[resource] = record
    elseif state ~= record.state then
        record.state = state
        record.stateSince = currentTime
        record.transitions[#record.transitions + 1] = currentTime
    end
    record.expected = Expected[resource] == true
    record.critical = Critical[resource] == true
    record.protected = Protected[resource] == true
    LastSnapshot = nil
    return record
end

local function sampleResources()
    local currentTime = nowMs()
    local discovered = {}
    for index = 0, GetNumResources() - 1 do
        local resource = GetResourceByFindIndex(index)
        if resource then discovered[resource] = true end
    end
    for resource in pairs(Expected) do discovered[resource] = true end

    for resource in pairs(discovered) do
        local state = GetResourceState(resource)
        local record = observeResource(resource, state, currentTime)
        evaluate(record, currentTime)
    end

    local rows = {}
    local summary = {
        total = 0,
        started = 0,
        stopped = 0,
        warnings = 0,
        critical = 0,
        quarantined = 0
    }
    for _, record in pairs(Records) do
        summary.total = summary.total + 1
        if record.state == 'started' then summary.started = summary.started + 1
        else summary.stopped = summary.stopped + 1 end
        if record.status == 'warning' then summary.warnings = summary.warnings + 1 end
        if record.status == 'critical' then summary.critical = summary.critical + 1 end
        if record.status == 'quarantined' then summary.quarantined = summary.quarantined + 1 end
        rows[#rows + 1] = {
            name = record.name,
            state = record.state,
            stateSince = record.stateSince,
            health = record.health,
            status = record.status,
            reasons = record.reasons,
            transitionCount = record.transitionCount,
            confirmations = record.confirmations,
            expected = record.expected,
            critical = record.critical,
            protected = record.protected,
            quarantined = record.quarantined == true,
            quarantineReason = record.quarantineReason,
            quarantinedAt = record.quarantinedAt,
            quarantinedBy = record.quarantinedBy,
            lastAction = record.lastAction
        }
    end
    local priority = { quarantined = 1, critical = 2, warning = 3, healthy = 4 }
    table.sort(rows, function(a, b)
        local left, right = priority[a.status] or 9, priority[b.status] or 9
        if left == right then return a.name:lower() < b.name:lower() end
        return left < right
    end)

    LastCheckAt = currentTime
    LastSnapshot = {
        available = true,
        enabled = Enabled,
        autoStop = type(ResourceGuardConfig.AutoStop) == 'table'
            and ResourceGuardConfig.AutoStop.Enabled == true,
        generatedAt = currentTime,
        startupGraceRemainingMs = math.max(
            0,
            clampInteger(ResourceGuardConfig.StartupGraceMs, 60000, 0, 600000)
                - (currentTime - StartedAt)
        ),
        summary = summary,
        resources = rows
    }
    return LastSnapshot
end

local function getSnapshot()
    return LastSnapshot or sampleResources()
end

local function setEnabled(enabled)
    if not controlsAllowed() then return false, 'Controller nicht berechtigt.' end
    Enabled = enabled == true
    sampleResources()
    print(('[MS ResourceGuard] Passive Überwachung %s.'):format(Enabled and 'aktiviert' or 'deaktiviert'))
    return true, Enabled and 'Überwachung aktiviert.' or 'Überwachung deaktiviert.'
end

local function quarantineResource(resource, actor)
    if not controlsAllowed() then return false, 'Controller nicht berechtigt.' end
    if not resourceExists(resource) then return false, 'Resource wurde nicht gefunden.' end
    sampleResources()
    local record = Records[resource]
    if not record then return false, 'Resource konnte nicht analysiert werden.' end
    return stopResourceSafely(record, 'Manuelle ACP-Quarantäne', actor or 'ACP')
end

local function releaseResource(resource, actor)
    if not controlsAllowed() then return false, 'Controller nicht berechtigt.' end
    local record = Records[resource]
    if not record or not record.quarantined then return false, 'Resource steht nicht unter Quarantäne.' end
    record.quarantined = false
    record.quarantineReason = nil
    record.quarantinedAt = nil
    record.quarantinedBy = nil
    record.lastAction = ('Quarantäne aufgehoben von %s'):format(actor or 'ACP')
    record.confirmations = 0
    LastSnapshot = nil
    sampleResources()
    return true, 'Quarantäne wurde aufgehoben. Die Resource wird nicht automatisch gestartet.'
end

exports('GetSnapshot', getSnapshot)
exports('RunCheck', sampleResources)
exports('SetEnabled', setEnabled)
exports('QuarantineResource', quarantineResource)
exports('ReleaseResource', releaseResource)

local function commandReply(source, message)
    print(('[MS ResourceGuard] %s'):format(message))
    if source == 0 then return end
    TriggerClientEvent('chat:addMessage', source, {
        color = { 227, 190, 123 },
        args = { 'MS ResourceGuard', message }
    })
end

RegisterCommand('resourceguard', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, ResourceGuardConfig.CommandPermission) then
        return commandReply(source, 'Keine Berechtigung.')
    end
    local action = tostring(args[1] or 'status'):lower()
    if action == 'status' then
        local snapshot = sampleResources()
        commandReply(source, ('Aktiv: %s | Gestartet: %d/%d | Warnungen: %d | Kritisch: %d | Quarantäne: %d'):format(
            tostring(snapshot.enabled),
            snapshot.summary.started,
            snapshot.summary.total,
            snapshot.summary.warnings,
            snapshot.summary.critical,
            snapshot.summary.quarantined
        ))
        return
    end
    if action == 'enable' or action == 'disable' then
        local success, message = setEnabled(action == 'enable')
        commandReply(source, message)
        return
    end
    if action == 'quarantine' then
        local success, message = quarantineResource(args[2], source == 0 and 'Konsole' or GetPlayerName(source))
        commandReply(source, message)
        return
    end
    if action == 'release' then
        local success, message = releaseResource(args[2], source == 0 and 'Konsole' or GetPlayerName(source))
        commandReply(source, message)
        return
    end
    commandReply(source, 'Verwendung: resourceguard status|enable|disable|quarantine <Resource>|release <Resource>')
end, false)

AddEventHandler('onResourceStart', function(resource)
    if resource == ResourceName then return end
    local record = observeResource(resource, 'started', nowMs())
    if not record or not record.quarantined or record.protected then return end
    SetTimeout(0, function()
        record.state = GetResourceState(resource)
        stopResourceSafely(record, record.quarantineReason or 'Aktive Quarantäne', 'KI-Ressourcenwächter')
    end)
end)

AddEventHandler('onResourceStarting', function(resource)
    if resource == ResourceName then return end
    local record = Records[resource]
    if record and record.quarantined and not record.protected then
        CancelEvent()
        emitAlert(record, 'quarantined', record.quarantineReason or 'Aktive Quarantäne', false)
        return
    end
    observeResource(resource, 'starting', nowMs())
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == ResourceName then return end
    observeResource(resource, 'stopping', nowMs())
end)

CreateThread(function()
    Wait(1000)
    sampleResources()
    while true do
        Wait(clampInteger(ResourceGuardConfig.CheckIntervalMs, 5000, 1000, 60000))
        if Enabled then sampleResources() end
    end
end)
