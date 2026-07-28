<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/version -->
<!-- primary snapshot: 20240907003621  |  3 captures, 1 distinct content version(s) -->
# version

# **POPStarter version**

______________________________________________________________________________________________________________

A tip to know what version of POPStarter you are using…

Open POPSTARTER.ELF file with a hex editor and look at offset $59 (blue on the picture the below the table) : it’s the **build date**. In red, starting at offset $5E is the **build ID**. With these two informations, you can determine what version you are currently using.

**Notes :**

- the build ID did not change from Beta 1 to Beta 7 (0×06) ;

- most protos have the same build ID (0xFE) :

- some protos doesn’t have a build date and build ID.

<table class="wiki"> <tbody><tr> <td> <strong>Version</strong> </td> <td> <strong>Build date YY YY MM DD (blue)</strong> </td> <td> <strong>Build ID (red)</strong> </td> </tr> <tr> <td> Rev 13 Beta <a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/20190605">20190605</a> (Final release) </td> <td> 20 19 06 05 </td> </tr> <tr> <td> Rev 13 Beta <a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/20190104">20190104</a> </td> <td> 20 19 01 04 </td> </tr> <tr> <td> Rev 13 Beta <a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/20180924">20180924</a> </td> <td> 20 18 09 24 </td> </tr> <tr> <td> Rev 13 Beta <a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/20180922">20180922</a> </td> <td> 20 18 09 22 </td> </tr> <tr> <td> Rev 13 Beta <a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/20180921">20180921</a> </td> <td> 20 18 09 21 </td> </tr> <tr> <td> Rev 13 Beta <a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/20180920">20180920</a> </td> <td> 20 18 09 20 </td> </tr> <tr> <td> Rev 13 RIP 06 </td> <td> 20 17 10 20 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 Prototype 9 </td> <td> 20 17 10 08 </td> <td> 0xFE </td> </tr> <tr> <td> Rev 13 Prototype 8 </td> <td> 20 17 10 03 </td> <td> 0xFE </td> </tr> <tr> <td> Rev 13 Prototype 7 </td> <td> 20 17 07 03 </td> <td> 0xFE </td> </tr> <tr> <td> Rev 13 Prototype 6 </td> <td> 20 17 06 24 </td> <td> 0xFE </td> </tr> <tr> <td> Rev 13 Prototype 5 </td> <td> 20 17 06 15 </td> <td> 0xFE </td> </tr> <tr> <td> Rev 13 Prototype 4 </td> <td> 20 17 05 31 </td> <td> 0xFE </td> </tr> <tr> <td> Rev 13 Prototype 3 </td> <td> 20 17 05 30 </td> <td> 0xFE </td> </tr> <tr> <td> Rev 13 Prototype 2 </td> <td> 00 00 00 00 </td> <td> 0×00 </td> </tr> <tr> <td> Rev 13 Prototype 1 </td> <td> 00 00 00 00 </td> <td> 0×00 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 17 </td> <td> 20 17 01 28 </td> <td> 0×11 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 16 </td> <td> 20 16 11 20 </td> <td> 0×10 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 15 </td> <td> 20 16 09 19 </td> <td> 0×0F </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 14 </td> <td> 20 16 07 23 </td> <td> 0×0E </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 13 </td> <td> 20 15 12 07 </td> <td> 0×0D </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 12 </td> <td> 20 15 11 24 </td> <td> 0×0C </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 11 </td> <td> 20 15 11 11 </td> <td> 0×0B </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 10 </td> <td> 20 15 10 26 </td> <td> 0×0A </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 9 </td> <td> 20 15 10 24 </td> <td> 0×09 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 8 </td> <td> 20 15 10 23 </td> <td> 0×08 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 7 </td> <td> 20 15 07 28 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 6 </td> <td> 20 15 07 27 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 5 </td> <td> 20 15 07 14 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 4 </td> <td> 20 15 07 13 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 3 </td> <td> 20 15 07 12 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 2 </td> <td> 20 15 06 25 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 WIP 06 Beta 1 </td> <td> 20 15 06 22 </td> <td> 0×06 </td> </tr> <tr> <td> Rev 13 WIP 05 </td> <td> 20 15 06 03 </td> <td> 0×05 </td> </tr> <tr> <td> Rev 13 WIP 04 </td> <td> 20 15 05 31 </td> <td> 0×04 </td> </tr> <tr> <td> Rev 13 WIP 03 </td> <td> 20 15 04 24 </td> <td> 0×03 </td> </tr> <tr> <td> <strong>Rev 13 WIP 02</strong> </td> <td> <strong>20 14 08 22</strong> </td> <td> <strong>0×02</strong> </td> </tr> <tr> <td> Rev 13 WIP 01 </td> <td> 20 14 07 11 </td> <td> 0×01 </td> </tr> </tbody></table>

**Example (pic below) :** this is Rev 13 WIP 2.

For the .KELF version, the build date starts at offset $29 and the build ID at offset $2E.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
