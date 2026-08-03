<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/ps1-special-devices -->
<!-- primary snapshot: 20170629113655  |  6 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/ps1-special-devices/: 20200812190036, 20240324023529 -->
# ps1-special-devices

# [PS1 devices] **Use your [special device : light gun…] with POPS**

______________________________________________________________________________________________________________
*[Original tutorial by AKuHAK]* [@ASSEMblergames](http://assemblergames.com/l/threads/ps2-pops-stuff.45347/page-56#post-794781)

**1.** Find a PS2 game that supports your special device and look inside its content;

**2.** Look for some IRX files;

**3.** First file that you need is SIO2MAN.IRX. You need this module for making other modules working;

**4.** Copy it into POPS folder and rename as MODULE_0.IRX;

**5.** Then search for your specific IRX files. It can be one file or multiple files. For light gun, it might be USBD.IRX and USBGUN.IRX;

**6.** Rename them as MODULE_1.IRX, MODULE_2.IRX, ... etc. You have to experiment to find the correct order. For light gun, first .IRX might be USBD.IRX and second .IRX USBD.IRX;

**7.** Copy these files into POPS folder and run your game. If you got special device to work – have fun!

**8.** If you have no luck – you can copy specific IOPRPxxx.IMG from your game into POPS folder and rename it as IOPRP252.IMG. In such way, you have to delete POPS.PAK and use only POPS.ELF + IOPRP252.IMG.

**9.** If it still doesnt work, you can also try to add more modules from your game (repeat 6th step) or you can try to change modules order.

**Notes :**

- Don’t forget that USB devices may not work if you use POPS in USB mode.

- These manipulations doesn’t mean that you will be able to use all special functions. It only means that your device will be recognized properly (so all standard functions will work).

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
