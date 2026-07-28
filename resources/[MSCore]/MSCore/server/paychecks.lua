local PaycheckState = {}
local MetadataKey = 'paycheckDuty'
local PersistIntervalSeconds = 300
local DutyResources = {
    MS_BossMenu = true
}

local function paycheckSettings(player)
    if not player then return end
    local job = Config.Jobs[player.job]
    local grade = job and job.grades and job.grades[player.jobGrade]
    local intervalMinutes = job and tonumber(job.payIntervalMinutes)
    local salary = grade and tonumber(grade.salary)
    if not intervalMinutes or not salary then return end

    intervalMinutes = math.floor(intervalMinutes)
    salary = math.floor(salary)
    if intervalMinutes < 1 or intervalMinutes > 10080 or salary < 1 then return end

    local account = job.payAccount == 'cash' and 'cash' or 'bank'
    return {
        job = player.job,
        grade = player.jobGrade,
        intervalSeconds = intervalMinutes * 60,
        salary = salary,
        account = account,
        jobLabel = job.label or player.job,
        gradeLabel = grade.label or ('Grad %d'):format(player.jobGrade)
    }
end

local function stateMatches(state, player, settings)
    return state
        and state.characterId == player.characterId
        and state.job == settings.job
        and state.grade == settings.grade
end

local function persistState(player, state)
    if not player or not state then return end
    player.metadata[MetadataKey] = {
        job = state.job,
        grade = state.grade,
        workedSeconds = math.max(0, math.floor(tonumber(state.workedSeconds) or 0)),
        onDuty = state.onDuty == true
    }
    player.dirty = true
    state.persistedAt = os.time()
end

local function createState(source, player, settings, restoreProgress)
    source = tonumber(source)
    if not source or not player or not settings then return end

    local workedSeconds = 0
    local stored = player.metadata and player.metadata[MetadataKey]
    if restoreProgress
        and type(stored) == 'table'
        and stored.job == settings.job
        and tonumber(stored.grade) == settings.grade
    then
        workedSeconds = math.max(0, math.floor(tonumber(stored.workedSeconds) or 0))
        workedSeconds = workedSeconds % settings.intervalSeconds
    end

    local state = {
        characterId = player.characterId,
        job = settings.job,
        grade = settings.grade,
        onDuty = false,
        workedSeconds = workedSeconds,
        lastTickAt = nil,
        startedAt = nil,
        persistedAt = os.time()
    }
    PaycheckState[source] = state
    persistState(player, state)
    return state
end

local function ensureState(source, player, settings, restoreProgress)
    local state = PaycheckState[source]
    if stateMatches(state, player, settings) then return state end
    return createState(source, player, settings, restoreProgress)
end

local function accrueTime(state, currentTime)
    if not state or not state.onDuty then return end
    currentTime = currentTime or os.time()
    local lastTickAt = tonumber(state.lastTickAt) or currentTime
    if currentTime > lastTickAt then
        state.workedSeconds = state.workedSeconds + (currentTime - lastTickAt)
    end
    state.lastTickAt = currentTime
end

local function paySalary(source, player, settings, state)
    local paid = false
    while state.workedSeconds >= settings.intervalSeconds do
        if not player:addMoney(settings.account, settings.salary, 'on_duty_job_salary') then
            break
        end

        state.workedSeconds = state.workedSeconds - settings.intervalSeconds
        paid = true
        local destination = settings.account == 'bank'
            and 'auf dein Bankkonto'
            or 'als Bargeld'
        TriggerClientEvent(
            'mscore:client:notify',
            source,
            ('Dienstlohn: $%d für %s – %s %s.'):format(
                settings.salary,
                settings.jobLabel,
                settings.gradeLabel,
                destination
            )
        )
        TriggerEvent(
            'mscore:server:paycheckPaid',
            source,
            settings.salary,
            settings.account,
            settings.job,
            settings.grade
        )
    end
    return paid
end

local function processState(source, player, currentTime)
    local settings = paycheckSettings(player)
    if not settings then
        PaycheckState[source] = nil
        return
    end

    local state = ensureState(source, player, settings, true)
    accrueTime(state, currentTime)
    local paid = paySalary(source, player, settings, state)
    if paid or (state.onDuty and currentTime - state.persistedAt >= PersistIntervalSeconds) then
        persistState(player, state)
    end
    return settings, state
end

local function dutyPayload(source)
    source = tonumber(source)
    local player = source and GetPlayer(source)
    if not player then return end

    local currentTime = os.time()
    local settings, state = processState(source, player, currentTime)
    if not settings or not state then return end

    return {
        onDuty = state.onDuty,
        workedSeconds = math.max(0, math.floor(state.workedSeconds)),
        intervalSeconds = settings.intervalSeconds,
        remainingSeconds = math.max(0, settings.intervalSeconds - math.floor(state.workedSeconds)),
        salary = settings.salary,
        account = settings.account,
        job = settings.job,
        grade = settings.grade,
        jobLabel = settings.jobLabel,
        gradeLabel = settings.gradeLabel,
        startedAt = state.startedAt,
        serverTime = currentTime
    }
end

function GetDutyState(source)
    return dutyPayload(source)
end

function SetDutyState(source, desiredState)
    local invokingResource = GetInvokingResource()
    if not DutyResources[invokingResource] then
        return false, 'Diese Ressource darf den Dienststatus nicht ändern.'
    end

    source = tonumber(source)
    local player = source and GetPlayer(source)
    local settings = paycheckSettings(player)
    if not source or not player or not settings then
        return false, 'Für diesen Job ist keine Gehaltszahlung eingerichtet.'
    end

    local currentTime = os.time()
    local state = ensureState(source, player, settings, true)
    accrueTime(state, currentTime)
    local paid = paySalary(source, player, settings, state)

    local onDuty = desiredState == true
    if state.onDuty ~= onDuty then
        state.onDuty = onDuty
        state.lastTickAt = onDuty and currentTime or nil
        state.startedAt = onDuty and currentTime or nil
        persistState(player, state)
        player:save()
        TriggerEvent('mscore:server:dutyChanged', source, onDuty, settings.job, settings.grade)
    elseif paid then
        persistState(player, state)
        player:save()
    end

    return true, dutyPayload(source)
end

exports('GetDutyState', GetDutyState)
exports('SetDutyState', SetDutyState)

AddEventHandler('mscore:server:playerLoaded', function(source, player)
    local settings = paycheckSettings(player)
    if settings then
        createState(source, player, settings, true)
    end
end)

AddEventHandler('mscore:server:playerUnloaded', function(source, player)
    source = tonumber(source)
    local state = source and PaycheckState[source]
    if not source or not state then return end

    player = player or GetPlayer(source)
    local settings = paycheckSettings(player)
    if player and settings and stateMatches(state, player, settings) then
        local currentTime = os.time()
        accrueTime(state, currentTime)
        paySalary(source, player, settings, state)
        state.onDuty = false
        state.lastTickAt = nil
        state.startedAt = nil
        persistState(player, state)
        player:save()
    end
    PaycheckState[source] = nil
end)

AddEventHandler('mscore:server:jobChanged', function(source)
    source = tonumber(source)
    local player = source and GetPlayer(source)
    local settings = paycheckSettings(player)
    if settings then
        createState(source, player, settings, false)
    elseif source then
        PaycheckState[source] = nil
        if player then
            player.metadata[MetadataKey] = nil
            player.dirty = true
        end
    end
end)

CreateThread(function()
    while true do
        local interval = math.max(
            1000,
            math.min(60000, math.floor(tonumber(Config.PaycheckCheckIntervalMs) or 30000))
        )
        Wait(interval)

        local players = GetPlayers()
        local currentTime = os.time()
        for source, player in pairs(players) do
            processState(source, player, currentTime)
        end

        for source in pairs(PaycheckState) do
            if not players[source] then PaycheckState[source] = nil end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local currentTime = os.time()
    for source, player in pairs(GetPlayers()) do
        local settings = paycheckSettings(player)
        local state = PaycheckState[source]
        if settings and stateMatches(state, player, settings) then
            accrueTime(state, currentTime)
            paySalary(source, player, settings, state)
            state.onDuty = false
            state.lastTickAt = nil
            state.startedAt = nil
            persistState(player, state)
            player:save()
        end
    end
end)
