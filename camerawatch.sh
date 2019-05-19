#!/bin/bash
#fotos kommen ca alle 2 sek
let tpicdelta=2
#maximal 30s zusammenfassen (->15 bilder)
let tdeltamax=5

cd /home/pi/FTP/C1-Lite_E8ABFA8CC679/snap

mypidfile=/opt/fhem/camerawatch.sh.pid
inotifypidfile=/var/run/inotify_camerawatch.pid
#trap "rm -f '$mypidfile’" 2
echo $$ > "$mypidfile"
let numpix=0
let delta=0
declare -a apix
declare -a adat
#do not pipe but read via file descriptor
#and establish inotifywait as background process
#so we may take a break from reading/processing its output
exec 3< <(inotifywait -m -e create  /home/pi/FTP/C1-Lite_E8ABFA8CC679/snap & echo $! &)
# the first thing being output into our file redirection 
# will be the pid of inotifywait
# so we do our first read to get that
read -t 2 <&3 $T bla
# dump the pid to a pidfile
# without buffering it. in case it matters 
# note so self: it doesn't. (reading back the old pid of a previous run from the pid file
# was due to placing the trap instruction before writing the (new) pid file)
# who could have guessed that trap instructions get prepared (in full) before they are
# executed. Hint: I didn't.
stdbuf -i0 -o0 echo $bla > "$inotifypidfile"

#modified shutdown of spawned inotify.
#to be more selective (only kill ours)
#we need to break out of two loops to achieve clean exit
#todo: change hardcoded name of pid file to variable
trap "kill -15 `stdbuf -i0 -o0 cat /var/run/inotify_camerawatch.pid`; rm -f '$mypidfile'; rm -f '$inotifypidfile'; break 2;" SIGINT SIGTERM
  
#read from file descriptor with timeout
#afterwards, process (eventual) output of inotifywait
{ while true; do
   while read -t $tdeltamax <&3 $T path action file; do
	adat[$numpix]=`date +%s`
        echo "adat[$numpix] is now ${adat[$numpix]}"
        #save path/name of file
        apix[$numpix]=$path$file
        echo "apix[$numpix] is now ${apix[$numpix]}"
	#inc counter
        (( numpix ++ ))
        #echo "numpix is now $numpix"
	logger "The file '$file' appeared in directory '$path' via '$action'"
	echo "The file '$file' appeared in directory '$path' via '$action'"
   done
   echo "Terminate read loop because of timeout (or failed read, subprocess may be dead)."
   #do we have pictures?
   if [ "$numpix" -gt 0 ];
   then
	echo "Processing $numpix pictures.."
	echo ${apix[$numpix]}
	#concatenate string of filenames
	unset namestr
	(( numpix -- ))
	for i in `seq 0 $numpix`
	do
	   echo "${apix[$i]}"
	   namestr="$namestr ${apix[$i]}"
	done
	echo "built string of filenames: $namestr"
	`montage -adjoin -depth 8 -quality 20 -geometry '1x1+0+0<' $namestr /var/tmp/composite.jpg`
	mv /var/tmp/composite.jpg /opt/fhem/www/snapshots/composite.jpg
	chmod a+r /opt/fhem/www/snapshots/composite.jpg
	logger "sending notification to fhem about composite image"
	token=$(curl -s -D - 'http://localhost:8083/fhem?XHR=1' | awk '/X-FHEM-csrfToken/{print $2}')
        curl --data "fwcsrf=$token" "http://localhost:8083/fhem?cmd=setreading%20OUT.Bewegung%20current_file%20/var/tmp/composite.jpg"
	
	#echo "doing detection magic"
	#cd /home/pi/ncsdk/ncappzoo/apps/security-cam
	#numpix has already been dec'd
	#for i in `seq 0 $numpix`
	#do
	#   echo "${apix[$i]}"
	#   logger "Calling NCS security-cam script for person detection"
	#   python3 security-cam.py -t 20 -i ${apix[$i]}
	#   #exit codes: 
	   #0 -> normal execution , no person detected
	   #1 -> error, image file not found
	   #2 -> person detected
	   #if exit codes indicates having detected a person -> give a heads-up to fhem
	   #fhem will handle pushover to subscribed clients by watching the reading change
	#   if [ $? -eq 2 ]
	#   then
	#        logger "Person found. notifying fhem."
	#	curl --data "fwcsrf=$token" "http://localhost:8083/fhem?cmd=setreading%20OUT.Bewegung%20detection_file%20/var/tmp/detection.jpg"	
	#   fi
	#done
   fi
   unset apix
   unset adat
   let numpix=0
done }
