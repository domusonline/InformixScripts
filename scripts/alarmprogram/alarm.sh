#!/bin/sh
# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - fernando.nunes@tmn.pt
# Projecto: alarmprogram
# Author: David Ranney
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

send_mail()
{
${IFMX_ALARM_SENDMAIL} <<!
FROM: $IFMX_ALARM_HEADER_FROM
TO: $IFMX_ALARM_HEADER_TO
CC: $IFMX_ALARM_HEADER_CC
SUBJECT: Intancia: $INFORMIXSERVER : Maquina: $host $sev_msg
 
Este mail foi gerado pelo script de ALARM da instancia ${INFORMIXSERVER} na maquina $host
--------------------------------------------------------------------------------

Severity: $severity
Class Id: $class_id
Class msg: $class_msg
Specific msg: $specific_msg
Data: $datevar
 
$class_text
 
$specific_msg
 
Informacao adicional: $see_also

------------------------------------------------------------------------------
.
!
}

ALARM_BASE_DIR=`dirname $0`
exec 1>&2
exec 2>>${ALARM_BASE_DIR}/alarm.err
if [ $# -lt 4 ]
then
   echo "`date +'%Y-%m-%d %H:%M:%S'`: O `basename $0` requer pelo menos 4 argumentos." >&2
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
	echo "`date +'%Y-%m-%d %H:%M:%S'`: Script auxiliar de datas '${ALARM_BASE_DIR}/datas_aux.sh' nao existe ou nao e executavel" >&2
        exit 1
fi

if [ $severity -ge ${IFMX_ALARM_SEV_MAIL} ]
then
   LAST_EVENT_FILE=${ALARM_BASE_DIR}/${INFORMIXSERVER}_last_event
   if [ -r ${LAST_EVENT_FILE} ]
   then
     LAST_EVENT_STATUS=`tail -1 ${LAST_EVENT_FILE}`
     LAST_EVENT_TYPE=`echo ${LAST_EVENT_STATUS} | cut -f1 -d' '`
     LAST_EVENT_TSTAMP=`echo ${LAST_EVENT_STATUS} | cut -f2 -d' '`
     echo $LAST_EVENT_STATUS >>${ALARM_BASE_DIR}/alarm.err
     echo $LAST_EVENT_TYPE >>${ALARM_BASE_DIR}/alarm.err
     echo $LAST_EVENT_TSTAMP >>${ALARM_BASE_DIR}/alarm.err
   else
     LAST_EVENT_TYPE=-1
   fi

   if [ ${LAST_EVENT_TYPE} -eq ${class_id} ]
   then
     diff_t1_t2 $timestamp ${LAST_EVENT_TSTAMP} ${TSTAMP_INTERVAL}
     res=$?
     echo "${class_id} ${timestamp}" >> ${LAST_EVENT_FILE}
     if [ $res -eq 0 ]
     then
       exit 0
     fi
   fi

   case $severity in
      1) sev_msg="Nivel do evento: DESCRICAO";
         ;;
      2) sev_msg="Nivel do evento: INFORMACAO";
         ;;
      3) sev_msg="Nivel do evento: ATENCAO";
         ;;
      4) sev_msg="Nivel do evento: EMERGENCIA";
         ;;
      5) sev_msg="Nivel do evento: FATAL";
         ;;
      *) sev_msg="Nivel do evento: DESCONHECIDO - $severity - ";
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
         send_sms
         ;;
     21)
         class_text="OnLine resource overflow: $class_msg"
         ;;
     22)
         class_text="Long Transaction Detected"
         ;;
     23)
         class_text="Logical Log $class_msg Complete"
         ;;
     24)
         class_text="Unable to Allocate Memory"
         ;;
   esac
 
   # Send email to those who may be interested
 
   send_mail
fi
 
if [ $severity -ge $IFMX_ALARM_SEV_SMS ]
then
	# Emergency or worse
	# Send a page to the systems group
	send_sms
fi
