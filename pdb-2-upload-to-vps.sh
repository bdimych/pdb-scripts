#!/bin/bash

# TODO: description,

set -e

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

file="$1"
[[ -f "$file" && -s "$file" && "$file" == *.7z ]] || error usage: ${0##*/} file.7z

tee_progress "$file"

# check parameters: {{{

echo "==========
$0 started at $(mydate)
==========
"
grep -m1 uploaded-to-vps "${file%.7z}-in-progress.txt" && error file is already uploaded
ls -lh "$file"
echo "
upload can take long time depending on file size and connection speed,
(you can stop it by pressing Ctrl+C and later resume it by running the same command again),
"
read -p 'start upload (y|N)? ' x
[[ $x == y ]] || exit

echo
read -s -p 'please enter your vps ssh password: ' SSHPASS
echo
export SSHPASS
$vps_sshpass_command $vps_ssh_connection_string echo ssh connection ok || error ssh connection failed

echo
log 'calculating md5 (can take long time)...'
file_md5=$(md5sum "$file" | cut -b 1-32)
grep $file_md5 "$filelist_local" && error md5 $file_md5 is already present in the local file list
grep -m1 $file_md5 "${file%.7z}-in-progress.txt" || error md5 is absent in the progress file
echo ok,

# }}},

# upload: {{{

# if connection breaks then rsync process should probably stop but it doesn't stop and can interfere with other rsync-s - see google "rsync ssh timeout doesn't work"
# simple workaround is to kill all rsync-s,
# (maybe newer rsync versions will work as expected),
function kill_rsyncs {
	$vps_sshpass_command $vps_ssh_connection_string killall -v rsync || [[ 1 ]]
}
vpsfile="$vps_uploads_dir/$(printf %q "${file##*/}")"
trap 'error INT signal caught' INT
for i in {1..10}
do
	kill_rsyncs
	sleep 3
	log package status: uploading-to-vps
	rsync -vv --append-verify --outbuf=N --progress --timeout=30 -e "$vps_sshpass_command" "$file" "$vps_ssh_connection_string:$vpsfile.part" && break
	[[ $i == 10 ]] && error upload failed $i retries
	warning rsync failed, retry in 1 minute...
	sleep 60
done
sleep 3
kill_rsyncs

# }}},

log 'verifying md5 (can take long time)...'
$vps_sshpass_command $vps_ssh_connection_string md5sum "$vpsfile.part" | grep $file_md5 || error md5 check failed
log md5 is ok,
$vps_sshpass_command $vps_ssh_connection_string mv -v "$vpsfile{.part,}" || error rename .part failed
log rename is ok,
echo
echo file has been uploaded successfully,
# TODO: show memorable ascii art text box,
# TODO: and print recommendations what to do next,
echo
log package status: uploaded-to-vps
echo
echo now you can run pdb-3-check-freenet-uploads.sh
echo

