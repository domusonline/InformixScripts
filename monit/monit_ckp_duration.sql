-- Copyright (c) 2010-2017 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision: 2.0.36 $
-- $Date: 2018-03-12 14:00:26 $
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.
--
-- Informix Monit project
-- Purpose: Check checkpoint duration
-- Description: This function will verify the checkpoint duration
-- Parameters (name, type, default, description):
--      ALARM CLASS           NUMERIC     918        Class id for alarmprogram
--      YELLOW ALARM SEVERITY NUMERIC     3          Severity of the yellow alarm
--      RED ALARM SEVERITY    NUMERIC     4          Severity of the red alarm
--      YELLOW THRESHOLD      NUMERIC     10         Number of seconds above which a YELLOW alarm is trigger
--      RED THRESHOLD         NUMERIC     30         Number of seconds above which a RED alarm is trigger


--DROP FUNCTION IF EXISTS monit_ckp_duration;
CREATE FUNCTION monit_ckp_duration(v_task_id INTEGER, v_id INTEGER) RETURNING INTEGER

---------------------------------------------------------------------------------------
-- Generic Variables and to send ALARM
---------------------------------------------------------------------------------------
DEFINE v_threshold_yellow, v_threshold_red, v_severity_yellow, v_severity_red, v_severity, v_class, v_value, v_alert_id INT;
DEFINE v_last_task_run DATETIME YEAR TO SECOND;
DEFINE v_alert_color, v_current_alert_color CHAR(6);
DEFINE v_message VARCHAR(254,0);


---------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
---------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE sysadmin:ph_threshold.name;
DEFINE v_aux_threshold_value LIKE sysadmin:ph_threshold.value;

---------------------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_ckp_duration.dbg' WITH APPEND;
--TRACE ON;

---------------------------------------------------------------------------------------
-- Default values if nothing is configured in ph_threshold table
---------------------------------------------------------------------------------------
LET v_class = 918;
LET v_severity_yellow = 3;
LET v_severity_red = 4;
LET v_threshold_yellow = 10;
LET v_threshold_red = 30;


---------------------------------------------------------------------------------------
-- Get the defaults configured in the ph_threshold table
---------------------------------------------------------------------------------------
FOREACH
        SELECT
                p.name, p.value
        INTO
                v_aux_threshold_name, v_aux_threshold_value
        FROM
                sysadmin:ph_threshold p
        WHERE
                p.task_name = 'Monit Checkpoint Duration'

        IF v_aux_threshold_name = 'YELLOW THRESHOLD'
        THEN
                        LET v_threshold_yellow = v_aux_threshold_value;
                        CONTINUE FOREACH;
        END IF;
        IF v_aux_threshold_name = 'RED THRESHOLD'
        THEN
                        LET v_threshold_red = v_aux_threshold_value;
                        CONTINUE FOREACH;
        END IF;
        IF v_aux_threshold_name = 'ALARM CLASS'
        THEN
                        LET v_class = v_aux_threshold_value;
                        CONTINUE FOREACH;
        END IF;
        IF v_aux_threshold_name = 'YELLOW ALARM SEVERITY'
        THEN
                        LET v_severity_yellow = v_aux_threshold_value;
                        CONTINUE FOREACH;
        END IF;
        IF v_aux_threshold_name = 'RED ALARM SEVERITY'
        THEN
                        LET v_severity_red = v_aux_threshold_value;
                        CONTINUE FOREACH;
        END IF;
END FOREACH;


---------------------------------------------------------------------------------------
-- Main procedure
---------------------------------------------------------------------------------------

LET v_last_task_run=NULL;
SELECT
	MAX(r.run_time)
INTO
	v_last_task_run
FROM
	sysadmin:ph_run r
WHERE
	run_task_id = v_task_id;

IF ( v_last_task_run IS NULL)
THEN
	-- get max checkpoint duration (from last 20 checkpoints)
	SELECT
	        MAX(cp_time)
	INTO
	        v_value
	FROM
	        sysmaster:syscheckpoint c;
ELSE
	-- get max checkpoint duration (from last 20 checkpoints)
	SELECT
	        MAX(cp_time)
	INTO
	        v_value
	FROM
	        sysmaster:syscheckpoint c
	WHERE
		DBINFO('utc_to_datetime',c.clock_time) >= v_last_task_run;
END IF


-- check if there is an alarm situation
LET v_alert_color = NULL;

IF v_value > v_threshold_red
THEN
        LET v_alert_color = 'RED';
        ELIF v_value > v_threshold_yellow
        THEN
                LET v_alert_color = 'YELLOW';
END IF

-- check if there is an alarm already triggered
LET v_alert_id = NULL;
LET v_current_alert_color = NULL;

SELECT
        p.id, p.alert_color
INTO
        v_alert_id, v_current_alert_color
FROM
        ph_alert p
WHERE
        p.alert_task_id = v_task_id
        AND p.alert_object_name = 'Monit Checkpoint Duration'
        AND p.alert_state = 'NEW';


-- if there was an alarm, but not now, clear it
IF v_alert_color IS NULL AND v_current_alert_color IS NOT NULL
THEN
        UPDATE
                        ph_alert
        SET
                        alert_state = 'ADDRESSED'
        WHERE
                        ph_alert.id = v_alert_id;
END IF


-- if there is an alarm now, and it is new, trigger it
IF v_alert_color IS NOT NULL AND v_current_alert_color IS NULL
THEN
        IF v_alert_color = 'RED'
    THEN
                LET v_message = 'The checkpoint duration was ' || v_value || ' seconds (RED threshold is ' || v_threshold_red || ')';
                LET v_severity = v_severity_red;
        ELSE
                LET v_message = 'The checkpoint duration was ' || v_value || ' seconds (YELLOW threshold is ' || v_threshold_yellow || ')';
                LET v_severity = v_severity_yellow;
        END IF

        INSERT INTO ph_alert (id, alert_task_id, alert_task_seq, alert_type, alert_color, alert_time, alert_state,
                alert_state_changed, alert_object_type, alert_object_name, alert_message, alert_action_dbs)
        VALUES(0, v_task_id, v_id, 'WARNING', v_alert_color, CURRENT YEAR TO SECOND, 'NEW',
                CURRENT YEAR TO SECOND, 'ALARM', 'Monit Checkpoint Duration', v_message, 'sysadmin');

        EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Checkpoint Duration',v_message,NULL);
END IF


-- if there is an alarm now "red" and already existed but was yellow, update it
IF v_alert_color IS NOT NULL AND v_current_alert_color IS NOT NULL
THEN
        IF v_alert_color = 'RED' AND v_current_alert_color = 'YELLOW'
        THEN
                UPDATE
                        ph_alert
                SET
                        alert_color = 'RED'
                WHERE
                        ph_alert.id = v_alert_id;

                LET v_message = 'The checkpoint duration was ' || v_value || ' seconds (RED threshold is ' || v_threshold_red || ')';
                LET v_severity = v_severity_red;

                EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Checkpoint Duration',v_message,NULL);
        END IF
END IF
END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Checkpoint Duration';

INSERT INTO ph_threshold VALUES(0, 'ALARM CLASS','Monit Checkpoint Duration', '918', 'NUMERIC', 'Class id for alarmprogram');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ALARM SEVERITY','Monit Checkpoint Duration', '3', 'NUMERIC', 'Severity of the YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ALARM SEVERITY','Monit Checkpoint Duration', '4', 'NUMERIC', 'Severity of the RED alarm');
INSERT INTO ph_threshold VALUES(0, 'YELLOW THRESHOLD','Monit Checkpoint Duration', '10', 'NUMERIC', 'Number of seconds above which a YELLOW alarm is trigger');
INSERT INTO ph_threshold VALUES(0, 'RED THRESHOLD','Monit Checkpoint Duration', '30', 'NUMERIC', 'Number of seconds above which a RED alarm is trigger');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Checkpoint Duration';

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
        'Monit Checkpoint Duration',
        'Task to monitor the duration of checkpoints',
        'TASK',
        'monit_ckp_duration',
        '00:00:00',
        '23:59:59',
        '0 00:10:00',
        'T','T','T','T','T','T','T',
        'USER',
        'T'
);

--EXECUTE FUNCTION EXECTASK('Monit Checkpoint Duration');
