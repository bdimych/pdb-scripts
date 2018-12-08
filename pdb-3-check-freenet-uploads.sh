#!/bin/bash

# TODO: description,

set -e -o pipefail

source "${0%/*}/pdb-config.sh"
source "${0%/*}/pdb-lib.sh"

read -s -p 'please enter ssh password: ' SSHPASS
echo
export SSHPASS

session=$(date +%s)
log check-freenet-uploads session $session
shopt -s lastpipe
declare -A pfiles statistics

# get current uploads information: {{{
$vps_ssh_command $vps_ssh_connection_string find "'$vps_uploads_dir'" -type f -name "'*.7z*'" | while read f
do
	let statistics[uploads-files-count]+=1
	echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'
	log file: "$f"
	f="${f##*/}"
	name_md5=$(md5sum <<<"$f" | tr -d ' -')
	log name_md5: $name_md5
	[[ "$f" =~ ^(.+)\.7z ]]
	base="${BASH_REMATCH[1]}"
	pf=$(find "$local_packages_dir" -name "$base-in-progress.txt")
	[[ $pf ]] || error could not find progress file
	log progress file: "$pf"
	pfiles["$pf"]=1
	echo "--------------------------------------------------
$(mydate) check-freenet-uploads session $session:
File: $f" >>"$pf"
	echo "
set -e
exec 3<>/dev/tcp/127.0.0.1/9481
echo -e 'ClientHello\nName=pdb-3-check-freenet-uploads.sh\nExpectedVersion=2.0\nEndMessage' >&3
echo -e 'GetRequestStatus\nIdentifier=$name_md5\nGlobal=true\nEndMessage' >&3
while [[ 1 ]]; do read -u3 -t1 x || break; echo \"\$x\"; done
echo -e 'Disconnect\nEndMessage' >&3
echo
" | tee -a "$pf" | $vps_ssh_command $vps_ssh_connection_string >>"$pf" 2>&1
	echo
done
echo
# }}}

declare -i parts_count parts_done
declare -A part_progress
declare errors_found chk
for pf in "${!pfiles[@]}"
do
	echo '##################################################'
	echo "${pf##*/}"
	parts_count=0
	parts_done=0
	cat "$pf" | while read -r x
	do
		if [[ "$x" =~ "check-freenet-uploads session $session" ]]; then
			parts_count+=1
			echo -------------------- part $parts_count: ---------------------
			part_progress=()
			errors_found=
			chk=

		elif [[ $parts_count == 0 ]]; then
			continue

		elif [[ "$x" =~ File:\ (.+) ]]; then
			f="${BASH_REMATCH[1]}"
			echo file: "$f"

		elif [[ "$x" == 'CodeDescription=No such identifier' ]]; then
			let statistics[not-yet-added]+=1
			echo not yet added to uploads

		elif [[ "$x" == 'Started=true' ]]; then
			let statistics[started]+=1
			echo upload started

		elif [[ "$x" == 'Fatal=true' ]]; then
			let statistics[fatal]+=1
			echo upload fatal error

		elif perl -ne '!/^\w*Filename=/ && /error/i || exit 1' <<<"$x"; then
			errors_found=1
			let statistics[errors]+=1
			echo upload error found: "$x"

		elif [[ "$x" =~ URI=(CHK@.{43},.{43},AAMC--8) && ! $chk ]]; then
			chk="${BASH_REMATCH[1]}"
			# TODO: get ssh md5sum - add file to files.txt - and rsync files.txt to vps
			let statistics[chk]+=1
			echo chk found

		elif [[ "$x" =~ ^(DataLength|Succeeded|Total|LastProgress)=(.+) ]]; then
			part_progress[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}

		elif [[ "$x" == PutSuccessful ]]; then
			# TODO: ssh mv from uploads dir to completed dir
			let statistics[upload-done]+=1
			parts_done+=1
			echo upload done

		fi
	done
	if [[ $parts_count == $parts_done ]]
	then
		:
		# TODO: ??? what to do if all parts done ???
	fi
	# TODO: calculate progress
	# TODO: print status to $pf
	echo
done

declare -p statistics
# TODO: print statistics

