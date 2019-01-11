# raspberrypi
stuff i need and do

blink.py: 
Demo script for using blinkpy package
See https://github.com/fronzbot/blinkpy for more information

blinkwatch, blinkwatch.sh and blinkdownload.py:
Monitor Blink servers for new videos, download. blinkwatch is the startup script (/etc/init.d), blinkwatch.sh is the housekeeping daemon and blinkdownload.py does the actual checking and downloading.

camerawatch, camerawatch.sh:
Checking local filesystem (which gets filled by ftp upload from a security cam) for new files. Gives heads-up to my home automation server (fhem) and hands new pictures over to Movidius Neural Compute Stick handling script for detection of persons.

ssh_fail:
How to set QoS for sshd. In case ssh sessions keep hanging after displaying password prompt. This happens in combination with some switches (Netgear?!?).

boot_from_sd_external_root:
How to keep the SD card for starting up RPi while at the same time moving the root file system to an external hdd/ssd.
