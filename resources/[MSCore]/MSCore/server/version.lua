local RESOURCE_NAME = GetCurrentResourceName()
local CURRENT_VERSION = GetResourceMetadata(RESOURCE_NAME, 'version', 0) or '0.0.0'
local Settings = Config.VersionCheck or {}

local VersionState = {
    current = CURRENT_VERSION,
    latest = nil,
    status = 'idle',
    updateAvailable = false,
    checkedAt = nil,
    error = nil,
    repositoryUrl = Settings.RepositoryUrl
}

local checkInProgress = false
local lastCheckAt = 0

local function log(message, ...)
    print(('[MSCore:version] ' .. message):format(...))
end

local function copyState()
    return {
        current = VersionState.current,
        latest = VersionState.latest,
        status = VersionState.status,
        updateAvailable = VersionState.updateAvailable,
        checkedAt = VersionState.checkedAt,
        error = VersionState.error,
        repositoryUrl = VersionState.repositoryUrl
    }
end

local function normalizeVersion(value)
    if type(value) ~= 'string' then return nil end

    local normalized = value:gsub('^%s+', ''):gsub('%s+$', ''):gsub('^[vV]', '')
    local major, minor, patch, suffix = normalized:match('^(%d+)%.(%d+)%.(%d+)(.*)$')
    if not major then return nil end
    if suffix ~= '' and not suffix:match('^%-[0-9A-Za-z%.%-]+$') then return nil end

    return ('%d.%d.%d%s'):format(
        tonumber(major),
        tonumber(minor),
        tonumber(patch),
        suffix
    )
end

local function splitPrerelease(value)
    local identifiers = {}
    for identifier in value:gmatch('[^%.]+') do
        identifiers[#identifiers + 1] = identifier
    end
    return identifiers
end

local function comparePrerelease(left, right)
    if left == right then return 0 end
    if left == '' then return 1 end
    if right == '' then return -1 end

    local leftParts = splitPrerelease(left:sub(2))
    local rightParts = splitPrerelease(right:sub(2))
    local length = math.max(#leftParts, #rightParts)

    for index = 1, length do
        local leftPart = leftParts[index]
        local rightPart = rightParts[index]

        if leftPart == nil then return -1 end
        if rightPart == nil then return 1 end

        if leftPart ~= rightPart then
            local leftNumber = leftPart:match('^%d+$') and tonumber(leftPart) or nil
            local rightNumber = rightPart:match('^%d+$') and tonumber(rightPart) or nil

            if leftNumber and rightNumber then
                return leftNumber < rightNumber and -1 or 1
            end
            if leftNumber then return -1 end
            if rightNumber then return 1 end
            return leftPart < rightPart and -1 or 1
        end
    end

    return 0
end

local function compareVersions(left, right)
    left = normalizeVersion(left)
    right = normalizeVersion(right)
    if not left or not right then return nil end

    local leftMajor, leftMinor, leftPatch, leftSuffix =
        left:match('^(%d+)%.(%d+)%.(%d+)(.*)$')
    local rightMajor, rightMinor, rightPatch, rightSuffix =
        right:match('^(%d+)%.(%d+)%.(%d+)(.*)$')

    local leftNumbers = { tonumber(leftMajor), tonumber(leftMinor), tonumber(leftPatch) }
    local rightNumbers = { tonumber(rightMajor), tonumber(rightMinor), tonumber(rightPatch) }

    for index = 1, 3 do
        if leftNumbers[index] ~= rightNumbers[index] then
            return leftNumbers[index] < rightNumbers[index] and -1 or 1
        end
    end

    return comparePrerelease(leftSuffix, rightSuffix)
end

local function finishCheck(status, latest, errorMessage)
    checkInProgress = false
    VersionState.status = status
    VersionState.latest = latest
    VersionState.error = errorMessage
    VersionState.checkedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    if status ~= 'success' then VersionState.updateAvailable = false end

    TriggerEvent('mscore:server:versionChecked', copyState())
end

local function checkForUpdates(force)
    if Settings.Enabled == false then
        VersionState.status = 'disabled'
        VersionState.updateAvailable = false
        VersionState.error = nil
        return false, 'disabled'
    end

    if checkInProgress then return false, 'in_progress' end

    local now = os.time()
    local minimumInterval = math.max(tonumber(Settings.MinimumIntervalMinutes) or 10, 1) * 60
    if not force and lastCheckAt > 0 and now - lastCheckAt < minimumInterval then
        return false, 'rate_limited'
    end

    local url = tostring(Settings.Url or '')
    if not url:match('^https://') then
        VersionState.status = 'error'
        VersionState.error = 'Die Versions-URL muss HTTPS verwenden.'
        log('%s', VersionState.error)
        return false, 'invalid_url'
    end

    checkInProgress = true
    lastCheckAt = now
    VersionState.status = 'checking'
    VersionState.error = nil

    PerformHttpRequest(url, function(statusCode, responseBody, _, requestError)
        if statusCode ~= 200 then
            local message = ('Versionsabfrage fehlgeschlagen (HTTP %s%s).'):format(
                tostring(statusCode),
                requestError and requestError ~= '' and (': ' .. tostring(requestError)) or ''
            )
            finishCheck('error', nil, message)
            log('%s Der Server läuft mit Version %s weiter.', message, CURRENT_VERSION)
            return
        end

        local decodedSuccessfully, remoteData = pcall(json.decode, responseBody or '')
        if not decodedSuccessfully or type(remoteData) ~= 'table' then
            local message = 'Die entfernte version.json ist ungültig.'
            finishCheck('error', nil, message)
            log('%s Der Server läuft mit Version %s weiter.', message, CURRENT_VERSION)
            return
        end

        local latestVersion = normalizeVersion(remoteData.version)
        local comparison = latestVersion and compareVersions(CURRENT_VERSION, latestVersion) or nil
        if not comparison then
            local message = 'Die entfernte Versionsnummer ist nicht semantisch gültig.'
            finishCheck('error', nil, message)
            log('%s Der Server läuft mit Version %s weiter.', message, CURRENT_VERSION)
            return
        end

        VersionState.updateAvailable = comparison < 0
        finishCheck('success', latestVersion, nil)

        if comparison < 0 then
            log('Update verfügbar: installiert %s, aktuell %s.', CURRENT_VERSION, latestVersion)
            log('Download: %s', tostring(Settings.RepositoryUrl or remoteData.repository or url))
        elseif comparison > 0 then
            log('Entwicklungsversion erkannt: installiert %s, veröffentlicht %s.',
                CURRENT_VERSION, latestVersion)
        else
            log('Version %s ist aktuell.', CURRENT_VERSION)
        end
    end, 'GET', '', {
        ['Accept'] = 'application/json',
        ['Cache-Control'] = 'no-cache',
        ['User-Agent'] = ('MSCore-Framework/%s'):format(CURRENT_VERSION)
    })

    return true, 'started'
end

local function reply(playerSource, message, isError)
    if playerSource == 0 then
        log('%s', message)
        return
    end

    TriggerClientEvent('chat:addMessage', playerSource, {
        color = isError and { 205, 70, 62 } or { 200, 164, 91 },
        args = { 'MSCore', message }
    })
end

function GetFrameworkVersion()
    return CURRENT_VERSION
end

function GetFrameworkVersionState()
    return copyState()
end

function CheckFrameworkVersion()
    return checkForUpdates(false)
end

MSCore.Version = CURRENT_VERSION
MSCore.GetVersion = GetFrameworkVersion
MSCore.GetVersionState = GetFrameworkVersionState

RegisterCommand('frameworkversion', function(playerSource, args)
    local action = tostring(args[1] or ''):lower()

    if action == 'check' then
        if playerSource ~= 0
            and not IsPlayerAceAllowed(
                playerSource,
                tostring(Settings.AdminAce or 'mscore.version.check')
            )
        then
            reply(playerSource, 'Keine Berechtigung für eine neue Versionsabfrage.', true)
            return
        end

        local started, reason = checkForUpdates(false)
        if started then
            reply(playerSource, 'Versionsabfrage wurde gestartet.')
        elseif reason == 'rate_limited' then
            reply(playerSource, 'Die Version wurde kürzlich geprüft. Bitte später erneut versuchen.', true)
        elseif reason == 'in_progress' then
            reply(playerSource, 'Eine Versionsabfrage läuft bereits.', true)
        elseif reason == 'disabled' then
            reply(playerSource, 'Die automatische Versionsabfrage ist deaktiviert.', true)
        else
            reply(playerSource, 'Die Versionsabfrage konnte nicht gestartet werden.', true)
        end
        return
    end

    local latestText = VersionState.latest and (' · GitHub: ' .. VersionState.latest) or ''
    local updateText = VersionState.updateAvailable and ' · Update verfügbar' or ''
    reply(playerSource, ('Installiert: %s%s%s'):format(CURRENT_VERSION, latestText, updateText))
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end

    log('MSCore Framework Version %s', CURRENT_VERSION)

    if Settings.Enabled == false then
        VersionState.status = 'disabled'
        log('Automatische Versionsabfrage ist deaktiviert.')
        return
    end

    SetTimeout(math.max(tonumber(Settings.DelayMs) or 2500, 0), function()
        checkForUpdates(false)
    end)
end)
