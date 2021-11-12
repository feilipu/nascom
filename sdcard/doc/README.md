# Documentation

* nascom_sdcard.txt -- a description of the commands supported by the Arduino software
* protocol.pdf      -- shows the operation of the protocol on the nascom - Arduino interface
* pio_connection.pdf -- shows the connections from the Arduino to the NASCOM
* nascom_sdcard_user_guide.pdf -- user guide, assembly instructions etc.
* nascom_sdcard_user_guide.odt -- as above, but open office format
* nascom_sd_REVA_schematic.pdf -- schematic of REV A PCB
* nascom_sd_pcb_render_reva.jpg -- 3D render of assembled REV A PCB
* nascom_sd_REVA_eco.pdf -- schematic marked up with ECO (4 cuts, 4 wires)
* nascom_sd_REVB_schematic.pdf -- schematic of REV B PCB (also applies to REV C PCB)
* nascom_sd_pcb_render_revb.jpg -- 3D render of assembled REV B PCB


# Internals

* [Parallel interface command set](parallel_interface_command_set.md) aka "NASdsk command set"
* [Parallel interface protocol](parallel_interface_protocol.md)
* [Parallel interface programming examples](parallel_interface_programming.md)
* [Console interface command set](console_interface_command_set.md) aka "NASconsole command set"
* [Serial interface command set](serial_interface_command_set.md) aka "NAScas command set"
* [Profile record format](profile_record_format.md)
* [Boot loader](boot_loader.md) - the NASdsk PBOOT command, the [diskboot](../host_programs/dskboot.asm) program and the [SDBOOT0](../host_programs/SDBOOT0.asm) disk image


Elsewhere:

* The Z80 assembly listings in the host_programs/ directory are commented
examples of how to "talk" to the Arduino board.

* The header of nascom_arduino.ino has a complete description of the hardware
connections.
