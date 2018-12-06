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
declare -A pfiles
$vps_ssh_command $vps_ssh_connection_string find "'$vps_uploads_dir'" -type f -name "'*.7z*'" | while read f
do
	echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'
	log file "$f"
	f="${f##*/}"
	name_md5=$(md5sum <<<"$f" | tr -d ' -')
	log name_md5 $name_md5
	[[ "$f" =~ ^(.+)\.7z ]]
	base="${BASH_REMATCH[1]}"
	pf=$(find "$local_packages_dir" -name "$base-in-progress.txt")
	[[ $pf ]] || error could not find progress file
	log progress file "$pf"
	pfiles["$pf"]=1
	echo "--------------------------------------------------
$(mydate) check-freenet-uploads session $session:" >>"$pf"
	echo "
set -e
exec 3<>/dev/tcp/127.0.0.1/9481
echo -e 'ClientHello\nName=pdb-3-check-freenet-uploads.sh\nExpectedVersion=2.0\nEndMessage' >&3
echo -e 'GetRequestStatus\nIdentifier=$name_md5\nGlobal=true\nEndMessage' >&3
while [[ 1 ]]; do read -u3 -t1 x || break; echo \"\$x\"; done
echo -e 'Disconnect\nEndMessage' >&3
echo
" | tee -a "$pf" | $vps_ssh_command $vps_ssh_connection_string >>"$pf" 2>&1
done
echo

for pf in "${!pfiles[@]}"
do
	echo "${pf##*/}"
	status=freenet-upload$(sed -n "/check-freenet-uploads session $session/,\$p" "$pf" | perl -ne '
		if (/check-freenet-uploads session/) {$status{parts}++}
		elsif (/Started=true/) {$status{started}++}
		elsif (/Fatal=true/) {$status{fatal}++}
		elsif (/URI=CHK@.{43},.{43},AAMC--8/) {$status{chk}++}
		elsif (/error/i && ! /^\w*Filename=/) {$status{error}++}
		END {for $k (qw(parts started chk error fatal)) {print "-$k($status{$k})" if $status{$k}}}
	')
	log package status: $status'\n' | tee -a "$pf"
done

