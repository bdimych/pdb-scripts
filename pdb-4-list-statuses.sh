#!/bin/bash

# TODO: description,

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

find "$local_packages_dir" -name '*in-progress.txt*' | while read pf
do
	f="${pf%-in-progress.txt*}.7z"
	[[ -e "$f" ]] && size="$(( $(stat -c%s "$f")/1024/1024 )) Mb" || size='7z not found'
	echo "$(grep 'package status' "$pf" | tail -n1 | sed 's/LOG: package status: //'): <${pf##*/}> ($size)"
done | sort -n | while read x
do
	echo "$x"
	if [[ "$x" =~ freenet-upload-(started-chk-done)+ ]]
	then
		echo ready to save
		# TODO: ssh grep md5 completed.txt
	fi
done

