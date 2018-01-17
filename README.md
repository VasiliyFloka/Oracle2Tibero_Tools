# Oracle2Tibero_Tools
Tools for migration from Oracle to [Tibero](http://tmaxsoft.com/products/tibero/)
## Introduction
Oracle2Tibero_Tools are PL/SQL packages to simplify migration from Oracle to [Tibero](http://tmaxsoft.com/products/tibero/).
It is based on PL/Scope which is available in the Oracle Database since version 11g.
Requires a Oracle database server side installation.
## Release notes
At the moment, only the use of Oracle system error codes is checked and some other issues.
## How to use (example)
    SQL> ALTER SESSION SET plscope_settings='IDENTIFIERS:ALL';
    SQL> alter procedure p1 compile reuse settings;
    SQL> set serveroutput on
    SQL> exec tmax_check4migrate.run
    Check exceptions...
    1. Exception E_OBJECT_NOT_EXISTS(PROCEDURE HR.P1 line 2) init with error code -4043(line 3)
    ...replace it to HR.TMAX_ERRPKG.E_OBJECT_NOT_EXISTS
    Reference list
    1.1 PROCEDURE HR.P1 line 15
    1.2 PROCEDURE HR.P1 line 22
    You need to use conditional compilation to define different system error codes for Tibero and Oracle
    Check other issues...
    The keyword "new" in the type constructor expressions is optional in Oracle and is absent in Tibero
    Reference list
    1 PROCEDURE HR.P1 line 27
    ***
    4 lines need to be rewritten for migration to Tibero
    54 analyzable lines of PL/SQL code in HR scheme(compiled with plscope_settings='IDENTIFIERS:ALL')
    325 total lines of PL/SQL code in HR scheme
