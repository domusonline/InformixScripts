CREATE PROCEDURE get_explain() RETURNING CLOB AS explain;
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
END PROCEDURE;
