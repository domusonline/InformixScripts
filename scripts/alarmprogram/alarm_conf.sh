#!/bin/sh
# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - fernando.nunes@tmn.pt
# Projecto: alarmprogram


if [ "X" = "X${INFORMIXSERVER}" ]
then
	echo "`basename $0`: INFORMIXSERVER nao definido" >&2
	exit 1
fi
engine=$INFORMIXSERVER

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
#IFMX_ALARM_HEADER_TO="Paulo Nunes <pnunes@tmn.pt>, Daniel Valente <daniel.valente@tmn.pt>"
IFMX_ALARM_HEADER_TO="Fernando Nunes <fernando.nunes@tmn.pt>"

#---- Mails separados por ","
#IFMX_ALARM_HEADER_CC="Fernando Nunes <fernando.nunes@tmn.pt>"
IFMX_ALARM_HEADER_CC=""

#---- Numeros de telefone separados por espacos
IFMX_ALARM_NUM_SMS="964018888 966400151"

#---- Minimo 'severity level' para enviar mail
IFMX_ALARM_SEV_MAIL=2

#---- Minimo 'severity level' para enviar sms
IFMX_ALARM_SEV_SMS=4

IFMX_ALARM_SENDMAIL="/usr/sbin/sendmail -t"
IFMX_ALARM_SENDSMS="/usr/bin/scripts/avisa"

#intervalo durante o qual o mesmo evento nao sera repetido
TSTAMP_INTERVAL=60

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
