#!/bin/sh
# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - fernando.nunes@tmn.pt
# Projecto: alarmprogram
# History:
#    v 1.1:
#           - Introducao das variaveis IFMX_ALARM_CLASS_MAIL e IFMX_ALARM_CLASS_SMS
#           - Introducao de variaveis para controlo de backup de logical logs pelo On-Bar
#    v 1.0:
#           - Correccao dos headers de mail
#           - Export do TSTAMP


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
	echo "`basename $0`: o motor nao existe no sqlhosts" >&2
	exit 1
fi
engine=`echo ${engine} | tr "[A-Z]"  "[a-z]"`

host=`hostname`

IFMX_ALARM_HEADER_FROM="Informix Admin <informix@${host}>"

#---- Mails separados por ","
IFMX_ALARM_HEADER_TO="Paulo Nunes <pnunes@tmn.pt>, Daniel Valente <daniel.valente@tmn.pt>"

#---- Mails separados por ","
IFMX_ALARM_HEADER_CC="Fernando Nunes <fernando.nunes@tmn.pt>"

#---- Numeros de telefone separados por espacos
IFMX_ALARM_NUM_SMS="964018888 966400151"

#---- Minimo 'severity level' para enviar mail
IFMX_ALARM_SEV_MAIL=3

#---- Minimo 'severity level' para enviar sms
IFMX_ALARM_SEV_SMS=4

IFMX_ALARM_SENDMAIL="/usr/sbin/sendmail -t"
IFMX_ALARM_SENDSMS="/usr/bin/scripts/avisa"

#intervalo durante o qual o mesmo evento nao sera repetido
TSTAMP_INTERVAL=60

#Faz backup dos logs com onbar (1) ou nao (0)
IFMX_BAR_LOG_BACKUP=0

#Veritas LOG POOL:
INFXBSA_LOGICAL_CLASS=informix-logs

#Classes que enviam mail independentemente da severidade:
IFMX_ALARM_CLASS_MAIL="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 17 19 20 21 22 24 25 29 26 27 28"
IFMX_ALARM_CLASS_SMS="4 12 20"

case $engine in
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

