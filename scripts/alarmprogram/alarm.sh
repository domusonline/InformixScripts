#!/bin/sh
# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - domusonline@domus.online.pt
# Project: alarmprogram
# Original Author: David Ranney
# To Compile:
#             chmod 555 alarm.sh
#
# To Run:
#        alarm.sh severity class-id class-msg specific-msg see-also
#        -   severity: Category of event
#        -   class-id: Class identifier
#        -   class-msg: string containing text of message
#        -   specific-msg: string containing specific information
#        -   see-also: path to a see-also file
#
# Description:
# This script was written to conform to the calling convention required for an
# online event alarm file according to the July 8 1994 document.
#
# This script sends email and pages the systems group when necessary.
#
# History:
#   v 1.3: - syslog logging added
#   v 1.2: - Correction on the event repetition...
#   v 1.1: - Introduction off logical log backup by onbar
#          - Activation of variables IFMX_ALARM_CLASS_MAIL and IFMX_ALARM_CLASS_SMS
#   v 1.0: - Debug messages removed

VERSION=`echo "$Revision$" | cut -f2 -d' '`

send_sms()
{
MSG_SMS="${INFORMIXSERVER}@${host}: \
$class_msg \
$specific_msg -- $datevar"
for numero in ${IFMX_ALARM_NUM_SMS}
do
	${IFMX_ALARM_SENDSMS} $numero $MSG_SMS
done
}

send_syslog()
{

	case $severity in
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


	logger -p ${IFMX_ALARM_SYSLOG_FACILITY}.${IFMX_ALARM_SYSLOG_PRIORITY} "${IFMX_ALARM_IX_COMPONENT}#${IFMX_ALARM_IX_SUBCOMPONENT}#${severity}#${class_id}#informix#${INFORMIXSERVER}#${class_msg}#${specific_msg}"

}

send_mail()
{
${IFMX_ALARM_SENDMAIL} <<!
FROM: $IFMX_ALARM_HEADER_FROM
TO: $IFMX_ALARM_HEADER_TO
CC: $IFMX_ALARM_HEADER_CC
SUBJECT: Instance: $INFORMIXSERVER : Host: $host $sev_msg
 
This is an automatic generated mail created by the alarm.sh script
of the Informix instance ${INFORMIXSERVER} at host $host
------------------------------------------------------------------

Severity: $severity
Class Id: $class_id
Class msg: $class_msg
Specific msg: $specific_msg
Data: $datevar
 
$class_text
 
$specific_msg
 
Aditional information: $see_also

------------------------------------------------------------------------------
.
!
}

flag_send_mail=0
flag_send_sms=0
flag_send_syslog=0

ALARM_BASE_DIR=`dirname $0`
exec 1>&2
exec 2>>${ALARM_BASE_DIR}/alarm.err
if [ $# -lt 4 ]
then
   echo "`date +'%Y-%m-%d %H:%M:%S'`: `basename $0` requires at least 4 arguments." >&2
   exit 1
fi

# Get the arguments themselves
severity=$1
class_id=$2
class_msg=$3
specific_msg=$4
see_also=$5

# Init other useful variables
datevar=`date`
timestamp=`date +"%Y%j%H%M%S"`
host=`hostname`


# If this variables aren't defined, defined them in a way it won't trigger the respective events
# otherwise we could have errors in the 'ifs' at the bottom
if [ -z "{IFMX_ALARM_SEV_SMS}" ]
then
	IFMX_ALARM_SEV_SMS=6
fi

if [ -z "{IFMX_ALARM_SEV_MAIL}" ]
then
	IFMX_ALARM_SEV_MAIL=6
fi

if [ -z "{IFMX_ALARM_SEV_SYSLOG}" ]
then
	IFMX_ALARM_SEV_SYSLOG=6
fi

ALARM_CONF=${ALARM_BASE_DIR}/alarm_conf.sh

if [ -x ${ALARM_CONF} ]
then
	. ${ALARM_CONF}
else
	ALARM_CONF=`dirname ${INFORMIXSQLHOSTS}`/alarm_conf.sh
	if [ -x ${ALARM_CONF} ]
	then
		. ${ALARM_CONF}
	else
		ALARM_CONF=${INFORMIXDIR}/etc/alarm_conf.sh
		if [ -x ${ALARM_CONF} ]
		then
			. ${ALARM_CONF}
		fi
	fi
fi
if [ -x ${ALARM_BASE_DIR}/datas_aux.sh ]
then
	. ${ALARM_BASE_DIR}/datas_aux.sh
else
	echo "`date +'%Y-%m-%d %H:%M:%S'`: Aux script for date calculation '${ALARM_BASE_DIR}/datas_aux.sh' doen't exist or isn't executable" >&2
        exit 1
fi

case $severity in
	1) sev_msg="Nivel do evento: DESCRIPTION";
		;;
	2) sev_msg="Nivel do evento: INFORMATION";
		;;
	3) sev_msg="Nivel do evento: WARNING";
		;;
	4) sev_msg="Nivel do evento: EMERGENCY";
		;;
	5) sev_msg="Nivel do evento: FATAL";
		;;
	*) sev_msg="Nivel do evento: UNKNOWN - $severity - ";
	;;
esac
 
case $class_id in
	1)
		class_text="Table failure: $class_msg"
		;;
	2)
		class_text="Index failure: $class_msg"
		;;
	3)
		class_text="Blob failure: $class_msg"
		;;
	4)
		class_text="Chunk is off-line, mirror is active: $class_msg"
		;;
	5)
		class_text="DBSpace is off-line: $class_msg"
		;;
	6)
		class_text="Internal Subsystem Failure: $class_msg"
		;;
	7)
		class_text="OnLine Initialization failure"
		;;
	8)
		class_text="Physical Restore failure"
		;;
	9)
		class_text="Physical Recovery failure"
		;;
	10)
		class_text="Logical Recovery failure"
		;;
	11)
		class_text="Cannot Open Chunk: $class_msg"
		;;
	12)
		class_text="Cannot Open DBSpace: $class_msg"
		;;
	13)
		class_text="Performance Improvement possible"
		;;
	14) 
		class_text="Database failure: $class_msg"
		;;
	15)
		class_text="DR failure"
		;;
	16)
		class_text="Archive completed: $class_msg"
		;;
	17)
		class_text="Archive aborted: $class_msg"
		;;
	18)
		class_text="Log Backup Completed: $class_msg"
		;;
	19)
		class_text="Log Backup Aborted: $class_msg"
		;;
	20)
		class_text="Logical Logs are FULL"
		# Handle special case for full logs
		;;
	21)
		class_text="OnLine resource overflow: $class_msg"
		;;
	22)
		class_text="Long Transaction Detected"
		;;
	23)
		class_text="Logical Log $class_msg Complete"
		if [ ${IFMX_BAR_LOG_BACKUP} -eq 1 ]
		then
			$INFORMIXDIR/bin/onbar -l
			rc=$?
			class_text="${class_text}: Return code de onbar -l: ${rc}"
		fi
		;;
	24)
		class_text="Unable to Allocate Memory"
		;;
	25)
		class_text="Internal Subsystem started: $class_msg"
		;;
	26)
		class_text="Dynamically added log file ($class_msg)."
		;;
	27)
		class_text="Log file required."
		;;
	28)
		class_text="No space for dynamic log file."
		;;
	29)
		class_text="Internal Subsystem: $class_msg"
		;;

esac
 
for check_class in ${IFMX_ALARM_CLASS_MAIL}
do
	if [ ${class_id} -eq ${check_class} ]
	then
		flag_send_mail=1
	fi
done


for check_class in ${IFMX_ALARM_CLASS_SMS}
do
	if [ ${class_id} -eq ${check_class} ]
	then
		flag_send_sms=1
	fi
done

for check_class in ${IFMX_ALARM_CLASS_SYSLOG}
do
	if [ ${class_id} -eq ${check_class} ]
	then
		flag_send_sms=1
	fi
done


#send sms/paging event
if [ $severity -ge ${IFMX_ALARM_SEV_SMS}  -o ${flag_send_sms} -eq 1 ]
then
	# Emergency or worse
	# Send a page to the systems group
	send_sms
fi

#send message to syslog
if [ $severity -ge ${IFMX_ALARM_SEV_SYSLOG}  -o ${flag_send_syslog} -eq 1 ]
then
	# Emergency or worse
	# Send a page to the systems group
	send_syslog
fi

# Send email to those who may be interested
if [ $severity -ge ${IFMX_ALARM_SEV_MAIL} -o ${flag_send_mail} -eq 1 ]
then
	LAST_EVENT_FILE=${ALARM_BASE_DIR}/${INFORMIXSERVER}_last_event
	if [ -r ${LAST_EVENT_FILE} ]
	then
		LAST_EVENT_STATUS=`tail -1 ${LAST_EVENT_FILE}`
		LAST_EVENT_TYPE=`echo ${LAST_EVENT_STATUS} | cut -f1 -d' '`
		LAST_EVENT_TSTAMP=`echo ${LAST_EVENT_STATUS} | cut -f2 -d' '`
	else
		LAST_EVENT_TYPE=0
	fi

	if [ ${LAST_EVENT_TYPE} -eq ${class_id} ]
	then
		diff_t1_t2 $timestamp ${LAST_EVENT_TSTAMP} ${TSTAMP_INTERVAL}
		res=$?
		if [ $res -eq 0 ]
		then
			echo "${class_id} ${timestamp} ${LAST_EVENT_TYPE}" >> ${LAST_EVENT_FILE} 
			exit 0
		fi
	fi
	echo "${class_id} ${timestamp} ${LAST_EVENT_TYPE}" >> ${LAST_EVENT_FILE} 
	send_mail
fi
 
