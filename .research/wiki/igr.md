<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr -->
<!-- primary snapshot: 20240324023512  |  8 captures, 2 distinct content version(s) -->
<!-- other distinct versions retained in _versions/igr/: 20170629144509 -->
# igr

# **In-Game-Reset**

______________________________________________________________________________________________________________

## *IGR Behaviour Modifiers :*

POPStarter has his own IGR ( Select + R1 + L1 ). You can change the button combo using one PATCH/TROJAN of the [IGR behaviour modifiers archive](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_Behaviour_Modifiers.zip) – or just use a [special command](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats) for it in POPS/CHEATS.TXT or POPS/GAME/CHEATS.TXT.

<table class="wiki"> <tbody><tr> <td> <strong>File name</strong> </td> <td> <strong>Button combo</strong> </td> <td> <strong>Action</strong> </td> </tr> <tr> <td> TROJAN_0.BIN </td> <td> L1 + L2 + R1 + R2 + ✕ + ↓ </td> <td> Opens the IGR menu. </td> </tr> <tr> <td> TROJAN_1.BIN </td> <td> Select + Start </td> <td> Opens the IGR menu. </td> </tr> <tr> <td> TROJAN_2.BIN </td> <td> L1 + L2 + R1 + R2 + Select + Start </td> <td> Opens the IGR menu. </td> </tr> <tr> <td> TROJAN_3.BIN </td> <td> L1 + L2 + R1 + R2 + ✕ + ↓ </td> <td> Terminates POPS (no IGR menu). </td> </tr> <tr> <td> TROJAN_4.BIN </td> <td> Select + Start </td> <td> Terminates POPS (no IGR menu). </td> </tr> <tr> <td> TROJAN_5.BIN </td> <td> L1 + L2 + R1 + R2 + Select + Start </td> <td> Terminates POPS (no IGR menu). </td> </tr> <tr> <td> PATCH_0.BIN </td> <td> (none) </td> <td> Disables the IGR menu. </td> </tr> </tbody></table>

- **How to install :**

Copy one of the PATCH/TROJAN files to the VMC game folder or to the POPS folder.

When copied to a VMC game folder, it’s used on the relative game only.

When copied to the POPS folder, it’s used on all the installed games.

- **What to do if you don’t want to overwrite your existing TROJAN_#.BIN/PATCH_#.BIN file :**

1. Change the number in the name of the file you want to copy ;

1. Open the file you want to copy with a hexadecimal editor, change the number in its header according to the one of the new file name ;

1. And finally copy the edited file.

POPStarter will refuse to load the PATCH/TROJAN file if the number in its filename doesn’t match the number in its header.

______________________________________________________________________________________________________________

## *IGR Textures:*

POPStarter has a built-in IGR loader texture making you able to change the japanese IGR screen with one of your language. Just drop the “IGR_BG.TM2”, “IGR_NO.TM2” and “IGR_YES.TM2” files into your POPS folder.

**Example :**

```
__common/POPS/IGR_BG.TM2
__common/POPS/IGR_NO.TM2
__common/POPS/IGR_YES.TM2
```

**Note :** .TM2 extension MUST be UPPERCASE for internal HDD – or it won’t work.

Some IGR textures made by the guys @[ASSEMbler](https://assemblergames.com/threads/ps2-pops-stuff.45347/). Kudos to them. Credits go to their original authors.

<table class="wiki"> <tbody><tr> <td> <strong>Preview</strong> </td> <td> <strong>Author</strong> </td> <td> <strong>Chinese</strong> </td> <td><strong>English</strong> </td> <td> <strong>French</strong> </td> <td> <strong>Spanish</strong> </td> <td> <strong>Polish</strong> </td> <td> <strong>Portuguese</strong> </td> <td> <strong>German</strong> </td> </tr> <tr> <td>  </td> <td> arkl1t32 </td> <td> – </td> <td> X </td> <td> X </td> <td> – </td> <td> X </td> <td> – </td> <td> – </td> </tr> <tr> <td>  </td> <td> arkl1t32 </td> <td> – </td> <td> X </td> <td> X </td> <td> – </td> <td> X </td> <td> – </td> <td> – </td> </tr> <tr> <td>  </td> <td> arkl1t32 </td> <td> – </td> <td> X </td> <td> X </td> <td> – </td> <td> X </td> <td> – </td> <td> – </td> </tr> <tr> <td>  </td> <td> arkl1t32 </td> <td> X </td> <td> X </td> <td> X </td> <td> – </td> <td> X </td> <td> X </td> <td> – </td> </tr> <tr> <td>  </td> <td> arkl1t32 </td> <td> – </td> <td> X </td> <td> X </td> <td> – </td> <td> X </td> <td> – </td> <td> – </td> </tr> <tr> <td>  </td> <td> gledson999 </td> <td> – </td> <td> X </td> <td> X </td> <td> – </td> <td> – </td> <td> X </td> <td> – </td> </tr> <tr> <td>  </td> <td> El_Patas (mod of gledson999’s) </td> <td> – </td> <td> X </td> <td> – </td> <td> – </td> <td> X </td> <td> – </td> <td> – </td> </tr> <tr> <td>  </td> <td> LopoTRI</td> <td> – </td> <td> X </td> <td> – </td> <td> – </td> <td> – </td> <td> – </td> <td> X </td> </tr> <tr> <td> <strong>Download links for language packs</strong> </td> <td> </td> <td> <strong><a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_textures_-_Chinese_pack.7z">Chinese</a></strong> </td> <td><strong><a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_textures_-_English_pack.7z">English</a></strong> </td> <td> <strong><a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_textures_-_French_pack.7z">French</a></strong> </td> <td> <strong><a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_textures_-_Spanish_pack.7z">Spanish</a></strong> </td> <td> <strong><a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_textures_-_Polish_pack.7z">Polish</a></strong> </td> <td> <strong><a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_textures_-_Portuguese_pack.7z">Portuguese</a></strong> </td> <td> <strong><a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/IGR_textures_-_German_Pack.7z">German</a></strong> </td> </tr> </tbody></table>

______________________________________________________________________________________________________________

## *“Exit to [name of app]” function :*

POPStarter has a built-in launcher added to the in-game reset function. It looks for mc0:/BOOT/BOOT.ELF then mc1:/BOOT/BOOT.ELF. If not found/invalid, it exits to the PS2 browser.

If you want to exit game to some app (uLE_kHn for example), name it BOOT.ELF and place it in the BOOT folder of your memory card.

______________________________________________________________________________________________________________

## *Related stuff :*

You may want to give a look at this :

- [IGR] [Make your own IGR textures](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr-textures)

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
