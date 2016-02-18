#!/bin/bash

### self-determining
scriptFolderPath=$(dirname $(readlink -f "$0"))
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
userToDrop="ptrade"
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
linkName="PT_DB"
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
argFirst=${1:-} # using parameter default value (here it is "") because of the strict mode
argSecond=${2:-}
argsQty="$#"
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
installationPath=""

storagePath="/export/home/$userPermitted/build_server/Releases/PTS"
storageLocalPath="/export/home/$userPermitted/tmp_storage_$userToDrop"

help_function()
{
	echo "******************************************************************************************************"
	echo "This is a script for ptradeDB schema installation"
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

drop_user()
{
echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Dropping user $userToDrop" yellow

### defining error message for the following block
errorMsg="Error while dropping user, installation not finished"

## sqlplus -S / as sysdba <<EOF
sqlplus / as sysdba <<EOF
SPOOL ptradeDB_drop_user.txt
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR  EXIT SQL.SQLCODE;
SET VERIFY OFF
SET FEEDBACK ON
SET echo ON
set heading off
SET DEFINE "^"

DEFINE dropUser=$userToDrop
prompt sqlplus Dropping user $userToDrop, please wait...
SET SERVEROUTPUT ON

declare 
	lUserExists number;
begin
DBMS_OUTPUT.ENABLE (buffer_size => NULL);

    if upper('^dropUser') not in ('PTRADE','SDATA','SAPPHIRE','DBOARD') then
        raise_application_error(-20999, 'Not supported user for drop');
    end if;
	
DBMS_OUTPUT.PUT_LINE('check if user exists');
	-- check if user exists
	select count(*) into lUserExists from dba_users where upper(username)=upper('^dropUser');
	if (lUserExists=1) then /* if user exists */
		-- lock user
		execute immediate 'ALTER USER ^dropUser ACCOUNT LOCK';
		-- Kill active sessions
		DBMS_OUTPUT.PUT_LINE('Kill active sessions');
		for i in (select 'ALTER SYSTEM KILL SESSION '''||s.sid ||','|| s.serial# ||''' '  KillSQL from v\$session s where USERNAME=upper('^dropUser'))
		loop
			execute immediate i.KillSQL;
		end loop;
		DBMS_OUTPUT.PUT_LINE('commit');
		commit;
		DBMS_OUTPUT.PUT_LINE('dbms_lock.sleep(30)');
		dbms_lock.sleep(30);
		-- drop user
		DBMS_OUTPUT.PUT_LINE('execute immediate drop user dropUser cascade');
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
prompt sqlplus User $userToDrop dropped!
SPOOL OFF

exit;
EOF

### cleaning error message
errorMsg=""

echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Dropping user \""$userToDrop"\" finished" green
echoColoured ""
}

create_app_users()
{
### defining error message for the following block
errorMsg="Error while creating user, installation not finished"

echoColoured "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Creating user $userToDrop..." yellow

# /export/home/techusr/ovcm/oracle/ptdb/add-user/create_app_users

######################################################
###              set_env                       #######
######################################################
function set_env {
   # Set the variables needed for successful run.
   # set the environment
   DIR=${HOME}
   TMPDIR="/etc/ebs";
   DT=`date +%C%y%m%d-%H:%M:%S`
   # LOGDIR="/etc/ebs";   
   # log=${LOGDIR}/create_sapphire_dboard_users_${DT}.log;

   echo "set_env is complete";
}

######################################################
###          check_user_exist                  #######
######################################################
function check_user_exist {
         #This checks the existence of user

user="$1"
USERNAME="NONE"

user_exist_sqlout=`sqlplus -S / as sysdba <<_EOF_
SPOOL ptradeDB_check_user_exist.txt
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR  EXIT SQL.SQLCODE;
set feedback off
set trim on
set verify off
set heading off

prompt sqlplus Checking if user $user exists...

select 'USER', username from dba_users where username=upper('$user');
SPOOL OFF
exit;
_EOF_
`;

#echo "$user_exist_sqlout"
count=`echo $user_exist_sqlout | grep USER | awk -F"USER" '{print $2}' | awk '{print $1}' | wc -l`
#echo "count: $count"

if [ $count -eq 1 ];then
   USERNAME=`echo $user_exist_sqlout | grep USER | awk -F"USER" '{print $2}' | awk '{print $1}'`
   echo "USERNAME: $USERNAME";
   echo "$USERNAME already exists in the database"
    exit
fi

echo "check_user_exist is completed";
}

######################################################
###             create_schema                  #######
######################################################
function create_schema {
                 # This one recreates cae_core schema

# user="$1";
# echo "Creating user $user"

create_user=`sqlplus / as sysdba <<_EOF_
SPOOL ptradeDB_create_schema.txt
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR  EXIT SQL.SQLCODE;
set trim on
set verify off
set heading off
set linesize 150

prompt sqlplus Creating schema...

begin
        execute immediate 'CREATE BIGFILE TABLESPACE PTRADEDATA LOGGING DATAFILE SIZE 500M AUTOEXTEND ON NEXT  50M MAXSIZE UNLIMITED EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT  AUTO';
exception
        when others then null;
end;
/

begin
        execute immediate 'CREATE BIGFILE TABLESPACE PTRADEINDX LOGGING DATAFILE SIZE 500M AUTOEXTEND ON NEXT  50M MAXSIZE UNLIMITED EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT  AUTO';
exception
        when others then null;
end;
/
CREATE USER PTRADE IDENTIFIED BY ptrade
        DEFAULT TABLESPACE PTRADEDATA
        TEMPORARY TABLESPACE TEMP
        QUOTA UNLIMITED ON PTRADEDATA
        QUOTA UNLIMITED ON PTRADEINDX;

GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE JOB, CREATE MATERIALIZED VIEW, UNLIMITED TABLESPACE TO PTRADE;
GRANT CREATE SYNONYM TO PTRADE;
GRANT READ, WRITE ON DIRECTORY DATA_PUMP_DIR TO PTRADE;
grant execute on DBMS_SQL to PTRADE;
grant execute on DBMS_LOB to PTRADE;
grant execute on dbms_application_info  to PTRADE;
grant execute on dbms_xplan to PTRADE;
grant select any dictionary to PTRADE;
grant execute on dbms_workload_repository to PTRADE;
grant administer database trigger to PTRADE;
grant execute on dbms_lock to PTRADE;
grant drop any context to PTRADE;
grant create any context to PTRADE;
grant execute on dbms_flashback to ptrade;
/
prompt sqlplus Finished creating schema
SPOOL OFF
_EOF_
`;

echo "Done"
echo  "SQLPLUS RESULT create_user is:"
echo "$create_user"

echo "create_schema is done";
}
################################################################################
##################### MAIN Main main ###########################################
################################################################################
START_TIME=`date +%C%y%m%d-%H:%M:%S`
echo "START_TIME is $START_TIME";
set_env;
# check_user_exist "$userToDrop";
# create_schema "$userToDrop";
create_schema;

echo "Finished create_app_users at `date +%C%y%m%d-%H:%M:%S` ";

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
	countResult=$(tar --exclude="*/*" -tf $tarPath|egrep -c "$tarFilter")
	
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
	countResult=$(tar --exclude="*/*" -tf $tarPath |egrep -c "$tarFilter")
	
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
create_app_users

### ***** creating schema *****
echoColoured "Start installing $userToDrop..." yellow

### defining error message for the following block
errorMsg="Error while installing schema, installation not finished"

cd "$installationPath"
chmod 755 *.sh
./install_ptrade_db.sh "$installPtradeMode"

### cleaning error message
errorMsg=""

### creating link
echoColoured "Creating link $linkName..." yellow

### defining error message for the following block
errorMsg="Error while creating link, installation not finished"

### creating link
ln -nsfv "$installationPath" "$scriptFolderPath"/"$linkName"

### defining error message for the following block
errorMsg="Error while removing PID file $scriptFolderPath/pid_$userToDrop, installation not finished"

### removing PID file
rm -f "$pidFile"

### cleaning error message
errorMsg=""

echoColoured "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Installation finished" green