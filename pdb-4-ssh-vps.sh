#!/bin/bash

source "$(dirname "$(realpath "$0")")/pdb-config.sh"

$vps_ssh_command $vps_ssh_connection_string "
$(declare -p \
	vps_freenet_dir \
	vps_freenet_downloads_dir \
	vps_frd_dir \
	vps_uploads_dir \
	vps_completed_dir | sed 's/--/-x/'
)
$(sed -ne '/^# === begin/,/^# === end/p' "$0")
"

exit

# === begin vps-side script === {{{

function ph {
	echo "
pdb commands:
+-----------------------------------+
| ph - this help,                   |
| p1 - completed downloads,         |
| p2 - free/occupied space,         |
| p3 - frd-log errors and warnings, |
| p4 - freenet uploads/downloads,   |
+-----------------------------------+
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
	echo show frd-log errors and warnings:
	echo ---------------------------------
	grep -i -P 'check file|err|warn' $vps_frd_dir/frd-log-*.txt | less
}
function p4 {
	local x='if (/Totals/..0) {s/<.*?>//g; s/^\s*//; s/\n/ /; s/(low)/\n\1/; print}'
	echo freenet uploads:
	echo ----------------
	curl http://127.0.0.1:8888/uploads/ | perl -ne "$x"
	echo ------------------
	echo freenet downloads:
	echo ------------------
	curl http://127.0.0.1:8888/downloads/ | perl -ne "$x"
}
ph
export -f ph p{1..4}
exec bash

# === end === }}}


