# FS25_varioRangeControl

This mod is in active development. This is not an official release build. Use at your own risk.

Real Fendt Vario tractors with the older *ML transmissions* use two operating ranges: **range I for field work and range II for transport**. This Farming Simulator 25 mod recreates that behaviour by allowing the driver to manually switch ranges. This mod requires a properly configured mod to function, XML description below.

Why have I made this? From real life experience driving Fendt Vario tractors with the old ML transmissions, I felt there was something missing in the game. Namely stopping by the edge of the field or before driving up the silage bunker to switch between **operating range I (field)** and **operating range II (road)**, which becomes second nature after a while. I wanted to implement this feature into the game without completely overhauling or redesigning the CVT system, so I made this.

By default the vehicle must be stopped to switch ranges (as this is how I drive a Vario IRL), but the maximum allowed speed for switching can be configured per vehicle in XML. The keybind (Default: **SHIFT+1**) is a toggle and can be configured in the controls menu like normal.

### Operating ranges

- **Range I (Field)** – intended for field work and heavy pulling
- **Range II (Road)** – intended for transport and higher driving speeds


## Features

- Manual Vario operating range selection (I / II)
- The currently selected range is indicated on the HUD
- The last range selected is always set, even after turning the ignition on or off, or saving and loading the game
- Range switching is only allowed below the configured speed limit (warning shown if exceeded)
- Configurable speed and ratio limits for operating range I in XML
- Dashboard integration

### Future ideas

- Different maximum allowed speed for switching ranges depending on if switching from I -> II or II -> I
- Require a minimum allowed temperature for switching ranges (IRL example: Fendt Vario 700 COM3 - min trans temp 10C)

## XML Configuration

In the mod vehicle XML file, add a `<varioRanges>` section inside the vehicle `<transmission>`.

### Full XML format
Range I defines custom speed limits and ratios. Range II uses the existing transmission configuration of the vehicle.

```xml
<transmission ...>
  <varioRanges defaultRange="2" shiftSpeedMax="2.5">
    <range1 maxForwardSpeed="36" maxBackwardSpeed="20" minForwardGearRatio="25.0" maxForwardGearRatio="350" minBackwardGearRatio="25.0" maxBackwardGearRatio="350"/>
  </varioRanges>
</transmission>
```

### Minimal configuration

Only the maximum speeds must be defined. All other attributes are optional.

```xml
<transmission ...>
  <varioRanges>
    <range1 maxForwardSpeed="36" maxBackwardSpeed="20"/>
  </varioRanges>
</transmission>
```

### Attributes

Defining gear ratios can be used to mimic IRL behaviour where engine RPM rises noticeably as the tractor approaches the maximum speed of operating range I. They are not required.

| Attribute | Description | Default |
|----------|-------------|--------|
| `defaultRange` | Range selected when entering the vehicle the first time | `2` |
| `shiftSpeedMax` | Maximum vehicle speed where range switching is allowed | `2.5` kph |
| `maxForwardSpeed` | Maximum forward speed in this range | Required |
| `maxBackwardSpeed` | Maximum reverse speed in this range | Required |
| `minForwardGearRatio` | Minimum forward gear ratio | From vehicle transmission |
| `maxForwardGearRatio` | Maximum forward gear ratio | From vehicle transmission |
| `minBackwardGearRatio` | Minimum reverse gear ratio | From vehicle transmission |
| `maxBackwardGearRatio` | Maximum reverse gear ratio | From vehicle transmission |

## Dashboard Integration

| Value Type | Description |
|-------------|-------------|
| `varioRangeControl.currentRange` | Numeric value of the active range (1 or 2) |
| `varioRangeControl.range1Active` | Boolean value that is true when Range I is active |
| `varioRangeControl.range2Active` | Boolean value that is true when Range II is active |

Example:

```xml
<dashboard displayType="VISIBILITY" valueType="varioRangeControl.range1Active" node="rangeIconI"/>

<dashboard displayType="VISIBILITY" valueType="varioRangeControl.range2Active" node="rangeIconII"/>
```


## Screenshot

<img width="3840" height="2160" alt="screenshot" src="https://github.com/user-attachments/assets/00c18211-80b0-4477-a95e-c80e81f8a258" />
