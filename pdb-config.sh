
password_script=/home/bdimych/tl-my/bdimych-text-git/2/pdb/Storage/pdbs-180901-pdb-package-password.sh
function password_check { [[ ${#password} == 31 ]]; }

copy_progress_files_to=/home/bdimych/tl-my/bdimych-text-git/3/mypdb/progress-files

saved_suffix=---[saved]

vps_ssh_command='sshpass -e ssh -o ConnectTimeout=25 -p ???port???'
vps_ssh_connection_string=???user???@1.2.3.4

vps_uploads_dir=/home/bdimych/frd/uploads

filelist_local=/home/bdimych/tl-my/bdimych-text-git/2/pdb/Storage/pdbs-180919-my-files.txt
filelist_vps=/home/bdimych/pdbs-180919-my-files.txt

local_packages_dir=/home/bdimych/tl-big/MyPDB

