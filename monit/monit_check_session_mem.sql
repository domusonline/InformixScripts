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
-- Purpose: Check sessions memory usage
-- Description: This function will verify if there are sessions exceeding the parameterized values for memory usage
-- Parameters (name, type, default, description):
--      NUM ALARMS             NUMERIC     3          Number of alarms sent
--      ALARM CLASS            NUMERIC     911        Class id for alarmprogram
--      YELLOW ALARM SEVERITY  NUMERIC     3          Severity of the yellow alarm
--      RED ALARM SEVERITY     NUMERIC     4          Severity of the red alarm
--      YELLOW THRESHOLD       NUMERIC     10000000   Ammount of memory usage that triggers a YELLOW alarm
--      RED THRESHOLD          NUMERIC     15000000   Ammount of memory usage that triggers a YELLOW alarm
--      KILL THRESHOLD         NUMERIC     100000000  Ammount of memory usage that triggers a session kill if KILL SESSIONS is set to 1
--      EXCLUDE KILL USER LIST STRING      informix   List of users (separated by commas) of users which sessions won't be killed
--      KILL SESSIONS          NUMERIC     0          Kill (1) or don't kill (0) sessions which exceed the KILL threshold
--      LOG COMMAND            STRING      TRACE      Command to be used for logging session status (TRACE will use SPL Trace functionality to write to a file in DUMPDIR or /tmp)

DROP FUNCTION IF EXISTS monit_check_session_mem;



CREATE FUNCTION monit_check_session_mem(v_task_id INTEGER, v_id INTEGER) RETURNING INTEGER

------------------------------------------------------------------------------------------
-- Generic help variables to allow interaction with OAT and ALARMPROGRAM
------------------------------------------------------------------------------------------

DEFINE v_num_alarms SMALLINT;
DEFINE v_alert_id LIKE ph_alert.id;
DEFINE v_alert_task_seq LIKE ph_alert.alert_task_seq;
DEFINE v_alert_color, v_current_alert_color CHAR(6);
DEFINE v_message VARCHAR(254,0);
DEFINE v_see_also VARCHAR(254,0);

DEFINE v_severity, v_severity_yellow, v_severity_red, v_class SMALLINT;


DEFINE v_threshold_yellow, v_threshold_red, v_threshold_kill INTEGER;
DEFINE v_user_kill_exclude CHAR(128);
DEFINE v_kill_sessions, v_kill_flag SMALLINT;

DEFINE v_line_aux LVARCHAR(32739);

DEFINE v_sid LIKE sysmaster:sysscblst.sid;
DEFINE v_username LIKE sysmaster:sysscblst.username;
DEFINE v_hostname LIKE sysmaster:sysscblst.hostname;
DEFINE v_progname LIKE sysmaster:sysscblst.progname;
DEFINE v_pid LIKE sysmaster:sysscblst.pid;
DEFINE v_memtotal LIKE sysmaster:sysscblst.memtotal;
DEFINE v_memused LIKE sysmaster:sysscblst.memused;

DEFINE v_log_command LIKE ph_threshold.value;

------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;



---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_check_session_mem.dbg' WITH APPEND;
--TRACE ON;

---------------------------------------------------------------------------
-- Default values if nothing is configured in ph_threshold table
---------------------------------------------------------------------------
LET v_num_alarms=3;
LET v_class = 911;
LET v_severity_yellow = 3;
LET v_severity_red = 4;
LET v_threshold_yellow = 10000000;    -- 10MB
LET v_threshold_red = 15000000;       -- 15MB
LET v_threshold_kill = 100000000;     -- 100MB
LET v_user_kill_exclude = 'informix';
LET v_kill_sessions = 0;

LET v_log_command = 'TRACE';


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
		p.task_name = 'Monit Check Session Memory'

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
	IF v_aux_threshold_name = 'KILL THRESHOLD'
	THEN
		LET v_threshold_kill = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'EXCLUDE KILL USER LIST'
	THEN
		LET v_user_kill_exclude = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'KILL SESSIONS'
	THEN
		LET v_kill_sessions = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'LOG COMMAND'
	THEN
		LET v_log_command = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	
END FOREACH;

---------------------------------------------------------------------------
-- Obtain session memory...
---------------------------------------------------------------------------

LET v_alert_color = NULL;
LET v_kill_flag = 0;

LET v_user_kill_exclude = REPLACE(v_user_kill_exclude,' ','');

CREATE TEMP TABLE
monit_check_ses_mem_tab
(
	c_line LVARCHAR(32739)
) EXTENT SIZE 1000 NEXT SIZE 1500;
INSERT INTO monit_check_ses_mem_tab VALUES(NULL);

LET v_see_also = NULL;

SELECT
	cfg.cf_effective
INTO
	v_see_also
FROM
	sysmaster:syscfgtab cfg
WHERE
	cfg.cf_name = 'DUMPDIR';

IF v_see_also IS NULL
THEN
	LET v_see_also = '/tmp/';
END IF


LET v_see_also = TRIM(v_see_also) || '/MemUsage_' || TRIM(TO_CHAR(current year to minute, '%Y%m%d%H%M')) || '.rpt';


FOREACH
	SELECT
		s.sid, s.username, s.hostname, s.progname, s.pid, s.memtotal, s.memused
	INTO
		v_sid, v_username, v_hostname, v_progname, v_pid, v_memtotal, v_memused
		
	FROM
		sysmaster:sysrstcb r, sysmaster:sysscblst s
	WHERE
		s.address = r.scb AND
		s.sid != DBINFO('sessionid') AND
		(s.memtotal > v_threshold_yellow OR s.memtotal >v_threshold_red)


	IF v_memtotal > v_threshold_red
	THEN
		LET v_line_aux = 'Alarm RED (' || v_threshold_red || ',' || v_memtotal || ')'; 
		IF v_alert_color IS NULL OR v_alert_color = 'YELLOW'
		THEN
			LET v_alert_color = 'RED';
		END IF;
	ELSE
		LET v_line_aux = 'Alarm YELLOW(' || v_threshold_yellow || ',' || v_memtotal || ')';
		IF v_alert_color IS NULL
		THEN
			LET v_alert_color = 'YELLOW';
		END IF;
	END IF
	

	IF v_log_command = 'TRACE'
	THEN
		SELECT
			TASK('onstat', '-g ses', v_sid)
		INTO
			v_line_aux
		FROM
			systables
		WHERE
			tabid = 1;

		INSERT INTO monit_check_ses_mem_tab VALUES (v_line_aux);
	ELSE
		SYSTEM( v_log_command||" "|| v_sid ||" >> " || v_see_also);
		INSERT INTO monit_check_ses_mem_tab VALUES (v_line_aux);
	END IF




	IF v_kill_sessions = 1
	THEN
		IF (
			v_memtotal > v_threshold_kill AND
			(
				v_user_kill_exclude NOT MATCHES v_username AND
				v_user_kill_exclude NOT MATCHES v_username||',*' AND
				v_user_kill_exclude NOT MATCHES '*,'||v_username AND
				v_user_kill_exclude NOT MATCHES '*,'||v_username||',*'
			)
		)
		
		THEN
			SELECT
				TASK('onmode', 'z', v_sid)

			INTO
				v_line_aux
			FROM
				systables
			WHERE
				tabid = 1;

			LET v_line_aux = "Tried to kill session: "||v_sid|| ": " || v_line_aux;
			INSERT INTO monit_check_ses_mem_tab VALUES (v_line_aux);
			LET v_kill_flag = 1;
		END IF
	END IF
	
END FOREACH

	



	IF v_alert_color IS NULL
	THEN
	---------------------------------------------------------------------------
	-- check to see if there is an already inserted alarm
	---------------------------------------------------------------------------
		LET v_alert_id = NULL;

		SELECT
			p.id, p.alert_task_seq, p.alert_color
		INTO
			v_alert_id, v_alert_task_seq, v_current_alert_color
		FROM
			ph_alert p
		WHERE
			p.alert_task_id = v_task_id
			AND p.alert_object_name = 'HIGH MEM'
			AND p.alert_state = "NEW";
		
		IF v_alert_id IS NOT NULL
		THEN
	
			UPDATE
				ph_alert
			SET
				alert_state = 'ADDRESSED'
			WHERE
				ph_alert.id = v_alert_id;

			LET v_message = 'Previous alarm for memory consumption cleared.';
			IF v_current_alert_color = 'RED'
			THEN
				LET v_severity = v_severity_red;
			ELSE
				LET v_severity = v_severity_yellow;
			END IF;
			EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Memory usage',v_message,NULL);
		END IF;
	ELSE


		---------------------------------------------------------------------------
		-- There are sessions exceeding the threshold(s)
		---------------------------------------------------------------------------


		SET DEBUG FILE TO v_see_also WITH APPEND;
		FOREACH
			SELECT
				c_line
			INTO
				v_line_aux
			FROM monit_check_ses_mem_tab
			
			TRACE TRIM(v_line_aux);

		END FOREACH;




		---------------------------------------------------------------------------
		-- Check to see if we already have an alert in the ph_alert table in the
		-- state NEW ...
		---------------------------------------------------------------------------
		IF v_alert_color = 'RED'
		THEN
			LET v_message = 'There are sessions that exceeded the mem usage RED threshold (' || FORMAT_UNITS(v_threshold_red,'B',2) || ')';
			LET v_severity = v_severity_red;
		ELSE
			LET v_message = 'There are sessions that exceeded the mem usage YELLOW threshold (' || FORMAT_UNITS(v_threshold_yellow,'B', 2) || ')';
			LET v_severity = v_severity_yellow;
		END IF

		IF v_kill_flag = 1
		THEN
			LET v_message = TRIM(v_message) || ' Some session(s) killed!';
		END IF
			

		LET v_alert_id = NULL;

		SELECT
			p.id, p.alert_task_seq, p.alert_color
		INTO
			v_alert_id, v_alert_task_seq, v_current_alert_color
		FROM
			ph_alert p
		WHERE
			p.alert_task_id = v_task_id
			AND p.alert_object_name = 'HIGH MEM'
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
				0, v_task_id, v_id, 'WARNING', v_alert_color, CURRENT YEAR TO SECOND,
				'NEW', CURRENT YEAR TO SECOND,'ALARM', 'HIGH MEM', v_message, 'sysadmin');
	 
				EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Session status',v_message,v_see_also);
		ELSE
			---------------------------------------------------------------------------
			-- There is an alarm...
			-- Need to check if it's still the same color...
			---------------------------------------------------------------------------
			IF ( v_current_alert_color != v_alert_color ) 
			THEN
				-------------------------------------------------------------------
				-- Either was red and now is yellow, or was yellow and now is red.
				-- In either case, the severity should be RED
				-------------------------------------------------------------------

				LET v_severity = v_severity_red;
				---------------------------------------------------------------------------
				-- Change the color... And reset the seq to reactivate the couter...
				---------------------------------------------------------------------------
				UPDATE ph_alert
				SET (alert_task_seq, alert_color, alert_state_changed, alert_message) = (v_id,v_alert_color, CURRENT YEAR TO SECOND, v_message)	
				WHERE ph_alert.id = v_alert_id;
	
				IF v_alert_color = 'RED'
				THEN
					LET v_message = TRIM(v_message)||". Changed to RED!";
				ELSE
					LET v_message = TRIM(v_message)||". Changed to YELLOW!";
				END IF
	
				EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Memory usage',v_message,v_see_also);
			ELSE
				IF (v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
				THEN
					EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Memory usage',v_message,NULL);
				END IF
			END IF;
		END IF;
	END IF;

DROP TABLE monit_check_ses_mem_tab;


END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Check Session Memory';

INSERT INTO ph_threshold VALUES(0, 'NUM ALARMS','Monit Check Session Memory', '3', 'NUMERIC', 'Number of alarms sent');
INSERT INTO ph_threshold VALUES(0, 'ALARM CLASS','Monit Check Session Memory', '911', 'NUMERIC', 'Class id for alarmprogram');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ALARM SEVERITY','Monit Check Session Memory', '3', 'NUMERIC', 'Severity of the YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ALARM SEVERITY','Monit Check Session Memory', '4', 'NUMERIC', 'Severity of the RED alarm');
INSERT INTO ph_threshold VALUES(0, 'YELLOW THRESHOLD','Monit Check Session Memory', '10000000', 'NUMERIC', 'Ammount of memory usage that triggers a YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED THRESHOLD','Monit Check Session Memory', '15000000', 'NUMERIC', 'Ammount of memory usage that triggers a RED alarm');
INSERT INTO ph_threshold VALUES(0, 'KILL THRESHOLD','Monit Check Session Memory', '15000000', 'NUMERIC', 'Ammount of memory usage that triggers a session kill if KILL SESSION is set to 1');
INSERT INTO ph_threshold VALUES(0, 'EXCLUDE KILL USER LIST','Monit Check Session Memory', 'informix', 'STRING', 'List of users (separated by commas) of users which sessions will not be killed');
INSERT INTO ph_threshold VALUES(0, 'KILL SESSIONS','Monit Check Session Memory', '0', 'NUMERIC', 'Kill (1) or do not kill (0) sessions which exceed the KILL threshold');
INSERT INTO ph_threshold VALUES(0, 'LOG COMMAND','Monit Check Session Memory', 'TRACE', 'STRING', 'Command to be used for logging session status (TRACE will use SPL Trace functionality to write to a file in DUMPDIR or /tmp)');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Check Session Memory';

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
        'Monit Check Session Memory',
        'Task to monitor the ammount of memory used by sessions',
        'TASK',
        'monit_check_session_mem',
        '00:00:00',
        NULL,
        '0 00:30:00',
        'T','T','T','T','T','T','T',
        'USER',
        'T'
);

