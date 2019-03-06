#!/bin/bash

# TODO: description,

set -e

source "$(dirname "$(realpath "$0")")/pdb-config.sh"
source "$(dirname "$(realpath "$0")")/pdb-lib.sh"

case "$1" in
*-in-progress.txt) pf="$1";;
*.7z) pf="${1%.7z}-in-progress.txt";;
*) error usage: ${0##*/} progress-file-or-7z
esac
[[ -f "$pf" ]] || error progress file not found
archive="${pf%-in-progress.txt}.7z"
[[ -f "$archive" ]] || error archive file not found

tee_progress "$pf"

log ${0##*/} started
ls -lh "$archive" "$pf"

exit

OK -параметр комстроки это $pf или 7z,
-напечатать все статусы,
-проверить completed.txt,
-из files взять размеры частей файла и посчитать что split | md5 совпадают из files,
-проверить транзакцию в блокчейне и расшифровать сообщение,
-написать финальную фразу что всё ок,
-и отметить каталог и файл как ---[saved]
-и напечатать огромными буквами figlet pdb-package xxx has been saved for history!
	-и что не забудьте дать ссылки всем друзьям чтобы они поставили в frd,

