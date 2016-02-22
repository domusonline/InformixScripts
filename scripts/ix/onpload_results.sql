-- Copyright (c) 2010-2016 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision 2.0.1 $
-- $Date 2016-02-22 02:38:48$
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.

DROP TABLE onpload_results;
CREATE TABLE onpload_results
(
	id SERIAL,
	username CHAR(18),
	session_id INTEGER,
	tstamp DATETIME YEAR TO FRACTION(5),
	cmd VARCHAR(255),
	result_code INTEGER,
	result_text TEXT
) EXTENT SIZE 5000 NEXT SIZE 5000 LOCK MODE ROW;

CREATE INDEX ix_onpload_results_1 ON onpload_results(session_id);
CREATE INDEX ix_onpload_results_2 ON onpload_results(username,tstamp);

GRANT select,insert ON onpload_results TO public;


DROP PROCEDURE start_onpload;

CREATE PROCEDURE start_onpload(args CHAR(200)) RETURNING INT AS return_code, INT AS return_id;


	DEFINE command CHAR(500); -- build command string here
	DEFINE osname  CHAR(128); -- Operating System name.

	DEFINE v_result_id, v_result_code, v_sessionid INT;
	DEFINE v_result_text CHAR(1000);
	DEFINE v_servername CHAR(128);
	DEFINE v_serverdir CHAR(128);
	DEFINE v_serversqlhosts CHAR(128);

	LET v_sessionid = DBINFO('sessionid');

	IF (args MATCHES '*[;$%]*') THEN
		RETURN -1, NULL;
	END IF;

	SELECT os_name INTO osname FROM sysmaster:sysmachineinfo;

	SELECT env_value INTO v_servername FROM sysmaster:sysenv WHERE env_name = 'INFORMIXSERVER';
	SELECT env_value INTO v_serverdir FROM sysmaster:sysenv WHERE env_name = 'INFORMIXDIR';
	SELECT env_value INTO v_serversqlhosts FROM sysmaster:sysenv WHERE env_name = 'INFORMIXSQLHOSTS';

	IF (osname = 'Windows') then
		LET command = 'cmd /c %INFORMIXDIR%\bin\onpload ' || args;
	ELSE
		LET command = '/usr/informix/bin/ixonpload ' || TRIM(v_servername) || " " || TRIM(v_serverdir) || " " || TRIM(v_serversqlhosts) || " " || v_sessionid || " gbdia " || USER || " " || args;
	END IF;

	LET v_result_id = NULL;

	SYSTEM (command);
	SELECT MAX(id)
	INTO v_result_id
	FROM onpload_results
	WHERE session_id = v_sessionid;

	IF v_result_id IS NOT NULL
	THEN
		SELECT
			result_code
		INTO
			v_result_code
		FROM
			onpload_results
		WHERE
			id = v_result_id;

		RETURN v_result_code, v_result_id;
	ELSE
		RETURN -2,NULL;
	END IF
END PROCEDURE;
GRANT EXECUTE ON start_onpload TO public;
