-- Copyright (c) 2021 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision: 2.0.53 $
-- $Date: 2021-03-07 13:01:52 $
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.
--

-- This function will clear the explain file


--DROP PROCEDURE reset_explain;
CREATE PROCEDURE reset_explain()
  DEFINE GLOBAL explain_file_name VARCHAR(255) DEFAULT NULL;
  DEFINE GLOBAL explain_file_dir VARCHAR(255) DEFAULT NULL;
  DEFINE GLOBAL explain_execute BOOLEAN DEFAULT NULL;
  DEFINE exp_file,sys_cmd VARCHAR(255);

  IF explain_file_dir IS NOT NULL AND explain_file_name IS NOT NULL
  THEN
    LET exp_file = explain_file_dir ||'/'||explain_file_name;
    SET EXPLAIN OFF;
    LET sys_cmd='cat /dev/null > '||exp_file;
    SYSTEM(sys_cmd);
    SET EXPLAIN FILE TO exp_file;
    IF explain_execute = 't'
    THEN
      SET EXPLAIN ON;
    ELSE
      IF explain_execute = 'f'
      THEN
        SET EXPLAIN ON AVOID_EXECUTE;
      ELSE
        RAISE EXCEPTION -746, "Execute option of set explain is not defined!";
      END IF;
    END IF;
  ELSE
    RAISE EXCEPTION -746, "Explain file or dir is not set!";
  END IF;
END PROCEDURE;
