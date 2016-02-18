#!/bin/bash

### self-determining
scriptFolderPath=$(dirname $(readlink -f "$0"))
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
userToDrop="sdata1"
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

### envs
export LD_LIBRARY_PATH="/ora01/app/oracle/product/12.1.0/dbhome_1/lib::/usr/lib:/usr/local/lib"
export ORACLE_SID="PTDB"
export DB_UNIQUE_NAME="PTDB_TYOBPDB01M_TLVQ"
export ORACLE_BASE="/ora01/app/oracle"
export PATH="/ora01/app/oracle/product/12.1.0/dbhome_1/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/sbin:/usr/sbin:/usr/local/bin:."
export ORA_NLS33="/ora01/app/oracle/product/12.1.0/dbhome_1/ocommon/nls/admin/data"
export ORACLE_HOME="/ora01/app/oracle/product/12.1.0/dbhome_1"

### link, logs
linkName="SDATA1"
logsDir="$scriptFolderPath/logs_$linkName"
mkdir -p "$logsDir"
logFile="$logsDir"/"$baseScriptName".log
echo "">"$logFile"

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
untarWhereTo="$scriptFolderPath/packages"

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

### Init
userPermitted="oracle"
userPermittedGroup="$(id -g -n $userPermitted)"
argFirst=${1:-}  # using parameter default value (here it is "") because of the strict mode
argSecond=${2:-}
argsQty="$#"
create_user_scriptPath="$scriptFolderPath"
create_user_scriptName="buildSchema_sdata1.sh"
create_user_script="$create_user_scriptPath"/"$create_user_scriptName"
storageLocalPath="/export/home/$userPermitted/tmp_storage_$userToDrop"
storagePath="/export/home/$userPermitted/build_server/Releases/db_sdata"
db_config_sdata_exampleName="db_config_sdata1_example.sql"
db_config_sdata_examplePath="$scriptFolderPath/$db_config_sdata_exampleName"
verboseMode=""
pathGiven=""
errorMsg=""
COLOR=""
getLastPackageName=""
getPackageName=""
installationPath=""

### checking db config example and target file
if ! [ -f "$db_config_sdata_examplePath" ]; then
	echo -e "\e[31mError: $db_config_sdata_examplePath not found, exiting\e[0m"
	exit 1
fi

help_function()
{
	echo "******************************************************************************************************"
	echo "This is a script for sdataDB schema1 installation"
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

drop_user()
{
echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Dropping user $userToDrop" yellow

### defining error message for the following block
errorMsg="Error while dropping user, installation not finished"

sqlplus "$userToDrop"/"$userToDrop" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR  EXIT SQL.SQLCODE;
SET VERIFY OFF
SET FEEDBACK OFF
SET echo ON
set heading off

prompt sqlplus -- Disabling scheduled jobs for user $userToDrop...

-- List scheduled jobs before change
select JOB_NAME, enabled, state from user_scheduler_jobs;

-- Disable all scheduled jobs
begin
  if (USER in ('SYS', 'SYSTEM')) then 
    raise_application_error(-20001, 'DO NOT EXECUTE AS USER '||USER);
  end if;
  dbms_output.enable(500);
  for i in (select JOB_NAME from user_scheduler_jobs where enabled='TRUE')
  loop
    begin 
      --dbms_scheduler.disable(i.job_name);
      dbms_output.put_line('JOB '||i.job_name||' is disabled.');
    exception
      when others then 
        dbms_output.put_line('JOB '||i.job_name||' disable - FAILED.');
    end;
  end loop;
end;
/

-- List scheduled jobs after change
select JOB_NAME, enabled, state from user_scheduler_jobs;

EOF

## sqlplus -S / as sysdba <<EOF
sqlplus / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR  EXIT SQL.SQLCODE;
SET VERIFY OFF
SET FEEDBACK OFF
SET echo ON
set heading off
SET DEFINE "^"

DEFINE dropUser=$userToDrop
prompt sqlplus-- Dropping user $userToDrop, please wait...

declare 
       lUserExists number;
       lWaitForKill number :=300; --seconds to wait for sessions to die
       lStartTime   date;
       lUserSessions number;
begin

    if upper('^dropUser') not in ('SDATA1') then
        raise_application_error(-20999, 'Not supported user for drop');
    end if;
       

       -- check if user exists
       select count(*) into lUserExists from dba_users where upper(username)=upper('^dropUser');
       if (lUserExists=1) then /* if user exists */
              -- lock user
              execute immediate 'ALTER USER ^dropUser ACCOUNT LOCK';
              -- Kill active sessions
              for i in (select 'ALTER SYSTEM KILL SESSION '''||s.sid ||','|| s.serial# ||''' '  KillSQL from v\$session s where USERNAME=upper('^dropUser'))
              loop
                 begin
                     execute immediate i.KillSQL;
                 exception
                     when others then 
                        if (sqlcode=-31) then                  
                          null;
                        end if;
                 end;
              end loop;
              commit;

    -- wait for sessions to die
    lStartTime:=sysdate;
    loop
      select count(*) into lUserSessions 
      from v\$session s 
      where USERNAME=upper('^dropUser');      
      
      if (sysdate>lStartTime+lWaitForKill/1440) then 
        raise_application_error(-20998, 'Drop user - Timeout on killing sessions');
      end if;
      exit when lUserSessions=0 ;
      dbms_lock.sleep(1);
    end loop;
    
    -- drop user
    begin 
      execute immediate 'drop user ^dropUser cascade';
    exception 
      when others then /* Failed to drop user, unlocking the account */ 
        execute immediate 'ALTER USER ^dropUser ACCOUNT UNLOCK';
        raise_application_error(-20998, 'Failed to drop user, unlocking the account');
    end;
  end if;
end;
/
prompt sqlplus-- User $userToDrop dropped!
EOF

### cleaning error message
errorMsg=""

echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Dropping user \""$userToDrop"\" finished" green
echoColoured ""
}

create_user1()
{
### defining error message for the following block
errorMsg="Error while creating user, installation not finished"

echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Creating user $userToDrop..." yellow

### checking the creating script and launching it
if [[ -x "$create_user_script" ]]; then
	cd "$create_user_scriptPath"
	./"$create_user_scriptName" "$userToDrop"
else
	echoColoured "Error: script for creating user \""$create_user_script"\" does not exist or is not executable, exiting" red
	exit 1
fi

# cleaning error message
errorMsg=""

echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Creating $userToDrop user completed" green
echoColoured ""
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
		echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Copying finished"
	fi
	
else
	### checking that mounted directory exists and not empty
	if [ "$(ls -A $storagePath)" ]; then
		echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- \""$storagePath"\" exists and is not empty" green
	else
		echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- \""$storagePath"\" does not exist or is empty, exiting" red
		exit 1
	fi

	### getting the name of last package and its parent folders (if exist) within storage folder
	getLastPackageName=$(cd "$storagePath" && find * -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

	archiveName=$(echo "$getLastPackageName"|cut -d $'/' -f 2)
	
	echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Getting $storagePath/$getLastPackageName" yellow
	
	### return 1 if the files are not identical (byte-to-byte comparison)
	if cmp -s "$pathGiven" "$untarWhereTo/$archiveName"; then
		echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- The identical package is already in the target folder, continuing without copy"
	else
		\cp -fv "$storagePath/$getLastPackageName" "$untarWhereTo"
		echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Copying finished"
	fi
fi

echo "setting env variable AUTOMATION_PACKAGE_NAME_$userToDrop in .bashrc"
set_replace_env_global AUTOMATION_PACKAGE_NAME_"$userToDrop" "$archiveName"

### cleaning error message
errorMsg=""
}

extractPackage()
{
local tarPath=""
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
	if [ $(tar --exclude="*/*" -tf $tarPath|wc -l) != 1 ]; then
		echoColoured "Error: there should be only one directory in the package \""$tarPath"\". Exiting" red
		exit 1
	else
		installationFolderNameSlash="$(tar --exclude="*/*" -tf $tarPath)"
	fi

	installationFolderName1=${installationFolderNameSlash%/}
	installationFolderName="$installationFolderName1"_"$userToDrop"
	installationPath="$untarWhereTo/$installationFolderName"
	db_config_sdata_Path="$installationPath/db_config_sdata.sql"
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
	if [ $(tar --exclude="*/*" -tf $tarPath|wc -l) != 1 ]; then
		echoColoured "Error: there should be only one directory in the package \""$tarPath"\". Exiting" red
		exit 1
	else
		installationFolderNameSlash="$(tar --exclude="*/*" -tf $tarPath)"
	fi

	installationFolderName1=${installationFolderNameSlash%/}
	installationFolderName="$installationFolderName1"_"$userToDrop"
	installationPath="$untarWhereTo/$installationFolderName"
	db_config_sdata_Path="$installationPath/db_config_sdata.sql"
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

### defining error message for the following block
errorMsg="Error while replacing db config file, installation not finished"

### replacing db_config_sdata.sql
if [ -f "$db_config_sdata_Path" ]; then
	cat "$db_config_sdata_examplePath" > "$db_config_sdata_Path"
	echo -e "\e[32m$db_config_sdata_Path was set for $userToDrop:\n\e[0m"
	cat "$db_config_sdata_Path"
	echo ""
else
	echo -e "\e[31mError: \""$db_config_sdata_Path"\" not found, exiting\e[0m"
	exit 1
fi

### cleaning error message
errorMsg=""
}

provideRmanAnswers()
{
### extracting package
echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Removing oracle archive logs with RMAN...\n" yellow

### setting envs
echoColoured "\nsetting PTS_AUTOMATION_LOGS_HOME" yellow
export PTS_AUTOMATION_LOGS_HOME="$logsDir"
echo "set PTS_AUTOMATION_LOGS_HOME: $PTS_AUTOMATION_LOGS_HOME"

echoColoured "\nsetting PTS_AUTOMATION_USERNAME" yellow
export PTS_AUTOMATION_USERNAME="$userToDrop"
echo -e "set PTS_AUTOMATION_USERNAME: $PTS_AUTOMATION_USERNAME\n"

### defining error message for the following block
errorMsg="Timeout or inner expect error while executing rman, installation not finished"

msg=""
automation_logs_home=""
automation_script_username=""
expect -c "
log_user 1
set timeout 15

proc err_exit {msg} {
	puts "---"
    puts stderr \"\$msg\"
	send \"exit status: \$?\r\"
    exit 1
}

puts \"Reading PTS_AUTOMATION_LOGS_HOME\"

if {[info exists env(PTS_AUTOMATION_LOGS_HOME)]} {
    set automation_logs_home $::env(PTS_AUTOMATION_LOGS_HOME)
	puts \"Found PTS_AUTOMATION_LOGS_HOME\"
} else {
	err_exit \"Error while reading env variable PTS_AUTOMATION_LOGS_HOME\"
}

puts \"Reading PTS_AUTOMATION_USERNAME\"

if {[info exists env(PTS_AUTOMATION_USERNAME)]} {
    set automation_script_username $::env(PTS_AUTOMATION_USERNAME)
	puts \"Found PTS_AUTOMATION_USERNAME\"
} else {
	err_exit \"Error while reading env variable PTS_AUTOMATION_USERNAME\"
}

exp_internal -f \$automation_logs_home/expect_rman_debug_\$automation_script_username.log 0

spawn bash

send \"rman\r\"
sleep 2
expect {
    \"*Recovery Manager: Release*\" {
        send \"connect target\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 2
expect {
    \"*connected to target database:*\" {
        send \"delete force archivelog all completed before 'sysdate -2/24';\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 2

expect {
    \"*Do you really want to delete the above objects (enter YES or NO)*\" {
        send \"YES\r\"
    }
	\"*specification does not match any archived log in the repo*\" {
        send \"exit\r\"
		exit 0
    }
	\"*using target database control file instead of recovery catalog*\" {
        send \"exit\r\"
		exit 0
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 3
expect {
    \"*Deleted*objects\" {
        send \"exit\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}

expect eof
"

### cleaning error message
errorMsg=""

echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Finished RMAN\n" green
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
echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Starting installation..." yellow

### Removing oracle archive logs with RMAN
provideRmanAnswers

### ***** dropping user *****
drop_user

### ***** creating user *****
create_user1

### ***** creating schema *****
echoColoured "Start installing $userToDrop..." yellow

### defining error message for the following block
errorMsg="Error while installing schema, installation not finished"

cd "$installationPath"
chmod 755 *.sh
./install_db_sdata.sh "$userToDrop"

### cleaning error message
errorMsg=""

### creating link
echoColoured "Creating link $linkName..." yellow

### defining error message for the following block
errorMsg="Error while creating link, installation not finished"

ln -nsfv "$installationPath" "$scriptFolderPath"/"$linkName"

### defining error message for the following block
errorMsg="Error while removing PID file $scriptFolderPath/pid_$userToDrop, installation not finished"

### removing PID file
rm -f "$pidFile"

### cleaning error message
errorMsg=""

echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Installation finished" green