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
-- Purpose: Check dbspace free size
-- Description: This function will verify the free/used space in your dbspaces
-- Parameters (name, type, default, description):
--      NUM ALARMS             NUMERIC     3                       Number of alarms sent
--      ALARM CLASS            NUMERIC     908                     Class id for alarmprogram
--      YELLOW ALARM SEVERITY  NUMERIC     3                       Severity of the yellow alarm
--      RED ALARM SEVERITY     NUMERIC     4                       Severity of the red alarm
--      DBSPACE YELLOW DEFAULT NUMERIC     90                      Default percentage for YELLOW alarms
--      DBSPACE RED DEFAULT    NUMERIC     95                      Default percentage for RED alarms
--      DBSPACE EXCLUDE LIST   STRING      rootdbs,physdbs,llogdbs Comma separated list of dbspaces to exclude from monitoring
--      DBSPACE YELLOW dbspace NUMERIC                             Percentage for YELLOW alarms for specific dbspace
--      DBSPACE RED dbspace    NUMERIC                             Percentage for RED alarms for specific dbspace


--DROP FUNCTION IF EXISTS monit_check_space;

CREATE FUNCTION monit_check_space(task_id INTEGER, v_id INTEGER) RETURNING INTEGER

DEFINE v_num_alarms SMALLINT;
DEFINE v_generic_yellow_threshold, v_generic_red_threshold SMALLINT;
DEFINE v_dbs_yellow_threshold, v_dbs_red_threshold SMALLINT;
DEFINE v_name LIKE ph_threshold.name; 
DEFINE v_dbsnum INTEGER;
DEFINE v_dbs_name CHAR(128);
DEFINE v_pagesize, v_is_blobspace, v_is_sbspace, v_is_temp SMALLINT;
DEFINE v_size, v_free BIGINT;
DEFINE v_used DECIMAL(5,2);
DEFINE v_alert_id LIKE ph_alert.id;
DEFINE v_alert_task_seq LIKE ph_alert.alert_task_seq;
DEFINE v_alert_color,v_current_alert_color CHAR(6);
DEFINE v_message VARCHAR(254,0);
DEFINE v_units_used CHAR(20);
DEFINE v_units_free CHAR(20);
DEFINE v_dbspace_exclude_list LVARCHAR;

DEFINE v_severity, v_severity_yellow, v_severity_red, v_class SMALLINT;
------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;

---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_check_space.dbg' WITH APPEND;
--TRACE ON;

---------------------------------------------------------------------------
-- Default values if nothing is configured in ph_threshold table
---------------------------------------------------------------------------
LET v_generic_yellow_threshold=90;
LET v_generic_red_threshold=95;

LET v_class = 908;
LET v_num_alarms=3;
LET v_severity_yellow=3;
LET v_severity_red=4;
LET v_dbspace_exclude_list='rootdbs,physdbs,llogdbs';

---------------------------------------------------------------------------
-- Get the values configured in the ph_threshold table
---------------------------------------------------------------------------


FOREACH
        SELECT
                p.name, p.value
        INTO
                v_aux_threshold_name, v_aux_threshold_value
        FROM
                ph_threshold p
        WHERE
                p.task_name = 'Monit Check Space'

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
	IF v_aux_threshold_name = 'DBSPACE YELLOW DEFAULT'
	THEN
		LET v_generic_yellow_threshold = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'DBSPACE RED DEFAULT'
	THEN
		LET v_generic_red_threshold = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'DBSPACE EXCLUDE LIST'
	THEN
		LET v_dbspace_exclude_list = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;

END FOREACH;

---------------------------------------------------------------------------
-- Foreach dbspace....
---------------------------------------------------------------------------
LET v_dbspace_exclude_list = REPLACE(v_dbspace_exclude_list,' ','');

FOREACH
	SELECT
		d.dbsnum, d.name, d.pagesize, 
		d.is_blobspace, d.is_sbspace, d.is_temp,
		SUM(c.chksize),
		CASE
		WHEN (d.is_sbspace = 1 OR d.is_blobspace = 1)
			THEN SUM(c.udfree)
		ELSE
			SUM(c.nfree)
		END
	INTO
		v_dbsnum, v_dbs_name, v_pagesize, v_is_blobspace, v_is_sbspace, v_is_temp,
		v_size, v_free
	FROM
		sysmaster:sysdbspaces d, sysmaster:syschunks c
	WHERE
		d.dbsnum = c.dbsnum
	GROUP BY 1, 2, 3, 4, 5, 6
	ORDER BY 1
	
	IF (
		v_dbspace_exclude_list MATCHES TRIM(v_dbs_name) OR
		v_dbspace_exclude_list MATCHES TRIM(v_dbs_name)||',*' OR
		v_dbspace_exclude_list MATCHES '*,'||TRIM(v_dbs_name) OR
		v_dbspace_exclude_list MATCHES '*,'||TRIM(v_dbs_name)||',*'
	)
	THEN
		CONTINUE FOREACH;
	END IF

	---------------------------------------------------------------------------
	-- Get specific dbspace red threshold if available....
	---------------------------------------------------------------------------
	LET v_name = 'DBSPACE RED ' || TRIM(v_dbs_name);

	SELECT
		value
	INTO
		v_dbs_red_threshold
	FROM
		ph_threshold
	WHERE
		task_name = 'Monit Check Space' AND
		name = v_name;

	IF v_dbs_red_threshold IS NULL
	THEN
		LET v_dbs_red_threshold = v_generic_red_threshold;
	END IF;

	---------------------------------------------------------------------------
	-- Get specific dbspace yellow threshold if available....
	---------------------------------------------------------------------------
	LET v_name = 'DBSPACE YELLOW ' || TRIM(v_dbs_name);

	SELECT
		value
	INTO
		v_dbs_yellow_threshold
	FROM
		ph_threshold
	WHERE
		task_name = 'Monit Check Space' AND
		name = v_name;

	IF v_dbs_yellow_threshold IS NULL
	THEN
		LET v_dbs_yellow_threshold = v_generic_yellow_threshold;
	END IF;

	---------------------------------------------------------------------------
	-- Calculate used percentage and act accordingly...
	---------------------------------------------------------------------------
	LET v_used = ROUND( ((v_size - v_free) / v_size)  * 100,2);
	LET v_units_used = FORMAT_UNITS(( v_size - v_free ) * v_pagesize,'B',2 );
	LET v_units_free = FORMAT_UNITS(v_free * v_pagesize,'B',2 );

	IF v_used > v_dbs_red_threshold
	THEN
		LET v_alert_color = 'RED';
		LET v_message ='DBSPACE ' || TRIM(v_dbs_name) || ' exceed the RED threshold (' ||v_dbs_red_threshold||'). Currently using ' || v_used ||'%. '||TRIM(v_units_used)||' used. '||TRIM(v_units_free)||' free.';
		LET v_severity = v_severity_red;
	ELSE
		IF v_used > v_dbs_yellow_threshold
		THEN
			LET v_alert_color = 'YELLOW';
			LET v_message ='DBSPACE ' || TRIM(v_dbs_name) || ' exceed the YELLOW threshold (' ||v_dbs_yellow_threshold||'). Currently using ' || v_used  ||'%. '||TRIM(v_units_used)||' used. '||TRIM(v_units_free)||' free.';
			LET v_severity = v_severity_yellow;
		ELSE
			LET v_alert_color = NULL;
		END IF
	END IF


	IF v_alert_color IS NULL
	THEN
		---------------------------------------------------------------------------
		-- The used space is lower than any of the thresholds...
		-- check to see if there is an already inserted alarm
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
			AND p.alert_object_name = v_dbs_name
			AND p.alert_state = "NEW";
		
		IF v_alert_id IS NOT NULL
		THEN

			UPDATE
				ph_alert
			SET
				alert_state = 'ADDRESSED'
			WHERE
				ph_alert.id = v_alert_id;
	
			IF v_current_alert_color = 'RED' THEN
				LET v_severity = v_severity_red;
			ELSE
				LET v_severity = v_severity_yellow;
			END IF;
			LET v_message = 'Previous alarm for DBSPACE '||TRIM(v_dbs_name)||' removed. Currently below thresholds';
			EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'DBSPACE used space too high',v_message,NULL);
		END IF;
	ELSE
		
		---------------------------------------------------------------------------
		-- The used space is bigger than one of the thresholds...
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
			AND p.alert_object_name = v_dbs_name
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
				'NEW', CURRENT YEAR TO SECOND,'DBSPACE', v_dbs_name, v_message, 'sysadmin');
 
			EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'DBSPACE used space too high',v_message,NULL);

		ELSE
			---------------------------------------------------------------------------
			-- There is an alarm...
			-- Need to check if it's still the same color...
			---------------------------------------------------------------------------
			IF v_current_alert_color != v_alert_color
			THEN
				---------------------------------------------------------------------------
				-- Change the color... And reset the seq to reactivate the couter...
				---------------------------------------------------------------------------
				UPDATE ph_alert
				SET (alert_task_seq, alert_color) = (v_id,v_alert_color)
				WHERE ph_alert.id = v_alert_id;
				EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'DBSPACE used space too high',v_message,NULL);
			ELSE
				IF (v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
				THEN
					EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'DBSPACE used space too high',v_message,NULL);
				END IF;
			END IF;
		END IF;
	END IF;
END FOREACH

END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Check Space';

INSERT INTO ph_threshold VALUES(0, 'NUM ALARMS','Monit Check Space', '3', 'NUMERIC', 'Number of alarms sent');
INSERT INTO ph_threshold VALUES(0, 'ALARM CLASS','Monit Check Space', '908', 'NUMERIC', 'Class id for alarmprogram');
INSERT INTO ph_threshold VALUES(0, 'YELLOW ALARM SEVERITY','Monit Check Space', '3', 'NUMERIC', 'Severity of the YELLOW alarm');
INSERT INTO ph_threshold VALUES(0, 'RED ALARM SEVERITY','Monit Check Space', '4', 'NUMERIC', 'Severity of the RED alarm');
INSERT INTO ph_threshold VALUES(0, 'DBSPACE YELLOW DEFAULT','Monit Check Space', '90', 'NUMERIC', 'Default usage percentage for YELLOW alarms');
INSERT INTO ph_threshold VALUES(0, 'DBSPACE RED DEFAULT','Monit Check Space', '95', 'NUMERIC', 'Default usage percentage for RED alarms');
INSERT INTO ph_threshold VALUES(0, 'DBSPACE EXCLUDE LIST','Monit Check Space', 'rootdbs,physdbs,llogdbs', 'STRING', 'Comma separated list of dbspaces to exclude from monitoring');
-- Example for other dbspaces (dbspace named "work"):
-- INSERT INTO ph_threshold VALUES(0, 'DBSPACE YELLOW work','Monit Check Space', '85', 'NUMERIC', 'Usage percentage that triggers YELLOW alarm for dbspace named work');
-- INSERT INTO ph_threshold VALUES(0, 'DBSPACE RED work','Monit Check Space', '90', 'NUMERIC', 'Usage percentage that triggers RED alarm for dbspace named work');


------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Check Space';

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
	'Monit Check Space',
	'Task to monitor the usage space in the dbspaces',
	'TASK',
	'monit_check_space',
	'00:00:00',
	NULL,
	'0 00:30:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);

