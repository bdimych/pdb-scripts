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
$vps_ssh_command $vps_ssh_connection_string find "'$vps_uploads_dir'" -type f -name "'*.7z*'" -printf "'%s %p\n'" | while read size f
do
	echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'
	log file: "$f"
	log size: $size
	if ! [[ "$f" =~ .+/(.+)\.7z($|\.[0-9][0-9]$) ]]
	then
		let statistics[unrecognized-files]+=1
		let statistics[unrecognized-files-size]+=$size
		warning skip unrecognized name
		continue
	fi
	let statistics[files]+=1
	let statistics[files-size]+=$size

	pf=$(find "$local_packages_dir" -name "${BASH_REMATCH[1]}-in-progress.txt")
	[[ $pf ]] || error could not find progress file
	log progress file: "$pf"
	pfiles["$pf"]=1

	name_md5=$(md5sum <<<"${f##*/}" | tr -d ' -')
	log name_md5: $name_md5

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
declare status errors_found chk DataLength Succeeded Total LastProgress
function print_part_stats {
	local stats=
	[[ $DataLength ]] && stats+="size: $(( DataLength/1024/1024 )) Mb; "
	[[ $Succeeded && $Total ]] && stats+="ready: $(( Succeeded*100/Total ))%; "
	[[ $LastProgress ]] && stats+="LastProgress: $(( ($(date +%s) - LastProgress/1000)/60 )) minutes ago;"
	[[ $stats ]] && echo "$stats"
	return 0
}
for pf in "${!pfiles[@]}"
do
	echo '##################################################'
	echo "$pf"
	parts_count=0
	parts_done=0
	status=freenet-upload
	unset errors_found chk DataLength Succeeded Total LastProgress
	cat "$pf" | while read -r x
	do
		if [[ "$x" =~ "check-freenet-uploads session $session" ]]; then
			print_part_stats
			parts_count+=1
			echo ---------- part $parts_count: ----------
			unset errors_found chk DataLength Succeeded Total LastProgress

		elif [[ $parts_count == 0 ]]; then
			continue

		elif [[ "$x" =~ File:\ (.+) ]]; then
			f="${BASH_REMATCH[1]}"
			echo file: "$f"

		elif [[ "$x" == 'CodeDescription=No such identifier' ]]; then
			let statistics[not-yet-added]+=1
			status+=-pending

		elif [[ "$x" == 'Started=true' ]]; then
			let statistics[started]+=1
			status+=-started

		elif [[ "$x" == 'Fatal=true' ]]; then
			let statistics[fatal]+=1
			status+=-fatal
			echo fatal error

		elif perl -ne '!/^\w*Filename=/ && /error|PutFailed|Description/i || exit 1' <<<"$x"; then
			errors_found=1
			let statistics[errors]+=1
			status+=-errors
			echo error: "$x"

		elif [[ "$x" =~ URI=(CHK@.{43},.{43},AAMC--8) && ! $chk ]]; then
			chk="${BASH_REMATCH[1]}"
			# TODO: get ssh md5sum - add file to files.txt - and rsync files.txt to vps
			let statistics[chk]+=1
			status+=-chk
			echo chk found

		elif [[ "$x" =~ ^(DataLength|Succeeded|Total|LastProgress)= ]]; then
			eval $x

		elif [[ "$x" == PutSuccessful ]]; then
			# TODO: ssh mv from uploads dir to completed dir
			let statistics[done]+=1
			status+=-done
			parts_done+=1
			echo upload done!

		fi
	done
	print_part_stats
	if [[ $parts_count == $parts_done ]]
	then
		:
		# TODO: ??? what to do if all parts done ???
	fi
	# TODO: calculate progress
	echo '====== package status: ======'
	log package status: $status | tee -a "$pf"
	echo
done

declare -p statistics
# TODO: print statistics

