Config = {}

Config.StudioLocation = vector3(628.8900, 1419.6689, 2403.6514) -- Way up in the sky so nobody sees it

Config.OutputSize = 512 -- 256, 512, or 1024
Config.OutputFormat = 'webp'

Config.GreenThreshold = 120
Config.GreenDiff = 40

-- Crop FiveM UI from bottom-right before processing
Config.CropBottom = 80
Config.CropRight = 80

Config.CaptureDelay = 500

Config.Weather = 'EXTRASUNNY'
Config.Time = { hour = 12, minute = 0, second = 0 }
Config.FreezeTime = true

Config.PedModels = {
    male = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01'
}

-- Only the 6 components used by meteo-appearance
-- hideComponents: hide specific parts (0=head, 2=hair, etc.)
-- heading: camera orbit position | pedHeading: which way ped faces
Config.ClothingCamera = {
    [1] = { name = 'mask', fov = 45, zOffset = 0.70, distance = 27.8, heading = 339, pedHeading = 0.0, hideComponents = {0} },
    [3] = { name = 'torso', fov = 50, zOffset = 0.3, distance = 60.0, heading = 0.0, pedHeading = 0.0, hideComponents = {} },
    [4] = { name = 'legs', fov = 55, zOffset = -0.43, distance = 67.5, heading = 0.0, pedHeading = 0.0, hideComponents = {} },
    [5] = { name = 'bag', fov = 50, zOffset = 0.40, distance = 67.3, heading = 0.0, pedHeading = 175.00, hideComponents = {0} },
    [6] = { name = 'shoes', fov = 50, zOffset = -0.71, distance = 52.0, heading = 0.0, pedHeading = 337.0, hideComponents = {} },
    [11] = { name = 'top', fov = 50, zOffset = 0.27, distance = 82.6, heading = 0.0, pedHeading = 0.0, hideComponents = {0} },
}

-- Green screen setup
Config.GreenScreenProp = 'prop_big_cin_screen'
Config.GreenScreenOffsets = {
    vector3(0.0, 0.0, 15.0),
    vector3(0.0, 0.0, 0.0),
    vector3(0.0, 0.0, -15.0),
}

Config.AdjustControls = {
    cancel = 194, -- BACKSPACE (used to stop an in-progress capture)
}
