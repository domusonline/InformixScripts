<?php
/*
 **************************************************************************   
 *  (c) Copyright Fernando Nunes (domusonline@gmail.com). 2010.  All Rights Reserved
 *
 *  $Id$
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 *  $Author$
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
