#!/bin/ksh
# Copyright (c) 2016-2016 Fernando Nunes - domusonline@gmail.com
# License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
# $Author: Fernando Nunes - domusonline@gmail.com $
# $Revision 2.0.1 $
# $Date 2016-02-22 02:38:48$
# Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
#             Although the author is/was an IBM employee, this software was created outside his job engagements.
#             As such, all credits are due to the author.

ix_checkpoint()
{

	# -----------------------------------------------------------------
	# expected variables from ixproclog:
	# LOG_LINE
	# AWK
	# ALARM_SCRIPT
	# -----------------------------------------------------------------


	
	SETINFX_CONF_DIR=`get_setinfx_conf_dir`
	if [ "X${SETINFX_CONF_DIR}" = "X" ]
	then
		CHKPOINT_CONTROL_FILE_LIST="${DIRNAME}/${PROGNAME}.checkpoint.def"
	else
		CHKPOINT_CONTROL_FILE_LIST="${SETINFX_CONF_DIR}/${PROGNAME}.checkpoint.def ${SETINFX_CONF_DIR}/${PROGNAME}.checkpoint.def"
	fi
		

	F_NOT_FOUND=1
	for CHKPOINT_CONTROL_FILE in ${CHKPOINT_CONTROL_FILE_LIST}
	do
		if [ -r ${CHKPOINT_CONTROL_FILE} ]
		then
			F_NOT_FOUND=0
			break
		fi
	done
	if [ "${F_NOT_FOUND}" = 1 ]
	then
		echo "${PROGNAME} - ix_checkpoint [ Worker ${IX_NUM} ${INFORMIXSERVER} ] - Error: Cannot read checkpoint configuration file" >&2
		return
	fi

	# -----------------------------------------------------------------
	# Gets checkpoint duration from LOG line...
	# -----------------------------------------------------------------
	LOG_DESCRIPTION=`echo ${LOG_LINE} | cut -f2-  -d' '`
	CHK_POINT_VALUE=`echo ${LOG_DESCRIPTION} | cut -f2- -d':' | ${AWK} '{print $3}'`


	# -----------------------------------------------------------------
	# Gets Absolute max value for instance and current hour max
	# -----------------------------------------------------------------
	ABS_VALUE=`grep "^${INFORMIXSERVER}|ABS_MAX|" ${CHKPOINT_CONTROL_FILE} | ${AWK} -F'|' '{print $3}'`
	CURRENT_HOUR=`date +"%H"`
	HOUR_VALUE=`grep -i "^${INFORMIXSERVER}|HOUR|" ${CHKPOINT_CONTROL_FILE} | ${AWK} -F'|' -v "CURRENT_HOUR=${CURRENT_HOUR}" '{ if ( $3 <= CURRENT_HOUR && CURRENT_HOUR <= $4 ) {print $5;exit 0}}'`


	
	# -----------------------------------------------------------------
	# If ABS_VALUE is not defined, this instance isn't cofigured. Exits
	# -----------------------------------------------------------------
	if [ "X${ABS_VALUE}" = "X" ]
	then
		return 0
	fi

	# -----------------------------------------------------------------
	# checks for absolute limit...
	# -----------------------------------------------------------------
	if [ ${CHK_POINT_VALUE} -ge ${ABS_VALUE} ]
	then
		${ALARM_SCRIPT} 4 ${EXPR_ALARM_CLASS_ID} "Chekpoint too large.Exceeds max value for instance: ${ABS_VALUE}" "${LOG_LINE}"
		return 0
	fi



	# -----------------------------------------------------------------
	# checks for current hour limit
	# -----------------------------------------------------------------
	if [ "X${HOUR_VALUE}" != "X" ]
	then
		if [ ${CHK_POINT_VALUE} -ge ${HOUR_VALUE} ]
		then
			${ALARM_SCRIPT} 4 ${EXPR_ALARM_CLASS_ID} "Chekpoint too large. Exceeds max value for hour: ${HOUR_VALUE}" "${LOG_LINE}"
			return 0
		fi
	fi
}
