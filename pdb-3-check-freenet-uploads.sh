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
function name_md5 {
	echo $(md5sum <<<"${f##*/}" | tr -d ' -')
}
$vps_ssh_command $vps_ssh_connection_string find "'$vps_uploads_dir'" -type f -name "'*.7z*'" -printf "'%s %p\n'" | sort -k2 | while read size f
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

	pf=$(find "$local_packages_dir" -name "${BASH_REMATCH[1]}-in-progress.txt*")
	[[ $pf ]] || error could not find progress file
	log progress file: "$pf"
	pfiles["$pf"]=$(( ${pfiles["$pf"]} + 1 ))

	log name_md5: $(name_md5)

	echo "--------------------------------------------------
$(mydate) check-freenet-uploads session $session:
File: $f" >>"$pf"
	# TODO: fcp_script GetRequestStatus
	echo "
set -e
exec 3<>/dev/tcp/127.0.0.1/9481
echo -e 'ClientHello\nName=pdb-3-check-freenet-uploads.sh\nExpectedVersion=2.0\nEndMessage' >&3
echo -e 'GetRequestStatus\nIdentifier=$(name_md5)\nGlobal=true\nEndMessage' >&3
while [[ 1 ]]; do read -u3 -t3 x || break; echo \"\$x\"; lastx=\"\$x\"; done
[[ \"\$lastx\" == EndMessage ]] || { echo something was wrong with fcp: \$lastx; exit 1; }
echo -e 'Disconnect\nEndMessage' >&3
echo
" | tee -a "$pf" | $vps_ssh_command $vps_ssh_connection_string >>"$pf" 2>&1
	echo
done
if (( ${#pfiles[*]} == 0 ))
then
	echo no uploads found
	exit
fi
echo 'check-freenet-uploads session end
' | tee -a "${!pfiles[@]}"
# }}}

declare -i parts_count
declare status errors_found chk DataLength Succeeded Total LastProgress
function print_part_stats {
	local stats=
	[[ $DataLength ]] && stats+="size: $(( DataLength/1024/1024 )) Mb; "
	[[ $Succeeded && $Total ]] && stats+="ready: $(( Succeeded*100/Total ))%; "
	[[ $LastProgress ]] && stats+="LastProgress: $(( ($(date +%s) - LastProgress/1000)/60 )) minutes ago;"
	[[ $stats ]] && echo "part_stats: $stats"
	return 0
}
for pf in "${!pfiles[@]}" # {{{
do
	echo '##################################################'
	echo "$pf"
	parts_count=0
	status=freenet-upload
	unset errors_found chk DataLength Succeeded Total LastProgress
	exec 3<"$pf"
	while read -u3 -r x # {{{
	do
		if [[ "$x" =~ "check-freenet-uploads session $session" ]]; then
			print_part_stats
			parts_count+=1
			echo ---------- part $parts_count: ----------
			unset errors_found chk DataLength Succeeded Total LastProgress

		elif [[ $parts_count == 0 || ! "$x" ]]; then
			continue

		elif [[ "$x" == 'check-freenet-uploads session end' ]]; then
			break

		elif [[ "$x" =~ File:\ (.+) ]]; then
			f="${BASH_REMATCH[1]}"
			echo "$f"

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
			status=${status//-errors/}-errors
			echo error: "$x"

		elif [[ "$x" =~ URI=(CHK@.{43},.{43},AAMC--8) && ! $chk ]]; then
			chk="${BASH_REMATCH[1]}"
			let statistics[chk]+=1
			if grep -F "$chk" "$filelist_local" >/dev/null
			then
				let statistics[old-chk]+=1
				status+=-chk
				echo chk is already present in the file list

			else # update file list: {{{
				echo new chk found
				echo $(date +%T) calculating md5 "(can take long time ($(( DataLength/1024/1024 )) Mb))..."
				md5=$($vps_ssh_command $vps_ssh_connection_string md5sum "$(printf %q "$f")" | cut -b 1-32)
				echo $(date +%T) ok, updating file list...
				echo "# added at $(mydate) by $0" >>"$filelist_local"
				echo -e "files+=(\n  $(printf %q "${f##*/}")  $DataLength  $md5\n  $chk\n)" | tee -a "$filelist_local"
				echo >>"$filelist_local"
				rsync --progress --compress --timeout=10 -e "$vps_ssh_command" "$filelist_local" "$vps_ssh_connection_string:$filelist_vps"
				echo $(date +%T) ok, filelist updated,
				let statistics[new-chk]+=1
				status+=-newchk
				# }}}
			fi

		elif [[ "$x" =~ ^(DataLength|Succeeded|Total|LastProgress)= ]]; then
			eval $x

		elif [[ "$x" == PutSuccessful ]]; then
			echo upload done!
			{
				$vps_ssh_command $vps_ssh_connection_string mv -v "$(printf %q "$f")" "$vps_completed_dir"
				log package status: freenet-upload-$(name_md5)-done
				echo remove from freenet uploads...
				# TODO: fcp_script RemoveRequest ok
				$vps_ssh_command $vps_ssh_connection_string <<eof
set -e
exec 3<>/dev/tcp/127.0.0.1/9481
echo -e 'ClientHello\nName=pdb-3-check-freenet-uploads.sh\nExpectedVersion=2.0\nEndMessage' >&3
echo -e 'RemoveRequest\nIdentifier=$(name_md5)\nGlobal=true\nEndMessage' >&3
while [[ 1 ]]; do read -u3 -t3 x || break; echo "\$x"; lastx="\$x"; done
[[ "\$lastx" == EndMessage ]] || { echo something was wrong with fcp: \$lastx; exit 1; }
echo -e 'Disconnect\nEndMessage' >&3
echo ok
eof
			} 2>&1 | tee -a "$pf"
			let statistics[done]+=1
			status+=-done

		fi
	done # end of "while read $pf" loop }}}
	print_part_stats
	echo '====== package status: ======'
	log package status: $status | tee -a "$pf"
	echo
done
# }}}

function statnum {
	echo $(( statistics[$1]+0 ))
}
echo "**************************************************
script has finished successfully,
**************************************************
STATISTICS:
$(statnum files) files of size $(( statistics[files-size]/1024/1024 )) Mb, $(statnum started) started, $(statnum chk) chk-s, $(statnum errors) errors, $(statnum fatal) fatal,
during this check: $(statnum new-chk) new chk-s were added, $(statnum done) finished uploads were processed,
unrecognized files: $(statnum unrecognized-files) of size $(( statistics[unrecognized-files-size]/1024/1024 )) Mb
"

