#!/bin/ksh
# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - domusonline@gmail.com
# Licence: This script is licensed as GPL ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
# History:

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
