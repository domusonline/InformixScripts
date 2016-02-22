# InformixScripts

A repository of Informix utility scripts by Fernando Nunes (domusonline@gmail.com)
If you're interested in Informix the author would also recommend his blog at:

[http://informix-technology.blogspot.com](http://informix-technology.blogspot.com "Fernando Nunes's blog")

###Introdution
The documentation is the weakest part of this repository. For now I'mjust including a very brief description of the structure and contents of the repository.

###Distribution and license
These repository uses GPL V2 (unless stated in a specific script or folder). In short terms it means you can use the contents freely. If you change them and distribute the results, you must also make the "code" available (with the current contents this is redundant as the script is the code)- The full license text can be read here:

[http://www.gnu.org/licenses/old-licenses/gpl-2.0.html](http://www.gnu.org/licenses/old-licenses/gpl-2.0.html "GNU GPL V2")

###Disclaimer
These scripts are provided AS IS. No guaranties of any sort are provided. Use at your own risk<br/>
None of the scripts should do any harm to your instances or your data. The worst they could do is to provide some misleading information.
However, bad configuration or any unkown bug for example in the environment configuration script (setinfx) could cause some confusion and put you in a situation where you could be adminisering the wrong instance.
Please test the scripts in non critical environments before you put them into production

###Support
As stated in the disclaimer section above, the scripts are provided AS IS. The author will not guarantee any sort of support.

Nevertheless the author is insterested in improving these scripts. if you find a bug or have some special need please contact the author and provide information that can help him fix the bug ordecide if the feature is relevant and can be added in a future version

###Structure
####OAT_plugins
Plugins for the Open Admin Tool. Currently the only plugin present is **ixlocks**, a plugin that will show your instance locks with a few options (by table, session etc.)

####queries
This contains handy queries. Currently only one is present but more will be added in the future

####scripts
This is currently the main part of the repository. Most scripts provide a *-h* option that will show the script usage and syntax. It contains four folders:

- alarmprogram<br/>A replacement script for the standard alarmprogram.sh that is shipped with the engine

- setinfx<br/>A script to position environment variables for different instances and present a selection menu based on a config file

- ix<br/A bunch of scripts for different uses:<br/>

 - ixcaches<br/>This will generate oversized parameters for PC_, DD_ and DS_ parameters

 - ixlocks<br/>Show current locks

 - ixproclog<br/>Monitors your online.log and reacts to different entries. Must be used with a few associated files

 - ixprofiling<br/>Shows detailed statistcs for the execution of one or more queries. The comparison and the results should provide good guidance aboutthe best query plan

 - ixrunalldbs<br/>Runs a script in all the instance's non-system databases

 - ixseqscans<br/>Shows tables with sequential scans
 
 - ixses<br/>onstat -g ses replacement with much more information in a single output (merges information form several onstat commands and some system views

 - ixtableuse<br/>shows who's locking a table or preventing an ALTER TABLE

 - ixtop<br/>Shows the top sessions or table/partitions based on some specified criteria. By default shows top CPU consumption threads, but much more options are available

 - ixvirtdir<br/>Creates a new "INFORMIXDIR" based on an existing product installation. Some sub-directories are duplicated (like etc/, dbssodir/, aaodir/) to allow better granularity for role-separation and different configurations (although currently most of the files are instance indepedent when an INFORMIXDIR is shared across instances)

 There are a few other but they'r not as stable/tested/useful as the above ones

- updstats<br/>Scripts to run statistics on a table or database level with several options.

