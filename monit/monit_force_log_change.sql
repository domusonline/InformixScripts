-- Copyright (c) 2010-2017 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision: 2.0.32 $
-- $Date: 2017-10-07 01:19:30 $
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.
--
-- Informix Monit project
-- Purpose: Force a logical log change if it didn't occur in the previous defined interval
-- Description: This procedure will guarantee a logical log change at a specificed interval (if the last change happened before the
--              defined interval, it will force (onmode -l using SQL ADMIN API)
-- Parameters (name, type, default, description):
--      LOG CHANGE INTERVAL   NUMERIC 180 Number of seconds for log change
--      MINIMUM FREE SPACE KB NUMERIC 100 If the logical log has less than this ammount to reach limit, skip force change unless the last change was 2 cycles ago

--DROP FUNCTION IF EXISTS monit_force_log_change;
CREATE FUNCTION monit_force_log_change(v_task_id INTEGER, v_id INTEGER) RETURNING INTEGER;

-------------------------------------------------------------------------------------------------
-- This procedure checks how long the last log change was done. If it was longer than a specified
-- number of seconds, than it will force a log change.
-- To reduce the probability of a race condition (the check decides a log change is needed, but
-- at the same time one is done, we can define a parameter with a number of free KB on the log.
-- If the free space is less than this value (the log is almost full), we don't do the log change
-- unless we're on the "second cycle" of verification
-------------------------------------------------------------------------------------------------

DEFINE v_current_log, v_log_free_space, v_log_min_free_space, v_force_interval, v_admin_ret INTEGER;
DEFINE v_last_log_change DATETIME YEAR TO SECOND;

DEFINE v_alert_id LIKE ph_alert.id;

------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;

---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_force_log_change.dbg WITH APPEND;
--TRACE ON;


-------------------------------------------------------------------------------------------------
-- Choose your settings here
-------------------------------------------------------------------------------------------------
LET v_force_interval = 180;
LET v_log_min_free_space = 100;


FOREACH
	SELECT
		p.name, p.value
	INTO
		v_aux_threshold_name, v_aux_threshold_value
	FROM
		ph_threshold p
	WHERE
		task_name = 'Monit Force Log Change'


	IF v_aux_threshold_name = 'LOG CHANGE INTERVAL'
	THEN
		LET v_force_interval = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'MINIMUM FREE SPACE KB'
	THEN
		LET v_log_min_free_space = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
END FOREACH;
	


-------------------------------------------------------------------------------------------------
-- check the current state of the logs
-------------------------------------------------------------------------------------------------
SELECT
	(size-used) * (SELECT sh_pagesize / 1024 FROM sysmaster:sysshmvals), (SELECT DBINFO('utc_to_datetime', filltime) FROM sysmaster:syslogfil WHERE uniqid = (SELECT MAX(uniqid) - 1 FROM sysmaster:syslogfil))
INTO
	v_log_free_space, v_last_log_change
FROM sysmaster:syslogfil
WHERE
	uniqid = (SELECT MAX(uniqid) FROM sysmaster:syslogfil);

-------------------------------------------------------------------------------------------------
-- Decide if a log change is required or not
-------------------------------------------------------------------------------------------------

IF v_last_log_change + v_force_interval UNITS SECOND <= CURRENT YEAR TO SECOND THEN
	IF v_log_free_space >= v_log_min_free_space THEN
		-- Shift log
		EXECUTE FUNCTION sysadmin:ADMIN('onmode', 'l') INTO v_admin_ret;
	ELSE
		IF v_last_log_change + (2 * v_force_interval) UNITS SECOND < CURRENT YEAR TO SECOND THEN
			-- Shift log
			EXECUTE FUNCTION sysadmin:ADMIN('onmode', 'l') INTO v_admin_ret;
		END IF
	END IF
END IF

RETURN 0;
END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Clear Logical Log Alerts';

INSERT INTO ph_threshold VALUES(0, 'LOG CHANGE INTERVAL','Monit Force Log Change', '180', 'NUMERIC', 'Maximum log change interval in seconds');
INSERT INTO ph_threshold VALUES(0, 'MINIMUM FREE SPACE KB','Monit Force Log Change','100', 'NUMERIC', 'Minim free space in current log to force change');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Force Log Change';

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
	'Monit Force Log Change',
	'Task to force a log change if it was not change in the last N seconds',
	'TASK',
	'monit_force_log_change',
	'00:00:00',
	'23:59:59',
	'0 00:01:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);
--EXECUTE FUNCTION EXECTASK('Monit Force Log Change');
