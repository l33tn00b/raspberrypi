#!/usr/bin/python3
# this script periodically checks blink's servers via the API for new videos
# if there are new videos, they will be downloaded and stored for later processing 
# via the Movidius Neural Compute Stick.

# ideally, it is to be used in conjunction with a startup script (blinkwatch.sh) that 
# does some housekeeping for use as a daemon

# the startup script is to be called at startup via /etc/init.d/blinkwatch 
# (which may also be used to control shutdown / restart)

from blinkpy import blinkpy
from blinkpy.helpers.util import (http_req, merge_dicts)
from blinkpy.api import request_video_count
from datetime import datetime
from requests.structures import CaseInsensitiveDict
import sys
import argparse
import time


def checkVideoCount(blink, headers):
	# checks for the toal number of videos saved on blink's servers
	# this will be used as an indicator for initiating download
	# although we'll have to combine it with some other indicator
	# because there is the option of automatically deleting older videos
	# from the servers
	# returns a dict with one entry (key 'count' to access the number of videos) 
	return request_video_count(blink, headers)

def buildDictLastRecord(blink):
	# build dictionary with camera names as keys
	# containing date of latest video recorded by that camera
	# we don't use this function in our script.
	dictLastRecord = dict()
	for name, camera in blink.cameras.items():
		dictLastRecord[name] = camera.attributes['last_record'][0]
	return dictLastRecord

def doDownload(blink, clipName, oPath):
	# performs download of specified video clip and saves it to disk
	# gets blink instance (because of auth headers) as parameter blink
	# gets name of the video clip as parameter clipName
	# gets path to place downloaded videos to as parameter oPath
	response = http_req(blink,"https://prod.immedia-semi.com"+clipName,headers=blink.auth_header, stream=False, json_resp=False, is_retry=False)
	#print(response.status_code)
	# response with status code 200 is what we want.
	# anything else is no good...
	if response.status_code == 200:
		# extract account id, network id and camera id from clip name
		# account is after 4th slash
		# network is after 6th slash
		# camera is after 8th slash 
		idAccount = clipName.split("/")[4]
		idNetwork = clipName.split("/")[6]
		idCamera = clipName.split("/")[8]
		idClip = clipName.split("/")[9]
		#print(idAccount)
		#print(idNetwork)
		#print(idCamera)
		#print(idClip)
		# open file for binary write
		# we don't exactly care if there is a file already 
		file = open(oPath + "/" + idAccount + "_" + idNetwork + "_" + idCamera + "_" + idClip, "wb")
		file.write(response.content)
		file.close()
	else:
		print("No valid server response. Does the video exist?")

def getVideoAllSyncMod(blink):
	# takes blink instance as parameter blink
	# relies on sync modules having been updated (so as to contain 
	# up to date information regarding available videos
	# will return a dictionary with camera names as keys
	# items of the dict are lists containing dictionaries.
	# sounds funny?
	# {'CAM1':[{'clip':'path_to_clip', 'thumb':'path_to_thumb'},{'clip':'path_to_clip', 'thumb':'path_to_thumb'},... ], 'CAM2':[]}
	# we don't use this function in this script.
	# leftover
	# from my perspective, it is much easier to just do stuff manually
	# instead of using blinkpy
	# call it a lack of documentation and time for digging through the code to 
	# understand what gets cached and what not...
	combined = CaseInsensitiveDict({})
	for sync in blink.sync:
		combined = merge_dicts(combined, blink.sync[sync].videos)
	return combined

def syncModVideoDict2List(videoDict):
	# takes a dict containing the videos (see getVideoAllSyncMod)
	# and dumps all videos/clips into one big list 
	# basically, this is first dumping the dictionary keys (and the information which camera created the clip)
	# we don't use this function in our download script.
	# it is a leftover...
	videoList = []
	for key in videoDict:
		videoList = videoList + videoDict[key]
	# we now have this:
	# [{'clip':'path_to_clip', 'thumb':'path_to_thumb'},{'clip':'path_to_clip', 'thumb':'path_to_thumb'}]
	# and want to get rid of the 'thumb' parts
	# so it will just be a flat list of paths to video clips
	videoList2 = []
	for item in videoList:
		videoList2 = videoList2 + [item['clip']]
	return videoList2

def getFirstVideoPage(blink):
	# takes blink instance as parameter (because we need auth header)
	# gets first page of video list
	# which makes for 10 videos
	# returns a list which contains dicts with video clip information
	response = http_req(blink,"https://prod.immedia-semi.com/api/v2/videos/page/0",headers=blink.auth_header, stream=False, json_resp=True, is_retry=False)
	return response

def convertVideoPage2ID(videopage):
	# takes a result from getFirstVideoPage
	# extracts video ids from it and returns them as a list 
	# makes for easier comparing of new vs. old video list
	l = []
	for d in videopage:
		l = l + [d['id']]
	return l


def main():
	# blinkpy sometimes is a bit too complicated
	# wo we chiefly use it for login/authentication
	# and do things manually (because it is faster like that)
	# and frankly, I didn't understand what's going on behind the scenes
	# of blinkpy due to a lack of documentation...
	# do basic setup (as per blinkpy doc) 
	print("Starting up..")
	blink = blinkpy.Blink(username=ARGS.user, password=ARGS.password, refresh_rate=ARGS.refresh)
	blink.start()
	print("Startup done.")
	# do first check for number of videos 
	# so we have a baseline to compare against
	prevVideoCount = checkVideoCount(blink, headers=blink.auth_header)['count']
	print("Initial number of videos: " + str(prevVideoCount))
	#datetime_object = datetime.strptime(dictLastRecord['ObourgFront'], '%Y_%m_%d__%I_%M%p')
	#print(datetime_object)
	print("Getting reference for (previously) existing videos...")
	prevIDFirstVideoPage = convertVideoPage2ID(getFirstVideoPage(blink))
	
	# our default refresh rate for connecting to blink's servers is 60 seconds
	# since we don't have anything else to do, we'll just relax
	print("Starting periodic check for new videos...")
	while True:
		# sleep a bit longer than our chosen (or default) refresh rate
		# so we'll have blinkpy module poll for an update when we wake up 
		blink.refresh(force_cache=True)
		videoCount = checkVideoCount(blink, headers=blink.auth_header)['count']
		print("Current number of videos: " + str(videoCount))
		if videoCount != prevVideoCount :
			# change in the number of videos
			# get the first page from blink's servers
			currFirstVideoPage = getFirstVideoPage(blink)
			# extract IDs from the page
			currIDFirstVideoPage = convertVideoPage2ID(currFirstVideoPage)
			# look for new element(s)
			temp3 = [x for x in currIDFirstVideoPage if x not in prevIDFirstVideoPage]
			print("New Video Clips with IDs:")
			print(temp3)
			# and download clips
			for vID in temp3:
				# get dataset for specified ID
				tvt= next(item for item in currFirstVideoPage if item['id'] == int(vID))
				print("Getting Video Clip: " + tvt['address'])
				# download clip to specified output directory
				doDownload(blink,tvt['address'],ARGS.output)
			# establish new reference
			prevIDFirstVideoPage = currIDFirstVideoPage
			prevVideoCount = videoCount
		# relax...
		time.sleep(ARGS.refresh + 1)


# ---- Define 'main' function as the entry point for this script -------------

if __name__ == '__main__':
	parser = argparse.ArgumentParser(
				description="Blink Video Download Script.")

	parser.add_argument( '-o', '--output', type=str,
				default='/var/tmp/blinkwatch',
				help="Absolute path to place downloaded videos." )

	parser.add_argument( '-u', '--user', type=str,
				default="",
				required=True,
				help="User Name for Login (usually your Email Address).")
	
	parser.add_argument( '-p', '--password', type=str,
				default="",
				required=True,
				help="Password for Login.")

	parser.add_argument( '-r', '--refresh', type=int,
				default=60,
				help="Refresh after X seconds. Default is 60. Use with caution so as not to overwhelm the API.")
						 
	ARGS = parser.parse_args()
	
	main()
