from blinkpy import blinkpy
from blinkpy.helpers.util import http_req
from io import BytesIO
import sys
# do basic setup (as per blinkpy doc) 
blink = blinkpy.Blink(username='YOUR USERNAME HERE', password='YOUR PASSWORD HERE', refresh_rate=30)
blink.start()

# now, access camera properties of all cameras registered with sync modules 
# that are set up under the previously used account for signing in
# blink.cameras is a dict
# accessing  items() of a dict:
# items():  Return a new view of the dictionary’s items ((key, value) pairs). 
# See the documentation of view objects.
# reference: https://docs.python.org/3/library/stdtypes.html#typesmapping
print("getting cameras...")
for name, camera in blink.cameras.items():
	#print("Camera Name " + " " + name)  	# Name of the camera
	#print(type(camera.attributes))
	#print(camera.attributes)      		# Print available attributes of camera
	for itemname, data in camera.attributes.items():
		if itemname != "last_record":
			print('{:<23}'.format(itemname) + '{:<20}'.format(data))
		else:
			print('{:<23}'.format(itemname) + str(data))
	print("")

#camera = blink.cameras['SOME CAMERA NAME']
#camera.snap_picture()       # Take a new picture with the camera
#blink.refresh()             # Get new information from server
#camera.image_to_file('/local/path/for/image.jpg')
#camera.video_to_file('/local/path/for/video.mp4')


# get events from sync modules linked to account
# these are things like arming, disarming, boot, heartbeat to blink's servers
print("getting events...")
for name, syncmod in blink.sync.items():
	#print("Sync Module" + " " + name)
	print("All times are GMT.")
	# get_events() gives a list of dictionaries
	# i.e. each element in the list of events is a dictionary
	# [ {event1}, {event2}, ... ]
	#print(syncmod.get_events())
	for event in syncmod.get_events():
		print('{:<20}'.format(event['type']) + '{:<20}'.format(event['created_at']))
	# syncmod.get_videos() gives a dict with camera names as keys and
	# a list of dicts containing video information i.e.
	# [ {dict for video 1}, {dict for video 2},... ]
	# the video dictionaries contain two keys each: 'clip' and 'thumb'
	for cam,item in syncmod.get_videos(0,1).items():
		print(cam)
		print(item)
		# this will keep the path to the first video of the last cam
		# just for later downloading 
		videopath = item[0]['clip']
print("")
#print(videopath)

# finally, get a video from the video list (not the last cached video available via
# video_to_file() but another one from the list of videos obtained from get_videos()
# and dump the contents to a file
file = open("resp.mp4", "wb")
response = http_req(blink,"https://prod.immedia-semi.com"+videopath,headers=blink.auth_header, stream=False, json_resp=False, is_retry=False)
print(response.status_code)
file.write(response.content)
file.close()
