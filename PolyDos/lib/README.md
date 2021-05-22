# Index of files on PolyDos disk images

````

PD000 -- PolyDos 2 System disk and SDcard utilities
=====

   Sect Nsct Load Exec SysFlg   Name
   0004 0008 c800 0000 L        Exec.OV               PolyDos
   000c 0005 c800 0000 L        Emsg.OV               "
   0011 0006 c800 0000 L        Dfun.OV               "
   0017 0003 c800 0000 L        Ecmd.OV               "
   001a 0008 c800 0000 L        Edit.OV               "
   0022 0001 c200 c200 L        Info.IN               "
   0023 0001 c800 0000 L        BSfh.OV               "
   0024 0010 b000 b000 L        BSdr.BR               "
   0034 0005 1000 1000          FORMAT.GO             " NOTE1
   0039 0003 1000 1000          BACKUP.GO             " NOTE1
   003c 0004 1000 1000          SZAP.GO               "
   0040 0016 1000 1000          PZAP.GO               "
   0056 0005 0000 0000          SYSEQU.SY             "
   005b 0012 0000 0000          DUMPS.TX              "
   006d 0001 1000 1000          DUMP.GO               "
   006e 0075 0000 0000          PD2S.TX
   00e3 0010 1000 1000          PTXT.GO
   00f8 000b 10d6 0000          DBASE.BS
   0103 0006 0000 0000          DATA.TX
   0109 0003 10d6 0000          FOUR.BS
   010c 004e 1000 101e          PASCAL.GO
   015a 001d 0000 0000          GETCPM.TX
   0177 0002 b800 b800          GET30.GO
   0179 0030 1000 1000          MOVCPM.MC
   01a9 0001 0000 0000          HELLO.TX
   01aa 0001 1000 1000          SDDIR.GO              SD utility to show files on SDcard
   01ab 0002 1000 1000          SETDRV.GO             SD utility to set drive from SDcard file
   01ad 0002 bd00 bd00          CASDSK.GO             SD utility to redirect tape load/save to disk
   01af 0004 1000 1000          SCRAPE5.GO            SD utility to scrape CP/M disk to SDcard
   01b3 0001 0c80 0c80          SD_WR1.GO             SD code to write file to SDcard from RAM
   01b4 0008 d800 d800          POUTD800.GO           PolyDos/SD utils boot ROM binary
   01bc 0008 b800 b800          POUTB800.GO           PolyDos/SD utils boot ROM binary
   01c4 0001 0c80 0c80          SD_RD1.GO             SD code to read file from SDcard to RAM
   01c5 0001 0000 0000          SDOFF.GO              SD utility to disable SDcard so that PIO can be used for something else
   01c6 0002 1000 1000          SCRAPE.GO             SD utility to scrape PolyDos disk to SDcard
   01c3 0004 1000 1000          FORMAT3.GO            PolyDos NOTE2
   01c7 0003 1000 1000          BACKUP3.GO            PolyDos NOTE2
   01ca 0004 1000 1000          NUBLO.GO              Software for GM808 EPROM programmer
   01ce 0008 0000 0000          VID80.TX              Source code for VID80.GO
   01d6 0001 9000 9000          VID80.GO              Switch to 80-column video on MAP80 VFC board

NOTE1: nascom_sdcard does not require the use of these PolyDos utilities. If you run them, they will
(attempt to) talk to your disk drive hardware directly; useful if you do want to create physical
magnetic media. These are the version for PolyDos 2 (and so they expect 35-track DS SD/DD drives).

NOTE2: These are the versions for PolyDos3 (and so they expect 80-track SS DD drives).

--------------------------------------------------------------------------------------
PD100 -- Languages
==================

   Sect Nsct Load Exec SysFlg   Name
   0004 002f 1400 1400          FORTH.GO     HULL Forth, version 1.1  [Origin: virtual-nascom]
   0033 0054 1000 1000          HISOFT.GO    E 1000  Hisoft Pascal    [Origin: virtual-nascom]
   0087 0030 1000 1000          BLSPAS12.GO  BLS Pascal 1.2           [Origin: virtual-nascom]
   00b7 0016 1000 1000          EMPL.GO      Micro APL                [Origin: groups.io]

--------------------------------------------------------------------------------------
PD200 -- INMC Classics
======================

pirana.cas     E 1000  Simple but classic, from INMC magazine. [Origin: virtual-nascom]
ELIZA.nas              Clasic [Origin: virtual-nascom]


--------------------------------------------------------------------------------------
PD300 -- Games in Danish
========================

adventur.cas   E 1000  Text-based adventure (Danish language) [Origin: virtual-nascom]
falling.cas    E 1000  Falling Stones (Danish instructions)   [Origin: virtual-nascom]
skak.cas       E 1000  Chess (Danish language)                [Origin: virtual-nascom]


PD301 -- Level 9 Computing
==========================

lordtime.cas   E 1000  Lords Of Time, Level 9 Computing.      [Origin: virtual-nascom]
snowball.cas   E 1000  Text-based space adventure, Level 9 Computing. [Origin: virtual-nascom]
ASTEROID.NAS           Level 9 Computing. [Origin: virtual-nascom]
EDEN.NAS               Level 9 Computing. [Origin: virtual-nascom]
COLOSSAL.NAS           Level 9 Computing. [Origin: virtual-nascom]
DUNGEON.NAS            Level 9 Computing. [Origin: virtual-nascom]
DUNGEON.CLU            Clues for DUNGEON    [Origin: virtual-nascom]
DUNGEON.SOL            Solution for DUNGEON [Origin: virtual-nascom]


PD302 -- Blue-label software games
==================================

breakout.go   E 1000  Breakout, Blue Label Software.           [Origin: virtual-nascom]
pacman.go     E 1000  Pacman, of course. Blue Label Software.  [Origin: virtual-nascom]
spacezap.go   E 1000  Shoot-em-up. Blue Label Software.        [Origin: virtual-nascom]


PD303 -- Miscellaneous Games
============================

ASTEROID.GO    E 1000  Asteroids, Steven Weller                [Origin: virtual-nascom]
DRIVER.GO      E 1000  Night Driver, OZ1AEX                    [Origin: virtual-nascom]
ENARMET.GO     E 4400  Fruit machine, S.C. Allen               [Origin: virtual-nascom]
LABYRINT.GO    E 1000  Walk though a 3D maze                   [Origin: virtual-nascom]
LUMBERJA.GO    E 1000  Lumberjack. From Program Power.         [Origin: virtual-nascom]
MONSTER.GO     E 1000  Graphical platform game, SSI Real-time games.          [Origin: virtual-nascom]
SERPENT.GO                                                     [Origin: virtual-nascom]
AVALANCHE.GO                                                   [Origin: virtual-nascom]
GOLD.GO                                                        [Origin: virtual-nascom]
PACMAN.GO                                                      [Origin: virtual-nascom]
REVERSI.GO                                                     [Origin: virtual-nascom]
HOLE.GO                                                        [Origin: virtual-nascom]
SPCINV.GO                                                      [Origin: virtual-nascom]
SPACEWAR.GO                                                    [Origin: virtual-nascom]
GALAXIAN.GO                                                    [Origin: virtual-nascom]
JAILBRK.GO                                                     [Origin: virtual-nascom]
GALAXY.GO                                                      [Origin: virtual-nascom]
SARGON13.GO                                                    [Origin: virtual-nascom]
PACMAN2.GO                                                     [Origin: virtual-nascom]
MAZE3D.GO    KKS-3dmaze.nas                                    [Origin: virtual-nascom]


PD304 "M/C Games" -- Miscellaneous machine-code games (from Neal's collection)
=================

   Sect Nsct Load Exec SysFlg   Name
   0004 0008 c800 0000 L        Exec.OV
   000c 0005 c800 0000 L        Emsg.OV
   0011 0006 c800 0000 L        Dfun.OV
   0017 0003 c800 0000 L        Ecmd.OV
   001a 0008 c800 0000 L        Edit.OV
   0022 0001 c800 0000 L        BSfh.OV
   0023 0010 b000 b000 L        BSdr.BR
   0033 0017 1000 1000          GALAXY.GO
   004a 0009 1000 1000          PIRAN.GO
   0053 0010 1000 1000          SPCINV.GO
   0063 0020 e000 e000          MICBAS.MC
   0083 001d 1000 1000          SARGON.GO
   00a0 0016 1000 1000          ASTROD.GO
   00b6 006b 1000 1000          TRAP.GO
   0121 000e 1000 1000          DEFEND.GO
   012f 000c 1000 1000          GALINV.GO
   013b 0004 0c80 0c80          OTHELO.GO
   013f 0006 1000 1000          3DTTT.GO
   0145 0004 1000 1000          LOLLIPOP.GO
   0149 000b 4400 4400          FRUIT.GO
   0154 0004 1600 1600          RUBIK.GO
   0158 0009 1000 1000          SIMP.GO
   0161 0070 1000 1000          ADVENTUR.GO
   01d1 000e 1000 1000          STARFGHT.GO
   01df 0043 1000 1000          ELIZA.GO


PD305 "More M/C Games" -- Miscellaneous machine-code games
======================

   Sect Nsct Load Exec SysFlg   Name
   0004 006b 1000 1000          ASTROTRP.GO  -- Astrotraps, Deep Thought Software, 1982


--------------------------------------------------------------------------------------
PD400 -- BASIC Games
====================

NIMBOT.BS                                       [Origin: virtual-nascom]
LEMONADE.BS Classic Lemonade Stand simulation   [Origin: virtual-nascom]
INVADERS.BS Space invaders implemented in BASIC [Origin: virtual-nascom]

PD402 -- BASIC Games (from The Nascom Home Page)
====================

DQUEST.BS    Dungeon Quest.
KKRAAL.BS    Keys of Kraal.
OXO3D.BS     3d Noughts and Crosses.
ALIENINV.BS  Alien Invaders.
AMSTRMND.BS  Auto Mastermind.
BIO.BS       Bio Rhythms.
BIO2.BS      Bio Rhythms 2.
DRIVE.BS     Drive.
HANGMAN.BS   Hangman.
HELLO.BS     Hello.
LABYRNTH.BS  Labyrinth.
LUNAR2.BS    Lunar II.
MOONBASE.BS  Moonbase.
OTHELLO.BS   Othello.
QUEST.BS     Quest.
SHEEPDOG.BS  Sheepdog.
SCRAMBLE.BS  Scramble, The Word Computer Game.
TREK16.BS    Star-Trek for 16KB Nascoms.
TREK.BS      The classic game Startrek
WRAPTRAP.BS  WrapTrap.
LDGOLD.BS    Lost Dutchman's Gold
SNAILR.BS    Snail Racing from PCW
SWINGHS.BS   SwingHouse (graphic Animation after 10 min)
ADVENTR.BS   Adventure Land
SWORDS.BS    Swords and Sorcery by David Kastrup
LEMON.BS     Lemonade Stand
CAMEL.BS     Camel
INVADERS.BS  The Invaders -- from C&VG



PD403 -- BASIC Games in German (from The Nascom Home Page)
====================

MALOCHE.BS     Maloche game in german.
SCRAMBLE.BS    Mini Scramble game in german.
CHECKERS.BS    Das Dame Spiel (Checkers)
SCHIFFE.BS     in german: Schiffe versenken
SYMDIFF.BS     mathematics in german: symbolisches Differenzieren
VECTOR.BS      mathematics in german: Vektorrechnung
FILTER.BS      electronics in german: Filterberechnung


PD404 -- BASIC Games (from Neal's collection)
====================

   Sect Nsct Load Exec SysFlg   Name
   0004 0008 c800 0000 L        Exec.OV
   000c 0006 c800 0000 L        Dfun.OV
   0012 0005 c800 0000 L        Emsg.OV
   0017 0001 c200 0000 L        Info.IN
   0018 0001 c800 0000 L        BSfh.OV
   0019 0010 b000 b000 L        BSdr.BR
   0029 0001 0c90 0c90 L        Init.GO
   002a 0020 10d6 0000          ELIZA.BS
   004a 001d 10d6 0000          STOCKMAR.BS
   0067 0018 10d6 0000          MACRONOI.BS
   007f 000a 10d6 0000          MOON1NC.BS
   0089 0006 10d6 0000          MOON2NC.BS
   008f 001d 10d6 0000          EVEREST.BS
   00ac 0009 10d6 0000          M-MIND.BS
   00b5 0009 10d6 0000          ZOMBIES.BS
   00be 0006 10d6 0000          ADDNTEST.BS
   00c4 0007 10d6 0000          MULTTEST.BS
   00cb 0005 10d6 0000          REACTIME.BS
   00d0 0008 10d6 0000          SUBMARIN.BS
   00d8 0007 10d6 0000          DRIVING.BS
   00df 0007 10d6 0000          AMBUSH.BS
   00e6 0003 10d6 0000          SPACER.BS
   00e9 000c 10d6 0000          ROADRACE.BS
   00f5 000b 10d6 0000          STOCKCAR.BS
   0100 0003 10d6 0000          DICE.BS
   0103 0012 10d6 0000          AG-FLIER.BS
   0115 000a 10d6 0000          HANGMAN.BS
   011f 0015 10d6 0000          ROBOTNIM.BS
   0134 0033 10d6 0000          B-GAMMON.BS
   0167 0027 10d6 0000          LABYRINT.BS
   018e 0009 10d6 0000          CALENDER.BS
   0197 0011 10d6 0000          LONGADD.BS
   01a8 0017 10d6 0000          CAMEL.BS
   01bf 003c 10d6 0000          ADVENTUR.BS
   01fb 0020 10d6 0000          GOLF.BS
   021b 000f 10d6 0000          FOXHON.BS
   022a 0061 10d6 0000          VALLEY.BS
   028b 0039 10d6 0000          ALILAB.BS
   02c4 0045 0c80 0c80          LUNLAN.BS
   0309 0044 10d6 0000          QUEST.BS
   034d 0049 10d6 0000          KRAAL.BS
   0396 0035 10d6 0000          STARTREK.BS
   03cb 0035 10d6 0000          TREK.BS
   0400 0012 10d6 0000          ALIEN.BS
   0412 003f 10d6 0000          SARAH.BS
   0451 0010 10d6 0000          SHEEPDOG.BS
   0461 0009 10d6 0000          MASTERMD.BS
   046a 000a 10d6 0000          BIO.BS
   0474 000e 10d6 0000          BATSHIPS.BS
   0482 0013 10d6 0000          SCI-FI.BS


PD405 "BASIC games 2" -- More BASIC Games (from Neal's collection)
=====================

   0035 001b 10d6 0000          MAGICLAB.BS
   0050 000f 10d6 0000          ZOMBIE.BS
   005f 000c 10d6 0000          MOONBASE.BS
   006b 000d 10d6 0000          MAZE-RUN.BS
   0078 000c 10d6 0000          WRAPTRAP.BS
   0084 0007 10d6 0000          REVERSAL.BS
   008b 0004 10d6 0000          NAS-PAT.BS
   008f 0036 10d6 0000          STONEVIL.BS
   00c5 000d 10d6 0000          FIGHTER.BS

--------------------------------------------------------------------------------------
PD500.BIN "Adventure dev." -- Adventure engine based on article in Practical Computing
==========================

   0024 0016 1000 1000 L        AS.GO
   003a 003a 0000 0000          DRIVER.TX
   0074 003a 0000 0000          ADVENDOC.TX
   00ae 0007 1000 1000          ADVENT.GO
   00b5 0005 0000 0000          DRIVER.SY
   00ba 0007 1676 1006          Q.GO
   00c1 0001 0000 0000          REDODA.TX
   00c2 0012 0000 0000          DATABAS.TX

--------------------------------------------------------------------------------------
PD600.BIN NASCOM ROMs
=====================

Sect Nsct Load Exec SysFlg   Name
   0004 0008 c800 0000 L        Exec.OV
   000c 0005 c800 0000 L        Emsg.OV
   0011 0006 c800 0000 L        Dfun.OV
   0017 0003 c800 0000 L        Ecmd.OV
   001a 0008 c800 0000 L        Edit.OV
   0022 0001 c200 c200 L        Info.IN
   0023 0001 c800 0000 L        BSfh.OV
   0024 0010 b000 b000 L        BSdr.BR
   0034 000d 0000 0000          CHARGEN.TX
   0041 0008 0000 0000          README.TX
   0049 0010 0000 0000          CHARGEN.GO
   0059 0020 0000 0000          BASIC.GO
   0079 0008 0000 0000          NASSYS3.GO
   0081 0008 0000 0000          NASSYS3A.GO
   0089 0008 0000 0000          NASSYS3N.GO
   0091 0008 0000 0000          NASSYS3X.GO
   0099 0008 0000 0000          NASPEN.GO
   00a1 0008 0000 0000          POLY2.GO
   00a9 0007 0000 0000          POLY3.GO
   00b0 0008 0000 0000          NASSYS1.GO


PD601.BIN NAS-DOS ROMs
======================

  Sect Nsct Load Exec SysFlg   Name
   0004 0008 c800 0000 L        Exec.OV
   000c 0005 c800 0000 L        Emsg.OV
   0011 0006 c800 0000 L        Dfun.OV
   0017 0003 c800 0000 L        Ecmd.OV
   001a 0008 c800 0000 L        Edit.OV
   0022 0001 c200 c200 L        Info.IN
   0023 0001 c800 0000 L        BSfh.OV
   0024 0010 b000 b000 L        BSdr.BR
   0034 0004 0000 0000          NASDOSDC.GO
   0038 0004 0000 0000          NASDOSD8.GO
   003c 0004 0000 0000          NASDOSD0.GO
   0040 0004 0000 0000          NASDOSD4.GO
   0044 0004 0000 0000          ND14MDC.GO
   0048 0004 0000 0000          ND14DD0.GO
   004c 0004 0000 0000          ND14MD0.GO
   0050 0004 0000 0000          ND14DD8.GO
   0054 0004 0000 0000          ND14DD4.GO
   0058 0004 0000 0000          ND14MD8.GO
   005c 0004 0000 0000          ND14DDC.GO
   0060 0004 0000 0000          ND14MD4.GO
   0064 0008 0000 0000          README.TX

README.TX
NASCOM ROM Images

BASIC.GO    - (8Kb) NASCOM 8K ROM BASIC, load at £E000
CHARGEN.GO  - (4Kb) NASCOM main and graphics character set
CHARGEN.TX  -       Format of CHARGEN.GO
NASSYS3.GO  - (2Kb) NAS-SYS 3, load at £0000
NASSYS1.GO  - (2Kb) NAS-SYS 1, load at £0000. As dumped from
                    Neal's original N2 masked ROM
NASSYS3A.GO - (2Kb) NAS-SYS 3A, load at £0000. As sold with
                    NASCOM3 to provide AVC Disable
NASSYS3N.GO - (2Kb) NAS-SYS 3N, load at £0000. For networked
                    system?
NASSYS3X.GO - (2Kb) NAS-SYS 3, load at £0000. Of unknown
                    provenance
NASPEN.GO   - (2Kb) NASPEN, load at £B800
NASDOSD0.GO - (1Kb) NAS-DOS 1.2, load at £D000
NASDOSD4.GO - (1Kb) NAS-DOS 1.2, load at £D400
NASDOSD8.GO - (1Kb) NAS-DOS 1.2, load at £D800
NASDOSDC.GO - (1Kb) NAS-DOS 1.2, load at £DC00
                    Images dumped by Mike Strange
                    Include Lucas copyright message

ND14MD0.GO  - (1Kb) NAS-DOS 1.4, load at £D000
ND14MD4.GO  - (1Kb) NAS-DOS 1.4, load at £D400
ND14MD8.GO  - (1Kb) NAS-DOS 1.4, load at £D800
ND14MDC.GO  - (1Kb) NAS-DOS 1.4, load at £DC00
                    Images from "nasdos-1.4.rom" dumped
                    by Malkavian "as found on a NASCOM 3".
                    Different copyright dates from the
                    other set but both announce themselves
                    as "NAS-DOS 1"
                    Include Lucas copyright message
                    These match code from the latest version
                    of nasdos disassembly, as found on Github

ND14DD0.GO  - (1Kb) NAS-DOS 1.4, load at £D000
ND14DD4.GO  - (1Kb) NAS-DOS 1.4, load at £D400
ND14DD8.GO  - (1Kb) NAS-DOS 1.4, load at £D800
ND14DDC.GO  - (1Kb) NAS-DOS 1.4, load at £DC00
                    Images from "Nasdos-disassembled.zip"
                    by Malkavian.
                    Identical to images from "Nas-Dos.zip"
                    by Mike Strange.
                    (ND14DDC.GO matches ND14MDC.GO)
                    No Lucas copyright message. These seem to
                    have come from a ROM in MAME.

POLY2.GO    - (2Kb) POLYDOS 2 boot ROM, load at £D000
POLY3.GO    - (2Kb) POLYDOS 3 boot ROM, load at £D000 -- only
                    1720 bytes. I assume the rest is unused

--------------------------------------------------------------------------------------




============= to import from virtual NASCOM

ls e1000/
CHESS.BAT     dungeon.zip chessv13.zip  ROM?-CGSARGON.NAS


======= BASIC programs from the Nascom Home Page

TODO - "classic" INMC games onto 1 disk

TODO games from Nascom Home Page
TODO games from yahoo
TODO ROM images
TODO remove duplicates, test everything, better organisation etc..

````
