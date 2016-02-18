#!/bin/bash

### catching exit
MyExit()
{
	echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Stopped by user\e[0m"|tee /dev/stderr
    exit 1
}
trap MyExit INT # custom message when stopped by user

exit_status=0
giveErrorMsg()
{
exit_status="$?"
if [ $exit_status -ne 0 ]; then
	echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- $errorMsg\e[0m"|tee /dev/stderr
	echo "exit_status: $exit_status"
	exit 1
fi
}
trap giveErrorMsg EXIT # print error message

anotherExit()
{
echo -e "\n\e[31m$(date +%Y-%m-%d_%H:%M:%S,%3N) -- terminated\e[0m"|tee /dev/stderr
exit 1
}
trap anotherExit SIGTERM SIGHUP HUP QUIT PIPE TERM

### checking if the script file is set as executable
if ! [[ -x "$scriptFolderPath/$scriptName" ]]; then
	echo -e "\e[31mError: the script \""$scriptFolderPath/$scriptName"\" is not set as executable, exiting\e[0m\n"
	exit 1
fi

scriptFolderPath=$(dirname $(readlink -f "$0"))
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
ptradehome="/export/home/ptrade"
logDir="$ptradehome"/Automation/logs_PT_APP
logFile="$logDir"/"$baseScriptName".log
echo "">"$logFile"
logDebug="$logDir"/"$baseScriptName"_debug.log
logPTScoreSuccessfulEvent="PTS-C832"
logPTStidySuccessfulEvent="PTS-C601"
searchRequest="execId"
countResult=0

### debug features
exec 5> "$logDebug"
BASH_XTRACEFD="5"
PS4='$LINENO: '
set -x

### getting path to ERs folder if given as an argument
ersPath="$scriptFolderPath/ers"
argFirst=${1:-}
argSecond=${2:-}
if [ "$argFirst" = "ers_path:" ]; then
	shift
	shift
	
	if [ -d "$argSecond" ]; then
		ersPath="$argSecond"
		echo -e "Path to ERs folder given: \""$ersPath"\"\n">>"$logFile"
	else
		echo -e "Error: folder \""$argSecond"\" not found, continuing with the default value of path to ERs folder: \""$ersPath"\"\n">>"$logFile"
	fi
fi

### getting path to PostTrade logs folder if given as an argument
logsPTSpath="$ptradehome"/Automation/PTS/logs
argFirst=${1:-}
argSecond=${2:-}
if [ "$argFirst" = "pts_logs_path:" ]; then
	shift
	shift
	
	if [ -d "$argSecond" ]; then
		logsPTSpath="$argSecond"
		echo -e "Path to PostTrade logs folder given: \""$logsPTSpath"\"\n">>"$logFile"
	else
		echo -e "Error: folder \""$argSecond"\" not found, continuing with the default value of path to PostTrade logs: \""$logsPTSpath"\"\n">>"$logFile"
	fi
fi

argsQty="$#"
if [ "$argsQty" -gt 0 ]; then
	echo "Error: invalid argument(s) found"
	exit 1
fi

### redirecting STDOUT to a log
exec 1>> "$logFile"

echo -e "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Started\n"

foundResult="$(egrep -R "$searchRequest" "$ersPath")"
foundResult="${foundResult//\"}"

if [ "$(ls -A $ersPath)" ]; then
	echo -e "\""$ersPath"\" exists and is not empty"
else
	echo -e "\e[31m\n\""$ersPath"\" does not exist or is empty\e[0m\n"|tee /dev/stderr
	exit 1
fi

if [ "$(ls -A $logsPTSpath)" ]; then
	echo -e "\""$logsPTSpath"\" exists and is not empty\n"
else
	echo -e "\e[31m\n\""$logsPTSpath"\" does not exist or is empty\e[0m\n"|tee /dev/stderr
	exit 1
fi

arr=()
countERs=0
echo "Found \""$searchRequest"\" in \""$ersPath"\":"
while read -r line; do
	if ! [ -z "$line" ]; then
		line="${line//\n}"
		line1="${line##*/}"
		line1="${line1%%:*}"
		line2="${line##*: }"
		arr+=("$line2")
		((countERs+=1))
		echo "$countERs: $line2 in $line1"
	fi
done <<< "$foundResult"

echo ""

arrCoreErrors=()
countCore=0
echo "Found in PTS core log:"
for i in "${arr[@]}"
do
	if egrep "$i" "$logsPTSpath"/pts_core_*.log|egrep "$logPTScoreSuccessfulEvent" >/dev/null; then
		((countCore+=1))
		res="$(egrep "$i" "$logsPTSpath"/pts_core_*.log|egrep "$logPTScoreSuccessfulEvent")"
		res="${res//\n}"
		echo "$countCore: $res"
	else
		arrCoreErrors+=("$i")
		echo "-- Event \""$logPTScoreSuccessfulEvent"\" (which means successful delivery) of $searchRequest \""$i"\" not found in PTS core log"
	fi
done

echo ""

arrTidyErrors=()
countTidy=0
echo "Found in PTS tidy log:"
for i in "${arr[@]}"
do
	if egrep "$i" "$logsPTSpath"/pts_tidy_*.log|egrep "$logPTStidySuccessfulEvent" >/dev/null; then
		((countTidy+=1))
		res="$(egrep "$i" "$logsPTSpath"/pts_tidy_*.log|egrep "$logPTStidySuccessfulEvent")"
		res="${res//\n}"
		echo "$countTidy:"
		echo "$res"
	else
		arrTidyErrors+=("$i")
		echo "-- Event \""$logPTStidySuccessfulEvent"\" (which means successful routing) of $searchRequest \""$i"\" not found in PTS tidy log"
	fi
done

echo ""

if [ "$countERs" = "$countCore" ] && [ "$countERs" = "$countTidy" ]; then
	echo "No difference found: $countERs \""$searchRequest"\" in \""$ersPath"\", PTS core and tidy logs">&2
	echo -e "\nNo difference found: $countERs \""$searchRequest"\" in \""$ersPath"\", PTS core and tidy logs"
else
	echo -e "\nMismatch found: $countERs \""$searchRequest"\" in \""$ersPath"\", $countCore in PTS core log, $countTidy in PTS tidy log.\nSee file \""$logFile"\" for more details\n"|tee /dev/stderr
	if [ ${#arrCoreErrors[@]} -ne 0 ]; then
		echo "Not found in pts core log:"
		for i in "${arrCoreErrors[@]}"
		do
			echo "$i"
		done
	fi
	echo ""
	if [ ${#arrTidyErrors[@]} -ne 0 ]; then
		echo "Not found in pts tidy log:"
		for i in "${arrTidyErrors[@]}"
		do
			echo "$i"
		done
	fi
fi
echo -e "\n-----"