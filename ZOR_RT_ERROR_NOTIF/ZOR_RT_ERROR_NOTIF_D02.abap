*&---------------------------------------------------------------------*
*& Include ZOR_RT_ERROR_NOTIF_D02 — Technical utility class definitions
*& (Genel: HTML kaçış, BCS gönderimi — lcl_technical)
*&---------------------------------------------------------------------*
CONSTANTS:
  gc_email_to TYPE ad_smtpadr VALUE 'perakende.destek@ozdilek.com.tr'.

CLASS lcl_technical DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS:
      escape_html
        IMPORTING iv_str         TYPE string
        RETURNING VALUE(rv_html) TYPE string,
      send_html_mail
        IMPORTING
          iv_html    TYPE string
          iv_subject TYPE so_obj_des
          iv_to      TYPE ad_smtpadr OPTIONAL.

ENDCLASS.
