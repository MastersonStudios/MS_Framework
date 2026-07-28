local Config = MSBossMenuConfig
local Sessions = {}
local LastActions = {}
local ManagedCharacters = {}

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_BossMenu] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function notify(playerSource, message)
    TriggerClientEvent('mscore:client:notify', playerSource, tostring(message))
end

local function jobConfig(jobName)
    return type(jobName) == 'string'
        and type(Config.Jobs) == 'table'
        and Config.Jobs[jobName]
        or nil
end

local function pointConfig(job, pointIndex)
    pointIndex = math.floor(tonumber(pointIndex) or 0)
    return type(job) == 'table'
        and type(job.points) == 'table'
        and job.points[pointIndex]
        or nil
end

local function coordsPayload(coords)
    if not coords then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z }
end

local function distanceToPoint(playerSource, point)
    local ped = GetPlayerPed(playerSource)
    local target = point and coordsPayload(point.coords or point)
    if not ped or ped == 0 or not target then return math.huge end
    local coords = GetEntityCoords(ped)
    local dx, dy, dz = coords.x - target.x, coords.y - target.y, coords.z - target.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function playerIsAlive(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return false end
    return not (
        (type(IsEntityDead) == 'function' and IsEntityDead(ped))
        or (tonumber(GetEntityHealth(ped)) or 0) <= 0
    )
end

local function playerDistance(firstSource, secondSource)
    local firstPed, secondPed = GetPlayerPed(firstSource), GetPlayerPed(secondSource)
    if not firstPed or firstPed == 0 or not secondPed or secondPed == 0 then
        return math.huge
    end
    local first, second = GetEntityCoords(firstPed), GetEntityCoords(secondPed)
    local dx, dy, dz = first.x - second.x, first.y - second.y, first.z - second.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function bossAccess(player, job)
    return player
        and type(job) == 'table'
        and player.job ~= nil
        and (tonumber(player.jobGrade) or -1) >= math.max(
            0,
            math.floor(tonumber(job.bossGrade) or 0)
        )
end

local function dutyAccess(player, job)
    return player
        and type(job) == 'table'
        and player.job ~= nil
        and (tonumber(player.jobGrade) or -1) >= math.max(
            0,
            math.floor(tonumber(job.dutyGrade) or 0)
        )
end

local function closeBankingSession(playerSource)
    if GetResourceState('MS_Banking') ~= 'started' then return end
    pcall(function()
        exports.MS_Banking:CloseCompanySession(playerSource)
    end)
end

local function closeSession(playerSource, reason, tellClient)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    Sessions[playerSource] = nil
    closeBankingSession(playerSource)
    if tellClient ~= false then
        TriggerClientEvent('ms_bossmenu:client:close', playerSource, {
            reason = tostring(reason or 'closed')
        })
    end
end

local function activeSession(playerSource)
    playerSource = tonumber(playerSource)
    local session = playerSource and Sessions[playerSource]
    local player = playerSource and getPlayer(playerSource)
    local job = player and jobConfig(player.job)
    local point = session and job and pointConfig(job, session.pointIndex)
    if not session or not player or not job or not point
        or session.characterId ~= player.characterId
        or session.job ~= player.job
        or not dutyAccess(player, job)
        or not playerIsAlive(playerSource)
        or distanceToPoint(playerSource, point) > math.max(
            1.0,
            tonumber(Config.ServerInteractionDistance) or 5.0
        ) then
        if playerSource and session then closeSession(playerSource, 'access_lost', true) end
        return nil, nil, nil, nil
    end
    return session, player, job, point
end

local function actionAllowed(playerSource, action)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local cooldown = math.max(100, math.floor(tonumber(Config.ActionCooldownMs) or 800))
    if LastActions[key] and now - LastActions[key] < cooldown then return false end
    LastActions[key] = now
    return true
end

local function onlineSourceForCharacter(characterId)
    local player = exports.MSCore:GetPlayerFromCharacterId(characterId)
    return player and tonumber(player.source) or nil
end

local function employeeRows(player, job)
    local limit = math.max(1, math.min(
        500,
        math.floor(tonumber(Config.EmployeeLimit) or 200)
    ))
    local rows = MySQL.query.await(([[
        SELECT id, firstname, lastname, job_grade
        FROM mscore_characters
        WHERE job = ? AND is_deleted = 0
        ORDER BY job_grade DESC, lastname ASC, firstname ASC
        LIMIT %d
    ]]):format(limit), { player.job }) or {}
    local employees = {}
    local actorGrade = math.floor(tonumber(player.jobGrade) or 0)
    for _, row in ipairs(rows) do
        local characterId = tonumber(row.id)
        local grade = math.floor(tonumber(row.job_grade) or 0)
        local isSelf = characterId == tonumber(player.characterId)
        local manageable = (Config.AllowSelfFire == true or not isSelf)
            and (Config.AllowManageSameGrade == true or grade < actorGrade)
        employees[#employees + 1] = {
            characterId = characterId,
            name = ('%s %s'):format(
                tostring(row.firstname or ''),
                tostring(row.lastname or '')
            ),
            grade = grade,
            isBoss = grade >= math.max(0, math.floor(tonumber(job.bossGrade) or 0)),
            isSelf = isSelf,
            online = onlineSourceForCharacter(characterId) ~= nil,
            manageable = manageable
        }
    end
    return employees
end

local function nearbyCandidates(playerSource, player)
    local candidates = {}
    local maximumDistance = math.max(1.0, tonumber(Config.HireDistance) or 5.0)
    local requireUnemployed = Config.RequireUnemployedForHire == true
    local unemployedJob = tostring(Config.UnemployedJob or 'unemployed')
    local actorBucket = GetPlayerRoutingBucket(playerSource)
    for targetSource, target in pairs(exports.MSCore:GetPlayers() or {}) do
        targetSource = tonumber(targetSource)
        if targetSource and targetSource ~= playerSource
            and target
            and GetPlayerRoutingBucket(targetSource) == actorBucket then
            local distance = playerDistance(playerSource, targetSource)
            local available = not requireUnemployed or target.job == unemployedJob
            if available and distance <= maximumDistance then
                candidates[#candidates + 1] = {
                    source = targetSource,
                    characterId = tonumber(target.characterId),
                    name = target:getName(),
                    currentJob = tostring(target.job or unemployedJob),
                    distance = math.floor(distance * 10 + 0.5) / 10
                }
            end
        end
    end
    table.sort(candidates, function(first, second)
        if first.distance == second.distance then return first.name < second.name end
        return first.distance < second.distance
    end)
    return candidates
end

local function companyAccount(jobName)
    if GetResourceState('MS_Banking') ~= 'started' then return nil end
    local success, account = pcall(function()
        return exports.MS_Banking:GetCompanyAccount(jobName)
    end)
    return success and account or nil
end

local function menuPayload(playerSource, player, job, point)
    local canManage = bossAccess(player, job)
    local account = canManage and companyAccount(player.job) or nil
    local duty
    local dutyRead = pcall(function()
        duty = exports.MSCore:GetDutyState(playerSource)
    end)
    if not dutyRead then duty = nil end
    return {
        job = {
            name = player.job,
            label = tostring(job.label or player.job),
            dutyGrade = math.max(0, math.floor(tonumber(job.dutyGrade) or 0)),
            bossGrade = math.max(0, math.floor(tonumber(job.bossGrade) or 0)),
            hireGrade = math.max(0, math.floor(tonumber(job.hireGrade) or 0))
        },
        boss = {
            characterId = tonumber(player.characterId),
            name = player:getName(),
            grade = math.floor(tonumber(player.jobGrade) or 0),
            cash = tonumber(player.money and player.money.cash) or 0
        },
        point = {
            label = tostring(point.label or job.label or player.job)
        },
        duty = duty,
        permissions = {
            manage = canManage
        },
        employees = canManage and employeeRows(player, job) or {},
        candidates = canManage and nearbyCandidates(playerSource, player) or {},
        company = account,
        settings = {
            currency = '$',
            hireDistance = math.max(1.0, tonumber(Config.HireDistance) or 5.0),
            requireUnemployed = Config.RequireUnemployedForHire == true
        }
    }
end

local function refreshMenu(playerSource)
    local _, player, job, point = activeSession(playerSource)
    if not player then return false end
    TriggerClientEvent(
        'ms_bossmenu:client:refresh',
        playerSource,
        menuPayload(playerSource, player, job, point)
    )
    return true
end

local function sendResult(playerSource, success, message, refresh)
    TriggerClientEvent('ms_bossmenu:client:result', playerSource, {
        success = success == true,
        message = tostring(message or 'Aktion verarbeitet.')
    })
    if refresh == true then refreshMenu(playerSource) end
end

RegisterNetEvent('ms_bossmenu:server:open', function(jobName, pointIndex)
    local playerSource = source
    local player = getPlayer(playerSource)
    local job = player and jobConfig(player.job)
    pointIndex = math.floor(tonumber(pointIndex) or 0)
    local point = job and pointConfig(job, pointIndex)
    if not player or player.job ~= tostring(jobName or '') or not job or not point then
        return notify(playerSource, 'Dieser Dienstpunkt ist nicht verfügbar.')
    end
    if not dutyAccess(player, job) then
        return notify(playerSource, 'Dein Jobgrad darf dieses Dienstmenü nicht öffnen.')
    end
    if not playerIsAlive(playerSource) then
        return notify(playerSource, 'Du kannst das Dienstmenü in diesem Zustand nicht öffnen.')
    end
    if distanceToPoint(playerSource, point) > math.max(
        1.0,
        tonumber(Config.ServerInteractionDistance) or 5.0
    ) then
        return notify(playerSource, 'Du bist zu weit vom Dienstpunkt entfernt.')
    end

    if bossAccess(player, job) and GetResourceState('MS_Banking') == 'started' then
        local coords = coordsPayload(point.coords)
        local called, opened, errorMessage = pcall(function()
            return exports.MS_Banking:OpenCompanySession(
                playerSource,
                player.job,
                coords,
                Config.ServerInteractionDistance,
                Config.SessionDurationMs
            )
        end)
        if not called or opened ~= true then
            notify(
                playerSource,
                tostring(errorMessage or 'Das Firmenkonto ist derzeit nicht verfügbar.')
            )
        end
    end

    Sessions[playerSource] = {
        characterId = player.characterId,
        job = player.job,
        pointIndex = pointIndex
    }
    TriggerClientEvent(
        'ms_bossmenu:client:open',
        playerSource,
        menuPayload(playerSource, player, job, point)
    )
    debugLog('%s öffnet %s an Dienstpunkt %d.', player:getName(), player.job, pointIndex)
end)

RegisterNetEvent('ms_bossmenu:server:close', function()
    closeSession(source, 'closed', false)
end)

RegisterNetEvent('ms_bossmenu:server:refresh', function()
    if not actionAllowed(source, 'refresh') then return end
    refreshMenu(source)
end)

RegisterNetEvent('ms_bossmenu:server:toggleDuty', function(desiredState)
    local playerSource = source
    if type(desiredState) ~= 'boolean' then return end
    if not actionAllowed(playerSource, 'toggle_duty') then
        return sendResult(playerSource, false, 'Bitte warte kurz vor dem nächsten Dienstwechsel.', false)
    end

    local _, player = activeSession(playerSource)
    if not player then return end
    local called, success, payloadOrMessage = pcall(function()
        return exports.MSCore:SetDutyState(playerSource, desiredState)
    end)
    if not called then
        print(('[MS_BossMenu] Dienstwechsel für Spieler %d fehlgeschlagen: %s'):format(
            playerSource,
            tostring(success)
        ))
        return sendResult(playerSource, false, 'Der Dienststatus konnte nicht geändert werden.', true)
    end
    if success ~= true then
        return sendResult(
            playerSource,
            false,
            tostring(payloadOrMessage or 'Der Dienststatus konnte nicht geändert werden.'),
            true
        )
    end

    sendResult(
        playerSource,
        true,
        desiredState and 'Du bist jetzt im Dienst.' or 'Du hast deinen Dienst beendet.',
        true
    )
end)

RegisterNetEvent('ms_bossmenu:server:hire', function(rawTargetSource)
    local playerSource = source
    if not actionAllowed(playerSource, 'hire') then
        return sendResult(playerSource, false, 'Bitte warte kurz vor der nächsten Einstellung.', false)
    end
    local _, player, job = activeSession(playerSource)
    if player and not bossAccess(player, job) then
        return sendResult(playerSource, false, 'Du hast keine Berechtigung für die Personalverwaltung.', false)
    end
    local targetSource = tonumber(rawTargetSource)
    local target = targetSource and getPlayer(targetSource)
    if not player or not target or targetSource == playerSource then
        return sendResult(playerSource, false, 'Der Bewerber ist nicht mehr verfügbar.', true)
    end
    if GetPlayerRoutingBucket(playerSource) ~= GetPlayerRoutingBucket(targetSource)
        or playerDistance(playerSource, targetSource) > math.max(
            1.0,
            tonumber(Config.HireDistance) or 5.0
        ) then
        return sendResult(playerSource, false, 'Der Bewerber ist nicht mehr in deiner Nähe.', true)
    end
    local unemployedJob = tostring(Config.UnemployedJob or 'unemployed')
    if Config.RequireUnemployedForHire == true and target.job ~= unemployedJob then
        return sendResult(playerSource, false, 'Es können nur arbeitslose Charaktere eingestellt werden.', true)
    end

    local hireGrade = math.max(0, math.floor(tonumber(job.hireGrade) or 0))
    if not target:setJob(player.job, hireGrade) then
        return sendResult(playerSource, false, 'Der Job konnte nicht zugewiesen werden.', true)
    end
    target:save()
    notify(
        targetSource,
        ('Du wurdest von %s bei %s eingestellt.'):format(
            player:getName(),
            tostring(job.label or player.job)
        )
    )
    sendResult(
        playerSource,
        true,
        ('%s wurde mit Jobgrad %d eingestellt.'):format(target:getName(), hireGrade),
        true
    )
    TriggerEvent('MS_BossMenu:server:hired', {
        actorSource = playerSource,
        actorCharacterId = player.characterId,
        targetSource = targetSource,
        targetCharacterId = target.characterId,
        job = player.job,
        grade = hireGrade
    })
end)

RegisterNetEvent('ms_bossmenu:server:fire', function(rawCharacterId)
    local playerSource = source
    if not actionAllowed(playerSource, 'fire') then
        return sendResult(playerSource, false, 'Bitte warte kurz vor der nächsten Entlassung.', false)
    end
    local _, player, job = activeSession(playerSource)
    if player and not bossAccess(player, job) then
        return sendResult(playerSource, false, 'Du hast keine Berechtigung für die Personalverwaltung.', false)
    end
    local characterId = math.floor(tonumber(rawCharacterId) or 0)
    if not player or characterId < 1 then
        return sendResult(playerSource, false, 'Der Mitarbeiter ist nicht verfügbar.', true)
    end
    if characterId == tonumber(player.characterId) and Config.AllowSelfFire ~= true then
        return sendResult(playerSource, false, 'Du kannst dich nicht selbst entlassen.', false)
    end
    if ManagedCharacters[characterId] then
        return sendResult(playerSource, false, 'Dieser Mitarbeiter wird bereits bearbeitet.', false)
    end

    ManagedCharacters[characterId] = true
    local success, message, targetSource
    local executed, errorMessage = pcall(function()
        local row = MySQL.single.await([[
            SELECT id, firstname, lastname, job, job_grade
            FROM mscore_characters
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
        ]], { characterId })
        if not row or row.job ~= player.job then
            success, message = false, 'Der Charakter gehört nicht mehr zu deinem Job.'
            return
        end
        local targetGrade = math.floor(tonumber(row.job_grade) or 0)
        local actorGrade = math.floor(tonumber(player.jobGrade) or 0)
        if Config.AllowManageSameGrade ~= true and targetGrade >= actorGrade then
            success, message = false, 'Du kannst keinen gleich- oder höherrangigen Mitarbeiter entlassen.'
            return
        end

        targetSource = onlineSourceForCharacter(characterId)
        local target = targetSource and getPlayer(targetSource)
        local unemployedJob = tostring(Config.UnemployedJob or 'unemployed')
        local unemployedGrade = math.max(
            0,
            math.floor(tonumber(Config.UnemployedGrade) or 0)
        )
        if target then
            if not target:setJob(unemployedJob, unemployedGrade) then
                success, message = false, 'Der Ersatzjob ist nicht gültig konfiguriert.'
                return
            end
            target:save()
        else
            local affected = MySQL.update.await([[
                UPDATE mscore_characters
                SET job = ?, job_grade = ?
                WHERE id = ? AND job = ? AND is_deleted = 0
            ]], { unemployedJob, unemployedGrade, characterId, player.job })
            if tonumber(affected) ~= 1 then
                success, message = false, 'Der Mitarbeiter konnte nicht entlassen werden.'
                return
            end
        end

        local targetName = ('%s %s'):format(
            tostring(row.firstname or ''),
            tostring(row.lastname or '')
        )
        success = true
        message = ('%s wurde entlassen.'):format(targetName)
        if targetSource then
            notify(
                targetSource,
                ('Du wurdest von %s bei %s entlassen.'):format(
                    player:getName(),
                    tostring(job.label or player.job)
                )
            )
        end
        TriggerEvent('MS_BossMenu:server:fired', {
            actorSource = playerSource,
            actorCharacterId = player.characterId,
            targetSource = targetSource,
            targetCharacterId = characterId,
            job = player.job
        })
    end)
    ManagedCharacters[characterId] = nil
    if not executed then
        print(('[MS_BossMenu] Entlassung von Charakter %d fehlgeschlagen: %s'):format(
            characterId,
            tostring(errorMessage)
        ))
        success, message = false, 'Die Entlassung konnte nicht verarbeitet werden.'
    end
    sendResult(playerSource, success, message, true)
end)

RegisterNetEvent('ms_bossmenu:server:companyOperation', function(operation, rawAmount)
    local playerSource = source
    operation = tostring(operation or '')
    if operation ~= 'deposit' and operation ~= 'withdraw' then return end
    if not actionAllowed(playerSource, 'company_' .. operation) then
        return sendResult(playerSource, false, 'Bitte warte kurz vor der nächsten Buchung.', false)
    end
    local _, player, job = activeSession(playerSource)
    if player and not bossAccess(player, job) then
        return sendResult(playerSource, false, 'Du hast keine Berechtigung für das Firmenkonto.', false)
    end
    if not player then return end

    local amount = tonumber(rawAmount)
    if not amount or amount ~= math.floor(amount) or amount < 1 then
        return sendResult(playerSource, false, 'Gib einen gültigen ganzzahligen Betrag ein.', false)
    end
    local called, success, message = pcall(function()
        if operation == 'deposit' then
            return exports.MS_Banking:CompanySessionDeposit(playerSource, amount)
        end
        return exports.MS_Banking:CompanySessionWithdraw(playerSource, amount)
    end)
    if not called then
        print(('[MS_BossMenu] Firmenbuchung für Spieler %d fehlgeschlagen: %s'):format(
            playerSource,
            tostring(success)
        ))
        return sendResult(
            playerSource,
            false,
            'Das Firmenkonto konnte nicht verarbeitet werden.',
            true
        )
    end
    sendResult(playerSource, success, message, true)
end)

AddEventHandler('mscore:server:jobChanged', function(playerSource)
    if Sessions[tonumber(playerSource)] then
        SetTimeout(0, function()
            activeSession(tonumber(playerSource))
        end)
    end
end)

AddEventHandler('mscore:server:paycheckPaid', function(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource or not Sessions[playerSource] then return end
    SetTimeout(0, function()
        if Sessions[playerSource] then refreshMenu(playerSource) end
    end)
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    closeSession(playerSource, 'logout', false)
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    closeSession(playerSource, 'disconnect', false)
    local prefix = ('%d:'):format(playerSource)
    for key in pairs(LastActions) do
        if key:sub(1, #prefix) == prefix then LastActions[key] = nil end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local sources = {}
    for playerSource in pairs(Sessions) do sources[#sources + 1] = playerSource end
    for _, playerSource in ipairs(sources) do closeSession(playerSource, 'resource_stop', false) end
end)
