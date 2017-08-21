#!/bin/ksh
# Copyright (c) 2001-2017 Fernando Nunes - domusonline@gmail.com
# License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
# $Author: Fernando Nunes - domusonline@gmail.com $
# $Revision: 2.0.18 $
# $Date 2017-08-22 00:07:46$
# Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
#             Although the author is/was an IBM employee, this software was created outside his job engagements.
#             As such, all credits are due to the author.
# !!!!!!!!!!!!! WARNING !!!!!!!!!!!!! 
# This script is intended to work with /bin/sh (standard bourne sh). But some /bin/sh (solaris) don't implement
# SIGERR. /bin/ksh does. Check the caveats below...
# Name: $RCSfile: alarm.sh,v $
#
# Based on ideas from David Ranney and lots of stuff from 10.00.xC6 alarmprogram.sh
# To use: chmod 755 alarm.sh alarm_conf.sh and configure the alarm_conf.sh
# caveats:
#	With some alarms (lock table overflow) you can get thousands of
# executions of this script. This can generate two undesirable effects:
#     1- You can receive thousands of emails (my record is 12K!)
#     2- You can easily exceed the max procs per user on your system
#     This 2nd situation will cause random errors on the script and
# turns any attempt to avoid the 1st situation into useless code.
#     To avoid this, the script is prepared by default to exit whenever
# an error is encountered. It will exit with error code 5. If you don't
# want this (if you need to debug it) you can turn this off. See below
# at the top of the script.
# To Run:
#        alarm.sh severity class-id class-msg specific-msg see-also event-uniqueid
#        -   severity: Category of event
#        -   class-id: Class identifier
#        -   class-msg: string containing text of message
#        -   specific-msg: string containing specific information
#        -   see-also: path to a see-also file
#        -   uniqid: Specific ID for the event


#If having repeated alarms (locks on v7...) you can reach max proc per user
# in that case it's better to exit on any error
jump_out()
{
	exit 5
}

#comment this line if you don't want the script to exit on any error or
# NOTE: some SHELLs may not implement signal ERR. Check the alarm.err file for possible errors
trap jump_out ERR

IFMX_ALARM_BASE_DIR=`dirname $0`

#redirect stout for stderr. Script should be silent. Also redirect stderr for a file
IFMX_ALARM_DEFAULT_ERR_FILE=${IFMX_ALARM_BASE_DIR}/alarm_${INFORMIXSERVER}_$(date -u +'%Y-%m').err
exec 1>&2
exec 2>>${IFMX_ALARM_DEFAULT_ERR_FILE}

#give the variable IFMX_ALARM_DEBUG the value 1 to get DEBUG messages
IFMX_ALARM_DEBUG=0

VERSION=`echo "$Revision: 2.0.18 $" | cut -f2 -d' '`

#Max number of seconds to wait for the execution of a previous alarm for the same event
IFMX_ALARM_MAX_LOOP=5

#Default number of seconds for event repeat safeguard.
IFMX_ALARM_DEF_TSTAMP_INTERVAL=60


#Calls the send sms script for a list of space separated phone numbers
send_sms()
{
	#-----------------------------------------------
	# get and check the send sms command
	#-----------------------------------------------
	AUX=`echo ${IFMX_ALARM_SENDSMS} | cut -f1 -d' '`
	if [ ! -x ${AUX} ]
	then
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` ERROR: PID=$$ CLASS_ID=${CLASS_ID} Tried to call SEND SMS ( ${AUX} ) program but it doesn't exist or is not executable..." >&2
		return
	fi
	MSG_SMS="${INFORMIXSERVER}@${HOST}: ${CLASS_MSG}[${EVENT_UNIQID}] ${SPECIFIC_MSG} -- ${DATE_VAR}"
	for PHONE in ${IFMX_ALARM_NUM_SMS}
	do
		${IFMX_ALARM_SENDSMS} ${PHONE} ${MSG_SMS} | cat
	done
}


#Logs entries in the syslog
send_syslog()
{

	case ${SEVERITY} in
	0)
		IFMX_ALARM_SYSLOG_PRIORITY=debug
		;;
	1)
		IFMX_ALARM_SYSLOG_PRIORITY=info
		;;
	2)
		IFMX_ALARM_SYSLOG_PRIORITY=notice
		;;
	3)
		IFMX_ALARM_SYSLOG_PRIORITY=warning
		;;
	4)
		IFMX_ALARM_SYSLOG_PRIORITY=err
		;;
	5)
		IFMX_ALARM_SYSLOG_PRIORITY=crit
		;;
	esac


	logger -p ${IFMX_ALARM_SYSLOG_FACILITY}.${IFMX_ALARM_SYSLOG_PRIORITY} "${IFMX_ALARM_IX_COMPONENT}#${IFMX_ALARM_IX_SUBCOMPONENT}#${SEVERITY}#${CLASS_ID}#${EVENT_UNIQID}##informix#${INFORMIXSERVER}#${CLASS_MSG}#${SPECIFIC_MSG}"

}


#Constructs and sends mail
#IFMX_ALARM_SENDMAIL must be a command that accepts a pre-constructed (with headers) mail msg
send_mail()
{
	#-----------------------------------------------
	# get and check the send mail command
	#-----------------------------------------------
	AUX=`echo ${IFMX_ALARM_SENDMAIL} | cut -f1 -d' '`
	if [ ! -x ${AUX} ]
	then
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` ERROR: PID=$$ CLASS_ID=${CLASS_ID} Tried to call SEND MAIL ( ${AUX} program but it doesn't exist or is not executable..." >&2
		return
	fi
	${IFMX_ALARM_SENDMAIL} <<!
FROM: ${IFMX_ALARM_HEADER_FROM}
TO: ${IFMX_ALARM_HEADER_TO}
CC: ${IFMX_ALARM_HEADER_CC}
SUBJECT: Instance: ${INFORMIXSERVER} : Host: ${HOST} ${SEV_MSG}

This is an automatic generated mail created by the alarm.sh script
of the Informix instance ${INFORMIXSERVER} at host ${HOST}
------------------------------------------------------------------

Date: ${DATE_VAR}
Severity: ${SEVERITY}
Class Id: ${CLASS_ID}
Class desc: ${CLASS_TEXT}

Class msg: ${CLASS_MSG}

Specific msg: ${SPECIFIC_MSG}

Event Uniq ID: ${EVENT_UNIQID}


Aditional information:
${SEE_ALSO}

`cat ${MAILBODY}`

------------------------------------------------------------------------------
.
!
}


#Tries to clean up on exit
clean_up()
{
	rm -f ${TMPFILE} ${MAILBODY} ${LOCKFILE}
}



if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
then
	echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ Script start..." >&2
fi

ONSTATCMD="onstat"
TMPFILE=/tmp/__TMPFILE_$$


if [ $# -lt 4 ]
then
	echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` requires at least 4 arguments." >&2
	exit 1
fi

# Get the arguments passed by IDS alarm subsystem
SEVERITY=$1
CLASS_ID=$2
CLASS_MSG=$3
SPECIFIC_MSG=$4
SEE_ALSO=$5
EVENT_UNIQID=$6

# Init other useful variables
DATE_VAR=`date`
TIMESTAMP=`date +"%Y%j%H%M%S"`
HOST=`hostname`


#implement critical session
# Only allows the execution of one script at a time for the same engine and event.

trap clean_up 0
LOCKFILE=/tmp/alarm_${INFORMIXSERVER}_${CLASS_ID}

LOOP_COUNT=0
export LOCKFILE IFMX_ALARM_MAX_LOOP LOOP_COUNT

until ( umask 222; echo $$>${LOCKFILE} ) 2>/dev/null
do
	sleep 1
	LOOP_COUNT=`expr ${LOOP_COUNT} + 1`
	if [ ${LOOP_COUNT} -gt ${IFMX_ALARM_MAX_LOOP} ]
	then
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : Alarm program could not get green flag to run after ${IFMX_ALARM_MAX_LOOP} seconds for event ${CLASS_ID}" >&2
		exit 3
	fi
done

if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
then
	echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Entered into critical section..." >&2
fi

#Include the configuration file. Search for it in: alarm.sh dir,INFORMIXSQLHOSTS's dir and INFORMIXDIR/etc
ALARM_CONF=${IFMX_ALARM_BASE_DIR}/alarm_conf.sh

if [ -x ${ALARM_CONF} ]
then
	. ${ALARM_CONF}
else
	if [ "X${INFORMIXSQLHOSTS}" != "X" ]
	then
		ALARM_CONF=`dirname ${INFORMIXSQLHOSTS}`/alarm_conf.sh
		if [ ! -x ${ALARM_CONF} ]
		then
			ALARM_CONF=${INFORMIXDIR}/etc/alarm_conf.sh
		fi
	else
		ALARM_CONF=${INFORMIXDIR}/etc/alarm_conf.sh
	fi

	if [ -x ${ALARM_CONF} ]
	then
		. ${ALARM_CONF}
	else
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` ERROR: PID=$$ CLASS_ID=${CLASS_ID} Alarm program could not find alarm_conf.sh" >&2
		exit 4
	fi
fi

if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
then
	echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Loaded config file..." >&2
fi

if [ "X${IFMX_ALARM_ERR_FILE}" != "X" ]
then
	exec 2>>${IFMX_ALARM_ERR_FILE}
fi

if [ "X${IFMX_LOG_FREE_THRESHOLD}" = "X" ]
then
	IFMX_LOG_FREE_THRESHOLD=50
fi

#check for event repetition
LAST_EVENT_FILE=${IFMX_ALARM_BASE_DIR}/${INFORMIXSERVER}_last_event
if [ -r ${LAST_EVENT_FILE} ]
then
	LAST_EVENT_STATUS=`tail -1 ${LAST_EVENT_FILE}`
	LAST_EVENT_TYPE=`echo ${LAST_EVENT_STATUS} | cut -f1 -d' '`
	LAST_EVENT_TSTAMP=`echo ${LAST_EVENT_STATUS} | cut -f2 -d' '`
else
	LAST_EVENT_TYPE=0
fi

#if not defined in the alarm_conf.sh
if [ "X${TSTAMP_INTERVAL}" = "X" ]
then
	TSTAMP_INTERVAL=${IFMX_ALARM_DEF_TSTAMP_INTERVAL}
fi
export TSTAMP_INTERVAL

if [ -z "${IFMX_ALARM_CLASS_NO_REPEAT}" ]
then
	IFMX_ALARM_CLASS_NO_REPEAT=""
fi

RC=`echo ${IFMX_ALARM_CLASS_NO_REPEAT} | egrep -c "(${CLASS_ID} |${CLASS_ID}$)" | cat`
case $RC in
0)
	echo "${CLASS_ID} ${TIMESTAMP} ${LAST_EVENT_TYPE} B $$" >> ${LAST_EVENT_FILE}
	;;
1|*)
	if [ ${LAST_EVENT_TYPE} -eq ${CLASS_ID} ]
	then
		if [ ${TSTAMP_INTERVAL} -gt 3599 ]
		then
			echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} `basename $0` ERROR: PID=$$ CLASS_ID=${CLASS_ID}  TSTAMP_INTERVAL cannot be greater than 3599 for event ${CLASS_ID}. Using max value" >&2
			TSTAMP_INTERVAL=3599
		fi
		TSTAMP_HOUR=`echo ${LAST_EVENT_TSTAMP} | cut -c8-9`
		TSTAMP_MIN=`echo ${LAST_EVENT_TSTAMP} | cut -c10-11`
		TSTAMP_SEC=`echo ${LAST_EVENT_TSTAMP} | cut -c12-13`

		MINUTES_TO_ADD=`expr ${TSTAMP_INTERVAL} / 60  | cat`
		SECONDS_TO_ADD=`expr ${TSTAMP_INTERVAL} - ${MINUTES_TO_ADD} \* 60 | cat`

		AUX=`expr ${SECONDS_TO_ADD} + ${TSTAMP_SEC} | cat`
		if [ ${AUX} -gt 59 ]
		then
			MINUTES_TO_ADD=`expr ${MINUTES_TO_ADD} + 1 | cat`
			SECONDS_TO_ADD=`expr ${SECONDS_TO_ADD} - 60 | cat`
		fi
		AUX=`expr ${MINUTES_TO_ADD} + ${TSTAMP_MIN} | cat`
		if [ ${AUX} -gt 59 ]
		then
			MINUTES_TO_ADD=`expr ${MINUTES_TO_ADD} - 60 | cat`
			HOURS_TO_ADD=10000
		else
			HOURS_TO_ADD=0
		fi
		NEW_TSTAMP=`expr ${LAST_EVENT_TSTAMP} + ${HOURS_TO_ADD} + ${MINUTES_TO_ADD}00 + ${SECONDS_TO_ADD}`


		if [ ${NEW_TSTAMP} -gt ${TIMESTAMP} ]
		then
			echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} `basename $0` ERROR: PID=$$ exiting due to TSTAMP_INTERVAL for event ${CLASS_ID}" >&2
			exit 0
		fi
		if [ ${TIMESTAMP} -gt ${LAST_EVENT_TSTAMP} ]
		then
			echo "${CLASS_ID} ${TIMESTAMP} ${LAST_EVENT_TYPE} ${LAST_EVENT_TSTAMP} $$" >> ${LAST_EVENT_FILE}
		fi
	else
		echo "${CLASS_ID} ${TIMESTAMP} ${LAST_EVENT_TYPE} A $$" >> ${LAST_EVENT_FILE}
	fi
	;;
esac


#exit from the exclusive section
rm -f ${LOCKFILE}

MAILBODY=/tmp/__MAILBODY_$$

cat /dev/null > ${MAILBODY}

# If this variables aren't defined, defined them in a way it won't trigger the respective events
# otherwise we could have errors in the 'ifs' at the bottom

if [ -z "${IFMX_ALARM_SEV_SMS}" ]
then
	IFMX_ALARM_SEV_SMS=6
fi

if [ -z "${IFMX_ALARM_SEV_MAIL}" ]
then
	IFMX_ALARM_SEV_MAIL=6
fi

if [ -z "${IFMX_ALARM_SEV_SYSLOG}" ]
then
	IFMX_ALARM_SEV_SYSLOG=6
fi


#This option depends on the OS... Linux requires --lines=+<X>.
TAIL_OPTION="+"
echo | tail +1 >/dev/null 2>&1 || TAIL_OPTION="--lines=+"

FLAG_SEND_MAIL=0
FLAG_SEND_SMS=0
FLAG_SEND_SYSLOG=0

case ${SEVERITY} in
	1) SEV_MSG="Event level: DESCRIPTION";
		;;
	2) SEV_MSG="Event level: INFORMATION";
		;;
	3) SEV_MSG="Event level: WARNING";
		;;
	4) SEV_MSG="Event level: EMERGENCY";
		;;
	5) SEV_MSG="Event level: FATAL";
		;;
	*) SEV_MSG="Event level: UNKNOWN - ${SEVERITY} - ";
	;;
esac

if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
then
	echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Starting case for class_id..." >&2
fi
case ${CLASS_ID} in
	1)
		#Severity 3,4
		CLASS_TEXT="Table failure: $CLASS_MSG"
		;;
	2)
		#Severity 3,4
		CLASS_TEXT="Index failure: $CLASS_MSG"
		;;
	3)
		CLASS_TEXT="Blob failure: $CLASS_MSG"
		;;
	4)
		CLASS_TEXT="Chunk is off-line, mirror is active: $CLASS_MSG"
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -d | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 > $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -m | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 > $MAILBODY
		;;
	5)
		CLASS_TEXT="DBSpace is off-line: $CLASS_MSG"
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -d | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 > $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -m | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 > $MAILBODY
		;;
	6)
		#Severity 3 (archive aborted); Severity 2 (audit skiping existing files); Severity 5 (crash MT)
		CLASS_TEXT="Internal Subsystem Failure: $CLASS_MSG"
		# Many things cause this problem see the online.log
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -m | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		;;
	7)
		CLASS_TEXT="OnLine Initialization failure"
		;;
	8)
		CLASS_TEXT="Physical Restore failure"
		;;
	9)
		CLASS_TEXT="Physical Recovery failure"
		;;
	10)
		CLASS_TEXT="Logical Recovery failure"
		;;
	11)
		CLASS_TEXT="Cannot Open Chunk: $CLASS_MSG"
		;;
	12)
		CLASS_TEXT="Cannot Open DBSpace: $CLASS_MSG"
		;;
	13)
		CLASS_TEXT="Performance Improvement possible"
		;;
	14) 
		CLASS_TEXT="Database failure: $CLASS_MSG"
		;;
	15)
		#Severity 2 (DR Operacional); #Severity 3 (DR off/server incompatible)
		CLASS_TEXT="DR failure"
		;;
	16)
		CLASS_TEXT="Archive completed: $CLASS_MSG"
		;;
	17)
		CLASS_TEXT="Archive aborted: $CLASS_MSG"
		# With this we will be able to get the stack trace for the ontape thread
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY

		$ONSTATCMD -g ath | grep ontape > $TMPFILE
		$ONSTATCMD -g ath | grep arcbackup >> $TMPFILE

		for i in `cat $TMPFILE | awk '{print $1}'`
		do
			$ONSTATCMD -g stk $i | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
			printf "\n-------------------------------------\n" >> $MAILBODY
		done
		;;
	18)
		CLASS_TEXT="Log Backup Completed: ${CLASS_MSG}"
		;;
	19)
		#Severity 3
		CLASS_TEXT="Log Backup Aborted: $CLASS_MSG"
		# Try to get the stack trace for all the ontape thread
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -g ath | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY

		for i in `$ONSTATCMD -g ath | grep ontape | awk '{print $1}'`
		do
			printf "\n-------------------------------------\n\n" >> $MAILBODY
			$ONSTATCMD -g stk $i
		done
		;;
	20)
		#Severity 3
		CLASS_TEXT="Logical Logs are FULL"
		OLDESTLOG=`$ONSTATCMD -l | tail ${TAIL_OPTION}4 |grep U- | awk '{print $4}' | sort -n | head -1`
		$ONSTATCMD -x | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}6 | grep -v active | grep "\-" > $TMPFILE
		LONGTX=0
		while read ADDRESS FLAGS USERTHREAD LOCKS LOGBEGIN CURLOG LOGPOS ISOL RETRYS COORD
		do
			if [ $LOGBEGIN -eq $OLDESTLOG ]
			then
				LONGTX=1
				# A long transaction has ocurred, get the culprit one
				SESSID=`$ONSTATCMD -u | grep $USERTHREAD\  | awk '{print $3}'`
				printf "   A LONG TRANSACTION has filled the Logical Logs, please check\n" >> $MAILBODY
				printf "below the information about transaction 0x%s that was generated\n" $ADDRESS >> $MAILBODY
				printf "by session %s.\n\nSESSION INFORMATION:\n" $SESSID >> $MAILBODY
				$ONSTATCMD -g ses $SESSID | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
			fi
		done < $TMPFILE

		if [ $LONGTX -eq 0 ]
		then
			NUMLOGB=`$ONSTATCMD -l | grep U-B | wc -l`
			if [ $NUMLOGB -eq 0 ]
			then
				printf "NO LONG TRANSACTION HAS OCCURED\n" >> $MAILBODY
				printf "LOGICAL LOGS NEED A BACKUP\n" >> $MAILBODY
				printf "RUN 'onbar -b -l' OR 'ontape -a' OR 'ontape -c'\n\n\n" >> $MAILBODY
			else
				printf "SEEMS THAT THERE ARE NO LONG TRANSACTIONS\n" >> $MAILBODY
				printf "AND LOGICAL LOGS WERE BACKED UP\n" >> $MAILBODY
				printf "CALL IBM Informix tech support\n" >> $MAILBODY
				SEVERITY=4
			fi
		fi

		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -l | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -x | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -u | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		;;
	21)
		#Severity 3 (Locks)
		CLASS_TEXT="OnLine resource overflow: $CLASS_MSG"
		;;
	22)
		#Severity 3
		CLASS_TEXT="Long Transaction Detected"
		dbaccess sysmaster <<! 2> /dev/null | grep \@ | awk '{print $2, $3, $4}' > $TMPFILE
select "@", tx_id, trim(LEADING '0' from replace(lower(HEX(tx_owner)), "0x", "")), hex(tx_addr)
from systrans
where tx_longtx != 0
!
		printf "   $EVENT_ADD_TEXT,\n" >> $MAILBODY
		if [ -s $TMPFILE ]
		then
			while read TXID TXOWNER TXADDR
			do
				SESSID=`$ONSTATCMD -u | grep $TXOWNER | awk '{print $3}'`
				printf "please check the information below about transaction TID=%s at %s\n" $TXID $TXADDR >>$MAILBODY
				printf "that was generated by session %s.\n\nSESSION INFORMATION:\n" $SESSID >> $MAILBODY
				$ONSTATCMD -g ses $SESSID | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
			done < $TMPFILE
		else
			printf "   The ALARMPROGRAM was not fast enough to capture information about\n" >> $MAILBODY
			printf "the session, please please check the online.log for more information.\n" >> $MAILBODY
		fi

		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -x | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -l | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -m | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		;;
	23)
		#Severity 2
		CLASS_TEXT="Logical Log Complete"

		if [ "X${IFMX_BAR_LOG_BACKUP}" = "X1" ]
		then
			rc=0;
			if [ "X${IFMX_BAR_LOG_COMMAND}" != "X" ]
			then
				$IFMX_BAR_LOG_COMMAND || rc=$?
			else
				$INFORMIXDIR/bin/onbar -b -l || rc=$?
			fi
			if [ ${rc} != 0 ]
			then
				SEVERITY=4
				SPECIFIC_MSG="Logical log backup failed return code: ${rc}"
			else
				SPECIFIC_MSG="Logical log backup return code: ${rc}"
			fi
		
		fi

		# Now check if the logs are near to fill up
		NUMLOGUB=`$ONSTATCMD -l | grep U-B | wc -l`
		NUMLOGF=`$ONSTATCMD -l | grep F- | wc -l`
		NUMLOGA=`$ONSTATCMD -l | grep A- | wc -l`
		NUMLOGU=`$ONSTATCMD -l | grep U- | wc -l`
		NUMLOG=`expr $NUMLOGU + $NUMLOGA + $NUMLOGF | cat`
		PERC=`expr  \( 100 \*  \( $NUMLOGUB + $NUMLOGF + $NUMLOGA \) \) / $NUMLOG | cat`

		#PERC=Usable logs

		if ( `test  $PERC -le $IFMX_LOG_FREE_THRESHOLD` ) then
			PERC_USED=`expr 100 - $PERC`
			SEVERITY=4
			SPECIFIC_MSG="${SPECIFIC_MSG}. Logical logs may be full ($PERC_USED) !!!"
			IFMX_ALARM_SYSLOG_PRIORITY=err
			printf "\n-------------------------------------\n\n" >> $MAILBODY
			printf "WARNING : PERCENTAGE OF LOGS FREE (%s) IS LESS THAN THE DEFINED THRESHOLD (%s)\n" $PERC $IFMX_LOG_FREE_THRESHOLD >> $MAILBODY
			printf "          A LOGICAL LOG BACKUP IS NEEDED. SEE INFO BELOW\n" >> $MAILBODY
			$ONSTATCMD -l | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		fi
		;;
	24)
		CLASS_TEXT="Unable to Allocate Memory"
		;;
	25)
		CLASS_TEXT="Internal Subsystem started: $CLASS_MSG"
		;;
	26)
		CLASS_TEXT="Dynamically added log file ($CLASS_MSG)."
		echo ${CLASS_MSG} | read -r DYN ADD LOG FILE LOGNUM TO DBS DBSNUM

dbaccess sysmaster <<! 2> /dev/null | grep \@ | awk '{print $2, $3, $4, $5}' > $TMPFILE
select '@', number, trunc(physloc/1048576), lower(hex(physloc)), size
from syslogfil
where number = $LOGNUM;
!
		read -r LOG CHKNUM PHYSLOC SIZE < $TMPFILE
		dbaccess sysmaster <<! 2> /dev/null | grep dbsname | awk '{print $2}' > $TMPFILE
select name as dbsname from sysdbspaces d
where dbsnum = $DBSNUM;
!
		read -r DBSNAME < $TMPFILE
		printf "   Logical log file number %s has been dynamically added by\n" $LOGNUM >> $MAILBODY
		printf "the engine, the log was added to Chunk Number %s in dbspace '%s';\n" $CHKNUM $DBSNAME >> $MAILBODY
		printf "please check free space on this dbspace and the process that\n" >> $MAILBODY
		printf "generated this event.\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "RELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -l | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -d | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		;;
	27)
		#Severity 4
		CLASS_TEXT="Log file required."
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "\nRELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -l | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -d | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		;;
	28)
		CLASS_TEXT="No space for dynamic log file."
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		printf "\nRELATED INFORMATION:\n" >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -d | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -l | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		printf "\n-------------------------------------\n\n" >> $MAILBODY
		$ONSTATCMD -m | grep -v Blocked: | grep -v Block: | tail ${TAIL_OPTION}4 >> $MAILBODY
		;;
	29)
		CLASS_TEXT="Internal Subsystem: $CLASS_MSG"
		;;
	40)
		CLASS_TEXT="RSS alarm"
		;;
	44)
		CLASS_TEXT="Dbspace is full"
		SEVERITY=4
		;;
	45)
		CLASS_TEXT="Number of extents exceeded"
		;;
	#these are custom classes to be used by other IX* scripts (ixproclogs) and/or sysadmin tasks
	#If this numbers are ever used by IBM this must be changed...
	900)
		CLASS_TEXT="Checkpoint completed"
		;;
	901)
		CLASS_TEXT="Connection problem"
		;;
	902)
		CLASS_TEXT="Archive Started"
		;;
	903)
		CLASS_TEXT="Operating status change"
		;;
	904)
		CLASS_TEXT="Runtime error"
		;;
	905)
		CLASS_TEXT="Dynamically allocated new memory segment"
		;;
	906)
		CLASS_TEXT="Archive Problem"
		;;
	907)
		CLASS_TEXT="DR server"
		;;
	908)
		CLASS_TEXT="Dbspace Usage"
		;;
	909)
		CLASS_TEXT="Session Status"
		;;
	910)
		CLASS_TEXT="Object state"
		;;
	911)
		CLASS_TEXT="Session memory"
		;;
	912)
		CLASS_TEXT="Number of extents"
		;;
	913)
		CLASS_TEXT="Alert to central"
		;;
	914)
		CLASS_TEXT="Number of cores"
		;;
	915)
		CLASS_TEXT="Logical Logs usage"
		;;
	916)
		CLASS_TEXT="Pages limit"
		;;
	917)
		CLASS_TEXT="Replication log diff"
		;;
	918)
		CLASS_TEXT="Checkpoint duration"
		;;
	919)
		CLASS_TEXT="Too many sessions"
		;;
	920)
		CLASS_TEXT="RSS acknowledging"
		;;
	*)
		CLASS_TEXT="Unknow event ID. Maybe due to v10+ and ALRM_ALL_EVENTS 1 in ONCONFIG file?"
		;;
esac

if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
then
	echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Ended case for class_id..." >&2
fi
FLAG_SEND_MAIL=`echo ${IFMX_ALARM_CLASS_MAIL} | egrep -c -e "(^${CLASS_ID} |^${CLASS_ID}$| ${CLASS_ID} | ${CLASS_ID}$)" | cat`

FLAG_SEND_SMS=`echo ${IFMX_ALARM_CLASS_SMS} | egrep -c -e "(^${CLASS_ID} |^${CLASS_ID}$| ${CLASS_ID} | ${CLASS_ID}$)" | cat`

FLAG_SEND_SYSLOG=`echo ${IFMX_ALARM_CLASS_SYSLOG} | egrep -c -e "(^${CLASS_ID} |^${CLASS_ID}$| ${CLASS_ID} | ${CLASS_ID}$)" | cat`

FLAG_SEND_MONITORING=`echo ${IFMX_ALARM_CLASS_MONITORING} | egrep -c -e "(^${CLASS_ID} |^${CLASS_ID}$| ${CLASS_ID} | ${CLASS_ID}$)" | cat`


#send sms/paging event
if [ ${SEVERITY} -ge ${IFMX_ALARM_SEV_SMS}  -o ${FLAG_SEND_SMS} -eq 1 ]
then
	# Emergency or worse
	# Send a page to the systems group
	if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
	then
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Will call send_sms..." >&2
	fi
	send_sms | cat
fi

#send message to syslog
if [ ${SEVERITY} -ge ${IFMX_ALARM_SEV_SYSLOG}  -o ${FLAG_SEND_SYSLOG} -eq 1 ]
then
	# Emergency or worse
	# Send a page to the systems group
	if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
	then
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Will call send_syslog..." >&2
	fi
	send_syslog | cat
fi

# Send email to those who may be interested
if [ ${SEVERITY} -ge ${IFMX_ALARM_SEV_MAIL} -o ${FLAG_SEND_MAIL} -eq 1 ]
then
	if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
	then
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Will call send_mail..." >&2
	fi
	send_mail | cat
fi

# Send event to monitoring system if conditions match
if [ ${SEVERITY} -ge ${IFMX_ALARM_SEV_MONITORING} -o ${FLAG_SEND_MONITORING} -eq 1 ]
then
	if [ "X${IFMX_ALARM_DEBUG}" != "X0" ]
	then
		echo "`date +'%Y-%m-%d %H:%M:%S'`: ${INFORMIXSERVER} : `basename $0` DEBUG: PID=$$ CLASS_ID=${CLASS_ID} Will call send_monitoring..." >&2
	fi
	send_monitoring | cat
fi
