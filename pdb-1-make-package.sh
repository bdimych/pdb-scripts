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

source "${0%/*}/pdb-config.sh"
source "${0%/*}/pdb-lib.sh"

srcdir="${1%/}"
ls -lh "$srcdir" || error usage: ${0##*/} source-directory
(( $(stat -c%s "$srcdir/pdb-message.txt") > 40 )) || error pdb-message.txt is absent or too short
cd "$srcdir"
packagename="$(basename "${PWD%"$saved_suffix"}")-$(date +%y%m%d-%H%M%S)"

echo
read -p "start make package \"$packagename\" (y|N) ? " x
[[ $x == y ]] || exit
echo
log "script started $0"
log "PWD is $PWD"
echo

password=$(echo "$packagename" | bash "$password_script")
password_check || error password check failed

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
openssl='openssl aes-256-cbc -nosalt'
encrypted_msg="$(bzip2 -v <../pdb-message.txt | $openssl -pass pass:$password | base64 -w0)"
md5_encrypted_msg=$(md5sum <<<"$encrypted_msg" | tr -d ' -')
diff -s --brief ../pdb-message.txt <(base64 -d <<<"$encrypted_msg" | $openssl -d -pass pass:xxx | bunzip2) && exit 1
diff -s --brief ../pdb-message.txt <(base64 -d <<<"$encrypted_msg" | $openssl -d -pass pass:$password | bunzip2)

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
find .. -printf '%-10u %-10g %M %10s %TY-%Tm-%Td %.8TT %y%Y ' -and '(' -type l -printf '%p -> %l\n' -or -printf '%p\n' ')' | sort -k8
)

====================================================================================================

archive:
$(ls -l "$packagename.7z"):
-----
$(7z l -p$password "$packagename.7z")

====================================================================================================

pdb message:
$(ls -l ../pdb-message.txt):
-----
$(< ../pdb-message.txt)
-----

====================================================================================================

message for blockchains:
-----
$(ls -Q --quoting-style shell "$packagename.7z")  $(stat -c%s "$packagename.7z")  $md5_archive
add-chk-here
$encrypted_msg
-----
(you can check encrypted message md5sum: $md5_encrypted_msg)

====================================================================================================
}}}
"
echo ok, package "\"$packagename\"" has been created,
echo now you can run pdb-start-upload script.
echo
log package status: package-created
echo

