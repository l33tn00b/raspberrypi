#!/usr/bin/env python
# this is for the "master" controlling a remote pi
# we need pigpio installed
# we need gpiozero installed
# so: 
# sudo apt-get install python-pip
# sudo pip install pigpio
# sudo pip install gpiozero
#
# on the remote pi:
# Enable Remote GPIO on the Pi in the Raspberry Pi Configuration Tool.
# Run the pigpio daemon on the Pi: sudo pigpiod

# on the local pi:
# need to have environment variables set
# i.e.
# GPIOZERO_PIN_FACTORY=pigpio
# PIGPIO_ADDR=192.168.3.34
from gpiozero import LED
from signal import pause
from gpiozero.pins.pigpio import PiGPIOFactory
# broadcom numbbering is default
# playing dumb. hardcoded address.
factory = PiGPIOFactory(host='192.168.3.34')
led = LED(18, pin_factory=factory)
led.on()  # inverted logic
pause()
