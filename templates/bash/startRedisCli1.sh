#!/bin/bash 

redispid="$(/sbin/pidof redis-server)"
redisclipid="$(/sbin/pidof redis-cli)"
ptradehome="/export/home/ptrade1"
localredis=""
output=""
scriptName=$(basename "$0")
baseScriptName=${scriptName%*.sh}
logDir="$ptradehome"/Automation/logs_PT_APP1
logFile="$logDir"/"$baseScriptName".log
logDebug="$logDir"/"$baseScriptName"_debug.log

### catching exit status
anyExit()
{
echo "$(date +%Y-%m-%d_%H:%M:%S,%3N) -- exit" >> "$logFile"
echo "$errorMsg" >> "$logFile"
}
trap anyExit 0 1 2 3 13 15 SIGTERM SIGHUP HUP QUIT PIPE TERM

### debug features
exec 5> "$logDebug"
BASH_XTRACEFD="5"
PS4='$LINENO: '
set -x

#####################
#start redis monitor
#####################
startRedisCli()
{
RedisMonitor="$ptradehome"/Automation/RedisMonitor1.txt
	if ! [ -z "$redisclipid" ]; then
		/bin/kill -9 "$redisclipid" >> "$logFile" 2>&1
		echo -e "\n Killed previous redis cli [$redisclipid]\n" >> "$logFile"
		sleep 3
	fi
	cd "$ptradehome"/redis/src && ./redis-cli -p 6379 -a redis --csv monitor > "$RedisMonitor" &
	locaclipid="$(/sbin/pidof redis-cli)"
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
   return "$redispid"
   echo -e "\n Found redis server running [$redispid], omitting\n" >> "$logFile"
elif [ -z "$redispid" ]; then
	cd "$ptradehome"/redis/src && ./redis-server ebs-redis.conf > /dev/null 2>&1 &
	sleep 3
	localredis="$(/sbin/pidof redis-server)"
	if [ "$localredis" ]; then
		echo -e "\n Redis server is now running [$localredis]\n" >> "$logFile"
	else
		echo -e "\n Did not succeed to launch redis server \n"
		exit 1
	fi
	output='OK'
	return "$localredis"
else
   echo -e "\n redis server is not running \n"
   exit 1	
fi
return 0
}

startRedisServer
if [ "$(/sbin/pidof redis-server)" ]; then
	startRedisCli
	exit 0
else
	echo -e "\n redis server start failed\n"
	exit 1
fi
exit 0