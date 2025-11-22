-- scripts/VarioRangeControl_register.lua
-- Registers the specialization and injects it into the default 'tractor' vehicle type.

-- Register specialization
g_specializationManager:addSpecialization(
    "varioRangeControl",
    "VarioRangeControl",
    g_currentModDirectory.."scripts/VarioRangeControl.lua"
)

VarioRangeControlRegister = {}
VarioRangeControlRegister.done = false

function VarioRangeControlRegister:register(name)
    if VarioRangeControlRegister.done then
        return
    end

    print("VarioRangeControlRegister: running TypeManager.finalizeTypes hook")

    for _, vehicleType in pairs(g_vehicleTypeManager:getTypes()) do
        local motorized = false
        local hasVario  = false

        for _, specName in pairs(vehicleType.specializationNames) do
            if specName == "motorized" then
                motorized = true
            end
            if specName == "varioRangeControl" then
                hasVario = true
            end
        end

        if motorized and vehicleType.name == "tractor" then
            if not hasVario then
                print("varioRangeControl: attaching varioRangeControl to vehicleType '" .. tostring(vehicleType.name) .. "'")
                g_vehicleTypeManager:addSpecialization(
                    vehicleType.name,
                    "FS25_varioRangeControl.varioRangeControl"
                )
            else
                print("varioRangeControl: vehicleType '" .. tostring(vehicleType.name) .. "' already has varioRangeControl")
            end
        end
    end

    VarioRangeControlRegister.done = true
end

TypeManager.finalizeTypes = Utils.prependedFunction(
    TypeManager.finalizeTypes,
    VarioRangeControlRegister.register
)
