
password_script=/home/bdimych/tl-my/bdimych-text-git/2/pdb/Storage/pdbs-180901-pdb-package-password.sh
source /home/bdimych/tl-my/bdimych-text-git/2/pdb/Storage/pdbs-190310-check-password.sh

copy_progress_files_to=/home/bdimych/tl-my/bdimych-text-git/3/mypdb/progress-files

saved_suffix=---[saved]

vps_ssh_port=???
vps_ssh_command="ssh -t -L 8888:localhost:8888 -p $vps_ssh_port"
vps_sshpass_command="sshpass -e ssh -o ConnectTimeout=25 -p $vps_ssh_port"
vps_ssh_connection_string=???user???@1.2.3.4

vps_freenet_dir=/home/bdimych/freenet/freenet_1478
vps_freenet_downloads_dir=$vps_freenet_dir/downloads
vps_frd_dir=/home/bdimych/frd
vps_uploads_dir=$vps_frd_dir/uploads
vps_completed_dir=$vps_frd_dir/completed

filelist_local=/home/bdimych/tl-my/bdimych-text-git/2/pdb/Storage/pdbs-180919-my-files.txt
filelist_vps=/home/bdimych/pdbs-180919-my-files.txt

local_packages_dir=/home/bdimych/tl-big/MyPDB

openssl_command='openssl aes-256-cbc -nosalt'

