#!/bin/bash

# TODO: description,

set -e

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

[[ $1 ]] || error usage: ${0##*/} progress-file.txt
if [[ -f "$1" && "$1" =~ -in-progress.txt$ ]]
then
	pf="$1"
else
	pf="$(find "$local_packages_dir" -name "$1")"
fi
[[ $pf ]] || error progress file not found

log progress file: "$pf"
tee_progress "$pf"
echo
echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
log $0 started

echo get message data...
eval "$(sed -n -e '/^pdb_message=/,/^archive_md5=/p; /^archive_md5=/q' "$pf")"
declare -p pdb_message pdb_message_encrypted pdb_message_encrypted_md5 archive_name archive_size archive_md5 >/dev/null
echo ok

echo get chk links...
source "$filelist_local"
frd_array="$(grep -Po 'CHK@.{43},.{43},AAMC--8' "$pf" | sort -u | while read chk
do
	found=
	for (( i = 0; i < ${#files[*]}; i++ ))
	do
		if [[ "$chk" == "${files[i]}" ]]
		then
			echo "${files[i-3]} ${files[i-2]} ${files[i-1]} $chk"
			found=1
		fi
	done
	[[ $found ]] || error chk not found in the file list 1>&2
done | sort)"
[[ $frd_array ]] || error something went wrong
echo ok

echo "----- your pdb message: -----
$pdb_message

----- message for blockchain: -----
$frd_array
$pdb_message_encrypted
"

read -p 'do you want to make this message public (publish the password) (y|N)? ' x
if [[ $x == y ]]
then
	echo ARE YOU REALLY SURE YOU WANT TO MAKE THIS MESSAGE PUBLIC?
	read -p 'please type 5 first letters of encrypted message to confirm: ' x
	[[ ${#x} == 5 && "$pdb_message_encrypted" =~ ^$x ]] || exit 1
	echo
	append_password=1
	echo get and check password...
	set -x
	password=$(echo "${archive_name%.7z}" | bash "$password_script")
	7z t -p$password "${pf%-in-progress.txt}.7z" >/dev/null
	diff -s <(echo "$pdb_message") <(base64 -d <<<"$pdb_message_encrypted" | $openssl_command -d -pass pass:$password | bunzip2)
	set +x
	echo ok
fi

exit

actions:
OK -get messages plain and encrypted,
	OK -in pdb-1 make assignments block appropriate for eval "$(sed -n -e '//,//p')",
OK -get all file parts CHK links,
OK -print both messages,
OK -ask if to publish or not to publish password,
	OK -if yes then ask to confirm to print something more difficult than just y/n,
OK -if publish then:
	OK -get password,
	OK -check 7z t -p$p $f
	OK -check encrypted message

and that's it:
-ask one more time to confirm,
	-print something more "epic" than simple confirmation because it will be saved forever without any chance to fix,
-run Mike's script - https://ethlance.com/#/job-proposal/1099
-print transaction ID,
-print new package status,


