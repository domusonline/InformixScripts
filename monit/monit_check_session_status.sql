-- Copyright (c) 2010-2017 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision: 2.0.25 $
-- $Date: 2017-08-25 01:01:40 $
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.
--
-- Informix Monit project
-- Purpose: Check session status
-- Description: This function checks the session status (running, buffer waiting, lock waiting...) and alarms if the counters exceed the parameters
-- Parameters (name, type, default, description):
--      NUM ALARMS                  NUMERIC     3          Number of alarms sent
--      ALARM CLASS                 NUMERIC     909        Class id for alarmprogram
--      YELLOW ALARM SEVERITY       NUMERIC     3          Severity of the yellow alarm
--      RED ALARM SEVERITY          NUMERIC     4          Severity of the red alarm
--      WORK AS ALARM               NUMERIC     1          If it should act as an alarm
--      WORK AS SENSOR              NUMERIC     0          If it should act as a sensor (stores the measures)
--      CHANGE TO RED               NUMERIC     5          After how many iteractions should a YELLOW alarm be promoted to RED
--      LOCK WAITERS PERCENT        NUMERIC     90         Percentage of sessions waiting for locks to trigger an alarm
--      LOCK WAITERS ABS            NUMERIC     30         Number of sessions waiting for locks to trigger an alarm
--      MUTEX WAITERS PERCENT       NUMERIC     90         Percentage of sessions waiting for mutex to trigger an alarm
--      MUTEX WAITERS ABS           NUMERIC     30         Number of sessions waiting for mutex to trigger an alarm
--      LOG WAITERS PERCENT         NUMERIC     90         Percentage of sessions waiting for log buffer to trigger an alarm
--      LOG WAITERS ABS             NUMERIC     30         Number of sessions waiting for log buffer to trigger an alarm
--      ACTIVE PERCENT              NUMERIC     90         Percentage of sessions in active state (running) to trigger an alarm
--      ACTIVE ABS                  NUMERIC     30         Number of sessions in active state (running) to trigger an alarm
--      BUFFER WAITERS PERCENT      NUMERIC     90         Percentage of sessions waiting for buffers to trigger an alarm
--      BUFFER WAITERS ABS          NUMERIC     30         Number of sessions waiting for buffers to trigger an alarm
--      TRANSACTION WAITERS PERCENT NUMERIC     90         Percentage of sessions waiting for transaction slot to trigger an alarm
--      TRANSACTION WAITERS ABS     NUMERIC     30         Number of sessions waiting for transaction slot to trigger an alarm
--      TOTAL SESSIONS              NUMERIC     3000       Number of sessions to trigger an alarm
--      MIN SESSIONS TO ALERT       NUMERIC     5          Minimum number of sessions that must exist for the checking to take place


-- DROP FUNCTION IF EXISTS monit_check_session_status;

CREATE FUNCTION monit_check_session_status(task_id INTEGER, v_id INTEGER) RETURNING INTEGER

------------------------------------------------------------------------------------------
-- Thresholds in the code... overriden by parameters in ph_threshold
------------------------------------------------------------------------------------------
DEFINE v_lock_wait_percent_threshold, v_lock_wait_abs_threshold SMALLINT;
DEFINE v_mutex_wait_percent_threshold, v_mutex_wait_abs_threshold SMALLINT;
DEFINE v_log_wait_percent_threshold, v_log_wait_abs_threshold SMALLINT;
DEFINE v_buffer_wait_percent_threshold, v_buffer_wait_abs_threshold SMALLINT;
DEFINE v_transaction_wait_percent_threshold, v_transaction_wait_abs_threshold SMALLINT;
DEFINE v_active_percent_threshold, v_active_abs_threshold SMALLINT;
DEFINE v_total_sessions_threshold SMALLINT;

DEFINE v_min_sessions_to_alert SMALLINT;

DEFINE v_change_color_threshold SMALLINT;

------------------------------------------------------------------------------------------
-- Effective counts taken from sysmaster
------------------------------------------------------------------------------------------
DEFINE v_count_wait_lock SMALLINT;
DEFINE v_count_wait_mutex SMALLINT;
DEFINE v_count_wait_logs SMALLINT;
DEFINE v_count_wait_buffer SMALLINT;
DEFINE v_count_wait_transaction SMALLINT;
DEFINE v_count_active SMALLINT;

DEFINE v_count_wait_checkpoint SMALLINT;
DEFINE v_count_wait_cond SMALLINT;
DEFINE v_count_sleep SMALLINT;


------------------------------------------------------------------------------------------
-- Aux variables used in FOREACH query on sysmaster
------------------------------------------------------------------------------------------
DEFINE v_status CHAR(30);
DEFINE v_count SMALLINT;



------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;


------------------------------------------------------------------------------------------
-- To make a generic FOR loop
------------------------------------------------------------------------------------------
DEFINE v_wait_type CHAR(18); 
DEFINE v_count_all SMALLINT;                   -- gives total number of session
DEFINE v_count_aux SMALLINT;                   -- generic ABS count
DEFINE v_count_aux_percent SMALLINT;           -- generic percent value
DEFINE v_count_aux_threshold SMALLINT;         -- generic ABS threshold
DEFINE v_count_aux_percent_threshold SMALLINT; -- generic percent threshold


------------------------------------------------------------------------------------------
-- configures the task behavior... can just alert, or collect, or both...
------------------------------------------------------------------------------------------
DEFINE v_work_as_sensor_flag, v_work_as_alarm_flag SMALLINT;



------------------------------------------------------------------------------------------
-- Generic help variables to allow interaction with OAT and ALARMPROGRAM
------------------------------------------------------------------------------------------

DEFINE v_num_alarms SMALLINT;
DEFINE v_alert_id LIKE ph_alert.id;
DEFINE v_alert_task_seq LIKE ph_alert.alert_task_seq;
DEFINE v_alert_color,v_current_alert_color CHAR(6);
DEFINE v_message VARCHAR(254,0);

DEFINE v_severity_yellow, v_severity_red, v_class SMALLINT;
---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_check_session_status.dbg' WITH APPEND;
--TRACE ON;

---------------------------------------------------------------------------
-- Default values if nothing is configured in ph_threshold table
---------------------------------------------------------------------------
LET v_lock_wait_percent_threshold = 90;
LET v_lock_wait_abs_threshold = 30;

LET v_mutex_wait_percent_threshold = 90;
LET v_mutex_wait_abs_threshold = 30;

LET v_log_wait_percent_threshold = 90;
LET v_log_wait_abs_threshold = 30;

LET v_active_percent_threshold = 90;
LET v_active_abs_threshold = 30;

LET v_buffer_wait_percent_threshold = 90;
LET v_buffer_wait_abs_threshold = 30;

LET v_transaction_wait_percent_threshold = 90;
LET v_transaction_wait_abs_threshold = 30;

LET v_total_sessions_threshold = 3000;

LET v_change_color_threshold = 5;

LET v_min_sessions_to_alert = 5;

LET v_num_alarms=3;
LET v_class = 909;
LET v_severity_yellow = 3;
LET v_severity_red = 4;

LET v_work_as_sensor_flag = 0;
LET v_work_as_alarm_flag = 1;

---------------------------------------------------------------------------
-- Get the defaults configured in the ph_threshold table
---------------------------------------------------------------------------

FOREACH
	SELECT
		p.name, p.value
	INTO
		v_aux_threshold_name, v_aux_threshold_value
	FROM
		ph_threshold p
	WHERE
		p.task_name = 'Monit Check Session Status'
		AND p.name IN ('WORK AS ALARM', 'WORK AS SENSOR')

	IF v_aux_threshold_name = 'WORK AS ALARM'
	THEN
		LET v_work_as_alarm_flag = v_aux_threshold_value;
	END IF;
	IF v_aux_threshold_name = 'WORK AS SENSOR'
	THEN
		LET v_work_as_sensor_flag = v_aux_threshold_value;
	END IF;
END FOREACH;

IF v_work_as_alarm_flag = 1
THEN

	FOREACH
		SELECT
			p.name, p.value
		INTO
			v_aux_threshold_name, v_aux_threshold_value
		FROM
			ph_threshold p
		WHERE
			task_name = 'Monit Check Session Status'
			AND p.name NOT IN ('WORK AS ALARM', 'WORK AS SENSOR')



		IF v_aux_threshold_name = 'CHANGE TO RED'
		THEN
			LET v_change_color_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'NUM ALARMS'
		THEN
			LET v_num_alarms = v_aux_threshold_value;
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
		IF v_aux_threshold_name = 'LOCK WAITERS PERCENT'
		THEN
			LET v_lock_wait_percent_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'LOCK WAITERS ABS'
		THEN
			LET v_lock_wait_abs_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'MUTEX WAITERS PERCENT'
		THEN
			LET v_mutex_wait_percent_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'MUTEX WAITERS ABS'
		THEN
			LET v_mutex_wait_abs_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'LOG WAITERS PERCENT'
		THEN
			LET v_log_wait_percent_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'LOG WAITERS ABS'
		THEN
			LET v_log_wait_abs_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'ACTIVE PERCENT'
		THEN
			LET v_active_percent_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'ACTIVE ABS'
		THEN
			LET v_active_abs_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'BUFFER WAITERS PERCENT'
		THEN
			LET v_buffer_wait_percent_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'BUFFER WAITERS ABS'
		THEN
			LET v_buffer_wait_abs_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'TRANSACTION WAITERS PERCENT'
		THEN
			LET v_transaction_wait_percent_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'TRANSACTION WAITERS ABS'
		THEN
			LET v_transaction_wait_abs_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'TOTAL SESSIONS'
		THEN
			LET v_total_sessions_threshold = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
		IF v_aux_threshold_name = 'MIN SESSIONS TO ALERT'
		THEN
			LET v_min_sessions_to_alert = v_aux_threshold_value;
			CONTINUE FOREACH;
		END IF;
	END FOREACH;
END IF;

---------------------------------------------------------------------------
-- Initialize counts for each condition
---------------------------------------------------------------------------

LET v_count_wait_lock        = 0;
LET v_count_wait_mutex       = 0;
LET v_count_wait_logs        = 0;
LET v_count_active           = 0;
LET v_count_wait_buffer      = 0;
LET v_count_wait_transaction = 0;
LET v_count_all              = 0;
LET v_count_wait_checkpoint  = 0;
LET v_count_wait_cond        = 0;
LET v_count_sleep 	     = 0;

---------------------------------------------------------------------------
-- Obtain counts per condition
---------------------------------------------------------------------------
FOREACH
	SELECT
		CASE
			WHEN wtcondp != 0 THEN
				'WAIT ON CONDITION'
			WHEN sysmaster:bitval(r.flags, '0x2') = 1 THEN
				'WAIT ON MUTEX'
			WHEN sysmaster:bitval(r.flags, '0x4') = 1 THEN
				'WAIT ON LOCK'
			WHEN sysmaster:bitval(r.flags, '0x8') = 1 THEN
				'WAIT ON BUFFER'
			WHEN sysmaster:bitval(r.flags, '0x10') = 1 THEN
				'WAIT ON CHECKPOINT'
			WHEN sysmaster:bitval(r.flags, '0x1000') = 1 THEN
				'WAIT ON LOGS'
			WHEN sysmaster:bitval(r.flags, '0x40000') = 1 THEN
				'WAIT ON TRANSACTION'
			WHEN t.state=7 AND t.flags!=0 THEN
                                'SLEEPING'
			ELSE
				'ACTIVE'
		END,
		COUNT(*)
	INTO
		v_status, v_count
	FROM
	        sysmaster:sysrstcb r,  sysmaster:sysscblst s, sysmaster:systcblst t
	WHERE
		s.address = r.scb AND
		r.tid = t.tid AND
		r.sid != DBINFO('sessionid') AND
		t.name NOT LIKE 'dbWorker%' AND
		t.name NOT LIKE 'dbSched%'
	GROUP BY 1


	

	IF v_status = 'WAIT ON CONDITION'
	THEN
		LET v_count_wait_cond = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
	IF v_status = 'WAIT ON MUTEX'
	THEN
		LET v_count_wait_mutex = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
	IF v_status = 'WAIT ON LOCK'
	THEN
		LET v_count_wait_lock = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
	IF v_status = 'WAIT ON BUFFER'
	THEN
		LET v_count_wait_buffer = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
	IF v_status = 'WAIT ON CHECKPOINT'
	THEN
		LET v_count_wait_checkpoint = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
	IF v_status = 'WAIT ON LOGS'
	THEN
		LET v_count_wait_logs = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
	IF v_status = 'WAIT ON TRANSACTION'
	THEN
		LET v_count_wait_transaction = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
	IF v_status = 'ACTIVE'
	THEN
		LET v_count_active = v_count;
		LET v_count_all = v_count_all + v_count;
		CONTINUE FOREACH;
	END IF
        IF v_status = 'SLEEPING'
        THEN
                LET v_count_sleep= v_count;
                LET v_count_all = v_count_all + v_count;
                CONTINUE FOREACH;
        END IF


END FOREACH;

---------------------------------------------------------------------------
-- If acting as a sensor insert into the monitor table
---------------------------------------------------------------------------
IF v_work_as_sensor_flag = 1
THEN
	INSERT
		INTO mon_session_status (id,num_wait_cond,num_wait_mutex,num_wait_lock,num_wait_buffer,num_wait_checkpoint, num_wait_logs, num_wait_transaction, num_active, num_total)
		VALUES ( v_id, v_count_wait_cond, v_count_wait_mutex, v_count_wait_lock, v_count_wait_buffer, v_count_wait_checkpoint, v_count_wait_logs, v_count_wait_transaction, v_count_active, v_count_all);
END IF;


---------------------------------------------------------------------------
-- If acting as an alert task then verify the thresholds and act
-- accordingly
---------------------------------------------------------------------------
IF v_work_as_alarm_flag = 1
THEN

	---------------------------------------------------------------------------
	-- These are the states that can general alarms
	---------------------------------------------------------------------------
	
	FOR v_wait_type IN ('LOCK', 'MUTEX', 'LOG', 'ACTIVE', 'BUFFER', 'TRANSACTION', 'TOTAL')
		
		IF v_wait_type = 'LOCK'
		THEN
			LET v_count_aux = v_count_wait_lock;
			LET v_count_aux_threshold = v_lock_wait_abs_threshold;
			LET v_count_aux_percent_threshold = v_lock_wait_percent_threshold;
		END IF;
		IF v_wait_type = 'MUTEX'
		THEN
			LET v_count_aux = v_count_wait_mutex;
			LET v_count_aux_threshold = v_mutex_wait_abs_threshold;
			LET v_count_aux_percent_threshold = v_mutex_wait_percent_threshold;
		END IF;
		IF v_wait_type = 'LOG'
		THEN
			LET v_count_aux = v_count_wait_logs;
			LET v_count_aux_threshold = v_log_wait_abs_threshold;
			LET v_count_aux_percent_threshold = v_log_wait_percent_threshold;
		END IF;
		IF v_wait_type = 'ACTIVE'
		THEN
			LET v_count_aux = v_count_active;
			LET v_count_aux_threshold = v_active_abs_threshold;
			LET v_count_aux_percent_threshold = v_active_percent_threshold;
		END IF;
		IF v_wait_type = 'BUFFER'
		THEN
			LET v_count_aux = v_count_wait_buffer;
			LET v_count_aux_threshold = v_buffer_wait_abs_threshold;
			LET v_count_aux_percent_threshold = v_buffer_wait_percent_threshold;
		END IF;
		IF v_wait_type = 'TRANSACTION'
		THEN
			LET v_count_aux = v_count_wait_transaction;
			LET v_count_aux_threshold = v_transaction_wait_abs_threshold;
			LET v_count_aux_percent_threshold = v_transaction_wait_percent_threshold;
		END IF;
		IF v_wait_type = 'TOTAL'
		THEN
			LET v_count_aux = v_count_all;
			LET v_count_aux_threshold = v_total_sessions_threshold;
		END IF;
		
		IF v_count_all = 0
		THEN
			IF v_count_aux != 0
			THEN
				RAISE EXCEPTION -746,0, "Error in proc. monit_check_session_status: Sessions waiting for condition != 0, but total sessions = 0";
			ELSE
				LET v_count_aux_percent = 0;
			END IF
		ELSE
			LET v_count_aux_percent = ROUND((v_count_aux / v_count_all) * 100, 2);
		END IF;

		LET v_alert_color = NULL;

		IF v_wait_type = 'TOTAL'
		THEN
			IF (v_count_aux > v_count_aux_threshold)
			THEN
				LET v_alert_color = 'YELLOW';
				LET v_message = "Exceed threshold (" ||v_count_aux_threshold||") for total number of sessions:"||v_count_aux;
			END IF
		ELSE
			IF (v_count_aux_percent > v_count_aux_percent_threshold) OR (v_count_aux > v_count_aux_threshold )
			THEN
				LET v_alert_color = 'YELLOW';
			
				IF v_wait_type = 'ACTIVE'
				THEN
					LET v_message = "Exceed tresholds ("||v_count_aux_threshold||" or "||v_count_aux_percent_threshold||
						"%) for number of sessions in ACTIVE state. "||v_count_aux||
						" of "||v_count_all||" ("||v_count_aux_percent||"%)";
				ELSE
					LET v_message = "Exceed tresholds ("||v_count_aux_threshold||" or "||v_count_aux_percent_threshold||
						"%) for number of sessions waiting for "||v_wait_type||". "||v_count_aux||
						" of "||v_count_all||" ("||v_count_aux_percent||"%)";
				END IF
			END IF
		END IF

		IF v_count_all < v_min_sessions_to_alert
		THEN
			LET v_alert_color = NULL;
		END IF;

		IF v_alert_color IS NULL
		THEN
			---------------------------------------------------------------------------
			-- Check to see if there is an already inserted alarm
			-- If so... clear it...
			---------------------------------------------------------------------------
			LET v_alert_id = NULL;
	
			SELECT
				p.id, p.alert_task_seq, p.alert_color
			INTO
				v_alert_id, v_alert_task_seq, v_current_alert_color
			FROM
				ph_alert p
			WHERE
				p.alert_task_id = task_id
				AND p.alert_object_name = v_wait_type
				AND p.alert_state = "NEW";
		
			IF v_alert_id IS NOT NULL
			THEN
	
				UPDATE
					ph_alert
				SET
					alert_state = 'ADDRESSED'
				WHERE
					ph_alert.id = v_alert_id;
		
				LET v_message = 'Previous alarm for session state '||TRIM(v_wait_type)||' removed. Currently below thresholds';
				IF v_current_alert_color = 'YELLOW'
				THEN
					EXECUTE PROCEDURE call_alarmprogram(v_severity_yellow, v_class, 'Session status',v_message,NULL);
				ELSE
					EXECUTE PROCEDURE call_alarmprogram(v_severity_red, v_class, 'Session status',v_message,NULL);
				END IF;
			END IF;
		ELSE
		
			---------------------------------------------------------------------------
			-- Check to see if we already have an alert in the ph_alert table in the
			-- state NEW ...
			---------------------------------------------------------------------------

			LET v_alert_id = NULL;

			SELECT
				p.id, p.alert_task_seq, p.alert_color
			INTO
				v_alert_id, v_alert_task_seq, v_current_alert_color
			FROM
				ph_alert p
			WHERE
				p.alert_task_id = task_id
				AND p.alert_object_name = v_wait_type
				AND p.alert_state = "NEW";

			IF v_alert_id IS NULL
			THEN
				---------------------------------------------------------------------------
				-- There is no alarm... or the alarm changed from NEW
				---------------------------------------------------------------------------
				
				INSERT INTO
					ph_alert (id, alert_task_id, alert_task_seq, alert_type, alert_color, alert_time,
					alert_state, alert_state_changed, alert_object_type, alert_object_name, alert_message,
					alert_action_dbs)
				VALUES(
					0, task_id, v_id, 'WARNING', v_alert_color, CURRENT YEAR TO SECOND,
					'NEW', CURRENT YEAR TO SECOND,'DBSPACE', v_wait_type, v_message, 'sysadmin');
 
				EXECUTE PROCEDURE call_alarmprogram(v_severity_yellow, v_class, 'Session status',v_message,NULL);
			ELSE
				---------------------------------------------------------------------------
				-- There is an alarm...
				-- Need to check if it's still the same color...
				---------------------------------------------------------------------------
				IF ( v_current_alert_color = "YELLOW" ) AND
				( v_id = v_alert_task_seq + v_change_color_threshold) AND (v_change_color_threshold != 0)
				THEN
					---------------------------------------------------------------------------
					-- Change the color... And reset the seq to reactivate the couter...
					---------------------------------------------------------------------------
					UPDATE ph_alert
					SET (alert_task_seq, alert_color) = (v_id,'RED')
					WHERE ph_alert.id = v_alert_id;
					LET v_message = TRIM(v_message)||". Changed to RED!";
					EXECUTE PROCEDURE call_alarmprogram(v_severity_red, v_class, 'Session status',v_message,NULL);
				ELSE
					IF (v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
					THEN
						IF v_current_alert_color = 'YELLOW'
						THEN
							EXECUTE PROCEDURE call_alarmprogram(v_severity_yellow, v_class, 'Session status',v_message,NULL);
						ELSE
							EXECUTE PROCEDURE call_alarmprogram(v_severity_red, v_class, 'Session status',v_message,NULL);
						END IF;
					END IF
				END IF;
			END IF;
		END IF;
	END FOR
END IF


END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Check Session Status';

INSERT INTO ph_threshold VALUES(0, 'NUM ALARMS','Monit Check Session Status', '3', 'NUMERIC', 'Number of alarms sent');
INSERT INTO ph_threshold VALUES(0, 'ALARM CLASS','Monit Check Session Status', '909', 'NUMERIC', 'Class id for alarmprogram');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ALARM SEVERITY','Monit Check Session Status', '3', 'NUMERIC', 'Severity of the YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ALARM SEVERITY','Monit Check Session Status', '4', 'NUMERIC', 'Severity of the RED alarm');
INSERT INTO ph_threshold VALUES(0, 'WORK AS ALARM','Monit Check Session Status', '1', 'NUMERIC', 'If it should act as an alarm');
INSERT INTO ph_threshold VALUES(0, 'WORK AS SENSOR','Monit Check Session Status', '0', 'NUMERIC', 'If it should act as a sensor (stores the measurements)');
INSERT INTO ph_threshold VALUES(0, 'CHANGE TO RED','Monit Check Session Status', '5', 'NUMERIC', 'After how many iteractions should a YELLOW alarm be promoted to RED');
INSERT INTO ph_threshold VALUES(0, 'LOCK WAITERS PERCENT','Monit Check Session Status', '90', 'NUMERIC', 'Percentage of sessions waiting for locks to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'LOCK WAITERS ABS','Monit Check Session Status', '30', 'NUMERIC', 'Number of sessions waiting for locks to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'MUTEX WAITERS PERCENT','Monit Check Session Status', '90', 'NUMERIC', 'Percentage of sessions waiting for mutex to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'MUTEX WAITERS ABS','Monit Check Session Status', '30', 'NUMERIC', 'Number of sessions waiting for mutex to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'LOG WAITERS PERCENT','Monit Check Session Status', '90', 'NUMERIC', 'Percentage of sessions waiting for log buffer to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'LOG WAITERS ABS','Monit Check Session Status', '30', 'NUMERIC', 'Number of sessions waiting for log buffer to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'ACTIVE PERCENT','Monit Check Session Status', '90', 'NUMERIC', 'Percentage of sessions in active state (running) to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'ACTIVE ABS','Monit Check Session Status', '30', 'NUMERIC', 'Number of sessions in active state (running) to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'BUFFER WAITERS PERCENT','Monit Check Session Status', '90', 'NUMERIC', 'Percentage of sessions waiting for buffers to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'BUFFER WAITERS ABS','Monit Check Session Status', '30', 'NUMERIC', 'Number of sessions waiting for buffers to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'TRANSACTION WAITERS PERCENT','Monit Check Session Status', '90', 'NUMERIC', 'Percentage of sessions waiting for transaction slot to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'TRANSACTION WAITERS ABS','Monit Check Session Status', '30', 'NUMERIC', 'Number of sessions waiting for transaction slot to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'TOTAL SESSIONS','Monit Check Session Status', '3000', 'NUMERIC', 'Number of sessions to trigger an alarm');
INSERT INTO ph_threshold VALUES(0, 'MIN SESSIONS TO ALERT','Monit Check Session Status', '5', 'NUMERIC', 'Minimum number of sessions that must exist for the checking to take place');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Check Session Status';

-- To use as a task use this instruction:
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
	'Monit Check Session Status',
	'Task to monitor the status of the sessions',
	'TASK',
	'monit_check_session_status',
	'00:00:00',
	NULL,
	'0 00:05:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);

-- To use as a sensor use this instruction:
{

INSERT INTO ph_task (
	tk_id,
	tk_name,
	tk_description,
	tk_type,
	tk_result_table,
	tk_create,
	tk_execute,
	tk_delete,
	tk_start_time,
	tk_stop_time,
	tk_frequency,
	tk_monday, tk_tuesday, tk_wednesday, tk_thursday, tk_friday, tk_saturday, tk_sunday,
	tk_group,
	tk_enable
)
VALUES (
	0,
	'Monit Check Session Status',
	'Task to monitor the status of the sessions',
	'SENSOR',
	'mon_session_status',
	'CREATE TABLE mon_session_status (id INTEGER,num_wait_cond INTEGER,num_wait_mutex INTEGER,num_wait_lock INTEGER,num_wait_buffer INTEGER,num_wait_checkpoint INTEGER, num_wait_logs INTEGER, num_wait_transaction INTEGER, num_active INTEGER, num_total INTEGER) EXTENT SIZE 5000 NEXT SIZE 5000 LOCK MODE ROW;',
	'monit_check_session_status',
	'7 00:00:00',
	'00:00:00',
	NULL,
	'0 00:05:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);
}

--EXECUTE FUNCTION EXECTASK('Monit Check Session Status');
