-- scripts/VarioRangeControlVehicleConfigs.lua
--
-- Vehicle configuration injector for VarioRangeControl
-- Loads external XML definitions and injects them into vehicle XML before VarioRangeControl reads them

VarioRangeControlVehicleConfigs = {}

local CONFIG_XML_PATH = g_currentModDirectory .. "vehicleConfigs.xml"


function VarioRangeControlVehicleConfigs.getNormalizedFilename(vehicle)
    if vehicle == nil or vehicle.configFileName == nil then
        return nil
    end

    return string.lower(vehicle.configFileName):gsub("\\", "/")
end


function VarioRangeControlVehicleConfigs.injectVehicleConfigs(self)

    -- Safeguard: config XML must exist
    if not fileExists(CONFIG_XML_PATH) then
        return
    end

    local xmlFile = XMLFile.load("varioRangeControlVehicleConfigs", CONFIG_XML_PATH)

    if xmlFile == nil then
        return
    end

    local vehicleFilename = VarioRangeControlVehicleConfigs.getNormalizedFilename(self)

    if vehicleFilename == nil then
        xmlFile:delete()
        return
    end


    local i = 0

    while true do

        local vehicleKey = string.format("vehicleConfigs.vehicle(%d)", i)

        if not xmlFile:hasProperty(vehicleKey) then
            break
        end

        local filename = xmlFile:getString(vehicleKey .. "#filename")

        if filename ~= nil then

            filename = string.lower(filename):gsub("\\", "/")

            if filename == vehicleFilename then

                local j = 0

                while true do

                    local setKey = string.format("%s.injections.set(%d)", vehicleKey, j)

                    if not xmlFile:hasProperty(setKey) then
                        break
                    end

					local path = xmlFile:getString(setKey .. "#path")
					local value = xmlFile:getString(setKey .. "#value")

					if path ~= nil and value ~= nil then
						local numericValue = tonumber(value)

						if numericValue ~= nil then
							value = numericValue
						end

						self.xmlFile:setValue(path, value)
					end

                    j = j + 1
                end

                break
            end
        end

        i = i + 1
    end

    xmlFile:delete()
end


VarioRangeControl.onLoad = Utils.prependedFunction(
    VarioRangeControl.onLoad,
    VarioRangeControlVehicleConfigs.injectVehicleConfigs
)