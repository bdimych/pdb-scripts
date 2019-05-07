#!/bin/bash

# TODO: description,

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

echo "local_packages_dir is $local_packages_dir"
find "$local_packages_dir" -name '*in-progress.txt*' | while read pf
do
	f="${pf%-in-progress.txt*}.7z"
	[[ -e "$f" ]] && size="7z size $(( $(stat -c%s "$f")/1024/1024 )) Mb" || size='7z not found'
	echo "$(grep 'package status' "$pf" | tail -n1 | sed 's/LOG: package status: //'): ${pf##*/} ($size)"
done | sort -n | while read x
do
	if [[ "$x" =~ freenet-upload(-started-chk-done)+:\ (.*)\ \( ]]
	then
		cat <<eof
┌─────────
│ $x
│ freenet upload done, you can run: pdb-5-save-message-to-blockchain.sh $(printf %q "${BASH_REMATCH[2]}")
└─────────
eof
	elif [[ "$x" =~ message-saved:\ (.*)\ \( ]]
	then
		cat <<eof
╔═════════
║ $x
║ message is saved in the blockchain, you can run: pdb-6-check-and-mark-package-saved.sh $(printf %q "${BASH_REMATCH[1]}")
╚═════════
eof
	else
		echo "$x"
	fi
done

