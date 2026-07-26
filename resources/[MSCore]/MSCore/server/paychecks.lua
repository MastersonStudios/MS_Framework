local PaycheckState = {}

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

local function resetPaycheck(source, player)
    source = tonumber(source)
    if not source then return end
    local settings = paycheckSettings(player)
    if not settings then
        PaycheckState[source] = nil
        return
    end
    PaycheckState[source] = {
        characterId = player.characterId,
        job = settings.job,
        grade = settings.grade,
        dueAt = os.time() + settings.intervalSeconds
    }
end

local function paycheckStateMatches(state, player, settings)
    return state
        and state.characterId == player.characterId
        and state.job == settings.job
        and state.grade == settings.grade
end

AddEventHandler('mscore:server:playerLoaded', function(source, player)
    resetPaycheck(source, player)
end)

AddEventHandler('mscore:server:playerUnloaded', function(source)
    local playerSource = tonumber(source)
    if playerSource then PaycheckState[playerSource] = nil end
end)

AddEventHandler('mscore:server:jobChanged', function(source)
    resetPaycheck(source, GetPlayer(source))
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
            local settings = paycheckSettings(player)
            if not settings then
                PaycheckState[source] = nil
            else
                local state = PaycheckState[source]
                if not paycheckStateMatches(state, player, settings) then
                    resetPaycheck(source, player)
                elseif currentTime >= state.dueAt then
                    state.dueAt = currentTime + settings.intervalSeconds
                    if player:addMoney(settings.account, settings.salary, 'hourly_job_salary') then
                        local destination = settings.account == 'bank'
                            and 'auf dein Bankkonto'
                            or 'als Bargeld'
                        TriggerClientEvent(
                            'mscore:client:notify',
                            source,
                            ('Stündlicher Lohn: $%d für %s – %s %s.'):format(
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
                end
            end
        end

        for source in pairs(PaycheckState) do
            if not players[source] then PaycheckState[source] = nil end
        end
    end
end)
