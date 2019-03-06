#!/bin/bash

read -p 'install local or vps part (l|v)? ' which_part

if [[ $which_part == l ]]
then
	# install local part of scripts: {{{
	set -x
	# TODO: which 7z bzip2 openssl... etc check all required programs
	sudo ln -sfv -t /usr/local/bin "$PWD"/{pdb-{1..6}*,pdb-ssh-vps.sh}
	# }}}

elif [[ $which_part == v ]]
then
	# install vps part of scripts: {{{
	:
	# TODO: ?cron job to reboot vps every 2-3-4 months?
	:
	# }}}
fi

