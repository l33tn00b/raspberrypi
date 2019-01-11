#!/bin/bash

# this script gets started as a daemon by /etc/init.d/blinkwatch
# 
# shebang wasn't interpreted correctly, trying to run this script 
# with sh instead of bash sucks..

# think of this script as doing the housekeeping work I didn't want to 
# do in the python download script (keeping track of PID, shutdown,..)  

# we'll put downloaded videos to /var/tmp/blinkwatch
# for later processing via Neural Compute Stick 
# to check for presence of persons
# since we don't care about the cat walking around or some car passing by.
# note to self: no space before/after equal sign when using let
storagedir="/var/tmp/blinkwatch"

if [ ! -d "$storagedir" ]; then
  # make directory if it doesn't exist
  mkdir -p $storagedir
fi
mypidfile=/var/run/blinkwatch.sh.pid
# caveat: not used in all cases (sometimes name is hardcoded)
inotifypidfile=/var/run/inotify_blinkwatch.pid

# create PID file (so control script /etc/init.d/blinkwatch may do its work)
#echo $$ > "$mypidfile"

# note to self: 
# do not insert spaces before/after equal sign when setting variables using let
# avoid let for sh compatibility.
# but declare -a breaks it anyway...
tdeltamax=5
numpix=0
delta=0
declare -a apix
declare -a adat
# do not pipe but read via file descriptor
# and establish inotifywait as background process
# so we may take a break from reading/processing its output
exec 3< <(inotifywait -m -e create  $storagedir & echo $! &)  
# the first thing being output into our file redirection 
# will be the pid of inotifywait
# so we o our first read to get that
read -t 2 <&3 $T bla
# dump the pid to a pidfile
# without buffering it. in case it matters 
# note so self: it doesn't. (reading back the old pid of a previous run from the pid file
# was due to placing the trap instruction before writing the (new) pid file)
# who could have guessed that trap instructions get prepared (in full) before they are
# executed. Hint: I didn't.
stdbuf -i0 -o0 echo $bla > "$inotifypidfile"
#echo "created pidfile for inotifywait"
#echo "pid is `cat $inotifypidfile`"

# if we get killed/shutdown, do housekeeping
# note to self:
# shell programming wtf...
# trap instruction needs to be placed after creating the pid file
# else we'll _always_ read back an old pid (if the file still exists)
# another wtf:
# break _must_ appear at the end.
# might seem logical, but wasn't to me. After all, I need to break the loop(s) first before soing something else.
# todo: change hard coded  pid file name to var
trap "echo Booh!; echo `stdbuf -i0 -o0 cat $inotifypidfile`; kill -15 `stdbuf -i0 -o0 cat /var/run/inotify_blinkwatch.pid`; rm -f '$mypidfile'; rm -f '$inotifypidfile'; break 2" SIGINT SIGTERM

#process results from inotifywait
#read from file descriptor with timeout
#afterwards, process (possible) output of inotifywait
{ while true; do
   while read -t $tdeltamax <&3 $T path action file; do
        #save path/name of file
        apix[$numpix]=$path$file
        #echo "apix[$numpix] is now ${apix[$numpix]}"
	#inc counter
        (( numpix ++ ))
        #echo "numpix is now $numpix"
	#echo "The file '$file' appeared in directory '$path' via '$action'"
   done
   #echo "Terminate read loop because of timeout (or failed read, subprocess may be dead)."
   #do we have files?
   # guess what, this has just been adapted from processing pictures...
   if [ "$numpix" -gt 0 ];
   then
	#echo "Processing $numpix files.."
	echo ${apix[$numpix]}
	# fhem is running on the same machine
	token=$(curl -s -D - 'http://localhost:8083/fhem?XHR=1' | awk '/X-FHEM-csrfToken/{print $2}')
	#concatenate string of filenames
	#unset namestr
	(( numpix -- ))
	for i in `seq 0 $numpix`
	do
	 # give heads up to fhem regarding new video clip  
	 echo "${apix[$i]}"
	   curl --data "fwcsrf=$token" "http://localhost:8083/fhem?cmd=setreading%20OUT.Bewegung%20current_video%20${apix[$i]}"
	done
   fi
   let numpix=0
done }

