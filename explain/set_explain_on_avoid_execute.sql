-- Copyright (c) 2021 Fernando Nunes - domusonline@gmail.com
-- License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
-- $Author: Fernando Nunes - domusonline@gmail.com $
-- $Revision: 2.0.51 $
-- $Date: 2021-03-07 03:18:57 $
-- Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
--             Although the author is/was an IBM employee, this software was created outside his job engagements.
--             As such, all credits are due to the author.
--

-- This function will activates the explain without execution. This clears the file
-- Note that by default the files are created per user and per session on /tmp
--     This can be changed by editing the default directory (explain_file_dir)
--    and the filename creation rule
CREATE PROCEDURE set_explain_on_avoid_execute()
  DEFINE GLOBAL explain_file_name VARCHAR(255) DEFAULT NULL;
  DEFINE GLOBAL explain_file_dir VARCHAR(255) DEFAULT '/tmp';
  DEFINE GLOBAL explain_execute BOOLEAN DEFAULT NULL;
  DEFINE exp_file, sys_cmd VARCHAR(255);

  LET explain_file_name = USER||'.'||DBINFO('sessionid');
  LET exp_file = explain_file_dir||'/'||explain_file_name;
  LET sys_cmd='cat /dev/null > '||exp_file;
  SYSTEM(sys_cmd);
  SET EXPLAIN FILE TO exp_file;
  SET EXPLAIN ON AVOID_EXECUTE;
  LET explain_execute = 'f';
END PROCEDURE;
