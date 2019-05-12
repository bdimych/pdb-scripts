#!/bin/bash

# TODO: description,

set -e -o pipefail

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

echo "$vps_ssh_command $vps_ssh_connection_string"
$vps_ssh_command $vps_ssh_connection_string "
$(declare -p \
	vps_freenet_dir \
	vps_freenet_downloads_dir \
	vps_frd_dir \
	vps_uploads_dir \
	vps_completed_dir \
	perl_print_downloads_in_plain_text | sed 's/--/-x/'
)
$(sed -ne '/^# === begin/,/^# === end/p' "$0")
[[ ${#*} == 0 ]] && exec bash
$*
"

exit

# === begin vps-side script === {{{

function ph {
	echo "
pdb commands:
+------------------------------------+
| ph - this help,                    |
| p1 - completed downloads,          |
| p2 - free/occupied space,          |
| p3 - frd-log errors and warnings,  |
| p3% - with progress,               |
| p4 - freenet uploads/downloads,    |
| p5 - freenet node technical stats, |
+------------------------------------+
	"
}

function p1 {
	echo completed downloads sorted by date:
	echo -----------------------------------
	cat $vps_frd_dir/frd-completed.txt | perl -ne '/\((.+?)\) '\''(.+?)'\'' /; $x{$2}=$1; END {for (keys %x) {print "$x{$_} $_\n"}}' | sort
}

function p2 {
	local y x="$vps_freenet_dir $vps_freenet_downloads_dir $vps_frd_dir $vps_uploads_dir $vps_completed_dir"
	echo free space:
	echo -----------
	df -h $x | sort -ur
	echo --------------------
	echo size of directories:
	echo --------------------
	for y in $x
	do
		du -sh $y
	done
}

function p3 {
	echo show frd-log errors and warnings$( [[ $1 ]] && echo ' and progress' ):
	echo ---------------------------------
	grep -i -P "check file|err|warn$( [[ $1 ]] && echo '|%$|ago$|download complete|start download' )" $vps_frd_dir/frd-log-*.txt | less
}
function p3% { p3 1; }

function p4 {
	echo freenet uploads:
	echo ----------------
	curl -Ss http://127.0.0.1:8888/uploads/?fproxyAdvancedMode=1 | perl -ne "$perl_print_downloads_in_plain_text"
	echo ------------------
	echo freenet downloads:
	echo ------------------
	curl -Ss http://127.0.0.1:8888/downloads/?fproxyAdvancedMode=1 | perl -ne "$perl_print_downloads_in_plain_text"
}

function p5 {
	curl http://127.0.0.1:8888/stats/?fproxyAdvancedMode=2 | perl -ne '
		s/^\s+|<.+?>//g;
		s/&nbsp;/ /g;
		if (/opennetSizeEstimate|nodeUptime|^(Input|Output) Rate|Session Total|Payload Output|Global Total/) {print}
	'
}

# TODO: less frd/frd-log-*.txt frd/uploads/pdb-freenet-upload-starter-log.txt - view in one terminal splitted - how? vim?

# TODO: statistics about files - total count, total size, too-long-ago count,

ph
export -f ph p{1..5} p3%

# === end === }}}

