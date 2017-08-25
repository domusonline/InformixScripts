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
-- Purpose: Check number of pages
-- Description: This function will verify if there are any tables exceeding the parameterized number of pages
-- Parameters (name, type, default, description):
--      NUM ALARMS            NUMERIC     3          Number of alarms sent
--      ALARM CLASS           NUMERIC     916        Class id for alarmprogram
--      YELLOW ALARM SEVERITY NUMERIC     3          Severity of the yellow alarm
--      RED ALARM SEVERITY    NUMERIC     4          Severity of the red alarm
--      YELLOW ABS THRESHOLD  NUMERIC     10000000   Number of existing pages that trigger a YELLOW alarm
--      RED ABS THRESHOLD     NUMERIC     14000000   Number of existing pages that trigger a RED alarm



DROP FUNCTION IF EXISTS monit_check_numpages;


CREATE FUNCTION monit_check_numpages(task_id INTEGER, v_id INTEGER) RETURNING INTEGER

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

DEFINE v_line_aux LVARCHAR(32739);

DEFINE v_database LIKE sysmaster:systabnames.dbsname;
DEFINE v_tabname, v_partname LIKE sysmaster:systabnames.tabname;
DEFINE v_num_pages INTEGER;
DEFINE v_partnum LIKE sysmaster:sysptnhdr.partnum;
DEFINE v_dbspace_name LIKE sysmaster:sysdbstab.name;


------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;



---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_check_numpages.dbg' WITH APPEND;
--TRACE ON;

---------------------------------------------------------------------------
-- Default values if nothing is configured in ph_threshold table
---------------------------------------------------------------------------
LET v_num_alarms=3;
LET v_class = 916;
LET v_severity_yellow = 3;
LET v_severity_red = 4;
LET v_abs_threshold_yellow = 10000000;
LET v_abs_threshold_red = 14000000;

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
		p.task_name = 'Monit Check Num Pages'

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
END FOREACH;

---------------------------------------------------------------------------
-- Obtain dump directory
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


LET v_see_also = TRIM(v_see_also) || '/NumPagessMonit' || TRIM(TO_CHAR(current year to minute, '%Y%m%d%H%M')) || '.rpt';


FOREACH
	SELECT

		t.dbsname, t.tabname, t1.tabname,
		pt.npused, d.name, pt.partnum
	INTO
		v_database, v_tabname, v_partname, v_num_pages, v_dbspace_name, v_partnum
	FROM
		sysmaster:systabnames t,
		sysmaster:systabnames t1,
		sysmaster:sysptnhdr pt,
		sysmaster:sysdbstab d
	WHERE
		t.partnum = pt.lockid AND
		pt.partnum = t1.partnum AND
		t.dbsname NOT IN ('sysmaster') and
		d.dbsnum = sysmaster:partdbsnum(t1.partnum) and
		pt.npused >= v_abs_threshold_yellow
	ORDER by 4 DESC, 1, 2, 3


	IF (v_num_pages > v_abs_threshold_red)
	THEN
		IF v_alert_color IS NULL
		THEN
			SET DEBUG FILE TO v_see_also;
		END IF
		IF v_alert_color IS NULL OR v_alert_color = 'YELLOW'
		THEN
			LET v_alert_color = 'RED';
		END IF;
		TRACE LPAD('RED',7) || " " || LPAD(v_database,64) || " " || LPAD(v_tabname,64) || " " || LPAD(v_partname,64) || " " || LPAD(v_partnum,9) || " " ||LPAD(v_dbspace_name,32) || " " || LPAD(v_num_pages,9);
	ELSE
		IF (v_num_pages > v_abs_threshold_yellow)
		THEN
			IF v_alert_color IS NULL
			THEN
				SET DEBUG FILE TO v_see_also;
				LET v_alert_color = 'YELLOW';
			END IF
			TRACE LPAD('YELLOW',7) || " " || LPAD(v_database,64) || " " || LPAD(v_tabname,64) || " " || LPAD(v_partname,64) || " " || LPAD(v_partnum,9) || " " ||LPAD(v_dbspace_name,32) || " " || LPAD(v_num_pages,9);
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
			p.alert_task_id = task_id
			AND p.alert_object_name = 'TOO MANY PAGES'
			AND p.alert_state = "NEW";
		
		IF v_alert_id IS NOT NULL
		THEN
	
			UPDATE
				ph_alert
			SET
				alert_state = 'ADDRESSED'
			WHERE
				ph_alert.id = v_alert_id;

			LET v_message = 'Previous alarm for too much pages cleared.';
			IF v_current_alert_color = 'RED'
			THEN
				LET v_severity = v_severity_red;
			ELSE
				LET v_severity = v_severity_yellow;
			END IF;
			EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of pages.',v_message,NULL);
		END IF;
	ELSE


		---------------------------------------------------------------------------
		-- There are sessions exceeding the threshold(s)
		-- Check to see if we already have an alert in the ph_alert table in the
		-- state NEW ...
		---------------------------------------------------------------------------
		IF v_alert_color = 'RED'
		THEN
			LET v_message = 'There are tables/partitions that exceeded the number of pages ('|| v_abs_threshold_red ||') RED threshold';
			LET v_severity = v_severity_red;
		ELSE
			LET v_message = 'There are tables/partitions that exceeded the number of pages ('|| v_abs_threshold_yellow ||') YELLOW threshold';
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
			p.alert_task_id = task_id
			AND p.alert_object_name = 'TOO MANY PAGES'
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
				'NEW', CURRENT YEAR TO SECOND,'ALARM', 'TOO MANY PAGES', v_message, 'sysadmin');
	 
				EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of pages.',v_message,v_see_also);
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
	
				EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of pages',v_message,v_see_also);
			ELSE
				IF (v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
				THEN
					EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Number of pages',v_message,NULL);
				END IF
			END IF;
		END IF;
	END IF;


END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Check Num Pages';

INSERT INTO ph_threshold VALUES(0, 'NUM ALARMS','Monit Check Num Pages', '3', 'NUMERIC', 'Number of alarms sent');
INSERT INTO ph_threshold VALUES(0, 'ALARM CLASS','Monit Check Num Pages','916', 'NUMERIC', 'Class id for alarmprogram');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ALARM SEVERITY','Monit Check Num Pages', '3', 'NUMERIC', 'Severity of the YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ALARM SEVERITY','Monit Check Num Pages', '4', 'NUMERIC', 'Severity of the RED alarm');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ABS THRESHOLD','Monit Check Num Pages', '10000000', 'NUMERIC', 'Number of existing pages that trigger a YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ABS THRESHOLD','Monit Check Num Pages', '14000000', 'NUMERIC', 'Number of existing pages that trigger a RED alarm');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Check Num Pages';

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
	'Monit Check Num Pages',
	'Task to monitor the number of pages per fragment',
	'TASK',
	'monit_check_numpages',
	'00:00:00',
	NULL,
	'1 00:00:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);

