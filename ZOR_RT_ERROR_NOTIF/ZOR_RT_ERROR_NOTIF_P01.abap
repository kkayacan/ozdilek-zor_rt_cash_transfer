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

    IF p_mail = 'X' OR p_fis = 'X'.
      fetch_invalid_trx( ).
    ENDIF.

    IF p_mail = 'X' OR p_kasa = 'X'.
      TRY.
          DATA(lt_bw) = fetch_genius_bw( ).
          DATA(lt_agg) = build_sap_aggregates( ).
          gt_kasa = compare_bw_sap( it_bw = lt_bw it_agg = lt_agg ).
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
          DATA(lv_err) TYPE c LENGTH 132.
          lv_err = lx_root->get_text( ).
          MESSAGE e007 WITH lv_err.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD fetch_invalid_trx.
    IF s_retail[] IS INITIAL.
      SELECT * FROM zor_rt_cash_inval
        WHERE businessdaydate BETWEEN @p_begda AND @p_endda
        ORDER BY erdat, erzet, go_trans_id
        INTO TABLE @gt_inv.
    ELSE.
      SELECT * FROM zor_rt_cash_inval
        WHERE businessdaydate BETWEEN @p_begda AND @p_endda
          AND retailstoreid IN @s_retail
        ORDER BY erdat, erzet, go_trans_id
        INTO TABLE @gt_inv.
    ENDIF.
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
    CLEAR rv_datum.
    IF strlen( iv_str ) < 10.
      RETURN.
    ENDIF.
    TRY.
        rv_datum = iv_str+0(4) && iv_str+5(2) && iv_str+8(2).
      CATCH cx_root.
        CLEAR rv_datum.
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
          ls_inv TYPE zor_rt_cash_inval,
          ls_ka  TYPE ty_kasa_err,
          lv_dat TYPE char10,
          lv_dt  TYPE string,
          lv_tm  TYPE string,
          lv_sub TYPE string.

    CLEAR: ev_html, ev_subject.

    lv_dt = |{ sy-datum DATE = ISO }|.
    lv_tm = |{ sy-uzeit TIME = ISO }|.
    lv_sub = |{ text-m00 } { lv_dt }|.
    ev_subject = CONV #( lv_sub(50) ).

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
        WRITE ls_inv-erdat TO lv_dat.
        lv_row = |<tr><td>{ lcl_technical=>escape_html( CONV string( lv_dat ) ) }</td>| &&
                 |<td>{ lcl_technical=>escape_html( CONV string( ls_inv-erzet ) ) }</td>| &&
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
