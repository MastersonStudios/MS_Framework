local Definitions = {
    npcs = {},
    storages = {},
    doors = {}
}
local NpcEntities = {}
local NpcLoading = {}
local NpcFailures = {}
local DoorEntities = {}
local BuilderOpen = false
local StorageOpen = false
local NearestInteraction = nil

local TASK_START_SCENARIO = 0x524B54361229154F
local UPDATE_PED_VARIATION = 0x283978A15512B2FE

local function distance(coords, data)
    local dx, dy, dz = coords.x - data.x, coords.y - data.y, coords.z - data.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return end
    RequestModel(hash, false)
    local expires = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function deleteNpc(id)
    local entity = NpcEntities[id]
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
    NpcEntities[id] = nil
end

local function spawnNpc(id, npc)
    if NpcEntities[id] or NpcLoading[id] or NpcFailures[id] then return end
    NpcLoading[id] = true
    CreateThread(function()
        local hash = loadModel(npc.model)
        if not hash or not Definitions.npcs[id] or NpcEntities[id] then
            NpcLoading[id] = nil
            NpcFailures[id] = true
            return print(('[MSCore World Builder] NPC-Modell "%s" konnte nicht geladen werden.'):format(npc.model))
        end
        local ped = CreatePed(hash, npc.x, npc.y, npc.z, npc.heading, false, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if not DoesEntityExist(ped) then
            NpcLoading[id] = nil
            NpcFailures[id] = true
            return
        end
        Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, true)
        SetEntityVisible(ped, true)
        SetEntityAsMissionEntity(ped, true, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        FreezeEntityPosition(ped, true)
        if npc.scenario and npc.scenario ~= '' then
            Citizen.InvokeNative(
                TASK_START_SCENARIO,
                ped,
                GetHashKey(npc.scenario),
                -1,
                true,
                false,
                false,
                1.0,
                false
            )
        end
        NpcEntities[id] = ped
        NpcLoading[id] = nil
    end)
end

local function findDoorEntity(door)
    local entity = GetClosestObjectOfType(
        door.x,
        door.y,
        door.z,
        2.0,
        door.modelHash,
        false,
        false,
        false
    )
    return entity and entity ~= 0 and entity or nil
end

local function applyDoor(door)
    local entity = DoorEntities[door.id]
    if not entity or not DoesEntityExist(entity) then
        entity = findDoorEntity(door)
        DoorEntities[door.id] = entity
    end
    if entity and DoesEntityExist(entity) then
        FreezeEntityPosition(entity, door.locked == true)
    end
end

local function closeMenus()
    BuilderOpen = false
    StorageOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeAll' })
end

local function externalUiOpen()
    if GetResourceState('MS_AdminMenu') ~= 'started' then return false end
    local success, open = pcall(function()
        return exports.MS_AdminMenu:IsUiOpen()
    end)
    return success and open == true
end

exports('HasNearbyInteraction', function()
    return NearestInteraction ~= nil
end)

local function builderEnvelope(data)
    return {
        definitions = data,
        models = WorldBuilderConfig.NpcModels,
        scenarios = WorldBuilderConfig.NpcScenarios,
        limits = {
            storageCapacity = WorldBuilderConfig.MaxStorageCapacity,
            storageRadius = 5,
            transfer = WorldBuilderConfig.TransferLimit
        }
    }
end

RegisterCommand(WorldBuilderConfig.Command, function()
    if BuilderOpen then
        closeMenus()
    else
        TriggerServerEvent('ms_worldbuilder:server:openBuilder')
    end
end, false)

RegisterKeyMapping(
    WorldBuilderConfig.Command,
    'MSCore World Builder öffnen',
    'keyboard',
    WorldBuilderConfig.DefaultKey
)

RegisterNetEvent('ms_worldbuilder:client:sync', function(data)
    local incoming = { npcs = {}, storages = {}, doors = {} }
    for id, npc in pairs(data and data.npcs or {}) do
        npc.id = tonumber(npc.id) or tonumber(id)
        incoming.npcs[npc.id] = npc
    end
    for id, storage in pairs(data and data.storages or {}) do
        storage.id = tonumber(storage.id) or tonumber(id)
        incoming.storages[storage.id] = storage
    end
    for id, door in pairs(data and data.doors or {}) do
        door.id = tonumber(door.id) or tonumber(id)
        incoming.doors[door.id] = door
    end

    for id in pairs(NpcEntities) do
        if not incoming.npcs[id] then deleteNpc(id) end
    end
    for id in pairs(NpcFailures) do
        if not incoming.npcs[id] then NpcFailures[id] = nil end
    end
    for id, entity in pairs(DoorEntities) do
        if not incoming.doors[id] then
            if entity and DoesEntityExist(entity) then FreezeEntityPosition(entity, false) end
            DoorEntities[id] = nil
        end
    end

    Definitions = incoming
    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, door in pairs(Definitions.doors) do
        if distance(playerCoords, door) <= WorldBuilderConfig.DoorApplyDistance then
            applyDoor(door)
        end
    end
end)

RegisterNetEvent('ms_worldbuilder:client:updateDoor', function(door)
    local id = tonumber(door and door.id)
    if not id then return end
    door.id = id
    Definitions.doors[id] = door
    applyDoor(door)
    if BuilderOpen then TriggerServerEvent('ms_worldbuilder:server:openBuilder') end
end)

RegisterNetEvent('ms_worldbuilder:client:openBuilder', function(data)
    BuilderOpen = true
    StorageOpen = false
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openBuilder', data = builderEnvelope(data) })
end)

RegisterNetEvent('ms_worldbuilder:client:builderData', function(data)
    if BuilderOpen then
        SendNUIMessage({ action = 'builderData', data = builderEnvelope(data) })
    end
end)

RegisterNetEvent('ms_worldbuilder:client:openStorage', function(data)
    StorageOpen = true
    BuilderOpen = false
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openStorage', data = data })
end)

RegisterNetEvent('ms_worldbuilder:client:result', function(data)
    SendNUIMessage({
        action = 'result',
        success = data and data.success == true,
        message = data and data.message or 'Aktion verarbeitet.'
    })
end)

RegisterNUICallback('closeBuilder', function(_, cb)
    closeMenus()
    cb({ ok = true })
end)

RegisterNUICallback('closeStorage', function(_, cb)
    closeMenus()
    cb({ ok = true })
end)

RegisterNUICallback('createDefinition', function(data, cb)
    if not BuilderOpen or type(data) ~= 'table' or type(data.kind) ~= 'string' then
        return cb({ ok = false })
    end
    TriggerServerEvent('ms_worldbuilder:server:create', data.kind, data.data or {})
    cb({ ok = true })
end)

RegisterNUICallback('deleteDefinition', function(data, cb)
    if not BuilderOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_worldbuilder:server:delete', data.kind, data.id)
    cb({ ok = true })
end)

RegisterNUICallback('toggleDoor', function(data, cb)
    if not BuilderOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_worldbuilder:server:builderToggleDoor', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('capturePosition', function(data, cb)
    if not BuilderOpen then return cb({ ok = false }) end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local radians = math.rad(heading)
    local offset = data and data.kind == 'npc' and 1.6 or 0.8
    cb({
        ok = true,
        coords = {
            x = coords.x - math.sin(radians) * offset,
            y = coords.y + math.cos(radians) * offset,
            z = coords.z,
            heading = heading
        }
    })
end)

local function cameraDirection(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local pitchScale = math.abs(math.cos(pitch))
    return vector3(-math.sin(yaw) * pitchScale, math.cos(yaw) * pitchScale, math.sin(pitch))
end

RegisterNUICallback('captureDoor', function(_, cb)
    if not BuilderOpen then return cb({ ok = false }) end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'captureHint', visible = true })
    Wait(1500)

    local origin = GetGameplayCamCoord()
    local direction = cameraDirection(GetGameplayCamRot(2))
    local destination = origin + direction * 10.0
    local ray = StartShapeTestRay(
        origin.x, origin.y, origin.z,
        destination.x, destination.y, destination.z,
        16,
        PlayerPedId(),
        0
    )
    local status, hit, endCoords, surfaceNormal, entity
    local expires = GetGameTimer() + 1000
    repeat
        status, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(ray)
        if status == 1 then Wait(0) end
    until status ~= 1 or GetGameTimer() >= expires
    SendNUIMessage({ action = 'captureHint', visible = false })
    SetNuiFocus(true, true)

    if not hit or not entity or entity == 0 or GetEntityType(entity) ~= 3 then
        return cb({ ok = false, error = 'Kein Tür- oder Objektmodell anvisiert.' })
    end
    local coords = GetEntityCoords(entity)
    cb({
        ok = true,
        door = {
            modelHash = GetEntityModel(entity),
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = GetEntityHeading(entity)
        }
    })
end)

RegisterNUICallback('storageTransfer', function(data, cb)
    if not StorageOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent(
        'ms_worldbuilder:server:transfer',
        data.storageId,
        data.direction,
        data.item,
        data.amount
    )
    cb({ ok = true })
end)

RegisterCommand('+mscore_world_interact', function()
    if BuilderOpen or StorageOpen or externalUiOpen() or not NearestInteraction then return end
    if NearestInteraction.kind == 'storage' then
        TriggerServerEvent('ms_worldbuilder:server:openStorage', NearestInteraction.id)
    elseif NearestInteraction.kind == 'door' then
        TriggerServerEvent('ms_worldbuilder:server:interactDoor', NearestInteraction.id)
    end
end, false)
RegisterCommand('-mscore_world_interact', function() end, false)
RegisterKeyMapping(
    '+mscore_world_interact',
    'Lager oder Tür benutzen',
    'keyboard',
    WorldBuilderConfig.InteractionKey
)

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for id, npc in pairs(Definitions.npcs) do
            local npcDistance = distance(coords, npc)
            if npcDistance <= WorldBuilderConfig.NpcStreamDistance then
                spawnNpc(id, npc)
            elseif npcDistance >= WorldBuilderConfig.NpcDespawnDistance then
                deleteNpc(id)
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for _, door in pairs(Definitions.doors) do
            if distance(coords, door) <= WorldBuilderConfig.DoorApplyDistance then applyDoor(door) end
        end
        Wait(800)
    end
end)

CreateThread(function()
    while true do
        if BuilderOpen or StorageOpen or externalUiOpen() then
            NearestInteraction = nil
            SendNUIMessage({ action = 'prompt', visible = false })
            Wait(300)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for id, storage in pairs(Definitions.storages) do
                local currentDistance = distance(coords, storage)
                if currentDistance <= storage.radius and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = { kind = 'storage', id = id, label = storage.label, private = storage.type == 'private' }
                    nearestDistance = currentDistance
                end
            end
            for id, door in pairs(Definitions.doors) do
                local currentDistance = distance(coords, door)
                if currentDistance <= door.radius and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = { kind = 'door', id = id, label = door.label, locked = door.locked }
                    nearestDistance = currentDistance
                end
            end
            NearestInteraction = nearest
            SendNUIMessage({
                action = 'prompt',
                visible = nearest ~= nil,
                key = WorldBuilderConfig.InteractionKey,
                kind = nearest and nearest.kind,
                label = nearest and nearest.label,
                detail = nearest and (
                    nearest.kind == 'storage'
                        and (nearest.private and 'Privates Lager' or 'Globales Lager')
                        or (nearest.locked and 'Abgeschlossen' or 'Aufgeschlossen')
                )
            })
            Wait(nearest and 120 or 350)
        end
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1200)
    TriggerServerEvent('ms_worldbuilder:server:requestSync')
end)

RegisterNetEvent('mscore:client:prepareLogout', function()
    closeMenus()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeMenus()
    for id in pairs(NpcEntities) do deleteNpc(id) end
    for _, entity in pairs(DoorEntities) do
        if entity and DoesEntityExist(entity) then FreezeEntityPosition(entity, false) end
    end
end)
