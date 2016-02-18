#!/bin/bash

### Init
scriptName=$(basename "$0")
scriptFolderPath=$(dirname $(readlink -f "$0"))
baseScriptName=${scriptName%*.sh}
argsQty="$#"
argFirst="$1"
logDir="$scriptFolderPath"
linkName="$USER"
logFile="$logDir"/"$baseScriptName".log
logDebug="$logDir"/"$baseScriptName"_debug.log
mslIP=""
mslUser="msl"
mslPass="msl1"
verboseMode=""

### debug features
debugEnabled="yes"
if ! [ -z "$debugEnabled" ]; then
	exec 5> "$logDebug"
	BASH_XTRACEFD="5"
	PS4='$LINENO: '
	set -x
fi

### redirecting output to a log
exec 3>&1 1>"$logFile"

ErrorToConsoleAndLog()
{
message="$1"
if [ "$verboseMode" = "v" ]; then
	echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $message\e[0m"
else
	echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $message\e[0m"|tee /dev/stderr
fi
}

WarningToConsoleAndLog()
{
message="$1"
if [ "$verboseMode" = "v" ]; then
	echo -e "\n\e[33m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $message\e[0m"
else
	echo -e "\n\e[33m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $message\e[0m"|tee /dev/stderr
fi
}

MessageToConsoleAndLog()
{
message="$1"
if [ "$verboseMode" = "v" ]; then
	echo "$message"
else
	echo "$message"|tee /dev/stderr
fi
}

help_function()
{
MessageToConsoleAndLog "*****************************************************************************************************************************************************"
MessageToConsoleAndLog "The script is for cleaning MSL DB in automation lab, it can be launched only by user ptrade or ptrade1"
MessageToConsoleAndLog "Usage: ./$scriptName"
MessageToConsoleAndLog "Note: launching without -v means silent mode (all output is redirected to a log, only errors would be printed to console)"
MessageToConsoleAndLog ""
MessageToConsoleAndLog "-v                           verbose mode, printing output both to console and to log"
MessageToConsoleAndLog "Usage: ./$scriptName -v"
MessageToConsoleAndLog ""
MessageToConsoleAndLog "-msl:<IP of MSL>             use the given MSL IP"
MessageToConsoleAndLog "Usage: ./$scriptName -msl:<IP of MSL>      "
MessageToConsoleAndLog ""
MessageToConsoleAndLog "-v-msl:<IP of MSL>           use the given MSL IP running in verbose mode"
MessageToConsoleAndLog "Usage: ./$scriptName -v-msl:<IP of MSL>    "
MessageToConsoleAndLog ""
MessageToConsoleAndLog "-help, --help, -h, --h       print the manual"
MessageToConsoleAndLog "Usage: ./$scriptName -help"
MessageToConsoleAndLog ""
MessageToConsoleAndLog "*****************************************************************************************************************************************************"
}

### catching exit
MyExit()
{
	ErrorToConsoleAndLog "Stopped by user"
    exit 1
}
trap MyExit INT # custom message when stopped by user

exit_status=0
giveErrorMsg()
{
exit_status="$?"
if [ $exit_status -ne 0 ]; then
	ErrorToConsoleAndLog "Error"
	echo "exit_status: $exit_status"
	exit 1
fi
}
trap giveErrorMsg EXIT # print error message

anotherExit()
{
ErrorToConsoleAndLog "Terminated"
help_function
exit 1
}
trap anotherExit SIGTERM SIGHUP HUP QUIT PIPE TERM

readParam()
{
if [ "$argsQty" -eq 1 ]; then
	case "$argFirst" in
		-help|--help|help|-h|--h)
			help_function
			exit
			;;
		-v)
			verboseMode="v"
			;;
		-msl:*)
			mslIP=${argFirst//\n}
			mslIP=${mslIP##*:}
			verboseMode=""
			;;
		-v-msl:*)
			mslIP=${argFirst//\n}
			mslIP=${mslIP##*:}
			verboseMode="v"
			;;
		*)
			ErrorToConsoleAndLog "Incorrect argument given - \""$argFirst"\", exiting"
			help_function
			exit 1
			;;
	esac
elif [ "$argsQty" -eq 0 ]; then
	verboseMode=""
else
	ErrorToConsoleAndLog "Error: there could be only one argument after script name, you gave \""$argsQty"\". Exiting"
	help_function
	exit 1
fi
}

function valid_ip()
{
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
    fi
    return $stat
}

readParam

if [ -z "$mslIP" ]; then
	ErrorToConsoleAndLog "Error: there should be a correct MSL IP, you gave empty value: \""$argFirst"\". Exiting"
	help_function
	exit 1
fi

if valid_ip "$mslIP"; then
	echo "MSL IP is valid"
else
	ErrorToConsoleAndLog "Error: there should be a correct MSL IP, you gave \""$mslIP"\". Exiting"
	help_function
	exit 1
fi

### returning the former redirection and redirecting all output to a log if verbose and STDOUT only if not
exec 1>&3
if [ "$verboseMode" = "v" ]; then
	exec > >(tee "$logFile") 2>&1
else
	exec 1> "$logFile"
fi

### starting
echo -e "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Started...\n"

### setting envs
echo "setting MSLdbCleaner_MSL_IP"
export MSLdbCleaner_MSL_IP="$mslIP"
echo "set MSLdbCleaner_MSL_IP: $MSLdbCleaner_MSL_IP"

echo -e "\nsetting MSLdbCleaner_MSL_USER"
export MSLdbCleaner_MSL_USER="$mslUser"
echo "set MSLdbCleaner_MSL_USER: $MSLdbCleaner_MSL_USER"

echo -e "\nsetting MSLdbCleaner_MSL_PWD"
export MSLdbCleaner_MSL_PWD="$mslPass"
echo "set MSLdbCleaner_MSL_PWD: $MSLdbCleaner_MSL_PWD"

echo -e "\nsetting MSLdbCleaner_NAME"
export MSLdbCleaner_NAME="$linkName"
echo "set MSLdbCleaner_NAME: $MSLdbCleaner_NAME"

echo -e "\nsetting MSLdbCleaner_LOGS_HOME"
export MSLdbCleaner_LOGS_HOME="$logDir"
echo -e "set MSLdbCleaner_LOGS_HOME: $MSLdbCleaner_LOGS_HOME\n"

echo "" > "$MSLdbCleaner_LOGS_HOME"/expect_mslDbCleaner_debug_"$MSLdbCleaner_NAME".log

msg=""
automation_logs_home=""
automation_script_name=""
msl_ip=""
msl_user=""
msl_pass=""

expect -c "
log_user 1
set timeout 10

proc err_exit {msg} {
	puts "---"
    puts stderr \"\$msg\"
	send \"exit status: \$?\r\"
    exit 1
}

puts \"Reading MSLdbCleaner_LOGS_HOME\"
if {[info exists env(MSLdbCleaner_LOGS_HOME)]} {
    set automation_logs_home $::env(MSLdbCleaner_LOGS_HOME)
	puts \"Found MSLdbCleaner_LOGS_HOME\"
} else {
	err_exit \"Error while reading env variable MSLdbCleaner_LOGS_HOME\"
}

puts \"Reading MSLdbCleaner_NAME\"
if {[info exists env(MSLdbCleaner_NAME)]} {
    set automation_script_name $::env(MSLdbCleaner_NAME)
	puts \"Found MSLdbCleaner_NAME\"
} else {
	err_exit \"Error while reading env variable MSLdbCleaner_NAME\"
}

exp_internal -f \$automation_logs_home/expect_mslDbCleaner_debug_\$automation_script_name.log 0

puts \"Reading MSLdbCleaner_MSL_IP\"
if {[info exists env(MSLdbCleaner_MSL_IP)]} {
    set msl_ip $::env(MSLdbCleaner_MSL_IP)
	puts \"Found MSLdbCleaner_MSL_IP\"
} else {
	err_exit \"Error while reading env variable MSLdbCleaner_MSL_IP\"
}

puts \"Reading MSLdbCleaner_MSL_USER\"
if {[info exists env(MSLdbCleaner_MSL_USER)]} {
    set msl_user $::env(MSLdbCleaner_MSL_USER)
	puts \"Found MSLdbCleaner_MSL_USER\"
} else {
	err_exit \"Error while reading env variable MSLdbCleaner_MSL_USER\"
}

puts \"Reading MSLdbCleaner_MSL_PWD\"
if {[info exists env(MSLdbCleaner_MSL_PWD)]} {
    set msl_pass $::env(MSLdbCleaner_MSL_PWD)
	puts \"Found MSLdbCleaner_MSL_PWD\"
} else {
	err_exit \"Error while reading env variable MSLdbCleaner_MSL_PWD\"
}

spawn ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o RSAAuthentication=no -o ServerAliveInterval=300 -o ConnectTimeout=300 \$msl_user@\$msl_ip
sleep 1

expect {
	\"*sword*\" {
		send \"\$msl_pass\r\"
	}
	timeout {
		err_exit \"Error: timeout\n\"
		exit 1
	}
}
sleep 1
expect {
	\"*msl@*\" {
		send \"cd /export/home/msl/data\r\"
	}
	timeout {
		err_exit \"Error: timeout\n\"
		exit 1
	}
}
sleep 1
expect {
	\"*msl@*\" {
		send \"rm -f dump.rdb\r\"
	}
	timeout {
		err_exit \"Error: timeout\n\"
		exit 1
	}
}
sleep 1
expect {
	\"*msl@*\" {
		send \"psql redur\r\"
	}
	timeout {
		err_exit \"Error: timeout\n\"
		exit 1
	}
}
sleep 1
expect {
    \"*redur=>*\" {
        send \"\\\d\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*List of relations*\" {
        send \"truncate messages;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_00;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_01;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_02;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_03;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_04;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_05;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_06;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_07;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_08;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_09;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_10;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_11;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_12;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate messages_13;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate redur;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate replays;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*TRUNCATE TABLE*\" {
        send \"truncate sources;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*redur=>*\" {
        send \"commit;\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*COMMIT*\" {
        send \"\\\q\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
set timeout 120
expect {
    \"*msl@*\" {
        send \"/export/home/msl/bin/stop-msl\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*msl@*\" {
        send \"/export/home/msl/bin/start-msl\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*msl@*\" {
        send \"ps -aef\|grep redur\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
set timeout 3
expect {
    \"*msl@*\" {
        send \"ps -aef\|grep redis\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}
sleep 1
expect {
    \"*msl@*\" {
        send \"ps -aef\|grep post\r\"
    }
    timeout {
        err_exit \"\nError: timeout\n\"
    }
}

expect eof
"

echo -e "\n$(date +%Y-%m-%d_%H:%M:%S,%3N)"
MessageToConsoleAndLog "Finished successfully"