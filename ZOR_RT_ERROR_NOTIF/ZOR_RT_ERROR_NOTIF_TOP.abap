*&---------------------------------------------------------------------*
*& Include ZOR_RT_ERROR_NOTIF_TOP
*&---------------------------------------------------------------------*
INCLUDE zor_rt_error_notif_d00.    " Controller class definition
INCLUDE zor_rt_error_notif_d01.    " Business model class definitions
INCLUDE zor_rt_error_notif_d02.    " Technical utility class definitions

DATA g_so_retail TYPE /posdw/tlogf-retailstoreid.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-t01.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) text-s01 FOR FIELD p_begda MODIF ID flt.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_begda TYPE datum OBLIGATORY DEFAULT sy-datum MODIF ID flt.
SELECTION-SCREEN COMMENT 52(5) text-s02 FOR FIELD p_endda MODIF ID flt.
PARAMETERS p_endda TYPE datum OBLIGATORY DEFAULT sy-datum MODIF ID flt.
SELECTION-SCREEN END OF LINE.

SELECT-OPTIONS s_retail FOR g_so_retail.

PARAMETERS p_mail RADIOBUTTON GROUP rg01 USER-COMMAND out.
PARAMETERS p_disp RADIOBUTTON GROUP rg01 DEFAULT 'X'.
SELECTION-SCREEN SKIP.
PARAMETERS p_fis RADIOBUTTON GROUP rg02 DEFAULT 'X' USER-COMMAND lst MODIF ID lst.
PARAMETERS p_kasa RADIOBUTTON GROUP rg02 MODIF ID lst.
SELECTION-SCREEN END OF BLOCK b1.

TABLES sscrfields.
