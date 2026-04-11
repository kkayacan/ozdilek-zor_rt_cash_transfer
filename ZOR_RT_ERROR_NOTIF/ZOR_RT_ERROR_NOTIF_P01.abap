*&---------------------------------------------------------------------*
*& Include ZOR_RT_ERROR_NOTIF_P01 — Business model class implementations
*&---------------------------------------------------------------------*
CLASS lcl_business IMPLEMENTATION.

  METHOD validate_selection.
    IF p_begda > p_endda.
      MESSAGE e008.
    ENDIF.
  ENDMETHOD.

  METHOD refresh_data.
    CLEAR: gt_inv, gt_kasa.
    TRY.
        DATA(lt_bw) = fetch_genius_bw( ).
        DATA(lt_agg) = build_sap_aggregates( ).
        gt_kasa = compare_bw_sap( it_bw = lt_bw it_agg = lt_agg ).

        IF p_mail = 'X' OR p_fis = 'X'.
          gt_inv = fetch_invalid_trx( gt_kasa ).
        ENDIF.

      CATCH cx_sql_exception INTO DATA(lx_sql).
        DATA: lv_sqltxt TYPE c LENGTH 120,
              lv_sqlcod TYPE c LENGTH 10,
              lv_int    TYPE c LENGTH 132.
        IF lx_sql->db_error = 'X'.
          lv_sqltxt = lx_sql->sql_message.
          lv_sqlcod = lx_sql->sql_code.
          MESSAGE e006 WITH lv_sqlcod lv_sqltxt.
        ELSE.
          lv_int = lx_sql->internal_error.
          MESSAGE e007 WITH lv_int.
        ENDIF.
      CATCH cx_root INTO DATA(lx_root).
        DATA lv_err TYPE c LENGTH 132.
        lv_err = lx_root->get_text( ).
        MESSAGE e007 WITH lv_err.
    ENDTRY.
  ENDMETHOD.

  METHOD fetch_invalid_trx.
    DATA: lt_scope         TYPE tt_kasa_scope,
          ls_scope         TYPE ty_kasa_scope,
          ls_kasa          TYPE ty_kasa_err,
          ls_header        TYPE ty_genius_header,
          ls_inv           TYPE ty_inv_err,
          lv_reason        TYPE string,
          lv_retailstoreid TYPE /posdw/tlogf-retailstoreid.

    CLEAR rt_inv.

    LOOP AT it_kasa INTO ls_kasa.
      INSERT VALUE #(
        uretim_yeri = ls_kasa-uretim_yeri
        fk_pos      = ls_kasa-fk_pos
        tarih       = ls_kasa-tarih ) INTO TABLE lt_scope.
    ENDLOOP.

    LOOP AT lt_scope INTO ls_scope.
      CLEAR ls_kasa.
      ls_kasa-uretim_yeri = ls_scope-uretim_yeri.
      ls_kasa-fk_pos      = ls_scope-fk_pos.
      ls_kasa-tarih       = ls_scope-tarih.

      DATA(lt_headers) = fetch_genius_headers( ls_kasa ).
      LOOP AT lt_headers INTO ls_header.
        lv_reason = check_header_missing( ls_header ).
        IF lv_reason IS INITIAL.
          CONTINUE.
        ENDIF.

        CLEAR: ls_inv, lv_retailstoreid.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = ls_header-fk_store
          IMPORTING
            output = lv_retailstoreid.

        ls_inv-trans_date      = parse_sql_date( ls_header-trans_date ).
        ls_inv-trans_time      = parse_sql_time( ls_header-trans_date ).
        ls_inv-go_trans_id     = ls_header-id.
        ls_inv-receipt_barcode = ls_header-receipt_barcode.
        ls_inv-fk_store        = ls_header-fk_store.
        ls_inv-fk_pos          = ls_header-fk_pos.
        ls_inv-businessdaydate = COND #(
          WHEN ls_inv-trans_date IS NOT INITIAL THEN ls_inv-trans_date
          ELSE ls_scope-tarih ).
        ls_inv-retailstoreid   = lv_retailstoreid.
        ls_inv-reason          = lv_reason.
        APPEND ls_inv TO rt_inv.
      ENDLOOP.
    ENDLOOP.

    SORT rt_inv BY trans_date trans_time go_trans_id.
  ENDMETHOD.

  METHOD fetch_genius_headers.

    DATA: lv_sql   TYPE string,
          lv_date  TYPE string,
          lv_store TYPE string,
          lv_pos   TYPE string.

    CLEAR rt_headers.

    lv_store = is_kasa-uretim_yeri.
    lv_pos   = is_kasa-fk_pos.
    lv_date  = |{ is_kasa-tarih+0(4) }-{ is_kasa-tarih+4(2) }-{ is_kasa-tarih+6(2) }|.

    lv_sql =
      |SELECT ID, FK_STORE, FK_POS, TRANS_DATE, RECEIPT_BARCODE, PTYPE, STATUS | &&
      |FROM TRANSACTION_HEADER WITH (NOLOCK) | &&
      |WHERE FK_STORE = ? AND FK_POS = ? AND CONVERT(date, TRANS_DATE) = ? AND STATUS = 0 | &&
      |ORDER BY TRANS_DATE, ID|.

    DATA(lo_con) = cl_sql_connection=>get_connection( gc_dbcon_genius3 ).
    DATA(lo_stmt) = lo_con->create_statement( tab_name_for_trace = 'TRANSACTION_HEADER' ).

    lo_stmt->set_param( REF #( lv_store ) ).
    lo_stmt->set_param( REF #( lv_pos ) ).
    lo_stmt->set_param( REF #( lv_date ) ).

    DATA(lo_res) = lo_stmt->execute_query( lv_sql ).

    lo_res->set_param_table( REF #( rt_headers ) ).
    lo_res->next_package( ).
    lo_res->close( ).

  ENDMETHOD.

  METHOD check_header_missing.

    CLEAR rv_reason.

    IF has_genius_rows(
         iv_table     = 'TRANSACTION_SALE'
         iv_header_id = is_header-id ) = abap_false.
      rv_reason = |SALE;|.
    ENDIF.

    IF is_header-ptype <> '7'
       AND has_genius_rows(
             iv_table     = 'TRANSACTION_PAYMENT'
             iv_header_id = is_header-id ) = abap_false.
      rv_reason = |{ rv_reason }PAY;|.
    ENDIF.

    IF has_genius_rows(
         iv_table     = 'TRANSACTION_RESULT'
         iv_header_id = is_header-id ) = abap_false.
      rv_reason = |{ rv_reason }RES;|.
    ENDIF.

  ENDMETHOD.

  METHOD has_genius_rows.

    DATA: lv_sql   TYPE string,
          lv_table TYPE string,
          lt_key   TYPE tt_genius_key.

    CLEAR rv_exists.

    CASE iv_table.
      WHEN 'TRANSACTION_SALE' OR 'TRANSACTION_PAYMENT' OR 'TRANSACTION_RESULT'.
        lv_table = iv_table.
      WHEN OTHERS.
        RETURN.
    ENDCASE.

    lv_sql = |SELECT TOP 1 ID FROM { lv_table } WITH (NOLOCK) WHERE FK_TRANSACTION_HEADER = ?|.

    DATA(lo_con) = cl_sql_connection=>get_connection( gc_dbcon_genius3 ).
    DATA(lo_stmt) = lo_con->create_statement( tab_name_for_trace = conv TABNAME( lv_table ) ).

    lo_stmt->set_param( REF #( iv_header_id ) ).

    DATA(lo_res) = lo_stmt->execute_query( lv_sql ).
    lo_res->set_param_table( REF #( lt_key ) ).
    lo_res->next_package( ).
    lo_res->close( ).

    rv_exists = xsdbool( lt_key IS NOT INITIAL ).
  ENDMETHOD.

  METHOD fetch_genius_bw.

    DATA: lv_sql   TYPE string,
          lv_d1    TYPE string,
          lv_d2    TYPE string,
          lv_where TYPE string,
          lt_or    TYPE TABLE OF string,
          lv_line  TYPE string,
          ls_r     LIKE LINE OF s_retail.

    lv_d1 = |{ p_begda+0(4) }-{ p_begda+4(2) }-{ p_begda+6(2) }|.
    lv_d2 = |{ p_endda+0(4) }-{ p_endda+4(2) }-{ p_endda+6(2) }|.

    CLEAR lt_or.
    LOOP AT s_retail INTO ls_r WHERE sign = 'I'.
      CASE ls_r-option.
        WHEN 'EQ'.
          IF ls_r-low CO '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
            APPEND |[ÜRETİM YERİ] = '{ ls_r-low }'| TO lt_or.
          ENDIF.
        WHEN 'BT'.
          IF ls_r-low CO '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
             AND ls_r-high CO '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
            APPEND |[ÜRETİM YERİ] BETWEEN '{ ls_r-low }' AND '{ ls_r-high }'| TO lt_or.
          ENDIF.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.

    IF lt_or IS NOT INITIAL.
      lv_where = | AND ( |.
      LOOP AT lt_or INTO lv_line.
        IF sy-tabix > 1.
          lv_where = lv_where && | OR |.
        ENDIF.
        lv_where = lv_where && lv_line.
      ENDLOOP.
      lv_where = lv_where && | )|.
    ENDIF.

    lv_sql = |SELECT [MAĞAZA ADI] AS MAGAZA, [ÜRETİM YERİ] AS WERKS, [FK_POS] AS FK_POS, | &&
             |[KASA NO] AS KASA, [İP ADRESİ] AS IP, CONVERT(varchar(10),[TARİH],23) AS TDATE, | &&
             |CAST([SATIŞ TOPLAM] AS nvarchar(50)) AS SATIS, CAST([IADE] AS nvarchar(50)) AS IADE | &&
             |FROM [Genius3].[GENIUS3].[VW_BW_SALES_CONTROL] | &&
             |WHERE CONVERT(date,[TARİH]) BETWEEN '{ lv_d1 }' AND '{ lv_d2 }'| &&
             lv_where.

    CLEAR rt_bw.

    DATA(lo_con) = cl_sql_connection=>get_connection( gc_dbcon_genius3 ).
    DATA(lo_stmt) = lo_con->create_statement( tab_name_for_trace = 'VW_BW_SALES_CONTROL' ).
    DATA(lo_res) = lo_stmt->execute_query( lv_sql ).

    lo_res->set_param_table( REF #( rt_bw ) ).
    lo_res->next_package( ).
    lo_res->close( ).

  ENDMETHOD.

  METHOD build_sap_aggregates.

    DATA: lt_tf  TYPE STANDARD TABLE OF /posdw/tlogf WITH DEFAULT KEY,
          lt_ts  TYPE STANDARD TABLE OF /posdw/tstat WITH DEFAULT KEY,
          lv_exc TYPE abap_bool,
          ls_tf  TYPE /posdw/tlogf,
          ls_ts  TYPE /posdw/tstat,
          lv_amt TYPE /posdw/transturnover.

    FIELD-SYMBOLS <agg> TYPE ty_sap_agg.

    CLEAR rt_agg.

    IF s_retail[] IS INITIAL.
      SELECT * FROM /posdw/tlogf
        WHERE recordqualifier = 1
          AND transtypecode <> '1002'
          AND businessdaydate BETWEEN @p_begda AND @p_endda
        INTO TABLE @lt_tf.
    ELSE.
      SELECT * FROM /posdw/tlogf
        WHERE recordqualifier = 1
          AND transtypecode <> '1002'
          AND businessdaydate BETWEEN @p_begda AND @p_endda
          AND retailstoreid IN @s_retail
        INTO TABLE @lt_tf.
    ENDIF.

    IF s_retail[] IS INITIAL.
      SELECT * FROM /posdw/tstat
        WHERE taskstatus <> '4'
          AND businessdaydate BETWEEN @p_begda AND @p_endda
        INTO TABLE @lt_ts.
    ELSE.
      SELECT * FROM /posdw/tstat
        WHERE taskstatus <> '4'
          AND businessdaydate BETWEEN @p_begda AND @p_endda
          AND retailstoreid IN @s_retail
        INTO TABLE @lt_ts.
    ENDIF.

    LOOP AT lt_tf INTO ls_tf.
      lv_exc = abap_false.
      LOOP AT lt_ts INTO ls_ts
        WHERE retailstoreid = ls_tf-retailstoreid
          AND businessdaydate = ls_tf-businessdaydate.
        IF ls_tf-transindex >= ls_ts-transindexbegin
           AND ls_tf-transindex <= ls_ts-transindexend.
          lv_exc = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_exc = abap_true.
        CONTINUE.
      ENDIF.

      READ TABLE rt_agg ASSIGNING <agg>
        WITH TABLE KEY
          retailstoreid   = ls_tf-retailstoreid
          businessdaydate = ls_tf-businessdaydate
          workstationid   = ls_tf-workstationid.
      IF sy-subrc <> 0.
        INSERT VALUE #(
          retailstoreid   = ls_tf-retailstoreid
          businessdaydate = ls_tf-businessdaydate
          workstationid   = ls_tf-workstationid
          sale_sum        = 0
          ref_sum         = 0 ) INTO TABLE rt_agg ASSIGNING <agg>.
      ENDIF.

      IF ls_tf-transtypecode = '9001'.
        lv_amt = abs( ls_tf-turnover ).
        <agg>-ref_sum = <agg>-ref_sum + lv_amt.
      ELSE.
        <agg>-sale_sum = <agg>-sale_sum + ls_tf-turnover.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD compare_bw_sap.

    DATA: ls_bw  TYPE ty_bw_sql,
          ls_err TYPE ty_kasa_err,
          lv_r   TYPE /posdw/tlogf-retailstoreid,
          lv_w   TYPE /posdw/tlogf-workstationid,
          lv_b   TYPE /posdw/tlogf-businessdaydate,
          lv_sbw TYPE /posdw/transturnover,
          lv_ibw TYPE /posdw/transturnover.

    FIELD-SYMBOLS <agg> TYPE ty_sap_agg.

    CLEAR rt_diff.

    LOOP AT it_bw INTO ls_bw.
      CLEAR: ls_err, lv_r, lv_w, lv_b, lv_sbw, lv_ibw.

      ls_err-magaza_adi  = ls_bw-magaza.
      ls_err-uretim_yeri = ls_bw-werks.
      ls_err-fk_pos      = ls_bw-fk_pos.
      ls_err-kasa_no     = ls_bw-kasa.
      ls_err-ip_adresi   = ls_bw-ip.
      ls_err-tarih       = parse_sql_date( ls_bw-tdate ).
      lv_sbw = parse_dec_string( ls_bw-satis ).
      lv_ibw = parse_dec_string( ls_bw-iade ).
      ls_err-satis_bw = lv_sbw.
      ls_err-iade_bw  = lv_ibw.

      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = ls_bw-werks
        IMPORTING
          output = lv_r.

      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = ls_bw-kasa
        IMPORTING
          output = lv_w.

      lv_b = ls_err-tarih.

      READ TABLE it_agg ASSIGNING <agg>
        WITH TABLE KEY
          retailstoreid   = lv_r
          businessdaydate = lv_b
          workstationid   = lv_w.
      IF sy-subrc = 0.
        ls_err-satis_sap = <agg>-sale_sum.
        ls_err-iade_sap  = <agg>-ref_sum.
      ELSE.
        CLEAR: ls_err-satis_sap, ls_err-iade_sap.
      ENDIF.

      ls_err-diff_satis = ls_err-satis_bw - ls_err-satis_sap.
      ls_err-diff_iade  = ls_err-iade_bw - ls_err-iade_sap.

      IF abs( ls_err-diff_satis ) > gc_tol OR abs( ls_err-diff_iade ) > gc_tol.
        APPEND ls_err TO rt_diff.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD parse_sql_date.
    DATA: lv_src  TYPE string,
          lv_date TYPE string.

    CLEAR rv_datum.
    lv_src = iv_str.
    CONDENSE lv_src NO-GAPS.

    IF lv_src IS INITIAL.
      RETURN.
    ENDIF.

    IF strlen( lv_src ) >= 10.
      lv_date = lv_src(10).
    ELSE.
      lv_date = lv_src.
    ENDIF.

    TRY.
        IF strlen( lv_date ) = 10
           AND lv_date+4(1) = '-'
           AND lv_date+7(1) = '-'.

          " YYYY-MM-DD
          rv_datum = lv_date+0(4) && lv_date+5(2) && lv_date+8(2).

        ELSEIF strlen( lv_date ) = 10
           AND ( lv_date+2(1) = '.' OR lv_date+2(1) = '/' )
           AND ( lv_date+5(1) = '.' OR lv_date+5(1) = '/' ).

          " DD.MM.YYYY or DD/MM/YYYY
          rv_datum = lv_date+6(4) && lv_date+3(2) && lv_date+0(2).

        ELSEIF strlen( lv_date ) = 8
           AND lv_date CO '0123456789'.

          " YYYYMMDD or DDMMYYYY
          IF lv_date+0(4) BETWEEN '1900' AND '2999'.
            rv_datum = lv_date.
          ELSE.
            rv_datum = lv_date+4(4) && lv_date+2(2) && lv_date+0(2).
          ENDIF.
        ENDIF.
      CATCH cx_root.
        CLEAR rv_datum.
    ENDTRY.

    IF rv_datum IS NOT INITIAL.
      CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
        EXPORTING
          date                      = rv_datum
        EXCEPTIONS
          plausibility_check_failed = 1
          OTHERS                    = 2.
      IF sy-subrc <> 0.
        CLEAR rv_datum.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD parse_sql_time.
    DATA lv_src TYPE string.

    CLEAR rv_uzeit.
    lv_src = iv_str.
    CONDENSE lv_src.

    TRY.
        IF strlen( lv_src ) >= 19
           AND lv_src+4(1) = '-'
           AND lv_src+7(1) = '-'
           AND ( lv_src+10(1) = space OR lv_src+10(1) = 'T' ).

          rv_uzeit = lv_src+11(2) && lv_src+14(2) && lv_src+17(2).

        ELSEIF strlen( lv_src ) >= 19
           AND ( lv_src+2(1) = '.' OR lv_src+2(1) = '/' )
           AND ( lv_src+5(1) = '.' OR lv_src+5(1) = '/' )
           AND ( lv_src+10(1) = space OR lv_src+10(1) = 'T' ).

          rv_uzeit = lv_src+11(2) && lv_src+14(2) && lv_src+17(2).
        ENDIF.
      CATCH cx_root.
        CLEAR rv_uzeit.
    ENDTRY.
  ENDMETHOD.

  METHOD parse_dec_string.
    DATA lv TYPE string.
    lv = iv_str.
    CONDENSE lv.
    REPLACE ALL OCCURRENCES OF ',' IN lv WITH '.'.
    TRY.
        rv_dec = CONV /posdw/transturnover( CONV decfloat34( lv ) ).
      CATCH cx_root.
        CLEAR rv_dec.
    ENDTRY.
  ENDMETHOD.

  METHOD build_notification_email.

    DATA: lv_row TYPE string,
          ls_inv TYPE ty_inv_err,
          ls_ka  TYPE ty_kasa_err,
          lv_dat TYPE char10,
          lv_dt  TYPE string,
          lv_tm  TYPE string,
          lv_sub TYPE string.

    CLEAR: ev_html, ev_subject.

    lv_dt = |{ sy-datum DATE = ISO }|.
    lv_tm = |{ sy-uzeit TIME = ISO }|.
    lv_sub = |{ text-m05 } — { lv_dt }|.
    IF strlen( sy-sysid ) >= 3 AND sy-sysid+2(1) <> 'P'.
      lv_sub = |[{ sy-sysid }] { lv_sub }|.
    ENDIF.
    ev_subject = CONV so_obj_des( lv_sub ).

    ev_html =
      |<html><head><style>| &&
      |body \{ font-family: Arial,sans-serif; font-size:10pt; \}| &&
      |table \{ border-collapse:collapse; width:100%; max-width:960px; \}| &&
      |th,td \{ border:1px solid #333; padding:4px; text-align:left; \}| &&
      |.h \{ background:#eee; font-weight:bold; \}| &&
      |</style></head><body><p>| &&
      |{ text-m01 } { lv_dt } { lv_tm }| &&
      |</p>|.

    ev_html = ev_html && |<p class="h">| &&
      text-m02 &&
      |</p><table><tr class="h">| &&
      |<td>| && text-f01 && |</td>| &&
      |<td>| && text-f02 && |</td>| &&
      |<td>| && text-f03 && |</td>| &&
      |<td>| && text-f04 && |</td>| &&
      |<td>| && text-f05 && |</td>| &&
      |<td>| && text-f06 && |</td>| &&
      |<td>| && text-f07 && |</td>| &&
      |<td>| && text-f08 && |</td>| &&
      |<td>| && text-f09 && |</td></tr>|.

    IF gt_inv IS INITIAL.
      ev_html = ev_html && |<tr><td colspan="9">| &&
        text-m03 && |</td></tr>|.
    ELSE.
      LOOP AT gt_inv INTO ls_inv.
        WRITE ls_inv-trans_date TO lv_dat.
        lv_row = |<tr><td>{ lcl_technical=>escape_html( CONV string( lv_dat ) ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( |{ ls_inv-trans_time TIME = ISO }| ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( ls_inv-go_trans_id ) ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( ls_inv-receipt_barcode ) ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( ls_inv-fk_store ) ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( ls_inv-fk_pos ) ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( |{ ls_inv-businessdaydate DATE = ISO }| ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( ls_inv-retailstoreid ) ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( ls_inv-reason ) ) }</td></tr>|.
        ev_html = ev_html && lv_row.
      ENDLOOP.
    ENDIF.
    ev_html = ev_html && |</table>|.

    ev_html = ev_html && |<p class="h">| &&
      text-m04 &&
      |</p><table><tr class="h">| &&
      |<td>| && text-f10 && |</td>| &&
      |<td>| && text-f11 && |</td>| &&
      |<td>| && text-f12 && |</td>| &&
      |<td>| && text-f13 && |</td>| &&
      |<td>| && text-f14 && |</td>| &&
      |<td>| && text-f15 && |</td>| &&
      |<td>| && text-f16 && |</td>| &&
      |<td>| && text-f17 && |</td>| &&
      |<td>| && text-f18 && |</td>| &&
      |<td>| && text-f19 && |</td>| &&
      |<td>| && text-f20 && |</td>| &&
      |<td>| && text-f21 && |</td></tr>|.

    IF gt_kasa IS INITIAL.
      ev_html = ev_html && |<tr><td colspan="13">| &&
        text-m03 && |</td></tr>|.
    ELSE.
      LOOP AT gt_kasa INTO ls_ka.
        WRITE ls_ka-tarih TO lv_dat.
        lv_row = |<tr><td>{ lcl_technical=>escape_html( ls_ka-magaza_adi ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( ls_ka-uretim_yeri ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( ls_ka-fk_pos ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( ls_ka-kasa_no ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( ls_ka-ip_adresi ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( lv_dat ) ) }</td>| &&
                 |<td>{ ls_ka-satis_bw }</td><td>{ ls_ka-satis_sap }</td><td>{ ls_ka-diff_satis }</td>| &&
                 |<td>{ ls_ka-iade_bw }</td><td>{ ls_ka-iade_sap }</td><td>{ ls_ka-diff_iade }</td></tr>|.
        ev_html = ev_html && lv_row.
      ENDLOOP.
    ENDIF.

    ev_html = ev_html && |</table></body></html>|.

  ENDMETHOD.

ENDCLASS.