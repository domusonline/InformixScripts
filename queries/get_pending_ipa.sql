
DROP FUNCTION get_pending_ipa;

CREATE FUNCTION get_pending_ipa() RETURNING
	VARCHAR(128) as database, VARCHAR(128) as table, INTEGER as partnum, SMALLINT as version, INTEGER as npages

-- Name: $RCSfile$
-- CVS file: $Source$
-- CVS id: $Header$
-- Revision: $Revision$
-- Revised on: $Date$
-- Revised by: $Author$
-- Support: Fernando Nunes - domusonline@gmail.com
-- Licence: This script is licensed as GPL ( http://www.gnu.org/licenses/old-licenses/lgpl-2.0.html )

-- Variables holding the database,tabnames and partnum
DEFINE v_dbsname, v_old_dbsname LIKE sysmaster:systabnames.dbsname;
DEFINE v_tabname, v_old_tabname LIKE sysmaster:systabnames.tabname;
DEFINE v_partnum LIKE sysmaster:syspaghdr.pg_partnum;

-- Variables holding the various table versions and respective number of pages pending to migrate
DEFINE v_version SMALLINT;
DEFINE v_pages INTEGER;

-- Hexadecimal representation of version and pending number of pages
DEFINE v_char_version CHAR(6);
DEFINE v_char_pages CHAR(10);

-- Hexadecimal representation of the slot 6 data. Each 16 bytes will appear as a record that needs to be concatenated
DEFINE v_hexdata VARCHAR(128);

-- Variable to hold the sysmaster:syssltdat hexadecimal representation of each 16 bytes of the slot data
DEFINE v_slot_hexdata CHAR(40);

DEFINE v_aux VARCHAR(128);

DEFINE v_endian CHAR(6);
DEFINE v_offset SMALLINT;
DEFINE v_slotoff SMALLINT;

-- In case we need to trace the function... Uncomment the following two lines
--SET DEBUG FILE TO "/tmp/get_pending_ipa.dbg";
--TRACE ON;

-- Now lets find out the Endianess ( http://en.wikipedia.org/wiki/Endianness ) of this platform
-- The data in sysmaster:syssltdat will be different because of possible byte swap

-- Read the first slot of the rootdbs TBLSpace tblspace (0x00100001)
-- The first 4 bytes hold the partition number (0x00100001)

SELECT
	s.hexdata[1,8]
INTO
	v_hexdata
FROM
	sysmaster:syssltdat s
WHERE
	s.partnum = '0x100001' AND
	s.pagenum = 1 AND
	s.slotnum = 1 AND
	s.slotoff = 0;

IF v_hexdata = '01001000'
THEN
	-- Byte swap order, so we're little Endian (Intel, Tru64....)
	LET v_endian = 'LITTLE';
ELSE
	IF v_hexdata = '00100001'
	THEN
		-- Just as we write it (no byte swap), so we're big Endian (Sparc, Power, Itanium...)
		LET v_endian = 'BIG';
	ELSE
		-- Just in case something weird (like a bug(!) or physical modification) happened
		RAISE EXCEPTION -746, 0, 'Invalid Endianess calculation... Check procedure code!!!';
	END IF
END IF

-- Flags to mark the beginning
LET v_hexdata = "-";
LET v_old_dbsname = "-";
LET v_old_tabname = "-";

-- The information we want for each version description will occupy this number of characters in the sysmaster:syssltdat.hexdata notation
LET v_offset = 52;


FOREACH
	-- This query will browse through all the instance partitions, excluding sysmaster database, and will look for slot 6 of
	-- any extended partition header (where partition header "next" field is not 0)
        SELECT
                t.dbsname, t.tabname, t.partnum, s.hexdata, s.slotoff
	INTO
		v_dbsname, v_tabname, v_partnum, v_slot_hexdata, v_slotoff
        FROM
                sysmaster:systabnames t,
                sysmaster:syspaghdr p,
                sysmaster:sysdbstab d,
		sysmaster:syssltdat s
        WHERE
		s.partnum = p.pg_partnum AND
		s.pagenum = p.pg_next AND
		s.slotnum = 6 AND
                p.pg_partnum = sysmaster:partaddr(sysmaster:partdbsnum(t.partnum),1) AND
                p.pg_pagenum = sysmaster:partpagenum(t.partnum) AND
                t.dbsname NOT IN ('sysmaster') AND
                d.dbsnum = sysmaster:partdbsnum(t.partnum) AND
		p.pg_next != 0
	ORDER BY
		t.dbsname, t.tabname, s.slotoff

	IF ( v_dbsname != v_old_dbsname OR v_tabname != v_old_tabname )
	THEN
		-- First iteraction for each table
		LET v_hexdata = v_slot_hexdata;
	ELSE
		-- Next iteractions for each table
		LET v_hexdata = TRIM(v_hexdata) || v_slot_hexdata;
		IF LENGTH(v_hexdata) >= v_offset
		THEN
			-- We already have enough data for a version within a table
			-- Note that we probably have part of the next version description in v_hexdata
			-- So we need to copy part of it, and keep the rest for next iteractions
			LET v_aux=v_hexdata;
			LET v_hexdata=SUBSTR(v_aux,v_offset+1,LENGTH(v_aux)-v_offset);
		
			-- Split the version and number of pending pages part...
			LET v_char_version = v_aux[1,4];
			LET v_char_pages = v_aux[10,17];

			-- Create a usable hex number. Prefix it with '0x' and convert due to little endian if that's the case
			IF v_endian = "BIG"
			THEN
				LET v_char_version = '0x'||v_char_version;
				LET v_char_pages = '0x'||v_char_pages;
			ELSE
				LET v_char_version[5]=v_char_version[1];
				LET v_char_version[6]=v_char_version[2];
				-- Pos 3 and 4 stay the same...
				LET v_char_version[2]='x';
				LET v_char_version[1]='0';


				LET v_char_pages[9]=v_char_pages[1];
				LET v_char_pages[10]=v_char_pages[2];
				LET v_char_pages[7]=v_char_pages[3];
				LET v_char_pages[8]=v_char_pages[4];
				-- Pos 5 and 6 stay the same...
				LET v_char_pages[3]=v_char_pages[7];
				LET v_char_pages[4]=v_char_pages[8];
				LET v_char_pages[2]='x';
				LET v_char_pages[1]='0';
			END IF
			-- HEX into DEC (integer)
			LET v_version = TRUNC(v_char_version + 0);
			LET v_pages = TRUNC(v_char_pages + 0);
			IF v_pages > 0
			THEN
				-- This version has pending pages so show it...
				RETURN v_dbsname, v_tabname, v_partnum,  v_version, v_pages WITH RESUME;
			END IF
		END IF
	END IF
	LET v_old_dbsname = v_dbsname;
	LET v_old_tabname = v_tabname;
END FOREACH;

IF LENGTH(v_hexdata) = v_offset
THEN
	-- If we still have data to process...
	LET v_aux=v_hexdata;
	
	LET v_char_version = v_aux[1,4];
	LET v_char_pages = v_aux[10,17];

	IF v_endian = "BIG"
	THEN
		LET v_char_version = '0x'||v_char_version;
		LET v_char_pages = '0x'||v_char_pages;
	ELSE
		LET v_char_version[5]=v_char_version[1];
		LET v_char_version[6]=v_char_version[2];
		-- Pos 3 and 4 stay the same...
		LET v_char_version[2]='x';
		LET v_char_version[1]='0';


		LET v_char_pages[9]=v_char_pages[1];
		LET v_char_pages[10]=v_char_pages[2];
		LET v_char_pages[7]=v_char_pages[3];
		LET v_char_pages[8]=v_char_pages[4];
		-- Pos 5 and 6 stay the same...
		LET v_char_pages[3]=v_char_pages[7];
		LET v_char_pages[4]=v_char_pages[8];
		LET v_char_pages[2]='x';
		LET v_char_pages[1]='0';
	END IF
	-- HEX into DEC (integer)
	LET v_version = TRUNC(v_char_version + 0);
	LET v_pages = TRUNC(v_char_pages + 0);
	IF v_pages > 0
	THEN
		-- This version has pending pages so show it...
		RETURN v_dbsname, v_tabname, v_partnum,  v_version, v_pages WITH RESUME;
	END IF
END IF
END FUNCTION;

execute function get_pending_ipa();

