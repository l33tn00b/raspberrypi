Doesn't exist anymore (post deleted):
 https://www.reddit.com/r/pushover/comments/6p9eov/how_to_pushover_notifications_for_your_apc_ups/

# Running nut on a Raspberry:
- sudo apt-get install nut
- /etc/nut/nut.conf: ```MODE=netserver```
- /etc/nut/ups.conf: comment out ```maxretry = 3```, create section 
```[UPSKeller]
  driver = usbhid-ups
  port = auto
  desc = "whatever"```
- /etc/nut/upsd.conf:
```LISTEN 192.168.3.222```
- /etc/nut/upsd.users:
```
[local_mon]
        password = <whatever>
        #allowfrom = localhost
        upsmon master

#this one ("secret") is not a joke. it is for the synology disk station
[monuser]
        password = secret
        upsmon slave
        #allowfrom = localnet
```
- /etc/nut/upsmon.conf
```
MONITOR UPSKeller@localhost 1 local_mon <whatever> master
```

# Monitoring from a Disk Station
you may use nut as another option to check on your ups from a diskstation
