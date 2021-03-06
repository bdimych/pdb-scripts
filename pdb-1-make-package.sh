#!/bin/bash

# (triple curly brackets are for folding for jEdit)
# description: {{{
# - input: directory + text message,
# - result: encrypted archive + encrypted message = "pdb package",

# password for encryption is made from the name of directory so it is possible:
# - give access selectively for one package,
# - or give the algorithm and thus give access to all packages,
# }}}

set -e

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

srcdir="${1%/}"
ls -lhtr "$srcdir" || error usage: ${0##*/} source-directory
(( $(stat -c%s "$srcdir/pdb-message.txt") > 40 )) || error pdb-message.txt is absent or too short
cd "$srcdir"
echo ------------
echo pdb-message:
echo ------------
cat pdb-message.txt
echo ------------

packagename="$(basename "${PWD%"$saved_suffix"}")-$(date +%y%m%d-%H%M)"
read -p "start make package \"$packagename\" (y|N) ? " x
[[ $x == y ]] || exit
echo
log "script started $0"
log "PWD is $PWD"
echo

password=$(echo "$packagename" | bash "$password_script")
check_password || error check password failed

set -x
: =================================== make and test archive: ======================================= # {{{
:
mkdir -pv packaged
cd packaged
ln -vs .. "$packagename"
7z a -p$password -mhe=on -mx=0 -l '-xr!packaged' "$packagename.7z" "$packagename"
ls -lh "$packagename.7z"
7z t -pxxx "$packagename.7z" && exit 1
7z t -p$password "$packagename.7z"
rm -v "$packagename"
md5_archive=$(md5sum "$packagename.7z" | cut -b 1-32)
# }}}
:
: ================================== encrypt and test message: ===================================== # {{{
:
encrypted_msg="$(bzip2 -v <../pdb-message.txt | $openssl_command -pass pass:$password | base64 -w0)"
md5_encrypted_msg=$(md5sum <<<"$encrypted_msg" | tr -d ' -')
diff -s --brief ../pdb-message.txt <(base64 -d <<<"$encrypted_msg" | $openssl_command -d -pass pass:xxx | bunzip2) && exit 1
diff -s --brief ../pdb-message.txt <(base64 -d <<<"$encrypted_msg" | $openssl_command -d -pass pass:$password | bunzip2)

set +x
# }}}

echo
tee_progress "$packagename"
echo "====================================================================================================
=============== Package \"$packagename\" has been created: =============== {{{
====================================================================================================

package created at $(mydate):
working directory: $PWD:
$(
du -sh .. --exclude packaged
find .. -printf '%-10u %-10g %M %10s %TY-%Tm-%Td %.8TT %y%Y ' -and '(' -type l -printf '%p -> %l\n' -or -printf '%p\n' ')' | sort -k5
)

====================================================================================================

ARCHIVE:
$(ls -l "$packagename.7z"):
-----
$(7z l -p$password "$packagename.7z")

====================================================================================================

MESSAGE:
$(ls -l ../pdb-message.txt):
-----
pdb_message=\"\$(cat <<___eof___
$(< ../pdb-message.txt)
___eof___
)\"
pdb_message_encrypted=$encrypted_msg
pdb_message_encrypted_md5=$md5_encrypted_msg
archive_name=$(ls --quoting-style shell "$packagename.7z")
archive_size=$(stat -c%s "$packagename.7z")
archive_md5=$md5_archive

====================================================================================================
}}}
"
# TODO: ??? above "printf %q" instead of "ls --quoting-style" ???
# TODO: show memorable ascii art text box
echo SUCCESS!
echo package has been created:
ls -lh --quoting-style shell "$(realpath "$packagename.7z")"
echo
log package status: package-created
echo
echo now you can run pdb-2-upload-to-vps.sh
echo

