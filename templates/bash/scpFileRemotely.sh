#!/bin/bash

scriptName=$(basename "$0")
scriptFolderPath=$(dirname $(readlink -f "$0"))
baseScriptName=${scriptName%*.sh}
logDir="$scriptFolderPath"
logFile="$logDir"/"$baseScriptName".log
logDebug="$logDir"/"$baseScriptName"_debug.log

ErrorToConsoleAndLog()
{
message="$1"
echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $message\e[0m"|tee /dev/stderr
}

WarningToConsoleAndLog()
{
message="$1"
echo -e "\n\e[33m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $message\e[0m"|tee /dev/stderr
}

MessageToConsoleAndLog()
{
message="$1"
echo "$message"|tee /dev/stderr
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
	# help_function
	exit 1
}
trap anotherExit SIGTERM SIGHUP HUP QUIT PIPE TERM

### debug features
debugEnabled="yes"
if ! [ -z "$debugEnabled" ]; then
	exec 5> "$logDebug"
	BASH_XTRACEFD="5"
	PS4='$LINENO: '
	set -x
fi

exec 1> "$logFile"

### starting
echo -e "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Starting...\n"

host2="${1##*host2:}"
user2="${2##*user2:}"
pwd2="${3##*pwd2:}"
initial_path="${4##*initial_path:}"
target_path="${5##*target_path:}"
file="${6##*file:}"

### setting envs
echo "setting scpFileRemotely_home"
export scpFileRemotely_home="$scriptFolderPath"
echo "set scpFileRemotely_home: $scpFileRemotely_home"

echo "setting scpFileRemotely_host2"
export scpFileRemotely_host2="$host2"
echo "set scpFileRemotely_host2: $scpFileRemotely_host2"

echo "setting scpFileRemotely_user2"
export scpFileRemotely_user2="$user2"
echo "set scpFileRemotely_user2: $scpFileRemotely_user2"

echo "setting scpFileRemotely_pwd2"
export scpFileRemotely_pwd2="$pwd2"
echo "set scpFileRemotely_pwd2: $scpFileRemotely_pwd2"

echo "setting scpFileRemotely_initial_path"
export scpFileRemotely_initial_path="$initial_path"
echo "set scpFileRemotely_initial_path: $scpFileRemotely_initial_path"

echo "setting scpFileRemotely_target_path"
export scpFileRemotely_target_path="$target_path"
echo "set scpFileRemotely_target_path: $scpFileRemotely_target_path"

echo "setting scpFileRemotely_file"
export scpFileRemotely_file="$file"
echo "set scpFileRemotely_file: $scpFileRemotely_file"

echo "" > "$scriptFolderPath"/expect_scpFileRemotely.log

expect_home=""
expect_host2=""
expect_user2=""
expect_pwd2=""
expect_initial_path=""
expect_target_path=""
expect_file=""

expect -c "
log_user 1
set timeout 100

proc err_exit {msg} {
puts \"---\"
	puts stderr \"\$msg\"
	send \"exit status: \$?\r\"
	exit 1
}

puts \"Reading scpFileRemotely_home\"
if {[info exists env(scpFileRemotely_home)]} {
    set expect_home $::env(scpFileRemotely_home)
	puts \"Found scpFileRemotely_home\"
} else {
	err_exit \"Error while reading env scpFileRemotely_home scpFileRemotely_host2\"
}

exp_internal -f \$expect_home/expect_scpFileRemotely.log 0

puts \"Reading scpFileRemotely_host2\"
if {[info exists env(scpFileRemotely_host2)]} {
    set expect_host2 $::env(scpFileRemotely_host2)
	puts \"Found scpFileRemotely_host2\"
} else {
	err_exit \"Error while reading env variable scpFileRemotely_host2\"
}

puts \"Reading scpFileRemotely_user2\"
if {[info exists env(scpFileRemotely_user2)]} {
    set expect_user2 $::env(scpFileRemotely_user2)
	puts \"Found scpFileRemotely_user2\"
} else {
	err_exit \"Error while reading env variable scpFileRemotely_user2\"
}

puts \"Reading scpFileRemotely_pwd2\"
if {[info exists env(scpFileRemotely_pwd2)]} {
    set expect_pwd2 $::env(scpFileRemotely_pwd2)
	puts \"Found scpFileRemotely_pwd2\"
} else {
	err_exit \"Error while reading env variable scpFileRemotely_pwd2\"
}

puts \"Reading scpFileRemotely_initial_path\"
if {[info exists env(scpFileRemotely_initial_path)]} {
    set expect_initial_path $::env(scpFileRemotely_initial_path)
	puts \"Found scpFileRemotely_initial_path\"
} else {
	err_exit \"Error while reading env variable scpFileRemotely_initial_path\"
}

puts \"Reading scpFileRemotely_target_path\"
if {[info exists env(scpFileRemotely_target_path)]} {
    set expect_target_path $::env(scpFileRemotely_target_path)
	puts \"Found scpFileRemotely_target_path\"
} else {
	err_exit \"Error while reading env variable scpFileRemotely_target_path\"
}

puts \"Reading scpFileRemotely_file\"
if {[info exists env(scpFileRemotely_file)]} {
    set expect_file $::env(scpFileRemotely_file)
	puts \"Found scpFileRemotely_file\"
} else {
	err_exit \"Error while reading env variable scpFileRemotely_file\"
}

spawn bash
send \"scp -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o RSAAuthentication=no \$expect_initial_path/\$expect_file \$expect_user2@\$expect_host2:\$expect_target_path/\r\"
sleep 1
expect {
  \"*sword*\" {
	send \"\$expect_pwd2\r\"
  }
  timeout {
	err_exit \"Error: timeout\n\"
	exit 1
  }
}

expect eof
"

### Finishing
echo -e "\n$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Finished\n"
MessageToConsoleAndLog "Copied successfully"