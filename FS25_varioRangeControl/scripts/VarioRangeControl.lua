-- scripts/VarioRangeControl.lua
-- FS25: Vario Range Control specialization
--
-- in vehicle.xml do:
--
--	<transmission>
--		<varioRanges forwardSpeedRange1="36" forwardSpeedRange2="53" backwardSpeedRange1="20" backwardSpeedRange2="38"/>
--	</transmission>
--

VarioRangeControl = {}

function VarioRangeControl.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function VarioRangeControl.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("VarioRangeControl")

    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#forwardSpeedRange1", "Max forward speed in range I (km/h)")
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#forwardSpeedRange2", "Max forward speed in range II (km/h)")
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#backwardSpeedRange1", "Max backward speed in range I (km/h)")
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#backwardSpeedRange2", "Max backward speed in range II (km/h)")
    schema:register(XMLValueType.INT,   "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#defaultRange", "Default range (1 = I, 2 = II)", 2)

    schema:setXMLSpecializationType()
end

function VarioRangeControl.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setVarioRange", VarioRangeControl.setVarioRange)
    SpecializationUtil.registerFunction(vehicleType, "getVarioRange", VarioRangeControl.getVarioRange)
end

function VarioRangeControl.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", VarioRangeControl)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", VarioRangeControl)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", VarioRangeControl)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", VarioRangeControl)
end

function VarioRangeControl.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSpeedLimit", VarioRangeControl.getSpeedLimit)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getGearInfoToDisplay", VarioRangeControl.getGearInfoToDisplay)
end

function VarioRangeControl.getVarioRangeSpeedsFromXML(xmlFile, spec, baseKey)
    baseKey = baseKey or "vehicle.motorized.motorConfigurations.motorConfiguration(0).transmission.varioRanges"

    local forwardSpeedRange1 = xmlFile:getValue(baseKey .. "#forwardSpeedRange1")
    local backwardSpeedRange1 = xmlFile:getValue(baseKey .. "#backwardSpeedRange1")
    local forwardSpeedRange2 = xmlFile:getValue(baseKey .. "#forwardSpeedRange2")
    local backwardSpeedRange2 = xmlFile:getValue(baseKey .. "#backwardSpeedRange2")

    if forwardSpeedRange1 ~= nil then
        spec.range1ForwardSpeed = forwardSpeedRange1
    end

    if forwardSpeedRange2 ~= nil then
        spec.forwardSpeedRange2 = forwardSpeedRange2
    end

    if backwardSpeedRange1 ~= nil then
        spec.backwardSpeedRange1 = backwardSpeedRange1
    end

    if backwardSpeedRange2 ~= nil then
        spec.backwardSpeedRange2 = backwardSpeedRange2
    end
end

function VarioRangeControl:onLoad(savegame)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        self.spec_varioRangeControl = {}
        spec = self.spec_varioRangeControl
    end

    local transmissionKey = "vehicle.motorized.motorConfigurations.motorConfiguration(0).transmission.varioRanges"
    if not self.xmlFile:hasProperty(transmissionKey) then
        self.spec_varioRangeControl = nil
        return
    end
	
	-- fallback speeds if they are not set in xml
	-- could use maxForwardSpeed/maxBackwardSpeed as fallback, but if you are using this script you _should_ set everything in <varioRanges> anyway
    spec.forwardSpeedRange1 = 36
    spec.backwardSpeedRange1 = 20
    spec.forwardSpeedRange2 = 53
    spec.backwardSpeedRange2 = 38

    VarioRangeControl.getVarioRangeSpeedsFromXML(self.xmlFile, spec, transmissionKey)

    spec.currentRange = math.clamp(self.xmlFile:getValue(transmissionKey .. "#defaultRange", 2) or 2, 1, 2)

    spec.actionEvents = {}
    spec.varioActionEventId = nil
end

function VarioRangeControl:onPostLoad(savegame)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        return
    end
end

function VarioRangeControl:onDelete()
    self.spec_varioRangeControl = nil
end

function VarioRangeControl:getSpeedLimit(superFunc, onlyIfWorking)
    local limit, doCheckSpeedLimit = superFunc(self, onlyIfWorking)

    local spec = self.spec_varioRangeControl
    if spec == nil then
        return limit, doCheckSpeedLimit
    end

    local movingDirection = self.movingDirection or 1
    local isReverse = movingDirection < 0

    local forwardLimit = (spec.currentRange == 1) and spec.range1ForwardSpeed or spec.forwardSpeedRange2
    local backwardLimit = (spec.currentRange == 1) and spec.backwardSpeedRange1 or spec.backwardSpeedRange2
    local rangeLimit = isReverse and backwardLimit or forwardLimit
    if rangeLimit ~= nil and rangeLimit > 0 then
        if limit == nil then
            limit = rangeLimit
        else
            limit = math.min(limit, rangeLimit)
        end
    end

    return limit, doCheckSpeedLimit
end

function VarioRangeControl:getVarioRange()
    local spec = self.spec_varioRangeControl
    if spec ~= nil then
        return spec.currentRange or 1
    end
    return nil
end

function VarioRangeControl:setVarioRange(rangeIndex)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        return
    end

    rangeIndex = math.clamp(math.floor(rangeIndex or 1), 1, 2)
    if spec.currentRange ~= rangeIndex then
        spec.currentRange = rangeIndex
    end
end

function VarioRangeControl:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if not self.isClient then
        return
    end

    local spec = self.spec_varioRangeControl
    if spec == nil then
        return
    end

    self:clearActionEventsTable(spec.actionEvents)

    if isActiveForInputIgnoreSelection then
        local _, actionEventId = self:addActionEvent(
            spec.actionEvents,
            InputAction.VARIO_TOGGLE_RANGE,
            self,
            VarioRangeControl.actionEventToggleRange,
            false,
            true,
            false,
            true,
            nil
        )

        spec.varioActionEventId = actionEventId

        if actionEventId ~= nil then
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            VarioRangeControl.updateActionEventText(self)
        end
    end
end

function VarioRangeControl.actionEventToggleRange(self, actionName, inputValue, callbackState, isAnalog)
    if inputValue == 0 then
        return
    end

    local current = self:getVarioRange()
    local newRange = (current == 1) and 2 or 1

    self:setVarioRange(newRange)
    VarioRangeControl.updateActionEventText(self)
end

-- display F1 help menu action text
function VarioRangeControl.updateActionEventText(self)
    local spec = self.spec_varioRangeControl
    if spec == nil or spec.varioActionEventId == nil then
        return
    end

    local label
    if spec.currentRange == 1 then
        if g_i18n ~= nil and g_i18n:hasText("input_VARIO_RANGE_I") then
            label = g_i18n:getText("input_VARIO_RANGE_I")
        end
    else
        if g_i18n ~= nil and g_i18n:hasText("input_VARIO_RANGE_II") then
            label = g_i18n:getText("input_VARIO_RANGE_II")
        end
    end

    g_inputBinding:setActionEventText(spec.varioActionEventId, label)
end

-- display the current vario range on the speedometer HUD
function VarioRangeControl:getGearInfoToDisplay(superFunc)
    local gearName, gearGroupName, gearsAvailable, isAutomatic, prevGearName, nextGearName, prevPrevGearName, nextNextGearName, isGearChanging, showNeutralWarning = superFunc(self)

    local spec = self.spec_varioRangeControl
    if spec ~= nil then
        local range = self:getVarioRange()
        if range ~= nil then
            -- set current vario range as the gear group
            gearGroupName = (range == 2) and "II" or "I"

            -- mark as non-automatic so HUD actually draws gearGroupName
            isAutomatic = false
        end
    end

    return gearName, gearGroupName, gearsAvailable, isAutomatic, prevGearName, nextGearName, prevPrevGearName, nextNextGearName, isGearChanging, showNeutralWarning
end
