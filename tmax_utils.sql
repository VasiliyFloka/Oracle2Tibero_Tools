create or replace package tmax_utils is

  -- Author  : Vasiliy@Floka.ru
  -- Created : 15.02.2018 10:24:36
  -- Purpose : Common utils
  
function Blob2Xml(p_blob blob) return XmlType;

end tmax_utils;
/
create or replace package body tmax_utils is

function Blob2Xml(p_blob blob) return XmlType is
v_clob CLOB;
v_varchar VARCHAR2(32767);
v_start PLS_INTEGER := 1;
v_buffer PLS_INTEGER := 32767;
BEGIN
DBMS_LOB.CREATETEMPORARY(v_clob, TRUE);
FOR i IN 1..CEIL(DBMS_LOB.GETLENGTH(p_blob) / v_buffer)
LOOP
v_varchar := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(p_blob, v_buffer, v_start));
DBMS_LOB.WRITEAPPEND(v_clob, LENGTH(v_varchar), v_varchar);
v_start := v_start + v_buffer;
END LOOP;
RETURN XMLTYPE(v_clob);
end Blob2Xml;
end tmax_utils;
/
