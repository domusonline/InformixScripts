#!/bin/ksh
# Copyright (c) 2006-2016 Fernando Nunes - domusonline@gmail.com
# License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
# $Author: Fernando Nunes - domusonline@gmail.com $
# $Revision 2.0.1 $
# $Date 2016-02-22 02:38:48$
# Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
#             Although the author is/was an IBM employee, this software was created outside his job engagements.
#             As such, all credits are due to the author.

PID_FILE=~informix/etc/ixproclog.pid
cd ~informix/bin

start()
{
	FLAG=$1
        export INFORMIXCONTIME=300
       	ixproclog ${FLAG} DAEMON& 
	if [ $? = 0 ]
	then
	        CPID=$!
	        echo $CPID > $PID_FILE
	fi
        echo `date +"%Y%m%d %H%M%S"` Start...
}



if [ -r $PID_FILE ]
then
        CPID=`cat $PID_FILE`

        ps -p $CPID | grep "^ *$CPID" 1>/dev/null
        if [ $? = 0 ]
        then
                exit
        else
                echo `date +"%Y%m%d %H%M%S"` Restart...
                start -f
        fi

else
        CPID=`ps -ef | grep "ixproclog .*DAEMON" | grep -v grep | awk '{print $2}'`
        if [ "X$CPID" = "X" ]
        then
                start
        else
                echo `date +"%Y%m%d %H%M%S"` Recreating PID file...
                echo $CPID > $PID_FILE
        fi
fi
