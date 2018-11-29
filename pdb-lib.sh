
function mydate { date +%F-%T; }
function log { echo $(mydate): LOG: "$@"; }
function error { echo $(mydate): ERROR: "$@"; exit 1; }
function warning { echo $(mydate): WARNING: "$@"; }

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

