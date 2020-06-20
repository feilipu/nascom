// NAScas                             -*- c -*-
// https://github.com/nealcrook/nascom
//
// ARDUINO Uno/Nano (ATMEGA328) connected to NASCOM 2 as mass-storage device
//
// Connect through UART for the purpose of providing a "virtual cassette
// interface" in which the NAS-SYS R and W commands (and the equivalent from
// within BASIC and other applications) are directed to files on SDcard.
//
// This is "transparent" to the NASCOM but a utility program "serboot" is
// executed on the NASCOM to control what file is used for the read/write.
// serboot is tiny (~103 bytes) and is stored in the Arduino FLASH and
// automatically bootstrap-loaded through the serial port when the Arduino
// is reset.
//
// ** This software relies on the SdFat implementation. Download it
// ** into your Arduino/libraries area and then edit SdFat/src/SdFatConfig.h
// ** to change "#define USE_LONG_FILE_NAMES" from 1 to 0.
//
// ** By default the Nano ships with a larger boot loader than the Uno and
// ** this code may not fit. Best solution is to reprogram the Nano with
// ** the Uno bootloader code, then treat it as an Uno forever after.
// ** Alternative solution is to comment out one of the ROM images.
//
////////////////////////////////////////////////////////////////////////////////
// WIRING (assumes Arduino Uno/Nano)
//
// ANA6/ANA7 ARE INPUT ONLY *AND* YOU CANNOT USE
// digitalRead ON THEM - ONLY analogRead.
//
//
// 1/ connection to uSDcard adaptor
//
// uSD                     ARDUINO
// -------------------------------
// 1  GND                  GND
// 2  VCC                  5V
// 3  MISO                 DIG12
// 4  MOSI                 DIG11
// 5  SCK                  DIG13  (also ARDUINO's on-board LED)
// 6  CS_N                 DIG10
//
// 2/ connection to NASCOM 2 serial interface PL2 via 16-way ribbon
//
// Name   Direction   ARDUINO   NASCOM 2
// ---------------------------------------------------------------
// NAS_DRIVE  IN       ANA6     pin 1       DRIVE OUT
// NAS_TXD    IN       DIG7     pin 12      20mA OUT
// RXD_NAS    OUT      DIG8     pin 9       20mA IN
// SERCLK_NAS OUT      DIG9     pin 4 & 5   EXT TX CLK, EXT RX CLK
// GND                          pin 11 & 15 GND
// 5V                           pin 2       5V   (NOTE)
//
// - Set all LSW2 switches to UP/ON, Set LSW1/5 to UP (1 stop bit)
// - Fit a 1OOK resistor from DIG 7/ pin 12 to 5V
// - Fit a 33R series resistor on the DIG9 connection, at the Arduino end,
//   to reduce overshoot on the bit clock to the NASCOM.
//
// 3/ connection to LED (optional)
//
// Name   Direction   ARDUINO   Notes
// -----------------------------------
// DRIVE  OUT         ANA2      To LED. Copies state of DRIVE
//
// NOTE: Power
//
// - If you have the Arduino Uno connected to a computer on its USB port
// it will also get power from there: do NOT also connect to power on the
// NASCOM.
//
// - To power an Arduino Uno directly from 5V on the NASCOM you need to add
// a wire down-stream of the regulator. I connected to the 2-pin device that
// looks like a big resistor but is actually a fuse. Refer to the Arduino Uno
// schematics for details.
//
// - If you use an Arduino Nano, things are more straightforward as the
// Nano has a 5V input and a regulator arrangement that allows the Nano to
// draw power from the USB or the NASCOM. Refer to the schematics for details.
// I have NOT tried powering both at the same time.
//
////////////////////////////////////////////////////////////////////////////////
// PROTOCOL FOR SERIAL INTERFACE
//
// When running serboot (serboot.asm)
// E 0C80
// NAScas>
//
// NAS-SYS always polls the serial interface as well as the keyboard, so the
// serial interface can deliver input at any time. By sending R<return>
// followed by the CAS-encoded serboot code, followed by E0C80 <return>
// the NASCOM will load and execute the serboot binary, which provides a
// command-line interface.
//
// Commands from Host (serboot) are between 1 and 39 characters
// followed/terminated in a NUL (0x00). TODO check that's true ie that a 40
// char buffer is enough.
// Document this detail in serboot.asm code.
//
// Responses to the Host (by this program) are:
//
// RSDONE        (0x00  - command complete, no other respons.
// RSMOVE hh ll  (0x55) - relocate serboot to specified address
// RSMSG         (0xff) - ASCII text follows. Print until NUL.
//
////////////////////////////////////////////////////////////////////////////////
// FILESYSTEMS AND FORMATS
//
// There are 3 file-systems:
//
// - Vdisk  - a read-only filesystem implemented in a binary blob that is
//            stored on the SDcard. The binary blob is a PolyDos disk image;
//            the format is documented in the PolyDos System Programmers Guide.
//            File names use an 8.2 format: 1-8 characters before the dot,
//            exactly 2 characters after the dot.
// - Flash  - a read-only filesystem implemented in the Arduino Flash memory.
//            File names use PolyDos format (see above)
// - SDcard - a read/write filesystem implemented on the SD card. File names
//            use MSDOS 8.3 format: 1-8 characters before the dot, 1-3
//            characters after the dot.
//
// These file formats are supported:
//
// - CAS format - files that are stored as a byte stream that directly
//                corresponds to the byte stream generated by the NAS-SYS
//                R, W, G commands (and NASCOM BASIC CSAVE/CLOAD, which
//                include a small "filename" header). These files require
//                no conversion. When read and write commands are issued
//                from the NASCOM. These files are used directly.
// - Binary format - files that represent a memory image. Binary files
//                require additional meta-data (eg, load address) to be
//                useful. When read and write commands are issued
//                from the NASCOM. These files are converted to/from CAS
//                format on-the-fly.
// - ASCII format - Human-readable text files. These files are not sent
//                in response to read and write commands. Instead, they
//                are the equivalent of typing in the text by hand
//                (for example, if you have a BASIC program in ASCII
//                format you cannot directly load it into NASCOM BASIC
//                because programs are stored in a tokenised format.
//                This provides an automated way of "typing it in").
//
// These file operations are supported for the Vdisk file-system:
//
// - Directory
// - Read binary file (the file-system stores the load address and
//   exection address)
//
// These file operations are supported for the Flash filesystem:
//
// - Directory
// - Read binary file (the file-system stores the load address and
//   exection address)
//
// These file operations are supported for the SDcard filesystem:
//
// - Directory
// - Mount virtual file-system
// - Write CAS file
// - Read CAS file
// - Read ASCII (text) file
// - Erase file
// - Change disk
//
// Refer to the built-in help (which you can see in file messages.h)
//
////////////////////////////////////////////////////////////////////////////////
// SD CARD FORMAT
//
// The SD card uses MSDOS FAT format, with 8.3 filenames. This means that all
// names must be in UPPER CASE. Store files either in the root directory or in
// a directory named NASCOM.
//
// At reset or when the NEW command is issued, a check is made for the presence
// of an SD card and, if one is found, the presence of a NASCOM directory.
//
// If a NASCOM directory is found, all SD card operations use that directory.
// If not, all SD card operations use the root directory.
//
////////////////////////////////////////////////////////////////////////////////
// RESOURCES
//
// Detailed documentation:
// https://github.com/nealcrook/nascom/blob/master/sdcard/nascom_sdcard/doc/nascom_sdcard_user_guide.pdf
//
// PolyDos manual set, including PolyDos System Programmers Guide:
// https://github.com/nealcrook/nascom/tree/master/PolyDos/doc
//
// CAS<->bin converter and a tool for manipulating PolyDos disk images:
// https://github.com/nealcrook/nascom/tree/master/converters
//
// NASCOM software in PolyDos disk images, with an index:
// https://github.com/nealcrook/nascom/tree/master/PolyDos/lib
//
////////////////////////////////////////////////////////////////////////////////
// GOTCHAS/BUGS
//
////////////////////////////////////////////////////////////////////////////////
// COMMANDS
//
// Refer to the comments or to the help text in messages.h
//
////////////////////////////////////////////////////////////////////////////////
//
// Missing commands..
//
// It would be possible to add these, but probably not useful. Just in case,
// here are thoughts on how to do it..
//
// The current command-set does not support writing in binary format and so
// there is never a need to translate write data from CAS to binary. My
// utilities elsewhere in the github repository have code for doing that
// translation - but only the Vdisk format has a way to store the associated
// meta-data.
//
// Also, with the current command-set, there is no need to determine what
// format a file is in: it is either implicit or explict from the command.
// To add support for (eg) saving binary files to SDcard, there would need
// to be a rule to decide whether a file saved to SDcard was to be in binary
// or CAS format. This could be done by adding additional commands or by
// guessing from the file extension.
//
// To read a binary file from SD card the code to perform the translation
// to CAS format is already in place, but the meta-data is missing. The
// command could be changed to allow optional load and execution address
// to be specified. The existing number parser could be used to check for
// these; it needs no modification for this task.

// TODO
// "erase" could use the command-line buffer instead of parsing into a new buffer.
// currently 31880 bytes rom 1112 bytes ram
//           31404           1054           after change to FatFile etc.
//
// Make it work with serial comms faster than 2400bd. At one point I thought
// the "softserial" library was the limiting factor but I read that it should
// work OK at up to 9600bd with a 16MHz processor, and I tried using the
// hardware UART (with a hardware inverter in the data signals) but it gave
// no improvement. Full discussion here:
// https://github.com/nealcrook/nascom/blob/master/sdcard/NAScas/NASCOM_UART_performance.pdf
//
////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Configuration

// Define for use on NASCOM1, comment out for use on NASCOM2
// If defined:
// - baud rate reduced from 1200 to 600
// - serial comms is non-inverted.
//#define NASCOM1

// Define which ROMS to include in the Flash filesystem; you may need
// to omit some to make the code fit (especially if you enable CONSOLE)
//#define ROM_INVADERS
//#define ROM_PIRANHA
#define ROM_LOLLIPOP
#define ROM_ZEAP2
#define ROM_NASDIS

// Enable support for a console interface from a PC across the USB link
// - for details, search for "void cmd_console" below
#define CONSOLE

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


// If defined:
// - uses SoftwareSerial to communicate, on pins 7,8. Maximum baud rate is
//   4800 baud, inversion is done in software, hardware UART is used for debug
//   messages across USB via Arduino GUI console
// If not defined:
// - uses hardware UART to communicate, on pins 1, 2. Maximum baud rate is
//   ??? baud, need external inverter between Arduino and NASCOM (and need
//   to disconnect it before reprogramming the Arduino). No debug messages.
#define SOFTSERIAL

// If defined, builds a code variant that helps with hardware debug
//#define HWDEBUG


// Arduio generates 16x clock for the NASCOM UART.
//      600 baud need divide by 834
// For 1200 baud need divide by 417 (19208Hz) <-- default on NASCOM 2
//     2400                     208  <-- seems to work OK
//     4800                     104  <-- seems to work OK on small blocks but not reliable
//     9600                      52  <-- does not work; bad data at NASCOM
//    19200                      26
//
// The value of BAUD_RATE and BAUD_DIVISOR must always be consistent!
#ifdef SOFTSERIAL
#ifdef NASCOM1
// NASCOM1 defaults
#define BAUD_RATE (600)
#define BAUD_DIVISOR (834)
#define COUNT_FOR_RD (50000)
#define SOFTSERIAL_INVERT (0)
#define DRIVE_INVERT (0)
#else
// NASCOM2 defaults
#define BAUD_RATE (2400)
#define BAUD_DIVISOR (208)
#define COUNT_FOR_RD (15000)
#define SOFTSERIAL_INVERT (1)
#define DRIVE_INVERT (1)
#endif
#define NASSERIAL mySerial
#define DEBSERIAL Serial
#define DELAY (0)
#else
// EXPERIMENTAL - DO NOT USE
#define BAUD_RATE (2400)
#define BAUD_DIVISOR (208)
#define NASSERIAL Serial
#define DEBSERIAL mySerial
#endif


// Pin assignments (SERIAL)
#define PIN_DRV A6
#define PIN_CLK 9
#define PIN_NTXD 7
#define PIN_NRXD 8
#define PIN_LED A2

// *not* the standard Arduino library (which has some bugs and performance
// problems). Download from https://github.com/greiman/SdFat
#define SPI_SPEED SD_SCK_MHZ(50)
#include <SdFat.h>

#include <SoftwareSerial.h>
#include <EEPROM.h>

// Virtual disks use the PolyDos file structure
#define POLYDOS_BYTES_PER_SECTOR (256)

// The format of a 20-byte PolyDos directory entry.
typedef struct DIRENT {
    char fnam_fext[10]; // 8 char filename, 2 char extension.
                        // Blanks in unused positions, no "."
    uint8_t fsfl;       // system flags
    uint8_t fufl;       // user flags
    unsigned int fsec;  // start sector address
    unsigned int flen;  // length of data in 256-byte sectors
    unsigned int flda;  // load address on target
    unsigned int fexa;  // entry/execution address on target
} DIRENT;

// An 18-byte cut-down PolyDos directory entry, used for the Flash filesystem.
// - FSFL and FUSL are absent.
// - FSEC (start sector) is replaced by FPTR (pointer to the byte stream)
// - FLEN (number of sectors) is replaced by FLEN (number of bytes)
typedef struct FDIRENT {
    const char         fnam_fext[10]; // 8 char filename, 2 char extension.
                                      // Blanks in unused positions, no "."
    const uint8_t *    fptr;          // point to data bytestream
    const unsigned int flen;          // length of data in bytes
    const unsigned int flda;          // load address on target
    const unsigned int fexa;          // entry/execution address on target
} FDIRENT;


// Sometimes it's convenient to access a directory entry as a byte
// stream, so overlay it with a char array.
typedef union UDIRENT {
    struct DIRENT f;
    char b[20];
} UDIRENT;


// Prototypes for stuff in this file
void cmd_cass(void);
void cmd_cass_rd(void);
void cmd_cass_wr(void);
void open_sdcard(void);

// Stuff provided by parser.ino
extern char to_upper(char c);
extern int legal_char(char c);
extern int parse_leading(char **buf);
extern int parse_num(char **buf, unsigned long *result, int base);
extern int parse_ai(char **buf);
extern int parse_fname_msdos(char **buf, char * dest);
extern int parse_fname_polydos(char **buf, char * dest);


// Maintained by open_sdcard()
FatFile *working_dir;

// Only ever have 1 file open at a time
// FatFile takes ~12 bytes less data but only File supports size() needed for console code.
File handle;


// Boot ROM and some applications/games - stored in FLASH to save resources.
#include "roms.h"
// Message strings - stored in FLASH to save resources.
#include "messages.h"



// 16-bit flags/state.
// FM_ -- mask
// FS_ -- shift for LS bit of the field

// 0 = None/Not defined
// 1 = FLASH
// 2 = SD
// 3 = VDISK IMAGE
#define FS_RD_SRC   (14)
#define FS_WR_SRC   (12)
#define FM_RD_SRC   (3 << FS_RD_SRC)
#define FM_WR_SRC   (3 << FS_WR_SRC)

// RESERVED/Unused. At one point I thought I would read a file
// in one format at serve it to the NASCOM in another. For
// example, store binary files on SDcard and serve them to the
// NASCOM as CAS. In the end I chose not do to that. Instead
// all the conversions are implicit eg binary file from Virtual
// disk served to the NASCOM as CAS.
// 0 = store binary file, convert to/from cas
// 1 = store file literally
// 3, 4 reserved
#define FS_RD_CONV (10)
#define FS_WR_CONV (8)
#define FM_RD_CONV (3 << FS_RD_CONV)
#define FM_WR_CONV (3 << FS_WR_CONV)

#define FS_RD_AI   (7)
#define FS_WR_AI   (6)
#define FM_RD_AI   (1 << FS_RD_AI)
#define FM_WR_AI   (1 << FS_WR_AI)

// TODO eg for SPEED
#define FS_SPARE5  (5)
#define FS_SPARE4  (4)
#define FM_SPARE5  (1 << FS_SPARE5)
#define FM_SPARE4  (1 << FS_SPARE4)

#define FS_SD_FOUND (3)
#define FM_SD_FOUND (1 << FS_SD_FOUND)
// bit 2 is SPARE
#define FS_VDISK_MOUNT (1)
#define FM_VDISK_MOUNT (1 << FS_VDISK_MOUNT)
// 0 do not auto-go, 1 automatically execute program if possible
#define FS_AUTO_GO   (0)
#define FM_AUTO_GO   (1 << FS_AUTO_GO)

// Startup defaults: read from Flash and auto-go. This works because
// (1) flash is always present and (2) 0 is an illegal destination for writes.
int cas_flags = (1 << FS_RD_SRC) | FM_AUTO_GO;


// Space for storing file-names: each is initialised as a
// a null-terminated string that's the maximum size for an
// MSDOS (8.3) filename.
char cas_rd_name[]    = "NAS-RD00.CAS";
char cas_wr_name[]    = "NAS-WR00.CAS";
char cas_vdisk_name[] = "NAS-XX00.DSK";

// Index of directory entry for next Flash/Vdisk operation. At reset, the
// boot device is Flash and 0 means the first file: SERBOOT.GO
int dirindex = 0;

// Used by screen_page_quit() to track lines output to the NASCOM during
// directory listings
int lines;

// state for reading from Flash file-system
int index;

// state for loop()
unsigned long drive_on = 0;

// state for PAUSE/NULLS commands
// (need to issue X0 before starting BASIC else lines cannot exceed 48 char.
// Later use N to restore normal operation)
unsigned int pause_delay = 10; // in seconds
unsigned int nulls_delay = 100; // in milliseconds

// arduino clock is 16MHz
SoftwareSerial mySerial(PIN_NTXD, PIN_NRXD, SOFTSERIAL_INVERT); // RX, TX, control INVERSE_LOGIC on pin

SdFat SD;


// Run-time check of available RAM
// http://jheyman.github.io/blog/pages/ArduinoTipsAndTricks/
void pr_freeRAM(void) {
  extern int __heap_start, *__brkval;
  int v;
  DEBSERIAL.print(F("Bytes of free RAM = "));
  DEBSERIAL.println((int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval));
}

// get value of DRIVE. My current implementation maps this to A6
// which can only be read using analogRead.
// Echo its value on the LED (labelled "protocol error"..)
int rd_drive(void) {
    if (analogRead(PIN_DRV) > 500) {
        digitalWrite(PIN_LED, 1^DRIVE_INVERT);
        return 0^DRIVE_INVERT;
    }
    else {
        digitalWrite(PIN_LED, 0^DRIVE_INVERT);
        return 1^DRIVE_INVERT;
    }
}


void setup()   {
    pinMode(PIN_LED, OUTPUT);
    pinMode(PIN_DRV, INPUT);

    // Generate output clock that will be used as 16x clock for the NASCOM UART.
    // The output pin options are shown in the I/O Multiplexing table of the
    // data sheet ..need to select an Output Compare unit from one of the timers.
    // OC2B PD[3] = DIG3
    // OC2A PB[3] = DIG11 -- used for SDcard
    // OC1B PB[2] = DIG10 -- used for SDcard
    // OC1A PB[1] = DIG9  -- best candidate; already assigned for output clock.
    //
    // => use Timer1

    // Atmega clock is 16MHz. UART needs 16x clock. Timeout causes pin to toggle
    // and need 2 toggles for 1Hz. Therefore, for a baud rate B need a divide
    // value of D = 16E6/(16 * 2 * B). Frequency should then be 16E6/D

    PRR  &= ~(1 << PRTIM1);              // Ensure Timer1 is enabled

    TCCR1B |= (1 << CS10);               // Set Timer1 clock to "no prescaling"
    TCCR1B &= ~((1 << CS11) | (1 << CS12));

    TCCR1B &= ~(1 << WGM13);             // Set Timer1 CTC mode=4
    TCCR1B |=  (1 << WGM12);
    TCCR1A &= ~(1 << WGM11);
    TCCR1A &= ~(1 << WGM10);
    //
    TCCR1A |= (1 <<  COM1A0);            // Set "toggle on compare match"
    TCCR1A &= ~(1 << COM1A1);
    // For a divider of N, OCR1 is set to N-1.
    OCR1A = BAUD_DIVISOR -1;             // Set the compare value to toggle OC1A
    // bits in TCCR select OC unit as source of output, but still need to set the pin to the
    // output direction so that the clock is available at the output
    pinMode(PIN_CLK, OUTPUT);

    // should not need this?
    pinMode(PIN_NTXD, INPUT_PULLUP);

    DEBSERIAL.begin(115200);  // for Debug
    NASSERIAL.begin(BAUD_RATE);


#ifdef HWDEBUG
    // TEST1: Loop printing to the NASCOM. Since the NASCOM always monitors
    // for incoming characters, it should be echoed to the screen, verifying
    // the NAScas -> NASCOM data path and serial bit clock.
    // The pattern repeats every 48 characters and so, if there is no
    // "staircasing" of the output on the screen this suggests that data
    // is being transferred without corruption
    for (int j=0; j<50; j++) {
        // start with a space so NAS-SYS will ignore it
        NASSERIAL.write(' ');
        for (int i=65; i<65+47; i++) {
            NASSERIAL.write(i);
        }
    }
    NASSERIAL.println();
    NASSERIAL.println("X0"); // put NAS-SYS into echo mode
    NASSERIAL.println(" Type some characters");
    for (int i=0; i<10; i++) {
        while (! NASSERIAL.available()) {
        }
        NASSERIAL.print(" Read ");
        NASSERIAL.println(NASSERIAL.read());
    }
    NASSERIAL.println("Thanks, bye.");
#endif

    open_sdcard();

    // Bootstrap the CLI on the host. Sending R causes the NASCOM to start a
    // READ which will cause loop() to call cmd_cass_rd which will load file
    // from Flash using the directory index given by 'dirindex' and, provided
    // the auto-execute flag is set, it will go ahead and execute it.
    NASSERIAL.println(F("R"));
    DEBSERIAL.println((__FlashStringHelper*)msg_info);
}


// This routine is invoked repeatedly by the arduino "scheduler" and so there is
// no loop inside here; do one pass of polling and drop through the bottom. If
// anything needs doing it will be invoked from here. Any state must be global.
void loop() {
    // - if a serial char received and drive light is OFF, it's a command
    //   from the CLI running on the NASCOM; get it and process it to completion.
    //
    // - if a serial char received and drive light is ON, it's the first
    //   byte of a WRITE. Grab the data and save it to the specified place.
    //
    // - if drive light is ON and has been on for a while (longer than it
    //   takes for write data to arrive and longer than it would be on if
    //   it was being toggled in order to play a tune(!!)), it's a READ;
    //   supply the data from the specified place.

    if (rd_drive()) {
        drive_on = 0;
    }
    else {
        drive_on++;
    }

    if (NASSERIAL.available()) {
        if (drive_on == 0) {
            // Receive and process a command
            DEBSERIAL.println(F("cmd_cas"));
            cmd_cass();
        }
        else {
            // File save
            DEBSERIAL.print(F("wr. Count= "));
            DEBSERIAL.println(drive_on);
            drive_on = 0;
            // Write
            cmd_cass_wr();
        }
    }
    else if (drive_on > COUNT_FOR_RD) {
        // File Load
        DEBSERIAL.println(F("rd."));
        drive_on = 0;
        cmd_cass_rd();
    }
#ifdef CONSOLE
    else if (DEBSERIAL.available()) {
        cmd_console();
    }
#endif
}


// After each line of output for the directory listing (the only thing that
// can extend beyond 1 screen) this gets called. It returns TRUE if the
// operation should be aborted, FALSE if it should continue.
// It tracks output lines. When the bottom of the screen is reached it
// pauses the output and gets a keypress from the NASCOM keyboard, which
// determines whether to continue or not.
char screen_page_quit()  {
    char key;

    lines = (lines + 1) % 14; // GLOBAL

    if (lines == 0) {
        // print message, cursor home (to start of line) then pause
        NASSERIAL.print(F("Press [SPACE] to continue\x17\x01"));
        // wait for keypress from NASCOM
        while (!NASSERIAL.available()) {
        }
        key = NASSERIAL.read();

        // clear the line then send cursor home
        for (int i = 0; i< 45; i++) {
            NASSERIAL.write(' ');
        }
        NASSERIAL.write((byte)0x17);

        // what key was pressed?
        if (key != ' ') {
            NASSERIAL.write((byte)0x00); // end of message
            return 1; // abort
        }
    }
    return 0; // continue
}


// Print a message to the Host through the serial port. The message is stored
// in Flash. Flags determine what prefix/suffix bytes are sent (refer to the
// protocol description).
void pr_msg(const char *msg, char flags) {
    if (flags & F_MSG_RESPONSE) {
        NASSERIAL.write((byte)0xff); // tell host: a message is coming
    }

    // use this prefix when reporting an error outside the command loop
    if (flags & F_MSG_NASCAS) {
        NASSERIAL.print(F(" NAScas "));
    }

    // use this prefix rather than repeating this common string in Flash storage
    if (flags & F_MSG_ERROR) {
        NASSERIAL.print(F("Error - "));
    }

    while ((pgm_read_byte(msg) != 0)) {
        NASSERIAL.write(pgm_read_byte(msg++));
    }

    if (flags & F_MSG_CR) {
        NASSERIAL.println(); // TODO maybe do this explicitly. What does NASCOM need? CR LF or both? this does \r\n
    }

    if (flags & F_MSG_NULLTERM) {
        NASSERIAL.write((byte)0x00); // tell host: the message is complete
    }
}


// print as 4-digit hex with optional leading 0x and optional trailing crlf
// eg: 0x1234
void pr_hex4(unsigned int val, int leading_0x, int trailing_crlf) {
    if (leading_0x) {
        NASSERIAL.write("0x");
    }
    for (int i=12; i>=0; i=i-4) {
        char c = 0xf & (val>>i);

        if (c>9) {
            c=c + 'A' - 10;
        }
        else {
            c=c + '0';
        }
        NASSERIAL.write((byte)c);
    }
    if (trailing_crlf) {
        NASSERIAL.write("\x0d\x0a");
    }
}


// Used by iterator. Print a directory entry, d.
// argument 'dummy' is unused but needed so that all functions called by
// the iterator have the same prototype.
// Return: 0 to continue, 1 to abort the listing
int pr_dirent(UDIRENT *d, char *dummy) {
    // Print filename, formatting it by removing spaces, adding a "."
    // and space-padding to a 13-character field
    int len=12;
    for (int i=0; i<10; i++) {
        if (i==8) {
            NASSERIAL.print(".");
        }
        if (d->f.fnam_fext[i] != ' ') {
            len--;
            NASSERIAL.print(d->f.fnam_fext[i]);
        }
    }
    while (len>0) {
        NASSERIAL.print(" ");
        len--;
    }

    NASSERIAL.print(F("Size="));
    pr_hex4((unsigned int)d->f.flen, 1, 0);
    NASSERIAL.print(F(" Load="));
    pr_hex4((unsigned int)d->f.flda, 1, 0);
    NASSERIAL.print(F(" Exe="));
    pr_hex4((unsigned int)d->f.fexa, 1, 1);
    return screen_page_quit(); // Pager can continue/abort the interator
}


// Used by iterator. Given a directory entry, d and a string,
// name, look for string match between the 10 characters of
// name and the file name within d.
// Return: 0 if no match (to make the iterator move on)
//         1 if match (to make the iterator terminate)
int find_dirent(UDIRENT *d, char *name) {
    for (int i=0; i<10; i++) {
        if (d->f.fnam_fext[i] != name[i]) {
            return 0; // Force iterator to continue
        }
    }
    return 1; // Force iterator to abort
}


// Iterator. Calls fn for each flash directory entry. If fn returns 1,
// the iterator aborts, otherwise the iterator continues to completion.
// Return: -1 the iterator ran to completion
//         >=0 the iterator aborted. The return value is the iteration number
//         which is the directory index of the entry that aborted.
int foreach_flash_dir(int (*fn)(UDIRENT *d, char * buf2), char * fname) {
    for (unsigned int i=0; i<sizeof(romdir)/sizeof(struct DIRENT); i++) {
        // read the 18-byte FDIRENT into a 20-byte DIRENT by padding
        // in the middle so that all the fields we care about line up.
        UDIRENT dirent;

        int base = (int) &romdir[i].fnam_fext;
        for (int j=0; j<20; j++) {
            if ((j==10) | (j==11)) {
                // the flag fields don't exist in the FDIRENT
                continue;
            }
            dirent.b[j] = pgm_read_byte(base++);
        }
        // Now it looks like a DIRENT so we can use common routines
        // for both
        if ( fn(&dirent, fname) ) {
            return i;
        }
    }
    return -1; // Iterator ran to completion
}


// Iterator. Calls fn for each valid (non-deleted) vdisk directory entry.
// If fn returns 1, the iterator aborts, otherwise the iterator continues
// to completion.
// Return: -1 the iterator ran to completion
//         >=0 the iterator aborted. The return value is the iteration number
//         which is the directory index of the entry that aborted.
int foreach_vdisk_dir(int (*fn)(UDIRENT *d, char * buf2), char * fname) {
    if ( (working_dir->exists(cas_vdisk_name)) && (handle.open(cas_vdisk_name, FILE_READ)) ) {
        UDIRENT dirent;

        pr_freeRAM();

        // Format of first 4 sectors (1024 bytes) of PolyDos disk image:
        // 20 bytes - disk volume name
        // 2 bytes - next free sector (linear block addressing)
        // 2 bytes - next free file control block (FCB) address
        // 1000 bytes - 50, 20-byte FCB entries
        // Instead of FCB, this code uses the term 'directory entry' or
        // dirent.
        handle.read(dirent.b, 20); // read and discard disk volume name
        handle.read(dirent.b, 4);  // read next free sector, next free FCB addr

        // In PolyDos this structure is stored in RAM at 0xc418 and the
        // "next free FCB" address is relative to that, so rebase to 0
        // then convert to number of dirents at 20 bytes per entry.
        // Finally, this was the address of the first free entry and
        // so step back by 1 to get to the last used entry.
        unsigned int last = ((dirent.b[2] & 0xff) | (dirent.b[3] << 8)) - 0xc418;
        last = (last/sizeof(struct DIRENT)) - 1;

        for (int i=0; i<=last; i++) {
            handle.read(dirent.b, sizeof(struct DIRENT));

            if (dirent.f.fsfl & 2) {
                // system flags "deleted" bit is set so skip this entry
                continue;
            }

            // convert the size from sectors to bytes
            dirent.f.flen *= POLYDOS_BYTES_PER_SECTOR;

            // invoke the callback
            if ( fn(&dirent, fname) ) {
                handle.close();
                return i;
            }
        }
        handle.close();
    }
    else {
        pr_msg(msg_err_vdisk_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
    }
    return -1; // Iterator ran to completion or aborted on error
}


// Check for SDcard and (if present) move to the NASCOM directory.
// Update cas_flags accordingly. Used at startup and after NEw command.
void open_sdcard(void) {
    cas_flags &= ~(FM_SD_FOUND | FM_VDISK_MOUNT);
    if (SD.begin(10, SPI_SPEED)) {
        cas_flags |= FM_SD_FOUND;
        // move to NASCOM directory, if it exists.
        SD.chdir("NASCOM", 1);
        working_dir = SD.vwd();

        // the very first write after initialising a card takes significantly
        // longer than other writes, and it can cause the first blocks of write
        // data to get lost (and you cannot tell until you go to read it back).
        // Hacky solution is to do a dummy file write here..
        handle.open("NASCAS.TMP", FILE_WRITE | O_TRUNC);
        handle.write('X');
        handle.close();
    }

    DEBSERIAL.print(F("flags: 0x"));
    DEBSERIAL.println(cas_flags, HEX);
}


// print directory of files on SDcard, in current directory (which will either
// be root or the directory named NASCOM). Originally, did this using
// "SD.ls(&NASSERIAL, LS_SIZE)" but this hand-cranked version has the advantage
// that it can use the pager at the NASCOM end.
void dir_sdcard(void) {
    char txtbuf[8+1+3+1]; // 8.3 name with terminating 0
    char * txt = txtbuf;

    NASSERIAL.write((byte)0xff); // tell host: a message is coming

    working_dir->rewind();
    while (handle.openNext(working_dir, O_RDONLY)) {
        int len;
        handle.getSFN(txt);
        len = 15 - NASSERIAL.write(txt);

        if (handle.isDir()) {
            NASSERIAL.write('/');
        }
        else {
            while (len > 0) {
                NASSERIAL.write(' ');
                len--;
            }

            // Print file size in bytes. Max file size is 2gb ie 10 digits
            int pad=0;
            long i=1000000000;
            long n = handle.fileSize();
            long dig;

            while (i > 0) {
                dig = n/i; // integer division with truncation
                n = n % i; // remainder
                if ((dig > 0) | (pad==1) | (i==1)) {
                    pad = 1;
                    NASSERIAL.write('0'+dig);
                }
                else {
                    NASSERIAL.write(' ');
                }
                i = i/10;
            }
            NASSERIAL.write(" bytes");
        }
        NASSERIAL.write("\x0d\x0a");
        handle.close();

        if (screen_page_quit()) {
            // in this case, response "done" has already been sent but
            // the additional NUL will just be gobbled up and thrown away
            break;
        }
    }
    // Send response "done"
    NASSERIAL.write((byte)0x00);
}


// Come here when DRIVE is off and there is a serial character available. Infer
// that a null-terminated string is going to be delivered. Receive the string
// into a buffer and process it to completion -- for example, by setting up
// state that will be used subsequently.
void cmd_cass(void) {
    char buf[40]; // TODO I think the maximum incoming line is 40 + NUL. May need to make this 1 byte larger. Test.
    char * pbuf = &buf[0];
    char erase_name[13]; // 8 + 1 + 3 + 1 bytes for null-terminated FAT file name
    int index = 0;
    int cmd = 0;
    unsigned long tmp_long;

    // Receive a null-terminated string from the Host into buf[]
    while (1) {
        if (NASSERIAL.available()) {
            buf[index] = NASSERIAL.read();
            if (buf[index] == 0) {
                break;
            }
            else {
                index++;
            }
        }
    }
    //DEBSERIAL.print(F("Rx cmd line of "));
    //DEBSERIAL.print(index);
    //DEBSERIAL.println(F(" char"));

    lines = 0; // Reset in case the pager is needed, GLOBAL

    // The line is guaranteed to be at least 1 char + 1 NUL and to start with a
    // non-blank. Only the first 2 characters of a command are significant, so
    // it's always OK simply to blindly check the first 2 characters
    cmd = (to_upper(buf[0]) << 8) | to_upper(buf[1]);
    switch (cmd) {

    case ('H'<<8 | 'E'):      // HELP
        pr_msg(msg_help, F_MSG_RESPONSE + F_MSG_CR);
        break;

    case ('I'<<8 | 'N'):      // INFO - version and status
        pr_msg(msg_info, F_MSG_RESPONSE + F_MSG_CR);
        NASSERIAL.print("Flags:      ");  // TODO decode it??
        pr_hex4((uint16_t)cas_flags, 1, 1);

        // report current working directory (/ or NASCOM)
        working_dir->getSFN(pbuf);
        NASSERIAL.print(F("Directory:  "));
        NASSERIAL.println(pbuf);

        NASSERIAL.print(F("Read  name: "));
        NASSERIAL.println(cas_rd_name);
        NASSERIAL.print(F("Write name: "));
        NASSERIAL.println(cas_wr_name);
        NASSERIAL.print(F("Vdisk name: "));
        NASSERIAL.println(cas_vdisk_name);
        break;

    case ('T'<<8 | 'O'):      // TO xxxx - relocate boot loader to xxxx.
        if (parse_leading(&pbuf) && parse_num(&pbuf, &tmp_long, 16)) {
            NASSERIAL.write((byte)0x55); // tell host: relocation will occur
            NASSERIAL.write((byte)(tmp_long & 0xff));      // low  byte of 16-bits
            NASSERIAL.write((byte)((tmp_long>>8) & 0xff)); // high byte of 16-bits
            DEBSERIAL.print(F("TO to 0x"));
            DEBSERIAL.println(tmp_long, HEX);
            // break from here will result in an unneeded NUL being sent but
            // that is not a problem because the Host is in ZINLIN (either from
            // the NAS-SYS or the NAScas command loops) which accepts data from
            // from serial or keyboard and will simply gobble and discard NULs.
        }
        else {
            // bad argument
            pr_msg(msg_err_addr_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('P'<<8 | 'A'):      // PAUSE nn - delay before supplying text file
        if (parse_leading(&pbuf) && parse_num(&pbuf, &tmp_long, 10)) {
            pause_delay = (unsigned int)(tmp_long & 0xffff);
            // all done
        }
        else {
            // bad argument
            pr_msg(msg_err_num_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('N'<<8 | 'U'):      // NULLS nn - delay between lines of text file
        if (parse_leading(&pbuf) && parse_num(&pbuf, &tmp_long, 10)) {
            nulls_delay = (unsigned int)(tmp_long & 0xffff);
            // all done
        }
        else {
            // bad argument
            pr_msg(msg_err_num_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('N'<<8 | 'E'):      // NEW - (re)read SDcard
        open_sdcard();
        break;

    case ('A'<<8 | 'U'):      // AUTOGO [0 | 1] - execute a file after loading
        if (parse_leading(&pbuf)) {
            if (parse_num(&pbuf, &tmp_long, 10)) {
                // set or clear the flag
                cas_flags = (cas_flags & ~FM_AUTO_GO) | (tmp_long ? 1 << FS_AUTO_GO : 0);
            }
            else {
            // bad argument
            pr_msg(msg_err_num_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            // no argument, simply toggle the flag
            cas_flags = cas_flags ^ FM_AUTO_GO;
        }
        break;

    case ('M'<<8 | 'O'):      // MO <8.3> - Mount virtual disk from FAT file-system. In PolyDos format
        if (cas_flags & FM_SD_FOUND) {
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, cas_vdisk_name)) {
                // Don't want to create a file, so check existence first
                if ( (working_dir->exists(cas_vdisk_name)) && handle.open(cas_vdisk_name, FILE_READ) ) {
                    handle.close();
                    cas_flags |= FM_VDISK_MOUNT;
                }
                else {
                    pr_msg(msg_err_fname_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                }
            }
            else {
                pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('D'<<8 | 'S'):      // DS - directory of SDcard
        if (cas_flags & FM_SD_FOUND) {
            dir_sdcard();
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('D'<<8 | 'V'):      // DV - directory of Virtual disk
        if (cas_flags & FM_SD_FOUND) {
            if (cas_flags & FM_VDISK_MOUNT) {
                NASSERIAL.write((byte)0xff); // tell host: a message is coming
                foreach_vdisk_dir(&pr_dirent, 0);
            }
            else {
                pr_msg(msg_err_vdisk_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('D'<<8 | 'F'):      // DF - directory of Flash
        NASSERIAL.write((byte)0xff); // tell host: a message is coming
        foreach_flash_dir(&pr_dirent, 0);
        break;

    case ('E'<<8 | 'S'):      // ES <8.3> - Erase file from FAT file-system
        if (cas_flags & FM_SD_FOUND) {
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, erase_name)) {
                // "handle" is undefined; it's just needed to allow the
                // method to be called. SD.remove() is actually slightly smaller..
                if (!handle.remove(working_dir, erase_name)) {
                    pr_msg(msg_err_fname_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                }
            }
            else {
                pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('R'<<8 | 'S'):      // RS <8.3> [AI] - Read specified file from FAT file-system.
        cas_flags &= ~ (FM_RD_SRC | FM_RD_AI); // default to error case, no AI
        if (cas_flags & FM_SD_FOUND) {
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, cas_rd_name)) {

                if (parse_ai(&pbuf)) {
                    cas_flags |= FM_RD_AI;
                }

                if (!working_dir->exists(cas_rd_name)) {
                    pr_msg(msg_warn_fname_missing, F_MSG_RESPONSE + F_MSG_CR);
                }

                // there are cases where the file does not exist yet because
                // we'll write it before reading it, it's up to the user to
                // decide if that's really an error. Therefore,
                // 1/ we cannot rely on opening the file now; need to defer
                //    until it's needed
                // 2/ need to set flags as though this was successful

                // Indicate SDcard as the source.
                cas_flags |= (2 << FS_RD_SRC);
            }
            else {
                pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('R'<<8 | 'V'):      // RV <8.2> [AI] - Read specified file from virtual file-system.
        cas_flags &= ~ FM_RD_SRC; // default to error case
        if (cas_flags & FM_SD_FOUND) {
             if (cas_flags & FM_VDISK_MOUNT) {
                 if (parse_leading(&pbuf) && parse_fname_polydos(&pbuf, cas_rd_name)) {
                     // try to find it..
                     dirindex = foreach_vdisk_dir(&find_dirent, cas_rd_name);
                     if (dirindex == -1) {
                         pr_msg(msg_err_fname_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                     }
                     else {
                         // dirindex is set up for the read. Indicate Vdisk as the source.
                         cas_flags |= (3 << FS_RD_SRC);
                     }
                 }
                 else {
                     pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                 }
             }
             else {
                 pr_msg(msg_err_vdisk_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
             }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('R'<<8 | 'F'):      // RF <8.2> - Read specified file from flash file-system.
        cas_flags &= ~ FM_RD_SRC; // default to error case
        if (parse_leading(&pbuf) && parse_fname_polydos(&pbuf, cas_rd_name)) {
            // try to find it..
            dirindex = foreach_flash_dir(&find_dirent, cas_rd_name);
            if (dirindex == -1) {
                pr_msg(msg_err_fname_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
            else {
                // dirindex is set up for the read. Indicate Flash as the source.
                cas_flags |= (1 << FS_RD_SRC);
            }
        }
        else {
            pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

    case ('W'<<8 | 'S'):      // WS <8.3> [AI] - Write specified file to FAT file-system.
        cas_flags &= ~ (FM_WR_SRC | FM_WR_AI); // default to error case, no AI
        if (cas_flags & FM_SD_FOUND) {
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, cas_wr_name)) {

                if (parse_ai(&pbuf)) {
                    cas_flags |= FM_WR_AI;
                }

                if (working_dir->exists(cas_wr_name)) {
                    pr_msg(msg_info_2bdeleted, F_MSG_RESPONSE + F_MSG_CR);
                }

                // Indicate SDcard as the destination
                cas_flags |= (2 << FS_WR_SRC);
            }
            else {
                pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

        /* NOT SUPPORTED
    case ('W'<<8 | 'V'): // WV <8.2> [AI] - Write specified file to virtual file-system.
        cas_flags &= ~ FM_WR_SRC; // default to error case
        if (cas_flags & FM_SD_FOUND) {
            if (cas_flags & FM_VDISK_MOUNT) {
                if (parse_leading(&pbuf) && parse_fname_polydos(&pbuf, cas_wr_name)) {
                    // The file need not exist yet so nothing to do here except remember state

                    // Indicate Vdisk as the destination
                    cas_flags |= (3 << FS_WR_SRC);
                }
                else {
                    pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                }
            }
            else {
                pr_msg(msg_err_vdisk_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;
        */

    case ('T'<<8 | 'S'):     // TS <8.3> - Read specified file from FAT file-system as text.
        cas_flags &= ~ FM_RD_SRC; // default to error case
        if (cas_flags & FM_SD_FOUND) {
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, cas_rd_name)) {
                if (handle.open(cas_rd_name, FILE_READ)) {
                    DEBSERIAL.println(F("TS file OK"));
                    // Send response "done" to exit the NAScas> loop
                    NASSERIAL.write((byte)0x00);
                    // Ready to go. No need to change cas_flags
                    delay(1000 * pause_delay);
                    char c;
                    while (handle.read(&c, 1)) {
                        NASSERIAL.write(c);
                        // TODO on \r or on \n? To give BASIC time to tokenize
                        if (c == '\r') {
                              delay(nulls_delay);
                        }
                    }
                    handle.close();
                }
                else {
                    pr_msg(msg_err_fname_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                }
            }
            else {
                pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
            }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;

        /* NOT SUPPORTED
    case ('T'<<8 | 'V'): // TV <8.2> [AI] - Read specified file from virtual file-system as text.
        cas_flags &= ~ FM_RD_SRC; // default to error case
        if (cas_flags & FM_SD_FOUND) {
             if (cas_flags & FM_VDISK_MOUNT) {
                 if (parse_leading(&pbuf) && parse_fname_polydos(&pbuf, cas_rd_name)) {
                     // try to find it..
                     dirindex = foreach_vdisk_dir(&find_dirent, cas_rd_name);
                     if (dirindex == -1) {
                         pr_msg(msg_err_fname_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                     }
                     else {
                         // dirindex is set up for the read. Read it now. No need to change
                         // cas_flags
                         // TODO do it..
                     }
                 }
                 else {
                     pr_msg(msg_err_fname_bad, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
                 }
             }
             else {
                 pr_msg(msg_err_vdisk_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
             }
        }
        else {
            pr_msg(msg_err_sd_missing, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
        }
        break;
        */

    default:
        pr_msg(msg_err_try_help, F_MSG_RESPONSE + F_MSG_ERROR + F_MSG_CR);
    }

    // Send response "done"
    NASSERIAL.write((byte)0x00);
}


// Call-back for cass_bin2cas: provides next byte from Flash file-system
// uses global variable index which is initialised by cmd_cass_rd before
// the call-back is used for the first time
char flash_fs_getch_cback(void) {
    return pgm_read_byte(index++);
}


// Call-back for cass_bin2cas: provides next byte from SDcard
// uses global file-handle handle which is initialised by cmd_cass_rd
// before the call-back is used for the first time (file is also
// seeked to the correct position)
char sdcard_fs_getch_cback(void) {
    return handle.read();
}


// Convert a binary blob into CAS format and feed it to the NASCOM
// remain - initial value is total length of the binary (in bytes)
// addr - initial value is the load address for the first byte of the binary
// exe_addr - the entry point/execution address
// *getch - function pointer that will deliver each byte of the file in turn
void cass_bin2cas(int remain, int addr, int exe_addr, char (*getch)(void)) {
    int block; // current block number.
    int count; // bytes in this block
    char c;    // next byte
    char csum; // accumulated 8-bit checksum
    char auto_go;

    // total number of blocks needed to send remain bytes
    block = ((remain + 0xff) & 0xff00) >> 8;

    if (addr == 0x10d6) {
        // looks like a BASIC program. Start with a header that
        // will allow CLOAD to recognise the file
        NASSERIAL.write("\xd3\xd3\xd3\x41"); // 41 is "A", the "filename"
        NASSERIAL.write((byte)0x00);
        NASSERIAL.write((byte)0x00);
        auto_go = 0;
    }
    else {
        auto_go = cas_flags & FM_AUTO_GO;
    }

    while (block != 0) {
        block--;  // the new block number
        DEBSERIAL.print(F("Addr="));
        DEBSERIAL.println(addr, HEX);
        DEBSERIAL.print(F("Block="));
        DEBSERIAL.println(block, HEX);
        DEBSERIAL.print(F("Remain="));
        DEBSERIAL.println(remain, HEX);
        // output sync pattern
        NASSERIAL.write((byte)0x00);
        NASSERIAL.write("\xff\xff\xff\xff");

        // output block header and checksum
        csum = (addr & 0xff) + (addr >> 8) + block;
        NASSERIAL.write(addr & 0xff);
        NASSERIAL.write(addr >> 8);
        if (remain > 255) {
            count = 256;
            NASSERIAL.write((byte)0); // means 256 bytes
            // do not need to accumulate count (0) in checksum
        }
        else {
            count = remain;
            NASSERIAL.write(count);
            csum = csum + count;
        }
        NASSERIAL.write(block);
        delayMicroseconds(DELAY); // For faster comms need a delay here
        NASSERIAL.write(csum); // 8-bit header checksum
        delayMicroseconds(DELAY); // For faster comms need a delay here

        // output block body
        csum = 0;
        while (count !=0) {
            c = getch();
            csum = csum + c;
            NASSERIAL.write(c);

            count--;
            remain--; // TODO simply subtract count
            addr++; // TODO simply add count
        }
        NASSERIAL.write(csum); // 8-bit body checksum

        // inter-block gap -- 10 NUL characters
        for (csum = 0; csum < 10; csum++) {
            NASSERIAL.write((byte)0);
        }
    }

    if (auto_go) {
        NASSERIAL.write('E');
        pr_hex4(exe_addr, 0, 1);
    }
}


// Abort a tape read pre/post block:
// - print 4 ESC characters
// - wait for Drive to negate
// - print a message prefix " NAScas "
// - print the message at FLASH address msg
// - print a CR/LF
void abort_rd(const char * msg) {
    NASSERIAL.write("\x1b\x1b\x1b\x1b"); // F() doesn't work here, for some reason

    // wait for DRIVE pin to negate
    while (!rd_drive()) {
    }

    pr_msg(msg, F_MSG_NASCAS + F_MSG_ERROR + F_MSG_CR);
}


// Respond to DRIVE light being on and timeout being reached without any rx data
// -> infer a "R"ead command.
// CAS format: supply bytes from file on SD until it's empty.
// FLASH format: encode chunk of data in CAS format
// End by waiting for DRIVE light to go off
// TODO other formats
void cmd_cass_rd() {
    switch (cas_flags & FM_RD_SRC) {

    case (1 << FS_RD_SRC):  // CAS-encode a binary file from Flash
        DEBSERIAL.println(F("CAS-encode from Flash"));

        // address of first byte of code -- index is a GLOBAL
        index = pgm_read_word(&romdir[dirindex].fptr);

        cass_bin2cas(pgm_read_word(&romdir[dirindex].flen),
                     pgm_read_word(&romdir[dirindex].flda),
                     pgm_read_word(&romdir[dirindex].fexa),
                     &flash_fs_getch_cback);
        break;

    case (3 << FS_RD_SRC):  // CAS-encode a binary file from Vdisk
        DEBSERIAL.println(F("CAS-encode a binary file from vdisk"));

        if (handle.open(cas_vdisk_name, FILE_READ)) {
            UDIRENT dirent;

            // seek to start of directory entry
            handle.seekSet((long)24 + (long)dirindex*(long)sizeof(struct DIRENT));
            handle.read(dirent.b, sizeof(struct DIRENT));

            // seek to start of file, all ready for the callback to use
            handle.seekSet((long)dirent.f.fsec * (long)POLYDOS_BYTES_PER_SECTOR);

            cass_bin2cas(dirent.f.flen * POLYDOS_BYTES_PER_SECTOR,
                         dirent.f.flda,
                         dirent.f.fexa,
                         &sdcard_fs_getch_cback);
            handle.close();
        }
        else {
            abort_rd(msg_err_vdisk_bad);
        }
        break;

    case (2 << FS_RD_SRC):  // Send an already-CAS-encoded file from SD
        // TODO for now, assume it's a LITERAL from SD (ie, already a CAS format file)
        if (handle.open(cas_rd_name, FILE_READ)) {
            // have a file name and can open the file -> good to go!
            // while drive light is on, grab bytes and send them to serial
            DEBSERIAL.println(F("file from SD"));
            char c;
            while (handle.read(&c, 1)) {
                NASSERIAL.write(c);
            }
            handle.close();

            // prepare for next read
            if (cas_flags & FM_RD_AI) {
                ai_filename(cas_rd_name);
            }
        }
        else {
            abort_rd(msg_err_fname_missing);
        }
        break;

    default:
        abort_rd(msg_err_bad_src);
        break;
    }

    // wait for DRIVE pin to negate (on error, will already have done this)
    while (!rd_drive()) {
    }
}


// buf is a null-terminated string containing a filename
// If the last 2 characters of the filename are numeric, increment modulo 100.
// If either is not numeric, change it to a 0.
// If the filename is only 1 character long, increment it modulo 10.
void ai_filename(char *buf) {
    int i = 0;
    int carry;
    while (buf[i] != '\0') {
        if (buf[i]== '.') {
            break;
        }
        i++;
    }
    // name is >=1 character so no need for a check here
    carry = buf[i-1] == '9';

    if ( (buf[i-1] < '0') || (buf[i-1] > '8')) {
        // modulo wrap from 9->0 or not numeric
        buf[i-1] = '0';
    }
    else {
        buf[i-1]++;
    }

    // only consider if name >= 2 characters
    if ((i > 2) && carry) {
        if (buf[i-2] == '9') {
            // modulo wrap from 9->0
            buf[i-2] = '0';
        }
        else if ( (buf[i-2] < '0') || (buf[i-2] > '9')) {
            // was not numeric but now it is: go from X9 to 10 not 00
            buf[i-2] = '1';
        }
        else {
            buf[i-2]++;
        }
    }
}


// Respond to DRIVE light being on and rx data being available -> infer a
// "W"rite command.
// *Only* support saving files in the format that the NASCOM presents them
// (usually, CAS format). Store the byte stream to the file on SD until
// DRIVE goes off. After DRIVE goes off, discard any remaining/buffered data
void cmd_cass_wr(void) {
    unsigned long start=millis();
    int done = 0;

    if ( (handle.open(cas_wr_name, FILE_WRITE | O_TRUNC)) ) {
        // have a file name and can open the file -> good to go!
        // while drive light is on, grab bytes and send them to disk
        while (!rd_drive()) {
            if (NASSERIAL.available()) {
                handle.write(NASSERIAL.read());

                if (done == 0) { // TODO DEBUG.. add an error check
                    DEBSERIAL.println(millis() - start);
                    done = 1;
                }
            }
        }
        handle.close();
        if (NASSERIAL.overflow()) {
            pr_msg(msg_err_overflow, F_MSG_NASCAS + F_MSG_ERROR + F_MSG_CR);
        }

        // prepare for next write
        if (cas_flags & FM_WR_AI) {
            ai_filename(cas_wr_name);
        }
    }
    else {
         // wait for pin to negate
        while (!rd_drive()) { }
        pr_msg(msg_err_open_fail, F_MSG_NASCAS + F_MSG_ERROR + F_MSG_CR);
    }

    // empty any rogue characters TODO do I still need this?
    while (NASSERIAL.available()) {
        NASSERIAL.read();
    }
}


#ifdef CONSOLE
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Console interface: commands issued through the DEBSERIAL port, which
// is the USB connection to a PC.
//
// For command/protocol description, see
// ../doc/console_interface_command_set.md
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
void console_dir_sdcard(void) {
    char txtbuf[13];
    char * txt = txtbuf;

    working_dir->rewind();
    while (handle.openNext(working_dir, O_RDONLY)) {
        int len;
        handle.getSFN(txt);
        len = 15 - DEBSERIAL.write(txt);

        if (handle.isDir()) {
            DEBSERIAL.write('/');
        }
        else {
            while (len > 0) {
                DEBSERIAL.write(' ');
                len--;
            }

            // Print file size in bytes. Max file size is 2gb ie 10 digits
            int pad=0;
            long i=1000000000;
            long n = handle.fileSize();
            long dig;

            while (i > 0) {
                dig = n/i; // integer division with truncation
                n = n % i; // remainder
                if ((dig > 0) | (pad==1) | (i==1)) {
                    pad = 1;
                    DEBSERIAL.write('0'+dig);
                }
                else {
                    DEBSERIAL.write(' ');
                }
                i = i/10;
            }
            DEBSERIAL.write(" bytes");
        }
        DEBSERIAL.write("\x0d\x0a");
        handle.close();
    }
}


// Print "Ack n<cr><lf>" to DEBSERIAL, where n is the number given by "status"
void console_ack(int status) {
    DEBSERIAL.print(F("Ack "));
    DEBSERIAL.println(status);
}


// Command-handler for console interface.
void cmd_console(void) {
    char buf[512]; // used for command line then as write data buffer
    char * pbuf = &buf[0];
    char file_name[13]; // 8 + 1 + 3 + 1 bytes for null-terminated FAT file name
    int index = 0; // used to index buf[] in both of its applications
    unsigned long file_length;

    // Receive a CR-terminated string from the Host into buf[]
    while (1) {
        if (DEBSERIAL.available()) {
            buf[index] = DEBSERIAL.read();
            if (buf[index] == 0x0d) { // stop at end of line
                break;
            }
            else {
                index++;
            }
        }
    }

    if (cas_flags & FM_SD_FOUND) {
        switch (buf[0]) {
        case 'D':    // DIRECTORY
            console_ack(0); // Directory Success. Directory text follows..
            console_dir_sdcard();
            break;

        case 'E':    // ERASE
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, file_name)) {
                // "handle" is undefined; it's just needed to allow the
                // method to be called. SD.remove() is actually slightly smaller..
                if (handle.remove(working_dir, file_name)) {
                    console_ack(2); // Erase Success.
                    break;
                }
            }
            console_ack(3); // Error: bad filename or file not found or erase failed.
            break;

        case 'W':    // WRITE
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, file_name)
                && parse_num(&pbuf, &file_length, 10)
                && handle.open(file_name, FILE_WRITE | O_TRUNC)) {
                // got the file name and the file size and opened the file successfully
                console_ack(4); // Write success; ready for data

                // send a "." to request each chunk of 512 bytes into the buffer; write the
                // buffer when full or after the last transfer
                index = 0;
                DEBSERIAL.write('.');

                for (unsigned long i=0; i<file_length; i++) {
                    while (! DEBSERIAL.available()) {
                    }
                    buf[index++] = DEBSERIAL.read();
                    if (index == 512) {
                        handle.write(buf, index);
                        index = 0;
                        DEBSERIAL.write('.');
                    }
                }
                // final bytes
                if (index != 0) {
                    handle.write(buf, index);
                }
                handle.close(); // does an implicit sync
                console_ack(8); // Write success and finished
                break;
            }
            console_ack(5); // Error: bad filename or missing length or open failed.
            break;

        case 'R':    // READ
            if (parse_leading(&pbuf) && parse_fname_msdos(&pbuf, file_name)
                && handle.open(file_name, FILE_READ)) {

                console_ack(6); // So far, so good

                // need to report the file size so that the console knows how many bytes
                // to expect. Otherwise, no way to signal EOF while using a binary format.
                file_length = handle.size();
                DEBSERIAL.println(file_length);

                // send the file
                for (unsigned long i=0; i<file_length; i++) {
                    DEBSERIAL.write(handle.read());
                }

                handle.close();
                break;
            }
            console_ack(7); // Error: bad filename or file not found or open failed.
            break;

        case 'P':    // PUT
            {
                // use file_length to hold write address.
                unsigned long int data;
                if (parse_leading(&pbuf) && parse_num(&pbuf, &file_length, 16)
                    && parse_num(&pbuf, &data, 16) ) {
                    EEPROM.update(file_length, data);
                }
                console_ack(10); // EEPROM write success (even if it wasn't)
                break;
            }

        case 'G':    // GET
            // use file_length to hold write address and data
            if (parse_leading(&pbuf) && parse_num(&pbuf, &file_length, 16) ) {
                file_length = EEPROM.read(file_length);
            }
            else {
                file_length = 0;
            }
            console_ack(12); // EEPROM read success (even if it wasn't)
            DEBSERIAL.print((unsigned char)file_length, HEX);
            break;

        default:
            console_ack(9); // Error: command not recognised.
        }
    }
    else {
        console_ack(1); // Error: no SDcard present.
    }
}
#endif // CONSOLE
