# Monit Project

A repository of Informix sysadmin functions to monitor certain aspects of the instances by Fernando Nunes (domusonline@gmail.com)
If you're interested in Informix the author would also recommend his blog at:

[http://informix-technology.blogspot.com](http://informix-technology.blogspot.com "Fernando Nunes's blog")

### Introdution

The documentation is the weakest part of this repository. For now I'm just including a very brief description of the structure and contents of the project.

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

These project refers to a series of functions to be created in the sysadmin database. These functions are then used to create TASKS.
Each script includes the instructions to create the functions and the tasks (ph_task) as well as the parameter for each task (ph_threshold)

The tasks/functions are:

* call_alarmprogram.sql

   Creates the procedure _call_alarmprogram_  
   This procedure is an auxiliary procedure that interfaces between the several tasks and the alarmprogram. The idea is to configure a proper alarmprogram and then use it to send the alarms.  
   This allows for a centralized configuration of the alarm methods. This procedure accepts the same parameter as the alarmprogram

* monit_check_backup.sql

   Creates the function _monit_check_backup_  
   This function implements the TASK _Monit Check Backup_ that verifies that each dbspace has a level 0 and a backup of any level in the configured number of days

* monit_check_extents.sql

   Creates the function _monit_check_extents_  
   This function implements the TASK _Monit Check Extents_ that verifies if the number of extents in each table exceeds the defined thresholds. A report is generated in the DUMPDIR location and alarms are generated. Note that until version 11.70 there is a hard limit for the number of extents. The limit depends on the page size and the table structure, but rounds 220 on 2KB pages and double of that for 4KB. On versions where the limit is not enforced, it's still a good practice to keep the number low. And an high number of extents may indicate the dbspace is highly fragmented and it will trigger extent size doubling which may cause further allocations to become huge (if there is free space at time of allocation)

* monit_check_numpages.sql

   Creates the function _monit_check_numpages_  
   This function implements the TASK _Monit Check Num Pages_ that verifies if the number of pages in each table fragment exceed the defined thresholds. Note that there is an hard limit for the number of pages (16777216). If a fragment reaches this value no more rows can be inserted nor new extents allocated.

* monit_check_session_mem.sql

   Creates the function _monit_check_session_mem_  
   This function implements the TASK _Monit Check Session Memory_ that verifies the ammount of memory allocated by a session does not exceed the defined thresholds. Too much memory on a session usually means either a memory leak or a programming error (repeatedly preparing the same statements). The task allows sessions over a defined limit to be automatically killed, unless the user belongs to a specified list of users

* monit_check_session_status.sql

   Creates the function _monit_check_session_status_  
   This function implements the TASK/SENSOR _Monit Check Session Status_ that verifies the session status. It looks for active sessions, sessions waiting on buffers, locks, logical log buffers, transaction slots and mutexes. Thresholds (both absoulte and percent) can be given for all these as well as for total number of sessions. A minimum number of sessions in the engine can be defined to activate the alarms (with very low number of sessions, the percent thresholds may become fuzzy). The task can be configured to work as a SENSOR (collects data), as a TASK (just alarms) or both

* monit_check_space.sql:

   Creates the function _monit_check_space_  
   This function implements the TASK _Monit Check Space_ that verifies the free space in each dbspace. Thresholds for YELLOW and RED alarms can be defined generically or for specific dbspaces. A list of dbspaces to be excluded from the verification can be provided (for physical and logical logs dbspaces for example)

* monit_ckp_duration.sql

   Creates the function _monit_ckp_duration_  
   This function implements the TASK _Monit Checkpoint Duration_ which will generate an alarm whenever a checkpoint has exceeded the configured thresholds

* monit_clear_logicallog_alerts.sql

   Creates the function _monit_clear_logicallog_alerts_  
   This function implements the TASK _Monit Clear Logical Log Alerts_. It eliminates the alerts for logical log change in the ph_alert table that usually are not cleaned.
 
* monit_force_log_change.sql
   Creates the function _monit_force_log_change_ 
   This function implements the TASK _Monit Force Log Change_. It makes sure that a logical log is kept at most for the specificed ammount of time. If the last log change was older than the specified interval (seconfs) then a log switch if forced.

### TODO

