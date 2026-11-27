#!/bin/sh

# SPDX-License-Identifier: MIT, or BSD-3-Clause, or MPL-2.0, or I-don't-care
# Whatever suits your mood, but no warranties

set -eu

COMPONENTS_BACKUP_FILE=


is_deb_installed()
{
	dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null |
		grep -q '^installed$'
}

# this function was made 100% by ChatGippity,
# because I want to get this done and get to more productive things already
enable_debian_component()
{
	COMPONENT="$1"
	SOURCES_FILE="/etc/apt/sources.list"
	BACKUP_FILE="${SOURCES_FILE}.bak.$$"

	case "$COMPONENT" in
		contrib|non-free)
			;;
		*)
			echo "Invalid repository component: $COMPONENT" >&2
			return 1
			;;
	esac

	if [ ! -f "$SOURCES_FILE" ] ; then
		echo "Debian sources file not found: $SOURCES_FILE" >&2
		return 1
	fi

	if ! grep -Eq '^[[:space:]]*deb(-src)?[[:space:]]' "$SOURCES_FILE" ; then
		echo "No active repository entries found in $SOURCES_FILE" >&2
		return 1
	fi

	if [ -z "$COMPONENTS_BACKUP_FILE" ] ; then
		TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S') || return 1
		BACKUP_FILE="${SOURCES_FILE}.bak.${TIMESTAMP}"
		COUNTER=1

		while [ -e "$BACKUP_FILE" ] ; do
			BACKUP_FILE="${SOURCES_FILE}.bak.${TIMESTAMP}.${COUNTER}"
			COUNTER=$((COUNTER + 1))
		done

		sudo cp -a "$SOURCES_FILE" "$BACKUP_FILE" || return 1
		COMPONENTS_BACKUP_FILE="$BACKUP_FILE"
	fi

	# Add the component to every active repository entry, if missing.
	sudo sed -i -E "/^[[:space:]]*deb(-src)?[[:space:]]/ {
		/(^|[[:space:]])${COMPONENT}([[:space:]]|$)/! s/[[:space:]]*(#.*)?$/ ${COMPONENT}\\1/
	}" "$SOURCES_FILE"

	sudo apt update
}

question()
{
	QUESTION_ANSWER=

	while [ "$QUESTION_ANSWER" = "" ] ; do
		echo "$1 (y/n)"
		echo "If not sure, type \"n\" for no."
		read -r QUESTION_ANSWER
	done

	[ "$QUESTION_ANSWER" = "y" ] ||
	[ "$QUESTION_ANSWER" = "Y" ] ||
	[ "$QUESTION_ANSWER" = "yes" ] ||
	[ "$QUESTION_ANSWER" = "Yes" ] ||
	[ "$QUESTION_ANSWER" = "heck yes" ] ||
	[ "$QUESTION_ANSWER" = "oh yeah boi" ] ||
	[ "$QUESTION_ANSWER" = "sign me up" ]
}


echo "DISCLAIMER:"
echo "This script installs packages, and sets up a system to my taste."
echo "It is made for Debian. You may not want to use it elsewhere."
echo "There are no guarantees or warranties either way."
echo ""



if ! question "Do you want to continue?" ; then
	exit
fi

echo "> Installing updates"

sudo apt update
sudo apt upgrade -y

echo "> Installing base tools"

sudo apt install -y \
	ufw \
	apparmor \
	apparmor-utils \
	flatpak \
	fwupd \
	curl \
	htop \
	lsof \
	pciutils \
	usbutils \
	lm-sensors

if ! sudo aa-status ; then
	echo "WARNING: AppArmor is not active or functioning correctly."
fi

echo "> Enabling UFW Firewall"

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable

echo "> Adding binary paths to PATH"

cat <<'EOF' | sudo tee /etc/profile.d/schoki_debian.sh >/dev/null
# add sbin dirs to PATH
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
EOF

PROFILE_FILE="$HOME/.bash_profile"
if [ ! -f "$PROFILE_FILE" ] ; then
	PROFILE_FILE="$HOME/.profile"
fi
if [ -f "$PROFILE_FILE" ] ; then
	if ! grep -q -F ".local/bin" "$PROFILE_FILE"; then
	cat >> "$PROFILE_FILE" <<'EOF'

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF
	fi
else
	echo "Couldn't find a bash profile. Is this intentional?"
fi

echo "> Adding Flathub"

if flatpak remotes --system --columns=name |
   grep -Fxq flathub ; then
	echo "Flathub repo already added system wide."
	echo "Moving on."
else
	flatpak remote-add --user --if-not-exists flathub \
		https://dl.flathub.org/repo/flathub.flatpakrepo
fi

echo "> Adding Flatpak support to your graphical installer (if it exists)"

if dpkg-query -W -f='${db:Status-Status}' plasma-discover 2>/dev/null |
   grep -q '^installed$' ; then
	sudo apt install -y plasma-discover-backend-flatpak
fi
if dpkg-query -W -f='${db:Status-Status}' gnome-software 2>/dev/null |
   grep -q '^installed$' ; then
	sudo apt install -y gnome-software-plugin-flatpak
fi

echo "> It's time to start the Questioning"

if question "Do you want to install development tools and docs?" ; then
	sudo apt install -y \
		build-essential \
		gdb \
		libasan8 \
		libubsan1 \
		manpages-dev
fi

if question "Do you want to install multimedia codecs and VLC?" ; then
	enable_debian_component contrib
	sudo apt install \
		libavcodec-extra \
		libdvd-pkg \
		vlc
	sudo dpkg-reconfigure libdvd-pkg
fi

if question "Do you want to install the proprietary Steam launcher?" ; then
	enable_debian_component contrib
	sudo dpkg --add-architecture i386
	sudo apt update
	sudo apt install -y steam-installer
fi

if question "Do you want the proprietary nVidia graphics card driver?" ; then
	enable_debian_component non-free
	sudo apt update
	sudo apt install -y nvidia-driver
fi

if question "Do you want to debloat?" ; then
	if is_deb_installed xfce4-terminal ||
	   is_deb_installed konsole ||
	   is_deb_installed gnome-terminal; then
		sudo apt purge -y \
			epiphany-browser \
			konqueror \
			xiterm+thai \
			xterm
	fi
fi

if question "Do you want to remove default Firefox ESR?" ; then
	sudo apt purge -y firefox-esr
fi

echo "> WE'RE DONE HERE. Press Enter to exit."
read -r _USER_CONFIRM_DONE
echo "Have a very safe day."
