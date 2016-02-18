#!/bin/bash

function debugEcho() {
##################################################################################
# Target: Display msgs if in debug mode
##################################################################################
    if [ $debugMode -eq 1 ]; then 
        echo "debug:>>>> $1"
    fi
}

function show_usage() {
##################################################################################
# Target: Display usage
##################################################################################
echo "Target: backup schema before upgrade or rollback from a backup"
echo "Usage:"
echo "1. Display this help:"
echo "./db_bkp_rlbk.sh -help "
echo "2. Backup/Rollback:"
echo "./db_bkp_rlbk.sh -action [$CONST_BACKUP|$CONST_ROLLBACK] -app appName -app_schema schemaName [-rollback_schema bkp_schemaName] [-oracle_dir oracleDirectoryName] [-drop_target]"
echo "  Mandatory:: -action : If '$CONST_BACKUP' then clone schemaName to bkp_schemaName schema, then set the backup tables to read_noly mode and lock the user"
echo "  Mandatory:: -action : If '$CONST_ROLLBACK' then clone bkp_schemaName to schemaName schema, then set the tables to read/write mode and unlock the user"
echo "  Mandatory:: -app appName : One of sdata|dboard|ptrade|sapphire application that the utility id about to backup/rollback"
echo "  Mandatory:: -app_schema schemaName : The schema name used by the application"
echo "  Optional :: -rollback_schema bkp_schemaName : Default value is 'schemaName'_BKP. The schema name used to backup current schemaName. "
echo "  Optional :: -oracle_dir oracleDirectoryName : Default value is DATA_PUMP_DIR. Oracle oracleDirectoryName directory used for expdp/impdp. check dba_directory view for available directories."
echo "  Optional :: -drop_target: If specified at $CONST_BACKUP then bkp_schemaName is dropped"
echo "                            If specified at $CONST_ROLLBACK then schemaName is dropped"
echo " "
echo "Backup example:"
echo "To backup DBOARD schema for the dashboard application. If a backup schema already exists drop it and create a new backup. "
echo "./db_bkp_rlbk.sh -action $CONST_BACKUP -app Dashboard -app_schema DBOARD -drop_target"
echo " "
echo "To recover from DBOARD backup:"
echo "./db_bkp_rlbk.sh -action $CONST_ROLLBACK -app Dashboard -app_schema DBOARD "
echo "Note that -drop_target is not used, therefore DBOARD schema should not exist."
}

function isSchemaExist() {
##################################################################################
# Target: check that the schema exists and no sessions connected to it
# Inputs:
#   param1 - Connection string 
#   param2 - schema name (case insensitive) 
##################################################################################
    local connectString="$1"
    local schemaName="$2"
    local schemaCount=0

    schemaCount=$(sqlplus -s $connectString <<EOF
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    WHENEVER OSERROR  EXIT SQL.SQLCODE;
    set feedback off 
    set heading off
    set echo off
    select count(*) from dba_users where upper(username)=upper('$schemaName');
EOF
)
#    schemaCount=${schemaCount:1} #extract leading character 
    schemaCount="$(echo -e "${schemaCount}" | tr -d '[[:space:]]')"
    if [ -z "$schemaCount" ]; then 
        schemaCount=0
    fi
    echo "$schemaCount"
}

function isSessionConnected() {
##################################################################################
# Target: check that the schema exists and no sessions connected to it
# Inputs:
#   param1 - Connection string 
#   param2 - schema name (case insensitive) 
##################################################################################
    local connectString="$1"
    local schemaName="$2"
    local sessionsCount=0;
    
    sessionsCount=$(sqlplus -s $connectString <<EOF
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    WHENEVER OSERROR  EXIT SQL.SQLCODE;
    set feedback off 
    set heading off
    set echo off
    select count(*) from v\$session where upper(username)=upper('$schemaName') and rownum<200;
EOF
)
    sessionsCount="$(echo -e "${sessionsCount}" | tr -d '[[:space:]]')"
    echo "$sessionsCount"
}

function changeTablesState() {
##################################################################################
# Target: Set all schema tables to a specific state (RO/RW)
# Inputs:
#   param1 - Connection string 
#   param2 - schema name (case insensitive) 
#   param3 - target tables state. 
##################################################################################
    local CONNECT_STRING="$1"
    local SCHEMA_NAME=$2
    local READ_ONLY="NO"
    local TO_STATE="READ ONLY"

    if [ "$3" == "RW" ]; then
        READ_ONLY="YES"
        TO_STATE="READ WRITE"
    fi 

    echo ">>>>>>> setting $SCHEMA_NAME tables to $TO_STATE mode"
    sqlplus -s $CONNECT_STRING<<EOF
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    WHENEVER OSERROR  EXIT SQL.SQLCODE;
    set feedback off 
    set heading off
    set echo off
    begin 
        if ( '${TO_STATE}'='READ ONLY') then 
            FOR I IN (SELECT OWNER||'.'||TRIGGER_NAME TG_NAME from DBA_TRIGGERS WHERE owner=upper('$SCHEMA_NAME'))
            LOOP
                EXECUTE IMMEDIATE 'ALTER TRIGGER '||I.TG_NAME||' DISABLE';
            END LOOP;
        end if;
    end;
/
    begin 
        for i in (select OWNER||'.'||table_name as tableName from dba_tables where read_only='$READ_ONLY' and owner=upper('$SCHEMA_NAME'))
        loop
            execute immediate 'ALTER TABLE '|| i.tableName || ' $TO_STATE';
        end loop;
    end;
/
    begin 
        if ( '${TO_STATE}'='READ WRITE') then 
            FOR I IN (SELECT OWNER||'.'||TRIGGER_NAME TG_NAME from DBA_TRIGGERS WHERE owner=upper('$SCHEMA_NAME'))
            LOOP
                EXECUTE IMMEDIATE 'ALTER TRIGGER '||I.TG_NAME||' ENABLE';
            END LOOP;
        end if;
    end;
/

EOF
}

function drop_schema(){
##################################################################################
# Target: Set all schema tables to a specific state (RO/RW)
# Inputs:
#   param1 - Connection string 
#   param2 - schema name (case insensitive) 
##################################################################################
    local CONNECT_STRING="$1"
    local SCHEMA_NAME=$2

    echo ">>>>>>> Dropping schema $SCHEMA_NAME"
    sqlplus -s $CONNECT_STRING<<EOF
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    WHENEVER OSERROR  EXIT SQL.SQLCODE;
    set feedback off 
    set heading off
    set echo off

    declare tmp number;
    begin 
        select count(*) into tmp from dba_users where upper(username)=upper('$SCHEMA_NAME');
        if tmp=1 then 
            execute immediate 'drop user $SCHEMA_NAME cascade';
        end if;
    end;
/
EOF
}

function getOracleDirectory() {
##################################################################################
# Target: Get the OS path for specified Oracle directory 
# Inputs:
#   param1 - oracle connect string
#   param2 - Oracle directory name (case insensitive)
# Output: Oracle directory OS path ending with '/'
##################################################################################
    local connectString=$1
    local oracleDirectoryName="$2"  
    local oracleDirectoryLocation=""
    
    oracleDirectoryLocation=$(sqlplus -s $connectString <<EOF
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    WHENEVER OSERROR  EXIT SQL.SQLCODE;
    set feedback off 
    set heading off
    set echo off
    select directory_path from dba_directories where upper(directory_name)=upper('$oracleDirectoryName');
EOF
)
    oracleDirectoryLocation=${oracleDirectoryLocation:1} #extract leading character 
    
    if [ -z "$oracleDirectoryLocation" ]; then #no such directory
#        echo "Invalid Oracle directory $oracleDirectoryName "
        exit 1
    fi
    if [ "${oracleDirectoryLocation: -1}" != '/' ]; then 
        oracleDirectoryLocation="${oracleDirectoryLocation}/"
    fi
    echo "$oracleDirectoryLocation"
}

function check_log() {
#############################################################################
# Target: Check that a file does not contain a set of patterns
# Inputs:
#   param1 - file name 
#   param2 - patterns that should not exists in the file
# Output: 
#       0 - File is clear,                                                     
#       1 - File does not exist, or error(s) found                                               
#   
##################################################################################

###process function in parameters
   local logFile="$1"
   local searchPattern=""
   local errorCount=0;
   
   set +o nounset  #allow unbind parameters to check parameter $2
   searchPattern=${2:-^ORA-\\|^LRM-}
   ignorePattern="^ORA-39082\\|^ORA-39168\\|^ORA-39346"

   debugEcho "Checking log file: $logFile"
   debugEcho "Search pattern is $searchPattern "
   debugEcho "Ignore pattern is $ignorePattern "
   
   set -o nounset
    if [ -f "$logFile" ]; then 
        #grep for errors, if none found return 0 to avoid failures
        set +o pipefail #grep NOT finding patterns exit code >1
        errorCount=$(grep ${searchPattern} "${logFile}" |grep -v ${ignorePattern} | wc -l )
        set -o pipefail
        debugEcho "Error count in log is: $errorCount"
    else 
        echo "Log file not found"
        exit 1
    fi;
    if [ $errorCount -gt 0 ]; then 
        #display errors if found in file
        grep  ${searchPattern} "${logFile}" |grep -v ${ignorePattern}
        exit 1
    fi;
    return 0 
} 


# # # # # # # # # # # # # # # # # # # # # # 
 #  #  #   S T A R T    H E R E!!!   # # #
# # # # # # # # # # # # # # # # # # # # # # 
set -x
exec 5> debug_db_bkp_rlbk.txt
BASH_XTRACEFD="5"
PS4='$LINENO: '

#behaviour settings
#### NOTE! this script will terminate on any error with return value <> 0                           
set -o errexit    # will cause bash to exit with an error on any simple command failure          
set -o pipefail   # will cause bash to exit on any command failure in a pipeline as well         
set -o nounset    # fail if using un-initialized variables                                         

######################################################################################
# Process input parameters and init variables
######################################################################################
#Hard coded values and defautls(for now...)
CONST_BACKUP="backup"
CONST_ROLLBACK="rollback"
EBS_BR_TARGET_VER="v"
EBS_BR_PARALLEL=8
EBS_BR_FORCE_DROP="NO"
EBS_BR_RECOVER_FROM_FILE="NO"
ORACLE_CONNECT_STRING="/ as sysdba"
EBS_BR_ORA_DIRECTORY="DATA_PUMP_DIR"

DATE=$(date +"%Y.%m.%d.%H.%M.%S")
exitErrorCode=0
exitScript=0
debugMode=0
skipSchemaNameValidation=0

#No parameters at all
if [[ $# -eq 0 ]] ; then 
    show_usage
    exit 1
fi

#loop over parameters list 
while [[ $# -ge 1 ]]
do
    key="$1"
    case $key in
        -app)
            EBS_BR_APP="$2"
            shift # past argument
            ;;
        -action)
            EBS_BR_ACTION="$2"
            shift # past argument
            ;;
        -app_schema)
            APP_SCHEMA="$2"
            shift # past argument
            ;;
        -rollback_schema)
            RLBK_SCHEMA="$2"
            shift # past argument
            ;;
        -oracle_dir)
            EBS_BR_ORA_DIRECTORY="$2"
            shift # past argument
            ;;
        -drop_target)
            EBS_BR_FORCE_DROP="YES"
            ;;
        -parallel)
            EBS_BR_PARALLEL="$2"
            shift # past argument
            ;;
        -connect)
            ORACLE_CONNECT_STRING="$2"
            shift # past argument
            ;;
        -ver)
            EBS_BR_TARGET_VER="$2"
            shift # past argument
            ;;
        -dump_file)
            BASE_FILE_NAME="$2"
            EBS_BR_DUMP_FILE="$BASE_FILE_NAME"
            shift # past argument
            ;;
        -from_file)
            EBS_BR_RECOVER_FROM_FILE="YES"
            ;;
        -debug)
            debugMode=1
            ;;
        -help)
            show_usage
            exitScript=1
            ;;
        -no_validation)
            skipSchemaNameValidation=1
            ;;
        *)
            show_usage 
            exitErrorCode=1
            exitScript=1
            ;;
    esac
    shift # past argument or value
done #loop over activation arguments 

if [ $exitScript -eq 1 ]; then 
    exit $exitErrorCode
fi 

#validate mandatory values 
exitWithError=0
set +o nounset

#Application name [sapphire/sdata/ptrade/dashboard]
if [ -z "$EBS_BR_APP" ]; then 
    echo "-app parameter is mandatory"
    show_usage 
    exit 1
fi

#backup/rollback parameter
if [[ -z "$EBS_BR_ACTION"  || ( $EBS_BR_ACTION != $CONST_BACKUP && $EBS_BR_ACTION != $CONST_ROLLBACK ) ]]; then 
    echo "-action parameter is mandatory. Valid values are $CONST_BACKUP or $CONST_ROLLBACK"
    show_usage 
    exit 1

fi

#Application schema name
if [[ ( $EBS_BR_RECOVER_FROM_FILE != "YES")  &&  ( -z "$APP_SCHEMA") ]]; then 
    echo "-app_schema parameter is mandatory"
    show_usage 
    exit 1
elif [[ $skipSchemaNameValidation -eq 0 && !( ${APP_SCHEMA^^} == DBOARD || ${APP_SCHEMA^^} == SDATA || ${APP_SCHEMA^^} == PTRADE || ${APP_SCHEMA^^} == SAPPHIRE ) ]]; then 
    echo "-app_schema Unsupported schema name. Valid schemas are DBOARD|SDATA|PTRADE|SAPPHIRE"
    show_usage 
    exit 1
fi

#Rollback/backup schema name 
if [ -z "$RLBK_SCHEMA"  ]; then 
    if [ -n "$APP_SCHEMA" ]; then 
        RLBK_SCHEMA="${APP_SCHEMA}_BKP"
    elif  [ "$EBS_BR_RECOVER_FROM_FILE" != "YES" ]; then #No source/target shcema names and not rollback from file
        echo "Missing -rollback_schema or -app_schema arguments"
        show_usage 
        exit 1
    fi
fi

#dump file name 
if [[ "$EBS_BR_RECOVER_FROM_FILE" != "YES" && -z "$APP_SCHEMA" ]]; then 
    echo "-app_schema parameter is mandatory"
    show_usage 
    exit 1
fi

#set source and target schemas according to action
if [ "$EBS_BR_ACTION" == "$CONST_BACKUP" ]; then 
    EBS_BR_SOURCE_SCHEMA="$APP_SCHEMA"
    EBS_BR_TARGET_SCHEMA="$RLBK_SCHEMA"
else 
    EBS_BR_SOURCE_SCHEMA="$RLBK_SCHEMA"
    EBS_BR_TARGET_SCHEMA="$APP_SCHEMA"
fi

#dump file name 
if [ -z "$EBS_BR_DUMP_FILE" ]; then 
    if [ "$EBS_BR_RECOVER_FROM_FILE" == "YES" ]; then 
        echo "Can't recover from file without dump file name"        
        show_usage 
        exit 1
    else 
        BASE_FILE_NAME="${EBS_BR_APP}_${EBS_BR_ACTION}_${EBS_BR_TARGET_VER}_${APP_SCHEMA}_${DATE}"
    fi
fi


#if you are here - all params should be set 
set -o nounset

#Set dependent parameters
OS_DUMP_DIR_DEST="$(getOracleDirectory "$ORACLE_CONNECT_STRING" "$EBS_BR_ORA_DIRECTORY")"
debugEcho "Dump directory path is: $OS_DUMP_DIR_DEST "
EBS_BR_DUMP_FILE="${BASE_FILE_NAME}.dmp"    
EBS_BR_EXPORT_LOG_FILE="${EBS_BR_DUMP_FILE}.expdp.log"
EBS_BR_IMPORT_LOG_FILE="${EBS_BR_DUMP_FILE}.impdp.log"



######################################################################################
#   Validations
######################################################################################
#Validate source schema exists
tmp=$(isSchemaExist  "$ORACLE_CONNECT_STRING" "$EBS_BR_SOURCE_SCHEMA" )
if [ $tmp == 0 ]; then 
    echo "$EBS_BR_ACTION FAILED! $EBS_BR_SOURCE_SCHEMA schema does not exist"
    exit 1
fi;

tmp=$(isSchemaExist  "$ORACLE_CONNECT_STRING" "$EBS_BR_TARGET_SCHEMA" )
debugEcho "isSchemaExist  $ORACLE_CONNECT_STRING  $EBS_BR_TARGET_SCHEMA is $tmp "
dropTargetSchema=0
if [ $tmp == 1 ]; then 
    if [ $EBS_BR_FORCE_DROP == "YES" ]; then 
        dropTargetSchema=1
    else 
        echo "$EBS_BR_ACTION FAILED! $EBS_BR_TARGET_SCHEMA schema exist. Drop the schema or use -drop_target argument"
        exit 1    
    fi
fi 

tmp=$(isSessionConnected  "$ORACLE_CONNECT_STRING" "$EBS_BR_TARGET_SCHEMA" )
debugEcho "isSessionConnected  $ORACLE_CONNECT_STRING  $EBS_BR_TARGET_SCHEMA is $tmp"
if [ $tmp != 0 ]; then 
    echo "$EBS_BR_ACTION FAILED! There are sessions connected to $EBS_BR_TARGET_SCHEMA schema. Disconnect/kill sessions and retry"
    exit 1
fi;


######################################################################################
#   Backup - Change source tables to read only for consistent dump
######################################################################################
if [ "$EBS_BR_ACTION" == "$CONST_BACKUP" ]; then 
    changeTablesState "$ORACLE_CONNECT_STRING" "$EBS_BR_SOURCE_SCHEMA" "RO"
fi


###########################################
#   Export schema to dump file 
###########################################
debugEcho "Exporting schema $EBS_BR_SOURCE_SCHEMA. Log file is: ${OS_DUMP_DIR_DEST}$EBS_BR_EXPORT_LOG_FILE "
expdpCMD="expdp '"$ORACLE_CONNECT_STRING"'   STATUS=0  schemas=$EBS_BR_SOURCE_SCHEMA directory=$EBS_BR_ORA_DIRECTORY dumpfile=$EBS_BR_DUMP_FILE logfile=$EBS_BR_EXPORT_LOG_FILE "
set +o errexit 
debugEcho "Export command is: $expdpCMD "
$expdpCMD
set -o errexit 
check_log "${OS_DUMP_DIR_DEST}$EBS_BR_EXPORT_LOG_FILE"


######################################################################################
#   Backup - Change source tables to read write
######################################################################################
if [ "$EBS_BR_ACTION" == "$CONST_BACKUP" ]; then 
    changeTablesState "$ORACLE_CONNECT_STRING" "$EBS_BR_SOURCE_SCHEMA" "RW"
fi

###########################################
#   Drop target schema if exists
###########################################
if [  $dropTargetSchema -eq 1 ]; then 
    drop_schema "$ORACLE_CONNECT_STRING" "$EBS_BR_TARGET_SCHEMA"
fi

###########################################
#set the exclude according to application and export log file 
###########################################
debugEcho "Case schema name: ${APP_SCHEMA^^} "
skip_jobs=" "
set +o pipefail #grep NOT finding patterns exit code >1
case ${APP_SCHEMA^^} in
    DBOARD)
        debugEcho "CASE entry is: DBOARD "
        objPathCout=$(grep "SCHEMA_EXPORT/JOB" "${OS_DUMP_DIR_DEST}$EBS_BR_EXPORT_LOG_FILE" | wc -l )
        if [ $objPathCout -gt 0 ]; then 
            skip_jobs="$skip_jobs EXCLUDE=SCHEMA_EXPORT/JOB"
        fi
        objPathCout=$(grep "SCHEMA_EXPORT/REFRESH_GROUP" "${OS_DUMP_DIR_DEST}$EBS_BR_EXPORT_LOG_FILE" | wc -l )
        if [ $objPathCout -gt 0 ]; then 
            skip_jobs="$skip_jobs EXCLUDE=SCHEMA_EXPORT/REFRESH_GROUP"
        fi
        ;;
    PTRADE)
        debugEcho "CASE entry is: PTRADE "
#        tmp1=$(grep "SCHEMA_EXPORT/EVENT/TRIGGER" "${OS_DUMP_DIR_DEST}$EBS_BR_EXPORT_LOG_FILE")
#        echo "tmp1= $tmp1"
        objPathCout=$(grep "SCHEMA_EXPORT/EVENT/TRIGGER" "${OS_DUMP_DIR_DEST}$EBS_BR_EXPORT_LOG_FILE" | wc -l )
        if [ $objPathCout -gt 0 ]; then 
            skip_jobs="$skip_jobs EXCLUDE=SCHEMA_EXPORT/EVENT/TRIGGER"
        fi
        ;;
esac   
debugEcho "Exclude is: $skip_jobs"
set -o pipefail

###########################################
#   Import schema from dump file 
###########################################
echo ">>>>>>> Importing schema $EBS_BR_TARGET_SCHEMA from dump file ${EBS_BR_DUMP_FILE}. Log file is: ${OS_DUMP_DIR_DEST}$EBS_BR_IMPORT_LOG_FILE "
expdpCMD="impdp '"$ORACLE_CONNECT_STRING"' STATUS=0 $skip_jobs TRANSFORM=SEGMENT_CREATION:n remap_schema=$EBS_BR_SOURCE_SCHEMA:$EBS_BR_TARGET_SCHEMA directory=$EBS_BR_ORA_DIRECTORY dumpfile=$EBS_BR_DUMP_FILE logfile=$EBS_BR_IMPORT_LOG_FILE "
set +o errexit 
debugEcho "import command is: $expdpCMD "
$expdpCMD
set -o errexit 
echo ">>>>>>> Checking impdp  log ${OS_DUMP_DIR_DEST}$EBS_BR_IMPORT_LOG_FILE for errors"
check_log "${OS_DUMP_DIR_DEST}$EBS_BR_IMPORT_LOG_FILE"


######################################################################################
#   Backup - Change target tables to read only and lock schema
#   Recovery - Change target tables to read write and unlock schema
######################################################################################
if [ "$EBS_BR_ACTION" == "$CONST_BACKUP" ]; then 
    changeTablesState "$ORACLE_CONNECT_STRING" $EBS_BR_TARGET_SCHEMA "RO" 
    ACCOUNT_STATUS="Lock"
    SCHEDULER_STATUS="TRUE"
    SCHEDULER_ACTION="disable"
else    
    changeTablesState "$ORACLE_CONNECT_STRING" $EBS_BR_TARGET_SCHEMA "RW" 
    ACCOUNT_STATUS="Unlock"
    SCHEDULER_STATUS="FALSE"
    SCHEDULER_ACTION="enable"
fi
echo ">>>>>>> ${ACCOUNT_STATUS}ing login option for schema $EBS_BR_TARGET_SCHEMA and  ${SCHEDULER_ACTION} scheduler jobs"
sqlplus -s $ORACLE_CONNECT_STRING<<EOF
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    WHENEVER OSERROR  EXIT SQL.SQLCODE;
    set feedback off 
    set heading off
    set echo off

    alter user $EBS_BR_TARGET_SCHEMA identified by ${EBS_BR_TARGET_SCHEMA,,};
    alter user $EBS_BR_TARGET_SCHEMA account $ACCOUNT_STATUS;
    begin
        for i in (  select owner||'.'||job_name as job from dba_scheduler_jobs where owner='$EBS_BR_TARGET_SCHEMA' and enabled='$SCHEDULER_STATUS')
        loop
            dbms_scheduler.${SCHEDULER_ACTION}(i.job);
        end loop;
    end;
    /
EOF


###########################################
#   End 
###########################################
echo ">>>>>>> $EBS_BR_ACTION completed OK!"
