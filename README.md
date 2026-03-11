# FS25_varioRangeControl

This mod is in active development. This is not an official release build. Use at your own risk.

Vario Range Control is a mod that adds support for two speed ranges (I/II) to CVT transmissions for tractors in Farming Simulator 25. Requires vehicle XML preparation. Intended to be used with Fendt Vario tractors that have a I (field) / II (road) speed range control button in real life. By default you must stop in order to shift ranges (as this is how I drive a Vario IRL), but the max allowed speed for shifting can be configured per vehicle in xml. The keybind (Default: SHIFT+1) is a toggle and can be configured in the controls menu like normal.

Why have I made this? From real life experience driving Fendt Vario tractors with the old ML transmissions, I felt there was something missing in the game. Namely stopping by the edge of the field or before driving up the silage bunker to switch between the I/II ranges, which becomes second nature after a while.. I wanted to implement this feature into the game without completely overhauling or redesigning the CVT system, so I made this.

### XML format:
```xml
<transmission .. >
  <varioRanges defaultRange="2" shiftSpeedMax="2.5">
    <range1 maxForwardSpeed="36" maxBackwardSpeed="20" minForwardGearRatio="25.0" maxForwardGearRatio="350" minBackwardGearRatio="25.0" maxBackwardGearRatio="350" />
	<range2 maxForwardSpeed="53" maxBackwardSpeed="38" minForwardGearRatio="13" maxForwardGearRatio="300" minBackwardGearRatio="13" maxBackwardGearRatio="300" />
  </varioRanges>
</transmission>
```

### Example usage:
Not all values need to be defined.
  ```xml
  <motorConfiguration name="720 Vario" hp="203" price="0" consumerConfigurationIndex="1">
    <motor torqueScale="1.11" minRpm="650" maxRpm="1700" maxForwardSpeed="53" maxBackwardSpeed="33" brakeForce="8" lowBrakeForceScale="0.1" lowBrakeForceSpeedLimit="1" ptoMotorRpmRatio="3" dampingRateScale="1">
	  <torque normRpm="0.45" torque="0.9"/>
	  <torque normRpm="0.5" torque="0.97"/>
	  <torque normRpm="0.59" torque="1"/>
	  <torque normRpm="0.72" torque="1"/>
	  <torque normRpm="0.86" torque="0.88"/>
	  <torque normRpm="1" torque="0.72"/>
    </motor>
    <transmission minForwardGearRatio="10.3" maxForwardGearRatio="320" minBackwardGearRatio="16.7" maxBackwardGearRatio="320" name="$l10n_info_transmission_cvt">
      <varioRanges>
        <range1 maxForwardSpeed="28" maxBackwardSpeed="17" minForwardGearRatio="25" />
        <range2 maxForwardSpeed="50" maxBackwardSpeed="33" />
      </varioRanges>
    </transmission>
  </motorConfiguration>
```

If values are omitted, the following data applies:


Default range: 2 (II)

Max speed for shifting: 2.5 kph

Default speeds in range I (field): 0 - 36 kph forwards, 0 - 20 kph reverse

Default speeds in range II (road): 0 - 53 kph forwards, 0 - 38 kph reverse

Default gear ratios: As defined in vehicle transmission


### Screenshot

<img width="3840" height="2160" alt="screenshot" src="https://github.com/user-attachments/assets/00c18211-80b0-4477-a95e-c80e81f8a258" />
