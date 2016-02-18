#!/bin/bash

##################################################################################################
# Target: Create a database user for Sapphire
# Inputs :
##################################################################################################

#behaviour settings
##################################################################################################
# NOTE! this script will terminate on any error with return value <> 0                           #
set -o errexit    # will cause bash to exit with an error on any simple command failure          #
set -o pipefail   # will cause bash to exit on any command failure in a pipeline as well         #
set -o nounset    # faile using un-initialized variables                                         #
##################################################################################################
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
logDir=""
userhome="/export/home/$USER"
if [ "$USER" = "oracle" ]; then
	logDir="$userhome"/Automation/logs_PT_DB1
else
	echo -e "\e[31mError: this script must be launched only by user \""oracle"\", current user is \""$(whoami)"\", exiting\e[0m" 1>&2
	exit 1
fi
logFile="$logDir"/"$baseScriptName".log
echo "" > "$logFile"
searchPattern="ORA-\\|SP2-"
set +o nounset
forceDrop=${2:NO}
set -o nounset

sqlplus -s "/ as sysdba" <<EOF >"$logFile"

set echo on
set feedback on
whenever sqlerror continue
whenever oserror  continue

create user $1 identified by $1 ;
grant CREATE JOB							  to $1;
grant CREATE TABLE							  to $1;
grant CONNECT, RESOURCE, unlimited tablespace to $1;
grant execute on DBMS_SESSION                 to $1;
grant execute on DBMS_LOCK                    to $1;
grant execute on DBMS_SCHEDULER				  to $1;
grant execute on DBMS_LOB                     to $1;
grant execute on DBMS_FLASHBACK               to $1;
grant CREATE ANY CONTEXT                      to $1;
grant DROP ANY CONTEXT                        to $1;
grant CREATE VIEW                             to $1;
grant CREATE MATERIALIZED VIEW                to $1;
grant CREATE SYNONYM                          to $1;
grant SELECT on V_\$DATABASE                  to $1;
grant SELECT on V_\$INSTANCE                  to $1;
grant SELECT on V_\$SESSION                   to $1;
grant CREATE TRIGGER                          to $1;
grant administer database trigger             to $1;
grant debug connect session                   to $1;
EOF

set +o errexit
errorCount=$(grep -c ${searchPattern} ${logFile} )
set -o errexit
if [ $errorCount -ne 0 ]; then
  grep  ${searchPattern} "${logFile}"
  echo ">>>>> Error count is $errorCount"
  exit $errorCount;
else
  echo ">>>>> ${logFile} log file is clear!"
fi;

echo ">>>>> User creation completed OK. "
exit 0 #success...