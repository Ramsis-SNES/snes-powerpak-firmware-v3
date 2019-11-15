# SNES PowerPak Firmware v3 "MUFASA"

This is an unofficial firmware for RetroUSB's (unfortunately discontinued) [SNES PowerPak](http://www.retrousb.com/product_info.php?cPath=24&products_id=84) flash cart.

It offers several advantages over the stock v1.0X firmware:
* A more stable user interface with more intuitive joypad button mapping, on-screen button hints, and (where appropriate) context-sensitive help.
* Better performance thanks to a unified software design that takes advantage of the SNES CPU's 16-bit capabilities.
* Up to 56 characters per file name are displayed in the file browser thanks to the SNES's horizontal hi-res mode. (Up to 123 file name characters are actually compared when trying to auto-match an SRM file to a chosen ROM, and stored into the LASTGAME.LOG file.)
* ROM mapping is more interactive in special cases. This allows you to load and play most beta/prototype ROMs without having to hex-edit their -- often non-existent -- internal headers first.
* The SPC player actually works. ;-) It presents itself to you as a "window" overlay onto the file browser, has a timer-based auto-play feature for convenience, and takes you right back to where you were once you decide to quit listening.
* A settings menu allows you to reconfigure your PowerPak at any time, completely without the hassle of editing files on the CF card using a computer.
* Full theme support, i.e. with a bit of skill and effort, you can easily customize the UI to your very own liking. Or, just resort to using any of the themes bundled within this release package. :D
* In-system update flashing.
* Tons of bugs and glitches found in the stock firmware have been fixed or worked around for the most stable, reliable, and convenient user experience possible.
* Optionally randomize all SNES RAM content before booting a game ROM (an especially handy feature for SNES homebrew developers).
* ... and more! :-)

For installation instructions and more information, please check [How To Use.txt](https://github.com/Ramsis-SNES/snes-powerpak-firmware-v3/blob/master/How%20To%20Use.txt).

To learn about my other projects, feel free to visit my [homepage](https://manuloewe.de).

Have fun, and long live the SNES PowerPak! :-)
