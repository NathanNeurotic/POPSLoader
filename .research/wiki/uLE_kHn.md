<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/uLE_kHn -->
<!-- primary snapshot: 20240324023511  |  10 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/uLE_kHn/: 20170629140906, 20191109144508 -->
# uLE_kHn

# **[uLE_kHn](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version)**

______________________________________________________________________________________________________________

uLE_kHn is a modified version of AKuHAK’s [uLE 4.42e HDD edition WIP7](http://psx-scene.com/forums/f113/unofficial-launchelf-v4-42-a-37242/#post261143). It has 2 main features :

- Same as WIP7, it can create HDD partitions with no “+” symbol at start – to create the __.POPS/ partition ;

- It can be used as a GUI to launch your VCDs directly. Just place a single copy of POPSTARTER.ELF in your POPS folder and you’re done (no need to rename it).

**Example of working setup – USB mode :**

```
mass:/POPS/POPS_IOX.PAK
mass:/POPS/Crash Bandicoot.VCD
mass:/POPS/POPSTARTER.ELF
mc0:/BOOT/BOOT.ELF
```

**Notes :**

- Launching VCDs in SMB mode is not supported ;

- Do not use it as your normal uLE version – it’s based on obsolete stuff.

______________________________________________________________________________________________________________

## *Changelog :*

**Note :** uLE_kHn is discontinued.

- **uLE_kHn_20191110 – 2019/11/10**

- **[uLE_kHn_20160723 – 2016/07/24](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-84#post-895246)**

```
The new uLE_kHn_20160723 is the same as uLE_kHn_20150727, but I've restored the USB drivers of my PS2SDK installation.
```

- **uLE_kHn_20150727 – 2015/07/27**

```
- Sbv from PS2SDK commit c6cd5b3447.
- Old USBD (CRC32 8EA56869) + USBHDFSD of POPStarter r13 WIP 02/05 (CRC32 E96C037A).
- Added support for running VCDs from mass:/POPS#/ (as introduced in POPStarter r13 WIP 06 OBT).
- The stub of the packed ELF is a clone of the POPStarter r13 payload.
Side note : compiled the same day as POPStarter r13 WIP 06 open beta 6.
```

- **[uLE_kHn_2015/06/02 – 2015/06/03](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-61#post-813385)**

```
- Fixed : Red screen of death in the PSX after selecting MISC/PS2Browser.
- MISC/PS2Browser does not skip the HDD and the MC when uLE has not been run from the MBR.
```

- **[uLE_kHn_20150506 – 2015/05/06](https://www.metagames-eu.com/forums/1770217-post163.html)**

```
- Fixed : Cannot launch ELFs/VCDs on slims and fats that don't have a HDD.
```

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
