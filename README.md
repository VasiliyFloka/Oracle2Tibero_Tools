# Oracle2Tibero_Tools
Tools for migration from Oracle to [Tibero](http://tmaxsoft.com/products/tibero/)
## Introduction
Oracle2Tibero_Tools are PL/SQL packages to simplify migration from Oracle to [Tibero](http://tmaxsoft.com/products/tibero/).
It is based on PL/Scope which is available in the Oracle Database since version 11g.
Requires a Oracle database server side installation.
## Release notes
At the moment, only the use of Oracle system error codes is checked and some other issues.
## How to use 
### Check only (example)
    SQL> ALTER SESSION SET plscope_settings='IDENTIFIERS:ALL';
    SQL> alter procedure p1 compile;
    SQL> set serveroutput on
    SQL> exec tmax_check4migrate.run
    Check exceptions...
    1.Exception E_OBJECT_NOT_EXISTS(PROCEDURE HR.P1 line 2) init with error code -4043(line 3)
    ...replace it to HR.TMAX_ERRPKG.E_OBJECT_NOT_EXISTS
      Reference list
      1)PROCEDURE HR.P1 line 18
      2)PROCEDURE HR.P1 line 25
    ...You need to use conditional compilation to define different system error codes for Tibero and Oracle
    Check other issues...
    *** The keyword "new" in the type constructor expressions is optional in Oracle and is absent in Tibero
      Reference list
      1.PROCEDURE HR.P1 line 30
    *** The parallel-enabled functions is absent in Tibero
    1.PACKAGE HR.PARALLEL_PTF_API.TEST_PTF
      Reference list
      1)PROCEDURE HR.P1 line 37
    ...You can use conditional compilation to exclude PARALLEL_ENABLE clause in Tibero
    *** The ANYTYPE is absent in Tibero
    1.FUNCTION HR.CREATE_A_TYPE
      Reference list
      1)PROCEDURE HR.P1 line 48
    2.PACKAGE HR.TEST1PKG.CREATE_A_TYPE2
      Reference list
      1)PROCEDURE HR.P1 line 61
    *** The JSON_ARRAY_T is absent in Tibero
    1.FUNCTION HR.JSON_F1
      Reference list
      1)PROCEDURE HR.P1 line 57
    2.PACKAGE HR.TEST1PKG.JSON_F1
      Reference list
      1)PROCEDURE HR.P1 line 58
    ***
    13 lines need to be rewritten for migration to Tibero
    214 analyzable lines of PL/SQL code in HR scheme(compiled with plscope_settings='IDENTIFIERS:ALL')
    485 total lines of PL/SQL code in HR scheme
### Check and auto modify PL/SQL code. 
#### For example, at first the result of the check was the following:
    Check exceptions...
    1.Exception LONG_TEXT(PACKAGE BODY GPT.CM_CISTERN line 2528) init with error code -6502(line 2529)
    ...replace it to VALUE_ERROR
    Reference list
    1)PACKAGE BODY GPT.CM_CISTERN line(s) 2570,2615
    4.Exception E_END_AQ(PACKAGE BODY GPT.CM_CISTERN line 6128) init with error code -25228(line 6129)
    Reference list
    1)PACKAGE BODY GPT.CM_CISTERN line(s) 6198
    6.Exception E_END_GROUP_AQ(PACKAGE BODY GPT.CM_CISTERN line 6131) init with error code -25235(line 6132)
    Reference list
    1)PACKAGE BODY GPT.CM_CISTERN line(s) 6197
    ...
    620.Exception E_UK_CONSTRAINT(PACKAGE BODY GPT.HUB_ZDD_RES_GU12_APCK line 254) init with error code -1(line 255)
    ...replace it to DUP_VAL_ON_INDEX
    Reference list
    1)PACKAGE BODY GPT.HUB_ZDD_RES_GU12_APCK line(s) 619
    ...You need to use conditional compilation to define different system error codes for Tibero and Oracle
    Check other issues...
    *** The keyword "new" in the type constructor expressions is optional in Oracle and is absent in Tibero
    Reference list
    1.PACKAGE BODY GPT.CM_CA_DATA_PCK line(s) 1296,2297
    3.PACKAGE BODY GPT.CM_CISTERN line(s) 2553,6144,6375
    6.PACKAGE BODY GPT.CM_CLIENT_ORDERS_PCK line(s) 3424,3438
    8.PACKAGE BODY GPT.CM_CONTRAGENT line(s) 469
    9.PACKAGE BODY GPT.CM_FPU line(s) 494,2327
    11.PACKAGE BODY GPT.CM_GU12 line(s) 7426,7529,7638,7638
    15.PACKAGE BODY GPT.CM_GU12ZDD_PCK line(s) 95,159,197,214
    19.PACKAGE BODY GPT.CM_GVC_TASKS_PCK line(s) 172
    20.PACKAGE BODY GPT.CM_INVOICE_PCK line(s) 17,14121,14255,14604,14770,14988,15117,15331,15379
    ...
    970.TRIGGER GPT.HUB_GPT006_DEPO_ATRG line(s) 14,29
    972.TRIGGER GPT.HUB_IMP001_CNT016_STATION_ATRG line(s) 8
    ***
    1593 lines need to be rewritten for migration to Tibero
    725286 analyzable lines of PL/SQL code in GPT scheme(compiled with plscope_settings='IDENTIFIERS:ALL')
    725286 total lines of PL/SQL code in GPT scheme
    ***
    SYS referenced objects list
    ...
#### Try to auto modify PL/SQL code. Edition-based redefinition using is not necessary but very useful.
    SQL>drop edition tmax;
    Done
    SQL>create edition tmax;
    Done
    SQL>alter session set edition=tmax;
    Session altered
    SQL>exec tmax_check4migrate.run(p_modify => true)
    PL/SQL procedure successfully completed
    SQL> set serveroutput on
    SQL> exec tmax_check4migrate.run
    Check exceptions...
    Check other issues...
    ***
    0 lines need to be rewritten for migration to Tibero
    725286 analyzable lines of PL/SQL code in GPT scheme(compiled with plscope_settings='IDENTIFIERS:ALL')
    725286 total lines of PL/SQL code in GPT scheme
    ***
    SYS referenced objects list
    ...
#### Thus, 1593 lines of code were automatically fixed

