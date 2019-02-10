#!/bin/bash

read -p 'install local or vps part (l|v)? ' which_part

if [[ $which_part == l ]]
then
	# install local part of scripts: {{{
	set -x
	sudo ln -sfv -t /usr/local/bin "$PWD"/{pdb-{1..5}*,pdb-ssh-vps.sh}
	# }}}

elif [[ $which_part == v ]]
then
	# install vps part of scripts: {{{
	:
	# TODO: ?cron job to reboot vps every 2-3-4 months?
	:
	# }}}
fi

