General overview notes on main features of SPI OLED_S7789 screen with pins. Updates will be written as I sort out my messy handwritten notes XP

## ST7789 OLED Display Notes
#### Overview
- Pixel Dimensions: 135x240
- Uses SPI for communicate from FPGA to PMOD (4 wires)
- Voltage Power of 3,3 V
- 6/16/18 RGB Interface(VSYNC, HSYNC, DOTCLK, ENABLE, DB[17:0])
- Serial Peripheral Interface(SPI Interface)
#### PMOD Pinout
- CS: chip select, bring active LOW
- SDA (MOSI): to connect to the SPI MOSI of the FPGA
- SCL: serial clock; to connect to SPI SCL (clock)
- DC: data/command control
	- if high, inputs are interpreted as a command and will be decoded and written to corresponding command register
	- if low, data is written to graphic display data RAM
- RES: Reset for controller. It’s usually high, bring to low to reset
- VCC: Power supply of 3.3V
- BLK: retroillumination controller. If disconnected, it’s always active

![[Pasted image 20250802130742.png]]
#### PMOD Schematics
