# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - domusonline@gmail.com
# License: This script is licensed as GPL ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
# Notes:
# History:

BEGIN {
	state=-1;
	last_date="";
	initial_date=-1
	last_offline_date=-1
	last_offline_hour=-1
	last_online_date=-1
	last_online_hour=-1
	printf "" >OFFLINE_FILE
	printf "" >ONLINE_FILE
	if ( ONLINE_LOG_HAS_DATE == 1 )
		HOUR_OFFSET=2;
	else
		HOUR_OFFSET=1;
}

function add_time(mode)
{
	if (mode==0)
	{
		if (last_offline_date != -1 )	
		{
			if ( VERBOSE_FLAG == 1 )
				printf "Server was down between %-10s %-8s and %-10s %-8s\n", last_offline_date, last_offline_hour, seen_offline_date, seen_offline_hour;
			print last_offline_date " " last_offline_hour "|" seen_offline_date " " seen_offline_hour "|" >>OFFLINE_FILE
		}
	}
	else
	if (mode==1)
	{
		if (last_online_date != -1 )	
		{
			if ( VERBOSE_FLAG == 1 )
				printf "Server was up between   %-10s %-8s and %-10s %-8s\n", last_online_date, last_online_hour, seen_online_date, seen_online_hour
			print last_online_date " " last_online_hour "|" seen_online_date " " seen_online_hour "|" >>ONLINE_FILE
		}
	}
	else
		exit(1);
}
function mes_int( mes )
{
	if ( mes == "Jan" )
		return 1
	else
	if ( mes == "Feb" )
		return 2
	else
	if ( mes == "Mar" )
		return 3
	else
	if ( mes == "Apr" )
		return 4
	else
	if ( mes == "May" )
		return 5
	else
	if ( mes == "Jun" )
		return 6
	else
	if ( mes == "Jul" )
		return 7
	else
	if ( mes == "Aug" )
		return 8
	else
	if ( mes == "Sep" )
		return 9
	else
	if ( mes == "Oct" )
		return 10
	else
	if ( mes == "Nov" )
		return 11
	else
	if ( mes == "Dec" )
		return 12
}

$0 ~ /Informix Dynamic Server Initialized/ {

if ( state == 1 )
{
add_time(1);
last_offline_date=last_date;
last_offline_hour=last_hour;
}
state=0;
}

$0 ~ /Requested shared/ {

if ( state == 1 )
{
last_offline_date=last_date;
last_offline_hour=last_hour;
add_time(1);
}
state=0;
}

$0 ~ /Informix.*Started/ {
#print "Server Started on " last_date " at " $1;
#print $0;

if ( state == 1 )
{
last_offline_date=last_date;
last_offline_hour=last_hour;

#--- changed... be careful...
seen_offline_date=last_date;
seen_offline_hour=$HOUR_OFFSET;
#--- changed... be careful...

add_time(1);
}
state=0;
}

$0 ~ /On-Line Mode/ {
#	print "Server went On-Line on " last_date " at " $1;
	if ( initial_date == -1)
	{
		initial_date=last_date;		
		initial_hour=last_hour;
	}
	last_hour=$HOUR_OFFSET;
	seen_offline_hour=$HOUR_OFFSET;
	seen_offline_date=last_date;
	add_time(0)
	last_online_date=last_date;
	last_online_hour=$HOUR_OFFSET;
	state=1;
}
$0 ~ /DR: Secondary server operational/ {
#	print "Server went On-Line on " last_date " at " $1;
	if ( initial_date == -1)
	{
		initial_date=last_date;		
		initial_hour=last_hour;
	}
	last_hour=$HOUR_OFFSET;
	if ( state == 0 )
	{
		seen_offline_hour=$HOUR_OFFSET;
		seen_offline_date=last_date;
		add_time(0)
		last_online_date=last_date;
		last_online_hour=$HOUR_OFFSET;
	}
	state=1;
}
$0 ~ /Informix.*Stopped/ {
#	print "Server was Stopped on " last_date " at " $1;
	if (state == 1)
	{	
		seen_online_hour=$HOUR_OFFSET;
		add_time(1);
	}
	if ( state == 0 )
	{
		seen_offline_hour=$HOUR_OFFSET;
		add_time(0);
	}
	last_offline_date=last_date;
	last_offline_hour=$HOUR_OFFSET;
	last_hour=$HOUR_OFFSET;
	state=0;
}
$0 ~ /PANIC: Attempting to bring system down/ {
#	print "Server was stopped by error on " last_date " at " $1;
	if ( state == 1 )
	{
		seen_online_hour=$HOUR_OFFSET;
		add_time(1);
	}
	if ( state == 0 )
	{
		seen_offline_hour=$HOUR_OFFSET;
		seen_offline_date=last_date;
		add_time(0)
	}
	last_offline_date=last_date;
	last_offline_hour=$HOUR_OFFSET;
	last_hour=$HOUR_OFFSET;
	state=0;
}

$0 ~ /^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)/ {
	mes=mes_int($2);
	last_date_tmp=$5"-"mes"-"$3;
	last_hour_tmp=$4;

	if ( initial_date == -1)
	{
		initial_date=last_date_tmp;
		initial_hour=last_hour_tmp;
	}
	
	if ( last_date == last_date_tmp )
	{
	if ( state == 0 )
		last_hour=last_hour_tmp;
	next;
	}
	last_date=last_date_tmp;
	last_hour=last_hour_tmp;
	if (state == 1)
	{
		seen_online_date=last_date;
		seen_online_hour=last_hour;
	}
	if (state == 0)
	{
		seen_offline_date=last_date;
		seen_offline_hour=last_hour;
	}
}
$0 ~ /^[0-9][0-9]*:[0-9][0-9]*:[0-9][0-9]* .* Checkpoint Completed/ {
	if ( state == 1 )
	{
		seen_online_date=last_date;
		seen_online_hour=$HOUR_OFFSET;
	}
	if ( state == 0 )
	{
		seen_offline_date=last_date;
		seen_offline_hour=$HOUR_OFFSET;
	}
	last_hour=$HOUR_OFFSET;
}
$0 ~ /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9] [0-9][0-9]*:[0-9][0-9]*:[0-9][0-9]* .* Checkpoint Completed/ {
	if ( state == 1 )
	{
		seen_online_date=last_date;
		seen_online_hour=$HOUR_OFFSET;
	}
	if ( state == 0 )
	{
		seen_offline_date=last_date;
		seen_offline_hour=$HOUR_OFFSET;
	}
	last_hour=$HOUR_OFFSET;
}




END {
if ( state == 1 )
{
	if (CURRENT_HOUR != "X" )
	{
		seen_online_date=CURRENT_DATE;
		seen_online_hour=CURRENT_HOUR;
	}
	add_time(1)
}
else
if ( state == 0 )
{
	if (CURRENT_HOUR != "X" )
	{
		seen_offline_date=CURRENT_DATE;
		seen_offline_hour=CURRENT_HOUR;
	}
	add_time(0)
}
}
