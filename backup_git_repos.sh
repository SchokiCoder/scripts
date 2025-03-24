#!/usr/bin/sh

# === Config ===

# The URL of all repositories.
URL="https://github.com/schokicoder"

# A list of repositories to be found under the URL.
REPOS="5th_2d 5th_schoki_game 5th_schoki_gui 5th_schoki_misc "`
	`"c2_generic2d c_50_years_old_foundation "`
	`"experiments flathub generic2d gohui hui hawps ms_office_macros "`
	`"rshui remote_control scripts smng sonne "`
	`"troll_erp twilights_program python_tutorial"

REPO_DEST="$HOME/git_backups"

# Uncomment to have a tar.gz of all repos copied to the destination,
# after the updates.
#TAR_DEST="$REPO_DEST"

# Config ends here. Stop editing.





# === Script ===

# log
DT=$(date +%Y-%m-%d_%H-%M)
echo "=== git clones/pulls at $DT ==="

# get / update repos
for ITEM in $REPOS; do
	if [ ! -d "$REPO_DEST/$ITEM" ]; then
		git clone "$URL/$ITEM" "$REPO_DEST/$ITEM"
	fi

	echo "Pulling into '$REPO_DEST/$ITEM'..."
	PREV=$(pwd)
	if ! cd "$REPO_DEST/$ITEM"; then
		echo "cd err, exiting"
		exit
	fi
	git pull
	if ! cd "$PREV"; then
		echo "cd err, exiting"
		exit
	fi
done

# log
echo "Repos updated"

# make a tar
if [ ! "$TAR_DEST" = "" ]; then
	echo "Creating archive"
	TAR_NAME="git_backups_$DT.tar.gz"
	tar -C "$REPO_DEST" -czf "$REPO_DEST/repos.tar.gz" $REPOS #intentionally non quoted var
	mv "$REPO_DEST/repos.tar.gz" "$TAR_DEST/$TAR_NAME"
fi

# log
echo "=== All done ==="
