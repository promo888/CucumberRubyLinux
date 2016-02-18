#!/bin/bash

redisPort=""
username="ptrade"
ptradehome="/export/home/$username"
redisPath="$ptradehome"/redis/src
localredis=""
output=""
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
logDir="$ptradehome"/Automation/logs_PT_APP
mkdir -p "$logDir"
logFile="$logDir"/"$baseScriptName".log
echo "" > "$logFile"
logDebug="$logDir"/"$baseScriptName"_debug.log
echo "" > "$logDebug"
RedisMonitor=""
RedisServerLog="$logDir"/"$baseScriptName"_rserv.log

### debug features
exec 5> "$logDebug"
BASH_XTRACEFD="5"
PS4='$LINENO: '
set -x

### catching exit status
abnormalExit()
{
echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- exit" >> "$logFile"
echo "Terminated" >> "$logFile"
exit 1
}
trap abnormalExit 1 2 3 13 15 SIGTERM SIGHUP HUP QUIT PIPE TERM

normalExit()
{
echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- exit" >> "$logFile"
exit 0
}
trap abnormalExit 0

argsQty="$#"
if [ "$argsQty" -gt 2 ]; then
	echo -e "\e[31mError: there could be 2 or no arguments after script name, you gave \""$argsQty"\". Exiting\e[0m"
	exit 1
elif [ "$argsQty" -eq 1 ]; then
	echo -e "\e[31mError: there could be 2 or no arguments after script name, you gave \""$argsQty"\". Exiting\e[0m"
	exit 1
elif [ "$argsQty" -eq 2 ]; then
	argFirst=${1:-}
	argSecond=${2:-}
	if [ "$argFirst" = "redisPort:" ]; then
		shift
		shift
		
		if [ -s "$redisPath"/ebs-redis_"$argSecond".conf ]; then
			redisPort="$argSecond"
		else
			echo -e "Error: file \""$redisPath/ebs-redis_$redisPort"\" not found or is empty\n">>"$logFile"
			exit 1
		fi
	fi
fi

redispid="$(/bin/ps -aef|egrep 'redis-server'|grep $redisPort|awk '{print $2}')"
redisclipid="$(/bin/ps -aef|egrep 'redis-cli'|grep $redisPort|awk '{print $2}')"

#####################
#start redis monitor
#####################
startRedisCli()
{
# RedisMonitor="$ptradehome"/Automation/RedisMonitor_"$redisPort".txt
RedisMonitor="$ptradehome"/Automation/RedisMonitor.txt
	if ! [ -z "$redisclipid" ]; then
		/bin/kill -9 "$redisclipid" >> "$logFile" 2>&1
		echo -e "\n Killed previous redis cli [$redisclipid]\n" >> "$logFile"
		sleep 3
	fi
	cd "$redisPath"
	nohup ./redis-cli -p "$redisPort" -a redis --csv monitor > "$RedisMonitor" &
	locaclipid="$(/bin/ps -aef|egrep 'redis-cli'|grep $redisPort|awk '{print $2}')"
	if ! [ -z "$locaclipid" ]; then
		output='OK'
		echo -e "\n Redis cli is now running [$locaclipid]\n" >> "$logFile"
	else
		echo -e "\n Redis cli start failed \n"
		exit 1
	fi
return 0
}

#####################
#start redis server
#####################
startRedisServer()
{
if ! [ -z "$redispid" ]; then
    # echo -e "\n Found redis server running [$redispid], omitting\n" >> "$logFile"
	# return "$redispid"
	/bin/kill -9 "$redispid" >> "$logFile" 2>&1
	echo -e "\n Killed previous redis server [$redispid]\n" >> "$logFile"
	sleep 3
fi
cd "$redisPath"
nohup ./redis-server ebs-redis_"$redisPort".conf &> "$RedisServerLog" &
sleep 3
localredis="$(/bin/ps -aef|egrep 'redis-server'|grep $redisPort|awk '{print $2}')"
if [ "$localredis" ]; then
	echo -e "\n Redis server is now running [$localredis]\n" >> "$logFile"
else
	echo -e "\n Did not succeed to launch redis server \n"
	exit 1
fi
output='OK'
return "$localredis"	
}

echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Started" >> "$logFile"

startRedisServer
if [ "$(/bin/ps -aef|egrep 'redis-server'|grep $redisPort|awk '{print $2}')" ]; then
	startRedisCli
	echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- Finished" >> "$logFile"
else
	echo -e "\n redis server start failed\n"
	exit 1
fi