-- scripts/VarioRangeControl_register.lua
-- Attach specialization to the tractor vehicle type and any vehicle types inheriting from it

local modName = g_currentModName
local modDir = g_currentModDirectory
local localSpecName = "varioRangeControl"
local fullSpecName = modName .. "." .. localSpecName
local registrationDone = false

local function hasVehicleTypeParent(vehicleType, parentTypeName)
    local currentType = vehicleType

    while currentType ~= nil do
        if currentType.name == parentTypeName then
            return true
        end

        currentType = currentType.parent
    end

    return false
end


local function registerSpecialization(self)
    if registrationDone then
        return
    end

    if self == nil or self.typeName ~= "vehicle" then
        return
    end

    registrationDone = true

    local count = 0

    g_specializationManager:addSpecialization(
        localSpecName,
        "VarioRangeControl",
        modDir .. "scripts/VarioRangeControl.lua"
    )

    for typeName, vehicleType in pairs(self:getTypes()) do
        if vehicleType ~= nil
            and hasVehicleTypeParent(vehicleType, "tractor")
            and vehicleType.specializationsByName[fullSpecName] == nil then

            self:addSpecialization(typeName, fullSpecName)
            count = count + 1

			-- for debugging
            print(string.format(
                "[%s] Attached VarioRangeControl specialization to vehicle type '%s' (parent: %s)",
                modName,
                vehicleType.name,
                vehicleType.parent and vehicleType.parent.name or "none"
            ))
			
			-- for release
			-- Logging.info("[%s] VarioRangeControl attached to vehicle type '%s'", modName, vehicleType.name)
        end
    end
	
	-- for debugging
    print(string.format("[%s] VarioRangeControl attached to %d vehicle types", modName, count))
	
	-- for release
	-- Logging.info("[%s] VarioRangeControl attached to %d vehicle types", modName, count)
end


TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, registerSpecialization)
