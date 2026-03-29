*&---------------------------------------------------------------------*
*&  Include           ZOR_RT_CASH_TRANSFER_D01
*&---------------------------------------------------------------------*


CLASS lcl_file_interface DEFINITION.

  PUBLIC SECTION.

    CONSTANTS: connection_name TYPE dbcon-con_name VALUE 'GENIUS3'.

    DATA: connection_ref TYPE REF TO cl_sql_connection.

    DATA: export_logs  TYPE TABLE OF gsty_export_log,
          receipt_list TYPE TABLE OF gsty_header,
          transactions TYPE TABLE OF gsty_trns,
          temp_list    TYPE TABLE OF gsty_header,
          gt_seller    TYPE gsty_receipt-seller,
          gt_store     TYPE gsty_receipt-store,
          gt_pos       TYPE gsty_receipt-pos,
          gt_user      TYPE gsty_receipt-user,
          gt_reason    TYPE gsty_receipt-reason,
          gt_campaign  TYPE gsty_receipt-campaign.

    CLASS-METHODS:
    handle_sql_exception
        IMPORTING p_context TYPE csequence
               p_sqlerr_ref TYPE REF TO cx_sql_exception.

    METHODS:

      db_connection
        EXCEPTIONS connection_failed,

      db_disconnection,

      get_receipt_list
        IMPORTING header_type  TYPE char35
        EXPORTING v_export_log TYPE tt_export_log,

      get_receipts
        EXPORTING receipts TYPE tt_receipts,

      get_header
        IMPORTING receipt_id TYPE csequence
        EXPORTING header     TYPE gsty_header,

      get_temp
        IMPORTING receipt_id TYPE csequence
        EXPORTING temp       TYPE gsty_header,

      get_sale
        IMPORTING receipt_id TYPE gsty_header-id
        EXPORTING sale       TYPE gsty_receipt-sale,

      get_sale_cancel
        IMPORTING receipt_id TYPE gsty_header-id
        EXPORTING sale       TYPE gsty_receipt-sale_cancel,

      get_payment
        IMPORTING receipt_id TYPE gsty_header-id
        EXPORTING payment    TYPE gsty_receipt-payment,

      get_discount
        IMPORTING receipt_id TYPE gsty_header-id
        EXPORTING discount   TYPE gsty_receipt-discount,

      get_discount_detail
        IMPORTING receipt_id      TYPE gsty_header-id
        EXPORTING discount_detail TYPE gsty_receipt-discount_detail,

      get_result
        IMPORTING receipt_id TYPE gsty_header-id
        EXPORTING result     TYPE gsty_receipt-result,

      get_payment_types
        EXPORTING payment_types TYPE tt_payment_types,

      get_customer
        IMPORTING customer_id TYPE gsty_header-fk_customer
        EXPORTING customer    TYPE gsty_receipt-customer ,

      get_customer_extension
        IMPORTING customer_id TYPE gsty_header-fk_customer
        EXPORTING customer_ex TYPE gsty_receipt-customer_ex ,

      check_date
        IMPORTING date TYPE gsty_receipt-header-trans_date
        CHANGING  save TYPE xfeld,

      get_table
        IMPORTING table TYPE char30
                  id    TYPE string
        EXPORTING desc  TYPE STANDARD TABLE,

      get_table_id
        IMPORTING table TYPE char30
                  id    TYPE string
        EXPORTING desc  TYPE STANDARD TABLE,


      update_db
        RETURNING VALUE(ep_done) TYPE xfeld,

      delete_db
        RETURNING VALUE(ep_done) TYPE xfeld,

      get_report
        EXPORTING report TYPE tt_zreport.


ENDCLASS.

CLASS lcl_pipe_inbound DEFINITION.

  PUBLIC SECTION.

    CLASS-METHODS:

      class_constructor.

    METHODS:

      populate_bapi_from_go,

      add_extension
        IMPORTING group            TYPE /posdw/fieldgroup
                  field            TYPE /posdw/fieldname
                  value            TYPE string
        RETURNING VALUE(extension) TYPE /posdw/tt_extensions ,

      add_header_ex
        IMPORTING header           TYPE gsty_receipt-header
        RETURNING VALUE(extension) TYPE /posdw/tt_extensions,


      rkd_word_wrap
        IMPORTING textline  TYPE char256
                  outputlen TYPE int4
        EXPORTING out_lines TYPE out_line ,

      call_bapi
        RETURNING VALUE(ep_done) TYPE xfeld.

  PRIVATE SECTION.

    CLASS-DATA:

      currency TYPE /posdw/prof-profilecurrency,
      o_aggr   TYPE REF TO zcl_exchange_aggregation.

    DATA:
      go_file       TYPE tt_receipts,
      go_report     TYPE tt_zreport,
      trans         TYPE /posdw/tt_transaction_int,
      payment_types TYPE tt_payment_types.

    CLASS-METHODS:

      collect_discount
        IMPORTING
          it_discount        TYPE /posdw/tt_discount
          is_discount        TYPE /posdw/discount
        RETURNING
          VALUE(et_discount) TYPE /posdw/tt_discount,

      check_queue
        IMPORTING
          ip_timestamp TYPE /posdw/tibq-timestamp
          it_trans     TYPE /posdw/tt_transaction_int
        RETURNING
          VALUE(et_del) TYPE /posdw/tt_tibqrecord_head,

      delete_tibq
        IMPORTING
          it_del TYPE /posdw/tt_tibqrecord_head.

ENDCLASS.

DATA: go_interface    TYPE REF TO lcl_file_interface,
      go_pipe_inbound TYPE REF TO lcl_pipe_inbound.
