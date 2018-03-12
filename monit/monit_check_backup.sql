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
-- Purpose: Check that all dbspaces have backups
-- Description: This function will verify if all the dbspaces have backups matching the policy for L0 and any level (number of days old)
-- Parameters (name, type, default, description):
--	NUM ALARMS          NUMERIC     3          Number of alarms sent
--	ALARM CLASS         NUMERIC     906        Class id for alarmprogram
--	BASE ALARM SEVERITY NUMERIC     4          Severity for lack of level 0 backup initial
--	NEXT ALARM SEVERITY NUMERIC     4          Severity for lack of level 0 backup when increased
--	BASE ALERT COLOR    STRING      YELLOW     Color for first alarm
--	NEXT ALERT COLOR    STRING      RED        Color for increased alarm
--	CHANGE COLOR        NUMERIC     5          After how many alarms does it change color
--	ANY LEVEL GENERIC   NUMERIC     30         Number of days without any backup that triggers the alarm
--	LEVEL 0 GENERIC     NUMERIC     30         Number of days without level 0 backup that triggers the alarm


--DROP FUNCTION IF EXISTS monit_check_backup;

CREATE FUNCTION monit_check_backup(v_task_id INT, v_id INT) RETURNING INTEGER;

------------------------------------------------------------------------------------------
-- Generic help variables to allow interaction with OAT and ALARMPROGRAM
------------------------------------------------------------------------------------------

DEFINE v_num_alarms SMALLINT;
DEFINE v_alert_id LIKE ph_alert.id;
DEFINE v_alert_task_seq LIKE ph_alert.alert_task_seq;
DEFINE v_alert_color, v_alert_color_next, v_current_alert_color CHAR(6);
DEFINE v_message VARCHAR(254,0);
DEFINE v_see_also VARCHAR(254,0);

DEFINE v_severity, v_severity_initial, v_severity_next SMALLINT;
DEFINE v_class, v_change_color, v_change_color_nolevel0, v_change_color_level0, v_change_color_level SMALLINT;


DEFINE v_nolevel0_flag, v_level0_flag, v_level_flag SMALLINT;

------------------------------------------------------------------------------------------
-- To get the parameters from ph_threshold on a FOREACH loop
------------------------------------------------------------------------------------------
DEFINE v_aux_threshold_name LIKE ph_threshold.name;
DEFINE v_aux_threshold_value LIKE ph_threshold.value;

DEFINE v_level_threshold SMALLINT;
DEFINE v_level0_threshold SMALLINT;

DEFINE v_dbspace_num INTEGER;
DEFINE v_dbspace_name CHAR(257);
DEFINE v_level_0 INTEGER;
DEFINE v_level_1 INTEGER;
DEFINE v_level_2 INTEGER;
DEFINE v_arcdist INTERVAL DAY(5) TO SECOND;

---------------------------------------------------------------------------
-- Uncomment to activate debug
---------------------------------------------------------------------------
--SET DEBUG FILE TO '/tmp/monit_check_backup.dbg' WITH APPEND;
--TRACE ON;

---------------------------------------------------------------------------
-- Default values if nothing is configured in ph_threshold table
---------------------------------------------------------------------------
LET v_num_alarms=3;
LET v_class = 906;
LET v_severity_initial = 4;
LET v_severity_next = 4;
LET v_alert_color = 'YELLOW';
LET v_alert_color_next = 'RED';
LET v_change_color = 5;
LET v_change_color_nolevel0 = 5;
LET v_change_color_level0 = 5;
LET v_level_threshold = 30;
LET v_level0_threshold = 30;


---------------------------------------------------------------------------
-- Get the defaults configured in the ph_threshold table
---------------------------------------------------------------------------

LET v_nolevel0_flag = 0;
LET v_level0_flag = 0;
LET v_level_flag = 0;
FOREACH
	SELECT
		p.name, p.value
	INTO
		v_aux_threshold_name, v_aux_threshold_value
	FROM
		ph_threshold p
	WHERE
		p.task_name = 'Monit Check Backup'

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
	IF v_aux_threshold_name = 'BASE ALARM SEVERITY'
	THEN
		LET v_severity_initial = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'NEXT ALARM SEVERITY'
	THEN
		LET v_severity_next = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'BASE ALERT COLOR'
	THEN
		LET v_alert_color = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'NEXT ALERT COLOR'
	THEN
		LET v_alert_color_next = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'CHANGE COLOR'
	THEN
		LET v_change_color = v_aux_threshold_value;
		LET v_change_color_level0 = v_change_color;
		LET v_change_color_nolevel0 = v_change_color;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'ANY LEVEL GENERIC'
	THEN
		LET v_level_threshold = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
	IF v_aux_threshold_name = 'LEVEL 0 GENERIC'
	THEN
		LET v_level0_threshold = v_aux_threshold_value;
		CONTINUE FOREACH;
	END IF;
END FOREACH;

FOREACH
	SELECT
		dbsnum, name, level0, level1, level2
	INTO
		v_dbspace_num, v_dbspace_name, v_level_0, v_level_1, v_level_2
	FROM
		sysmaster:sysdbstab
	WHERE
		dbsnum > 0 AND
		sysmaster:bitval(flags, '0x2000')=0
-- AND
--		(
--			(
--				( CURRENT - DBINFO("utc_to_datetime",level0) > v_level_threshold UNITS HOUR ) AND
--			        ( CURRENT - DBINFO("utc_to_datetime",level1) > v_level_threshold UNITS HOUR ) AND
--				( CURRENT - DBINFO("utc_to_datetime",level2) > v_level_threshold UNITS HOUR )
--			)
--			OR
--			(CURRENT - DBINFO("utc_to_datetime",level0) > v_level0_threshold UNITS HOUR )
--		)


	IF v_level_0 = 0
	THEN 
		------------------------------------------------------------------------------------
		-- DBSPACE has no level 0 backup ever!
		-- Check to see if it has an alarm...
		------------------------------------------------------------------------------------
		LET v_alert_id = NULL;
	
		SELECT                   
			p.id, p.alert_task_seq, p.alert_color
		INTO                             
			v_alert_id, v_alert_task_seq, v_current_alert_color
		FROM                             
			ph_alert p       
		WHERE            
			p.alert_task_id = v_task_id
			AND p.alert_object_name = 'NO LEVEL 0 ' ||TRIM(v_dbspace_name)
			AND p.alert_state = "NEW"; 

		IF v_alert_id IS NULL
		THEN
			---------------------------------------------------------------------------
			-- There is no alarm... Insert it and set flag to call alarmprogram...
			---------------------------------------------------------------------------
	        	INSERT INTO ph_alert
			(id, alert_task_id, alert_task_seq, alert_type, alert_color, alert_object_type,
			alert_object_name, alert_message,alert_action)
			VALUES
			(0, v_task_id, v_id, "WARNING", v_alert_color, "SERVER",
			'NO LEVEL 0 ' ||TRIM(v_dbspace_name), "Dbspace ["||trim(v_dbspace_name)|| "] has never had a level 0 backup. Recommend taking a level 0 backup immediately." , NULL);

			IF v_nolevel0_flag IN (0,3)
			THEN
				LET v_nolevel0_flag = 1;
			END IF
		ELSE
			---------------------------------------------------------------------------
			-- There is an alarm... check to see if we should call the alarm program
			-- and change the color....
			---------------------------------------------------------------------------

			IF ( v_id >= v_alert_task_seq + v_change_color_nolevel0 ) AND ( v_change_color_nolevel0 != 0 )
			AND (v_current_alert_color = v_alert_color)
			THEN
				UPDATE ph_alert
				SET (alert_task_seq, alert_color) = (v_id,v_alert_color_next)
				WHERE ph_alert.id = v_alert_id;

				LET v_nolevel0_flag = 2;
			ELSE
				IF ( v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
				THEN
					IF v_nolevel0_flag IN (0,3)
					THEN
						LET v_nolevel0_flag = 1;
					END IF
				END IF
			END IF
		END IF;
		CONTINUE FOREACH;
	ELSE
		--------------------------------------------------------------------------------------
		-- DBSPACE has level 0... check to see if there is an alert for lack of it...
		-- If yes, ADDRESS it and if v_nolevel0 flag is still clear set it to 3...
		--------------------------------------------------------------------------------------

		LET v_alert_id = NULL;
	
		SELECT                   
			p.id, p.alert_task_seq, p.alert_color
		INTO                             
			v_alert_id, v_alert_task_seq, v_current_alert_color
		FROM                             
			ph_alert p       
		WHERE            
			p.alert_task_id = v_task_id
			AND p.alert_object_name = 'NO LEVEL 0 '||TRIM(v_dbspace_name)
			AND p.alert_state = "NEW"; 
				

		IF v_alert_id IS NOT NULL
		THEN
			UPDATE
				ph_alert
			SET
				alert_state = 'ADDRESSED'
			WHERE
				ph_alert.id = v_alert_id;

			IF v_nolevel0_flag = 0
			THEN
				LET v_nolevel0_flag = 3;
			END IF
		END IF

		--------------------------------------------------------------------------------------
		-- ... and now continue to check if it has a "valid" backup...
		-- Lets start with level0 threshold...
		--------------------------------------------------------------------------------------


		IF CURRENT-DBINFO("utc_to_datetime",v_level_0) > v_level0_threshold UNITS HOUR
		THEN 
		        LET v_arcdist = CURRENT - DBINFO("utc_to_datetime",v_level_0);

			-----------------------------------------------------------------------------
			-- LEVEL 0 too old....
			-----------------------------------------------------------------------------
			LET v_alert_id = NULL;
	
			SELECT                   
				p.id, p.alert_task_seq, p.alert_color
			INTO                             
				v_alert_id, v_alert_task_seq, v_current_alert_color
			FROM                             
				ph_alert p       
			WHERE            
				p.alert_task_id = v_task_id
				AND p.alert_object_name = 'LEVEL 0 TOO OLD '||TRIM(v_dbspace_name)
				AND p.alert_state = "NEW"; 


			IF v_alert_id IS NULL
			THEN
				---------------------------------------------------------------------------
				-- There is no alarm... Insert it and set flag to call alarmprogram...
				---------------------------------------------------------------------------
		        	INSERT INTO ph_alert
				(id, alert_task_id,alert_task_seq,alert_type, alert_color, alert_object_type,
				alert_object_name, alert_message,alert_action)
				VALUES (0,v_task_id, v_id, "WARNING", v_alert_color, "SERVER",
				'LEVEL 0 TOO OLD '||TRIM(v_dbspace_name), "Dbspace ["||trim(v_dbspace_name)|| "] has not had a level 0 backup for " || v_arcdist|| ".  Recommend taking a level 0 backup immediately.", NULL);
				IF v_level0_flag IN (0,3)
				THEN
					LET v_level0_flag = 1;
				END IF
			ELSE
				---------------------------------------------------------------------------
				-- There is an alarm... check to see if we should call the alarm program
				-- and change the color....
				---------------------------------------------------------------------------

				IF ( v_id >= v_alert_task_seq + v_change_color_level0 ) AND ( v_change_color_level0 != 0 )
				AND (v_current_alert_color = v_alert_color)
				THEN
					UPDATE ph_alert
					SET (alert_task_seq, alert_color) = (v_id,v_alert_color_next)
					WHERE ph_alert.id = v_alert_id;

					LET v_level0_flag = 2;
				ELSE
					IF ( v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
					THEN
						IF v_level0_flag IN (0,3)
						THEN
							LET v_level0_flag = 1;
						END IF
					END IF
				END IF
			END IF
		ELSE
	

			LET v_alert_id = NULL;
	
			SELECT                   
				p.id, p.alert_task_seq, p.alert_color
			INTO                             
				v_alert_id, v_alert_task_seq, v_current_alert_color
			FROM                             
				ph_alert p       
			WHERE            
				p.alert_task_id = v_task_id
				AND p.alert_object_name = 'LEVEL 0 TOO OLD ' ||TRIM(v_dbspace_name)
				AND p.alert_state = "NEW"; 

			IF v_alert_id IS NOT NULL
			THEN
				UPDATE
					ph_alert
				SET
					alert_state = 'ADDRESSED'
				WHERE
					ph_alert.id = v_alert_id;

				IF v_level0_flag = 0
				THEN
					LET v_level0_flag = 3;
				END IF
			END IF
		END IF

		IF v_level_0 > v_level_1 THEN
			LET v_arcdist = CURRENT - DBINFO("utc_to_datetime",v_level_0);
		ELIF v_level_1 > v_level_2 THEN
			LET v_arcdist = CURRENT - DBINFO("utc_to_datetime",v_level_1);
		ELSE
			LET v_arcdist = CURRENT - DBINFO("utc_to_datetime",v_level_2);
		END IF



		IF v_arcdist > v_level_threshold UNITS HOUR
		THEN 

			-----------------------------------------------------------------------------
			-- Any level too old....
			-----------------------------------------------------------------------------
			LET v_alert_id = NULL;
	
			SELECT                   
				p.id, p.alert_task_seq, p.alert_color
			INTO                             
				v_alert_id, v_alert_task_seq, v_current_alert_color
			FROM                             
				ph_alert p       
			WHERE            
				p.alert_task_id = v_task_id
				AND p.alert_object_name = 'ANY LEVEL TOO OLD ' ||TRIM(v_dbspace_name)
				AND p.alert_state = "NEW"; 


			IF v_alert_id IS NULL
			THEN
				---------------------------------------------------------------------------
				-- There is no alarm... Insert it and set flag to call alarmprogram...
				---------------------------------------------------------------------------
		        	INSERT
				INTO ph_alert (id, alert_task_id,alert_task_seq,alert_type, alert_color,
					alert_object_type, alert_object_name, alert_message,alert_action)
				VALUES (0,v_task_id, v_id, "WARNING", v_alert_color,
				"SERVER",'ANY LEVEL TOO OLD ' ||TRIM(v_dbspace_name),
				"Dbspace ["||trim(v_dbspace_name)|| "] has not had a backup for "
				|| v_arcdist||". Recommend taking a backup immediately.", NULL);
				IF v_level_flag IN (0,3)
				THEN
					LET v_level_flag = 1;
				END IF
			ELSE
				---------------------------------------------------------------------------
				-- There is an alarm... check to see if we should call the alarm program
				-- and change the color....
				---------------------------------------------------------------------------

				IF ( v_id >= v_alert_task_seq + v_change_color ) AND ( v_change_color != 0 )
				AND ( v_current_alert_color = v_alert_color)
				THEN
					UPDATE ph_alert
					SET (alert_task_seq, alert_color) = (v_id,v_alert_color_next)
					WHERE ph_alert.id = v_alert_id;

					LET v_level_flag = 2;
				ELSE
					IF ( v_id < v_alert_task_seq + v_num_alarms) OR ( v_num_alarms = 0 )
					THEN
						IF v_level_flag IN (0,3)
						THEN
							LET v_level_flag = 1;
						END IF
					END IF
				END IF
			END IF
		ELSE
	

			LET v_alert_id = NULL;
	
			SELECT                   
				p.id, p.alert_task_seq, p.alert_color
			INTO                             
				v_alert_id, v_alert_task_seq, v_current_alert_color
			FROM                             
				ph_alert p       
			WHERE            
				p.alert_task_id = v_task_id
				AND p.alert_object_name = 'ANY LEVEL TOO OLD '||TRIM(v_dbspace_name)
				AND p.alert_state = "NEW"; 

			IF v_alert_id IS NOT NULL
			THEN
				UPDATE
					ph_alert
				SET
					alert_state = 'ADDRESSED'
				WHERE
					ph_alert.id = v_alert_id;

				IF v_level_flag = 0
				THEN
					LET v_level_flag = 3;
				END IF
			END IF
		END IF
	END IF
END FOREACH

-- flag = 0 nothing to report....
-- flag = 1 one alarm...
-- flag = 2 changed color
-- flag = 3 cleared

IF v_nolevel0_flag != 0
THEN
	IF v_nolevel0_flag = 1
	THEN
		LET v_message = "There is at least one DBSPACE without level 0 backup!";
		LET v_severity = v_severity_initial;
	ELSE
		IF v_nolevel0_flag = 2
		THEN
			LET v_message = "There is at least one DBSPACE without level 0 backup. Severity increased!!!";
			LET v_severity = v_severity_next;
		ELSE
			IF v_nolevel0_flag = 3
			THEN
				LET v_message = "Previous alarm for DBSPACE without level 0 backup cleared.";
				LET v_severity = v_severity_initial;
			END IF
		END IF
	END IF;

	EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Check backups',v_message,NULL);
END IF;

IF v_level0_flag != 0
THEN
	IF v_level0_flag = 1
	THEN
		LET v_message = "There is at least one DBSPACE with a level 0 backup older than " ||v_level0_threshold||" hours!";
		LET v_severity = v_severity_initial;
	ELSE
		IF v_level0_flag = 2
		THEN
			LET v_message = "There is at least one DBSPACE with a level 0 backup older than " ||v_level0_threshold||" hours! Increased severity!!!";
			LET v_severity = v_severity_next;
		ELSE
			IF v_level0_flag = 3
			THEN
				LET v_message = "Previous alarm for DBSPACE with too old level 0 backup cleared.";
				LET v_severity = v_severity_initial;
			END IF
		END IF
	END IF;
	EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Check backups',v_message,NULL);
END IF

IF v_level_flag != 0
THEN
	IF v_level_flag = 1
	THEN
		LET v_message = "There is at least one DBSPACE without a backup within " ||v_level_threshold||" hours!";
		LET v_severity = v_severity_initial;
	
	ELSE
		IF v_level_flag = 2
		THEN
			LET v_message = "There is at least one DBSPACE without a backup within " ||v_level_threshold||" hours! Increased severity!!!";
			LET v_severity = v_severity_next;
		ELSE
			IF v_level_flag = 3
			THEN
				LET v_message = "Previous alarm for DBSPACE without a backup in the last hours cleared.";
				LET v_severity = v_severity_initial;
			END IF
		END IF
	END IF;
	EXECUTE PROCEDURE call_alarmprogram(v_severity, v_class, 'Check backups',v_message,NULL);
END IF;

RETURN 0;

END FUNCTION;

------------------------------------------------------------------------------------------------------
-- Configuration of parameters in the ph_threshold table
------------------------------------------------------------------------------------------------------
DELETE FROM ph_threshold WHERE task_name = 'Monit Check Backup';

INSERT INTO ph_threshold VALUES(0, 'NUM ALARMS','Monit Check Backup','3', 'NUMERIC', 'Number of alarms sent');
INSERT INTO ph_threshold VALUES(0, 'ALARM CLASS','Monit Check Backup','906','NUMERIC', 'Class id for alarmprogram');
INSERT INTO ph_threshold VALUES(0, 'BASE ALARM SEVERITY','Monit Check Backup', '4', 'NUMERIC','Severity for lack of level 0 backup initial');
INSERT INTO ph_threshold VALUES(0, 'NEXT ALARM SEVERITY','Monit Check Backup','4', 'NUMERIC','Severity for lack of level 0 backup when increased');
INSERT INTO ph_threshold VALUES(0, 'BASE ALERT COLOR','Monit Check Backup','YELLOW', 'STRING','Color for first alarm');
INSERT INTO ph_threshold VALUES(0, 'NEXT ALERT COLOR','Monit Check Backup','RED', 'STRING','Color for increased alarm');
INSERT INTO ph_threshold VALUES(0, 'CHANGE COLOR','Monit Check Backup','5', 'NUMERIC', 'After how many alarms does it change color');
INSERT INTO ph_threshold VALUES(0, 'ANY LEVEL GENERIC','Monit Check Backup','3', 'NUMERIC', 'Number of days without any backup that triggers the alarm');
INSERT INTO ph_threshold VALUES(0, 'LEVEL 0 GENERIC','Monit Check Backup','30', 'NUMERIC', 'Number of days without level 0 backup that triggers the alarm');

------------------------------------------------------------------------------------------------------
-- Creation and schedule of the task
------------------------------------------------------------------------------------------------------
DELETE FROM ph_task WHERE tk_name = 'Monit Check Backup';

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
	'Monit Check Backup',
	'Task to monitor the execution of backups',
	'TASK',
	'monit_check_backup',
	'00:00:00',
	NULL,
	'0 06:00:00',
	'T','T','T','T','T','T','T',
	'USER',
	'T'
);

--EXECUTE FUNCTION EXECTASK('Monit Check Backup');
