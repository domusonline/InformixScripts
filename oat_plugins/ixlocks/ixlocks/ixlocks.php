<?php
/*
 **************************************************************************
 * Copyright (c) 2017 Fernando Nunes - domusonline@gmail.com
 * License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
 * $Author: Fernando Nunes - domusonline@gmail.com$
 * $Revision: 2.0.23 $
 * $Date: 2017-08-22 12:21:30 $
 * Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
 *             Although the author is/was an IBM employee, this software was created outside his job engagements.
 *             As such, all credits are due to the author.
 *
 **************************************************************************
 */

/**
 * This is an OAT plugin, based on the example module, and the purpose is to facilitate the locks managing inside the databases
 * It includes several 'actions' that allows the DBA to check the lock usage
 */

class ixlocks {

	/*
	 * This specifies the maximum rows to show for locks per table and locks per session:
	 * -1 Unlimited
	 * 0 OAT default (100)
	 * N
	 */

	var $MAX_ROWS_LOCKS_PER_TABLE = -1;
	var $MAX_ROWS_LOCKS_PER_SESSION = -1;

	/**
	* Each module should have an 'idsadmin' member , this gives access to the OAT API.
	*/
	var $idsadmin;

	/**
	* Every class needs to have a constructor method that takes &$idsadmin as its argument
	* We are also going to load our 'language' file too.
	* @param Class $idsadmin
	*/
	function __construct(&$idsadmin)
	{
		$this->idsadmin = $idsadmin;
		/**
		* load our language file.
		*/
		$this->idsadmin->load_lang("ixlocks");
	} // end of function __construct

	/**
	* Every class needs a 'run' method , this is the 'entry' point of your module.
	*
	*/
	function run()
	{
		/**
		* Set the Page Title - this is the title that is shown in the browser.
		*/
		$this->idsadmin->html->set_pagetitle($this->idsadmin->lang("page_title"));


		/**
		* find out what the user wanted todo ..
		*/
		$do = $this->idsadmin->in['do'];

		/**
		* map our action to a function.
		*/
		switch ($do)
		{
			case "lockwaiters":
				$this->lockwaiters();
				break;
			case "lockspertable":
				$this->lockspertable();
				break;
			case "lockspersession":
				$this->lockspersession();
				break;
			case "locklist":
				$this->locklist();
				break;
			default:
				$this->locklist();
		}
		
	} // end of function run


	/**
	* The function to show the lock list
	*/

	function locklist()
	{
		if ( isset($this->idsadmin->in['orderby']))
		{
			$ORDER_BY_CLAUSE="ORDER BY " . $this->idsadmin->in['orderby'];
			if ( isset( $this->idsadmin->in['orderway']) )
			{
				$ORDER_BY_CLAUSE=$ORDER_BY_CLAUSE .  " " . $this->idsadmin->in['orderway'];
			}
		}
		else
		{
			$ORDER_BY_CLAUSE="";
		}
		/**
		* we first need a 'connection' to the database.
		*/
		$db = $this->idsadmin->get_database("sysmaster");

		/**
		* now we write our query
		*/

		require_once ROOT_PATH."lib/gentab.php";
		$tab = new gentab($this->idsadmin);


		$qry =  "SELECT " .
		"HEX(lk_addr) addr, " .
		"CASE " .
		"	WHEN lk_same = 0 THEN " .
		"		'' " .
		"	ELSE " .
		"		HEX(lk_same) " .
		"END same, " .
		"TRIM(r1.username) wait_user , " .
		"r1.sid wait_sid, " .
		"TRIM(r.username) owner_user, " .
		"r.sid owner_sid, " .
		"CASE " .
		"        WHEN (MOD(lk_flags,2*2) >= 2) THEN " .
		"                'HDR+'||f.txt " .
		"        ELSE " .
		"                f.txt " .
		"END lock_type, " .
		"CASE " .
		"        WHEN lk_keynum = 0 THEN " .
		"                TRIM(t2.dbsname)||':'||TRIM(t2.tabname) " .
		"        ELSE " .
		"                TRIM(t2.dbsname)||':'||TRIM(t2.tabname)||'#'||TRIM(t1.tabname) " .
		"        END locked_object, " .
		"lk_rowid, " .
		"lk_partnum, " .
		"DBINFO('utc_to_datetime', lk_grtime) " .
		"FROM syslocktab l, flags_text f, systabnames t1, sysptnhdr p, systabnames t2, systxptab tx, sysrstcb r, outer sysrstcb r1 " .
		"WHERE " .
		"p.partnum = l.lk_partnum AND " .
		"t2.partnum = p.lockid AND " .
		"t1.partnum = l.lk_partnum AND " .
		"l.lk_type =  f.flags AND " .
		"f.tabname = 'syslcktab' AND " .
		"tx.address = lk_owner AND " .
		"r.address = tx.owner AND " .
		"r1.address = lk_wtlist AND " .
		"r.sid != DBINFO('sessionid') " .
		"$ORDER_BY_CLAUSE";

		$tab->display_tab_max("{$this->idsadmin->lang('TableLockList')}",
		array(
			"1" => "{$this->idsadmin->lang('LkAddr')}",
			"2" => "{$this->idsadmin->lang('LkSame')}",
			"3" => "{$this->idsadmin->lang('LkWaitUser')}",
			"4" => "{$this->idsadmin->lang('LkWaitSid')}",
			"5" => "{$this->idsadmin->lang('LkOwnerUser')}",
			"6" => "{$this->idsadmin->lang('LkOwnerSid')}",
			"7" => "{$this->idsadmin->lang('LkType')}",
			"8" => "{$this->idsadmin->lang('LkObject')}",
			"9" => "{$this->idsadmin->lang('LkRowId')}",
			"10" => "{$this->idsadmin->lang('LkPartnum')}",
			"11" => "{$this->idsadmin->lang('LkGranted')}",
		),
		$qry,
		"template_gentab_order_locks.php",
		$db,-1);

	} // end locklist()


	/**
	* The function to show lock details per session
	*/

	function lockspersession()
	{

		if ( isset($this->idsadmin->in['orderby']))
		{
			$ORDER_BY_CLAUSE="ORDER BY " . $this->idsadmin->in['orderby'];
			if ( isset( $this->idsadmin->in['orderway']) )
			{
				$ORDER_BY_CLAUSE=$ORDER_BY_CLAUSE .  " " . $this->idsadmin->in['orderway'];
			}
		}
		else
		{
			$ORDER_BY_CLAUSE="";
		}
		/**
		* we first need a 'connection' to the database.
		*/

		$db = $this->idsadmin->get_database("sysmaster");

		/**
		* now we write our query
		*/

		require_once ROOT_PATH."lib/gentab.php";
		$tab = new gentab($this->idsadmin);


		$qry =  "SELECT " .
		" '<a href=\"index.php?act=home&amp;do=sessexplorer&amp;sid=' || t.sid ||'\">'||t.sid||'</a>' session_id, " .
		"t.username, " .
		"SUM(nlocks) ses_num_locks, " .
		"SUM(upf_rqlock) ses_req_locks, " .
		"SUM(upf_wtlock) ses_wai_locks, " .
		"SUM(upf_deadlk) ses_dead_locks, " .
		"SUM(upf_lktouts) ses_lock_tout, " .
		"s.hostname, " .
		"d.odb_dbname, " .
		"f.txt, " .
		"s.pid, " .
		"DBINFO('utc_to_datetime', s.connected) ses_connected " .
		"FROM sysrstcb t, sysscblst s, sysopendb d, flags_text f " .
		"WHERE t.sid = s.sid AND " .
		"d.odb_sessionid = t.sid AND " .
		"odb_iscurrent = 'Y' AND " .
		"f.tabname = 'sysopendb' AND " .
		"f.flags = d.odb_isolation AND " .
		"t.sid != DBINFO('sessionid') " .
		"GROUP BY 1,2,8,9,10,11,12 " .
		"$ORDER_BY_CLAUSE";

		$tab->display_tab_max("{$this->idsadmin->lang('TableLocksPerSession')}",
		array(
			"1" => "{$this->idsadmin->lang('Sid')}",
			"2" => "{$this->idsadmin->lang('User')}",
			"3" => "{$this->idsadmin->lang('Locks')}",
			"4" => "{$this->idsadmin->lang('LockReqs')}",
			"5" => "{$this->idsadmin->lang('LockWaits')}",
			"6" => "{$this->idsadmin->lang('DeadLocks')}",
			"7" => "{$this->idsadmin->lang('LocksTout')}",
			"8" => "{$this->idsadmin->lang('Host')}",
			"9" => "{$this->idsadmin->lang('Database')}",
			"10" => "{$this->idsadmin->lang('SidIsolationLevel')}",
			"11" => "{$this->idsadmin->lang('Pid')}",
			"12" => "{$this->idsadmin->lang('Connected')}"
		),
		$qry,
		"template_gentab_order.php",
		$db,
		$MAX_ROWS_LOCKS_PER_SESSION);

	} #end lockspersession()

	/**
	* The function to show lock details per table
	*/

	function lockspertable()
	{

		if ( isset($this->idsadmin->in['orderby']))
		{
			$ORDER_BY_CLAUSE="ORDER BY " . $this->idsadmin->in['orderby'];
			if ( isset( $this->idsadmin->in['orderway']) )
			{
				$ORDER_BY_CLAUSE=$ORDER_BY_CLAUSE .  " " . $this->idsadmin->in['orderway'];
			}
		}
		else
		{
			$ORDER_BY_CLAUSE="";
		}

		/**
		* we first need a 'connection' to the database.
		*/

		$db = $this->idsadmin->get_database("sysmaster");

		/**
		* now we write our query
		* The way the query is written is important.
		* Other queries may scan the syslocks view which can take a very long time to run
		*/

		require_once ROOT_PATH."lib/gentab.php";
		$tab = new gentab($this->idsadmin);

		$qry =  "SELECT " .
		"t.dbsname , " .
		"t.tabname, " .
		"COUNT(l.partnum) AS lockcnt, " .
		"SUM(p.pf_rqlock) AS lockreq, " .
		"SUM(p.pf_wtlock) AS lockwaits, " .
		"SUM(p.pf_deadlk) AS deadlocks, " .
		"SUM(p.pf_lktouts) AS locktimeouts " .
		"FROM sysptntab p, systabnames t, outer syslcktab l " .
		"WHERE p.tablock = t.partnum AND " .
		"( (l.partnum = p.tablock AND l.rowidn != 0) OR (l.partnum = p.partnum AND l.rowidn = 0) ) " .
		"GROUP BY 1,2 " .
		"HAVING SUM(p.pf_rqlock) > 0 " . 
		"$ORDER_BY_CLAUSE" ;

		$tab->display_tab_max("{$this->idsadmin->lang('TableLocksPerTable')}",
		array(
			"1" => "{$this->idsadmin->lang('Database')}",
			"2" => "{$this->idsadmin->lang('TableName')}",
			"3" => "{$this->idsadmin->lang('LockCnt')}",
			"4" => "{$this->idsadmin->lang('LockReqs')}",
			"5" => "{$this->idsadmin->lang('LockWaits')}",
			"6" => "{$this->idsadmin->lang('DeadLocks')}",
			"7" => "{$this->idsadmin->lang('LocksTout')}",
		),
		$qry,
		"template_gentab_order.php",
		$db,
		$MAX_ROWS_LOCKS_PER_TABLE);

    } #end lockspertable()




	/**
	* The function to show locks with waiters
	*/
	function lockwaiters()
	{

		if ( isset($this->idsadmin->in['orderby']))
		{
			$ORDER_BY_CLAUSE="ORDER BY " . $this->idsadmin->in['orderby'];
			if ( isset( $this->idsadmin->in['orderway']) )
			{
				$ORDER_BY_CLAUSE=$ORDER_BY_CLAUSE .  " " . $this->idsadmin->in['orderway'];
			}
		}
		else
		{
			$ORDER_BY_CLAUSE="";
		}
		/**
		* we first need a 'connection' to the database.
		*/

		$db = $this->idsadmin->get_database("sysmaster");

		/**
		* now we write our query
		* The way the query is written is important.
		* Other queries may scan the syslocks view which can take a very long time to run
		*/

		$qry =  "SELECT {+ ORDERED } " .
			"l.indx out_lock_id, " .
			"f.txt[1,4] out_lock_type, " .
			"l.rowidr out_rowidr, " .
			"l.keynum out_keynum, " .
			"EXTEND(DBINFO('utc_to_datetime', grtime), DAY TO SECOND) out_lock_establish, " .
			"CURRENT YEAR TO SECOND - DBINFO('utc_to_datetime', grtime) out_lock_duration, " .
			"a.dbsname out_dbsname, " .
			"a.tabname out_tabname, " .
			" '<a href=\"index.php?act=home&amp;do=sessexplorer&amp;sid=' || t2.sid ||'\">'||t2.sid||'</a>' out_owner_sid, " .
			"t2.username out_owner_user, " .
			"h.hostname out_owner_hostname, " .
			"h.pid out_owner_pid, " .
			" '<a href=\"index.php?act=home&amp;do=sessexplorer&amp;sid=' || t.sid ||'\">'||t.sid||'</a>' out_waiter_sid, " .
			"CURRENT YEAR TO SECOND - DBINFO('utc_to_datetime',g.start_wait) out_lock_wait, " .
			"t.username out_wait_user, " .
			"h2.hostname out_wait_hostname, " .
			"h2.pid out_wait_pid " .
			"FROM " .
			"sysrstcb t, sysscblst h2, systcblst g, syslcktab l, systxptab c, sysrstcb t2, sysscblst h, flags_text f, systabnames a " .
			"WHERE " .
			"t.lkwait = l.address AND " .
			"l.owner = c.address AND " .
			"c.owner = t2.address AND " .
			"l.partnum = a.partnum AND " .
			"g.tid = t.tid AND " .
			"h2.sid = t.sid AND " .
			"h.sid = t2.sid AND " .
			'f.tabname = "syslcktab" AND f.flags = l.type ' .
			"ORDER BY out_lock_duration desc, out_lock_id;";

       		/**
		* We can use the 'gentab' api in OAT to create the output for us.
		*
		* 1. first we load the gentab class.
		*/

		require_once("lib/gentab.php");

		/**
		* create a new instance of the gentab class
		*/
		$tab = new gentab($this->idsadmin);

		$tab->display_tab_max( $this->idsadmin->lang("TableLocksWithWaiters"),
		array(
			"1" => $this->idsadmin->lang("out_lock_id"),
			"2" => $this->idsadmin->lang("out_lock_type"),
			"3" => $this->idsadmin->lang("out_rowidr"),
			"4" => $this->idsadmin->lang("out_keynum"),
			"5" => $this->idsadmin->lang("out_lock_establish"),
			"6" => $this->idsadmin->lang("out_lock_duration"),
			"7" => $this->idsadmin->lang("Database"),
			"8" => $this->idsadmin->lang("out_tabname"),
			"9" => $this->idsadmin->lang("out_owner_sid"),
			"10" => $this->idsadmin->lang("out_owner_user"),
			"11" => $this->idsadmin->lang("out_owner_hostname"),
			"12" => $this->idsadmin->lang("out_owner_pid"),
			"13" => $this->idsadmin->lang("out_wait_sid"),
                	"14" => $this->idsadmin->lang("out_lock_wait"),
			"15" => $this->idsadmin->lang("out_wait_user"),
			"16" => $this->idsadmin->lang("out_wait_hostname"),
			"17" => $this->idsadmin->lang("out_wait_pid"),
		),
		$qry,"template_gentab.php",$db,-1);

	} // end lockswithwaiters()
    
} // end of class
?>
