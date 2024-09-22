#!/bin/sh

URL="https://github.com/SchokiCoder/"

# empty backticks ` evaluate to nothing... yeah
REPOS="2d 5th_2d 5th_schoki_game 5th_schoki_gui 5th_schoki_misc "`
	`"c2_2d c_50_years_old_foundation "`
	`"experiments flathub gohui hui hawps ms_office_macros "`
	`"onewaypass rshui remote_control scripts smng sonne "`
	`"troll_erp twilights_program python_tutorial"

for ITEM in $REPOS; do
	if [ ! -d "$ITEM" ]; then
		git clone "$URL$ITEM"
	fi

	cd "$ITEM" || exit
	git pull
	cd ..
done

tar -czf "git_backups_$(date -I).tar.gz" $REPOS

