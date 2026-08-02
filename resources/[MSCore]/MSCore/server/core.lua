MSCore = MSCore or {}

MSCore.Name = 'MSCore'
MSCore.Version = Config.Version
MSCore.Players = MSCore.Players or {}
MSCore.IdentifierOwners = MSCore.IdentifierOwners or {}
MSCore.Jobs = MSCore.Jobs or {}
MSCore.Player = MSPlayer
MSCore.Character = MSCharacter

local function normalizeGrade(gradeId, definition)
    local numericGrade = tonumber(gradeId)
    if not numericGrade or numericGrade < 0 or numericGrade % 1 ~= 0 or type(definition) ~= 'table' then
        return nil
    end
    return numericGrade, {
        label = tostring(definition.label or ('Grad %d'):format(numericGrade)),
        salary = math.max(0, MSUtils.RoundMoney(definition.salary or 0))
    }
end

function MSCore.Log(level, message, ...)
    level = tostring(level or 'info'):upper()
    local ok, formatted = pcall(string.format, tostring(message or ''), ...)
    print(('[MSCore:%s] %s'):format(level, ok and formatted or tostring(message)))
end

function MSCore.GetIdentifier(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return nil end
    local wantedType = tostring(Config.IdentifierType or 'license'):lower()
    local prefix = wantedType .. ':'

    for _, identifier in ipairs(GetPlayerIdentifiers(playerSource) or {}) do
        if identifier:sub(1, #prefix):lower() == prefix then
            return identifier
        end
    end
    return nil
end

function MSCore.GetPlayer(playerSource)
    return MSCore.Players[tonumber(playerSource)]
end

function MSCore.GetPlayers()
    local players = {}
    for playerSource, player in pairs(MSCore.Players) do
        players[playerSource] = player
    end
    return players
end

function MSCore.GetPlayerByCharacterId(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end
    for _, player in pairs(MSCore.Players) do
        if player.activeCharacterId == characterId then return player end
    end
    return nil
end

function MSCore.RegisterJob(jobName, definition, resourceName)
    jobName = MSUtils.Trim(tostring(jobName or '')):lower()
    if jobName == '' or #jobName > 64 or jobName:find('[^%w_%-]') then
        return false, 'Ungültiger Jobname.'
    end
    if type(definition) ~= 'table' or type(definition.grades) ~= 'table' then
        return false, 'Der Job benötigt mindestens einen Grad.'
    end

    local grades = {}
    for gradeId, gradeDefinition in pairs(definition.grades) do
        local numericGrade, normalized = normalizeGrade(gradeId, gradeDefinition)
        if numericGrade then grades[numericGrade] = normalized end
    end
    if next(grades) == nil then return false, 'Der Job enthält keine gültigen Grade.' end

    local job = {
        name = jobName,
        label = tostring(definition.label or jobName),
        grades = grades,
        owner = resourceName or GetInvokingResource() or GetCurrentResourceName()
    }
    MSCore.Jobs[jobName] = job
    Config.Jobs[jobName] = job
    TriggerEvent('mscore:server:jobRegistered', jobName, MSUtils.Copy(job))
    return true, job
end

function MSCore.GetJob(jobName)
    return MSCore.Jobs[tostring(jobName or ''):lower()]
end

function MSCore.IsAdmin(playerSource)
    playerSource = tonumber(playerSource)
    if playerSource == 0 then return true end
    if not playerSource or not GetPlayerName(playerSource) then return false end
    if IsPlayerAceAllowed(playerSource, tostring(Config.AdminAce or 'mscore.admin')) then return true end
    local player = MSCore.GetPlayer(playerSource)
    return player ~= nil and (player.group == 'admin' or player.group == 'superadmin')
end

function MSCore.Notify(playerSource, message, notificationType, duration)
    playerSource = tonumber(playerSource)
    if not playerSource or not GetPlayerName(playerSource) then return false end
    TriggerClientEvent(
        'mscore:client:notify',
        playerSource,
        tostring(message or ''),
        tostring(notificationType or 'info'),
        math.max(1000, tonumber(duration) or 5000)
    )
    return true
end

function MSCore.RegisterCallback(name, callback)
    return MSCallbacks.RegisterServer(name, callback)
end

function MSCore.TriggerClientCallback(playerSource, name, callback, ...)
    return MSCallbacks.TriggerClient(playerSource, name, callback, ...)
end

for jobName, definition in pairs(Config.Jobs or {}) do
    local success, errorMessage = MSCore.RegisterJob(jobName, definition, GetCurrentResourceName())
    if not success then MSCore.Log('error', 'Job %s konnte nicht registriert werden: %s', jobName, errorMessage) end
end

exports('GetCore', function() return MSCore end)
exports('GetPlayer', function(playerSource) return MSCore.GetPlayer(playerSource) end)
exports('GetPlayers', function() return MSCore.GetPlayers() end)
exports('RegisterJob', function(jobName, definition) return MSCore.RegisterJob(jobName, definition) end)

AddEventHandler('mscore:getCore', function(callback)
    if type(callback) == 'function' then callback(MSCore) end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    for jobName, job in pairs(MSCore.Jobs) do
        if job.owner == resourceName then
            MSCore.Jobs[jobName] = nil
            Config.Jobs[jobName] = nil
        end
    end
end)
