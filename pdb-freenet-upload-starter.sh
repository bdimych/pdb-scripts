#!/bin/bash

# {{{
# purpose: automatically upload files from specified directory,

# TODO: useful commands
# }}}

lockname=/tmp/${0##*/}.lock
[[ -e $lockname ]] && { echo $(date) $0: script is already running; exit 1; }
mkdir -v $lockname || { echo $(date) $0: could not create lock directory; exit 1; }
trap "rmdir -v $lockname" EXIT

node_ip=127.0.0.1
updir=/home/???/frd/uploads
file_max_size=5G # see man find and man split
uploads_max_size=8100200300
sleep=100

function mydate { date +%F-%T; }
function log { echo $(mydate): LOG: "$@"; }
function error { echo $(mydate): ERROR: "$@"; }
function warning { echo $(mydate): WARNING: "$@"; }
function sleep { log sleep $1; echo; command sleep $1; }

logfile=pdb-freenet-upload-starter-log.txt
tempfile=pdb-freenet-upload-starter-tmp.txt

if ! cd "$updir"
then
	error cd updir failed
	exit 1
fi
# TODO: archive log files
exec >>$logfile 2>&1
echo -e '\n\n\n\n\n'
echo ====================================================================================================
log $0 started

while [[ 1 ]]
do
	[[ $notfirst ]] && sleep $sleep
	notfirst=1

	echo ==================================================

	# wget uploads {{{
	if ! wget -O $tempfile http://$node_ip:8888/uploads/?fproxyAdvancedMode=1
	then
		warning wget uploads failed
		continue
	fi
	sed -i -e 's/^[[:blank:]]*//' $tempfile || continue # no space left is possible
	grep failed-upload $tempfile && warning failed uploads found
	grep '^STARTING$' $tempfile && continue # when upload is STARTING freenet doesn't do anything else
	if ! perl -ne 'if ((/<form.+uncompleted/../form>/) && /size-\d+".+value="(\d+)"/) {print "$&\n"; $sum+=$1; exit 1 if $sum > '$uploads_max_size'}' <$tempfile
	then
		warning uploads_max_size exceeded
		continue
	fi
	# }}}

	# split big files {{{
	while read f
	do
		warning split big file
		ls -l "$f"
		if ! split --verbose -b $file_max_size -d "$f" "$f". # TODO: ?compare md5sum? or not necessary?
		then
			warning split failed
			continue 2
		fi
		rm -v "$f"
		ls -l "$f"*
	done < <(find . -type f -size +$file_max_size -name '*.7z')
	# }}}

	# check and start uploads {{{
	while read f
	do
		name_md5=$(md5sum <<<"${f##*/}" | tr -d ' -')
		log name_md5: "$f": $name_md5
		# get upload status: {{{
		{ echo "
ClientHello
Name=pdb-freenet-upload-starter
ExpectedVersion=2.0
EndMessage

GetRequestStatus
Identifier=$name_md5
Global=true
EndMessage
"; command sleep 3; echo -e '\nDisconnect\nEndMessage'; } | nc -v -w 30 $node_ip 9481 >$tempfile 2>&1 || { warning fcp conversation failed; cat $tempfile; continue; }
		# }}}
		if grep -C3 'PutFailed\|Fatal=true' $tempfile
		then
			echo
			warning upload failed - restart
			# remove upload and it will be restarted: {{{
			{ echo "
ClientHello
Name=pdb-freenet-upload-starter
ExpectedVersion=2.0
EndMessage

RemoveRequest
Identifier=$name_md5
Global=true
EndMessage
"; command sleep 3; echo -e '\nDisconnect\nEndMessage'; } | tee -a /dev/fd/2 | nc -v -w 30 $node_ip 9481 || warning fcp conversation failed
			# }}}
			continue 2
		elif grep PersistentPut $tempfile
		then
			log file is already added
			continue
		fi
		echo
		log start upload "$f"
		# start upload: {{{
		# TODO: before ClientPut make TestDDARequest or check freenet.ini flag "Assume that upload DDA is allowed" is set,
		{ echo "
ClientHello
Name=pdb-freenet-upload-starter
ExpectedVersion=2.0
EndMessage

ClientPut
Identifier=$name_md5
Filename=$f
UploadFrom=disk
MaxRetries=10
PriorityClass=4
URI=CHK@
DontCompress=true
Global=true
Persistence=forever
EarlyEncode=true
EndMessage
"; command sleep 3; echo -e '\nDisconnect\nEndMessage'; } | tee -a /dev/fd/2 | nc -v -w 30 $node_ip 9481 || warning fcp conversation failed
		# }}}
		continue 2
	done < <(find "$updir" -type f -name '*.7z*' | grep -v '.7z.part$')
	# }}}

done

