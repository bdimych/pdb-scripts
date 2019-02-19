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
	ls -lh "${pf%-in-progress.txt}.7z"
	:
	: testing archive can take long time...
	7z t -p$password "${pf%-in-progress.txt}.7z" >/dev/null
	: ok
	:
	diff -s <(echo "$pdb_message") <(base64 -d <<<"$pdb_message_encrypted" | $openssl_command -d -pass pass:$password | bunzip2)
	set +x
	echo ok
fi

echo "
----- final confirmation: -----

ok,
so,
You are going to save the message which You can see above to the ??? blockchain,

$(
if [[ $append_password ]]
then
	echo 'You also chose to publish the password for decryption so everyone will be able to read the message and view archive contents,'
else
	echo 'You did not choose to publish the password so Your information will stay private until You decide to give the password to someone else,'
fi
)

and now You have the last chance to think well and make the final decision because after saving You will not be able to modify or delete information from blockchain,
Your message will exist while human civilization will use this blockchain or keep it as historical artefact,

so,
"
read -p '??? are You sure (y|N) ??? ' x
[[ $x == y ]] || exit 1
echo
read -p "??? please type today's date exactly as on the following line: ???
$(LANG=C date +'The year XXXX, %B, the day XX, %A')
" x
[[ "$x" == "$(LANG=C date +'The year %Y, %B, the day %d, %A')" ]] || exit 1
echo
read -p 'and the very final confirmation and this time is really 100% all done:
are You ready to enter the history (y|N)?

                    ' x
[[ $x == y ]] || exit 1
echo

echo ok, let\'s do it,

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
OK -ask one more time to confirm,
	OK -print something more "epic" than simple confirmation because it will be saved forever without any chance to fix,
-run Mike's script - https://ethlance.com/#/job-proposal/1099
-print transaction ID,
-print new package status,


