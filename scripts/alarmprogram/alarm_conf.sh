#!/bin/sh
# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - domusonline@domus.online.pt
# Project: alarmprogram
# History:
#    v 1.1: - syslog facility
#    v 1.0:
#           - Mail headers correction
#           - Export TSTAMP


VERSION="1.1"
if [ "X" = "X${INFORMIXSERVER}" ]
then
	echo "`basename $0`: INFORMIXSERVER nao definido" >&2
	exit 1
fi
engine=$INFORMIXSERVER
ONCONFIG=onconfig.${INFORMIXSERVER}
export ONCONFIG

if [ "X" = "X${INFORMIXSQLHOSTS}" ]
then
	informix_sqlhosts=${INFORMIXDIR}/etc/sqlhosts
else
	informix_sqlhosts=${INFORMIXSQLHOSTS}
fi

grep -i "^${engine}" ${informix_sqlhosts} >/dev/null
RC=$?
if [ $RC != 0 ]
then
	echo "`basename $0`: INFORMIXSERVER is not in sqlhosts" >&2
	exit 1
fi
engine=`echo ${engine} | tr "[A-Z]"  "[a-z]"`

host=`hostname`

IFMX_ALARM_HEADER_FROM="Informix Admin <informix@tmn.pt>"

#---- Mails addresses separated by ","
IFMX_ALARM_HEADER_TO="Your Name <your_address@foo.com>, Another Name <other_address@foo.com>"


#---- Mails addresses separated by ","
IFMX_ALARM_HEADER_CC="A third Name <third.address@foo.com>"

#---- Phone numbers separated by spaces
IFMX_ALARM_NUM_SMS="123456789 987654321"

#---- Minumu 'severity level' to send to syslog
IFMX_ALARM_SEV_MAIL=0

#---- Minimum 'severity level' to send mail
IFMX_ALARM_SEV_MAIL=3

#---- Minimum 'severity level' to send sms
IFMX_ALARM_SEV_SMS=4

IFMX_ALARM_SENDMAIL="/usr/sbin/sendmail -t"
IFMX_ALARM_SENDSMS="/usr/bin/scripts/avisa"

#interval during which the same event won't be reported
TSTAMP_INTERVAL=60

#Onbar to make logical log backup...? (1 -yes) or (0-no)
IFMX_BAR_LOG_BACKUP=0

#Veritas LOG POOL:
INFXBSA_LOGICAL_CLASS=informix-logs
#INFXBSA_LOGICAL_CLASS=Baltico_informix_logs

#Classes which send mail whatever the severity...
IFMX_ALARM_CLASS_MAIL="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 17 19 20 21 22 24 25 29 26 27 28"
#Classes which send to syslog whatever the severity...
IFMX_ALARM_CLASS_SYSLOG="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 17 19 20 21 22 24 25 29 26 27 28"
#Classes which send sms whatever the severity...
IFMX_ALARM_CLASS_SMS="4 12 20"

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
export TSTAMP_INTERVAL

export IFMX_BAR_LOG_BACKUP

export INFXBSA_LOGICAL_CLASS
export IFMX_ALARM_CLASS_MAIL
export IFMX_ALARM_CLASS_SMS

export IFMX_ALARM_CLASS_SYSLOG
export IFMX_ALARM_SYSLOG_FACILITY
export IFMX_ALARM_IX_COMPONENT
export IFMX_ALARM_IX_SUBCOMPONENT
