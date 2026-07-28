<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vmc -->
<!-- primary snapshot: 20170629133617  |  6 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/vmc/: 20201112015747, 20240324023511 -->
# vmc

# **Virtual Memory Cards**

______________________________________________________________________________________________________________

## *About VMC :*

The very first time a game is launched, a new folder named “GAME” (ex : Crash Bandicoot) will be created into your POPS directory – one separate folder for each game. This folder contains 2 files – SLOT0.VMC & SLOT1.VMC, which are your VMCs.

```

POPS/Crash Bandicoot.VCD
POPS/Crash Bandicoot/SLOT0.VMC
POPS/Crash Bandicoot/SLOT1.VMC

```

If you know how to hexedit POPStarter, you can change that behaviour to have only 1 VMC created – or not at all. Check the [configuration table](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table) to know how to change the default setting (offset $429).

______________________________________________________________________________________________________________

## *Setting a path for the VMC folder :*

Here’s how to change the destination VMC folder of your games :
Let’s say your game is MY_GAME.VCD. The VMCs are saved to POPS/MY_GAME/. You want the VMCs to be saved into POPS/BLAHBLAH/ instead.

1. Create an empty text file;

1. Write BLAHBLAH into it;

1. Save it as VMCDIR.TXT;

1. Copy VMCDIR.TXT to POPS/MY_GAME/

Example :

```

mass:/POPS/MY_GAME.VCD
mass:/POPS/MY_GAME/VMCDIR.TXT
mass:/POPS/BLAHBLAH/SLOT0.VMC
mass:/POPS/BLAHBLAH/SLOT1.VMC

```

**Notes :**

-  All the POPStarter files (TROJANs, PATCHes, CHEATS.TXT...) will still be loaded from /POPS/MY_GAME/, but POPS will use the VMCs that are in /POPS/BLAHBLAH/

- Characters that are obviously not allowed are / \ and :

- VMCDIR.TXT will not be loaded if it’s bigger than 103 bytes or if it contains more than 1 line.

- Target folder must remain in POPS folder.

- This feature is useful when you are several users and want to use different VMCs. Each user can have his own VMC folder.

- If you want to use a single pair of VMCs for ALL your games, place the VMCDIR.TXT file in POPS folder. The VMCs will not be overwritten but mounted and loaded, and you will be able to save in them with no data loss.

Example :

```

smb:/YourSharedFolder/POPS/Crash Bandicoot.VCD
smb:/YourSharedFolder/POPS/Tekken.VCD
smb:/YourSharedFolder/POPS/Castlevania - Symphony of the night.VCD
smb:/YourSharedFolder/POPS/VMCDIR.TXT
smb:/YourSharedFolder/POPS/SAVES/SLOT0.VMC
smb:/YourSharedFolder/POPS/SAVES/SLOT1.VMC

```

with SAVES written into smb:/YourSharedFolder/POPS/VMCDIR.TXT

Here the 3 games mentionned will use smb:/YourSharedFolder/POPS/SAVES/SLOT0.VMC and smb:/YourSharedFolder/POPS/SAVES/SLOT1.VMC as VMCs with no issue.

______________________________________________________________________________________________________________

## *Additional notes :*

- No physical MC support ATM – would be too slow.

______________________________________________________________________________________________________________

## *Related stuff :*

You may want to give a look at this :

- [VMC] [Use your PS1 MC saves with POPStarter](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/pmc-to-vmc)

- [VMC] [Use your VMC saves on a PS1 retail console](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vmc-to-pmc)

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
