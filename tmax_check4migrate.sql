create or replace package tmax_check4migrate is
  -- Author  : Vasiliy@Floka.ru
  -- Created : 29.12.2017 13:08:54
  -- Purpose : Checking for known migration issues from Oracle to Tibero
  -- Before using you need ALTER SESSION SET plscope_settings='IDENTIFIERS:ALL' and recompile pl/sql objects
  -- Version of Oracle must be 11g or higher 
  c_ignore_prefix constant varchar2(8) := 'TMAX_';
  c_token_length constant int := 256;
type sc_t is record
( owner varchar2(128),
  name varchar2(128),
  type varchar2(16),
  line int,
  col int,
  token varchar2(c_token_length char),
  kind varchar2(16));
type sct_t is table of sc_t;
function sct(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_type varchar2 := null,
  p_name varchar2 := null) return sct_t pipelined;
-- Get exception name by error code
function getExceptionName(p_ErrCode int) return varchar2;
-- Checking for exceptions
function chk_excptns(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  ) return int;
-- Run checking
procedure Run(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_modify boolean := false
  );
-- Recompile for PLScope
procedure Recompile4PLScope(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  );
-- print replaced source code
procedure print_replaced_source_code;             
end tmax_check4migrate;
/
create or replace package body tmax_check4migrate is
-- 
c_name_length constant int := 128;
type t_exc_tab is table of varchar2(c_name_length) index by pls_integer;
v_exc_tab t_exc_tab;
type t_not_exists_exc_tab is table of int index by pls_integer;
v_not_exists_exc_tab t_not_exists_exc_tab;
--
type t_lines is table of varchar2(32767) index by pls_integer;
type t_TYPE is table of t_lines index by varchar2(c_name_length);
type t_NAME is table of t_TYPE index by varchar2(c_name_length);
type t_OWNER is table of t_NAME index by varchar2(c_name_length);
v_source_code t_OWNER;
-- load source code and save into collection
procedure load_source_code(
                p_OWNER varchar2,
                p_NAME  varchar2,
                p_TYPE  varchar2)
is
v_exists boolean := false;
begin
  begin
    v_exists:= v_source_code(p_OWNER)(p_NAME)(p_TYPE).exists(1); 
  exception when no_data_found then
    v_source_code(p_OWNER)(p_NAME)(p_TYPE)(0) := 
      'CREATE OR REPLACE /* TMAX '||to_char(sysdate,'rr-mm-dd hh24:mi:ss')||' */';
  for s in (
    select *
      from all_source s
     where s.OWNER = p_OWNER
       and s.NAME = p_NAME
       and s.TYPE = p_TYPE
        )loop
        v_source_code(s.OWNER)(s.NAME)(s.TYPE)(s.line) := s.text;
  end loop; 
  end;
end load_source_code;
-- replace source code and save into collection
procedure rplc(
                p_OWNER varchar2,
                p_NAME  varchar2,
                p_TYPE  varchar2,
                p_lines_list varchar2,
                p_oldsub varchar2 default null,
                p_newsub varchar2 default null,
                p_to_comment boolean default false,
                p_regexp boolean default true)
is
v_exists boolean := false;
begin
load_source_code(
                  p_OWNER,
                  p_NAME,
                  p_TYPE);
--
for s in (
 select regexp_substr(p_lines_list, '[^,]+', 1, level) line
  from dual
connect by regexp_substr(p_lines_list, '[^,]+', 1, level) is not null 
)
loop
 if p_to_comment then
  v_source_code(p_OWNER)(p_NAME)(p_TYPE)(s.line):='--'||
     v_source_code(p_OWNER)(p_NAME)(p_TYPE)(s.line);  
 else
  v_source_code(p_OWNER)(p_NAME)(p_TYPE)(s.line):= 
  case when p_regexp then
  regexp_replace(v_source_code(p_OWNER)(p_NAME)(p_TYPE)(s.line),p_oldsub,p_newsub,1,1,'i')
  else
  replace(v_source_code(p_OWNER)(p_NAME)(p_TYPE)(s.line),p_oldsub,p_newsub) end;
 end if;
  --dbms_output.put_line(v_source_code(p_OWNER)(p_NAME)(p_TYPE)(s.line));
end loop; 
exception when others then
   Raise_application_error(-20000,p_OWNER||'.'||p_NAME||' '||p_TYPE,true);
end rplc;
-- load exceptions from error package
procedure init_exc_tab(
  p_owner varchar2 := user,
  p_err_pck_name varchar2 := 'TMAX_ERRPKG')
is
v_err_code int;
v_exec_code varchar2(32767);
begin
   if v_exc_tab.count() > 0 then
     return;
   end if; 
--
for c in (select 
             i.OWNER,
             i.OBJECT_NAME,
             i.NAME
        from all_identifiers i
       where (i.OWNER,i.OBJECT_NAME) in (select p_owner,p_err_pck_name from dual union all
                                         select 'SYS','STANDARD' from dual )
         and i.OBJECT_TYPE = 'PACKAGE'
         and i.TYPE = 'EXCEPTION'
         and i.USAGE = 'DECLARATION'
         ) loop
           v_exec_code :=
           'begin
            raise '||c.owner||'.'||c.object_name||'.'||c.name||';
            exception
            when '||c.owner||'.'||c.object_name||'.'||c.name||' then
            :err := sqlcode;
            end;';
            begin 
            execute immediate v_exec_code using out v_err_code;
            if c.owner = 'SYS' then
              v_exc_tab(v_err_code):= c.name;
            else
              v_exc_tab(v_err_code):= c.owner||'.'||c.object_name||'.'||c.name;
            end if;
            exception when others then
              dbms_output.put_line(sqlerrm);
              dbms_output.put_line(v_exec_code);
            end;    
end loop;  
-- dbms_output.put_line('Loaded '||v_exc_tab.count()||' exceptions from '||p_owner||'.'||p_err_pck_name);
end init_exc_tab;
-- Get exception name by error code
function getExceptionName(p_ErrCode int) return varchar2
  is
 begin
   init_exc_tab;
   begin
     return v_exc_tab(p_ErrCode);
   exception
     when no_data_found then
       begin
         v_not_exists_exc_tab(p_ErrCode):=v_not_exists_exc_tab(p_ErrCode)+1;
       exception
       when no_data_found then
         v_not_exists_exc_tab(p_ErrCode):=1;
       end;
     return null;
   end;
 end getExceptionName;
-- print REFERENCE list
function print_ref_list(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_signature varchar2,
  p_type varchar2,
  p_usage varchar2,
  p_oldsub varchar2 default null,
  p_newsub varchar2 default null
  ) return int is
  v_lines_count int := 0;
  begin
    for r in (
      select count(*) cnt,
             i.OWNER,
             i.OBJECT_NAME,
             i.OBJECT_TYPE,
             listagg(i.LINE,','
 $if dbms_db_version.ver_le_12_2 $then
       ON OVERFLOW TRUNCATE
 $end             
             ) WITHIN GROUP(order by i.LINE)lines_list
        from all_identifiers i
       where i.OWNER = p_owner
         and i.OBJECT_NAME not like p_ignore_prefix || '%'
         and i.TYPE = p_type
         and i.USAGE = p_usage
         and i.SIGNATURE = p_signature
       group by i.OBJECT_TYPE,i.OWNER,i.OBJECT_NAME
       order by i.OBJECT_TYPE,i.OBJECT_NAME 
           ) loop
      if v_lines_count = 0 then
        dbms_output.put_line(chr(9)||'Reference list');
      end if;
      dbms_output.put_line(chr(9)||to_char(v_lines_count+1)||')'||r.object_type||' '||r.owner||'.'||r.object_name||' line(s) '||r.lines_list);
      v_lines_count := v_lines_count + r.cnt;  
      if p_type = 'EXCEPTION' 
        and p_newsub is not null then
          rplc(p_owner => r.owner,
                p_name => r.object_name,
                p_type => r.object_type,
                p_lines_list => r.lines_list,
                p_oldsub => p_oldsub,
                p_newsub => p_newsub);
      end if;
   end loop;
    return v_lines_count; 
end print_ref_list; 
-- checking for missing types
function chk_args(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  ) return  int is
v_lines_count int := 0;
begin
  for p in (
  select row_number() over(partition by a.TYPE_NAME order by p.OWNER, p.OBJECT_NAME, p.OBJECT_TYPE, p.PROCEDURE_NAME) rn,
         a.TYPE_NAME,
         i.TYPE,
         i.SIGNATURE,
         p.OBJECT_TYPE || ' ' || p.OWNER || '.' || p.OBJECT_NAME ||
         nvl2(p.PROCEDURE_NAME, '.' || p.PROCEDURE_NAME, null) name
    from all_arguments a, all_procedures p, all_identifiers i
   where a.OWNER = p_owner
     and (a.TYPE_NAME = 'ANYTYPE' or a.TYPE_NAME like 'JSON%')
     and a.OBJECT_ID = p.OBJECT_ID
     and a.SUBPROGRAM_ID = p.SUBPROGRAM_ID
     and a.OWNER = i.OWNER
     and a.OBJECT_NAME = i.NAME
     and p.OBJECT_TYPE = i.OBJECT_TYPE
     and i.USAGE = 'DECLARATION'
     and i.OBJECT_NAME not like p_ignore_prefix || '%')
   loop
    v_lines_count := v_lines_count + 1;
    if p.rn = 1 then
      dbms_output.put_line(
      '*** The '||p.type_name||' is absent in Tibero');
    end if;
    dbms_output.put_line(p.rn||'.'||p.name);
    v_lines_count := v_lines_count + print_ref_list(
                    p_owner => p_owner,
                    p_ignore_prefix => p_ignore_prefix,
                    p_signature => p.signature,
                    p_type => p.type,
                    p_usage => 'CALL'
                    );
   end loop;
  return v_lines_count;
end chk_args;   
-- search for the parallel-enabled functions
function chk_functions(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  ) return  int is
v_lines_count int := 0;
v_dummy int;
begin
  for p in (
   select row_number() over(order by p.OWNER, p.OBJECT_NAME, p.OBJECT_TYPE, p.PROCEDURE_NAME) rn,
          p.OBJECT_TYPE || ' ' || p.OWNER || '.' || p.OBJECT_NAME ||
          nvl2(p.PROCEDURE_NAME, '.' || p.PROCEDURE_NAME, null) name,
          i.SIGNATURE
     from all_procedures p,
          all_identifiers i
    where p.OWNER = p_owner
      and p.OBJECT_NAME not like p_ignore_prefix || '%'
      and p.PARALLEL = 'YES'
      and i.OWNER = p.OWNER
      and i.OBJECT_TYPE = p.OBJECT_TYPE
      and i.OBJECT_NAME = p.OBJECT_NAME
      and i.NAME = p.PROCEDURE_NAME
      )
   loop
    v_lines_count := p.rn; 
    if p.rn = 1 then
      dbms_output.put_line(
      '*** The parallel-enabled functions is absent in Tibero');
    end if;
    dbms_output.put_line(p.rn||'.'||p.name);
    v_dummy := print_ref_list(
                    p_owner => p_owner,
                    p_ignore_prefix => p_ignore_prefix,
                    p_signature => p.signature,
                    p_type => 'FUNCTION',
                    p_usage => 'CALL'
                    );
   end loop;
   if v_lines_count > 0 then 
    dbms_output.put_line('...You can use conditional compilation to exclude PARALLEL_ENABLE clause in Tibero');
   end if;
  return v_lines_count;
end chk_functions;
-- Checking for new keyword
function chk_new_keyword(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  ) return  int is
v_lines_count int := 0;
begin
  for r in ( 
    select count(*) cnt,
           s.OWNER,
           s.NAME,
           s.TYPE,
           listagg(s.LINE,','
 $if dbms_db_version.ver_le_12_2 $then
       ON OVERFLOW TRUNCATE
 $end           
           )  WITHIN GROUP(order by s.LINE) lines_list
      from all_source s, all_identifiers i
     where s.OWNER = p_owner
       and s.TYPE not like  'JAVA%'
       and s.NAME not like p_ignore_prefix || '%'
       and upper(s.TEXT) like '%:=%NEW %'
       and i.OWNER = s.OWNER
       and i.OBJECT_NAME = s.NAME
       and i.OBJECT_TYPE = s.TYPE
       and i.LINE = s.LINE
       and i.USAGE in ('ASSIGNMENT', 'CALL')
     group by s.TYPE, s.OWNER,s.NAME
     order by s.TYPE, s.NAME
    )loop
          if v_lines_count = 0 then
            dbms_output.put_line(
            '*** The keyword "new" in the type constructor expressions is optional in Oracle and is absent in Tibero');
            dbms_output.put_line(chr(9)||'Reference list');
          end if;
          dbms_output.put_line(chr(9)||to_char(v_lines_count+1)||'.'||r.type||' '||r.owner||'.'||r.name||' line(s) '||r.lines_list);
    v_lines_count := v_lines_count + r.cnt;
    rplc(p_owner => r.owner,
                p_name => r.name,
                p_type => r.type,
                p_lines_list => r.lines_list,
                p_oldsub => 'new ',
                p_newsub => '/*new */');
    end loop;
    return v_lines_count;
end chk_new_keyword;    
-- Checking for exceptions
function chk_excptns(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  ) return  int is
  v_err_code int;
  v_warning boolean := false;
  v_exec_code varchar2(32767);
  v_exc_pragma varchar2(32767);
  v_ExceptionName varchar2(c_name_length);
  v_lines_count int := 0;
  v_i int;
  v_err_msg varchar2(32767);
begin
  for c in (
    select i.SIGNATURE,
           i.OWNER,
           i.OBJECT_NAME,
           i.NAME,
           i.LINE,
           a.OBJECT_TYPE,
           a.LINE ASSIGNMENT_LINE
      from all_identifiers i, all_identifiers a
     where i.OWNER = p_owner
       and i.OBJECT_NAME not like p_ignore_prefix || '%'
       and i.TYPE = 'EXCEPTION'
       and i.USAGE = 'DECLARATION'
       and i.SIGNATURE = a.SIGNATURE
       and a.USAGE = 'ASSIGNMENT'
     order by i.OWNER, i.OBJECT_NAME, i.OBJECT_TYPE, i.LINE
           ) loop
           if c.object_type = 'PACKAGE' then
             v_exec_code :=
             'begin
              raise '||c.owner||'.'||c.object_name||'.'||c.name||';
              exception
              when '||c.owner||'.'||c.object_name||'.'||c.name||' then
              :err := sqlcode;
              end;';
              begin 
              execute immediate v_exec_code using out v_err_code;
              exception when others then
                dbms_output.put_line(sqlerrm);
                dbms_output.put_line(v_exec_code);
              end;
           else -- need to dive into source code
             v_exc_pragma := null;
             for s in (select /*+ first_rows(1)*/
                             s.TEXT
                        from all_source s
                       where s.OWNER = c.OWNER
                         and s.NAME = c.OBJECT_NAME
                         and s.TYPE = c.OBJECT_TYPE
                         and s.LINE >= c.ASSIGNMENT_LINE
                       order by s.LINE)loop
                         v_exc_pragma :=v_exc_pragma || s.text;
                         v_exec_code :=
                          '
                          declare '||c.name||' exception;
                          '||v_exc_pragma||'
                          begin
                            raise '||c.name||';
                          exception
                            when '||c.name||' then
                              :err := sqlcode;
                          end;';
                begin 
                execute immediate v_exec_code using out v_err_code;
                exit;-- have got to error code
                exception 
                  when tmax_ErrPkg.e_compilation_error then null;-- need add next line from all_source
                  when others then
                  dbms_output.put_line(sqlerrm);
                  dbms_output.put_line(v_exec_code);
                end;
             end loop;
           end if;
    if not v_err_code between -20999 and -20000 then
      v_lines_count := v_lines_count + 1;
       dbms_output.put_line(v_lines_count||'.Exception '||c.name||'('||c.object_type||' '||c.owner||'.'||c.object_name||' line '||c.line||')'||
       ' init with error code '||v_err_code || '(line '||c.assignment_LINE||')' );
       v_ExceptionName := getExceptionName(v_err_code);
       if v_ExceptionName is not null then
          dbms_output.put_line('...replace it to '||v_ExceptionName);
       end if;
       v_warning := true;
    -- REFERENCE list
    v_lines_count := v_lines_count + print_ref_list(
                                        p_owner => p_owner,
                                        p_ignore_prefix => p_ignore_prefix,
                                        p_signature => c.signature,
                                        p_type => 'EXCEPTION',
                                        p_usage => 'REFERENCE',
 p_oldsub => c.name||'|'||c.object_name||'.'||c.name||'|'||c.owner||'.'||c.object_name||'.'||c.name,
 p_newsub => v_ExceptionName                               
                                        );
    -- to comment 2 lines                                    
    rplc(
        p_owner => c.owner,
        p_name => c.object_name,
        p_type => c.object_type,
        p_lines_list => c.line||','||c.assignment_LINE,
        p_to_comment => true);                                       
    end if;
    v_err_code := null;
  end loop;
  if v_warning then 
    dbms_output.put_line('...You need to use conditional compilation to define different system error codes for Tibero and Oracle');
  
  v_i := v_not_exists_exc_tab.first;
  if v_i is not null  then
    dbms_output.put_line('Following error codes did not find in Tmax_ErrPkg package, need to add:');
  end if;
  while v_i is not null 
    loop
      --dbms_output.put_line(v_i||' - '||v_not_exists_exc_tab(v_i)||' references'); 
      begin
        execute immediate
        'declare
         e_ exception;
         pragma exception_init(e_,'||to_char(v_i)||');
        begin raise e_; end;';
      exception when others then
        v_err_msg:= replace(replace(sqlerrm,'ORA-'||lpad(abs(v_i),5,'0')||': '),' ','_');
      dbms_output.put_line('/* '||sqlerrm||' */'); 
      dbms_output.put_line(lpad('-',30,'-')); 
      dbms_output.put_line('e_'||v_err_msg||' exception;');
      dbms_output.put_line('pragma exception_init(e_'||v_err_msg||',');
      dbms_output.put_line('$if tmax_Constpkg.c_isTibero $THEN');
      dbms_output.put_line('-?????');
      dbms_output.put_line('$ELSE');
      dbms_output.put_line(v_i);
      dbms_output.put_line('$END');
      dbms_output.put_line(');');
      end; 
      v_i := v_not_exists_exc_tab.next(v_i);
    end loop;
  end if;
  return v_lines_count;
end chk_excptns;
-- Recompile for PLScope
procedure Recompile4PLScope(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  ) is
v_ddl varchar2(32767);
begin
  dbms_output.enable(null);
  execute immediate 
  'ALTER SESSION SET plscope_settings="IDENTIFIERS:ALL"';
  for c in (
 SELECT distinct replace(c.type,' BODY')||' "'||c.owner||'"."'||c.name||'"' obj
   FROM all_plsql_object_settings c
  where c.PLSCOPE_SETTINGS not like '%IDENTIFIERS:ALL%'
    and c.OWNER = p_owner
    and c.NAME not like p_ignore_prefix || '%'
   )loop
     begin
      v_ddl := 'alter '||c.obj||' compile';
      execute immediate v_ddl; 
     exception
       when others then
         dbms_output.put_line(c.obj);
         dbms_output.put_line(sqlerrm);
     end;     
   end loop;
end Recompile4PLScope;
-- print replaced source code
procedure print_replaced_source_code
  is
v_owner varchar2(c_name_length);
v_name varchar2(c_name_length);
v_type varchar2(c_name_length);
begin
  dbms_output.enable(null);
v_owner := v_source_code.first;
while v_owner is not null 
loop
dbms_output.put_line('prompt schema is '||v_owner);
 v_name := v_source_code(v_owner).first;
 while v_name is not null 
 loop
 dbms_output.put_line('prompt name is '||v_name);
  v_type := v_source_code(v_owner)(v_name).first;
  while v_type is not null 
  loop
    dbms_output.put_line('prompt type is '||v_type);
    for v_line in v_source_code(v_owner)(v_name)(v_type).first..v_source_code(v_owner)(v_name)(v_type).last
      loop
        dbms_output.put_line(
          replace(replace(
            v_source_code(v_owner)(v_name)(v_type)(v_line)
          ,chr(13)),chr(10))
        );
      end loop;
      dbms_output.put_line('/');
    v_type :=  v_source_code(v_owner)(v_name).next(v_type);
  end loop;
 v_name :=  v_source_code(v_owner).next(v_name); 
 end loop;  
v_owner := v_source_code.next(v_owner);
end loop;
end print_replaced_source_code;
-- modify_source_code
procedure modify_source_code
  is
v_stmt clob;
v_owner varchar2(c_name_length);
v_name varchar2(c_name_length);
v_type varchar2(c_name_length);
v_sl varchar2(32767);
begin
  dbms_lob.createtemporary(v_stmt,true,dbms_lob.call);
  dbms_output.enable(null);
v_owner := v_source_code.first;
while v_owner is not null 
loop
--dbms_output.put_line('prompt schema is '||v_owner);
 v_name := v_source_code(v_owner).first;
 while v_name is not null 
 loop
 --dbms_output.put_line('prompt name is '||v_name);
  v_type := v_source_code(v_owner)(v_name).first;
  while v_type is not null 
  loop
    --dbms_output.put_line('prompt type is '||v_type);
    for v_line in v_source_code(v_owner)(v_name)(v_type).first..v_source_code(v_owner)(v_name)(v_type).last
      loop
        v_sl := v_source_code(v_owner)(v_name)(v_type)(v_line);
        if v_sl is not null then
        begin
        dbms_lob.writeappend( v_stmt , length(v_sl), v_sl);
        exception when others then
          Raise_application_error(-20001, 'length='||length(v_sl)||' '||v_sl);
        end;
        end if;
        --dbms_output.put_line(v_source_code(v_owner)(v_name)(v_type)(v_line));
      end loop;
      begin
      execute immediate v_stmt;
      exception 
        when TMAX_ERRPKG.e_success_with_compilation_err then
          null;
        when others then
          Raise_application_error(-20002, sqlerrm||chr(10)||substr(v_stmt,1,2000));
      end;
      dbms_lob.trim(v_stmt,0);
      --dbms_output.put_line('/');
    v_type :=  v_source_code(v_owner)(v_name).next(v_type);
  end loop;
 v_name :=  v_source_code(v_owner).next(v_name); 
 end loop;  
v_owner := v_source_code.next(v_owner);
end loop;
end modify_source_code;
--
function Chk_XMLNamespaces
(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_modify boolean := false
  )return  int
  is
v_lines_count pls_integer := 0;
begin
$if dbms_db_version.ver_le_12 $then
  for r in (with s as (
select 
case when regexp_like(s.TEXT,'XMLNamespaces','i') then line end m2,
case when regexp_like(s.TEXT,'DEFAULT','i') and not regexp_like(s.TEXT,'(([\/\\]\*O2T)|(--)).*(DEFAULT)','i') then line end m3,
case when regexp_like(s.TEXT,'http','i') then line end m4,   
s.*
 from all_source s
 where s.OWNER = p_owner
 and s.TYPE not like  'JAVA%'
 and s.NAME not like p_ignore_prefix || '%'
 ),
 m as (
select * from s MATCH_RECOGNIZE(
partition by owner,name,type  
order by line
measures 
         MATCH_NUMBER() AS mno
         ALL ROWS PER MATCH
PATTERN (FLAT1 NXST? FLAT2 NXST? FLAT3+)
         DEFINE
           FLAT1 AS m2 is not null,
           FLAT2 AS m3 is not null,
           FLAT3 AS m4 is not null,
           NXST  AS m2 is null and m3 is null and m4 is null
       )),
  t as (
select owner,name,type,mno,max(m3)dflt_line,min(line) start_line, max(line) end_line,
listagg(text) within group(order by line) txt
from m
group by owner,name,type,mno),
  u as (
select 
regexp_substr(t.txt,'(DEFAULT)[^,]+,',1,1,'i') dflt1,
regexp_substr(t.txt,'(DEFAULT)[^,]+',1,1,'i') dflt2,
regexp_count(t.txt,'http',1,'i') http_count,
t.* 
from t)
select
regexp_substr(u.txt,'(as ([^)]*)){'||to_char(http_count-1)||'}[\)]*',1,1,'in',1) http1, 
u.* from u)loop
  if v_lines_count = 0 then
        dbms_output.put_line(chr(9)||'Tibero syntax error in XMLNamespaces statement');
  end if;
      dbms_output.put_line(chr(9)||to_char(v_lines_count+1)||')'||r.type||' '||r.owner||'.'||r.name||' lines '||r.start_line||'..'||r.end_line);
      v_lines_count := v_lines_count + 2;  
  if p_modify then
    rplc(p_owner => r.owner,
          p_name => r.name,
          p_type => r.type,
          p_lines_list => r.dflt_line,
          p_oldsub => r.dflt1,
          p_newsub => '/*O2T '||to_char(sysdate,'rr-mm-dd')||' '||r.dflt1||'*/',
          p_regexp => false);
    --
    rplc(p_owner => r.owner,
          p_name => r.name,
          p_type => r.type,
          p_lines_list => r.end_line,
          p_oldsub => r.http1,
          p_newsub => r.http1||'/*O2T '||to_char(sysdate,'rr-mm-dd')||' */ '||
          '$IF not tmax_Constpkg.c_isTibero $THEN , $END '||
          r.dflt2,
          p_regexp => false);
  end if;
end loop;
$else
  dbms_output.put_line('CheckXMLNamespaces function available only in 12c');
$end
 return v_lines_count;
end Chk_XMLNamespaces;
--
function Chk_getstringval
(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_modify boolean := false
  )return  int
  is
v_lines_count pls_integer := 0;
begin
  for r in (
  select 
  regexp_substr(s.TEXT,'extract\s*\(.+\).getstringval\(\)',1,1,'i') substr1,
  regexp_substr(s.TEXT,'(extract\s*\(.+\))(.getstringval\(\))',1,1,'i',1) substr2,
  s.*
   from all_source s
  where s.OWNER = p_owner
   and s.TYPE not like  'JAVA%'
   and s.NAME not like p_ignore_prefix || '%'
   and regexp_like(s.TEXT,'\).getstringval\(\)','i')
   and not regexp_like(s.TEXT,'(([\/\\]\*O2T)|(--)).*(\).getstringval\(\))','i')
)loop
  if v_lines_count = 0 then
        dbms_output.put_line(chr(9)||'Tibero syntax error in getstringval call');
  end if;
      dbms_output.put_line(chr(9)||to_char(v_lines_count+1)||')'||r.type||' '||r.owner||'.'||r.name||' line '||r.line);
      v_lines_count := v_lines_count + 1;  
  if p_modify then
    --
    rplc(p_owner => r.owner,
          p_name => r.name,
          p_type => r.type,
          p_lines_list => r.line,
          p_oldsub => r.substr1,
          p_newsub => '/*O2T '||to_char(sysdate,'rr-mm-dd')||' */ '||
          '$IF tmax_Constpkg.c_isTibero $THEN getstringval('||r.substr2||
          ') $ELSE '||r.substr1||' $END ',
          p_regexp => false);
  end if;
end loop;
 return v_lines_count;
end Chk_getstringval; 
--
function Chk_XmlMthds_old
(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_modify boolean := false,
  p_name varchar2 := null
  )return  int
is
type XmlMthdsList_t is varray(2) of varchar2(128);
v_m XmlMthdsList_t := XmlMthdsList_t('getrootelement','getclobval');
v_e varchar2(32767);
v_new varchar2(32767);
v_lines_count int := 0;
begin
 for i in v_m.first..v_m.last
  loop
    v_e := '(([^ )]+)|(\([^\(]+\)))(\.'||v_m(i)||'\(\))';
for r in (
select regexp_substr(s.TEXT, v_e, 1, 1, 'i') sbstr1,
       regexp_substr(s.TEXT, v_e, 1, 1, 'i', 1) sbstr2,
       s.owner,
       s.type,
       s.name,
       s.line
  from all_source s
 where s.OWNER = user
   and s.TYPE not like 'JAVA%'
   and s.NAME not like p_ignore_prefix || '%'
   and regexp_like(s.TEXT, v_m(i), 'i')
   and not regexp_like(s.TEXT,'(([\/\\]\*O2T)|(--)).*('||v_m(i)||')','i')
   and (s.name = upper(p_name) or p_name is null)
)loop
  if v_lines_count = 0 then
        dbms_output.put_line(chr(9)||'Tibero syntax error in '||v_m(i)||' call');
  end if;
      dbms_output.put_line(chr(9)||to_char(v_lines_count+1)||')'||r.type||' '||r.owner||'.'||r.name||' line '||r.line);
      v_lines_count := v_lines_count + 1; 
      v_new :=  case when r.sbstr2 is not null then '/*O2T '||to_char(sysdate,'rr-mm-dd')||' */ '||
          ' $IF tmax_Constpkg.c_isTibero $THEN '||v_m(i)||'('||r.sbstr2||
          ') $ELSE '||r.sbstr1||' $END '
      else null end;
        
      dbms_output.put_line(chr(9)||'OLD: '||r.sbstr1);
      dbms_output.put_line(chr(9)||'NEW: '||v_new);
  if p_modify and v_new is not null then
    --
    rplc(p_owner => r.owner,
          p_name => r.name,
          p_type => r.type,
          p_lines_list => r.line,
          p_oldsub => r.sbstr1,
          p_newsub => v_new,
          p_regexp => false);
  end if;
end loop;
 end loop;
 return v_lines_count;
end Chk_XmlMthds_old;
--
function Chk_XmlMthds
(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_modify boolean := false,
  p_type varchar2 := null,
  p_name varchar2 := null
  )return  int
is
v_lines_count int := 0;
begin
  for r in (
    with s as (
select 
t.* 
from tmax_check4migrate.sct(p_owner => p_owner,p_ignore_prefix => p_ignore_prefix,p_type => p_type,p_name => p_name) t
 ),
 m as (
select * from s MATCH_RECOGNIZE(
partition by owner,name,type  
order by line,col
measures 
         MATCH_NUMBER() AS mno,
         CLASSIFIER() AS CL
         ALL ROWS PER MATCH
PATTERN (((XS XO?)|XO) N+ XM)
         DEFINE
           XS as kind in ('SELECT',':='),
           XO as kind = 'XO',
           XM as kind = 'XM',
           N  as kind in ('N','COMM1','COMM2','COMM3')
       )),
  t as (
select owner,name,type,mno,
min(case when cl = 'XS' then line end) XS_line,
min(case when cl = 'XS' then token end) XS_token,
min(case when cl = 'XO' then line end) XO_line,
min(case when cl = 'XO' then token end) XO_token,
min(case when cl = 'XM' then line end) XM_line,
min(case when cl = 'XM' then token end) XM_token,
/*listagg(cl,',' ON OVERFLOW TRUNCATE ) within group(order by line,col) cls,*/
listagg(token,' ' $if dbms_db_version.ver_le_12_2 $then ON OVERFLOW TRUNCATE $end ) within group(order by line,col) txt
from m
group by owner,name,type,mno)
select * from t )loop
if v_lines_count = 0 then
    dbms_output.put_line(chr(9)||'Tibero syntax error in '||r.xm_token||' call');
end if;
  dbms_output.put_line(chr(9)||to_char(v_lines_count+1)||')'||r.type||' '||r.owner||'.'||r.name||' line '||r.xm_line);
  v_lines_count := v_lines_count + 1; 
dbms_output.put_line(chr(9)||'OLD: '||r.txt);
if p_modify then
  if r.xo_line > 0 then
    rplc(p_owner => r.owner,
          p_name => r.name,
          p_type => r.type,
          p_lines_list => r.xo_line,
          p_oldsub => r.xo_token,
          p_newsub => '/*O2T '||to_char(sysdate,'rr-mm-dd')||' */ '||
          ' $IF tmax_Constpkg.c_isTibero $THEN '||r.xm_token||'('||r.xo_token||
          ' $ELSE '||r.xo_token||' $END ',
          p_regexp => false);
  elsif r.xs_line > 0 then
    rplc(p_owner => r.owner,
          p_name => r.name,
          p_type => r.type,
          p_lines_list => r.xs_line,
          p_oldsub => r.xs_token,
          p_newsub => '/*O2T '||to_char(sysdate,'rr-mm-dd')||' */ '||
          ' $IF tmax_Constpkg.c_isTibero $THEN '||r.xs_token||r.xm_token||'('||
          ' $ELSE '||r.xs_token||' $END ',
          p_regexp => false);
  end if;
  --
  if r.xm_line > 0 then
    rplc(p_owner => r.owner,
          p_name => r.name,
          p_type => r.type,
          p_lines_list => r.xm_line,
          p_oldsub => '.'||r.xm_token||'()',
          p_newsub => '/*O2T '||to_char(sysdate,'rr-mm-dd')||' */ '||
          ' $IF tmax_Constpkg.c_isTibero $THEN '||')'||
          ' $ELSE '||'.'||r.xm_token||'()'||' $END ',
          p_regexp => false);
  end if;
end if;
/* if r.xo_line > 0 then
  dbms_output.put_line(chr(9)||'OLD: '||r.xs_token);
else
  dbms_output.put_line(chr(9)||'OLD: '||r.xs_token);
end if;
      
     v_new :=  case when r.sbstr2 is not null then '\*O2T '||to_char(sysdate,'rr-mm-dd')||' *\ '||
          ' $IF tmax_Constpkg.c_isTibero $THEN '||v_m(i)||'('||r.sbstr2||
          ') $ELSE '||r.sbstr1||' $END '
      else null end;

dbms_output.put_line(chr(9)||'NEW: '||v_new);*/
end loop;
  return v_lines_count;
end Chk_XmlMthds;
-- Run checking
procedure Run(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_modify boolean := false
  )
  is
  v_lines_count int := 0;
 begin
 v_source_code.delete;
 dbms_output.enable(null);
 dbms_output.put_line('Check exceptions...');
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'chk_excptns');
 v_lines_count := chk_excptns(p_owner,p_ignore_prefix);
 dbms_output.put_line('Check other issues...');
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'chk_new_keyword');
 v_lines_count := v_lines_count + chk_new_keyword(p_owner,p_ignore_prefix);
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'chk_functions');
 v_lines_count := v_lines_count + chk_functions(p_owner,p_ignore_prefix);
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'chk_args');
 v_lines_count := v_lines_count + chk_args(p_owner,p_ignore_prefix);
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'Chk_getstringval');
 v_lines_count := v_lines_count + Chk_getstringval(p_owner,p_ignore_prefix,p_modify);
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'Chk_XmlMthds');
 v_lines_count := v_lines_count + Chk_XmlMthds(p_owner,p_ignore_prefix,p_modify);
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'Chk_XMLNamespaces');
 v_lines_count := v_lines_count + Chk_XMLNamespaces(p_owner,p_ignore_prefix,p_modify);
 dbms_output.put_line('***');
 dbms_output.put_line(v_lines_count||' lines need to be rewritten for migration to Tibero');
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'count analyzable lines');
  SELECT count(*)
    into v_lines_count
    FROM all_plsql_object_settings s, all_source c
   where s.PLSCOPE_SETTINGS like '%IDENTIFIERS:ALL%'
     and s.OWNER = p_owner
     and c.NAME not like p_ignore_prefix || '%'
     and c.NAME not like  'SYS_PLSQL_%'
     and c.OWNER = s.OWNER
     and c.NAME = s.NAME
     and c.TYPE = s.TYPE;
  dbms_output.put_line(v_lines_count||' analyzable lines of PL/SQL code in '||p_owner||' scheme(compiled with plscope_settings=''IDENTIFIERS:ALL'')');
  dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'count total lines');
  select count(*)
   into v_lines_count
   from all_source s
  where s.OWNER = p_owner
    and s.TYPE not like  'JAVA%'
    and s.NAME not like p_ignore_prefix || '%'
    and s.NAME not like  'SYS_PLSQL_%';
 dbms_output.put_line(v_lines_count||' total lines of PL/SQL code in '||p_owner||' scheme');
 --
 dbms_output.put_line('***');
 dbms_application_info.set_module($$PLSQL_UNIT || '.' ||$$PLSQL_LINE,'SYS referenced objects list');
 dbms_output.put_line('SYS referenced objects list');
 for d in (
select d.REFERENCED_TYPE,
       d.REFERENCED_NAME,
       listagg(d.name, ',' 
 $if dbms_db_version.ver_le_12_2 $then
       ON OVERFLOW TRUNCATE
 $end
       ) WITHIN GROUP(order by d.name) REFERENCE_LIST
  from all_dependencies d
 where d.OWNER = p_owner
   and d.NAME not like p_ignore_prefix || '%'
   and d.REFERENCED_OWNER = 'SYS'
   and d.REFERENCED_NAME != 'STANDARD'
   and d.REFERENCED_NAME != 'DBMS_STANDARD'
 group by d.REFERENCED_TYPE, d.REFERENCED_NAME
 order by d.REFERENCED_TYPE, d.REFERENCED_NAME
)loop
dbms_output.put_line(d.referenced_type||' '||d.referenced_name||' : '||d.reference_list);
end loop;
--
if p_modify then
  modify_source_code;
end if;  
 end Run;
--
function sct(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix,
  p_type varchar2 := null,
  p_name varchar2 := null) return sct_t pipelined
is
v_sc sc_t ;
v_tr varchar2(32767) := '[[:space:],\(\)\;\.]';
v_prev varchar2(c_token_length char); 
begin
for s in (
select 
s.owner,
s.name,
s.type,
s.line,s.text
from all_source s
   where s.OWNER = p_owner
     and s.TYPE not like  'JAVA%'
     and s.NAME not like p_ignore_prefix || '%'
     and (s.TYPE = upper(p_type) or p_type is null)
     and (s.NAME = upper(p_name) or p_name is null)
order by
        s.owner,
        s.name,
        s.type,
        s.line     
     )loop
  v_sc.col := 1;
  for c in (
   select regexp_instr(s.text, v_tr, 1, level) col
    from dual
  connect by regexp_instr(s.text, v_tr, 1, level) > 0
  )
  loop     
  v_sc.owner:= s.owner;
  v_sc.name := s.name;
  v_sc.type := s.type;
  
  v_sc.token := substr(s.text,v_sc.col,c.col-v_sc.col);
  if regexp_replace(v_sc.token,'\s') is not null then
   --start kind define
   select  
   case when v_sc.kind = 'COMM1' and v_sc.line = s.line then 'COMM1'
        when v_sc.kind = 'COMM2' and v_prev not like '%*/%' then 'COMM2'
        when v_sc.kind = 'COMM3' and not regexp_like(v_sc.token,'\$END','i') then 'COMM3' 
        when regexp_like(v_sc.token,'(--){2,}') then 'COMM1'
        when regexp_like(v_sc.token,'^''{0}[^'']*(/\*)[^'']*''{0}$') then 'COMM2'
        when regexp_like(v_sc.token,'\$IF','i') then 'COMM3'
        when upper(v_sc.token) in ('EXTRACT') and v_prev != '.' then 'XO'
        when v_sc.token in (':=') then v_sc.token
        when upper(v_sc.token) in ('SELECT') then upper(v_sc.token)
        when v_prev = '.' and
             exists(select null from all_procedures p where p.PROCEDURE_NAME=upper(v_sc.token) and p.OBJECT_NAME = 'XMLTYPE')
             then 'XM' 
        when v_prev =':=' and 
             exists(select null from all_arguments a where a.OBJECT_NAME=upper(v_sc.token) and a.POSITION=0 and a.TYPE_NAME='XMLTYPE')
             then 'XO' 
        else 'N'
    end into v_sc.kind from dual;
   --end kind define
     v_sc.line := s.line;          
     pipe row (v_sc);
     --v_sc.kind := null;
     v_prev := v_sc.token;
  end if;
  --
  v_sc.col := c.col;
  v_sc.token := substr(s.text,c.col,1);
  if regexp_replace(v_sc.token,'\s') is not null then
    v_sc.kind := case  
                      when v_sc.kind = 'COMM1' then v_sc.kind
                      when v_sc.kind = 'COMM2' and v_prev not like '%*/%' then 'COMM2'
                      when v_sc.kind = 'COMM3' and not regexp_like(v_sc.token,'\$END','i') then 'COMM3'   
                      else case v_sc.token 
                           when ';' 
                           then v_sc.token 
                           else 'N' 
                           end
                 end;
     pipe row (v_sc);
     v_prev := v_sc.token;
     --v_sc.kind := null;
  end if; 
  v_sc.col := v_sc.col + 1;
  end loop;
--
end loop;
  return;
end sct;
end tmax_check4migrate;
/
