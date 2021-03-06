
function mydate { date +%F-%T; }
function log { echo -e $(mydate): LOG: "$@"; }
function error { echo -e $(mydate): ERROR: "$@"; exit 1; }
function warning { echo -e $(mydate): WARNING: "$@"; }

function _tee_progress {
	if [[ $copy_progress_files_to ]]
	then
		tee -i -a "$pf" "$copy_progress_files_to/${pf##*/}"
	else
		tee -i -a "$pf"
	fi
}
function tee_progress {
	if [[ $2 == yes ]]
	then
		local pf
		case "$1" in
		*-in-progress.txt) pf="$1";;
		*) pf="${1%.7z}-in-progress.txt";;
		esac
		_tee_progress
	else
		echo -n | tee_progress "$1" yes || error tee_progress failure
		trap 'sleep 1' EXIT # for tee delay
		exec > >(tee_progress "$1" yes) 2>&1 || error tee_progress failure
	fi
}

perl_print_downloads_in_plain_text='if (/<div id="content">/../priority_bottom/) {s/^\s*//; s/\n/ /; /identifier-/ && s/^/\n/; s/<.*?>//g; print} END {print "\n"}'

