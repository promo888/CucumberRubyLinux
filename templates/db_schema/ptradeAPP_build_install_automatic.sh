#!/bin/bash

# Init
userPermitted="ptrade"
archiveName="$1"
argsQty="$#"
scriptFolderPath=$(dirname $(readlink -f "$0"))
scriptName=$(basename "$0")
tarPath="$scriptFolderPath/$archiveName"
untarWhereTo="/export/home/$userPermitted/tmp"
untarSuccessMessage="The package \""$archiveName"\" was extracted in $untarWhereTo"

help_function()
{
        echo "******************************************************************************************************"
        echo "Usage: ./$scriptName <archive name>"
        echo "Note: archive should be located in the same directory as the script"
        echo "                   "
        echo "help, -h, --h             print the manual"
        echo "******************************************************************************************************"
}

# pre-checking
if [ "$argsQty" -ne 1 ]; then
	echo -e "\e[31mError: there should be one argument after script name, you gave \""$argsQty"\". Exiting\e[0m"
	help_function
	exit 1
fi

if ! [ -s "$tarPath" ]; then
	echo -e "\e[31mPackage \""$tarPath"\" not found or file size equals 0\e[0m"
	echo " "
	help_function
	exit 1
fi

installationFolderNameSlash="$(tar --exclude="*/*" -tf $tarPath | awk '/PT_APP/')"
installationFolderName=${installationFolderNameSlash%/}
installationPath="$untarWhereTo/$installationFolderName"
logFile="$scriptName.log"
linkPTSfolder="/export/home/$userPermitted"
linkPTSname="PTS"
untarModeVerbose="" #can take values "" or "v"

# redirecting output to a log
exec > >(tee "$logFile") 2>&1

checkCurrentUser()
{
local userId
userId="$(id -u $userPermitted)"
if [ "$(id -u)" != "$userId" ]; then
        echo -e "\e[31mError: this script must be run by user \""$userPermitted"\", current user is \""$(whoami)"\", exiting\e[0m" 1>&2
        exit 1
fi
}

MyExit()
{
    echo -e "\n\e[31mStopped by user\e[0m"
    exit 1
}
trap MyExit INT

readParam()
{
        case $archiveName in
                help|-help|--help|-h|--h)
					help_function
					exit 0
					;;
        esac
}

# user-checking
checkCurrentUser

readParam

# Let's go
if [ -d "$installationPath" ]; then
	echo "Directory with the same version found (\""$installationPath"\"), renaming the existing one... \n"
	timestamp=$(date -d "today" +"%Y_%m_%d_%H-%M-%S")
	mv -v $installationPath ${installationPath}_${timestamp}
fi

# ***** start extracting the archive *****
echo "Extracting $archiveName to $untarWhereTo..."
tar xzf$untarModeVerbose $tarPath -C $untarWhereTo
echo -e "\e[32m$untarSuccessMessage\n\e[0m"
# ***** finished extracting *****

# ***** start installation *****
# check if PTS link exists and unlink
cd "$linkPTSfolder"
if [ -L "$linkPTSname" ]; then
	echo -e "\e[33mFound PTS link to $(readlink $linkPTSname)\e[0m"
	unlink "$linkPTSname"
	echo -e "\e[32mPTS link removed\e[0m \n"
fi

echo "Start installing..."
cd $installationPath && sh pts_installer.sh
# ***** finished creating schema *****
echo ""
echo -e "\e[32mInstallation finished\e[0m"