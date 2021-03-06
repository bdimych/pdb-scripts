#!/bin/bash

# TODO: description,

set -e

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

[[ $1 ]] || error usage: ${0##*/} progress-file.txt
if [[ "$1" =~ -in-progress.txt$ ]]
then
	if [[ -f "$1" ]]
	then
		pf="$1"
	else
		pf="$(find "$local_packages_dir" -name "$1")"
	fi
fi
[[ $pf ]] || error progress file not found

log progress file: "$pf"
tee_progress "$pf"
echo
echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
log $0 started

grep -m1 'package status: message-saved' "$pf" && error message is already saved
# TODO: check if package has been uploaded and if not then ask user to confirm to save now or postpone, (grep freenet-upload(-started-chk-done)+)

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

message_for_blockchain="$frd_array
$pdb_message_encrypted"

echo "----- your pdb message: -----
$pdb_message

----- message for blockchain: -----
$message_for_blockchain
"

read -p 'do you want to make this message public (append the password) (y|N)? ' x
if [[ $x == y ]]
then
	echo are you really sure you want to make this message public?
	read -p 'please type 2 last letters of encrypted message: ' x
	[[ ${#x} == 2 && "$pdb_message_encrypted" =~ $x$ ]] || { echo wrong answer $x; exit 1; }
	echo ok,
	echo
	append_password=1
	echo ----- get and check password: -----
	set -x
	password=$(echo "${archive_name%.7z}" | bash "$password_script")
	ls -lh "${pf%-in-progress.txt}.7z"
	:
	: testing archive can take long time...
	7z t -p$password "${pf%-in-progress.txt}.7z" >/dev/null
	: ok
	:
	diff -s <(echo "$pdb_message") <(base64 -d <<<"$pdb_message_encrypted" | $openssl_command -d -pass pass:$password | bunzip2)
	message_for_blockchain+="
$password"
	set +x
	echo ok,
else
	echo no,
fi

echo "
----- CONFIRMATION: -----

ok,
so,

You are going to save your message to the $blockchain_name blockchain,

$(
if [[ $append_password ]]
then
	echo 'you also have chosen to PUBLISH the password so everyone will be able to read the message and view archive contents,'
else
	echo 'you have chosen NOT to publish the password so the message will remain private until you decide to give the password to someone else,'
fi
)

and now you have the last chance to think well and to make the final decision because !AFTER SAVING INFORMATION TO THE BLOCKCHAIN NOBODY WILL BE ABLE TO MODIFY OR DELETE IT!,
your message will exist while human civilization will use this blockchain or will keep it as historical artefact,

so,
"
function notyet { echo not yet.; exit 1; }
read -p '!!! are you sure (y|N) ??? ' x
[[ $x == y ]] || notyet
echo yes,
read -p "!!! please type today's date exactly as on the following line:
$(LANG=C date +'The year XXXX, %B, the day XX, %A')
" x
[[ "$x" == "$(LANG=C date +'The year %Y, %B, the day %d, %A')" ]] || notyet
echo ok,
read -p 'and the very final confirmation:
save message for history (y|N)?

              ' x
[[ $x == y ]] || notyet
echo yes,
echo

echo ok, "let's" do it:
log ===== save-message-script start =====
echo "$message_for_blockchain" | bash "$save_message_script"
log ===== save-message-script end =====

# TODO: print big ascii art banner
echo okay, the message has been saved,
echo
log package status: message-saved
echo
echo now you can run pdb-6-check-and-mark-package-saved.sh $(printf %q "${pf##*/}")
echo

