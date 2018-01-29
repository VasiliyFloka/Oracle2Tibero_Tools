create or replace package tmax_ErrPkg is

  -- Author  : Vasiliy@Floka.ru
  -- Created : 11.12.2017 10:36:21
  -- Purpose : Error handling
  e_object_not_exists exception;
  pragma exception_init(e_object_not_exists,
  $if tmax_Constpkg.c_isTibero $THEN
  -7071
  $ELSE
  -4043
  $END
  );
  --
  e_compilation_error exception;
  pragma exception_init(e_compilation_error,
  $if tmax_Constpkg.c_isTibero $THEN
  -15163
  $ELSE
  -06550
  $END
  );
  /*"ORA-06559: wrong datatype requested, string, actual datatype is string
    Cause: The sender put different datatype on the pipe than that being requested (package 'dbms_pipe'). The numbers are: 6 - number, 9 - char, 12 - date.
    Action: Check that the sender and receiver agree on the number and types of items placed on the pipe."*/  
  /*"14103: The requested data type is different from the actual data type.
    Cause The requested data type is different from the actual data type.
    Action Call the DBMS_PIPE.UNPACK_MESSAGE procedure by using a valid message type."
    */
  e_wrong_datatype_requested exception;
  pragma exception_init(e_wrong_datatype_requested,
  $if tmax_Constpkg.c_isTibero $THEN
  -14103
  $ELSE
  -06559
  $END
  );                  
  /*"ORA-06558: buffer in dbms_pipe package is full. No more items allowed
    Cause: The pipe buffer size has been exceeded.
    Action: None"*/  
  /*"14101: DBMS_PIPE package buffer size exceeded.
    Cause DBMS_PIPE package buffer size exceeded; no more data can be entered.
    Action Empty the data in the buffer by calling the DBMS_PIPE.SEND_MESSAGE function."
    */ 
  e_pipe_buffer_full exception;
  pragma exception_init(e_pipe_buffer_full,
  $if tmax_Constpkg.c_isTibero $THEN
  -14101
  $ELSE
  -06558
  $END
  );   
              
  /*"ORA-06556: the pipe is empty, cannot fulfill the unpack_message request
    Cause: There are no more items in the pipe.
    Action: Check that the sender and receiver agree on the number and types of items placed on the pipe."*/  
  /*"14102: Read buffer in the DBMS_PIPE package is empty.
    Cause All data in the buffer read from the DBMS_PIPE.RECEIVE_MESSAG function has been read.
    Action None"*/
  e_pipe_is_empty exception;
  pragma exception_init(e_pipe_is_empty,
  $if tmax_Constpkg.c_isTibero $THEN
  -14102
  $ELSE
  -06556
  $END
  );   
  /*"ORA-24344: success with compilation error
    Cause: A sql/plsql compilation error occurred.
    Action: Return OCI_SUCCESS_WITH_INFO along with the error code"*/  
  /*"15146: PSM compilation error.
    Cause Failed to compile the given PSM.
    Action Check the error, and modify the PSM."*/
  e_success_with_info exception;
  pragma exception_init(e_success_with_info,
  $if tmax_Constpkg.c_isTibero $THEN
  -15146
  $ELSE
  -24344
  $END
  );
  /*"ORA-04091: table string.string is mutating, trigger/function may not see it
    Cause: A trigger (or a user defined plsql function that is referenced in this statement) attempted to look at (or modify) a table that was in the middle of being modified by the statement which fired it.
    Action: Rewrite the trigger (or function) so it does not read that table."*/
  /*"10016: Table mutation occurred during trigger execution.
    Cause Table mutation occurred during trigger execution.
    Action Delete the mutation."*/
  e_table_mutating exception;
  pragma exception_init(e_table_mutating,
  $if tmax_Constpkg.c_isTibero $THEN
  -10016
  $ELSE
  -04091
  $END
  );
  /*01843 not a valid month
    // *Cause:
    // *Action:"*/  
  /*"5030: Invalid month value.
    Cause Invalid value specified for the month.
    Action Input an integer value between 1 and 12."*/
  e_not_valid_month exception;
  pragma exception_init(e_not_valid_month,
  $if tmax_Constpkg.c_isTibero $THEN
  -5030
  $ELSE
  -01843
  $END
  );
  /*"ORA-01427: single-row subquery returns more than one row
    Cause
    You tried to execute a SQL statement that contained a SQL subquery that returns more than one row."*/  
  /*"70069:Too many rows returned for the RETURNING clause
    Cause More than one row returned for the RETURNING clause
    Action Use a SQL statement that returns a single row"
    To do: NEED CHECK!!!*/
  e_subquery_too_many_rows exception;
  pragma exception_init(e_not_valid_month,
  $if tmax_Constpkg.c_isTibero $THEN
  -70069
  $ELSE
  -01427
  $END
  );
  /* ORA-25235: fetched all messages in current transaction from . */
  ------------------------------
  e_fetched_all_messages exception;
  pragma exception_init(e_fetched_all_messages,
  $if tmax_Constpkg.c_isTibero $THEN
  -?????
  $ELSE
  -25235
  $END
  );
  /* ORA-25228: timeout or end-of-fetch during message dequeue from . */
  ------------------------------
  e_timeout_or_end_of_fetch exception;
  pragma exception_init(e_timeout_or_end_of_fetch,
  $if tmax_Constpkg.c_isTibero $THEN
  -?????
  $ELSE
  -25228
  $END
  );
  /* ORA-23401: materialized view ""."" does not exist */
  ------------------------------
  e_materialized_view_not_exist exception;
  pragma exception_init(e_materialized_view_not_exist,
  $if tmax_Constpkg.c_isTibero $THEN
  -?????
  $ELSE
  -23401
  $END
  );
  /* ORA-02292: integrity constraint (.) violated - child record found */
  ------------------------------
  e_child_record_found exception;
  pragma exception_init(e_child_record_found,
  $if tmax_Constpkg.c_isTibero $THEN
  -?????
  $ELSE
  -2292
  $END
  );
  /* ORA-02291: integrity constraint (.) violated - parent key not found */
  ------------------------------
  e_parent_key_not_found exception;
  pragma exception_init(e_parent_key_not_found,
  $if tmax_Constpkg.c_isTibero $THEN
  -?????
  $ELSE
  -2291
  $END
  );
  /* ORA-01843: not a valid month */
  ------------------------------
  e_not_a_valid_month exception;
  pragma exception_init(e_not_a_valid_month,
  $if tmax_Constpkg.c_isTibero $THEN
  -?????
  $ELSE
  -1843
  $END
  );
  /* ORA-00054: resource busy and acquire with NOWAIT specified or timeout expired */
  ------------------------------
  e_resource_busy exception;
  pragma exception_init(e_resource_busy,
  $if tmax_Constpkg.c_isTibero $THEN
  -?????
  $ELSE
  -54
  $END
  );
  procedure put_line(
    p_err int := sqlcode,
    p_msg varchar2 := sqlerrm);
end tmax_ErrPkg;
/
create or replace package body tmax_ErrPkg is
  procedure put_line(
    p_err int := sqlcode,
    p_msg varchar2 := sqlerrm)
  is
  begin
    dbms_output.put_line(p_msg);
  end put_line;
  
end tmax_ErrPkg;
/
