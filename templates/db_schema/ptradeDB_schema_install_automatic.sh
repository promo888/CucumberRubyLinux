#!/bin/bash

# Init
userPermitted="root"
workingUser="oracle"
archiveName="$1"
argsQty="$#"
scriptFolderPath=$(dirname $(readlink -f "$0"))
scriptName=$(basename "$0")
tarPath="$scriptFolderPath/$archiveName"
untarWhereTo="/export/home/$workingUser"
untarSuccessMessage="The package \""$archiveName"\" was extracted in $untarWhereTo"
startingDropMessage="Start dropping user..."
userToDrop="ptrade"

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

installationFolderNameSlash="$(tar --exclude="*/*" -tf $tarPath | awk '/PT_DB/')"
installationFolderName=${installationFolderNameSlash%/}
installationPath="$untarWhereTo/$installationFolderName"
logFile="$scriptName.log"
installPtradeMode="qa" #can take values "" for production or "qa" for QA

# redirecting output to a log
exec > >(tee "$logFile") 2>&1

# sqlplus  / as sysdba <<EOF
# select username from dba_users where username in ('PTRADE','SDATA') order by 1;
# EOF

# sqlplus  / as sysdba <<EOF
# select count(*) from sdata.schema_version where app_name='SData';
# EOF

checkCurrentUser()
{
local userId
userId="$(id -u $userPermitted)"
if [ "$(id -u)" != "$userId" ]; then
        echo -e "\e[31mError: this script must be run by user \""$userPermitted"\", current user is \""$(whoami)"\", exiting\e[0m" 1>&2
        exit 1
fi
}

checkUserExists()
{
if id -u "$workingUser" >/dev/null 2>&1; then
        echo "User $workingUser exists"
else
        echo -e "\e[31mError: user $workingUser does not exist, exiting\e[0m"
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
checkUserExists

readParam

# Let's go
if [ -d "$installationPath" ]; then
	echo "Directory with the same version found (\""$installationPath"\"), renaming the existing one... \n"
	timestamp=$(date -d "today" +"%Y_%m_%d_%H-%M-%S")
	su - $workingUser -c "mv -v $installationPath ${installationPath}_${timestamp}"
fi

echo "Extracting $archiveName to $untarWhereTo..."
su - $workingUser -c "tar xzf $tarPath -C $untarWhereTo"
echo -e "\e[32m$untarSuccessMessage\n\e[0m"

echo "$startingDropMessage"
# ***** start dropping user *****
echo "Dropping user $userToDrop"
echo ""

su - oracle -c "sqlplus -S / as sysdba " <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR  EXIT SQL.SQLCODE;
SET VERIFY OFF
SET FEEDBACK OFF
SET ECHO OFF
SET DEFINE "^"
DEFINE dropUser=$userToDrop

begin
    if upper('^dropUser') not in ('PTRADE','SDATA','SAPPHIRE','DBOARD') then
        raise_application_error(-20999, 'Not supported user for drop');
    end if;
end;
/

prompt Dropping user $userToDrop, please wait...
declare lUserExists number;
begin
    -- lock user
    execute immediate 'ALTER USER ^dropUser ACCOUNT LOCK';
    -- Kill active sessions
    for i in (select 'ALTER SYSTEM KILL SESSION '''||s.sid ||','|| s.serial# ||''' '  KillSQL from v\$session s where USERNAME=upper('^dropUser'))
    loop
        execute immediate i.KillSQL;
    end loop;
    -- drop user
    commit;
    dbms_lock.sleep(10);
    execute immediate 'drop user ^dropUser cascade';
end;
/
prompt User $userToDrop dropped!

EOF

echo "Recreating ptrade and sdata users"
/export/home/techusr/ovcm/oracle/ptdb/add-user/create_app_users
echo "done!"

echo ""
echo -e "\e[32mDropping user \""$userToDrop"\" finished \n\e[0m"
# ***** finished dropping user *****

# ***** start creating schema *****
echo "Start installing $userToDrop..."
su - $workingUser -c "cd $installationPath && sh install_ptrade_db.sh $installPtradeMode"
# ***** finished creating schema *****
echo ""
echo -e "\e[32mInstallation finished\e[0m"