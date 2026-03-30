*&---------------------------------------------------------------------*
*& Include ZOR_RT_ERROR_NOTIF_D01 — Business model class definitions
*& (Türler, sabitler, lcl_business)
*&---------------------------------------------------------------------*
CONSTANTS:
  gc_dbcon_genius3 TYPE dbcon-con_name VALUE 'GENIUS3',
  gc_tol           TYPE p LENGTH 8 DECIMALS 2 VALUE '0.01'.

TYPES:
  BEGIN OF ty_bw_sql,
    magaza TYPE string,
    werks  TYPE string,
    fk_pos TYPE string,
    kasa   TYPE string,
    ip     TYPE string,
    tdate  TYPE string,
    satis  TYPE string,
    iade   TYPE string,
  END OF ty_bw_sql,
  BEGIN OF ty_kasa_err,
    magaza_adi    TYPE string,
    uretim_yeri   TYPE string,
    fk_pos        TYPE string,
    kasa_no       TYPE string,
    ip_adresi     TYPE string,
    tarih         TYPE datum,
    satis_bw      TYPE /posdw/transturnover,
    iade_bw       TYPE /posdw/transturnover,
    satis_sap     TYPE /posdw/transturnover,
    iade_sap      TYPE /posdw/transturnover,
    diff_satis    TYPE /posdw/transturnover,
    diff_iade     TYPE /posdw/transturnover,
  END OF ty_kasa_err,
  tt_kasa_err TYPE STANDARD TABLE OF ty_kasa_err WITH EMPTY KEY,
  BEGIN OF ty_sap_agg,
    retailstoreid   TYPE /posdw/tlogf-retailstoreid,
    businessdaydate TYPE /posdw/tlogf-businessdaydate,
    workstationid   TYPE /posdw/tlogf-workstationid,
    sale_sum        TYPE /posdw/transturnover,
    ref_sum         TYPE /posdw/transturnover,
  END OF ty_sap_agg,
  tt_sap_agg TYPE SORTED TABLE OF ty_sap_agg
    WITH UNIQUE KEY retailstoreid businessdaydate workstationid.

CLASS lcl_business DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-DATA:
      gt_inv  TYPE STANDARD TABLE OF zor_cash_inval WITH EMPTY KEY,
      gt_kasa TYPE tt_kasa_err.

    CLASS-METHODS:
      validate_selection,
      refresh_data,
      build_notification_email
        EXPORTING
          ev_html    TYPE string
          ev_subject TYPE so_obj_des.

  PRIVATE SECTION.

    CLASS-METHODS:
      fetch_invalid_trx,
      fetch_genius_bw
        RETURNING VALUE(rt_bw) TYPE STANDARD TABLE OF ty_bw_sql
        RAISING cx_sql_exception,
      build_sap_aggregates
        RETURNING VALUE(rt_agg) TYPE tt_sap_agg,
      compare_bw_sap
        IMPORTING it_bw            TYPE STANDARD TABLE OF ty_bw_sql
                  it_agg           TYPE tt_sap_agg
        RETURNING VALUE(rt_diff)   TYPE tt_kasa_err,
      parse_dec_string
        IMPORTING iv_str           TYPE string
        RETURNING VALUE(rv_dec)    TYPE /posdw/transturnover,
      parse_sql_date
        IMPORTING iv_str           TYPE string
        RETURNING VALUE(rv_datum)  TYPE datum.

ENDCLASS.
