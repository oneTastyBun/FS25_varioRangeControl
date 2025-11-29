-- scripts/VarioRangeControl.lua
-- FS25: Vario Range Control specialization
--
-- in vehicle.xml, do:
--
--	<transmission>
--		<varioRanges forwardSpeedRange1="36" forwardSpeedRange2="53" backwardSpeedRange1="20" backwardSpeedRange2="38" defaultRange="2" shiftSpeedMax="2.5"/>
--	</transmission>
--
-- idea: add min/max gear ratio in each range maybe
-- not sure if there will be a noticeable gameplay difference, since the FS CVT always finds the perfect rpm with no power loss etc
-- IRL: the tractor feels more sluggish and "rumbly" if you are in range II under high load at slow speeds. you can feel it
--
-- idea: require clutch press/neutral active and a certain max speed to shift ranges, like irl
-- example pulled from fendt favorit 900 gen 2 workshop manual:
-- I->II and II -> I is allowed if: speed 0-2.5km/h + neutral active/clutch pressed
-- I->II is allowed if: speed above 5km/h + neutral active/clutch pressed + load not too big. (max. 150 bar in vario high-pressure circuit)
--
-- issue: clutch or neutral do not exist for CVT transmissions in FS25
-- requiring pressing the clutch key would feel unnatural in the game, since nothing happens (no free-rolling or able to rev the engine)
-- this would require adding a clutch/neutral feature for CVT first
--
-- feature update 27/11/2025: implemented configurable max speed for range shift

VarioRangeControl = {}

function VarioRangeControl.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function VarioRangeControl.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("VarioRangeControl")

    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#forwardSpeedRange1", "Max forward speed in range I (km/h)", 36)
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#forwardSpeedRange2", "Max forward speed in range II (km/h)", 53)
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#backwardSpeedRange1", "Max backward speed in range I (km/h)", 20)
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#backwardSpeedRange2", "Max backward speed in range II (km/h)", 38)
    schema:register(XMLValueType.INT,   "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#defaultRange", "Default range (1 = I, 2 = II)", 2)

    -- 27/11/2025 update
    schema:register(XMLValueType.FLOAT, "vehicle.motorized.motorConfigurations.motorConfiguration(?).transmission.varioRanges#shiftSpeedMax", "Max vehicle speed for range shift (km/h)", 2.5)

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

function VarioRangeControl.loadVarioRangesFromXML(xmlFile, key, spec)
	-- could use maxForwardSpeed/maxBackwardSpeed, but if you are using this script you _should_ set everything in <varioRanges> anyway
	
	-- defaults are based on data from official user manual / repair manual for fendt 900 vario gen 2
    spec.forwardSpeedRange1 = xmlFile:getValue(key.."#forwardSpeedRange1", 36)
    spec.backwardSpeedRange1 = xmlFile:getValue(key.."#backwardSpeedRange1", 20)
    spec.forwardSpeedRange2 = xmlFile:getValue(key.."#forwardSpeedRange2", 53)
    spec.backwardSpeedRange2 = xmlFile:getValue(key.."#backwardSpeedRange2", 38)
    local defaultRange = xmlFile:getValue(key.."#defaultRange", 2)
    spec.shiftSpeedMax  = xmlFile:getValue(key.."#shiftSpeedMax", 2.5) -- 27/11/2025 update

	-- initialize spec.currentRange
    spec.currentRange = math.clamp(defaultRange, 1, 2)
end

function VarioRangeControl:onLoad(savegame)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        self.spec_varioRangeControl = {}
        spec = self.spec_varioRangeControl
    end

	-- check <varioRanges> exists in the vehicle xml, otherwise exit
    local key = "vehicle.motorized.motorConfigurations.motorConfiguration(0).transmission.varioRanges"
    if not self.xmlFile:hasProperty(key) then
        self.spec_varioRangeControl = nil
        return
    end

	-- load configuration data from vehicle XML
    VarioRangeControl.loadVarioRangesFromXML(self.xmlFile, key, spec)

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

    local forwardLimit = (spec.currentRange == 1) and spec.forwardSpeedRange1  or spec.forwardSpeedRange2
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

-- 27/11/2025 update
function VarioRangeControl.canShiftRange(self)
    local spec = self.spec_varioRangeControl
    if spec == nil then
        return false
    end

    local speedKmh = self:getLastSpeed()
    local maxSpeed = spec.shiftSpeedMax or 1

    if speedKmh > maxSpeed then
        return false
    end
	
	return true
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

    -- 27/11/2025 NEW: only allow shift when speed is within allowed range
    if not VarioRangeControl.canShiftRange(self) then
        if g_currentMission ~= nil then
            g_currentMission:showBlinkingWarning("Unable to change Vario range: Slow down!", 2000)
        end
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

