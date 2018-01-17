create or replace package tmax_check4migrate is

  -- Author  : Vasiliy@Floka.ru
  -- Created : 29.12.2017 13:08:54
  -- Purpose : Checking for known migration issues from Oracle to Tibero
  -- Before using you need ALTER SESSION SET plscope_settings='IDENTIFIERS:ALL' and recompile pl/sql objects
  -- Version of Oracle must be 11g or higher 
  c_ignore_prefix constant varchar2(8) := 'TMAX_';
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
  p_ignore_prefix varchar2 := c_ignore_prefix
  );
end tmax_check4migrate;
/
create or replace package body tmax_check4migrate is
-- 
c_exc_name_length constant int := 128;
type t_exc_tab is table of varchar2(c_exc_name_length) index by pls_integer;
v_exc_tab t_exc_tab;
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
       where i.OWNER = p_owner
         and i.OBJECT_TYPE = 'PACKAGE'
         and i.OBJECT_NAME = p_err_pck_name
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
            v_exc_tab(v_err_code):= c.owner||'.'||c.object_name||'.'||c.name;
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
       -- To do: add save not exist error codes
     return null;
   end;
 end getExceptionName;
-- Checking for new keyword
function chk_new_keyword(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  ) return  int is
v_lines_count int := 0;
begin
  for r in (  
select 
row_number() over( order by s.OWNER, s.NAME, s.TYPE, s.LINE)rn,
s.OWNER, s.NAME, s.TYPE, s.LINE
  from all_identifiers r,
       all_identifiers d,
       all_identifiers a,
       all_identifiers c,
       all_source      s
 where r.OWNER = p_owner
   and r.TYPE = 'OBJECT'
   and r.USAGE = 'REFERENCE'
   and r.OBJECT_NAME not like p_ignore_prefix||'%'
   and r.OWNER = d.OWNER
   and r.OBJECT_NAME = d.OBJECT_NAME
   and r.OBJECT_TYPE = d.OBJECT_TYPE
   and r.LINE = d.LINE
   and d.TYPE = 'VARIABLE'
   and d.USAGE = 'DECLARATION'
   and a.SIGNATURE = d.SIGNATURE
   and a.USAGE = 'ASSIGNMENT'
   and c.OWNER = r.OWNER
   and c.NAME = r.NAME
   and c.TYPE = 'FUNCTION'
   and c.USAGE = 'CALL'
   and c.OBJECT_TYPE = a.OBJECT_TYPE
   and c.OBJECT_NAME = a.OBJECT_NAME
   and s.OWNER = c.OWNER
   and s.TYPE = c.OBJECT_TYPE
   and s.NAME = c.OBJECT_NAME
   and s.LINE between a.LINE and c.LINE
   and upper(s.TEXT) like '%NEW %'
    )loop
    v_lines_count := r.rn; 
          if r.rn = 1 then
            dbms_output.put_line(
            'The keyword "new" in the type constructor expressions is optional in Oracle and is absent in Tibero');
            dbms_output.put_line('Reference list');
          end if;
          dbms_output.put_line(r.rn||' '||r.type||' '||r.owner||'.'||r.name||' line '||r.line);
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
  v_ExceptionName varchar2(c_exc_name_length);
  v_lines_count int := 0;
begin
  for c in (select
            row_number() over( order by i.OWNER,i.OBJECT_NAME,i.OBJECT_TYPE,i.LINE)rn,
               i.SIGNATURE, 
               i.OWNER,
               i.OBJECT_NAME,
               i.NAME,
               i.LINE,
               a.OBJECT_TYPE,
               a.LINE ASSIGNMENT_LINE
          from all_identifiers i, all_identifiers a
         where i.OWNER = p_owner
           and i.OBJECT_NAME not like p_ignore_prefix||'%'
           and i.TYPE = 'EXCEPTION'
           and i.USAGE = 'DECLARATION'
           and i.SIGNATURE = a.SIGNATURE
           and a.USAGE = 'ASSIGNMENT'
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
       dbms_output.put_line(c.rn||'. Exception '||c.name||'('||c.object_type||' '||c.owner||'.'||c.object_name||' line '||c.line||')'||
       ' init with error code '||v_err_code || '(line '||c.assignment_LINE||')' );
       v_ExceptionName := getExceptionName(v_err_code);
       if v_ExceptionName is not null then
          dbms_output.put_line('...replace it to '||v_ExceptionName);
       end if;
       v_warning := true;
    -- REFERENCE list
    for r in (select
               row_number() over( order by i.OWNER,i.OBJECT_NAME,i.OBJECT_TYPE,i.LINE)rn,
               i.SIGNATURE, 
               i.OWNER,
               i.OBJECT_NAME,
               i.OBJECT_TYPE,
               i.LINE
          from all_identifiers i
         where i.OWNER = p_owner
           and i.OBJECT_NAME not like p_ignore_prefix||'%'
           and i.TYPE = 'EXCEPTION'
           and i.USAGE = 'REFERENCE'
           and i.SIGNATURE = c.SIGNATURE
           ) loop
          v_lines_count := v_lines_count + 1; 
          if r.rn = 1 then
            dbms_output.put_line('Reference list');
          end if;
          dbms_output.put_line(c.rn||'.'||r.rn||' '||r.object_type||' '||r.owner||'.'||r.object_name||' line '||r.line);
    end loop;  
    end if;
    v_err_code := null;
  end loop;
  if v_warning then 
    dbms_output.put_line('You need to use conditional compilation to define different system error codes for Tibero and Oracle');
  end if;
  return v_lines_count;
end chk_excptns;
-- Run checking
procedure Run(
  p_owner varchar2 := user,
  p_ignore_prefix varchar2 := c_ignore_prefix
  )
  is
  v_lines_count int := 0;
 begin
 dbms_output.enable(null);
 dbms_output.put_line('Check exceptions...');
 v_lines_count := chk_excptns(p_owner,p_ignore_prefix);
 dbms_output.put_line('Check other issues...');
 v_lines_count := v_lines_count + chk_new_keyword(p_owner,p_ignore_prefix);
 dbms_output.put_line('***');
 dbms_output.put_line(v_lines_count||' lines need to be rewritten for migration to Tibero');
  SELECT count(*)
    into v_lines_count
    FROM all_plsql_object_settings s, all_source c
   where s.PLSCOPE_SETTINGS like '%IDENTIFIERS:ALL%'
     and c.NAME not like p_ignore_prefix || '%'
     and c.OWNER = s.OWNER
     and c.NAME = s.NAME
     and c.TYPE = s.TYPE;
  dbms_output.put_line(v_lines_count||' analyzable lines of PL/SQL code in '||p_owner||' scheme(compiled with plscope_settings=''IDENTIFIERS:ALL'')');
  select count(*)
   into v_lines_count
   from all_source s
  where s.OWNER = p_owner
    and s.NAME not like p_ignore_prefix || '%';
 dbms_output.put_line(v_lines_count||' total lines of PL/SQL code in '||p_owner||' scheme');
 end Run;
end tmax_check4migrate;
/
