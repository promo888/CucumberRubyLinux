#!/bin/bash

### self-determining
scriptFolderPath=$(dirname $(readlink -f "$0"))
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
linkName="PT_APP"
userToDrop="$linkName"
myPID="$$"
pidFromFile=""
pidFile="$scriptFolderPath/pid_$baseScriptName.log"

### checking whether another installation script is still running
checkPidFile()
{
if [ -f "$pidFile" ]; then
	pidFromFile=$(<"$pidFile")
	if [ "$pidFromFile" -ne "$myPID" ]; then
		if [ $(/bin/ps -aef|grep "$pidFromFile"|grep -v grep) ]; then
			echo -e "\e[31mError: another $userToDrop installation script is running with PID \""$pidFromFile"\", exiting\e[0m"
			exit 1
		else
			rm -f "$pidFile"
			echo -e "$pidFile removed\n"
		fi
	else
		rm -f "$pidFile"
		echo -e "$pidFile removed\n"
	fi
fi
}

### catching exit
MyExit()
{
	if [ "$verboseMode" = "v" ]; then
		echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Stopped by user\e[0m"
	else
		echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Stopped by user\e[0m"|tee /dev/stderr
	fi
	checkPidFile
    exit 1
}
trap MyExit INT # custom message when stopped by user

exit_status=0
giveErrorMsg()
{
exit_status="$?"
if [ $exit_status -ne 0 ]; then
	if [ "$verboseMode" = "v" ]; then
		echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $errorMsg\e[0m"
	else
		echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $errorMsg\e[0m"|tee /dev/stderr
	fi
	echo "exit_status: $exit_status"
	checkPidFile
	exit 1
fi
}
trap giveErrorMsg EXIT # print error message

anotherExit()
{
if [ "$verboseMode" = "v" ]; then
	echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- terminated\e[0m"
else
	echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- terminated\e[0m"|tee /dev/stderr
fi
checkPidFile
}
trap anotherExit SIGTERM SIGHUP HUP QUIT PIPE TERM

checkPidFile
echo "$myPID" > "$pidFile"

### checking if the script itself is set as executable
if ! [[ -x "$scriptFolderPath/$scriptName" ]]; then
	echo -e "\e[31mError: the script \""$scriptFolderPath/$scriptName"\" is not set as executable, exiting\e[0m"
fi

### logs
logsDir="$scriptFolderPath/logs_$linkName"
mkdir -p "$logsDir"
logFile="$logsDir"/"$baseScriptName".log
echo "">"$logFile"

### debug features
logDebug="$logsDir"/"$baseScriptName"_debug.log
exec 5> "$logDebug"
BASH_XTRACEFD="5"
PS4='$LINENO: '
set -x

### behaviour settings
### NOTE! this script will terminate on any error with return value <> 0
set -o errexit    # will cause bash to exit with an error on any simple command failure
set -o pipefail   # will cause bash to exit on any command failure in a pipeline as well
set -o nounset    # fail if using un-initialized variables

### Init
untarWhereTo="$scriptFolderPath/packages"
linkPTSfolder="$scriptFolderPath"

### getting folder for unpacking if given as an argument
argFirst=${1:-}
argSecond=${2:-}
if [ "$argFirst" = "extract_to:" ]; then
	shift
	shift
	
	if [ -d "$argSecond" ]; then
		untarWhereTo="$argSecond"
		echo -e "Folder for unpacking given: \""$untarWhereTo"\"\n">>"$logFile"
	else
		echo -e "Error: folder \""$argSecond"\" not found, continuing with the default value of the folder for unpacking: \""$untarWhereTo"\"\n">>"$logFile"
	fi
fi

### getting installation folder if given as an argument
argFirst=${1:-}
argSecond=${2:-}
if [ "$argFirst" = "install_to:" ]; then
	shift
	shift
	
	if [ -d "$argSecond" ]; then
		linkPTSfolder="$argSecond"
		echo -e "Folder for installation given: \""$linkPTSfolder"\"\n">>"$logFile"
	else
		echo -e "Error: folder \""$argSecond"\" not found, continuing with the default value of the installation folder: \""$linkPTSfolder"\"\n">>"$logFile"
	fi
fi

### Init
userPermitted="ptrade"
argFirst=${1:-}
argSecond=${2:-}
argsQty="$#"
archiveName=""
tarFilter="APP"
installLauncher="pts_installer.sh"
linkPTSname="PTS"
verboseMode=""
pathGiven=""
errorMsg=""
COLOR=""
getLastPackageName=""
getPackageName=""
installationPath=""
tarPath=""

storagePath="/export/home/ptrade/build_server/Releases/PTS"
storageLocalPath="/export/home/$userPermitted/build_server/Releases/PTS"

help_function()
{
	echo "******************************************************************************************************"
	echo "This is a script for ptradeAPP installation for user ptrade"
	echo "Usage: ./$scriptName"
	echo "Note: launching without -v means silent mode (output only in case of error)"
	echo ""
	echo "-verbose, -v            verbose mode"
	echo "Usage: ./$scriptName -v"
	echo ""
	echo "-n                      find package with the following name in the storage and use it"
	echo "Usage example: ./$scriptName -n package123.tar.gz"
	echo ""
	echo "-nv                     find package with the following name in the storage and use it running in verbose mode"
	echo "Usage example: ./$scriptName -nv package123.tar.gz"
	echo ""
	echo "-p                      specify full path to the package"
	echo "Usage example: ./$scriptName -p /export/home/username/tmp/package.tar.gz"
	echo "Note: path should be full, and the file should be a valid archive"
	echo ""
	echo "-pv                     specify full path to the package and run in verbose mode"
	echo "Usage example: ./$scriptName -pv /export/home/username/tmp/package.tar.gz"
	echo "Note: path should be full, and the file should be a valid archive"
	echo ""
	echo "-f                      specify full path to the package including IP of machine"
	echo "Usage example: ./$scriptName -p user@10.20.30.40:/export/home/username/tmp/package.tar.gz"
	echo "Note: path should be full, and the file should be a valid archive"
	echo ""
	echo "-fv                     specify full path to the package including IP of machine and run in verbose mode"
	echo "Usage example: ./$scriptName -pv user@10.20.30.40:/export/home/username/tmp/package.tar.gz"
	echo "Note: path should be full, and the file should be a valid archive"
	echo ""
	echo "help, -h, --h           print the manual"
	echo "******************************************************************************************************"
}

checkCurrentUser()
{
local userId
userId="$(id -u $userPermitted)"
if [ "$(id -u)" != "$userId" ]; then
        echo -e "\e[31mError: this script must be run by user \""$userPermitted"\", current user is \""$(whoami)"\", exiting\e[0m" 1>&2
        exit 1
fi
}

readParam()
{
if [ "$argsQty" -lt 3 ]; then
	if [ "$argsQty" -eq 2 ]; then
		if [[ "$argFirst" == "-v" || "$argFirst" == "-verbose" ]]; then
			errorMsg="Error: in case of \""$argFirst"\" there should be only one argument, you gave \""$argsQty"\": $argFirst $argSecond. Exiting"
			echo -e "\e[31mError: in case of \""$argFirst"\" there should be only one argument, you gave \""$argsQty"\": $argFirst $argSecond. Exiting\e[0m"
			help_function
			exit 1
		fi
		if [[ "$argFirst" == "-p" || "$argFirst" == "-pv" ]]; then
			if [[ -f "$argSecond" && "$argSecond" =~ \.t?gz$ ]]; then
				if [ "$argFirst" == "-pv" ]; then
					verboseMode="v"
				else
					verboseMode=""
				fi
				pathGiven="$argSecond"
				archiveName=${pathGiven##*/} # get * after last slash
			else
				errorMsg="Error: given path is incorrect, file \""$argSecond"\" not found or is not a valid archive, exiting"
				echo -e "\e[31mError: given path is incorrect, file \""$argSecond"\" not found or is not a valid archive, exiting\e[0m" 1>&2
				help_function
				exit 1
			fi
		elif [[ "$argFirst" == "-f" || "$argFirst" == "-fv" ]]; then
			ipRemote=${argSecond%:*}
			ipRemote=${ipRemote##*@}
			pathRemote=${argSecond##*:}
			userRemote=${argSecond%@*}
			### checking that remote file exists
			if [[ -z "$ipRemote" || -z "$pathRemote" || -z "$userRemote" ]]; then
				errorMsg="File not found: \""$argSecond"\""
				echo -e "\e[31mFile not found: \""$argSecond"\" \n\e[0m" 1>&2
				help_function
				exit 1
			fi
			if [ $(ssh "$ipRemote" "test -e $pathRemote && echo 1 || echo 0") -eq 1 ]; then
				if [ "$argFirst" == "-fv" ]; then
					verboseMode="v"
				else
					verboseMode=""
				fi
				pathGiven="$pathRemote"
				archiveName=${pathGiven##*/}
				echo -e "(date +%Y-%m-%d_%H:%M:%S,%3N) -- File found: \""$ipRemote:$pathRemote"\", downloading \n"
				mkdir -p "$storageLocalPath"
				scp "$userRemote"@"$ipRemote":"$pathGiven" "$storageLocalPath"
			else
				errorMsg="File not found: \""$ipRemote:$pathRemote"\""
				echo -e "\e[31mFile not found: \""$ipRemote:$pathRemote"\" \n\e[0m" 1>&2
				help_function
				exit 1
			fi

			if [[ -f "$storageLocalPath/$archiveName" && "$storageLocalPath/$archiveName" =~ \.t?gz$ ]]; then
				pathGiven="$storageLocalPath/$archiveName"
				archiveName="$archiveName"
			else
				errorMsg="Error: given path is incorrect, file \""$argSecond"\" not found or is not a valid archive, exiting"
				echo -e "\e[31mError: given path is incorrect, file \""$argSecond"\" not found or is not a valid archive, exiting\e[0m" 1>&2
				help_function
				exit 1
			fi
		elif [[ "$argFirst" == "-n" || "$argFirst" == "-nv" ]]; then			
			### getting the name of last package and its parent folders (if exist) within path
			if [ $(cd "$storagePath" && find * -type f -printf '%p\n' |egrep "$argSecond") ]; then
				if [ "$argFirst" == "-nv" ]; then
					verboseMode="v"
				else
					verboseMode=""
				fi
				getPackageName=$(cd "$storagePath" && find * -type f -printf '%p\n' |egrep "$argSecond")
			else
				errorMsg="Error: given path is incorrect, file \""$storagePath/$argSecond"\" not found or is not a valid archive, exiting"
				echo -e "\e[31mError: given path is incorrect, file \""$storagePath/$argSecond"\" not found or is not a valid archive, exiting\e[0m" 1>&2
				help_function
				exit 1
			fi
			
			if [[ -f "$storagePath/$getPackageName" && "$storagePath/$getPackageName" =~ \.t?gz$ ]]; then
				archiveName="$argSecond"
				pathGiven="$storagePath/$getPackageName"
			else
				errorMsg="Error: given path is incorrect, file \""$storagePath/$getPackageName"\" not found or is not a valid archive, exiting"
				echo -e "\e[31mError: given path is incorrect, file \""$storagePath/$getPackageName"\" not found or is not a valid archive, exiting\e[0m" 1>&2
				help_function
				exit 1
			fi
		else
			errorMsg="Incorrect argument given - \""$argFirst"\", exiting"
			echo -e "\e[31mIncorrect argument given - \""$argFirst"\", exiting\e[0m"
			help_function
			exit 1
		fi
	elif [ "$argsQty" -eq 1 ]; then
		case "$argFirst" in
		help|-help|--help|-h|--h)
			help_function
			exit 0
			;;
		-verbose|-v)
			verboseMode="v"
			;;
		-n)
			errorMsg="Error: path to package not found, exiting"
			echo -e "\n\e[31mError: path to package not found, exiting\e[0m"
			help_function
			exit 1
			;;
		-nv)
			errorMsg="Error: path to package not found, exiting"
			echo -e "\n\e[31mError: path to package not found, exiting\e[0m"
			help_function
			exit 1
			;;
		-p)
			errorMsg="Error: path to package not found, exiting"
			echo -e "\n\e[31mError: path to package not found, exiting\e[0m"
			help_function
			exit 1
			;;
		-pv)
			errorMsg="Error: path to package not found, exiting"
			echo -e "\n\e[31mError: path to package not found, exiting\e[0m"
			help_function
			exit 1
			;;
		-f)
			errorMsg="Error: path to package not found, exiting"
			echo -e "\n\e[31mError: path to package not found, exiting\e[0m"
			help_function
			exit 1
			;;
		-fv)
			errorMsg="Error: path to package not found, exiting"
			echo -e "\n\e[31mError: path to package not found, exiting\e[0m"
			help_function
			exit 1
			;;
		*)
			errorMsg="Incorrect argument given - \""$argFirst"\", exiting"
			echo -e "\e[31mIncorrect argument given - \""$argFirst"\", exiting\e[0m"
			help_function
			exit 1
			;;
		esac
	fi
else
	errorMsg="Error: there could be up to 2 arguments after script name, you gave \""$argsQty"\". Exiting"
	echo -e "\e[31mError: there could be up to 2 arguments after script name, you gave \""$argsQty"\". Exiting\e[0m"
	help_function
	exit 1
fi
}

echoColoured() # coloured output
{
if [ "$#" = 2 ]; then
	if [ "$2" = "yellow" ]; then
		COLOR="33"
	elif [ "$2" = "red" ]; then
		COLOR="31"
	elif [ "$2" = "green" ]; then
		COLOR="32"
	else
		COLOR=""
	fi
fi

if [ -z $COLOR ]; then
	echo "$1"
else
	echo -e "\e["$COLOR"m$1\e[0m"
fi
}

set_replace_env_global()
{
### replace string in .bashrc with env var if found, otherwise add
if [ $# -eq 2 ]; then
	if grep -q "export $1=" /export/home/"$userPermitted"/.bashrc; then
		sed -i -e "s/export $1=.*/export $1=$2/g" /export/home/"$userPermitted"/.bashrc
	else
		echo "export $1=$2" >> /export/home/"$userPermitted"/.bashrc
	fi
	return 0
else
	errorMsg="Error in set_replace_env_global. Usage: set_replace_env_global var_name var_value. Exiting"
	echo -e "\e[31mError in set_replace_env_global. Usage: set_replace_env_global var_name var_value. Exiting\e[0m"
	exit 1
fi
}

set_replace_ebs_env()
{
### replace var value in ebs.env with with given value if found, otherwise add
if [ $# -eq 2 ]; then
	if grep -q "$1=" /export/home/"$userPermitted"/ebs.env; then
		sed -i -e "s#$1=.*#$1=$2#g" /export/home/"$userPermitted"/ebs.env
	else
		echo "$1=$2" >> /export/home/"$userPermitted"/ebs.env
	fi
	return 0
else
	errorMsg="Error in set_replace_ebs_env. Usage: set_replace_ebs_env var_name var_value. Exiting"
	echo -e "\e[31mError in set_replace_ebs_env. Usage: set_replace_ebs_env var_name var_value. Exiting\e[0m"
	exit 1
fi
}

getPackage()
{
echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Getting package..." yellow

### defining error message for the following block
errorMsg="Error while getting package, installation not finished"

mkdir -p "$untarWhereTo"

### if user specified path to package manually
if [ "$pathGiven" != "" ]; then
	echoColoured "Path to package was given explicitly, getting $pathGiven" yellow
	
	### return 1 if the files are not identical (byte-to-byte comparison)
	if cmp -s "$pathGiven" "$untarWhereTo/$archiveName"; then
		echo "The identical package is already in the target folder, continuing without copy"
	else
		\cp -fv "$pathGiven" "$untarWhereTo"
		echo "Copying finished"
	fi
	
else
	### checking that mounted directory exists and not empty
	if [ "$(ls -A $storagePath)" ]; then
		 echoColoured "\""$storagePath"\" exists and is not empty" green
	else
		echoColoured "\""$storagePath"\" does not exist or is empty" red
		exit 1
	fi

	### getting the name of last package and its parent folders (if exist) within $storagePath
	getLastPackageName=$(cd "$storagePath" && find * -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

	archiveName=$(echo "$getLastPackageName"|cut -d $'/' -f 2)
	
	echoColoured "Getting $storagePath/$getLastPackageName" yellow
	
	### return 1 if the files are not identical (byte-to-byte comparison)
	if cmp -s "$pathGiven" "$untarWhereTo/$archiveName"; then
		echo "The identical package is already in the target folder, continuing without copy"
	else
		\cp -fv "$storagePath/$getLastPackageName" "$untarWhereTo"
		echo "Copying finished"
	fi
fi

echo "setting env variable AUTOMATION_PACKAGE_NAME_$userToDrop in .bashrc"
set_replace_env_global AUTOMATION_PACKAGE_NAME_"$userToDrop" "$archiveName"

### cleaning error message
errorMsg=""
}

extractPackage()
{
local installationFolderNameSlash=""
local installationFolderName1=""
local installationFolderName=""
local db_config_qa_ptrade_Path=""

### extracting package
echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Extracting $archiveName to $untarWhereTo...\n" yellow

### defining error message for the following block
errorMsg="Error while extracting package, installation not finished"

if [ "$pathGiven" != "" ]; then
	tarPath="$untarWhereTo/$archiveName"
	
	### checking if package file exists
	if ! [ -s "$tarPath" ]; then
		echoColoured "Package \""$tarPath"\" not found or file size equals 0" red
		echo ""
		help_function
		exit 1
	# else
		# echoColoured "Package \""$tarPath"\" is downloaded" green
	fi

	### check that there is only one necessary directory in package
	countResult=$(tar --exclude="*/*" -tf $tarPath|egrep -c $tarFilter)
	
	if [ "$countResult" != 1 ]; then
		echoColoured "Error: there should be only one directory starting with \""$tarFilter"\" in the package \""$tarPath"\", found $countResult. Exiting" red
		exit 1
	else
		installationFolderNameSlash="$(tar --exclude="*/*" -tf $tarPath|egrep $tarFilter)"
	fi

	installationFolderName1=${installationFolderNameSlash%/}
	installationFolderName="$installationFolderName1"_"$userToDrop"
	installationPath="$untarWhereTo"/"$installationFolderName"
else
	tarPath="$storagePath/$getLastPackageName"
	
	### checking if package file exists
	if ! [ -s "$tarPath" ]; then
		echoColoured "Package \""$tarPath"\" not found or file size equals 0" red
		echo ""
		help_function
		exit 1
	# else
		# echoColoured "Package \""$tarPath"\" is downloaded" green
	fi

	### check that there is only one necessary directory in package
	countResult=$(tar --exclude="*/*" -tf $tarPath |egrep -c $tarFilter)
	
	if [ "$countResult" != 1 ]; then
		echoColoured "Error: there should be only one directory starting with \""$tarFilter"\" in the package \""$tarPath"\", found $countResult. Exiting" red
		exit 1
	else
		installationFolderNameSlash="$(tar --exclude="*/*" -tf $tarPath|egrep $tarFilter)"
	fi

	installationFolderName1=${installationFolderNameSlash%/}
	installationFolderName="$installationFolderName1"_"$userToDrop"
	installationPath="$untarWhereTo"/"$installationFolderName"
fi

### defining error message for the following block
errorMsg="Error while removing directory with the same version, installation not finished"

### removing directory with the same version if found
if [ -d "$installationPath" ]; then
	echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Directory with the same version found (\""$installationPath"\"), removing the existing one..." yellow
	rm -rfv $installationPath
	echo ""
fi

### defining error message for the following block
errorMsg="Error while extracting package, installation not finished"

### extracting the package into the renamed target folder
mkdir "$installationPath" && tar xzvf "$tarPath" -C "$installationPath" --strip-components 1

echoColoured "\""$installationFolderName1"\" from the package \""$archiveName"\" was extracted in $untarWhereTo as \""$installationFolderName"\"" green

### cleaning error message
errorMsg=""
}

moveIfFound()
{
installationDir=$(tar --exclude="*/*/*" -tf $tarPath|egrep PTS_)
installationDir=${installationDir##*/}
installationDir=${installationDir%*.tar.gz}
installationDir="$linkPTSfolder"/"$installationDir"

### renaming the directory with old installation if the names are the same
if [ -d "$installationDir" ]; then
	echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Directory with the same version found (\""$installationDir"\"), renaming the existing one..." yellow
	timestamp=$(date -d "today" +"%Y_%m_%d_%H-%M-%S")
	mv -v "$installationDir" ${installationDir}_${timestamp}
	echo ""
fi
}

provideInstallerAnswers()
{
### defining error message for the following block
errorMsg="Error while executing $installLauncher, installation not finished"
echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Launching $installLauncher..." yellow

### setting env variables
echoColoured "\nSetting PTS_AUTOMATION_LOGS_HOME" yellow
export PTS_AUTOMATION_LOGS_HOME="$logsDir"
echo "PTS_AUTOMATION_LOGS_HOME: $PTS_AUTOMATION_LOGS_HOME"

### cleaning expect debug log
echo "" > "$logsDir"/expect_ptradeAPP_debug.log

#getting JAVA_HOME from ebs.env
java_home_default="/usr/java/jre1.8.0_45"

echoColoured "\nSetting PTS_AUTOMATION_JAVA_HOME" yellow
if [ -s /export/home/"$userPermitted"/ebs.env ]; then
	java_home_ebsenv=$(cat /export/home/"$userPermitted"/ebs.env|grep -w JAVA_HOME|cut -f2- -d"=")
	if [ -n "$java_home_ebsenv" ]; then
		export PTS_AUTOMATION_JAVA_HOME="$java_home_ebsenv"
		echo -e "Got PTS_AUTOMATION_JAVA_HOME from JAVA_HOME in ebs.env: $PTS_AUTOMATION_JAVA_HOME\n"
	else
		echoColoured "JAVA_HOME not found in ebs.env, using default value\n" yellow
		export PTS_AUTOMATION_JAVA_HOME="$java_home_default"
	fi
else
	echoColoured "/export/home/$userPermitted/ebs.env not found, using the default value of JAVA_HOME: $java_home_default\n" yellow
	export PTS_AUTOMATION_JAVA_HOME="$java_home_default"
fi

echoColoured "Setting PTS_HOME in ebs.env" yellow
set_replace_ebs_env "PTS_HOME" "$linkPTSfolder"
grep "PTS_HOME" /export/home/"$userPermitted"/ebs.env
echo ""

cd "$installationPath"

msg=""
expect -c "
log_user 1
set timeout 5

proc err_exit {msg} {
	puts "---"
    puts stderr \"\$msg\"
	send \"exit status: \$?\r\"
    exit 1
}

puts \"Reading JAVA_HOME and PTS_AUTOMATION_LOGS_HOME\"

if {[info exists env(PTS_AUTOMATION_LOGS_HOME)]} {
    set automation_logs_home $::env(PTS_AUTOMATION_LOGS_HOME)
	puts \"Found PTS_AUTOMATION_LOGS_HOME\"
} else {
	err_exit \"Error while reading env variable PTS_AUTOMATION_LOGS_HOME\"
}

if {[info exists env(PTS_AUTOMATION_JAVA_HOME)]} {
    set java_home $::env(PTS_AUTOMATION_JAVA_HOME)
	puts \"Found PTS_AUTOMATION_JAVA_HOME\"
} else {
	err_exit \"Error while reading env variable PTS_AUTOMATION_JAVA_HOME\"
}

exp_internal -f \$automation_logs_home/expect_ptradeAPP_debug.log 0

spawn \"./pts_installer.sh\"
sleep 1

expect {
    \"*elect Java Runtime*\" {
        send \"\$java_home\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*ype 1 to install*\" {
        send \"1\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*ype CPT core instance ID*\" {
        send \"1\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*ype 1 to install*\" {
        send \"1\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*ype CPT tidy instance ID*\" {
        send \"3\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*ype 1 to install*\" {
        send \"1\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*ype CPT http instance ID*\" {
        send \"1\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 2
expect {
    \"Edit settings*\" {
        send \"x\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}

expect eof
"

### unsetting env variable
unset PTS_AUTOMATION_LOGS_HOME
unset PTS_AUTOMATION_JAVA_HOME

### cleaning error message
errorMsg=""
}

### reading parameters
readParam

### redirecting all output to a log if verbose and STDOUT if not
if [ "$verboseMode" = "v" ]; then
	exec > >(tee "$logFile") 2>&1
else
	exec 1>> "$logFile"
fi

echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Started"
echo -e "\n---Writing regular output to log $logFile---"
echo -e "***Writing debug output to log $logDebug***\n"

### user-checking
checkCurrentUser

### Taking file from Jenkins
getPackage

### extracting package
extractPackage

### Let's go
echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Starting installation..."

### defining error message for the following block
errorMsg="Error while unlinking, installation not finished"

### checking if PTS link exists and unlinking
if [ -L "$linkPTSfolder/$linkPTSname" ]; then
	echoColoured "\nFound PTS link to $(readlink $linkPTSfolder/$linkPTSname)" yellow
	
	unlink "$linkPTSfolder/$linkPTSname"
	
	echoColoured "PTS link \""$linkPTSfolder/$linkPTSname"\" removed \n" green
else
	echoColoured "PTS link \""$linkPTSfolder/$linkPTSname"\" not found, continuing" yellow
fi

### defining error message for the following block
errorMsg="Error while renaming old installation dir"

### renaming the directory with old installation if the names are the same
moveIfFound

### cleaning error message
errorMsg=""

### Launching installer and providing answers
provideInstallerAnswers
a=$?
if [ $a -ne 0 ]; then
	echo "Error"
	exit 1
fi

### defining error message for the following block
errorMsg="Error while creating link, installation not finished"

### creating link
echoColoured "Creating $linkName link..." yellow
ln -nsfv "$installationPath" "$scriptFolderPath"/"$linkName"

### defining error message for the following block
errorMsg="Error while removing PID file $scriptFolderPath/pid_$linkName, installation not finished"

### removing PID file
rm -f "$pidFile"

### cleaning error message
errorMsg=""

echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Installation finished" green