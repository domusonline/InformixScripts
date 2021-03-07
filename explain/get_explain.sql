-- Copyright (c) 2021 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision: 2.0.53 $
-- $Date: 2021-03-07 13:01:52 $
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.
--

-- This function retrieves the explain file


-- DROP FUNCTION get_explain;
CREATE FUNCTION get_explain() RETURNING CLOB AS explain_plans;
  DEFINE GLOBAL explain_file_name VARCHAR(255) DEFAULT NULL;
  DEFINE GLOBAL explain_file_dir VARCHAR(255) DEFAULT NULL;
  DEFINE exp_file VARCHAR(255);
  DEFINE v_ret CLOB;

  IF explain_file_name IS NOT NULL AND explain_file_dir IS NOT NULL
  THEN
    LET exp_file = explain_file_dir||'/'||explain_file_name;
    LET v_ret = FILETOCLOB(exp_file,'server');
    RETURN v_ret;
  END IF;
END FUNCTION;
