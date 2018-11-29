#!/bin/bash

# {{{
# purpose: automatically upload files from specified directory,

# TODO: useful commands
# }}}

# TODO: check single instance

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
	if ! wget -O $tempfile http://$node_ip:8888/uploads/
	then
		warning wget uploads failed
		continue
	fi
	sed -i -e 's/^[[:blank:]]*//' $tempfile || continue # no space left is possible
	grep failed-upload $tempfile && warning failed uploads found
	if ! perl -n -e 'if (/<input.+name="size-\d+".+value="(\d+)"/) {print "$&\n"; $sum+=$1}; END {print "sum=$sum\n"; exit 1 if $sum > '$uploads_max_size'}' <$tempfile
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

	# start upload {{{
	while read f
	do
		name_md5=$(md5sum <<<"$f" | tr -d ' -')
		log name_md5: "$f": $name_md5
		if grep $name_md5 $tempfile
		then
			log file is already present
			continue
		fi
		log start upload "$f"
		{
			echo -e '\nClientHello\nName=pdb-freenet-upload-starter\nExpectedVersion=2.0\nEndMessage\n'
			command sleep 1
			# TODO: before ClientPut make TestDDARequest or check "Assume that upload DDA is allowed" is set,
			echo -e "\nClientPut\nIdentifier=$name_md5\nFilename=$f"
			echo -e 'UploadFrom=disk\nMaxRetries=10\nPriorityClass=4\nURI=CHK@\nDontCompress=true\nGlobal=true\nPersistence=forever\nEarlyEncode=true\nEndMessage\n'
			command sleep 1
			echo -e '\nDisconnect\nEndMessage\n'
			command sleep 1
		} | tee -a /dev/fd/2 | nc -v -w 30 $node_ip 9481 || warning fcp conversation failed
		continue 2
	done < <(find "$updir" -type f -name '*.7z*')
	# }}}

done

