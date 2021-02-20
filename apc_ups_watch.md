Doesn't exist anymore (post deleted):
 https://www.reddit.com/r/pushover/comments/6p9eov/how_to_pushover_notifications_for_your_apc_ups/

# Running nut on a Raspberry:
- sudo apt-get install nut
- /etc/nut/nut.conf: ```MODE=netserver```
- /etc/nut/ups.conf: comment out ```maxretry = 3```, create section 
```
# do not change this name ("ups")
# synology's stupid interface does not accept any other name
# wtf.
[ups]
  driver = usbhid-ups
  port = auto
  desc = "whatever"
```
- load driver
```
upsdrvctl start
```
- may want to check comms: 
```
upsc ups@localhost
```
- /etc/nut/upsd.conf:
```
# this one is for external clients (i.e. disk station)
# we need to specify our ip here?!?
LISTEN 192.168.3.222
# this one is for local clients
LISTEN localhost
LISTEN 127.0.0.1
```
- /etc/nut/upsd.users:
```
[local_mon]
        password = <whatever>
        upsmon master

# this one ("secret") is not a joke. it is for the synology disk station
[monuser]
        password = secret
        upsmon slave
```
- /etc/nut/upsmon.conf
```
MONITOR ups@localhost 1 local_mon <whatever> master
```

# Monitoring from a Disk Station
you may use nut as another option to check on your ups from a diskstation
- Enable monitoring another non-local UPS: Hardware / Energy in System Options
- Enter IP of NUT server 
- Be sure to have set the appropriate credentials ("monuser"/"secret") and UPS name ("ups")
