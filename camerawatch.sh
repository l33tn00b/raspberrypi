#!/bin/bash
#this is bash! not sh!
#timeout after 5s (cam snaps every 2s when motion is detected)
let tdeltamax=5
#go to directory where pictures are stored
cd /home/pi/ftp/C1-Lite_XXXXX/snap
#setup pid file
mypidfile=/opt/fhem/camerawatch.sh.pid
#trap "rm -f '$mypidfile’" 2
#uh-oh. maybe this is a bit too robust a way of shutting down our spawned bg processes
#wil also kill other inotifies which may not be ours...
#we need to break out of two loops to achieve clean exit
trap "break 2; killall -9 inotifywait; rm -f '$mypidfile'" SIGINT SIGTERM
#write pid
echo $$ > "$mypidfile"
#number of pictures taken until timeout (no more pictures from cam)
let numpix=0
#array for pictures
declare -a apix
#array for creation time stamp (not used, relict from old version)
declare -a adat
#do not pipe but read via file descriptor
#and establish inotifywait as background process
#so we may take a break from reading/processing its output
exec 3< <(inotifywait -m -e create  /home/pi/ftp/C1-Lite_XXXXXXX/snap)
#read from file descriptor with timeout
#afterwards, process (possible) output of inotifywait
#group this, so we may access variables after loop completion (because of timeout)
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
        #dec counter (array starts at 0)
        (( numpix -- ))
        for i in `seq 0 $numpix`
        do
           echo "${apix[$i]}"
           namestr="$namestr ${apix[$i]}"
        done
        echo "built string of filenames: $namestr"
        #call imagemagick's montage to assemble pictures
        `montage -adjoin -depth 8 -quality 20 -geometry '1x1+0+0<' $namestr /var/tmp/composite.jpg`
        #get fhem csrf token
        token=$(curl -s -D - 'http://localhost:8083/fhem?XHR=1' | awk '/X-FHEM-csrfToken/{print $2}')
        #and post to fhem dummy as a reading
        curl --data "fwcsrf=$token" "http://localhost:8083/fhem?cmd=setreading%20OUT.Bewegung%20current_file%20/var/tmp/composite.jpg"
        echo "doing detection magic"
         cd /home/pi/ncsdk/ncappzoo/apps/security-cam
         #numpix has already been dec'd
         for i in `seq 0 $numpix`
         do
            echo "${apix[$i]}"
            python3 security-cam.py -t 20 -i ${apix[$i]}
            #exit codes: 
            #0 -> normal execution , no person detected
            #1 -> error, image file not found
            #2 -> person detected
            #if exit codes indicates having detected a person -> give a heads-up to fhem
            #fhem will handle pushover to subscribed clients by watching the reading change
            if [ $? -eq 2 ]
            then
               curl --data "fwcsrf=$token" "http://localhost:8083/fhem?cmd=setreading%20OUT.Bewegung%20detection_file%20/var/tmp/detection.jpg"	
            fi
         done
   fi
   unset apix
   unset adat
   let numpix=0
done }
