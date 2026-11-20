#!/bin/sh

# SPDX-License-Identifier: MIT, or BSD-3-Clause, or MPL-2.0, or I-don't-care
# Whatever suits your mood, but no warranties

set -eux


# this function was made 100% by ChatGippity,
# because I want to get this done and get to more productive things already
enable_debian_component()
{
	COMPONENT="$1"
	SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"
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

	if ! grep -q '^Components:' "$SOURCES_FILE" ; then
		echo "No Components fields found in $SOURCES_FILE" >&2
		return 1
	fi

	if [ ! -e "$BACKUP_FILE" ] ; then
		sudo cp -a "$SOURCES_FILE" "$BACKUP_FILE"
	fi

	# add the component to every Components field, if missing
	sudo sed -i -E "/^Components:/ {
		/(^|[[:space:]])${COMPONENT}([[:space:]]|$)/! s/$/ ${COMPONENT}/
	}" "$SOURCES_FILE"
}


echo "DISCLAIMER:"
echo "This script installs packages, and sets up a system to my taste."
echo "It is made for Debian. You may not want to use it elsewhere."
echo "There are no guarantees or warranties either way."
echo ""

echo "Do you want to continue? (y/n)"
read -r USER_CONTINUE
if [ ! "$USER_CONTINUE" = "y" ] && [ ! "$USER_CONTINUE" = "Y" ] ; then
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

echo "> Adding user local binaries to PATH"

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

sudo flatpak remote-add --system --if-not-exists flathub \
	https://dl.flathub.org/repo/flathub.flatpakrepo

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

echo "Do you want to install development tools and docs? (y/n)"
echo "If not sure, type \"n\" for no."
read -r USER_DEVELOPER
if [ "$USER_DEVELOPER" = "y" ] || [ "$USER_DEVELOPER" = "Y" ] ; then
	sudo apt install -y \
		build-essential \
		gdb \
		libasan8 \
		libubsan1 \
		manpages-dev
fi

echo "Do you want to install the proprietary Steam launcher? (y/n)"
echo "If not sure, type \"n\" for no."
read -r USER_STEAM
if [ "$USER_STEAM" = "y" ] || [ "$USER_STEAM" = "Y" ] ; then
	enable_debian_component contrib
	sudo dpkg --add-architecture i386
	sudo apt update
	sudo apt install -y steam-installer
fi

echo "Do you want the proprietary nVidia graphics card driver? (y/n)"
echo "If not sure, type \"n\" for no."
read -r USER_GPU_NVIDIA
if [ "$USER_GPU_NVIDIA" = "y" ] || [ "$USER_GPU_NVIDIA" = "Y" ] ; then
	enable_debian_component non-free
	sudo apt update
	sudo apt install -y nvidia-driver
fi

echo "> WE'RE DONE HERE. Press Enter to exit."
read -r _USER_CONFIRM_DONE
echo "Have a very safe day."
