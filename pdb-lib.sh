
function mydate { date +%F-%T; }
function log { echo $(mydate): LOG: "$@"; }
function error { echo $(mydate): ERROR: "$@"; exit 1; }
function warning { echo $(mydate): WARNING: "$@"; }

