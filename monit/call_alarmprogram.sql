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
-- Purpose: interface with alarmprogram to have a centralized administration of alerts
-- Description: This is an auxiliary procedure called by the monit functions and in turn it will call the alarmprogram
-- Parameters:


-- DROP PROCEDURE IF EXISTS call_alarmprogram;

CREATE PROCEDURE call_alarmprogram(
	v_severity  SMALLINT,
	v_class     SMALLINT,
	v_class_msg VARCHAR(255) ,
	v_specific  VARCHAR(255) ,
	v_see_also  VARCHAR(255),
	v_uniqid    INTEGER DEFAULT NULL
)


--   severity: Category of event
--   class-id: Class identifier
--   class-msg: string containing text of message
--   specific-msg: string containing specific information
--   see-also: path to a see-also file
--   event-uniqid: unique ID of the event

DEFINE v_command CHAR(2000);
DEFINE v_alarmprogram VARCHAR(255);

--SET DEBUG FILE TO '/tmp/call_alarmprogram.dbg' WITH APPEND;
--TRACE ON;

SELECT
	cf_effective
INTO
	v_alarmprogram
FROM
	sysmaster:sysconfig
WHERE
      cf_name = "ALARMPROGRAM";

-- There's some risk of command injection into the script defined in the ALARMPROGRAM. Execution permission should be given only to "informix"

LET v_command = TRIM(v_alarmprogram) || " " || v_severity || " " || v_class || " '" || v_class_msg || "' '" || NVL(v_specific,v_class_msg) || "' '" || NVL(v_see_also,' ') || "' " || NVL(v_uniqid, ' ');
SYSTEM v_command;
END PROCEDURE;
