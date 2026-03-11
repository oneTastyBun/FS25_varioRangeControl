-- scripts/VarioRangeControlDebug.lua
-- Wrap GIANTS' transmission debug (gsVehicleDebug SHIFT+4) and append Vario Range Control values

if VehicleDebug ~= nil and VehicleDebug.drawTransmissionDebug ~= nil then
    local vrc_oldDrawTransmissionDebug = VehicleDebug.drawTransmissionDebug

    function VehicleDebug.drawTransmissionDebug(self, ...)
        -- call original GIANTS implementation
        vrc_oldDrawTransmissionDebug(self, ...)

        if VarioRangeControl == nil then
            return
        end

        local spec = self.spec_varioRangeControl
        if spec == nil then
            return
        end

        local motorSpec = self.spec_motorized
        local motor = motorSpec and motorSpec.motor
        if motor == nil then
            return
        end

        local rangeIndex = spec.currentRange or 2
        local rangeText = (rangeIndex == 2) and "II" or "I"
        local sourceText = (rangeIndex == 1) and "XML" or "GIANTS"

        local forwardSpeed
        local backwardSpeed
        local minForwardGearRatio
        local maxForwardGearRatio
        local minBackwardGearRatio
        local maxBackwardGearRatio

        if rangeIndex == 1 then
            forwardSpeed = spec.forwardSpeedRange1 or 0
            backwardSpeed = spec.backwardSpeedRange1 or 0
            minForwardGearRatio = spec.range1MinForwardGearRatio
            maxForwardGearRatio = spec.range1MaxForwardGearRatio
            minBackwardGearRatio = spec.range1MinBackwardGearRatio
            maxBackwardGearRatio = spec.range1MaxBackwardGearRatio
        else
            forwardSpeed = (motor.maxForwardSpeedOrigin or motor.maxForwardSpeed or 0) * 3.6
            backwardSpeed = (motor.maxBackwardSpeedOrigin or motor.maxBackwardSpeed or 0) * 3.6
            minForwardGearRatio = spec.baseMinForwardGearRatio or motor.minForwardGearRatioOrigin or motor.minForwardGearRatio
            maxForwardGearRatio = spec.baseMaxForwardGearRatio or motor.maxForwardGearRatioOrigin or motor.maxForwardGearRatio
            minBackwardGearRatio = spec.baseMinBackwardGearRatio or motor.minBackwardGearRatioOrigin or motor.minBackwardGearRatio
            maxBackwardGearRatio = spec.baseMaxBackwardGearRatio or motor.maxBackwardGearRatioOrigin or motor.maxBackwardGearRatio
        end

        local function formatRatio(value)
            if value == nil then
                return "n/a"
            end

            return string.format("%.3f", value)
        end

        -- build multi-column strings like VehicleDebug.drawBaseDebugRendering
        local str1, str2 = "", ""

        str1 = str1.."varioRangeControl:\n"          ; str2 = str2.."\n"
        str1 = str1.."range:\n"                     ; str2 = str2..string.format("%s\n", rangeText)
        str1 = str1.."source:\n"                    ; str2 = str2..string.format("%s\n", sourceText)
        str1 = str1.."maxForwardSpeed:\n"           ; str2 = str2..string.format("%.1fkm/h\n", forwardSpeed or 0)
        str1 = str1.."maxBackwardSpeed:\n"          ; str2 = str2..string.format("%.1fkm/h\n", backwardSpeed or 0)
        str1 = str1.."minForwardGearRatio:\n"       ; str2 = str2..string.format("%s\n", formatRatio(minForwardGearRatio))
        str1 = str1.."maxForwardGearRatio:\n"       ; str2 = str2..string.format("%s\n", formatRatio(maxForwardGearRatio))
        str1 = str1.."minBackwardGearRatio:\n"      ; str2 = str2..string.format("%s\n", formatRatio(minBackwardGearRatio))
        str1 = str1.."maxBackwardGearRatio:\n"      ; str2 = str2..string.format("%s\n", formatRatio(maxBackwardGearRatio))
        str1 = str1.."liveMotorMinForwardRatio:\n"  ; str2 = str2..string.format("%.3f\n", motor.minForwardGearRatio or 0)
        str1 = str1.."liveMotorMaxForwardRatio:\n"  ; str2 = str2..string.format("%.3f\n", motor.maxForwardGearRatio or 0)
        str1 = str1.."liveMotorMinBackwardRatio:\n" ; str2 = str2..string.format("%.3f\n", motor.minBackwardGearRatio or 0)
        str1 = str1.."liveMotorMaxBackwardRatio:\n" ; str2 = str2..string.format("%.3f\n", motor.maxBackwardGearRatio or 0)

        local textSize = getCorrectTextSize(0.018)

        -- position under / near the GIANTS transmission debug block
        local x = 0.25
        local y = 0.30

        setTextColor(1, 1, 0, 1)

        Utils.renderMultiColumnText(
            x, y,
            textSize,
            {str1, str2},
            0.008,
            {RenderText.ALIGN_RIGHT, RenderText.ALIGN_LEFT}
        )

        setTextColor(1, 1, 1, 1)
    end
end
