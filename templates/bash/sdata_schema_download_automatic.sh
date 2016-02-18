#!/bin/bash

### self-determining
scriptFolderPath=$(dirname $(readlink -f "$0"))
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
userToDrop="oracle"
procedureName="sdata"
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

### link, logs
linkName="PT_DB"
logsDir="$scriptFolderPath/logs_$linkName"
mkdir -p "$logsDir"
logFile="$logsDir"/"$baseScriptName".log

### debug features
logDebug="$logsDir"/"$baseScriptName"_debug.log
exec 5> "$logDebug"
BASH_XTRACEFD="5" # specify the file descriptor to write the set -x debugging output to
PS4='$LINENO: '
set -x

### behaviour settings
### NOTE! this script will terminate on any error with return value <> 0
set -o errexit    # will cause bash to exit with an error on any simple command failure
set -o pipefail   # will cause bash to exit on any command failure in a pipeline as well
set -o nounset    # fail if using un-initialized variables

### Init
userPermitted="oracle"
argFirst=${1:-} # using parameter default value (here it is "") because of the strict mode
argSecond=${2:-}
argsQty="$#"
untarWhereTo="$scriptFolderPath"
archiveName=""
tarFilter="DB"
installPtradeMode="qa" # can take values "" for production or "qa" for QA
verboseMode=""
pathGiven=""
errorMsg=""
COLOR=""
getLastPackageName=""
getPackageName=""
ipRemote=""
pathRemote=""
userRemote=""

storagePath="/export/home/$userPermitted/build_server/Releases/db_sdata"
storageLocalPath="/export/home/$userPermitted/tmp_storage_$userToDrop"

help_function()
{
	echo "******************************************************************************************************"
	echo "Usage: ./$scriptName"
	echo "Note: launching without -v means silent mode (output only in case of error)"
	echo ""
	echo "-verbose, -v            verbose mode"
	echo "Usage: ./$scriptName -v"
	echo ""
	echo "-n                      find package with the following name in the storage and download it"
	echo "Usage example: ./$scriptName -n package123.tar.gz"
	echo ""
	echo "-nv                     find package with the following name in the storage and download it running in verbose mode"
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
	echo -e "\e[31mError: this script must be launched only by user \""$userPermitted"\", current user is \""$(whoami)"\", exiting\e[0m" 1>&2
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
	errorMsg="Error in set_env_global. Usage: set_env_global var_name var_value. Exiting"
	echo -e "\e[31mError in set_env_global. Usage: set_env_global var_name var_value. Exiting\e[0m"
	exit 1
fi
}

getPackage()
{
echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Getting package..." yellow

### defining error message for the following block
errorMsg="Error while getting package, installation not finished"

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
		 echoColoured "\""$storagePath"\" exists and not empty" green
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

echo "setting env variable AUTOMATION_PACKAGE_NAME_$procedureName in .bashrc"
set_replace_env_global AUTOMATION_DOWNLOADED_PACKAGE_"$procedureName" "$archiveName"

### cleaning error message
errorMsg=""
}

### reading parameters
readParam

### redirecting all output to a log if verbose and STDOUT if not
if [ "$verboseMode" = "v" ]; then
	exec > >(tee "$logFile") 2>&1
else
	exec 1> "$logFile"
fi

echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Started"
echo -e "\n---Writing regular output to log $logFile---"
echo -e "***Writing debug output to log $logDebug***\n"

### user-checking
checkCurrentUser

### Taking file from Jenkins
getPackage

### removing PID file
rm -f "$pidFile"

### cleaning error message
errorMsg=""

echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Download finished" green