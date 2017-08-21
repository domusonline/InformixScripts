#!/bin/sh
# Copyright (c) 2001-2017 Fernando Nunes - domusonline@gmail.com
# License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
# $Author: Fernando Nunes - domusonline@gmail.com $
# $Revision: 2.0.18 $
# $Date 2017-08-22 00:07:46$
# Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
#             Although the author is/was an IBM employee, this software was created outside his job engagements.
#             As such, all credits are due to the author.

VERSION=`echo "$Revision: 2.0.18 $" | cut -f2 -d' '`
if [ "X" = "X${INFORMIXSERVER}" ]
then
	echo "`basename $0`: INFORMIXSERVER nao definido" >&2
	exit 1
fi
engine=$INFORMIXSERVER
if [ "X" = "X${ONCONFIG}" ]
then
	ONCONFIG=onconfig.${INFORMIXSERVER}
	export ONCONFIG
fi

if [ "X" = "X${INFORMIXSQLHOSTS}" ]
then
	informix_sqlhosts=${INFORMIXDIR}/etc/sqlhosts
else
	informix_sqlhosts=${INFORMIXSQLHOSTS}
fi

egrep -i -c -e "^${engine}[ |	]" ${informix_sqlhosts} | read RC
if [ $RC = 0 ]
then
	echo "`basename $0`: INFORMIXSERVER is not in sqlhosts" >&2
	exit 1
fi
engine=`echo ${engine} | tr "[:upper:]" "[:lower:]"`

host=`hostname`

IFMX_ALARM_HEADER_FROM="Informix Admin <informix@foo.com>"

#---- Mails addresses separated by ","
IFMX_ALARM_HEADER_TO="Your Name <your_address@foo.com>, Another Name <other_address@foo.com>"


#---- Mails addresses separated by ","
IFMX_ALARM_HEADER_CC="A third Name <third.address@foo.com>"

#---- Phone numbers separated by spaces
IFMX_ALARM_NUM_SMS="123456789 987654321"

#---- Minimum 'severity level' to send to syslog
IFMX_ALARM_SEV_SYSLOG=3

#---- Minimum 'severity level' to send mail
IFMX_ALARM_SEV_MAIL=3

#---- Minimum 'severity level' to send sms
IFMX_ALARM_SEV_SMS=4

#--- Minimum 'severity level' to send to monitoring system
IFMX_ALARM_SEV_MONITORING=3

#Stub functions for integration with alarm management systems
send_monitoring()
{
	#this function is called by alarm.sh when configuration triggers an event to alarm management system. Define the mapping to a function that deals with your system
	send_monitoring_openview $*
#	send_monitoring_tivoli $*
}

send_monitoring_openview()
{
	#sending event to HP OpenView Monitoring
	INST_MSG="Contact DBA Group"

	case $SEVERITY in
	0|1)
		OPEN_SEV=0
		;;
	4)
		OPEN_SEV=4
		INST_MSG1="OPENVIEW Message: Possible issues with Informix database instance: ${INFORMIXSERVER}"
		;;
	*)
		OPEN_SEV=`expr $SEVERITY - 1`
		;;
	esac
	/opt/OV/bin/opcmon OPV_POLICY_NAME=$OPV_SEV -object "${INFORMIXSERVER}:${CLASS_ID}" -option MSG="${CLASS_MSG} : $SPECIFIC_MSG" -option MSGGRP="APP-DBA" -option APP="Informix" -option INST0="$INST_MSG"
	echo "Openview"
}

send_monitoring_tivoli()
{
	#sending event to Tivoli Monitoring
	echo "Tivoli"
}

IFMX_ALARM_SENDMAIL="/usr/sbin/sendmail -t"
IFMX_ALARM_SENDSMS="/usr/bin/sendsms"

#Onbar to make logical log backup...? (1 -yes) or (0-no)
IFMX_BAR_LOG_BACKUP=0

#Which command to use
IFMX_BAR_LOG_COMMAND="${INFORMIXSDIR}/bin/onbar -b -l"

#Percentage of free logical logs below which an alarm will be triggered
IFMX_LOG_FREE_THRESHOLD=30

#Veritas LOG POOL:
INFXBSA_LOGICAL_CLASS=informix-logs

#Classes which send mail whatever the severity...
IFMX_ALARM_CLASS_MAIL="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 17 19 20 21 22 24 25 29 26 27 28 40 905 907 908 909 910 916 918 920"

#Classes which send to syslog whatever the severity...
IFMX_ALARM_CLASS_SYSLOG="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 17 19 20 21 22 24 25 29 26 27 28"

#Classes which send to alarm monitoring system whatever the severity...
IFMX_ALARM_CLASS_MONITORING="1 2 3 4 5 11 12 14 20 21 24 27 29 44 45 908 909"

#Classes which send sms whatever the severity...
IFMX_ALARM_CLASS_SMS="4 12 15 19 20 905 907 908"

#Classes that should avoid repeating processing within $TSTAMP_INTERVAL
IFMX_ALARM_CLASS_NO_REPEAT="21 24 6 901"

#Number of seconds before sending the same event alarm
TSTAMP_INTERVAL=60

IFMX_ALARM_SYSLOG_FACILITY=local7
IFMX_ALARM_IX_COMPONENT=IXS
IFMX_ALARM_IX_SUBCOMPONENT=DBENGINE

case $engine in
Engine1)
	IFMX_BAR_LOG_BACKUP=1
	;;
*)
;;
esac

export IFMX_ALARM_HEADER_FROM
export IFMX_ALARM_HEADER_TO
export IFMX_ALARM_HEADER_CC
export IFMX_ALARM_NUM_SMS
export IFMX_ALARM_SEV_SMS
export IFMX_ALARM_SEV_MAIL
export IFMX_ALARM_SEV_SYSLOG

export IFMX_ALARM_CLASS_NO_REPEAT
export TSTAMP_INTERVAL

export IFMX_BAR_LOG_BACKUP
export IFMX_BAR_LOG_COMMAND
export IFMX_LOG_FREE_THRESHOLD

export INFXBSA_LOGICAL_CLASS
export IFMX_ALARM_CLASS_MAIL
export IFMX_ALARM_CLASS_SMS

export IFMX_ALARM_CLASS_SYSLOG
export IFMX_ALARM_SYSLOG_FACILITY
export IFMX_ALARM_IX_COMPONENT
export IFMX_ALARM_IX_SUBCOMPONENT
