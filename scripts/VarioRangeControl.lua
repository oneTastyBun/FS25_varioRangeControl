-- scripts/VarioRangeControl.lua
-- FS25: Vario Range Control specialization
--
-- https://github.com/oneTastyBun/FS25_varioRangeControl


VarioRangeControl = {}

function VarioRangeControl.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function VarioRangeControl.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("VarioRangeControl")

    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges.range1#maxForwardSpeed", "Max forward speed in range I (km/h)", 36)
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges.range1#maxBackwardSpeed", "Max backward speed in range I (km/h)", 20)

    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges.range1#minForwardGearRatio",  "Min forward gear ratio in range I",  nil)
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges.range1#maxForwardGearRatio",  "Max forward gear ratio in range I",  nil)
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges.range1#minBackwardGearRatio", "Min backward gear ratio in range I", nil)
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges.range1#maxBackwardGearRatio", "Max backward gear ratio in range I", nil)

    schema:register(XMLValueType.INT,   "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#defaultRange", "Default range (1 = I, 2 = II)", 2)

    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#shiftSpeedMax", "Max vehicle speed for range shift (km/h)", 2.5)

    schema:setXMLSpecializationType()
	
	local schemaSavegame = Vehicle.xmlSchemaSavegame
	schemaSavegame:setXMLSpecializationType("FS25_varioRangeControl.varioRangeControl")
	schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?).FS25_varioRangeControl.varioRangeControl#currentRange", "Current vario range", 2)
	schemaSavegame:setXMLSpecializationType()
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
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", VarioRangeControl)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", VarioRangeControl)
end

function VarioRangeControl.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSpeedLimit", VarioRangeControl.getSpeedLimit)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getGearInfoToDisplay", VarioRangeControl.getGearInfoToDisplay)
end

function VarioRangeControl.getLogContext(self, spec)
    local motorConfigName = "Motor configuration"
    if spec ~= nil and spec.motorConfigName ~= nil and spec.motorConfigName ~= "" then
        motorConfigName = spec.motorConfigName
    end

    return motorConfigName
end

function VarioRangeControl.logConfigError(self, spec, message, ...)
    local motorConfigName = VarioRangeControl.getLogContext(self, spec)
    Logging.error("VarioRangeControl: %s " .. message, motorConfigName, ...)
end

function VarioRangeControl.logConfigWarning(self, spec, message, ...)
    local motorConfigName = VarioRangeControl.getLogContext(self, spec)
    Logging.warning("VarioRangeControl: %s " .. message, motorConfigName, ...)
end

function VarioRangeControl.validatePositiveRatio(self, spec, value, ratioName)
    if value ~= nil and value <= 0 then
        VarioRangeControl.logConfigWarning(self, spec, "invalid %s (%s). Using base transmission values.", ratioName, tostring(value))
        return nil
    end

    return value
end

function VarioRangeControl.loadVarioRangesFromXML(self, xmlFile, key, spec)
    spec.forwardSpeedRange1  = xmlFile:getValue(key .. ".range1#maxForwardSpeed", 36)
    spec.backwardSpeedRange1 = xmlFile:getValue(key .. ".range1#maxBackwardSpeed", 20)
	
    spec.range1MinForwardGearRatio  = xmlFile:getValue(key .. ".range1#minForwardGearRatio")
    spec.range1MaxForwardGearRatio  = xmlFile:getValue(key .. ".range1#maxForwardGearRatio")
    spec.range1MinBackwardGearRatio = xmlFile:getValue(key .. ".range1#minBackwardGearRatio")
    spec.range1MaxBackwardGearRatio = xmlFile:getValue(key .. ".range1#maxBackwardGearRatio")

    local defaultRange = xmlFile:getValue(key.."#defaultRange", 2)
    spec.shiftSpeedMax  = xmlFile:getValue(key.."#shiftSpeedMax", 2.5)

    if defaultRange < 1 or defaultRange > 2 then
        local clampedDefaultRange = math.clamp(defaultRange, 1, 2)
        VarioRangeControl.logConfigWarning(self, spec, "invalid defaultRange (%s). Clamped to %d.", tostring(defaultRange), clampedDefaultRange)
        defaultRange = clampedDefaultRange
    end

    if spec.shiftSpeedMax < 0 then
        VarioRangeControl.logConfigWarning(self, spec, "invalid shiftSpeedMax (%s). Clamped to 0.", tostring(spec.shiftSpeedMax))
        spec.shiftSpeedMax = 0
    end

    if spec.forwardSpeedRange1 <= 0 then
        VarioRangeControl.logConfigError(self, spec, "invalid maxForwardSpeed (%s). Disabled.", tostring(spec.forwardSpeedRange1))
        return false
    end

    if spec.backwardSpeedRange1 <= 0 then
        VarioRangeControl.logConfigError(self, spec, "invalid maxBackwardSpeed (%s). Disabled.", tostring(spec.backwardSpeedRange1))
        return false
    end

    spec.range1MinForwardGearRatio = VarioRangeControl.validatePositiveRatio(self, spec, spec.range1MinForwardGearRatio, "minForwardGearRatio")
    spec.range1MaxForwardGearRatio = VarioRangeControl.validatePositiveRatio(self, spec, spec.range1MaxForwardGearRatio, "maxForwardGearRatio")
    spec.range1MinBackwardGearRatio = VarioRangeControl.validatePositiveRatio(self, spec, spec.range1MinBackwardGearRatio, "minBackwardGearRatio")
    spec.range1MaxBackwardGearRatio = VarioRangeControl.validatePositiveRatio(self, spec, spec.range1MaxBackwardGearRatio, "maxBackwardGearRatio")

    if spec.range1MinForwardGearRatio ~= nil and spec.range1MaxForwardGearRatio ~= nil and spec.range1MinForwardGearRatio > spec.range1MaxForwardGearRatio then
        VarioRangeControl.logConfigWarning(self, spec, "invalid forward ratios. Using base transmission values.")
        spec.range1MinForwardGearRatio = nil
        spec.range1MaxForwardGearRatio = nil
    end

    if spec.range1MinBackwardGearRatio ~= nil and spec.range1MaxBackwardGearRatio ~= nil and spec.range1MinBackwardGearRatio > spec.range1MaxBackwardGearRatio then
        VarioRangeControl.logConfigWarning(self, spec, "invalid backward ratios. Using base transmission values.")
        spec.range1MinBackwardGearRatio = nil
        spec.range1MaxBackwardGearRatio = nil
    end

    -- true if we have configured at least one gear ratio
    spec.hasGearRatioConfig =
        spec.range1MinForwardGearRatio  ~= nil or
        spec.range1MaxForwardGearRatio  ~= nil or
        spec.range1MinBackwardGearRatio ~= nil or
        spec.range1MaxBackwardGearRatio ~= nil
	
	-- initialize spec.currentRange
    spec.currentRange = defaultRange

    return true
end

function VarioRangeControl:onLoad(savegame)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        self.spec_varioRangeControl = {}
        spec = self.spec_varioRangeControl
    end

	-- check <varioRanges> exists in the vehicle xml, otherwise exit
	--
    -- self.configurations["motor"] is 1-based
    -- motorConfiguration(?) is 0-based in XML
    local motorConfigIndex = Utils.getNoNil(self.configurations["motor"], 1) - 1

    local key = string.format(
        "vehicle.motorized.motorConfigurations.motorConfiguration(%d).transmission.varioRanges",
        motorConfigIndex
    )

    -- fallback
    if not self.xmlFile:hasProperty(key) then
        key = "vehicle.motorized.motorConfigurations.motorConfiguration(0).transmission.varioRanges"
    end
	
	-- exit
    if not self.xmlFile:hasProperty(key) then
        self.spec_varioRangeControl = nil
        return
    end
	--

    local motorConfigurationKey = key:gsub("%.transmission%.varioRanges$", "")
    spec.motorConfigName = self.xmlFile:getValue(motorConfigurationKey .. "#name")

	-- load configuration data from vehicle XML
    if not VarioRangeControl.loadVarioRangesFromXML(self, self.xmlFile, key, spec) then
        self.spec_varioRangeControl = nil
        return
    end

    spec.actionEvents = {}
    spec.varioActionEventId = nil
end

function VarioRangeControl:onPostLoad(savegame)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        return
    end
	
	-- save/load range to vehicles.xml
    if savegame ~= nil and not savegame.resetVehicles then
        local key = savegame.key .. ".FS25_varioRangeControl.varioRangeControl"
        VarioRangeControl.loadRangeFromSavegameXML(self, savegame.xmlFile, key)
    end

    -- apply initial gear ratios for default range
    VarioRangeControl.applyGearRatios(self)
end

function VarioRangeControl:onDelete()
    self.spec_varioRangeControl = nil
end

function VarioRangeControl:onWriteStream(streamId, connection)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        streamWriteBool(streamId, false)
        return
    end

    streamWriteBool(streamId, true)
    streamWriteUIntN(streamId, spec.currentRange or 2, 2)
end

function VarioRangeControl:onReadStream(streamId, connection)
    if not streamReadBool(streamId) then
        return
    end

    local spec = self.spec_varioRangeControl
    if spec == nil then
        return
    end

    spec.currentRange = streamReadUIntN(streamId, 2)
    VarioRangeControl.applyGearRatios(self)
end

function VarioRangeControl:getSpeedLimit(superFunc, onlyIfWorking)
    local limit, doCheckSpeedLimit = superFunc(self, onlyIfWorking)

    local spec = self.spec_varioRangeControl
    if spec == nil then
        return limit, doCheckSpeedLimit
    end

    local movingDirection = self.movingDirection or 1
    local isReverse = movingDirection < 0

    if spec.currentRange == 1 then
        local forwardLimit = spec.forwardSpeedRange1
        local backwardLimit = spec.backwardSpeedRange1
        local rangeLimit = isReverse and backwardLimit or forwardLimit
        if rangeLimit ~= nil and rangeLimit > 0 then
            if limit == nil then
                limit = rangeLimit
            else
                limit = math.min(limit, rangeLimit)
            end
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

        -- update motor gear ratio limits for the new range
        VarioRangeControl.applyGearRatios(self)
    end
end

function VarioRangeControl.canShiftRange(self)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        return false
    end

    local speedKmh = math.abs(self:getLastSpeed() or 0)
    local maxSpeed = math.max(spec.shiftSpeedMax or 0, 0)

    -- allow tiny standing-still jitter when shiftSpeedMax is 0
    local speedTolerance = 0.15

    if maxSpeed <= 0 then
        return speedKmh <= speedTolerance
    end

    return speedKmh <= maxSpeed
end

function VarioRangeControl.applyGearRatios(self)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        return
    end

    local motorizedSpec = self.spec_motorized
    if motorizedSpec == nil or motorizedSpec.motor == nil then
        return
    end

    local motor = motorizedSpec.motor
	
    -- cache original base ratios once
    if spec.baseMinForwardGearRatio == nil then
        spec.baseMinForwardGearRatio  = motor.minForwardGearRatioOrigin or motor.minForwardGearRatio
        spec.baseMaxForwardGearRatio  = motor.maxForwardGearRatioOrigin or motor.maxForwardGearRatio
        spec.baseMinBackwardGearRatio = motor.minBackwardGearRatioOrigin or motor.minBackwardGearRatio
        spec.baseMaxBackwardGearRatio = motor.maxBackwardGearRatioOrigin or motor.maxBackwardGearRatio
    end
	
    local rangeIndex = spec.currentRange or 2

    if rangeIndex == 1 and spec.hasGearRatioConfig then
        local minF = spec.range1MinForwardGearRatio
        local maxF = spec.range1MaxForwardGearRatio
        local minB = spec.range1MinBackwardGearRatio
        local maxB = spec.range1MaxBackwardGearRatio

        -- only change what’s actually set in XML
        if minF ~= nil then
            motor.minForwardGearRatio       = minF
            motor.minForwardGearRatioOrigin = minF
        end

        if maxF ~= nil then
            motor.maxForwardGearRatio       = maxF
            motor.maxForwardGearRatioOrigin = maxF
        end

        if minB ~= nil then
            motor.minBackwardGearRatio       = minB
            motor.minBackwardGearRatioOrigin = minB
        end

        if maxB ~= nil then
            motor.maxBackwardGearRatio       = maxB
            motor.maxBackwardGearRatioOrigin = maxB
        end
    else
        motor.minForwardGearRatio       = spec.baseMinForwardGearRatio
        motor.minForwardGearRatioOrigin = spec.baseMinForwardGearRatio
        motor.maxForwardGearRatio       = spec.baseMaxForwardGearRatio
        motor.maxForwardGearRatioOrigin = spec.baseMaxForwardGearRatio
        motor.minBackwardGearRatio       = spec.baseMinBackwardGearRatio
        motor.minBackwardGearRatioOrigin = spec.baseMinBackwardGearRatio
        motor.maxBackwardGearRatio       = spec.baseMaxBackwardGearRatio
        motor.maxBackwardGearRatioOrigin = spec.baseMaxBackwardGearRatio
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

	-- only allow shift when speed is within allowed range
	if not VarioRangeControl.canShiftRange(self) then
		local mission = g_currentMission
		if mission ~= nil and g_i18n ~= nil then
			mission:showBlinkingWarning(g_i18n:getText("warning_VARIO_RANGE_TOO_FAST"), 2000)
		end
		return
	end

	local current = self:getVarioRange()
	local newRange = (current == 1) and 2 or 1

	self:setVarioRange(newRange)

	-- MP - client sends request to server; server broadcasts and applies
	if g_server ~= nil then
		g_server:broadcastEvent(VarioRangeControlEvent.new(self, newRange), nil, nil, self)
	else
		g_client:getServerConnection():sendEvent(VarioRangeControlEvent.new(self, newRange))
	end
end

-- display F1 help menu action text
function VarioRangeControl.updateActionEventText(self)
    local spec = self.spec_varioRangeControl
    if spec == nil or spec.varioActionEventId == nil or g_i18n == nil then
        return
    end

    g_inputBinding:setActionEventText(spec.varioActionEventId, g_i18n:getText("action_VARIO_TOGGLE_RANGE"))
end
--

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
--

-- save/load range to vehicles.xml
function VarioRangeControl.loadRangeFromSavegameXML(self, xmlFile, key)
    local spec = self.spec_varioRangeControl
    if spec == nil or xmlFile == nil or key == nil then
        return false
    end

    local savedRange = xmlFile:getValue(key .. "#currentRange")
    if savedRange ~= nil then
        self:setVarioRange(savedRange)
        return true
    end

    return false
end

function VarioRangeControl.writeRangeToSavegameXML(self, xmlFile, key)
    local spec = self.spec_varioRangeControl
    if spec == nil or xmlFile == nil or key == nil then
        return false
    end

    xmlFile:setValue(key .. "#currentRange", spec.currentRange or 2)
    return true
end

function VarioRangeControl:saveToXMLFile(xmlFile, key, usedModNames)
    VarioRangeControl.writeRangeToSavegameXML(self, xmlFile, key)
end
--

function VarioRangeControl.getActiveMotorConfigurationIndex(self)
    local motorizedSpec = self.spec_motorized
    if motorizedSpec ~= nil then
        -- try the most likely places first
        if motorizedSpec.motorConfigurationIndex ~= nil then
            return motorizedSpec.motorConfigurationIndex
        end

        if motorizedSpec.currentMotorConfigurationIndex ~= nil then
            return motorizedSpec.currentMotorConfigurationIndex
        end
    end

    -- generic fallback: configuration table used by many vehicles
    if self.configurations ~= nil and self.configurations.motor ~= nil then
        return self.configurations.motor - 1
    end

    return 0
end
