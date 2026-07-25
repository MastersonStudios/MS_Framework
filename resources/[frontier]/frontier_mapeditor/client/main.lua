local Objects = {}
local Entities = {}
local Loading = {}
local Editor = nil
local Keys = {
    forward = false,
    backward = false,
    left = false,
    right = false,
    up = false,
    down = false,
    rotateLeft = false,
    rotateRight = false,
    pitchForward = false,
    pitchBackward = false,
    rollLeft = false,
    rollRight = false,
    fast = false
}

local function notify(message)
    TriggerEvent('frontier:client:notify', message)
end

local function modelHash(model)
    return GetHashKey(model)
end

local function loadModel(model)
    local hash = modelHash(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local expires = GetGameTimer() + MapEditorConfig.ModelLoadTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function deleteEntityFor(id)
    local entity = Entities[id]
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
    Entities[id] = nil
end

local function createMapEntity(id, data)
    if Loading[id] or Entities[id] or (Editor and Editor.id == id) then return end
    Loading[id] = true
    CreateThread(function()
        local hash = loadModel(data.model)
        if hash and Objects[id] and not Entities[id] and not (Editor and Editor.id == id) then
            local entity = CreateObject(hash, data.x, data.y, data.z, false, false, false)
            if DoesEntityExist(entity) then
                SetEntityRotation(entity, data.rotX, data.rotY, data.rotZ, 2, true)
                SetEntityCollision(entity, data.collision, data.collision)
                FreezeEntityPosition(entity, data.frozen)
                SetEntityAsMissionEntity(entity, true, false)
                Entities[id] = entity
            end
            SetModelAsNoLongerNeeded(hash)
        end
        Loading[id] = nil
    end)
end

local function nearestObject(maxDistance, requestedId)
    if requestedId then
        local object = Objects[requestedId]
        if not object then return nil end
        local playerCoords = GetEntityCoords(PlayerPedId())
        local dx, dy, dz = object.x - playerCoords.x, object.y - playerCoords.y, object.z - playerCoords.z
        if math.sqrt(dx * dx + dy * dy + dz * dz) <= maxDistance then return requestedId, object end
        return nil
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestId, nearestData, nearestDistance
    for id, object in pairs(Objects) do
        local dx, dy, dz = object.x - playerCoords.x, object.y - playerCoords.y, object.z - playerCoords.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if distance <= maxDistance and (not nearestDistance or distance < nearestDistance) then
            nearestId, nearestData, nearestDistance = id, object, distance
        end
    end
    return nearestId, nearestData, nearestDistance
end

local function setEditorUi(visible)
    if not visible or not Editor then
        SendNUIMessage({ action = 'hide' })
        return
    end
    SendNUIMessage({
        action = 'show',
        mode = Editor.id and ('Objekt #%d bearbeiten'):format(Editor.id) or 'Neues Objekt',
        model = Editor.model,
        x = Editor.x,
        y = Editor.y,
        z = Editor.z,
        rotX = Editor.rotX,
        rotY = Editor.rotY,
        rotZ = Editor.rotZ
    })
end

local function cleanupEditor(respawnOriginal)
    if not Editor then return end
    local id = Editor.id
    if Editor.entity and DoesEntityExist(Editor.entity) then
        SetEntityAsMissionEntity(Editor.entity, true, true)
        DeleteEntity(Editor.entity)
    end
    Editor = nil
    FreezeEntityPosition(PlayerPedId(), false)
    setEditorUi(false)
    if respawnOriginal and id and Objects[id] then createMapEntity(id, Objects[id]) end
end

local function startEditor(model, original)
    if Editor then cleanupEditor(true) end
    local hash = loadModel(model)
    if not hash then return notify(('Modell "%s" konnte nicht geladen werden.'):format(tostring(model))) end

    local coords, rotX, rotY, rotZ, id
    if original then
        id = original.id
        coords = vector3(original.x, original.y, original.z)
        rotX, rotY, rotZ = original.rotX, original.rotY, original.rotZ
        deleteEntityFor(id)
    else
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local heading = math.rad(GetEntityHeading(ped))
        coords = vector3(
            playerCoords.x - math.sin(heading) * 3.0,
            playerCoords.y + math.cos(heading) * 3.0,
            playerCoords.z
        )
        rotX, rotY, rotZ = 0.0, 0.0, GetEntityHeading(ped)
    end

    local entity = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(entity) then return notify('Das Vorschauobjekt konnte nicht erstellt werden.') end

    SetEntityRotation(entity, rotX, rotY, rotZ, 2, true)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityAlpha(entity, 190, false)
    SetEntityAsMissionEntity(entity, true, true)

    Editor = {
        id = id,
        entity = entity,
        model = model,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        rotX = rotX,
        rotY = rotY,
        rotZ = rotZ,
        collision = original and original.collision or true,
        frozen = original and original.frozen or true
    }
    FreezeEntityPosition(PlayerPedId(), true)
    setEditorUi(true)
end

local function editorPayload()
    return {
        model = Editor.model,
        x = Editor.x,
        y = Editor.y,
        z = Editor.z,
        rotX = Editor.rotX,
        rotY = Editor.rotY,
        rotZ = Editor.rotZ,
        collision = Editor.collision,
        frozen = Editor.frozen
    }
end

RegisterNetEvent('frontier_mapeditor:client:sync', function(objects)
    for id in pairs(Entities) do deleteEntityFor(id) end
    Objects = {}
    for id, object in pairs(objects or {}) do
        object.id = tonumber(object.id) or tonumber(id)
        Objects[object.id] = object
    end
end)

RegisterNetEvent('frontier_mapeditor:client:upsert', function(object)
    local id = tonumber(object.id)
    if not id then return end
    deleteEntityFor(id)
    object.id = id
    Objects[id] = object
end)

RegisterNetEvent('frontier_mapeditor:client:remove', function(id)
    id = tonumber(id)
    deleteEntityFor(id)
    Objects[id] = nil
    if Editor and Editor.id == id then cleanupEditor(false) end
end)

RegisterNetEvent('frontier_mapeditor:client:create', function(model)
    model = model or MapEditorConfig.ObjectCatalog[1].model
    startEditor(model:lower())
end)

RegisterNetEvent('frontier_mapeditor:client:edit', function(requestedId)
    local id, object = nearestObject(MapEditorConfig.SelectionDistance, requestedId)
    if not id then return notify('Kein passendes Map-Objekt in Reichweite.') end
    local original = {}
    for key, value in pairs(object) do original[key] = value end
    original.id = id
    startEditor(object.model, original)
end)

RegisterNetEvent('frontier_mapeditor:client:deleteNearest', function(requestedId)
    if Editor then
        local id = Editor.id
        if not id then return notify('Ein noch nicht gespeichertes Objekt kann nur abgebrochen werden.') end
        cleanupEditor(false)
        TriggerServerEvent('frontier_mapeditor:server:delete', id)
        return
    end
    local id = nearestObject(MapEditorConfig.SelectionDistance, requestedId)
    if not id then return notify('Kein passendes Map-Objekt in Reichweite.') end
    TriggerServerEvent('frontier_mapeditor:server:delete', id)
end)

RegisterNetEvent('frontier_mapeditor:client:listNearby', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearby = {}
    for id, object in pairs(Objects) do
        local dx, dy, dz = object.x - playerCoords.x, object.y - playerCoords.y, object.z - playerCoords.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if distance <= MapEditorConfig.SelectionDistance * 2 then
            nearby[#nearby + 1] = { id = id, model = object.model, distance = distance }
        end
    end
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    if #nearby == 0 then return notify('Keine Map-Objekte in der Nähe.') end
    local parts = {}
    for index = 1, math.min(#nearby, 10) do
        local item = nearby[index]
        parts[#parts + 1] = ('#%d %s (%.1fm)'):format(item.id, item.model, item.distance)
    end
    notify(table.concat(parts, ', '))
end)

RegisterNetEvent('frontier:client:prepareLogout', function()
    if Editor then cleanupEditor(true) end
end)

local function bindHold(name, description, defaultKey, field)
    RegisterCommand('+' .. name, function() Keys[field] = true end, false)
    RegisterCommand('-' .. name, function() Keys[field] = false end, false)
    RegisterKeyMapping('+' .. name, description, 'keyboard', defaultKey)
end

bindHold('frontier_map_forward', 'Mapeditor: vorwärts', 'W', 'forward')
bindHold('frontier_map_backward', 'Mapeditor: rückwärts', 'S', 'backward')
bindHold('frontier_map_left', 'Mapeditor: links', 'A', 'left')
bindHold('frontier_map_right', 'Mapeditor: rechts', 'D', 'right')
bindHold('frontier_map_up', 'Mapeditor: hoch', 'PAGEUP', 'up')
bindHold('frontier_map_down', 'Mapeditor: runter', 'PAGEDOWN', 'down')
bindHold('frontier_map_rotate_left', 'Mapeditor: links drehen', 'Q', 'rotateLeft')
bindHold('frontier_map_rotate_right', 'Mapeditor: rechts drehen', 'E', 'rotateRight')
bindHold('frontier_map_pitch_forward', 'Mapeditor: vorwärts kippen', 'R', 'pitchForward')
bindHold('frontier_map_pitch_backward', 'Mapeditor: rückwärts kippen', 'F', 'pitchBackward')
bindHold('frontier_map_roll_left', 'Mapeditor: nach links kippen', 'Z', 'rollLeft')
bindHold('frontier_map_roll_right', 'Mapeditor: nach rechts kippen', 'X', 'rollRight')
bindHold('frontier_map_fast', 'Mapeditor: schnell bewegen', 'LSHIFT', 'fast')

RegisterCommand('frontier_map_confirm', function()
    if not Editor then return end
    local id, payload = Editor.id, editorPayload()
    cleanupEditor(false)
    if id then
        TriggerServerEvent('frontier_mapeditor:server:update', id, payload)
    else
        TriggerServerEvent('frontier_mapeditor:server:create', payload)
    end
end, false)
RegisterKeyMapping('frontier_map_confirm', 'Mapeditor: speichern', 'keyboard', 'RETURN')

RegisterCommand('frontier_map_cancel', function()
    if Editor then
        cleanupEditor(true)
        notify('Bearbeitung abgebrochen.')
    end
end, false)
RegisterKeyMapping('frontier_map_cancel', 'Mapeditor: abbrechen', 'keyboard', 'BACK')

RegisterCommand('frontier_map_ground', function()
    if not Editor or not DoesEntityExist(Editor.entity) then return end
    PlaceObjectOnGroundProperly(Editor.entity)
    local coords = GetEntityCoords(Editor.entity)
    Editor.x, Editor.y, Editor.z = coords.x, coords.y, coords.z
    setEditorUi(true)
end, false)
RegisterKeyMapping('frontier_map_ground', 'Mapeditor: auf Boden setzen', 'keyboard', 'G')

CreateThread(function()
    TriggerServerEvent('frontier_mapeditor:server:requestSync')
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        for id, object in pairs(Objects) do
            local dx, dy, dz = object.x - playerCoords.x, object.y - playerCoords.y, object.z - playerCoords.z
            local inRange = (dx * dx + dy * dy + dz * dz) <= (MapEditorConfig.StreamDistance ^ 2)
            if inRange and not Entities[id] then
                createMapEntity(id, object)
            elseif not inRange and Entities[id] then
                deleteEntityFor(id)
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    local lastUiUpdate = 0
    while true do
        if not Editor then
            Wait(250)
        else
            Wait(0)
            FreezeEntityPosition(PlayerPedId(), true)
            local frameTime = math.min(GetFrameTime(), 0.05)
            local speed = MapEditorConfig.MoveSpeed * frameTime * 60.0
            if Keys.fast then speed = speed * MapEditorConfig.FastMultiplier end

            local camRotation = GetGameplayCamRot(2)
            local heading = math.rad(camRotation.z)
            local forwardX, forwardY = -math.sin(heading), math.cos(heading)
            local rightX, rightY = math.cos(heading), math.sin(heading)
            local moved = false

            if Keys.forward then Editor.x, Editor.y, moved = Editor.x + forwardX * speed, Editor.y + forwardY * speed, true end
            if Keys.backward then Editor.x, Editor.y, moved = Editor.x - forwardX * speed, Editor.y - forwardY * speed, true end
            if Keys.right then Editor.x, Editor.y, moved = Editor.x + rightX * speed, Editor.y + rightY * speed, true end
            if Keys.left then Editor.x, Editor.y, moved = Editor.x - rightX * speed, Editor.y - rightY * speed, true end
            if Keys.up then Editor.z, moved = Editor.z + speed, true end
            if Keys.down then Editor.z, moved = Editor.z - speed, true end
            if Keys.rotateLeft then Editor.rotZ, moved = (Editor.rotZ - MapEditorConfig.RotationSpeed) % 360.0, true end
            if Keys.rotateRight then Editor.rotZ, moved = (Editor.rotZ + MapEditorConfig.RotationSpeed) % 360.0, true end
            if Keys.pitchForward then Editor.rotX, moved = (Editor.rotX + MapEditorConfig.RotationSpeed) % 360.0, true end
            if Keys.pitchBackward then Editor.rotX, moved = (Editor.rotX - MapEditorConfig.RotationSpeed) % 360.0, true end
            if Keys.rollLeft then Editor.rotY, moved = (Editor.rotY - MapEditorConfig.RotationSpeed) % 360.0, true end
            if Keys.rollRight then Editor.rotY, moved = (Editor.rotY + MapEditorConfig.RotationSpeed) % 360.0, true end

            if moved and DoesEntityExist(Editor.entity) then
                SetEntityCoords(Editor.entity, Editor.x, Editor.y, Editor.z, false, false, false, false)
                SetEntityRotation(Editor.entity, Editor.rotX, Editor.rotY, Editor.rotZ, 2, true)
                if GetGameTimer() - lastUiUpdate > 100 then
                    setEditorUi(true)
                    lastUiUpdate = GetGameTimer()
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupEditor(false)
    for id in pairs(Entities) do deleteEntityFor(id) end
end)
