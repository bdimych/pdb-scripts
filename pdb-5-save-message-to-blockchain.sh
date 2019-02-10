#!/bin/bash

# TODO: description,

set -e

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

[[ $1 ]] || error usage: ${0##*/} progress-file.txt
pf="$(find "$local_packages_dir" -name "$1")"
[[ $pf ]] || error progress file not found

log progress file "$pf"
tee_progress "$pf"
echo
echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
log $0 started

echo
log get message data from the beginning of the progress file:
eval "$(sed -n -e '/^pdb_message=/,/^archive_md5=/p; /^archive_md5=/q' "$pf")"
declare -p pdb_message pdb_message_encrypted pdb_message_encrypted_md5 archive_name archive_size archive_md5

exit

actions:
OK -get messages plain and encrypted,
	OK -in pdb-1 make assignments block appropriate for eval "$(sed -n -e '//,//p')",
-get all file parts CHK links,
-print both messages,
-ask if to publish or not to publish password,
	-if yes then ask to confirm to print something more difficult than just y/n,
-if publish then:
	-get password,
	-check 7z t -p$p $f
	-add password:$p in the end of the message,

and that's it:
-ask one more time to confirm,
-run Mike's script - https://ethlance.com/#/job-proposal/1099
-print transaction ID,
-print new package status,


