#! /bin/bash

# JEG 13/06/24
# version 1.1

if [[ $EUID > 0 ]]
	then echo "Must run this script as root!"
	exit
fi

Help()
{
echo "Script to ease the install of Pi Presents KMS, especially when"
echo "rolling out to many identical systems"
echo
echo "OPTIONS:"
echo
echo "  -a    Full auto silent install, carries out all actions"
echo "  -h    Displays this help text"
echo "  -v    Shows version info"
echo
echo "Written by James Ball, 13/06/24"
echo
}

Version()
{
echo
echo "Pi Presents KMS install script"
echo "Version 1.1"
echo
echo "Written by James Ball, 13th June 2024"
echo
}

Update()
{
	# Update the system
	apt update
	apt upgrade
}

Installreq()
{
	# Install required packages
	apt-get -y install python3-pil.imagetk unclutter mplayer
	yes | pip3 install selenium

	apt-get -y install chromium-chromedriver

	apt-get -y install mpv python3-mpv
	python3 -m pip install DRV2605
}

Installopt()
{
	# Install optional packages
	yes | pip3 install evdev
	apt-get -y install mpg123
}

Installpp()
{
	# Download and install Pi Presents
	mkdir /home/pi/pipresents
	wget -P /home/pi/ https://github.com/KenT2/pipresents-kms/tarball/master -O - | tar --overwrite -xz -C /home/pi/pipresents --strip-components=1
	chown pi:pi -R /home/pi/pipresents
}

Installexmp()
{
	# Download and install Pi Presents Examples
	mkdir /home/pi/pp_home
	wget -P /home/pi/ https://github.com/KenT2/pipresents-kms-examples/tarball/master -O - | tar xz -C /home/pi/pp_home --strip-components=2
	chown pi:pi -R /home/pi/pp_home
}

Setautostart()
{
	if [ ! -f /home/pi/.config/lxsession/LXDE-pi/autostart ]; then

    	echo "Copying default autostart file..."
    	cp /etc/xdg/lxsession/LXDE-pi/autostart /home/pi/.config/lxsession/LXDE-pi/autostart
		chown pi:pi /home/pi/.config/lxsession/LXDE-pi/autostart

	fi

	echo "Inserting autostart line..."
	grep -qxF "/usr/bin/python3 /home/pi/pipresents/pp_manager.py" /home/pi/.config/lxsession/LXDE-pi/autostart || echo "/usr/bin/python3 /home/pi/pipresents/pp_manager.py" >> /home/pi/.config/lxsession/LXDE-pi/autostart

	echo "Patching pp_manager.py to wait 30 seconds before starting..."
	#edit pp_manager.py to wait 30 seconds for network to come up after starting (prevents failed launch)
	#sed -i '/start(PPManager,address=self.ip.*/i \ \ \ \ \ \ \ \ sleep(30)' /home/pi/pipresents/pp_manager.py
	sed -i 's/wait_for_network(10).*/wait_for_network(60)/' /home/pi/pipresents/pp_manager.py
	echo "...done!"

}

Sethostname()
{
	curhost=$(hostname)
	printf "Current hostname is: %s\n" "$curhost"
	echo Enter new hostname:
	read new_hostname
	raspi-config nonint do_hostname $new_hostname
	curhost=$(hostname)
	printf "New hostname is: %s\n" "$curhost"
	#edit pp_web.cfg to update hostname
	sed -i "s/unit =.*/unit = $curhost/" /home/pi/pipresents/pp_config/pp_web.cfg
}

Enablessh()
{
	# Seems to be more whether ssh is DISABLED or not, 1 = disabled, 0 = enabled
	raspi-config nonint do_ssh 0
}

Enablevnc()
{
	# Seems to be more whether vnc is DISABLED or not, 1 = disabled, 0 = enabled
	raspi-config nonint do_vnc 0
}

Disableblank()
{
	# 1 = disabled, 0 = enabled
	raspi-config nonint do_blanking 1
}

Installsmb()
{
	apt-get -y install samba samba-client
} 

Updateshares()
{
	# Backup then modify smb.conf, then restart samba.d
	echo "Enter a new SAMBA password:"
	read smbpassword
	(echo "$smbpassword"; echo "$smbpassword") | smbpasswd -s -a "pi"
	config=$"/etc/samba/smb.conf"
	line=$(sed -n '1{p;q}' /etc/samba/smb.conf)
	if [[ $line = "#JEG"  ]]; then
		echo "Config file already modified. Skipping!"
	else
		sed -i '1 i #JEG' $config;
		cp --backup=t $config /etc/samba/smb.conf.bak
		sed -i -e '169,236d' $config;
		echo "[Pi Presents]" >> $config
		echo "comment = Pi Presents root directory" >> $config
		echo "path = /home/pi/pipresents" >> $config
		echo "read only = no" >> $config
		echo "guest ok = no" >> $config
		echo "browseable = yes" >> $config
		echo "create mask = 0664" >> $config
		echo "directory mask = 0755" >> $config
		echo >> $config
		echo "[PP Home]" >> $config
		echo "comment = Pi Presents media and profiles" >> $config
		echo "path = /home/pi/pp_home" >> $config
		echo "read only = no" >> $config
		echo "guest ok = no" >> $config
		echo "browseable = yes" >> $config
		echo "create mask = 0664" >> $config
		echo "directory mask = 0755" >> $config
	fi
	
	service smbd restart
	
}

# setting the option -a ("all") installs everything and doesn't prompt per section
while getopts ":ahv" option; do
	case $option in
		a) #skip all yes/no prompts
			printf "Skipping all yes/no prompts!\n"
			doall=true;;
		h) #print help
			Help
			exit;;
		v) #print version info
			Version
			exit;;
		\?) #unknown option
			Help
			exit;;
	esac
done

echo
echo "This script does all the pre-requisite things for installing and"
echo "setting up Pi Presents KMS as per the install instructions on github."
echo "Additionally there are then options to set up SSH access, create SAMBA"
echo "shares and a few other things that make using the software easier."
echo
echo "This script assumes you are running Raspberry Pi OS (Legacy) with desktop"
echo "This script assumes you are the user \"pi\""
echo "If the above is not the case there may be unexpected results. Make"
echo "backups and proceed with caution!"
echo

if [[ $doall = true ]]; then
	echo
	echo "Updating system..."
	Update
else
	echo
	read -p "Update the system? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Updating system..."
		Update
	else
		echo
		echo "Skipping system update!"
		echo
	fi
fi

# Install required packages

if [[ $doall = true ]]; then
	echo
	echo "Installing required packages..."
	Installreq
else
	echo
	read -p "Install required packages? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Installing required packages..."
		Installreq
	else
		echo
		echo "Skip installing required packages!"
		echo
	fi
fi

# Install optional packages
if [[ $doall = true ]]; then
	echo
	echo "Installing optional packages..."
	Installopt
else
	echo
	read -p "Install optional packages? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Installing optional packages..."
		Installopt
	else
		echo
		echo "Skip installing optional packages!"
		echo
	fi
fi

# Download Pi Presents KMS
if [[ $doall = true ]]; then
	echo
	echo "Downloading and installing Pi Presents KMS..."
	Installpp
else
	echo
	read -p "Download and install Pi Presents KMS? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Downloading and installing Pi Presents KMS..."
		Installpp
	else
		echo
		echo "Skipping downloading and installing Pi Presents KMS!"
		echo
	fi
fi

# Download Pi Presents KMS Examples
if [[ $doall = true ]]; then
	echo
	echo "Downloading and installing Pi Presents KMS Examples..."
	Installexmp
else
	echo
	read -p "Download and install Pi Presents KMS Examples? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Downloading and installing Pi Presents KMS Examples..."
		Installexmp
	else
		echo
		echo "Skipping downloading and installing Pi Presents KMS Examples!"
		echo
	fi
fi

# Set PP Manager to autostart
if [[ $doall = true ]]; then
	echo
	echo "Setting PP Manager to autostart..."
	Setautostart
else
	echo
	read -p "Set PP Manager to autostart on logon? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Setting PP Manager to autostart..."
		Setautostart
	else
		echo
		echo "Skip setting PP Manager autostart!"
		echo
	fi
fi

# Set hostname
if [[ $doall = true ]]; then
	echo
	echo "Setting new hostname..."
	Sethostname
else
	echo
	read -p "Set new hostname? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Setting a new hostname..."
		Sethostname
	else
		echo
		echo "Skipping setting a new hostname!"
		echo
	fi
fi

# Enable SSH
if [[ $doall = true ]]; then
	echo
	echo "Enabling SSH access..."
	Enablessh
	echo "... Done!"
else
	echo
	status=$(raspi-config nonint get_ssh)
	if [[ $status = "0" ]]; then
		string=$"enabled!"
	else
		string=$"disabled!"
	fi
	printf "SSH access is currently %s\n" "$string"
	read -p "Enable SSH access? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Enabling SSH access..."
		Enablessh
		echo "... Done!"
	else
		echo
		echo "Skipping enabling SSH access!"
		echo
	fi
fi

# Enable VNC
if [[ $doall = true ]]; then
	echo
	echo "Enabling VNC access..."
	Enablevnc
	echo "... Done!"
else
	echo
	status=$(raspi-config nonint get_vnc)
	if [[ $status = "0" ]]; then
		string=$"enabled!"
	else
		string=$"disabled!"
	fi
	printf "VNC is currently %s\n" "$string"
	read -p "Enable VNC access? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Enabling VNC access..."
		Enablevnc
		echo "... Done!"
	else
		echo
		echo "Skipping enabling VNC access!"
		echo
	fi
fi

# Disable screen blanking (blanking = going blank after period of time)
if [[ $doall = true ]]; then
	echo
	echo "Disabling screen blanking..."
	Disableblank
	echo "... Done!"
else
	echo
	status=$(raspi-config nonint get_blanking)
	if [[ $status = "0" ]]; then
		string=$"enabled!"
	else
		string=$"disabled!"
	fi
	printf "Screen blanking is currently %s\n" "$string"
	read -p "Disable screen blanking? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Disabling screen blanking..."
		Disableblank
		echo "... Done!"
	else
		echo
		echo "Skip diabling screen blanking!"
		echo
	fi
fi

# Install SAMBA
if [[ $doall = true ]]; then
	echo
	echo "Installing SAMBA..."
	Installsmb
	echo "... Done!"
else
	echo
	read -p "Install SAMBA daemon and client? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Installing SAMBA..."
		Installsmb
	else
		echo
		echo "Skip installing SAMBA!"
		echo
	fi
fi

# Update SAMBA shares
if [[ $doall = true ]]; then
	echo
	echo "Updating SAMBA shares..."
	Updateshares
	echo "... Done!"
else
	echo
	read -p "Modify smb.conf and update shares (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Applying modifications and restarting SAMBA..."
		Updateshares
		echo "... Done!"
	else
		echo
		echo "Skip modifying SAMBA!"
		echo
	fi
fi

# Reboot system
if [[ $doall = true ]]; then
	echo
	echo "Rebooting system in 30 seconds!"
	sleep 30
	echo "Going down for reboot now!"
	reboot
else
	echo
	read -p "Reboot system? (yes/no) " -n 1 -r
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo
		echo "Rebooting system in 10 seconds!"
		sleep 10
		echo "Going down for reboot now!"
		reboot
	else
		echo
		echo "Skipping reboot!"
		echo
	fi
fi
