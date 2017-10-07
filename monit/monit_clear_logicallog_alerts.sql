-- Copyright (c) 2010-2017 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision: 2.0.31 $
-- $Date: 2017-10-07 01:19:06 $
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.
--
-- Informix Monit project
-- Purpose: Clear the alerts for logical log changing from the ph_alert table
-- Description: This function will delete the alerts referring to logical log changing in the ph_alert table
-- Parameters (name, type, default, description):
--      COMMIT INTERVAL NUMERIC 100 Number of record in each commit cycle
--      LIMIT PER RUN   NUMERIC 500 Maximum number of records deleted in each run
--      MIN DAYS AGE    NUMERIC 5   Delete only records older than this number of days

--DROP FUNCTION IF EXISTS monit_clear_logicallog_alerts;
CREATE FUNCTION monit_clear_logicallog_alerts(v_task_id INTEGER, v_id INTEGER) RETURNING INTEGER;

-------------------------------------------------------------------------------------------------
-- This procedure cleans up the Logical Log NNN Completed and Logical Log NNN * backup complete
-- alarms from ph_alert
--
-- To avoid locking in ph_alert it does the deletes in commit intervals and has a limit of
-- deletes per run (this could be a ph_threshold value, but I don't think it is worthe the effort
-------------------------------------------------------------------------------------------------


DEFINE v_commit_interval, v_count, v_limit, v_min_days_age INTEGER;
DEFINE v_alert_id LIKE ph_alert.id;

------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;

---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_clear_logicallog_alerts.dbg WITH APPEND;
--TRACE ON;


SET LOCK MODE TO WAIT 5;
-------------------------------------------------------------------------------------------------
-- Choose your settings here
-------------------------------------------------------------------------------------------------
LET v_commit_interval = 100;
LET v_limit = 500;
LET v_min_days_age = 5;


LET v_count = 0;

FOREACH
	SELECT
		p.name, p.value
	INTO
		v_aux_threshold_name, v_aux_threshold_value
	FROM
		ph_threshold p
	WHERE
		task_name = 'Monit Clear Logical Log Alerts'


	IF v_aux_threshold_name = 'COMMIT INTERVAL'
	THEN
		LET v_commit_interval = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'LIMIT PER RUN'
	THEN
		LET v_limit = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'MIN DAYS AGE'
	THEN
		LET v_min_days_age = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
END FOREACH;
	


-------------------------------------------------------------------------------------------------
-- Start the transaction and use WITH HOLD to keep the cursor opened after COMMIT
-------------------------------------------------------------------------------------------------
BEGIN WORK;
FOREACH WITH HOLD
        SELECT 
                a.id
        INTO
                v_alert_id
        FROM
                ph_alert a
        WHERE
                alert_message LIKE 'Logical Log %Complete%' AND
		alert_time <= CURRENT YEAR TO SECOND - v_min_days_age UNITS DAY


        DELETE FROM ph_alert
        WHERE   
                id = v_alert_id;

        LET v_count=v_count + 1;
	IF v_count = v_limit
	THEN
		EXIT FOREACH;
	ELSE
	        IF MOD(v_count,v_commit_interval) = 0
		THEN
			COMMIT WORK;
                	BEGIN WORK;
		END IF;
	END IF;
END FOREACH;

COMMIT WORK;

RETURN 0;

END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Clear Logical Log Alerts';

INSERT INTO ph_threshold VALUES(0, 'COMMIT INTERVAL','Monit Clear Logical Log Alerts', '100', 'NUMERIC', 'Number of records in each commit cycle');
INSERT INTO ph_threshold VALUES(0, 'LIMIT PER RUN','Monit Clear Logical Log Alerts','500', 'NUMERIC', 'Maximum number of records deleted in each run');
INSERT INTO ph_threshold VALUES(0, 'MIN DAYS AGE','Monit Clear Logical Log Alerts', '5', 'NUMERIC', 'Delete only records older than this number of days');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Clear Logical Log Alerts';

INSERT INTO ph_task (
	tk_id,
	tk_name,
	tk_description,
	tk_type,
	tk_execute,
	tk_start_time,
	tk_stop_time,
	tk_frequency,
	tk_monday, tk_tuesday, tk_wednesday, tk_thursday, tk_friday, tk_saturday, tk_sunday,
	tk_group,
	tk_enable
)
VALUES (
	0,
	'Monit Clear Logical Log Alerts',
	'Task to clear the log changing alerts from the ph_alert table',
	'TASK',
	'monit_clear_logicallog_alerts',
	'00:00:00',
	'23:59:59',
	'0 02:00:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);
--EXECUTE FUNCTION EXECTASK('Monit Clear Logical Log Alerts');
