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
-- Purpose: Check number of extents
-- Description: This function will verify if there are any tables exceeding the parameterized number of extents
-- Parameters (name, type, default, description):
--      NUM ALARMS            NUMERIC     3          Number of alarms sent
--      ALARM CLASS           NUMERIC     912        Class id for alarmprogram
--      YELLOW ALARM SEVERITY NUMERIC     3          Severity of the yellow alarm
--      RED ALARM SEVERITY    NUMERIC     4          Severity of the red alarm
--      YELLOW ABS THRESHOLD  NUMERIC     80         Number of existing extents that trigger a YELLOW alarm
--      RED ABS THRESHOLD     NUMERIC     150        Number of existing extents that trigger a RED alarm
--      YELLOW LEFT THRESHOLD NUMERIC     40         Number of extents till limit is reached that trigger a YELLOW alarm
--      RED LEFT THRESHOLD    NUMERIC     20         Number of extents till limit is reached that trigger a RED alarm


DROP FUNCTION IF EXISTS monit_check_extents;


CREATE FUNCTION monit_check_extents(v_task_id INTEGER, v_id INTEGER) RETURNING INTEGER

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


DEFINE v_abs_threshold_yellow, v_abs_threshold_red INTEGER;
DEFINE v_left_threshold_yellow, v_left_threshold_red INTEGER;

DEFINE v_line_aux LVARCHAR(32739);

DEFINE v_database LIKE sysmaster:systabnames.dbsname;
DEFINE v_tabname LIKE sysmaster:systabnames.tabname;
DEFINE v_num_extents INTEGER;
DEFINE v_max_extents INTEGER;
DEFINE v_left_extents INTEGER;
DEFINE v_dbspace_name LIKE sysmaster:sysdbstab.name;


------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;



---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_check_extents.dbg' WITH APPEND;
--TRACE ON;

---------------------------------------------------------------------------
-- Default values if nothing is configured in ph_threshold table
---------------------------------------------------------------------------
LET v_num_alarms=3;
LET v_class = 912;
LET v_severity_yellow = 3;
LET v_severity_red = 4;
LET v_abs_threshold_yellow = 80;
LET v_abs_threshold_red = 150;

LET v_left_threshold_yellow = 40;
LET v_left_threshold_red = 20;

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
		p.task_name = 'Monit Check Extents'

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
	IF v_aux_threshold_name = 'YELLOW ABS THRESHOLD'
	THEN
		LET v_abs_threshold_yellow = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'RED ABS THRESHOLD'
	THEN
		LET v_abs_threshold_red = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'YELLOW LEFT THRESHOLD'
	THEN
		LET v_left_threshold_yellow = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'RED LEFT THRESHOLD'
	THEN
		LET v_left_threshold_red = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
END FOREACH;

---------------------------------------------------------------------------
-- Obtain number of extents
---------------------------------------------------------------------------

LET v_alert_color = NULL;
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


LET v_see_also = TRIM(v_see_also) || '/ExtentsMonit' || TRIM(TO_CHAR(current year to minute, '%Y%m%d%H%M')) || '.rpt';


FOREACH
	SELECT
		t.dbsname, t.tabname,
		pt.nextns ext_current,
		pt.nextns + trunc(pg_frcnt / 8) ext_max,
		trunc(pg_frcnt / 8) ext_free,
		d.name
	INTO
		v_database, v_tabname, v_num_extents, v_max_extents, v_left_extents, v_dbspace_name
	FROM
		sysmaster:systabnames t,
		sysmaster:syspaghdr p,
		sysmaster:sysptnhdr pt,
		sysmaster:sysdbstab d
	WHERE
		pt.partnum = t.partnum AND
		p.pg_partnum = sysmaster:partaddr(sysmaster:partdbsnum(t.partnum),1) AND
		p.pg_pagenum = sysmaster:partpagenum(t.partnum) AND
		t.dbsname NOT IN ('sysmaster') and
		d.dbsnum = sysmaster:partdbsnum(t.partnum)
	ORDER by 4, 1, 2


	IF (v_num_extents > v_abs_threshold_red OR v_left_extents < v_left_threshold_red)
	THEN
		IF v_alert_color IS NULL
		THEN
			SET DEBUG FILE TO v_see_also;
		END IF
		IF v_alert_color IS NULL OR v_alert_color = 'YELLOW'
		THEN
			LET v_alert_color = 'RED';
		END IF;
		TRACE LPAD('RED',7) || " " || LPAD(v_database,64) || " " || LPAD(v_tabname,64) || " " ||LPAD(v_dbspace_name,32) || " " || LPAD(v_num_extents,6) ||
		" " || LPAD(v_max_extents,6) || " " || LPAD(v_left_extents,6);
	ELSE
		IF (v_num_extents > v_abs_threshold_yellow OR v_left_extents < v_left_threshold_yellow)
		THEN
			IF v_alert_color IS NULL
			THEN
				SET DEBUG FILE TO v_see_also;
				LET v_alert_color = 'YELLOW';
			END IF
			TRACE LPAD('YELLOW',7) || " " || LPAD(v_database,64) || " " || LPAD(v_tabname,64) || " " ||LPAD(v_dbspace_name,32) || " " || LPAD(v_num_extents,6) || " " || LPAD(v_max_extents,6) || " " || LPAD(v_left_extents,6);
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
			AND p.alert_object_name = 'TOO MANY EXTENTS'
			AND p.alert_state = "NEW";
		
		IF v_alert_id IS NOT NULL
		THEN
	
			UPDATE
				ph_alert
			SET
				alert_state = 'ADDRESSED'
			WHERE
				ph_alert.id = v_alert_id;

			LET v_message = 'Previous alarm for too many extents cleared.';
			IF v_current_alert_color = 'RED'
			THEN
				LET v_severity = v_severity_red;
			ELSE
				LET v_severity = v_severity_yellow;
			END IF;
			EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of extents.',v_message,NULL);
		END IF;
	ELSE


		---------------------------------------------------------------------------
		-- There are tables exceeding the threshold(s)
		-- Check to see if we already have an alert in the ph_alert table in the
		-- state NEW ...
		---------------------------------------------------------------------------
		IF v_alert_color = 'RED'
		THEN
			LET v_message = 'There are tables that exceeded the number of extents ('|| v_abs_threshold_red ||')or the number of free extents (' || v_left_threshold_red ||') RED threshold';
			LET v_severity = v_severity_red;
		ELSE
			LET v_message = 'There are tables that exceeded the number of extents ('|| v_abs_threshold_yellow ||')or the number of free extents (' || v_left_threshold_yellow ||') YELLOW threshold';
			LET v_severity = v_severity_yellow;
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
			AND p.alert_object_name = 'TOO MANY EXTENTS'
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
				'NEW', CURRENT YEAR TO SECOND,'ALARM', 'TOO MANY EXTENTS', v_message, 'sysadmin');
	 
				EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of extents.',v_message,v_see_also);
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
				SET (alert_task_seq, alert_color) = (v_id,v_alert_color)
				WHERE ph_alert.id = v_alert_id;
	
				IF v_alert_color = 'RED'
				THEN
					LET v_message = TRIM(v_message)||". Changed to RED!";
				ELSE
					LET v_message = TRIM(v_message)||". Changed to YELLOW!";
				END IF
	
				EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of extents',v_message,v_see_also);
			ELSE
				IF (v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
				THEN
					EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of extents',v_message,NULL);
				END IF
			END IF;
		END IF;
	END IF;


END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Check Extents';

INSERT INTO ph_threshold VALUES(0, 'NUM ALARMS','Monit Check Extents', '3', 'NUMERIC', 'Number of alarms sent');
INSERT INTO ph_threshold VALUES(0, 'ALARM CLASS','Monit Check Extents','912', 'NUMERIC', 'Class id for alarmprogram');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ALARM SEVERITY','Monit Check Extents', '3', 'NUMERIC', 'Severity of the YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ALARM SEVERITY','Monit Check Extents', '4', 'NUMERIC', 'Severity of the RED alarm');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ABS THRESHOLD','Monit Check Extents', '80', 'NUMERIC', 'Number of existing extents that trigger a YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ABS THRESHOLD','Monit Check Extents', '150', 'NUMERIC', 'Number of existing extents that trigger a RED alarm');
INSERT INTO ph_threshold VALUES(0, 'YELLOW LEFT THRESHOLD','Monit Check Extents', '40', 'NUMERIC', 'Number of extents till limit is reached that trigger a YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED LEFT THRESHOLD','Monit Check Extents','20', 'NUMERIC', 'Number of extents till limit is reached that trigger a RED alarm');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Check Extents';

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
 	'Monit Check Extents',
	'Task to monitor the number of extents',
	'TASK',
	'monit_check_extents',
	'00:00:00',
	NULL,
	'1 00:00:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);

--EXECUTE FUNCTION EXECTASK('Monit Check Extents');
