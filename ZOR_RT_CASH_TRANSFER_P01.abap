*&---------------------------------------------------------------------*
*&  Include           ZOR_RT_CASH_TRANSFER_P01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&  Include           ZOR_RT_CASH_TRANSFER_P01
*&---------------------------------------------------------------------*
CLASS lcl_file_interface IMPLEMENTATION.

  METHOD handle_sql_exception.
    "---------------------------------------------------------------------"
    "  Write appropriate error messages when a SQL exception has occured
    "---------------------------------------------------------------------"
    "  -->  P_SQLERR_REF  reference to a CX_SQL_EXCEPTION object
    "---------------------------------------------------------------------"
    IF p_sqlerr_ref->db_error = 'X'.
      PERFORM log_msg USING 'E' 'ZOR_RT' '006' p_sqlerr_ref->sql_code p_context
                            '' '' gv_handle.
      DATA(msg) = CONV char200( p_sqlerr_ref->sql_message ).
      PERFORM log_msg USING 'E' 'ZOR_RT' '000' msg(50)     msg+50(50)
                                               msg+100(50) msg+150(50)
                                               gv_handle.
    ELSE.
      PERFORM log_msg USING 'E' 'ZOR_RT' '007' p_context '' '' '' gv_handle.
      msg = CONV char200( p_sqlerr_ref->internal_error ).
      PERFORM log_msg USING 'E' 'ZOR_RT' '000' msg(50)     msg+50(50)
                                               msg+100(50) msg+150(50)
                                               gv_handle.
    ENDIF.
  ENDMETHOD.

  METHOD db_connection.

    DATA: lr_root TYPE REF TO cx_root,
          lv_msg  TYPE string.

    TRY .
        connection_ref = cl_sql_connection=>get_connection(
        connection_name ).
      CATCH cx_root INTO lr_root.
        MESSAGE 'genius open veri tabanına bağlantı kurulamadı' TYPE 'E'
        .
    ENDTRY.

  ENDMETHOD.

  METHOD db_disconnection.

    connection_ref->close( ).

  ENDMETHOD.

  METHOD get_receipt_list.

    CONSTANTS: c_tabname(30) VALUE 'V_EXPORT_LOG'.
    DATA: operation_type(3).
    DATA : lv_id TYPE c LENGTH 20.
    DATA : lv_desc TYPE c LENGTH 30.
    DATA : lv_limit TYPE i.

*    lv_id = p_id.
    lv_limit = p_limit.
    lv_desc   = header_type.
*    lv_id = '21151100000015 '.
*- Create query string
    DATA(l_stmt) =
  `SELECT TOP ` && lv_limit &&
  ` ID,FK_EXPORT_TABLE_DEFINITION,DESCRIPTION,RECORD_ID  FROM ` &&
     c_tabname &&
     ` with ( nolock )` && ` WHERE OPERATION_TYPE = ? AND DESCRIPTION = ? `.  "" ""AND RECORD_ID = ? `.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).


*- Create statement object
*- Bind input variable
    l_stmt_ref->set_param( REF #( operation_type ) ).
    l_stmt_ref->set_param( REF #( lv_desc ) ).
*****    l_stmt_ref->set_param( REF #( lv_id ) ).



    operation_type = 'I'.
*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( l_stmt ).

*- Get output table
    l_res_ref->set_param_table( REF #( v_export_log ) ).
    DATA(l_row_cnt) = l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.

  METHOD get_receipts.

    DATA: ls_export_log    TYPE gsty_export_log,
          ls_receipt       TYPE gsty_receipt,
          ls_seller        TYPE gsty_receipt-seller,
          ls_reason        TYPE gsty_receipt-reason,
          ls_campaign      TYPE gsty_receipt-campaign,
          lt_campaign      TYPE gsty_receipt-reason,
          ls_discount_reas TYPE gsty_receipt-discount_reas,
          lss_disc         TYPE LINE OF gsty_receipt-discount_reas,
          lt_discount_reas TYPE gsty_receipt-reason,
          lt_dis           TYPE tt_reason,
          lv_save          TYPE xfeld.


    IF p_satis EQ abap_true .
      go_interface->get_receipt_list(
        EXPORTING header_type  = 'TRANSACTION_HEADER'
        IMPORTING v_export_log = export_logs ).
    ELSE.
      go_interface->get_receipt_list(
      EXPORTING header_type  = 'TRANSACTION_HEADER_TEMP'
      IMPORTING v_export_log = export_logs ).
    ENDIF.

    LOOP AT export_logs INTO ls_export_log.
      id = ls_export_log-record_id.
*- Get Header
      IF p_satis EQ abap_true .
        gv_er = 'header'.
        go_interface->get_header(
          EXPORTING
            receipt_id = ls_export_log-record_id
          IMPORTING
            header     = ls_receipt-header ).

        APPEND ls_receipt-header TO me->receipt_list.
      ENDIF.
* Get Transaction_header_temp
      IF p_aski EQ abap_true.
        gv_er = 'temp'.
        go_interface->get_temp(
        EXPORTING
          receipt_id = ls_export_log-record_id
        IMPORTING
          temp     = ls_receipt-temp ).

        APPEND ls_receipt-temp   TO me->receipt_list.
        MOVE-CORRESPONDING ls_receipt-temp TO ls_receipt-header.
      ENDIF .
* Get Customer
      gv_er = 'customer'.
      go_interface->get_customer(
        EXPORTING
         customer_id = ls_receipt-header-fk_customer
         IMPORTING
         customer    = ls_receipt-customer ).

*      Get Store Desc
      READ TABLE gt_store INTO DATA(ls_store)
                        WITH KEY id = ls_receipt-header-fk_store.
      IF sy-subrc NE 0.
        gv_er = 'store'.
        go_interface->get_table(
        EXPORTING table = 'STORE'
                  id    = ls_receipt-header-fk_store
        IMPORTING desc  = ls_receipt-store  ).

        APPEND LINES OF ls_receipt-store TO me->gt_store.
      ELSE.
        APPEND ls_store TO ls_receipt-store.
      ENDIF.
*   Get Pos Desc
      READ TABLE gt_pos INTO DATA(ls_pos)
                        WITH KEY id = ls_receipt-header-fk_pos.
      IF sy-subrc NE 0.
        gv_er = 'pos'.
        go_interface->get_table(
        EXPORTING table = 'POS'
                  id    = ls_receipt-header-fk_pos
        IMPORTING desc  = ls_receipt-pos  ).

        APPEND LINES OF ls_receipt-pos TO me->gt_pos.
      ELSE.
        APPEND ls_pos TO ls_receipt-pos.
      ENDIF.
*   Get User Desc
      READ TABLE gt_user INTO DATA(lss_user)
                           WITH  KEY id = ls_receipt-header-fk_user.
      IF sy-subrc NE 0 .
        gv_er = 'user'.
        go_interface->get_table(
        EXPORTING table = 'USERS'
                  id    = ls_receipt-header-fk_user
        IMPORTING desc  = ls_receipt-user  ).

        APPEND LINES OF ls_receipt-user TO me->gt_user.
      ELSE.
        APPEND lss_user TO ls_receipt-user.
      ENDIF.

* Get Customer Extension
      gv_er = 'cust_ex'.
      go_interface->get_customer_extension(
        EXPORTING
         customer_id = ls_receipt-header-fk_customer
         IMPORTING
         customer_ex    = ls_receipt-customer_ex ).

*- Get Sale
      gv_er = 'sale'.
      go_interface->get_sale(
        EXPORTING
          receipt_id = ls_receipt-header-id
        IMPORTING
          sale       = ls_receipt-sale ).

      LOOP AT ls_receipt-sale INTO DATA(ls_sale).
*   Get Seller
        REFRESH : ls_seller,ls_reason.
        READ TABLE gt_seller INTO DATA(lss_seller)
                             WITH  KEY id = ls_sale-fk_seller.
        IF sy-subrc NE 0 .
          gv_er = 'seller'.
          go_interface->get_table(
          EXPORTING table = 'SELLER'
                    id    = ls_sale-fk_seller
          IMPORTING desc  = ls_seller  ).

          APPEND LINES OF ls_seller TO me->gt_seller.
        ELSE.
          APPEND lss_seller TO ls_seller.
        ENDIF.
*  Get Reason
        READ TABLE gt_reason INTO DATA(lss_reason)
                           WITH  KEY id = ls_sale-fk_return_reason.
        IF sy-subrc NE 0 .
          gv_er = 'return reason'.
          go_interface->get_table(
          EXPORTING table = 'RETURN_REASON'
                    id    = ls_sale-fk_return_reason
          IMPORTING desc  = ls_reason  ).

          APPEND LINES OF ls_reason TO me->gt_reason.
        ELSE.
          APPEND lss_reason TO ls_reason.
        ENDIF.

        APPEND LINES OF ls_seller  TO ls_receipt-seller.
        APPEND LINES OF ls_reason  TO ls_receipt-reason.
      ENDLOOP.
*- Get Sale Cancel
      gv_er = 'sale cancel'.
      go_interface->get_sale_cancel(
        EXPORTING
          receipt_id = ls_receipt-header-id
        IMPORTING
          sale       = ls_receipt-sale_cancel ).

*- Get Payment
      gv_er = 'payment'.
      go_interface->get_payment(
        EXPORTING
        receipt_id = ls_receipt-header-id
        IMPORTING
          payment  = ls_receipt-payment ).

*- Get Discount
      gv_er = 'discount'.
      go_interface->get_discount(
        EXPORTING
          receipt_id = ls_receipt-header-id
        IMPORTING
          discount   = ls_receipt-discount ).

      LOOP AT ls_receipt-discount INTO DATA(ls_discount).

        REFRESH : ls_campaign,ls_discount_reas,lt_discount_reas,lt_campaign.
* Get Campaign
        READ TABLE gt_campaign INTO DATA(lss_campaign)
                             WITH KEY id = ls_discount-fk_campaign.
        IF sy-subrc NE 0.
          gv_er = 'campaign'.
          go_interface->get_table(
          EXPORTING table = 'CAMPAIGN'
                    id    = ls_discount-fk_campaign
          IMPORTING desc  = lt_campaign  ).
          LOOP AT lt_campaign INTO DATA(ls_camp).
            CLEAR : lss_campaign.
            lss_campaign-id = ls_camp-id.
            lss_campaign-description = ls_camp-description.
            lss_campaign-parent_line = ls_discount-parent_line.
            APPEND lss_campaign TO me->gt_campaign.
          ENDLOOP.
*          APPEND LINES OF ls_campaign TO me->gt_campaign.
        ELSE.
          APPEND lss_campaign TO ls_campaign.
        ENDIF.
* Get Discount Reason
        gv_er = 'dis_reas'.
        go_interface->get_table(
        EXPORTING table = 'DISCOUNT_REASON'
                  id    = ls_discount-fk_discount_reason
        IMPORTING desc  = lt_discount_reas  ).

        APPEND LINES OF ls_campaign  TO ls_receipt-campaign.
*        APPEND LINES OF ls_discount_reas  TO ls_receipt-discount_reas.
        LOOP AT lt_discount_reas INTO DATA(ls_discc_reas).
          CLEAR : lss_disc.
          lss_disc-id = ls_discc_reas-id.
          lss_disc-description = ls_discc_reas-description.
          lss_disc-parent_line = ls_discount-parent_line.
          APPEND lss_disc TO ls_receipt-discount_reas.
        ENDLOOP.
      ENDLOOP.

*- Get Discount Detail
      gv_er = 'dis_detail'.
      go_interface->get_discount_detail(
        EXPORTING
          receipt_id = ls_receipt-header-id
        IMPORTING
          discount_detail   = ls_receipt-discount_detail ).

*- Get Result
      gv_er = 'result'.
      go_interface->get_result(
         EXPORTING
           receipt_id = ls_receipt-header-id
         IMPORTING
           result     = ls_receipt-result ).


      go_interface->get_table_id(
        EXPORTING table = 'TRANSACTION_PAYMENT_EFT_POS'
          id    = ls_receipt-header-id
        IMPORTING desc  = ls_receipt-eft  ).

      IF ls_receipt IS NOT INITIAL AND ls_receipt-header IS NOT INITIAL .

        APPEND ls_receipt TO receipts.
        CLEAR: ls_receipt.

      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_header.

    DATA : lv_id TYPE c LENGTH 20.
    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_HEADER'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,FK_STORE,FK_POS,TRANS_DATE,` &&
    `FK_USER,RECEIPT_BARCODE ,PTYPE ,STATUS ,DOCUMENT_NO,CUSTOMER_CODE,`
    &&
    `ADDRESS_ON_DOC ,NAME_ON_DOC , NUM , ` &&
    `GROSS_TOTAL,GROSS_VAT_TOTAL ,DISCOUNT_ON_TOTAL,` &&
    `DISCOUNT_ON_LINES , ROUNDING_TOTAL,`
    &&
    `TAXFREE_REFUND_TOTAL,CUSTOM_TEXT,VOID_DESCRIPTION,OPTION_BITFLAG,`
    && `FK_CUSTOMER`
    &&
     ` FROM ` &&
     c_tabname  && ` with ( nolock )` && ` WHERE ID = ? `.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_struct( REF #( header ) ).
    l_res_ref->next( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.

  METHOD get_temp.

    DATA : lv_id TYPE c LENGTH 20.
    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_HEADER_TEMP'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,FK_STORE,FK_POS,TRANS_DATE,` &&
    `FK_USER,RECEIPT_BARCODE ,PTYPE ,STATUS ,DOCUMENT_NO,CUSTOMER_CODE,`
    &&
    `ADDRESS_ON_DOC ,NAME_ON_DOC , NUM , ` &&
    `GROSS_TOTAL,GROSS_VAT_TOTAL ,DISCOUNT_ON_TOTAL,` &&
    `DISCOUNT_ON_LINES , ROUNDING_TOTAL,`
    &&
    `TAXFREE_REFUND_TOTAL,CUSTOM_TEXT,VOID_DESCRIPTION,OPTION_BITFLAG,`
    && `FK_CUSTOMER`
    &&
     ` FROM ` &&
     c_tabname  && ` with ( nolock )` && ` WHERE ID = ? `.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_struct( REF #( temp ) ).
    l_res_ref->next( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.


  METHOD get_sale.

    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_SALE'.

    DATA: query_string TYPE string.
    DATA : lv_id TYPE c LENGTH 20.
*- Create query string
    query_string =
    `SELECT ID,LINE_NO,STATUS,VAT_PERCENT,AMOUNT,FK_UNIT , ` &&
    `TOTAL_PRICE,VAT_TOTAL,BARCODE,CODE,SALE_TYPE , FK_SELLER , FK_RETURN_REASON FROM ` &&
     c_tabname &&  ` with ( nolock ) ` &&
     ` WHERE FK_TRANSACTION_HEADER = ? `.
    .
*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( sale ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.

  METHOD get_sale_cancel.

    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_SALE_CANCEL'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,LINE_NO,STATUS,VAT_PERCENT,AMOUNT,FK_UNIT,` &&
    `TOTAL_PRICE,VAT_TOTAL,BARCODE, CODE ,SALE_TYPE ,FK_SELLER ,FK_RETURN_REASON FROM ` &&
     c_tabname && ` with ( nolock )` &&
     ` WHERE FK_TRANSACTION_HEADER = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( sale ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.
  METHOD get_payment_types.
    CONSTANTS: c_tabname(30) VALUE 'PAYMENT_TYPE'.

    DATA: query_string    TYPE string,
          ls_payment_type TYPE gsty_payment_type-id.

    query_string =
  `SELECT ID,NUM FROM ` &&
   c_tabname && ` with ( nolock )` && ` WHERE ID <> ?`.


*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    l_stmt_ref->set_param( REF #( ls_payment_type ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( payment_types ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).


  ENDMETHOD.
  METHOD get_payment.

    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_PAYMENT'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,STATUS,FK_PAYMENT_TYPE,PAYMENT_TYPE,PAYMENT_TYPE_DETAIL,` &&
    `PAYMENT_TOTAL,CURRENCY_TOTAL,CUSTOM_TEXT,SERIAL_NO FROM ` &&
     c_tabname &&
     ` with ( nolock )` && ` WHERE FK_TRANSACTION_HEADER = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).
*    l_stmt_ref->set_param( REF #( receipt_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( payment ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.

  METHOD get_discount.

    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_DISCOUNT'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,LINE_NO,PARENT_LINE,DISCOUNT_TYPE,` &&
    `DISCOUNT_CODE,AMOUNT,PARAMETER_2 , FK_CAMPAIGN  ,FK_DISCOUNT_REASON FROM ` &&
     c_tabname && ` with ( nolock )` &&
     ` WHERE FK_TRANSACTION_HEADER = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).
*    l_stmt_ref->set_param( REF #( receipt_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( discount ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.

  METHOD get_discount_detail.

    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_DISCOUNT_DETAIL'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,FK_TRANSACTION_HEADER,` &&
    `FK_TRANSACTION_SALE,FK_TRANSACTION_DISCOUNT, AMOUNT FROM ` &&
     c_tabname && ` with ( nolock )` &&
     ` WHERE FK_TRANSACTION_HEADER = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).
*    l_stmt_ref->set_param( REF #( receipt_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( discount_detail ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).
  ENDMETHOD.

  METHOD get_result.
    CONSTANTS: c_tabname(30) VALUE 'TRANSACTION_RESULT'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,FK_TRANSACTION_HEADER,` &&
    `PARAMETER_1 , PARAMETER_2 , PARAMETER_3 ,CODE ,TYPE  FROM ` &&
     c_tabname && ` with ( nolock )` &&
     ` WHERE FK_TRANSACTION_HEADER = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = receipt_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( result ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).
  ENDMETHOD.

  METHOD get_customer.
    CONSTANTS: c_tabname(30) VALUE 'CUSTOMER'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,CODE ,NAME ,TC_IDENTITY_NO FROM ` &&
     c_tabname && ` with ( nolock )` &&
     ` WHERE ID  = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = customer_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( customer ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).

  ENDMETHOD.

  METHOD get_customer_extension.
    CONSTANTS: c_tabname(30) VALUE 'CUSTOMER_EXTENSION'.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT ID,FK_CUSTOMER ,TAX_OFFICE ,TAX_NUMBER ,` &&
    `ADDRESS_LETTER,CELL_PHONE FROM ` &&
     c_tabname && ` with ( nolock )` &&
     ` WHERE ID  = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = customer_id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( customer_ex ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).


  ENDMETHOD.

  METHOD get_table.

    DATA: t_9955_fields TYPE abap_compdescr_tab,
          w_9955_fields TYPE LINE OF abap_compdescr_tab.
    DATA : l_descr_ref TYPE REF TO cl_abap_structdescr,
           lv_string   TYPE string.

    APPEND INITIAL LINE TO desc .
    READ TABLE desc ASSIGNING FIELD-SYMBOL(<fs_desc>) INDEX 1.

    l_descr_ref ?= cl_abap_typedescr=>describe_by_data( <fs_desc> ).
    t_9955_fields = l_descr_ref->components.

    DELETE desc INDEX 1.

    LOOP AT t_9955_fields INTO w_9955_fields.
      IF sy-tabix EQ 1.
        CONCATENATE w_9955_fields-name '' INTO lv_string.
      ELSE.
        CONCATENATE lv_string w_9955_fields-name INTO lv_string
        SEPARATED BY ','.
      ENDIF.
    ENDLOOP.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT `
    && lv_string &&
     ` FROM ` && table && ` with ( nolock )` &&
     ` WHERE ID  = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = table ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( desc ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).


  ENDMETHOD.


  METHOD get_table_id.

    DATA: t_9955_fields TYPE abap_compdescr_tab,
          w_9955_fields TYPE LINE OF abap_compdescr_tab.
    DATA : l_descr_ref TYPE REF TO cl_abap_structdescr,
           lv_string   TYPE string.

    APPEND INITIAL LINE TO desc .
    READ TABLE desc ASSIGNING FIELD-SYMBOL(<fs_desc>) INDEX 1.

    l_descr_ref ?= cl_abap_typedescr=>describe_by_data( <fs_desc> ).
    t_9955_fields = l_descr_ref->components.

    DELETE desc INDEX 1.

    LOOP AT t_9955_fields INTO w_9955_fields.
      IF sy-tabix EQ 1.
        CONCATENATE w_9955_fields-name '' INTO lv_string.
      ELSE.
        CONCATENATE lv_string w_9955_fields-name INTO lv_string
        SEPARATED BY ','.
      ENDIF.
    ENDLOOP.

    DATA: query_string TYPE string.

*- Create query string
    query_string =
    `SELECT `
    && lv_string &&
     ` FROM ` && table && ` with ( nolock )` &&
     ` WHERE FK_TRANSACTION_HEADER  = ?`.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = table ).

*- Bind input variable
    DATA : lv_id TYPE c LENGTH 20.
    lv_id = id.
    l_stmt_ref->set_param( REF #( lv_id ) ).

*- Execute query
    DATA(l_res_ref) = l_stmt_ref->execute_query( query_string ).

*- Get Output table
    l_res_ref->set_param_table( REF #( desc ) ).
    l_res_ref->next_package( ).

*- Close statement
    l_res_ref->close( ).


  ENDMETHOD.


  METHOD check_date.
  ENDMETHOD.

  METHOD update_db.

    CONSTANTS: c_tabname(30) VALUE 'EXPORT_LOG'.
    DATA: "ls_receipt   TYPE gsty_header,
          query_string TYPE string.
    DATA: lv_operation_type TYPE c LENGTH 3,
          lv_record_id      TYPE c LENGTH 20.
    DATA : lt_log     TYPE TABLE OF zor_cash_id,
           ls_log     LIKE LINE OF lt_log,
           lv_message TYPE bapiret2-message.

*- Create query string
*    query_string = `UPDATE ` && c_tabname &&
*    ` SET OPERATION_TYPE = ? WHERE RECORD_ID = ?` ##no_text.
    query_string = `update EXPORT_LOG set OPERATION_TYPE = ? WHERE RECORD_ID = ? `.
*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

    LOOP AT me->transactions ASSIGNING FIELD-SYMBOL(<ls_trns>).

*- Bind input variable
      l_stmt_ref->set_param( REF #( <ls_trns>-operationtype ) ).
      l_stmt_ref->set_param( REF #( lv_record_id ) ).

*      lv_operation_type = 'Z'.
      lv_record_id = <ls_trns>-id.

*- Execute query
      TRY.
          DATA(l_row_cnt) = l_stmt_ref->execute_update( query_string ).
        CATCH cx_root INTO DATA(lo_root).
          MESSAGE e004(zor_rt) WITH <ls_trns>-id INTO lv_message.
*   & nolu işlem için EXPORT_LOG güncellemesinde hata
          WRITE / lv_message.
          CONTINUE.
      ENDTRY.

      CLEAR ls_log.
      ls_log-trans_date = <ls_trns>-businessdaydate.
      ls_log-id =  <ls_trns>-id.
      APPEND ls_log TO lt_log.

    ENDLOOP.

    IF lt_log[] IS NOT INITIAL .
      MODIFY zor_cash_id FROM TABLE lt_log.
    ENDIF.
*
*    WRITE: 'Çekilen fişlerin operasyon tipleri Z ile güncellendi'.
  ENDMETHOD.
  METHOD delete_db .
    CONSTANTS: c_tabname(30) VALUE 'EXPORT_LOG'.
    DATA: ls_receipt   TYPE gsty_header,
          query_string TYPE string.
    DATA: lv_operation_type,
          lv_record_id TYPE c LENGTH 20.

    DATA : lt_log TYPE TABLE OF zor_cash_id,
           ls_log LIKE LINE OF lt_log.

*- Create query string
    query_string = `DELETE FROM ` && c_tabname &&
    ` WHERE  RECORD_ID = ?` ##no_text.

*- Create statement object
    DATA(l_stmt_ref) = connection_ref->create_statement(
    tab_name_for_trace = c_tabname ).

    LOOP AT me->receipt_list INTO ls_receipt.
      l_stmt_ref->set_param( REF #( lv_record_id ) ).
      lv_record_id = ls_receipt-id.
      DATA(l_row_cnt) = l_stmt_ref->execute_update( query_string ).
      CLEAR ls_log.
      READ TABLE gt_log INTO gs_log WITH KEY id = ls_receipt-id.
      IF sy-subrc NE 0 .
        ls_log-trans_date =   ls_receipt-trans_date(4) &&
                              ls_receipt-trans_date+5(2) &&
                              ls_receipt-trans_date+8(2).

        ls_log-id         =  ls_receipt-id.
        ls_log-statu      =  ls_receipt-status.
        APPEND ls_log TO lt_log.
      ENDIF.
    ENDLOOP .

    IF lt_log[] IS NOT INITIAL .
      MODIFY zor_cash_id FROM TABLE lt_log.
    ENDIF.
**- Execute query
  ENDMETHOD.

  METHOD get_report.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_pipe_inbound IMPLEMENTATION.

  METHOD class_constructor.

    SELECT SINGLE profilecurrency
      FROM  /posdw/prof
      INTO lcl_pipe_inbound=>currency
     WHERE  profiletype  = 'OZD1'.


  ENDMETHOD.

  METHOD populate_bapi_from_go.

    DATA: ls_go              LIKE LINE OF me->go_file,
          ls_sale            LIKE LINE OF ls_go-sale,
          ls_sale_cancel     LIKE LINE OF ls_go-sale_cancel,
          ls_payment         LIKE LINE OF ls_go-payment,
          ls_payment_type    LIKE LINE OF me->payment_types,
          ls_discount_go     LIKE LINE OF ls_go-discount,
          ls_discount_detail LIKE LINE OF ls_go-discount_detail,
          ls_trans           LIKE LINE OF me->trans,
          lt_extensions      LIKE         ls_trans-extensions,
          lt_ex              LIKE         ls_trans-extensions,
          ls_retail          LIKE LINE OF ls_trans-retaillineitem,
          ls_discount        LIKE LINE OF ls_trans-discount,
          lt_dis_ex          LIKE         ls_discount-extensions,
          ls_dis_ex          LIKE LINE OF lt_dis_ex,
          ls_result          LIKE LINE OF ls_go-result,
          ls_rdisc           LIKE LINE OF ls_retail-discount,
          ls_tax             LIKE LINE OF ls_retail-tax,
          ls_tender          LIKE LINE OF ls_trans-tender,
          ls_ext             LIKE LINE OF ls_tender-extensions,
          lt_retailext       LIKE         ls_retail-extensions,
          ls_retailext       LIKE LINE OF ls_retail-extensions,
          ls_customer        LIKE LINE OF ls_go-customer,
          ls_customer_ex     LIKE LINE OF ls_go-customer_ex,
          lt_cart            TYPE /posdw/tt_creditcard,
          ls_cart            LIKE LINE OF lt_cart,
          lv_line_exist      TYPE abap_bool,
          lv_payment_exist   TYPE abap_bool,


          lv_date            TYPE c LENGTH 10,
          lv_time            TYPE c LENGTH 8,
          lv_date_i          TYPE c LENGTH 8,
          lv_noon            TYPE c LENGTH 2,
          lv_time_i          TYPE c LENGTH 6,
          lv_tmp1            TYPE c LENGTH 40,
          lv_tmp2            TYPE c LENGTH 40,
          lv_tmp3            TYPE c LENGTH 40,
          lv_tmp4            TYPE c LENGTH 80,
          lv_tmp5            TYPE c LENGTH 80,
          lv_tabix           TYPE sy-tabix,
          ls_cust            LIKE LINE OF ls_trans-customerdetails,
          lt_cust            LIKE ls_trans-customerdetails,
          lv_dec             TYPE p DECIMALS 2,
          lv_discountid      TYPE c LENGTH 32,
          lv_matl_type       TYPE /bi0/oimatl_type,
          lv_line_exit       TYPE abap_bool,
          lv_discr           TYPE string,
          lv_camp            TYPE string,
          lv_amount          TYPE c LENGTH 6.

*
*    IF p_z EQ abap_true .
*
*
*    ENDIF.

*    CHECK p_z IS INITIAL.

    CREATE OBJECT o_aggr.
    TRY.
*        *- Fişleri Çek
        go_interface->get_receipts(
          IMPORTING receipts = me->go_file ).


*- Get Payment Type
        CHECK me->go_file[] IS NOT INITIAL.
        DO 2 TIMES.
          go_interface->get_payment_types(
            IMPORTING
              payment_types = me->payment_types ).
          IF me->payment_types IS INITIAL.
            WAIT UP TO 1 SECONDS.
          ELSE.
            EXIT.
          ENDIF.
        ENDDO.

      CATCH cx_sql_exception INTO DATA(lo_sql_exc).
        lcl_file_interface=>handle_sql_exception( p_context    = ''
                                                  p_sqlerr_ref = lo_sql_exc ).
      CATCH cx_root INTO gr_root.
        CLEAR: gv_text.
        gv_text = gr_root->get_text( ).
        gv_text = id && '' && gv_er && gv_text.

        WRITE: gv_text.
    ENDTRY.

    IF me->payment_types IS INITIAL.
      LEAVE PROGRAM.
    ENDIF.

    LOOP AT me->go_file INTO ls_go.
      TRY .
*      IF ls_go-header-status NE '1'.
          id = ls_go-header-id.
          gv_er = ''.
*- Başlık verileri
          SPLIT ls_go-header-trans_date AT space INTO lv_date lv_time
          lv_noon.

          ls_trans-businessdaydate = lv_date+0(4) && lv_date+5(2) &&
                                     lv_date+8(2).

          lv_time_i = lv_time(2) && lv_time+3(2) && lv_time+6(2).

          ls_trans-transnumber = ls_go-header-receipt_barcode.
          CONDENSE ls_trans-transnumber.

          CLEAR: ls_trans-retailstoreid, ls_trans-workstationid.

          SELECT SINGLE werks sappos FROM  zor_plants
            INTO (ls_trans-retailstoreid,ls_trans-workstationid)
                 WHERE  kasa_tip  = '101'
                 AND    store     = ls_go-header-fk_store
                 AND    pos       = ls_go-header-fk_pos.

          IF ls_trans-retailstoreid IS INITIAL.
            ls_trans-retailstoreid = ls_go-header-fk_store.
          ENDIF.
          IF ls_trans-workstationid IS INITIAL.
            ls_trans-workstationid = ls_go-header-fk_pos.
          ENDIF.

          DATA(lv_retailstoreid) = CONV /posdw/tlogf-retailstoreid( |{ ls_trans-retailstoreid ALPHA = IN }| ).
          DATA(lv_workstationid) = CONV /posdw/tlogf-workstationid( |{ ls_trans-workstationid ALPHA = IN }| ).

          SELECT @abap_true FROM  /posdw/tlogf UP TO 1 ROWS INTO @DATA(lv_exists)
                 WHERE  retailstoreid    = @lv_retailstoreid
                 AND    businessdaydate  = @ls_trans-businessdaydate
                 AND    workstationid    = @lv_workstationid
                 AND    transnumber      = @ls_trans-transnumber
                 AND    recordqualifier  = 1.
          ENDSELECT.
          IF sy-subrc = 0.
            APPEND INITIAL LINE TO go_interface->transactions
            ASSIGNING FIELD-SYMBOL(<ls_trns>).
            <ls_trns>-id              = ls_go-header-id.
            <ls_trns>-retailstoreid   = ls_trans-retailstoreid.
            <ls_trns>-businessdaydate = ls_trans-businessdaydate.
            <ls_trns>-operationtype   = 'M'.

            CLEAR ls_trans.
            CONTINUE.
          ENDIF.

*        extension
          lt_ex = me->add_header_ex( EXPORTING header = ls_go-header ).

          APPEND LINES OF lt_ex TO lt_extensions.
          REFRESH : lt_ex.

          LOOP AT ls_go-discount_reas INTO DATA(ls_dis_reas) WHERE  parent_line EQ '0' .
            lt_ex = me->add_extension( EXPORTING group = 'DISC'
                                                 field = 'ID'
                                                 value = ls_dis_reas-id ).

            APPEND LINES OF lt_ex TO lt_extensions.
            REFRESH : lt_ex.

            lt_ex = me->add_extension( EXPORTING group = 'DISC'
                                                 field = 'DESC'
                                                 value = ls_dis_reas-description ).

            APPEND LINES OF lt_ex TO lt_extensions.
            REFRESH : lt_ex.
          ENDLOOP.

          LOOP AT ls_go-campaign INTO DATA(ls_campaign) WHERE parent_line EQ '0' .
            lt_ex = me->add_extension( EXPORTING group = 'CAMP'
                                                 field = 'ID'
                                                 value = ls_campaign-id ).

            APPEND LINES OF lt_ex TO lt_dis_ex.
            REFRESH : lt_ex.

            lt_ex = me->add_extension( EXPORTING group = 'CAMP'
                                                 field = 'DESC'
                                                 value = ls_campaign-description ).

            APPEND LINES OF lt_ex TO lt_dis_ex.
            REFRESH : lt_ex.
          ENDLOOP.

*          READ TABLE ls_go-store INTO DATA(ls_store) WITH KEY id = ls_go-header-fk_store.
*          IF sy-subrc EQ 0 .
*            ls_ext-fieldgroup = 'STORE'.
*            ls_ext-fieldname  = 'NO'.
*            ls_ext-fieldvalue = ls_store-id.
*            APPEND ls_ext TO lt_extensions.
*
*            lt_ex = me->add_extension( EXPORTING group = 'STORE'
*                                                 field = 'DESC'
*                                                 value = ls_store-description ).
*            APPEND LINES OF lt_ex TO lt_extensions.
*            REFRESH : lt_ex.
*          ENDIF.

*          READ TABLE ls_go-pos INTO DATA(ls_pos) WITH KEY id = ls_go-header-fk_pos.
*          IF sy-subrc EQ 0 .
*            ls_ext-fieldgroup = 'POS'.
*            ls_ext-fieldname  = 'NO'.
*            IF ls_go-header-status EQ '5'.
*              ls_ext-fieldvalue = ls_pos-id && 'A'.
*            ELSE.
*              ls_ext-fieldvalue = ls_pos-id.
*            ENDIF.
*            APPEND ls_ext TO lt_extensions.
*
*            lt_ex = me->add_extension( EXPORTING group = 'POS'
*                                          field = 'DESC'
*                                          value = ls_pos-description ).
*            APPEND LINES OF lt_ex TO lt_extensions.
*            REFRESH : lt_ex.
*          ENDIF.
          READ TABLE ls_go-user INTO DATA(ls_user) WITH KEY id = ls_go-header-fk_user.
          IF sy-subrc EQ 0 .
            ls_ext-fieldgroup = 'USER'.
            ls_ext-fieldname  = 'NO'.
            ls_ext-fieldvalue = ls_user-code.
            APPEND ls_ext TO lt_extensions.

            lt_ex = me->add_extension( EXPORTING group = 'USER'
                                                 field = 'NAME'
                                                 value = ls_user-name ).
            APPEND LINES OF lt_ex TO lt_extensions.
            REFRESH : lt_ex.
          ENDIF.

          CASE ls_go-header-status.
            WHEN '0'.
              CASE ls_go-header-ptype.
                WHEN '0'.  ls_trans-transtypecode = '1001'.  "Fiş.
                WHEN '1'.
                  CASE ls_go-header-option_bitflag.
                    WHEN '256'.  ls_trans-transtypecode = '1003'."efatura
                    WHEN OTHERS. ls_trans-transtypecode = '1004'."earsiv
                  ENDCASE.
                WHEN '4'. ls_trans-transtypecode = '1005'.  "İrsaliye
                WHEN '5'.  ls_trans-transtypecode = '1006'.  "Tax Free
                WHEN '26'. ls_trans-transtypecode = '1007'.  "Yemek Kartı
                WHEN '2'. ls_trans-transtypecode = '9001'. "iade
                WHEN OTHERS.     ls_trans-transtypecode = '1001'. "fİŞ

              ENDCASE.
            WHEN '5'.
              ls_trans-transtypecode = '3003'. "C
              ls_ext-fieldgroup = 'ZRT'.
              ls_ext-fieldname  = 'STATU'.
              ls_ext-fieldvalue = 'ASKIDA'.
              APPEND ls_ext TO lt_extensions.

            WHEN OTHERS.

              ls_trans-transtypecode = '1002'. "C
              ls_ext-fieldgroup = 'ZRT'.
              ls_ext-fieldname  = 'STATU'.
              ls_ext-fieldvalue = 'IPTAL'.
              APPEND ls_ext TO lt_extensions.
          ENDCASE.

*          CASE ls_go-header-status.
*            WHEN '0'.
*              CASE ls_go-header-ptype.
*                WHEN '2'. ls_trans-transtypecode = '9001'. "A
*                WHEN OTHERS.     ls_trans-transtypecode = '1001'. "B
*              ENDCASE.
*            WHEN OTHERS.
*              ls_trans-transtypecode = '1002'. "C
*              ls_ext-fieldgroup = 'ZRT'.
*              ls_ext-fieldname  = 'STATU'.
*              ls_ext-fieldvalue = 'IPTAL'.
*              APPEND ls_ext TO lt_extensions.
*          ENDCASE.

          IF ls_go-header-address_on_doc IS NOT INITIAL.
*            SPLIT ls_go-header-address_on_doc AT '|' INTO lv_tmp4 lv_tmp2
*            ls_trans-partnerid lv_tmp5.
            SPLIT ls_go-header-address_on_doc AT ';' INTO lv_tmp4 lv_tmp2
            ls_trans-partnerid lv_tmp5.
            lv_tmp1 = lv_tmp4(40).
            lv_tmp3 = lv_tmp4+40(40).
            ls_trans-department = ls_go-header-document_no.
            CLEAR lv_tmp4.
          ENDIF.

          IF ls_trans-partnerid IS INITIAL.
            ls_trans-partnerid = ls_go-header-customer_code.
          ENDIF.

          REFRESH lt_cust.
          CLEAR : ls_customer, ls_customer_ex.
          READ TABLE ls_go-customer INTO ls_customer
                                      WITH KEY id = ls_go-header-fk_customer.
          IF sy-subrc EQ 0 .
            CLEAR : ls_cust.
            ls_cust-customerinfotype = 'MUST'.
            ls_cust-dataelementid    = 'MUST_CODE'.
            ls_cust-dataelementvalue = ls_customer-code.
            APPEND ls_cust TO lt_cust.
            ls_cust-customerinfotype = 'MUST'.
            ls_cust-dataelementid    = 'MUST_NAME'.
            ls_cust-dataelementvalue = ls_customer-name.
            APPEND ls_cust TO lt_cust.
            ls_cust-customerinfotype = 'MUST'.
            ls_cust-dataelementid    = 'MUST_TC'.
            ls_cust-dataelementvalue = ls_customer-tc_identity_no.
            APPEND ls_cust TO lt_cust.

          ENDIF.

          LOOP AT ls_go-customer_ex INTO ls_customer_ex WHERE fk_customer = ls_go-header-fk_customer.
            CLEAR : ls_cust.
            ls_cust-customerinfotype = 'MUST'.
            ls_cust-dataelementid    = 'TAX_OFFICE'.
            ls_cust-dataelementvalue = ls_customer_ex-tax_office.
            APPEND ls_cust TO lt_cust.
            ls_cust-customerinfotype = 'MUST'.
            ls_cust-dataelementid    = 'TAX_NUMBER'.
            ls_cust-dataelementvalue = ls_customer_ex-tax_number.
            APPEND ls_cust TO lt_cust.
            ls_cust-customerinfotype = 'MUST'.
            ls_cust-dataelementid    = 'ADRRESS_LE'.
            ls_cust-dataelementvalue = ls_customer_ex-address_letter.
            APPEND ls_cust TO lt_cust.
            ls_cust-customerinfotype = 'MUST'.
            ls_cust-dataelementid    = 'CELL_PHONE'.
            ls_cust-dataelementvalue = ls_customer_ex-cell_phone.
            APPEND ls_cust TO lt_cust.
          ENDLOOP.

*--------------------------------------------------------------------*
* Müşteri adı uzunluğu/depozito geliştirmeleri AVM sisteminde
* canlıya alınacağı zaman bu kısım kapatılıp taşınacak.
* 28.09.2023 Kerem Kayacan

          ls_cust-customerinfotype = 'MUS'.
          ls_cust-dataelementid = 'MUS_ADI'.
          ls_cust-dataelementvalue = ls_go-header-name_on_doc.
          IF ls_go-header-ptype = '26'.
            LOOP AT ls_go-payment INTO ls_payment.
              SELECT SINGLE mus_adi FROM zrt_yemekkart INTO
              ls_go-header-name_on_doc "ls_cust-dataelementvalue
                                    WHERE /bic/oizge_ot =
                                    ls_payment-fk_payment_type.
            ENDLOOP.
          ENDIF.
          APPEND ls_cust TO lt_cust.
          CLEAR ls_cust.

* Müşteri adı uzunluğu/depozito geliştirmeleri AVM sisteminde
* canlıya alınacağı zaman bu kısım kapatılıp taşınacak.
* 28.09.2023 Kerem Kayacan
*--------------------------------------------------------------------*



*--------------------------------------------------------------------*
* Müşteri adı uzunluğu/depozito geliştirmeleri AVM sisteminde
* canlıya alınacağı zaman bu kısım açılıp taşınacak.
* 28.09.2023 Kerem Kayacan

*          IF ls_go-header-ptype = '26'.
*            ls_cust-customerinfotype = 'MUS'.
*            ls_cust-dataelementid = 'MUS_ADI_1'.
*            LOOP AT ls_go-payment INTO ls_payment.
*              SELECT SINGLE mus_adi FROM zrt_yemekkart INTO
*              ls_go-header-name_on_doc "ls_cust-dataelementvalue
*                                    WHERE /bic/oizge_ot =
*                                    ls_payment-fk_payment_type.
*            ENDLOOP.
*            APPEND ls_cust TO lt_cust.
*            CLEAR ls_cust.
*          ELSE.
*            DATA: lt_output_strings   TYPE TABLE OF string,
*                  lv_substring        TYPE string,
*                  lv_offset           TYPE i,
*                  lv_length           TYPE i,
*                  lv_remaining_length TYPE i,
*                  lv_index            TYPE c LENGTH 10.
*            lv_length = strlen( ls_go-header-name_on_doc ).
*            lv_offset = 0.
*            lv_remaining_length = lv_length.
*            WHILE lv_remaining_length > 0.
*              lv_index = sy-index. CONDENSE lv_index.
*              ls_cust-customerinfotype = 'MUS'.
*              ls_cust-dataelementid = 'MUS_ADI_' && lv_index.
*              IF lv_remaining_length >= 40.
*                ls_cust-dataelementvalue = ls_go-header-name_on_doc+lv_offset(40).
*                lv_offset = lv_offset + 40.
*                lv_remaining_length = lv_remaining_length - 40.
*              ELSE.
*                ls_cust-dataelementvalue = ls_go-header-name_on_doc+lv_offset.
*                lv_remaining_length = 0.
*              ENDIF.
*              APPEND ls_cust TO lt_cust.
*              CLEAR ls_cust.
*            ENDWHILE.
*          ENDIF.

* Müşteri adı uzunluğu/depozito geliştirmeleri AVM sisteminde
* canlıya alınacağı zaman bu kısım açılıp taşınacak.
* 28.09.2023 Kerem Kayacan
*--------------------------------------------------------------------*

          ls_cust-customerinfotype = 'MUS'.
          ls_cust-dataelementid = 'ADRES1'.
          ls_cust-dataelementvalue = lv_tmp1.
          LOOP AT ls_go-payment INTO ls_payment.
            SELECT SINGLE adres1 FROM zrt_yemekkart INTO
            ls_cust-dataelementvalue
                                  WHERE /bic/oizge_ot =
                                  ls_payment-fk_payment_type.
          ENDLOOP.
          APPEND ls_cust TO lt_cust.
          CLEAR ls_cust. CLEAR lv_tmp1.
          ls_cust-customerinfotype = 'MUS'.
          ls_cust-dataelementid = 'ADRES2'.
          ls_cust-dataelementvalue = lv_tmp3.
          LOOP AT ls_go-payment INTO ls_payment.
            SELECT SINGLE adres2 FROM zrt_yemekkart INTO
            ls_cust-dataelementvalue
                                  WHERE /bic/oizge_ot =
                                  ls_payment-fk_payment_type.
          ENDLOOP.
          APPEND ls_cust TO lt_cust.
          CLEAR ls_cust. CLEAR lv_tmp3.
          ls_cust-customerinfotype = 'MUS'.
          ls_cust-dataelementid = 'V.D'.
          ls_cust-dataelementvalue = lv_tmp2.
          LOOP AT ls_go-payment INTO ls_payment.
            SELECT SINGLE vergi_daire FROM zrt_yemekkart INTO
            ls_cust-dataelementvalue
                                  WHERE /bic/oizge_ot =
                                  ls_payment-fk_payment_type.
          ENDLOOP.
          APPEND ls_cust TO lt_cust.
          CLEAR ls_cust. CLEAR lv_tmp2.
          ls_cust-customerinfotype = 'MUS'.
          ls_cust-dataelementid = 'V.NO'.
          ls_cust-dataelementvalue = ls_trans-partnerid.
          LOOP AT ls_go-payment INTO ls_payment.
            SELECT SINGLE vergi_no FROM zrt_yemekkart INTO
            ls_cust-dataelementvalue
                                  WHERE /bic/oizge_ot =
                                  ls_payment-fk_payment_type.
          ENDLOOP.
          APPEND ls_cust TO lt_cust.
          CLEAR ls_cust.

          LOOP AT ls_go-result INTO ls_result WHERE type = '24' AND code =
          '4'.
            ls_cust-customerinfotype = 'MUS'.
            ls_cust-dataelementid = 'TC.NO'.
            ls_cust-dataelementvalue = ls_result-parameter_1.
            APPEND ls_cust TO lt_cust.
            CLEAR ls_cust.
            ls_cust-customerinfotype = 'MUS'.
            ls_cust-dataelementid = 'EMAIL'.
            ls_cust-dataelementvalue = ls_result-parameter_2.
            APPEND ls_cust TO lt_cust.
            CLEAR ls_cust.
            ls_cust-customerinfotype = 'MUS'.
            ls_cust-dataelementid = 'CEPNO'.
            ls_cust-dataelementvalue = ls_result-parameter_3.
            APPEND ls_cust TO lt_cust.
            CLEAR ls_cust.
            CLEAR ls_result.
          ENDLOOP.
*RESULT
*          LOOP AT ls_go-result INTO ls_result .
*            CONDENSE: ls_result-type, ls_result-code.
*            lt_ex = me->add_extension( EXPORTING group = 'RESUL'
*                                          field = ls_result-type && '-'  && ls_result-code && '-1'
*                                          value = ls_result-parameter_1 ).
*            APPEND LINES OF lt_ex TO lt_extensions.
*            REFRESH : lt_ex.
*
*            IF ls_result-parameter_2 IS NOT INITIAL .
*              lt_ex = me->add_extension( EXPORTING group = 'RESUL'
*                                  field = ls_result-type && '-'  && ls_result-code && '-2'
*                                  value = ls_result-parameter_2 ).
*              APPEND LINES OF lt_ex TO lt_extensions.
*              REFRESH : lt_ex.
*            ENDIF.
*
*            IF ls_result-parameter_3 IS NOT INITIAL .
*              lt_ex = me->add_extension( EXPORTING group = 'RESUL'
*                                  field = ls_result-type && '-'  && ls_result-code && '-3'
*                                  value = ls_result-parameter_3 ).
*              APPEND LINES OF lt_ex TO lt_extensions.
*              REFRESH : lt_ex.
*            ENDIF.
*
*          ENDLOOP.
          LOOP AT ls_go-result INTO ls_result.
            CONDENSE: ls_result-type, ls_result-code.
            IF  ls_result-parameter_1 IS NOT INITIAL.

              ls_cust-customerinfotype = 'RESU'.
              ls_cust-dataelementid = ls_result-type && '-'  && ls_result-code && '-1'.
              ls_cust-dataelementvalue = ls_result-parameter_1.
              APPEND ls_cust TO lt_cust.
              CLEAR ls_cust.

            ENDIF.

            IF  ls_result-parameter_2 IS NOT INITIAL.
              ls_cust-customerinfotype = 'RESU'.
              ls_cust-dataelementid = ls_result-type && '-'  && ls_result-code && '-2'.
              ls_cust-dataelementvalue = ls_result-parameter_2.
              APPEND ls_cust TO lt_cust.
              CLEAR ls_cust.
            ENDIF.
            IF  ls_result-parameter_3 IS NOT INITIAL.
              ls_cust-customerinfotype = 'RESU'.
              ls_cust-dataelementid = ls_result-type && '-'  && ls_result-code && '-3'.
              ls_cust-dataelementvalue = ls_result-parameter_3.
              APPEND ls_cust TO lt_cust.
              CLEAR ls_cust.
            ENDIF.

          ENDLOOP.
**CS0007674 ökc geliştirmeleri 12.02.2017 sinan.bayram
          LOOP AT ls_go-result INTO ls_result WHERE type = '2' AND code =
          '2'.
            ls_cust-customerinfotype = 'ZRT'.
            ls_cust-dataelementid = 'OKC_SERI_NO'.
            ls_cust-dataelementvalue = ls_result-parameter_1.
            APPEND ls_cust TO lt_cust.
            CLEAR ls_cust.
            CLEAR ls_result.
          ENDLOOP.

          LOOP AT ls_go-result INTO ls_result WHERE type = '2' AND code =
          '3'.
            ls_cust-customerinfotype = 'ZRT'.
            ls_cust-dataelementid = 'Z_NUMARASI'.
            ls_cust-dataelementvalue = ls_result-parameter_1.
            APPEND ls_cust TO lt_cust.
            CLEAR ls_cust.
            CLEAR ls_result.
          ENDLOOP.
*          IF sy-subrc NE 0 .
*            LOOP AT ls_go-result INTO ls_result WHERE type = '3' AND code =
*            '2'.
*              ls_cust-customerinfotype = 'ZRT'.
*              ls_cust-dataelementid = 'Z_NUMARASI'.
*              ls_cust-dataelementvalue = ls_result-parameter_1.
*              APPEND ls_cust TO lt_cust.
*              CLEAR ls_cust.
*              CLEAR ls_result.
*            ENDLOOP.
*
*          ENDIF.
          IF ls_go-header-num IS NOT INITIAL.
            ls_cust-customerinfotype = 'ZRT'.
            ls_cust-dataelementid = 'FISNO'.
            ls_cust-dataelementvalue = ls_go-header-num.
            APPEND ls_cust TO lt_cust.
            CLEAR ls_cust.
          ENDIF.

          LOOP AT lt_cust INTO ls_cust WHERE customerinfotype = 'RESU'
                                       AND   dataelementid    = '24-27-1'.
            ls_cust-dataelementvalue = ls_go-header-document_no.
            MODIFY lt_cust FROM ls_cust.
          ENDLOOP.
          IF sy-subrc <> 0.
            ls_cust-customerinfotype = 'RESU'.
            ls_cust-dataelementid = '24-27-1'.
            ls_cust-dataelementvalue = ls_go-header-document_no.
            APPEND ls_cust TO lt_cust.
          ENDIF.

***CS0007674 ökc geliştirmeleri 12.02.2017 sinan.bayram
          ls_trans-customerdetails = lt_cust.


*- Fiş için ek bilgiler, fiş tipi.
          ls_ext-fieldgroup = 'ZRT'.
          ls_ext-fieldname  = 'BELGE'.
          CASE ls_go-header-option_bitflag.
            WHEN 256. ls_ext-fieldvalue = zcl_pos_constants=>e_fatura.
            WHEN OTHERS.
              IF ls_trans-transtypecode <> '1002' AND ls_trans-transtypecode <> '3003'.
                CASE ls_go-header-ptype.
                  WHEN '0'. ls_ext-fieldvalue = zcl_pos_constants=>fis.
                  WHEN '1'. ls_ext-fieldvalue = zcl_pos_constants=>irsaliye.
                  WHEN '2'. ls_ext-fieldvalue = zcl_pos_constants=>iade.
                  WHEN '3'. ls_ext-fieldvalue = zcl_pos_constants=>diplomatik.
                  WHEN '4'. ls_ext-fieldvalue = zcl_pos_constants=>irsaliye.
                  WHEN '5'. ls_ext-fieldvalue = zcl_pos_constants=>taxfree.
                  WHEN '6'.
                    ls_ext-fieldvalue =
          zcl_pos_constants=>diplomatik_iade.
                  WHEN '7' OR '28'. ls_ext-fieldvalue = zcl_pos_constants=>puan.
                  WHEN '8'. ls_ext-fieldvalue = zcl_pos_constants=>mail_order.
                  WHEN '9'.
                    ls_ext-fieldvalue =
          zcl_pos_constants=>kredi_karti_tahsilati.
                  WHEN '26'.ls_ext-fieldvalue = zcl_pos_constants=>yemekkart.

                ENDCASE.
              ENDIF.
          ENDCASE.
          CONDENSE ls_ext-fieldvalue.
          APPEND ls_ext TO lt_extensions.

          CONCATENATE ls_trans-businessdaydate lv_time_i
            INTO ls_trans-begintimestamp.

          ls_trans-endtimestamp = ls_trans-begintimestamp.

          ls_trans-operatorqual = '1'.
          ls_trans-operatorid = ls_go-header-fk_user.

          ls_trans-transcurrency = lcl_pipe_inbound=>currency.

          lv_line_exit = abap_false.
*- Satış Kalemleri

          LOOP AT ls_go-sale INTO ls_sale.
            REFRESH : lt_retailext.
            MOVE-CORRESPONDING ls_trans TO ls_retail.
            REFRESH ls_retail-extensions.

            ls_retail-retailnumber = ls_sale-line_no.

            CASE ls_trans-transtypecode.
              WHEN '1001' OR '1003' OR '1004' OR '1005' OR '1006' OR '1007'. "B
                CASE ls_sale-status.
                  WHEN '0'. ls_retail-retailtypecode = '0101'.
                  WHEN '1'. ls_retail-retailtypecode = '0105'.
                ENDCASE.
              WHEN '1002' OR '3003'. "C
                CASE ls_sale-status.
                  WHEN '0'. ls_retail-retailtypecode = '0101'.
                  WHEN '1'. ls_retail-retailtypecode = '0105'.
                ENDCASE.

              WHEN '9001' OR '4002'. "A
                ls_retail-retailtypecode = '0201'.
            ENDCASE.

*extension
            lt_ex = me->add_extension( EXPORTING group = 'SALE'
                                                 field = 'SALE_TYPE'
                                                  value = ls_sale-sale_type ).
            APPEND LINES OF lt_ex TO lt_extensions.
            REFRESH : lt_ex.

            ls_retail-itemid = ls_sale-code.
            ls_retail-itemidqualifier = '2'.  "ean kodu  kodu
            CLEAR lv_amount .
            lv_amount = ls_sale-amount.

            IF ls_sale-amount CS '-3'.
              lv_amount = lv_amount / 1000.
            ELSEIF ls_sale-amount CS '-2'.
              lv_amount = lv_amount / 100.
            ELSEIF ls_sale-amount CS '-1'.
              lv_amount = lv_amount / 10.
            ENDIF.
            ls_retail-retailquantity = lv_amount. "Brüt Satış Fiyatı

            IF ls_trans-transtypecode = '9001' OR
            ls_trans-transtypecode = '4002'.
*            IF ls_retail-retailquantity > 0.
              ls_retail-retailquantity = ls_retail-retailquantity * -1.
*            ENDIF.
            ENDIF.

            IF ls_retail-retailtypecode = '0105' OR
            ls_retail-retailtypecode = '0201'.
              IF ls_retail-retailquantity > 0.
                ls_retail-retailquantity = ls_retail-retailquantity * -1.
              ENDIF.
            ENDIF.

            CASE ls_sale-fk_unit.
              WHEN '1'.
                ls_retail-salesuom = 'ST'.
              WHEN '2'.
                ls_retail-salesuom = 'KG'.
                ls_retail-retailquantity = ls_retail-retailquantity .
              WHEN '5'.
                ls_retail-salesuom = 'M2'.
              WHEN '3'.
                ls_retail-salesuom = 'M'.
              WHEN '4'.
                ls_retail-salesuom = 'L'.
              WHEN OTHERS.
                ls_retail-salesuom = 'ST'.
            ENDCASE.

            ls_retail-salesamount = ls_sale-total_price.
            ls_retail-normalsalesamt = ls_sale-total_price.

            IF ls_trans-transtypecode = '9001' OR
           ls_trans-transtypecode = '4002'.
              ls_retail-normalsalesamt = ls_retail-normalsalesamt * -1.
              ls_retail-salesamount = ls_retail-salesamount * -1.
            ENDIF.
            IF ls_retail-retailtypecode = '0105'.
*            IF  ls_retail-normalsalesamt > 0 .
              ls_retail-normalsalesamt = ls_retail-normalsalesamt * -1.
              ls_retail-salesamount = ls_retail-salesamount * -1.
*            ENDIF.
            ENDIF.


            ls_retail-units = ls_retail-retailquantity.

            MOVE-CORRESPONDING ls_retail TO ls_tax.

            CASE ls_sale-vat_percent.
              WHEN 0.  ls_tax-taxtypecode = '0203'.
              WHEN 1.  ls_tax-taxtypecode = '0200'.
              WHEN 8.  ls_tax-taxtypecode = '0201'.
              WHEN 18. ls_tax-taxtypecode = '0202'.
              WHEN 10.  ls_tax-taxtypecode = '0201'.
              WHEN 20. ls_tax-taxtypecode = '0202'.
            ENDCASE.


            ls_tax-taxamount = ls_sale-vat_total.

            IF ls_trans-transtypecode = '9001' OR
              ls_trans-transtypecode = '4002'.
              ls_tax-taxtypecode(2) = '09'.
              ls_tax-taxamount = ls_sale-vat_total * -1.
            ENDIF.

            APPEND ls_tax TO ls_retail-tax.
            CLEAR ls_tax.

* Seller Extension
            READ TABLE ls_go-seller INTO DATA(ls_seller) WITH KEY id = ls_sale-fk_seller.
            IF sy-subrc EQ 0 .
              ls_retailext-fieldgroup = 'SELL' .
              ls_retailext-fieldname  = 'SEL.NO'.
              ls_retailext-fieldvalue = ls_seller-id.
              APPEND ls_retailext TO lt_retailext.

              lt_ex = me->add_extension( EXPORTING group = 'SELL'
                                                    field = 'DESC'
                                                    value = ls_seller-name ).
              APPEND LINES OF lt_ex TO lt_retailext.
              REFRESH : lt_ex.

            ENDIF.
* Reason Extension
            READ TABLE ls_go-reason INTO DATA(ls_reason) WITH KEY id = ls_sale-fk_return_reason.
            IF sy-subrc EQ 0 .
              ls_retailext-fieldgroup = 'REAS' .
              ls_retailext-fieldname  = 'REAS.NO'.
              ls_retailext-fieldvalue = ls_reason-id.
              APPEND ls_retailext TO lt_retailext.

              lt_ex = me->add_extension( EXPORTING group = 'REAS'
                                                    field = 'REAS.DESC'
                                                    value = ls_reason-description ).
              APPEND LINES OF lt_ex TO lt_retailext.
              REFRESH : lt_ex.

            ENDIF.

            ls_retail-extensions = lt_retailext  .
            APPEND ls_retail TO ls_trans-retaillineitem.
            CLEAR ls_retail.

          ENDLOOP.

* satış iptal
          LOOP AT ls_go-sale_cancel INTO ls_sale_cancel.

            MOVE-CORRESPONDING ls_trans TO ls_retail.
            REFRESH ls_retail-extensions.

*         ls_trans-department  = ''. "GO'da departman yok

            ls_retail-retailnumber = ls_sale_cancel-line_no.

            CASE lv_line_exit.
              WHEN space.
                lv_line_exit = abap_true.
            ENDCASE.

            CASE ls_trans-transtypecode.
              WHEN '1001'  OR '1003' OR '1004' OR '1005' OR '1006' OR '1007'. "B
                CASE ls_sale_cancel-status.
                  WHEN '0'. ls_retail-retailtypecode = '0105'.
                ENDCASE.
              WHEN '1002' OR '3003'. "C
                ls_retail-retailtypecode = '0105'.
              WHEN '9001' OR '4002'. "A
                ls_retail-retailtypecode = '0105'.
            ENDCASE.

            ls_retail-itemid = ls_sale_cancel-code.

            ls_retail-itemidqualifier = '2'.  "EAN kodu

            TRY .
                ls_retail-retailquantity = ls_sale_cancel-amount.
              CATCH cx_root.
                ls_retail-retailquantity = '99999999.999'.
            ENDTRY.
            "FK_UNIT eşleştirmesi kontrol edilecek
            "KG için 1000'e bölüm kontrol edilecek
            CASE ls_sale_cancel-fk_unit.
              WHEN '1'.
                ls_retail-salesuom = 'ST'.
              WHEN '2'.
                ls_retail-salesuom = 'KG'.
                ls_retail-retailquantity = ls_retail-retailquantity .
              WHEN '5'.
                ls_retail-salesuom = 'M2'.
              WHEN '3'.
                ls_retail-salesuom = 'M'.
              WHEN '4'.
                ls_retail-salesuom = 'L'.
              WHEN OTHERS.
                ls_retail-salesuom = 'ST'.
            ENDCASE.

            ls_retail-salesamount = ls_sale_cancel-total_price .

            ls_retail-normalsalesamt = ls_sale_cancel-total_price.

            ls_retail-units = ls_retail-retailquantity.

            MOVE-CORRESPONDING ls_retail TO ls_tax.

            CASE ls_sale_cancel-vat_percent.
              WHEN 0.  ls_tax-taxtypecode = '0203'.
              WHEN 1.  ls_tax-taxtypecode = '0200'.
              WHEN 8.  ls_tax-taxtypecode = '0201'.
              WHEN 18. ls_tax-taxtypecode = '0202'.
              WHEN 10.  ls_tax-taxtypecode = '0201'.
              WHEN 20. ls_tax-taxtypecode = '0202'.
            ENDCASE.

            ls_tax-taxamount = ls_sale_cancel-vat_total.

            APPEND ls_tax TO ls_retail-tax.
            CLEAR ls_tax.

            APPEND ls_retail TO ls_trans-retaillineitem.
            CLEAR ls_retail.

          ENDLOOP.
* indirim detayı

          LOOP AT ls_go-discount_detail INTO ls_discount_detail.

            IF ls_discount_detail IS NOT INITIAL.
              LOOP AT ls_go-discount INTO ls_discount_go
                WHERE id EQ ls_discount_detail-fk_transaction_discount
                AND NOT ( discount_type = 1 AND discount_code = 2 AND parameter_2 IS NOT INITIAL ).
                REFRESH :lt_dis_ex.
                CLEAR : lv_camp .            CLEAR :lv_discr.
                IF ls_discount_go-line_no     <> 0 AND
                       ls_discount_go-parent_line <> 0.
                  "kalem indirimi

                  READ TABLE ls_go-sale INTO ls_sale
                    WITH KEY id = ls_discount_detail-fk_transaction_sale.
                  IF sy-subrc = 0.
                    READ TABLE ls_trans-retaillineitem INTO ls_retail
                      WITH KEY retailnumber = ls_sale-line_no.
                    IF sy-subrc = 0.
                      lv_tabix = sy-tabix.
                      MOVE-CORRESPONDING ls_trans TO ls_rdisc.
                      ls_rdisc-reductionamount = ls_discount_detail-amount
                      .
                      IF ls_trans-transtypecode = '9001' OR
                        ls_trans-transtypecode = '4002' OR
                        ls_trans-transtypecode = '1002' OR
                         ls_trans-transtypecode = '3003'.
                        ls_rdisc-reductionamount =
                        ls_rdisc-reductionamount * -1.
                      ENDIF.
                      IF ls_rdisc-reductionamount > 0 .
                        IF  ls_discount_go-discount_type = '1' AND
                        ls_discount_go-discount_code  = '1'.

                          ls_rdisc-disctypecode = '0101'.


                        ELSEIF  ls_discount_go-discount_type = '1' AND
                          ls_discount_go-discount_code  = '3'.

                          ls_rdisc-disctypecode = '0103'.
                        ELSE.

                          ls_rdisc-disctypecode = '0100'.
                        ENDIF.
                        IF  ls_go-header-status EQ '0'.
                          ls_trans-transtypecode = '4001'.
                        ENDIF.
                        IF lv_camp NE ls_discount_go-fk_campaign.
                          LOOP AT ls_go-campaign INTO ls_campaign WHERE id = ls_discount_go-fk_campaign AND parent_line EQ ls_sale-line_no .
                            lt_ex = me->add_extension( EXPORTING group = 'CAMP'
                                                                 field = 'ID'
                                                                 value = ls_campaign-id ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.

                            lt_ex = me->add_extension( EXPORTING group = 'CAMP'
                                                                 field = 'DESC'
                                                                 value = ls_campaign-description ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.
                          ENDLOOP.
                          lv_camp = ls_discount_go-fk_campaign.
                        ENDIF.
                        IF lv_discr NE ls_discount_go-fk_discount_reason.
                          LOOP AT ls_go-discount_reas INTO ls_dis_reas WHERE id = ls_discount_go-fk_discount_reason
                            AND parent_line EQ ls_sale-line_no .
                            lt_ex = me->add_extension( EXPORTING group = 'DISC'
                                                                 field = 'ID'
                                                                 value = ls_dis_reas-id ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.

                            lt_ex = me->add_extension( EXPORTING group = 'DISC'
                                                                 field = 'DESC'
                                                                 value = ls_dis_reas-description ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.
                            ls_rdisc-extensions = lt_dis_ex.
                          ENDLOOP.
                          lv_discr = ls_discount_go-fk_discount_reason.
                        ENDIF.
*          ls_rdisc-discreasoncode = ''.
                        APPEND ls_rdisc TO ls_retail-discount.
                      ELSEIF ls_rdisc-reductionamount < 0 .
                        IF  ls_discount_go-discount_type = '1' AND
                            ls_discount_go-discount_code  = '1'.

                          ls_rdisc-disctypecode = '0101'.

                        ELSEIF  ls_discount_go-discount_type = '1' AND
                          ls_discount_go-discount_code  = '3'.

                          ls_rdisc-disctypecode = '0103'.
                        ELSE.

                          ls_rdisc-disctypecode = '0100'.
                        ENDIF.
                        IF  ls_go-header-status EQ '0'.
                          ls_trans-transtypecode = '4002'.
                        ENDIF.
                        IF lv_camp NE ls_discount_go-fk_campaign.
                          LOOP AT ls_go-campaign INTO ls_campaign WHERE id = ls_discount_go-fk_campaign AND parent_line EQ ls_sale-line_no .
                            lt_ex = me->add_extension( EXPORTING group = 'CAMP'
                                                                 field = 'ID'
                                                                 value = ls_campaign-id ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.

                            lt_ex = me->add_extension( EXPORTING group = 'CAMP'
                                                                 field = 'DESC'
                                                                 value = ls_campaign-description ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.
                          ENDLOOP.
                          lv_camp = ls_discount_go-fk_campaign.
                        ENDIF.
                        IF lv_discr NE ls_discount_go-fk_discount_reason.
                          LOOP AT ls_go-discount_reas INTO ls_dis_reas WHERE id = ls_discount_go-fk_discount_reason
                            AND parent_line EQ ls_sale-line_no .
                            lt_ex = me->add_extension( EXPORTING group = 'DISC'
                                                                 field = 'ID'
                                                                 value = ls_dis_reas-id ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.

                            lt_ex = me->add_extension( EXPORTING group = 'DISC'
                                                                 field = 'DESC'
                                                                 value = ls_dis_reas-description ).

                            APPEND LINES OF lt_ex TO lt_dis_ex.
                            REFRESH : lt_ex.
                            ls_rdisc-extensions = lt_dis_ex.
                          ENDLOOP.
                          lv_discr = ls_discount_go-fk_discount_reason.
                        ENDIF.
*          ls_rdisc-discreasoncode = ''.
                        APPEND ls_rdisc TO ls_retail-discount.
                      ENDIF.
                      SUBTRACT ls_rdisc-reductionamount FROM
                      ls_retail-salesamount.

                      MODIFY ls_trans-retaillineitem FROM ls_retail INDEX
                      lv_tabix.
                    ENDIF.
                  ENDIF.
                ELSEIF ( ls_discount_go-line_no <> 0 AND
                      ls_discount_go-parent_line = 0 ).

*                  IF ls_discount_go-discount_type <> 0 OR
*                     ls_discount_go-discount_code <> 0.

                  IF ( ls_discount_go-discount_type = 1 AND
                         ls_discount_go-discount_code = 1 )  OR
                     ( ls_discount_go-discount_type = 1 AND
                         ls_discount_go-discount_code = 3 ).

                    LOOP AT ls_go-sale INTO ls_sale WHERE id EQ
                    ls_discount_detail-fk_transaction_sale.
                      IF ls_sale IS NOT INITIAL.
                        READ TABLE ls_trans-retaillineitem INTO
                        ls_retail
                        WITH KEY retailnumber = ls_sale-line_no.
                        IF ls_retail IS NOT INITIAL.
                          lv_tabix = sy-tabix.
                          MOVE-CORRESPONDING ls_trans TO ls_rdisc.
                          ls_rdisc-reductionamount =
                          ls_discount_detail-amount.
                          IF ls_trans-transtypecode = '9001' OR
                             ls_trans-transtypecode = '4002'.
                            ls_rdisc-reductionamount =
                            ls_rdisc-reductionamount
                                   * -1.
                          ENDIF.
                          IF ls_rdisc-reductionamount > 0.
                            ls_trans-transtypecode = '4001'.

                          ELSEIF ls_rdisc-reductionamount < 0.
                            ls_trans-transtypecode = '4002'.

                          ENDIF.
                          IF ls_discount_go-discount_type = 1 AND
                               ls_discount_go-discount_code = 1.
                            ls_rdisc-disctypecode = '0101'.
                            ls_rdisc-discid =
                            ls_discount_go-parameter_2.
                          ELSEIF   ls_discount_go-discount_type = 1 AND
                               ls_discount_go-discount_code = 3.
                            ls_rdisc-disctypecode = '0102'.
                            ls_rdisc-discid =
                            ls_discount_go-parameter_2.
                          ELSEIF   ls_discount_go-discount_type = 0 AND
                               ls_discount_go-discount_code = 0.
                            ls_rdisc-disctypecode = '0100'.
                            ls_rdisc-discid =
                            ls_discount_go-parameter_2.
                          ENDIF.
                          IF ls_rdisc IS NOT INITIAL .

                            APPEND ls_rdisc TO ls_retail-discount.
                          ENDIF.


                          SUBTRACT ls_rdisc-reductionamount FROM
                          ls_retail-salesamount.

                          MODIFY ls_trans-retaillineitem FROM ls_retail
                          INDEX lv_tabix.
                        ENDIF.
                      ENDIF.
                    ENDLOOP.
                  ELSE.
                    MOVE-CORRESPONDING ls_trans TO ls_discount.


                    IF NOT ( ls_discount_go-discount_type = 1 AND
                        ls_discount_go-discount_code = 2 ).
                      ls_discount-reductionamount =
                      ls_discount_detail-amount.
                      IF ls_trans-transtypecode = '9001' OR
                          ls_trans-transtypecode = '4002'.
                        ls_discount-reductionamount =
                        ls_discount-reductionamount
                                          * -1.
                      ENDIF.
                    ENDIF.

                    IF ls_discount_go-discount_type = 0 AND
                       ls_discount_go-discount_code = 0.
                      ls_discount-disctypecode = '0100'.
                    ELSEIF ls_discount_go-discount_type = 1 AND
                           ls_discount_go-discount_code = 0.
                      ls_discount-disctypecode = '0100'.
                    ELSEIF ls_discount_go-discount_type = 6 AND
                           ls_discount_go-discount_code = 0.
                      ls_discount-disctypecode = '0100'.
                    ELSEIF ls_discount_go-discount_type = 1 AND
                           ls_discount_go-discount_code = 5.
                      ls_discount-disctypecode = '0105'.
                      " Puan Harcam YSBAYRAM
                      ls_discount-discid = ls_discount_go-parameter_2.
                      "BUNUN 1 4 olanı puan kazanım ama kazanımları takip etmiyoruz.

                    ELSEIF ls_discount_go-discount_type = 5 AND
                           ls_discount_go-discount_code = 0.
                      ls_discount-disctypecode = '0104'.
                      " kazanılmış çeklerin iadesi
                      ls_discount-discid = ls_discount_go-parameter_2.
                      "kazanılmış çeklerin iadesi bu sadece iade işleminde oluyor,
                      "dolayısıyla amountu - olucak. Sinan Bayram.

                    ENDIF.
                    IF ls_trans-transtypecode <> '1002' AND ls_trans-transtypecode <> '3003' .
                      IF ls_discount-reductionamount > 0.
                        APPEND ls_discount TO ls_trans-discount.
                        ls_trans-transtypecode = '4001'.
                        "indirimli satış.
                      ELSEIF ls_discount-reductionamount < 0.
                        APPEND ls_discount TO ls_trans-discount.
                        ls_trans-transtypecode = '4002'.
                      ENDIF.
                    ENDIF.
                  ENDIF.

*                  ENDIF.
                ENDIF.
              ENDLOOP.
            ENDIF.
          ENDLOOP.

*- İndirimler
          SORT ls_go-discount BY id.
          LOOP AT ls_go-discount INTO ls_discount_go
            WHERE NOT ( discount_type = 1 AND discount_code = 2 AND parameter_2 IS NOT INITIAL ).
            REFRESH : ls_discount-extensions.
*- Toplam indirim
*          IF ls_discount_go-line_no    <> 0 AND
*             ls_discount_go-parent_line = 0.

            IF ( ls_discount_go-line_no    <> 0 AND
               ls_discount_go-parent_line = 0 )
              AND
*              ( ls_discount_go-discount_type = 0 AND
*                   ls_discount_go-discount_code = 0 )
              ls_go-discount_detail IS INITIAL.

              MOVE-CORRESPONDING ls_trans TO ls_discount.

              IF NOT ( ls_discount_go-discount_type = 1 AND
                       ls_discount_go-discount_code = 2 ). ""çek kazanma
                IF NOT ( ls_discount_go-discount_type = 1 AND
                       ls_discount_go-discount_code = 4 ). " puan kazanma
                  ls_discount-reductionamount = ls_discount_go-amount.
                  IF ls_trans-transtypecode = '9001' OR
                   ls_trans-transtypecode = '4002'.
                    ls_discount-reductionamount =
                    ls_discount-reductionamount
                                                * -1.
                  ENDIF.
                ENDIF.
              ENDIF.

*              IF ls_discount_go-amount <> '0'.
              IF ls_discount_go-discount_type = 0 AND
                 ls_discount_go-discount_code = 0.
                ls_discount-disctypecode = '0100'.
                IF ls_go-header-status = '0'.
                  IF ls_discount-reductionamount > '0'.
                    APPEND ls_discount TO ls_trans-discount.
                    ls_trans-transtypecode = '4001'."indirimli satış.
                  ELSEIF ls_discount-reductionamount < '0'.
                    APPEND ls_discount TO ls_trans-discount.
                    ls_trans-transtypecode = '4002'.
                  ENDIF.
                ENDIF.
              ELSE.
                IF NOT ( ls_trans-transtypecode = '9001' OR
                         ls_trans-transtypecode = '4002' ).
                  ls_discount-disctypecode = '0100'.
                  IF ls_go-header-status = '0'.
                    APPEND ls_discount TO ls_trans-discount.
                    ls_trans-transtypecode = '4001'."indirimli satış.
                  ENDIF.
                ENDIF.
              ENDIF.
              CLEAR ls_discount.
            ENDIF.
          ENDLOOP.

** sbayram 06.09.2017 paymentsatırı iptal fişlerinde yoksa
          lv_payment_exist = abap_false.
** sbayram 06.09.2017 paymentsatırı iptal fişlerinde yoksa

          DATA : lv_payment TYPE string.

          IF ls_go-header-ptype NE '7'.

            DATA: lv_serial_prefix TYPE string,
                  lv_serial        TYPE string.
            LOOP AT ls_go-payment INTO ls_payment.
              lv_payment = ls_payment-fk_payment_type.

              CLEAR: lv_serial_prefix, lv_serial.
              SPLIT ls_payment-serial_no AT ';' INTO lv_serial_prefix lv_serial.
              MOVE-CORRESPONDING ls_trans TO ls_tender.
              REFRESH ls_tender-extensions.

*- Ödeme tipi
              CLEAR: ls_payment_type.
              READ TABLE me->payment_types INTO ls_payment_type WITH KEY id
              = ls_payment-fk_payment_type.
              IF sy-subrc EQ 0.
                ls_payment-fk_payment_type = ls_payment_type-num.
              ENDIF.
              DATA : lv_payment2 TYPE char2.
              CLEAR : lv_payment2.
              CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
                EXPORTING
                  input  = ls_payment-fk_payment_type
                IMPORTING
                  output = lv_payment2.
              ls_payment-fk_payment_type = lv_payment2.
              CASE ls_payment-payment_type.
                WHEN 1. "Para üstü
                  IF ls_payment-fk_payment_type = '00'.
                    SELECT SINGLE /bic/zodemetip /bic/ztxtlg FROM
                    /bic/pzodemetip
                      INTO (ls_tender-tendertypecode,ls_tender-tenderid)
                           WHERE  objvers        = 'A'
                           AND    /bic/zge_ot    = '00'
                           AND    /bic/ziadeflag = space
                           AND    /bic/zse_ot    = lv_serial.
                    IF sy-subrc <> 0.
                      ls_tender-tendertypecode = '01'.
                    ENDIF.
                  ELSE .
                    SELECT SINGLE /bic/zodemetip /bic/ztxtlg FROM
                    /bic/pzodemetip
                      INTO (ls_tender-tendertypecode,ls_tender-tenderid)
                           WHERE  objvers        = 'A'
                          AND    /bic/zge_ot    = ls_payment-fk_payment_type
                          AND    /bic/ziadeflag = '2'
                          AND    /bic/zse_ot    = lv_serial.
                    IF sy-subrc <> 0.
                      ls_tender-tendertypecode = '01'.
                    ENDIF.
                  ENDIF.

                WHEN OTHERS.
                  SELECT SINGLE /bic/zodemetip /bic/ztxtlg FROM
                  /bic/pzodemetip
                    INTO (ls_tender-tendertypecode,ls_tender-tenderid)
                         WHERE  objvers        = 'A'
                         AND    /bic/zge_ot    = ls_payment-fk_payment_type
                         AND    /bic/ziadeflag = space
                         AND    /bic/zse_ot    = lv_serial.
                  IF sy-subrc <> 0.
                    ls_tender-tendertypecode = ls_payment-fk_payment_type.
                  ENDIF.
              ENDCASE.
**CS0010787 sbayram 06.09.2017 paymentsatırı iptallerde yoksa
              lv_payment_exist = abap_true.
**CS0010787 sbayram 06.09.2017 paymentsatırı iptallerde yoksa

              ls_tender-tenderamount = ls_payment-payment_total.
              ls_tender-referenceid = ls_payment-custom_text.
              IF ls_trans-transtypecode = '9001' OR
                ls_trans-transtypecode = '4002'.
                ls_tender-tenderamount = ls_tender-tenderamount * -1.
                SELECT SINGLE /bic/zodemetip /bic/ztxtlg FROM
                /bic/pzodemetip
                  INTO (ls_tender-tendertypecode,ls_tender-tenderid)
                       WHERE  objvers        = 'A'
                       AND    /bic/zge_ot    = ls_payment-fk_payment_type
                       AND    /bic/ziadeflag = '2'
                       AND    /bic/zse_ot    = lv_serial.
              ENDIF.
              IF ls_payment-status = 1. "İptal
*              ls_tender-tenderamount = ls_tender-tenderamount * -1.
              ENDIF.
              IF ls_payment-payment_type = 1. "Para üstü
                ls_tender-tenderamount = ls_tender-tenderamount * -1.
              ENDIF.

              IF ls_payment-payment_type = 2.
                ls_ext-fieldgroup = 'ZFI'.
                ls_ext-fieldname  = 'ZKUR'.
                TRY.
                    lv_dec = ls_payment-payment_total /
                    ls_payment-currency_total.
                  CATCH cx_root.
                ENDTRY.
                ls_ext-fieldvalue = lv_dec.
                CONDENSE ls_ext-fieldvalue.
                APPEND ls_ext TO ls_tender-extensions.

                CLEAR lv_dec.
                ls_ext-fieldgroup = 'ZFI'.
                ls_ext-fieldname  = 'ZTUTAR'.
                TRY .
                    lv_dec = ls_payment-currency_total.
                  CATCH cx_root.
                ENDTRY.
                ls_ext-fieldvalue = lv_dec.
                o_aggr->collect_tender(
                    ip_retailstoreid   = ls_trans-retailstoreid
                    ip_businessdaydate = ls_trans-businessdaydate
                    ip_tendertypecode  = ls_tender-tendertypecode
                    ip_timestamp       = ls_trans-begintimestamp
                    ip_tenderamount    = lv_dec
                    ip_transaction_id  = ls_go-header-id
                    ip_begintime       = CONV t( lv_time_i ) ).
                CONDENSE ls_ext-fieldvalue.
                APPEND ls_ext TO ls_tender-extensions.
              ENDIF.

              IF ls_tender-tendertypecode = 'H001'.
                ls_ext-fieldgroup = 'ZFI'.
                ls_ext-fieldname  = 'ZPARTNER'.
                ls_ext-fieldvalue = ls_trans-partnerid.
                APPEND ls_ext TO ls_tender-extensions.
              ENDIF.

*              eft pos
*            REFRESH : lt_cart.
*            LOOP AT ls_go-eft INTO DATA(ls_eft)  WHERE fk_payment_type_eft_pos = lv_payment.
*              CLEAR : ls_cart.
*              ls_cart-authtermid  = ls_eft-authorization_num.
*              ls_cart-cardnumber  = ls_eft-card_num.
*              ls_cart-paymentcard = ls_eft-card_type.
*              APPEND ls_cart TO lt_cart.
*            ENDLOOP.
*            IF lt_cart[] IS NOT INITIAL.
*              APPEND LINES OF lt_cart TO ls_tender-creditcard.
*            ENDIF.
              APPEND ls_tender TO ls_trans-tender.
              CLEAR ls_tender.

*            IF ls_go-header-ptype = '7'.
*              ls_tender-tendertypecode = 'J001'.
*              IF ls_tender-tenderamount IS INITIAL .
*                ls_tender-tenderamount = ls_payment-payment_total.
*              ENDIF.
*              ls_tender-tenderamount = ls_tender-tenderamount * -1.
*              ls_tender-tenderid = 'PUAN'.
*              APPEND ls_tender TO ls_trans-tender.
*            ENDIF.
            ENDLOOP.

          ELSE.

            CLEAR: ls_payment_type.
            READ TABLE me->payment_types INTO ls_payment_type WITH KEY id
            = ls_payment-fk_payment_type.
            IF sy-subrc EQ 0.
              ls_payment-fk_payment_type = ls_payment_type-num.
            ENDIF.
            DATA : lv_odemetip TYPE /bic/oizodemetip,
                   lv_txtlg    TYPE /bic/oiztxtlg.
            CLEAR : lv_payment2,lv_odemetip, lv_txtlg .
            CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
              EXPORTING
                input  = ls_payment-fk_payment_type
              IMPORTING
                output = lv_payment2.
            ls_payment-fk_payment_type = lv_payment2.
            CASE ls_payment-payment_type.
              WHEN 1. "Para üstü
                IF ls_payment-fk_payment_type = '00'.
                  SELECT SINGLE /bic/zodemetip /bic/ztxtlg FROM
                  /bic/pzodemetip
                    INTO (lv_odemetip,lv_txtlg)
                         WHERE  objvers        = 'A'
                         AND    /bic/zge_ot    = '00'
                         AND    /bic/ziadeflag = space.
                  IF sy-subrc <> 0.
                    lv_odemetip = '01'.
                  ENDIF.
                ELSE .
                  SELECT SINGLE /bic/zodemetip /bic/ztxtlg FROM
                  /bic/pzodemetip
                    INTO (lv_odemetip,lv_txtlg)
                         WHERE  objvers        = 'A'
                        AND    /bic/zge_ot    = ls_payment-fk_payment_type
                       AND    /bic/ziadeflag = '2'.
                  IF sy-subrc <> 0.
                    lv_odemetip = '01'.
                  ENDIF.
                ENDIF.

              WHEN OTHERS.
                SELECT SINGLE /bic/zodemetip /bic/ztxtlg FROM
                /bic/pzodemetip
                  INTO (lv_odemetip,lv_txtlg)
                       WHERE  objvers        = 'A'
                       AND    /bic/zge_ot    = ls_payment-fk_payment_type
                       AND    /bic/ziadeflag = space.
                IF sy-subrc <> 0.
                  lv_odemetip = ls_payment-fk_payment_type.
                ENDIF.
            ENDCASE.

            ls_tender-tendertypecode = lv_odemetip."'A007'.
            ls_tender-tenderamount = ls_go-header-gross_total.
            ls_tender-tenderid     = lv_txtlg."'A007'.
            APPEND ls_tender TO ls_trans-tender.
            CLEAR ls_tender.

            ls_tender-tendertypecode = 'J001'.
            ls_tender-tenderamount = ls_go-header-gross_total * -1.
            ls_tender-tenderid     = 'PUAN'.
            APPEND ls_tender TO ls_trans-tender.
            CLEAR ls_tender.
          ENDIF.

          IF ls_go-header-ptype = '28'.
            DATA(lv_puan_odeme) = abap_false.
            ls_tender-tenderamount = ls_go-header-discount_on_lines.
            IF ls_tender-tenderamount > 0.
              ls_tender-tendertypecode = 'A008'.
              ls_tender-tenderid     = 'KASA NOKSANI'.
              APPEND ls_tender TO ls_trans-tender.
              lv_puan_odeme = abap_true.
              ls_tender-tendertypecode = 'J002'.
              ls_tender-tenderamount = ls_go-header-gross_total * -1.
              ls_tender-tenderid     = 'PUAN'.
              APPEND ls_tender TO ls_trans-tender.
              CLEAR ls_tender.
            ENDIF.
            CLEAR ls_tender.
          ENDIF.

** SİNAN BAYRAM 22.06.2016 00:05 eğer kalemsiz ve ödemesiz fiş gelirse ben dummy ekliyorum
          IF ls_trans-transtypecode = '1002' OR ls_trans-transtypecode = '3003' .
            CASE lv_line_exist.
              WHEN space.
                ls_retail-retailtypecode = 'ZZZZ'.
                ls_retail-normalsalesamt = 1 / 100.
                ls_retail-salesamount = 1 / 100.
                APPEND ls_retail TO ls_trans-retaillineitem.
                CLEAR ls_retail.
            ENDCASE.
**CS0010787 sbayram 06.06.2017 paymentsatırı iptallerde yoksa
            CASE lv_payment_exist.
              WHEN space.
                ls_tender-tendertypecode = 'ZZZZ'.
                ls_tender-tenderamount = 1 / 100.
                APPEND ls_tender TO ls_trans-tender.
                CLEAR ls_tender.
            ENDCASE.
**CS0010787 sbayram 06.06.2017 paymentsatırı iptallerde yoksa
          ENDIF.

          ls_trans-extensions = lt_extensions.

          LOOP AT ls_trans-retaillineitem INTO ls_retail.
            IF ls_go-header-ptype = '28' AND lv_puan_odeme = abap_true.
              DELETE ls_retail-discount WHERE disctypecode IS NOT INITIAL.
              ls_retail-salesamount = ls_retail-normalsalesamt.
            ENDIF.
            LOOP AT ls_trans-extensions INTO ls_ext WHERE fieldgroup =
            'ZRT'
                                                    AND   fieldname  =
                                                    'BELGE'.
              APPEND ls_ext TO ls_retail-extensions.

              CLEAR ls_ext.
              IF ls_trans-partnerid IS NOT INITIAL.
                ls_ext-fieldgroup = 'ZRT'.
                ls_ext-fieldname  = 'BELNO'.
                ls_ext-fieldvalue = ls_trans-department.
                APPEND ls_ext TO ls_retail-extensions.
              ENDIF.


            ENDLOOP.
            MODIFY ls_trans-retaillineitem FROM ls_retail.
          ENDLOOP.

          DATA(is_valid) = abap_true.
          IF ls_trans-transtypecode <> '1002'.
            DATA(lv_salesamount)  = CONV /posdw/tlogf-salesamount( 0 ).
            DATA(lv_tenderamount) = CONV /posdw/tlogf-tenderamount( 0 ).
            LOOP AT ls_trans-retaillineitem ASSIGNING FIELD-SYMBOL(<ls_retail>)
              WHERE retailtypecode <> '2901'
              AND   retailtypecode <> '0105'.
              ADD <ls_retail>-salesamount TO lv_salesamount.
            ENDLOOP.
            LOOP AT ls_trans-discount ASSIGNING FIELD-SYMBOL(<ls_discount>).
              SUBTRACT <ls_discount>-reductionamount FROM lv_salesamount.
            ENDLOOP.
            LOOP AT ls_trans-tender ASSIGNING FIELD-SYMBOL(<ls_tender>)
              WHERE tendertypecode <> 'J001'
              AND   tendertypecode <> 'J002'.
              ADD <ls_tender>-tenderamount TO lv_tenderamount.
            ENDLOOP.
            IF lv_salesamount <> lv_tenderamount.
              is_valid = abap_false.
            ENDIF.
          ENDIF.

          APPEND INITIAL LINE TO go_interface->transactions
          ASSIGNING <ls_trns>.
          <ls_trns>-id              = ls_go-header-id.
          <ls_trns>-retailstoreid   = ls_trans-retailstoreid.
          <ls_trns>-businessdaydate = ls_trans-businessdaydate.

          IF is_valid = abap_true.

            <ls_trns>-operationtype   = 'Z'.

            APPEND ls_trans TO me->trans.

          ELSE.
            <ls_trns>-operationtype   = 'B'.
          ENDIF.
          CLEAR: ls_trans, lt_extensions,ls_trans-retaillineitem[],
          lt_cart[].
*      ENDIF.

        CATCH cx_root INTO gr_root2.
          CLEAR: gv_text.
          gv_text = gr_root2->get_text( ).
*          gv_text = id && '' && gv_er && gv_text.
          CONCATENATE id gv_text INTO gv_text SEPARATED BY space.
          CLEAR: ls_trans, lt_extensions,ls_trans-retaillineitem[].
          WRITE: gv_text.

          CLEAR gs_log.
          gs_log-trans_date = ls_go-header-trans_date(4) &&
                              ls_go-header-trans_date+5(2) &&
                              ls_go-header-trans_date+8(2).
          gs_log-id         = ls_go-header-id.
          gs_log-statu      = 'E'.
          APPEND gs_log TO gt_log.

      ENDTRY.
    ENDLOOP.

    IF gt_log[] IS NOT INITIAL .
      MODIFY zor_cash_id FROM TABLE gt_log.
    ENDIF.
  ENDMETHOD.

  METHOD call_bapi.

    DATA lv_message TYPE bapiret2-message.

    CLEAR ep_done.
    IF me->trans[] IS INITIAL.
      ep_done = abap_true.
      RETURN.
    ENDIF.

    o_aggr->save_aggregation( ip_commit = 'X' ) .

    GET TIME.
    DATA(lv_timestamp) = CONV /posdw/tibq-timestamp( sy-datum && sy-uzeit ).

    CALL FUNCTION '/POSDW/CREATE_TRANSACTIONS_EXT'
      EXPORTING
        it_transaction = me->trans
      EXCEPTIONS
        error_occurred = 1
        OTHERS         = 2.
    IF sy-subrc <> 0.
      IF sy-batch = space.
        MESSAGE ID sy-msgid TYPE 'I' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        DISPLAY LIKE sy-msgty.
      ENDIF.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
      INTO lv_message.
      WRITE : / lv_message.
    ELSE.
      MESSAGE s018(sv) INTO lv_message.
*   Veriler saklandı
      WRITE : / lv_message.
      DATA(lt_del) = lcl_pipe_inbound=>check_queue( ip_timestamp = lv_timestamp
                                                    it_trans     = me->trans ).
      IF lt_del IS NOT INITIAL.
        lcl_pipe_inbound=>delete_tibq( lt_del ).
        WRITE / TEXT-t01.
        WRITE / TEXT-t02.
        WRITE: / TEXT-t03, TEXT-t04.
        LOOP AT lt_del ASSIGNING FIELD-SYMBOL(<ls_del>).
          DELETE go_interface->transactions
          WHERE retailstoreid   = <ls_del>-retailstoreid
          AND   businessdaydate = <ls_del>-businessdaydate.
          WRITE: / <ls_del>-retailstoreid   UNDER TEXT-t03,
                   <ls_del>-businessdaydate UNDER TEXT-t04.
        ENDLOOP.
      ENDIF.
      ep_done = 'X'.
    ENDIF.

  ENDMETHOD.

  METHOD collect_discount.
    DATA ls_discount LIKE LINE OF et_discount.
    et_discount = it_discount.
    READ TABLE et_discount INTO ls_discount
      WITH KEY disctypecode = is_discount-disctypecode.
    CASE sy-subrc.
      WHEN 0.
        ADD is_discount-reductionamount TO ls_discount-reductionamount.
        MODIFY et_discount FROM ls_discount INDEX sy-tabix
          TRANSPORTING reductionamount.
      WHEN OTHERS.
        APPEND is_discount TO et_discount.
    ENDCASE.
  ENDMETHOD.

  METHOD check_queue.

    TYPES: BEGIN OF lst_key,
             retailstoreid   TYPE /posdw/transaction_int-retailstoreid,
             businessdaydate TYPE /posdw/transaction_int-businessdaydate,
             transcount      TYPE /posdw/tibq-transcount,
           END OF lst_key.

    DATA: lt_keys TYPE SORTED TABLE OF lst_key
          WITH UNIQUE KEY retailstoreid businessdaydate.

    LOOP AT it_trans ASSIGNING FIELD-SYMBOL(<ls_trans>).
      COLLECT VALUE lst_key( retailstoreid   = <ls_trans>-retailstoreid
                             businessdaydate = <ls_trans>-businessdaydate
                             transcount      = 1 )
                       INTO lt_keys.
    ENDLOOP.

    IF lt_keys IS NOT INITIAL.
      DO 10 TIMES.
        SELECT retailstoreid, businessdaydate, guid, timestamp, transcount,
               recordstatus, objkey, objtype, logsys
          FROM  /posdw/tibq
          INTO CORRESPONDING FIELDS OF TABLE @et_del
          FOR ALL ENTRIES IN @lt_keys
               WHERE  retailstoreid    = @lt_keys-retailstoreid
               AND    businessdaydate  = @lt_keys-businessdaydate
               AND    timestamp       >= @ip_timestamp.
        CASE sy-subrc.
          WHEN 0.      EXIT.
          WHEN OTHERS. WAIT UP TO 1 SECONDS.
        ENDCASE.
      ENDDO.
      LOOP AT et_del ASSIGNING FIELD-SYMBOL(<ls_del>).
        IF lt_keys[ retailstoreid   = <ls_del>-retailstoreid
                    businessdaydate = <ls_del>-businessdaydate ]-transcount
          = <ls_del>-transcount.
          DELETE et_del.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD delete_tibq.

    DATA: lt_del_admin_data TYPE /posdw/tt_tibqadmin,
          ls_del_admin_data TYPE /posdw/tibq_adm.

*         Get instance for processing
    DATA(lr_tibq_tool) = /posdw/cl_tibq_tool=>get_instance( ).

*         Get entries which have to be deleted
    lr_tibq_tool->retrieve_tibqrecords_by_key(
      EXPORTING
        it_tibqrecords_head = it_del
      IMPORTING
        et_tibqrecords      = DATA(lt_delete_tibq)
*              e_return            =
           ).

    IF NOT lt_delete_tibq IS INITIAL.

*           Delete entries from DB
      lr_tibq_tool->delete_tibqrecords(
        EXPORTING
          it_tibqrecords = lt_delete_tibq
        IMPORTING
          e_return       = DATA(l_return)
             ).

      IF l_return IS INITIAL.
*             Delete was successful
        LOOP AT lt_delete_tibq ASSIGNING FIELD-SYMBOL(<ls_delete_tibq_db>).

*               Collect data for update of admin records
          ls_del_admin_data-retailstoreid = <ls_delete_tibq_db>-retailstoreid.
          CASE <ls_delete_tibq_db>-recordstatus.
            WHEN /posdw/if_gen_constants=>tibq_status_ready.
              ls_del_admin_data-tibqrecready = 1.
              ls_del_admin_data-transready   = <ls_delete_tibq_db>-transcount.
            WHEN /posdw/if_gen_constants=>tibq_status_error.
              ls_del_admin_data-tibqrecerror = 1.
              ls_del_admin_data-transerror   = <ls_delete_tibq_db>-transcount.
            WHEN OTHERS.
*                       Currently nothing to do.
          ENDCASE.
          APPEND ls_del_admin_data TO lt_del_admin_data.

        ENDLOOP.

*             Update admin records if used.
        LOOP AT lt_del_admin_data ASSIGNING FIELD-SYMBOL(<ls_del_admin_data>).
          lr_tibq_tool->update_tibq_admin_entry(
            EXPORTING
              i_retailstoreid               = <ls_del_admin_data>-retailstoreid
              i_tibqrecords_completed       = <ls_del_admin_data>-tibqrecready
              i_tibqrecords_error_completed = <ls_del_admin_data>-tibqrecerror
              i_trans_completed             = <ls_del_admin_data>-transready
              i_trans_error_completed       = <ls_del_admin_data>-transerror
              i_get_timestamp_upd           = 'X'
            IMPORTING
              e_return                      = l_return
                 ).
        ENDLOOP.

      ENDIF.

    ENDIF.

  ENDMETHOD.

  METHOD add_extension.
    DATA: ls_ex    TYPE LINE OF /posdw/tt_extensions,
          lt_out   TYPE out_line,
          lv_value TYPE char256.

    lv_value = value.

    me->rkd_word_wrap(
      EXPORTING
        textline = lv_value
        outputlen = 40
      IMPORTING
        out_lines  = lt_out ).



    LOOP AT lt_out ASSIGNING FIELD-SYMBOL(<fs_out>).
      ls_ex-fieldgroup = group.
      ls_ex-fieldname  = field.
      ls_ex-fieldvalue = <fs_out>-line.
      APPEND ls_ex TO extension.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_header_ex.
    DATA : lt_ex TYPE /posdw/tt_extensions.

    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
                                         field = 'DOC_NO'
                                         value = header-document_no ).

    APPEND LINES OF lt_ex TO extension.
    REFRESH : lt_ex.


*    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
*                                         field = 'STATU'
*                                         value = header-status ).
*
*    APPEND LINES OF lt_ex TO extension.
*    REFRESH : lt_ex.

*
*    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
*                                         field = 'PTYPE'
*                                         value = header-ptype ).
*
*    APPEND LINES OF lt_ex TO extension.
*    REFRESH : lt_ex.


*    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
*                                         field = 'GROSS_TOT'
*                                         value = header-gross_total ).
*
*    APPEND LINES OF lt_ex TO extension.
*    REFRESH : lt_ex.

*    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
*                                         field = 'GROSS_VAT'
*                                         value = header-gross_vat_total ).
*
*    APPEND LINES OF lt_ex TO extension.
*    REFRESH : lt_ex.

*    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
*                                         field = 'DISC_TOT'
*                                        value = header-discount_on_total ).
*
*    APPEND LINES OF lt_ex TO extension.
*    REFRESH : lt_ex.

*    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
*                                         field = 'DISC_LIN'
*                                         value = header-discount_on_lines ).
*
*    APPEND LINES OF lt_ex TO extension.
*    REFRESH : lt_ex.

    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
                                         field = 'TAX_REF'
                                         value = header-taxfree_refund_total ).

    APPEND LINES OF lt_ex TO extension.
    REFRESH : lt_ex.

    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
                                         field = 'CUSTOM'
                                         value = header-custom_text ).

    APPEND LINES OF lt_ex TO extension.
    REFRESH : lt_ex.

    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
                                         field = 'VOID_DESC'
                                         value = header-void_description ).

    APPEND LINES OF lt_ex TO extension.
    REFRESH : lt_ex.

    lt_ex = me->add_extension( EXPORTING group = 'HEAD'
                                         field = 'OPTION'
                                         value = header-option_bitflag ).

    APPEND LINES OF lt_ex TO extension.
    REFRESH : lt_ex.

  ENDMETHOD.

  METHOD rkd_word_wrap.
    CONSTANTS: max_outputlen TYPE i VALUE 256.
    DATA : delimiter TYPE c VALUE '' .
    DATA: ld_line(max_outputlen) TYPE c,
          ld_str_len             TYPE i,
          ld_fieldlen            TYPE i,
          BEGIN OF ls_lines ,
            line(256) TYPE c,
          END OF ls_lines,
          lt_lines LIKE TABLE OF ls_lines.

    DESCRIBE FIELD textline LENGTH ld_fieldlen IN CHARACTER MODE.

* check for split-option
    ld_str_len = strlen( textline ).
    IF delimiter EQ space OR
       ld_str_len GT outputlen.
*   complex split: last occurrence of delimiter before split-position
      PERFORM split_complex TABLES lt_lines
                             USING textline
                                   outputlen
                                   delimiter.
    ELSE.
*   do a simple split with the delimiter
      SPLIT textline AT delimiter INTO TABLE lt_lines
                        IN CHARACTER MODE.
    ENDIF.
* fill the return parameters
    LOOP AT lt_lines INTO ls_lines.
      ld_line = ls_lines-line.
      APPEND ld_line TO out_lines.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
*&---------------------------------------------------------------------*
*&      Form  SPLIT_COMPLEX
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LT_LINES  text
*      -->P_TEXTLINE  text
*      -->P_OUTPUTLEN  text
*      -->P_DELIMITER  text
*----------------------------------------------------------------------*
FORM split_complex TABLES ct_lines
                    USING id_text TYPE c
                          id_len  TYPE i
                          id_del  TYPE c.

  DATA: ld_len    TYPE i,
        ld_pos    TYPE i,
        ld_strlen TYPE i.
  DATA : lv_text TYPE c LENGTH 256.
*        ld_string(256) type c.

  lv_text = id_text.
  FIELD-SYMBOLS: <ld_char>   TYPE c,
                 <ld_string> TYPE c.                        "H1407684

*  ASSIGN id_text TO <ld_string>.                            "H1407684
  ASSIGN lv_text TO <ld_string>.                            "H1407684
  REFRESH ct_lines.
* get starting position
  cl_scp_linebreak_util=>string_split_at_position(
           EXPORTING im_string   = <ld_string>              "H1407684
                     im_pos_tech = id_len
           IMPORTING ex_pos_tech = ld_pos ).
* check each single character - processing rigth to left
  DO.
*   check for exit
    ld_strlen = strlen( <ld_string> ).                      "H1407684
    ld_len = ld_pos.
    ld_pos = ld_pos - 1.
    IF ld_pos LT 0 OR ld_strlen EQ 0.
      EXIT.
    ENDIF.
*   get actual character
    cl_scp_linebreak_util=>string_split_at_position(
             EXPORTING im_string   = <ld_string>            "H1407684
                       im_pos_tech = ld_pos
             IMPORTING ex_pos_tech = ld_pos ).
    ld_len = ld_len - ld_pos.
    ASSIGN <ld_string>+ld_pos(ld_len) TO <ld_char> CASTING. "H1407684
*   check actual character
    IF ( <ld_char> EQ id_del AND ld_pos NE 0 ) OR
       ( ld_strlen LE id_len ).
*     delimiter found or string is short enough
      IF ld_pos GT 0.                                       "H1365149
        CONCATENATE <ld_string>(ld_pos) <ld_char>           "H1407684
                       INTO ct_lines RESPECTING BLANKS.     "H1355908
      ELSE.                                                 "H1365149
        ct_lines = <ld_char>.                               "H1365149
      ENDIF.                                                "H1365149
      APPEND ct_lines.
      SHIFT <ld_string> BY ld_pos PLACES.                   "H1407684
      SHIFT <ld_string> BY ld_len PLACES.                   "H1407684
      cl_scp_linebreak_util=>string_split_at_position(
               EXPORTING im_string   = <ld_string>          "H1407684
                         im_pos_tech = id_len
               IMPORTING ex_pos_tech = ld_pos ).
    ELSEIF ld_pos = 0.
*     no delimiter found - do a break at ID_LEN
      cl_scp_linebreak_util=>string_split_at_position(
               EXPORTING im_string   = <ld_string>          "H1407684
                         im_pos_tech = id_len
               IMPORTING ex_pos_tech = ld_pos ).
      ct_lines = <ld_string>(ld_pos).                       "H1407684
      APPEND ct_lines.
      SHIFT <ld_string> BY ld_pos PLACES.                   "H1407684
      cl_scp_linebreak_util=>string_split_at_position(
               EXPORTING im_string   = <ld_string>          "H1407684
                         im_pos_tech = id_len
               IMPORTING ex_pos_tech = ld_pos ).
    ENDIF.
  ENDDO.

ENDFORM.
