local SellerEntities = {}
local SellerLoading = {}
local SellerFailures = {}
local NearestShop = nil
local LastPromptShop = false
local ShopOpen = false
local ShopData = nil
local PreviewCamera = nil
local PreviewPed = nil
local PreviewComponents = {}
local OriginalHeading = nil
local PlayerWasVisible = true
local CameraDirection = nil
local CameraZoom = 0.5

local TASK_START_SCENARIO = 0x524B54361229154F
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE
local APPLY_SHOP_ITEM_TO_PED = 0xD3A7B003ED343FD9
local REMOVE_SHOP_ITEM_FROM_PED = 0x0D7FFA1B2F69ED82
local UPDATE_PED_VARIATION = 0xCC8CA3E88256E58F

local function previewTarget()
    if PreviewPed and PreviewPed ~= 0 and DoesEntityExist(PreviewPed) then return PreviewPed end
    return PlayerPedId()
end

local function distance(coords, point)
    local dx = coords.x - (tonumber(point.x) or 0.0)
    local dy = coords.y - (tonumber(point.y) or 0.0)
    local dz = coords.z - (tonumber(point.z) or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local expires = GetGameTimer() + MSClothingShopConfig.ModelLoadTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function deleteEntitySafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function deleteSeller(shopId)
    deleteEntitySafe(SellerEntities[shopId])
    SellerEntities[shopId] = nil
end

local function spawnSeller(shopId, shop)
    if SellerEntities[shopId] or SellerLoading[shopId] or SellerFailures[shopId] then return end
    SellerLoading[shopId] = true

    CreateThread(function()
        local seller = shop.seller
        local hash = loadModel(seller.model)
        if not hash then
            SellerLoading[shopId] = nil
            SellerFailures[shopId] = true
            return print(('[MS_ClothingShop] Verkäufermodell "%s" konnte nicht geladen werden.'):format(
                tostring(seller.model)
            ))
        end

        local ped = CreatePed(
            hash,
            seller.x,
            seller.y,
            seller.z,
            seller.heading or 0.0,
            false,
            false,
            false,
            false
        )
        SetModelAsNoLongerNeeded(hash)
        if not DoesEntityExist(ped) then
            SellerLoading[shopId] = nil
            SellerFailures[shopId] = true
            return
        end

        Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
        SetEntityAsMissionEntity(ped, true, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        FreezeEntityPosition(ped, true)
        if seller.scenario and seller.scenario ~= '' then
            Citizen.InvokeNative(
                TASK_START_SCENARIO,
                ped,
                GetHashKey(seller.scenario),
                -1,
                true,
                false,
                false,
                1.0,
                false
            )
        end

        SellerEntities[shopId] = ped
        SellerLoading[shopId] = nil
    end)
end

local function updatePedVariation(ped)
    Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, false, true, true, true, false)
end

local function applyShopItem(ped, componentHash, sex)
    local female = sex == 'female'
    Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, ped, componentHash, true, false, female)
    Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, ped, componentHash, true, true, female)
end

local function clearPreviewComponents()
    local ped = previewTarget()
    for _, componentHash in pairs(PreviewComponents) do
        Citizen.InvokeNative(REMOVE_SHOP_ITEM_FROM_PED, ped, componentHash, 0, false)
    end
    PreviewComponents = {}
    updatePedVariation(ped)
end

local function restoreInventoryOutfit()
    if GetResourceState('MS_Inventory') == 'started' then
        TriggerServerEvent('ms_inventory:server:requestOutfit')
    end
end

local function updateCamera()
    if not PreviewCamera or PreviewCamera == 0 or not DoesCamExist(PreviewCamera) or not CameraDirection then return end
    local ped = previewTarget()
    local coords = GetEntityCoords(ped)
    local preview = MSClothingShopConfig.Preview
    local minimum = tonumber(preview.minZoom) or 1.45
    local maximum = tonumber(preview.maxZoom) or 3.25
    local cameraDistance = maximum - (maximum - minimum) * CameraZoom
    local height = tonumber(preview.cameraHeight) or 0.72

    SetCamCoord(
        PreviewCamera,
        coords.x + CameraDirection.x * cameraDistance,
        coords.y + CameraDirection.y * cameraDistance,
        coords.z + height
    )
    PointCamAtEntity(PreviewCamera, ped, 0.0, 0.0, 0.58, true)
end

local function startPreviewCamera()
    local playerPed = PlayerPedId()
    OriginalHeading = GetEntityHeading(playerPed)
    PlayerWasVisible = IsEntityVisible(playerPed)
    FreezeEntityPosition(playerPed, true)
    DisplayRadar(false)

    PreviewPed = ClonePed(playerPed, false, false, true)
    if PreviewPed and PreviewPed ~= 0 and DoesEntityExist(PreviewPed) then
        local playerCoords = GetEntityCoords(playerPed)
        SetEntityCoordsNoOffset(PreviewPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
        SetEntityHeading(PreviewPed, OriginalHeading)
        SetEntityAsMissionEntity(PreviewPed, true, true)
        SetEntityInvincible(PreviewPed, true)
        SetBlockingOfNonTemporaryEvents(PreviewPed, true)
        SetPedCanRagdoll(PreviewPed, false)
        SetEntityNoCollisionEntity(PreviewPed, playerPed, false)
        ClearPedTasksImmediately(PreviewPed, true, true)
        RemoveAllPedWeapons(PreviewPed, true, true)
        FreezeEntityPosition(PreviewPed, true)
        SetEntityVisible(playerPed, false)
    else
        PreviewPed = nil
    end

    local ped = previewTarget()
    local preview = MSClothingShopConfig.Preview
    local initialDistance = tonumber(preview.cameraDistance) or 2.35
    local initial = GetOffsetFromEntityInWorldCoords(
        ped,
        0.0,
        initialDistance,
        tonumber(preview.cameraHeight) or 0.72
    )
    local coords = GetEntityCoords(ped)
    local dx, dy = initial.x - coords.x, initial.y - coords.y
    local length = math.sqrt(dx * dx + dy * dy)
    CameraDirection = length > 0.001 and { x = dx / length, y = dy / length } or { x = 0.0, y = 1.0 }
    CameraZoom = 0.5

    PreviewCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(PreviewCamera, tonumber(preview.cameraFov) or 38.0)
    updateCamera()
    SetCamActive(PreviewCamera, true)
    RenderScriptCams(true, true, 350, true, true, 0)
end

local function stopPreviewCamera()
    local usedClone = PreviewPed and PreviewPed ~= 0 and DoesEntityExist(PreviewPed)
    clearPreviewComponents()
    if not usedClone then restoreInventoryOutfit() end

    if PreviewCamera and DoesCamExist(PreviewCamera) then
        RenderScriptCams(false, true, 350, true, true, 0)
        DestroyCam(PreviewCamera, false)
    end
    PreviewCamera = nil
    CameraDirection = nil

    if usedClone then deleteEntitySafe(PreviewPed) end
    PreviewPed = nil

    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, PlayerWasVisible)
    if OriginalHeading then SetEntityHeading(playerPed, OriginalHeading) end
    OriginalHeading = nil
    FreezeEntityPosition(playerPed, false)
    DisplayRadar(true)
end

local function productByName(itemName)
    for _, product in ipairs(ShopData and ShopData.products or {}) do
        if product.item == itemName then return product end
    end
end

local function previewProduct(itemName)
    if not ShopOpen then return end
    local product = productByName(itemName)
    local componentHash = product and tonumber(product.componentHash)
    local slot = product and product.category
    if not componentHash or type(slot) ~= 'string' then
        return TriggerEvent('mscore:client:notify', 'Für dieses Kleidungsstück ist keine Vorschau verfügbar.')
    end

    local ped = previewTarget()
    local previous = PreviewComponents[slot]
    if previous then
        Citizen.InvokeNative(REMOVE_SHOP_ITEM_FROM_PED, ped, previous, 0, false)
    end
    applyShopItem(ped, componentHash, product.sex)
    PreviewComponents[slot] = componentHash
    updatePedVariation(ped)
end

local function inventoryIsOpen()
    if GetResourceState('MS_Inventory') ~= 'started' then return false end
    local success, open = pcall(function() return exports.MS_Inventory:IsUiOpen() end)
    return success and open == true
end

local function closeShop(notifyServer)
    if not ShopOpen then return end
    ShopOpen = false
    ShopData = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopPreviewCamera()
    if notifyServer ~= false then TriggerServerEvent('ms_clothingshop:server:close') end
end

local function openNearestShop()
    if ShopOpen then return closeShop(true) end
    if inventoryIsOpen() then
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst dein Inventar.')
    end
    if not NearestShop then
        return TriggerEvent('mscore:client:notify', 'Du bist bei keinem Bekleidungshändler.')
    end
    TriggerServerEvent('ms_clothingshop:server:open', NearestShop)
end

RegisterCommand(MSClothingShopConfig.Command, openNearestShop, false)
RegisterCommand('+ms_clothingshop_interact', function()
    if not ShopOpen and NearestShop and not inventoryIsOpen() then
        TriggerServerEvent('ms_clothingshop:server:open', NearestShop)
    end
end, false)
RegisterCommand('-ms_clothingshop_interact', function() end, false)
RegisterKeyMapping(
    '+ms_clothingshop_interact',
    'Bekleidungsshop benutzen',
    'keyboard',
    MSClothingShopConfig.InteractionKey
)

function IsShopOpen()
    return ShopOpen
end

exports('IsShopOpen', IsShopOpen)

RegisterNetEvent('ms_clothingshop:client:open', function(data)
    if type(data) ~= 'table' or ShopOpen then return end
    if inventoryIsOpen() then
        TriggerServerEvent('ms_clothingshop:server:close')
        return TriggerEvent('mscore:client:notify', 'Schließe zuerst dein Inventar.')
    end
    ShopOpen = true
    ShopData = data
    startPreviewCamera()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('ms_clothingshop:client:refresh', function(data)
    if ShopOpen and type(data) == 'table' then
        ShopData = data
        SendNUIMessage({ action = 'refresh', data = data })
    end
end)

RegisterNetEvent('ms_clothingshop:client:result', function(data)
    SendNUIMessage({
        action = 'result',
        success = data and data.success == true,
        message = data and data.message or 'Aktion verarbeitet.',
        clearCart = data and data.clearCart == true
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeShop(true)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if ShopOpen then TriggerServerEvent('ms_clothingshop:server:refresh') end
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    if ShopOpen and type(data) == 'table' and type(data.item) == 'string' then
        previewProduct(data.item)
    end
    cb({ ok = true })
end)

RegisterNUICallback('rotate', function(data, cb)
    if ShopOpen and type(data) == 'table' then
        local direction = tonumber(data.direction)
        if direction == -1 or direction == 1 then
            local ped = previewTarget()
            SetEntityHeading(
                ped,
                GetEntityHeading(ped) + direction * (tonumber(MSClothingShopConfig.Preview.rotationStep) or 18.0)
            )
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('zoom', function(data, cb)
    if ShopOpen and type(data) == 'table' and tonumber(data.value) then
        CameraZoom = math.max(0.0, math.min(1.0, tonumber(data.value)))
        updateCamera()
    end
    cb({ ok = true })
end)

RegisterNUICallback('purchase', function(data, cb)
    if ShopOpen and type(data) == 'table' and type(data.items) == 'table' then
        TriggerServerEvent('ms_clothingshop:server:purchase', data.items)
    end
    cb({ ok = true })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for shopId, shop in pairs(MSClothingShopConfig.Shops) do
            local sellerDistance = distance(coords, shop.seller)
            if sellerDistance <= MSClothingShopConfig.SellerStreamDistance then
                spawnSeller(shopId, shop)
            elseif sellerDistance > MSClothingShopConfig.SellerDespawnDistance then
                deleteSeller(shopId)
                SellerFailures[shopId] = nil
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while true do
        if ShopOpen then
            NearestShop = nil
            if LastPromptShop ~= false then
                SendNUIMessage({ action = 'prompt', visible = false })
                LastPromptShop = false
            end
            Wait(250)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for shopId, shop in pairs(MSClothingShopConfig.Shops) do
                local currentDistance = distance(coords, shop.seller)
                if currentDistance <= MSClothingShopConfig.InteractionDistance
                    and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = shopId
                    nearestDistance = currentDistance
                end
            end
            NearestShop = nearest
            if LastPromptShop ~= nearest then
                SendNUIMessage({
                    action = 'prompt',
                    visible = nearest ~= nil,
                    key = MSClothingShopConfig.InteractionKey,
                    label = nearest and MSClothingShopConfig.Shops[nearest].label or nil
                })
                LastPromptShop = nearest or false
            end
            Wait(nearest and 100 or 350)
        end
    end
end)

RegisterNetEvent('mscore:client:prepareLogout', function()
    closeShop(false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if ShopOpen then stopPreviewCamera() end
    for shopId in pairs(SellerEntities) do deleteSeller(shopId) end
end)
