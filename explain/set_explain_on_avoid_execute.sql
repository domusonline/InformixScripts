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
