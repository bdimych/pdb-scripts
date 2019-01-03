
function mydate { date +%F-%T; }
function log { echo -e $(mydate): LOG: "$@"; }
function error { echo -e $(mydate): ERROR: "$@"; exit 1; }
function warning { echo -e $(mydate): WARNING: "$@"; }

function tee_progress {
	if [[ $2 == yes ]]
	then
		local f="${1%.7z}-in-progress.txt"
		if [[ $copy_progress_files_to ]]
		then
			tee -i -a "$f" "$copy_progress_files_to/${f##*/}"
		else
			tee -i -a "$f"
		fi
	else
		echo -n | tee_progress "$1" yes || error tee_progress failure
		exec > >(tee_progress "$1" yes) 2>&1 || error tee_progress failure
	fi
}

perl_strip_html='if (/Totals/..0) {s/<.*?>//g; s/^\s*//; s/\n/ /; s/(low)/\n\1/; print} END {print "\n"}'

