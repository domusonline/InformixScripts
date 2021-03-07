# Explain procedures

A set of SQL scripts that will create auxiliary procedures to obtain the query plans on any tool


[http://informix-technology.blogspot.com](http://informix-technology.blogspot.com "Fernando Nunes's blog")

### Introdution

Obtaining the query plan on Informix has always been a challenge. These procedures propose a way to do it, on any tool, that will work with any Informix version starting with V10.
It's based on the ability to retrieve a file as a BLOB. So the procedures create the normal explain files and then there's one (get_explain()) that will retrieve that file as a BLOB

###Distribution and license

These repository uses GPL V2 (unless stated in a specific script or folder). In short terms it means you can use the contents freely. If you change them and distribute the results, you must also make the "code" available (with the current contents this is redundant as the script is the code)- The full license text can be read here:

[http://www.gnu.org/licenses/old-licenses/gpl-2.0.html](http://www.gnu.org/licenses/old-licenses/gpl-2.0.html "GNU GPL V2")

### Disclaimer

These scripts are provided AS IS. No guaranties of any sort are provided. Use at your own risk<br/>
None of the scripts should do any harm to your instances or your data. The worst they could do is to provide some misleading information.
However, bad configuration or any unkown bug for example in the environment configuration script (setinfx) could cause some confusion and put you in a situation where you could be adminisering the wrong instance.
Please test the scripts in non critical environments before you put them into production

### Support

As stated in the disclaimer section above, the scripts are provided AS IS. The author will not guarantee any sort of support.

Nevertheless the author is insterested in improving these scripts. if you find a bug or have some special need please contact the author and provide information that can help him fix the bug ordecide if the feature is relevant and can be added in a future version

### Description

These scripts contain procedures that can be created in a system database (like sysadmin) or on each individual database. Execution and connect permissions to a central database (if created in one) must be provided by the DBA and aren't currently included in the scripts.
The configuration relative to _where_ the files are created, and the filenames can be changed in the _set_explain_on and _set_explain_on_avoid_execute_ procedures. Default settings create them in /tmp and in a way where the session ID is included in the filename. This means a single user will have/see different files if using the procedures in different sessions. Otherwise they will interfere with each other (because the activation of the SET EXPLAIN will reset the file). Note that the files are not cleared. This means they will accumulate on the defined directory. A cleaning process should be put in place to avoid this (clearing files older than one day for example)
To turn off explain simply use the SQL statement SET EXPLAIN OFF

Example of usage:

EXECUTE PROCEDURE set_expalin_on_avoid_execute();
SELECT ... FROM ... WHERE ...;
EXECUTE PROCEDURE get_explain();

The procedures are:

* set_explain_on

   Creates the procedure _set_explain_on_  
   This procedure initializes the explain file on a script defined directory (user permissions must be granted) and activates the explain


* set_explain_on_avoid_execute

   Creates the function _set_explain_on_avoid_execute_
   This function is equivalent to _set_explain_on_ but activates the explain without execution option

* reset_explain

   Creates the function _reset_explain_
   This function simply clears the previously defined explain file. If no file was created/activated by the previous procedures, an error will be raised

* get_explain

   Creates the function _get_explain_
   This function obtains the previously defined explain file

### TODO

