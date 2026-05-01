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
  tt_bw_sql TYPE STANDARD TABLE OF ty_bw_sql WITH DEFAULT KEY,
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
    WITH UNIQUE KEY retailstoreid businessdaydate workstationid,
  BEGIN OF ty_inv_err,
    trans_date      TYPE datum,
    trans_time      TYPE uzeit,
    go_trans_id     TYPE string,
    receipt_barcode TYPE string,
    fk_store        TYPE string,
    fk_pos          TYPE string,
    businessdaydate TYPE datum,
    retailstoreid   TYPE /posdw/tlogf-retailstoreid,
    gross_total     TYPE /posdw/transturnover,
    reason          TYPE string,
  END OF ty_inv_err,
  tt_inv_err TYPE STANDARD TABLE OF ty_inv_err WITH EMPTY KEY,
  BEGIN OF ty_genius_header,
    id              TYPE string,
    fk_store        TYPE string,
    fk_pos          TYPE string,
    trans_date      TYPE string,
    receipt_barcode TYPE string,
    ptype           TYPE string,
    status          TYPE string,
    gross_total     TYPE string,
  END OF ty_genius_header,
  tt_genius_header TYPE STANDARD TABLE OF ty_genius_header WITH EMPTY KEY,
  BEGIN OF ty_kasa_scope,
    uretim_yeri TYPE string,
    fk_pos      TYPE string,
    tarih       TYPE datum,
  END OF ty_kasa_scope,
  tt_kasa_scope TYPE SORTED TABLE OF ty_kasa_scope
    WITH UNIQUE KEY uretim_yeri fk_pos tarih,
  BEGIN OF ty_genius_key,
    id TYPE string,
  END OF ty_genius_key,
  tt_genius_key TYPE STANDARD TABLE OF ty_genius_key WITH EMPTY KEY.

CLASS lcl_business DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-DATA:
      gt_inv  TYPE tt_inv_err,
      gt_kasa TYPE tt_kasa_err.

    CLASS-METHODS:
      validate_selection,
      refresh_data,
      build_notification_email
        EXPORTING
          ev_html    TYPE string
          ev_subject TYPE so_obj_des.

  PRIVATE SECTION.

    CLASS-DATA go_genius_con TYPE REF TO cl_sql_connection.

    CLASS-METHODS:
      get_genius_connection
        RETURNING VALUE(ro_con) TYPE REF TO cl_sql_connection
        RAISING cx_sql_exception,
      close_genius_connection,
      fetch_invalid_trx
        IMPORTING it_kasa          TYPE tt_kasa_err
        RETURNING VALUE(rt_inv)    TYPE tt_inv_err
        RAISING cx_sql_exception,
      fetch_genius_bw
        RETURNING VALUE(rt_bw) TYPE tt_bw_sql
        RAISING cx_sql_exception,
      fetch_genius_headers
        IMPORTING is_kasa             TYPE ty_kasa_err
        RETURNING VALUE(rt_headers)   TYPE tt_genius_header
        RAISING cx_sql_exception,
      check_header_missing
        IMPORTING is_header           TYPE ty_genius_header
        RETURNING VALUE(rv_reason)    TYPE string
        RAISING cx_sql_exception,
      has_genius_rows
        IMPORTING iv_table            TYPE string
                  iv_header_id        TYPE string
        RETURNING VALUE(rv_exists)    TYPE abap_bool
        RAISING cx_sql_exception,
      build_sap_aggregates
        RETURNING VALUE(rt_agg) TYPE tt_sap_agg,
      compare_bw_sap
        IMPORTING it_bw            TYPE tt_bw_sql
                  it_agg           TYPE tt_sap_agg
        RETURNING VALUE(rt_diff)   TYPE tt_kasa_err,
      parse_dec_string
        IMPORTING iv_str           TYPE string
        RETURNING VALUE(rv_dec)    TYPE /posdw/transturnover,
      parse_sql_date
        IMPORTING iv_str           TYPE string
        RETURNING VALUE(rv_datum)  TYPE datum,
      parse_sql_time
        IMPORTING iv_str           TYPE string
        RETURNING VALUE(rv_uzeit)  TYPE uzeit.

ENDCLASS.
