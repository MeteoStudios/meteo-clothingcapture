local isCapturing = false
local currentCam = nil
local greenScreenProps = {}
local capturePed = nil
local originalCoords = nil
local originalHeading = nil
local pendingCapture = nil
local currentCamSettings = nil


local function ShowNotification(message, type)
    type = type or 'info'
    SendNUIMessage({
        action = 'notification',
        message = message,
        type = type
    })
end

local function ShowProgress(current, total, itemName, category)
    local text = string.format('[%s] %s', category, itemName)
    SendNUIMessage({
        action = 'showProgress',
        text = text,
        current = current,
        total = total
    })
end

local function HideProgress()
    SendNUIMessage({
        action = 'hideProgress'
    })
end

local function LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    if not IsModelValid(hash) then
        return false
    end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    return HasModelLoaded(hash)
end

local function SetWeatherTime()
    SetRainLevel(0.0)
    SetWeatherTypePersist(Config.Weather)
    SetWeatherTypeNow(Config.Weather)
    SetWeatherTypeNowPersist(Config.Weather)

    NetworkOverrideClockTime(Config.Time.hour, Config.Time.minute, Config.Time.second)

    if Config.FreezeTime then
        NetworkOverrideClockMillisecondsPerGameMinute(999999999)
    end
end


local function GetFileExtension()
    return '.' .. (Config.OutputFormat or 'webp')
end

local function UpdateNUIConfig()
    SendNUIMessage({
        action = 'updateConfig',
        config = {
            greenThreshold = Config.GreenThreshold,
            greenDiff = Config.GreenDiff,
            outputSize = Config.OutputSize,
            outputFormat = Config.OutputFormat or 'webp',
            cropBottom = Config.CropBottom or 80,
            cropRight = Config.CropRight or 80
        }
    })
end

RegisterNUICallback('imageProcessed', function(data, cb)
    if data.success and data.image then
        TriggerServerEvent('meteo-clothingcapture:saveImage',
            data.image,
            data.category,
            data.filename
        )
    end
    cb('ok')
end)

RegisterNetEvent('meteo-clothingcapture:imageSaved', function(success, filename)
    if pendingCapture then
        pendingCapture(success)
        pendingCapture = nil
    end
end)


local function SetupStudio()
    local playerPed = PlayerPedId()

    SetWeatherTime()

    originalCoords = GetEntityCoords(playerPed)
    originalHeading = GetEntityHeading(playerPed)

    SetEntityCoords(playerPed, Config.StudioLocation.x, Config.StudioLocation.y, Config.StudioLocation.z + 5.0, false, false, false, false)
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)

    DisableIdleCamera(true)

    local propHash = GetHashKey(Config.GreenScreenProp)
    LoadModel(propHash)

    for _, offset in ipairs(Config.GreenScreenOffsets) do
        local pos = Config.StudioLocation + offset
        local prop = CreateObject(propHash, pos.x, pos.y, pos.z, false, false, false)
        FreezeEntityPosition(prop, true)
        table.insert(greenScreenProps, prop)
    end

    DisplayRadar(false)
    DisplayHud(false)

    UpdateNUIConfig()

    Wait(1000)

    SetWeatherTime()
end

local function CleanupStudio()
    for _, prop in ipairs(greenScreenProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    greenScreenProps = {}

    if capturePed and DoesEntityExist(capturePed) then
        DeleteEntity(capturePed)
        capturePed = nil
    end

    if currentCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(currentCam, true)
        currentCam = nil
    end

    currentCamSettings = nil

    local playerPed = PlayerPedId()
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
        SetEntityHeading(playerPed, originalHeading)
    end
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, true)

    DisplayRadar(true)
    DisplayHud(true)

    DisableIdleCamera(false)

    if Config.FreezeTime then
        NetworkOverrideClockMillisecondsPerGameMinute(30000) -- Default value
    end

    originalCoords = nil
    originalHeading = nil
    isCapturing = false
end


local function SetupCamera(entity, camSettings)
    currentCamSettings = camSettings

    if currentCam then
        DestroyCam(currentCam, true)
    end

    local entityCoords = GetEntityCoords(entity)
    local fov = camSettings.fov or 50
    local zOffset = camSettings.zOffset or 0.0
    local distance = camSettings.distance or 1.0

    if camSettings.pedHeading then
        SetEntityHeading(entity, camSettings.pedHeading)
    end

    local cameraHeading = camSettings.heading or GetEntityHeading(entity)

    local rad = math.rad(cameraHeading + 180)
    local camX = entityCoords.x + math.sin(rad) * distance
    local camY = entityCoords.y + math.cos(rad) * distance
    local camZ = entityCoords.z + zOffset

    currentCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(currentCam, camX, camY, camZ)
    PointCamAtCoord(currentCam, entityCoords.x, entityCoords.y, entityCoords.z + zOffset)
    SetCamFov(currentCam, fov)
    SetCamActive(currentCam, true)
    RenderScriptCams(true, true, 500, true, true)

    Wait(500)
end


local function CaptureScreenshot(filename, category, callback)
    pendingCapture = callback

    Wait(100)

    exports['screencapture']:requestScreenshot({ encoding = 'png' }, function(data)
        if data then
            SendNUIMessage({
                action = 'processImage',
                image = data,
                filename = filename,
                category = category
            })
        else
            if pendingCapture == callback then
                pendingCapture = nil
                callback(false)
            end
        end
    end)

    SetTimeout(15000, function()
        if pendingCapture == callback then
            pendingCapture = nil
            callback(false)
        end
    end)
end

local function AwaitCapture(filename, category)
    local done = false
    local success = false

    CaptureScreenshot(filename, category, function(result)
        success = result
        done = true
    end)

    local timeout = 0
    while not done and timeout < 150 do
        Wait(100)
        timeout = timeout + 1
    end

    Wait(500)

    return success
end


local function ResetPedComponents(ped)
    SetPedComponentVariation(ped, 0, 0, 1, 0)    -- Head (keep visible)
    SetPedComponentVariation(ped, 1, 0, 0, 0)    -- Mask
    SetPedComponentVariation(ped, 2, -1, 0, 0)   -- Hair - HIDDEN
    SetPedComponentVariation(ped, 3, -1, 0, 0)   -- Torso - HIDDEN
    SetPedComponentVariation(ped, 4, -1, 0, 0)   -- Legs - HIDDEN
    SetPedComponentVariation(ped, 5, 0, 0, 0)    -- Bags
    SetPedComponentVariation(ped, 6, -1, 0, 0)   -- Shoes - HIDDEN
    SetPedComponentVariation(ped, 7, 0, 0, 0)    -- Accessories
    SetPedComponentVariation(ped, 8, -1, 0, 0)   -- Undershirt - HIDDEN
    SetPedComponentVariation(ped, 9, 0, 0, 0)    -- Armor
    SetPedComponentVariation(ped, 10, 0, 0, 0)   -- Decals
    SetPedComponentVariation(ped, 11, -1, 0, 0)  -- Top - HIDDEN

    for i = 0, 7 do
        ClearPedProp(ped, i)
    end
end

local function LoadComponentVariation(ped, component, drawable, texture)
    texture = texture or 0

    SetPedPreloadVariationData(ped, component, drawable, texture)

    local timeout = 0
    while not HasPedPreloadVariationDataFinished(ped) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    SetPedComponentVariation(ped, component, drawable, texture, 0)
end

-- hiding head (0) needs 'allowEmptyHeadDrawable true' in F8 (Canary only, won't work on stable)
local function HidePedComponents(ped, componentIds)
    if not DoesEntityExist(ped) or not componentIds or #componentIds == 0 then return end

    for _, componentId in ipairs(componentIds) do
        if componentId == 0 then
            for i = 0, 12 do SetPedHeadOverlay(ped, i, 0, 0.0) end
        end
        SetPedComponentVariation(ped, componentId, -1, 0, 0)
    end

    Wait(50)
end


local function CreateCapturePed(gender)
    local modelName = Config.PedModels[gender]
    local modelHash = GetHashKey(modelName)

    if not LoadModel(modelHash) then
        return nil
    end

    local pos = Config.StudioLocation
    local ped = CreatePed(4, modelHash, pos.x, pos.y, pos.z, 0.0, false, true)

    SetEntityHeading(ped, 0.0)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)

    SetPedConfigFlag(ped, 32, true)
    TaskStandStill(ped, -1)
    SetEntityInvincible(ped, true)
    SetEntityRotation(ped, 0.0, 0.0, 0.0, 2, true)

    ResetPedComponents(ped)

    capturePed = ped
    return ped
end


local function CaptureClothing(gender, componentFilter)
    if isCapturing then
        ShowNotification('Capture already in progress')
        return
    end

    isCapturing = true

    SetupStudio()

    local genders = gender == 'all' and {'male', 'female'} or {gender}
    local totalCaptures = 0

    for _, g in ipairs(genders) do
        local ped = CreateCapturePed(g)
        if not ped then
            goto continue_gender
        end

        CreateThread(function()
            while isCapturing and capturePed do
                ClearPedTasksImmediately(capturePed)
                Wait(0)
            end
        end)

        Wait(500)

        local totalItems = 0
        for componentId, camSettings in pairs(Config.ClothingCamera) do
            if not componentFilter or camSettings.name:lower() == componentFilter:lower() then
                totalItems = totalItems + GetNumberOfPedDrawableVariations(ped, componentId)
            end
        end

        local currentItem = 0

        for componentId, camSettings in pairs(Config.ClothingCamera) do
            if componentFilter and camSettings.name:lower() ~= componentFilter:lower() then
                goto continue_component
            end

            local drawableCount = GetNumberOfPedDrawableVariations(ped, componentId)

            for drawable = 0, drawableCount - 1 do
                currentItem = currentItem + 1
                ShowProgress(currentItem, totalItems, string.format('%s %s #%d', g, camSettings.name, drawable), 'Clothing')

                ResetPedComponents(ped)
                Wait(150)

                LoadComponentVariation(ped, componentId, drawable, 0)
                Wait(100)

                if camSettings.hideComponents and #camSettings.hideComponents > 0 then
                    HidePedComponents(ped, camSettings.hideComponents)
                end

                SetupCamera(ped, camSettings)

                local filename = string.format('%s_%s_%d%s', g, camSettings.name, drawable, GetFileExtension())

                if not isCapturing then goto cleanup end

                AwaitCapture(filename, 'clothing')
                totalCaptures = totalCaptures + 1

                Wait(Config.CaptureDelay)
            end

            ::continue_component::
        end

        if capturePed and DoesEntityExist(capturePed) then
            DeleteEntity(capturePed)
            capturePed = nil
        end

        ::continue_gender::
    end

    ::cleanup::
    HideProgress()
    CleanupStudio()
    ShowNotification('Clothing capture complete: ' .. totalCaptures .. ' images')
end


RegisterCommand('capture-clothing', function(source, args)
    local gender = args[1] or 'all'
    local component = args[2] or nil

    if gender ~= 'male' and gender ~= 'female' and gender ~= 'all' then
        ShowNotification('Usage: /capture-clothing [male|female|all] [component]')
        return
    end

    CreateThread(function()
        CaptureClothing(gender, component)
    end)
end, false)


CreateThread(function()
    while true do
        Wait(0)
        if isCapturing then
            if IsControlJustPressed(0, Config.AdjustControls.cancel) then
                isCapturing = false
                ShowNotification('Capture stopped')
                HideProgress()
            end
        else
            Wait(100)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CleanupStudio()
    end
end)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/capture-clothing', 'Capture clothing images for meteo-appearance', {
        { name = 'gender', help = 'male / female / all (default: all)' },
        { name = 'component', help = 'mask, torso, legs, bag, shoes, top (optional - captures all if omitted)' }
    })
end)
