<?php
/*
 **************************************************************************   
 *
 * Copyright (c) 2010-2016 Fernando Nunes - domusonline@gmail.com
 * License: This script is licensed as GPL V2 ( http://www.gnu.org/licenses/old-licenses/gpl-2.0.html )
 * $Author: Fernando Nunes - domusonline@gmail.com $
 * $Revision 2.0.1 $
 * $Date 2016-02-22 02:38:48$
 * Disclaimer: This software is provided AS IS, without any kind of guarantee. Use at your own risk.
 *             Although the author is/was an IBM employee, this software was created outside his job engagements.
 *             As such, all credits are due to the author.
 *
 **************************************************************************
 */


class template_gentab_order_locks {

	public $idsadmin;
	private $sz=0;
    
	function __construct()
	{

	}
    
	function sysgentab_start_output( $title, $column_titles, $pag="")
	{
		$this->sz=sizeof($column_titles);
		$this->idsadmin->load_lang("misc_template");
		$url=$this->idsadmin->removefromurl("orderby");
		$url=preg_replace('/&'."orderway".'\=[^&]*/', '', $url);
		// $url = htmlentities($url);
        
		$HTML = <<<EOF
$pag
<div class="borderwrap">
<table class="gentab">
<tr>
<td class="tblheader" align="center" colspan="{$this->sz}">{$title}</td>
</tr>
EOF
;
		$HTML .= "<TR>";
		foreach ($column_titles as $index => $val)
		{
			$HTML .= "<td class='formsubtitle' align='center'>";
			$img="";
			if ( isset($this->idsadmin->in['orderby']) && $this->idsadmin->in['orderby']==$index)
			{
				$img="<img src='images/arrow-up.gif' border='0' alt='up'/>";
				if (isset($this->idsadmin->in['orderway']))
				$img="<img src='images/arrow-down.gif' border='0' alt='down'/>";
			}

			if( ( isset($this->idsadmin->in['orderby'])==$index) && !(isset($this->idsadmin->in['orderway'])) ) {
			$HTML .= "<a href='{$url}&amp;orderby=$index&amp;orderway=DESC' title='{$this->idsadmin->lang("OrderDesc")} {$val}'>{$val}{$img}</a>";
			} else {
				$HTML .= "<a href='{$url}&amp;orderby=$index' title='{$this->idsadmin->lang("OrderAsc")} {$val}'>{$val}{$img}</a>";
			}
			$HTML .= "</td>
";
		}
		$HTML .= "</TR>"
;
		return $HTML;
	}

	function sysgentab_row_output($data)
	{
		$HTML = "<TR>";
		$cnt=1;
		foreach ($data as $index => $val)
		{
			$HTML .= "<td>";
			switch($cnt)
			{
				case 1:     # Lock address - create an anchor
					$HTML .= '<a name="' . $val . '"></a>' . $val;
					break;
				case 2:     # Same resource lock - link to an anchor
					if ( isset($val) )
						$HTML .= '<a href="#' . $val . '">' . $val . '</a>';
					break;
				case 4:     # Wait SID
					if ( isset($val) )
						$HTML .= '<a href="/openadmin/index.php?act=home&amp;do=sessexplorer&amp;sid='. $val . '">' . $val . '</a>';	
					break;
				case 6:     # Owner SID
					if ( isset($val) )
						$HTML .= '<a href="/openadmin/index.php?act=home&amp;do=sessexplorer&amp;sid='. $val . '">' . $val . '</a>';	
					break;
				default: 
					$HTML .= $val;
			}
			$HTML .= "</td>";
		
			if ($cnt++ >= $this->sz )
			break;
		}
		$HTML .= "</TR>
         ";
		return $HTML;
	}

	function sysgentab_end_output($pag="")
	{
		$HTML = <<<EOF
</table>
</div>
        $pag
EOF;
		return $HTML;
	}

} // end class 
?>
