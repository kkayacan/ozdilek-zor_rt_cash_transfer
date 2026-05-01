*&---------------------------------------------------------------------*
*& Include ZOR_RT_ERROR_NOTIF_P00 — Controller class implementation
*&---------------------------------------------------------------------*
CLASS lcl_controller IMPLEMENTATION.

  METHOD load_of_program.
  ENDMETHOD.

  METHOD initialization.
  ENDMETHOD.

  METHOD at_selection_screen_output.
    DATA: ls_dummy TYPE screen,
          lv_g     TYPE c LENGTH 4.
    LOOP AT SCREEN INTO ls_dummy.
      lv_g = ls_dummy-group1.
      TRANSLATE lv_g TO UPPER CASE.
      IF lv_g = 'LST' AND p_mail = 'X'.
        ls_dummy-invisible = '1'.
        MODIFY SCREEN FROM ls_dummy.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD start_of_selection.
    lcl_business=>validate_selection( ).
  ENDMETHOD.

  METHOD end_of_selection.
    lcl_business=>refresh_data( ).
    IF p_mail = 'X'.
      DATA: lv_html    TYPE string,
            lv_subject TYPE so_obj_des,
            lv_k_cnt   TYPE i,
            lv_i_cnt   TYPE i.

      CALL METHOD lcl_business=>build_notification_email
        IMPORTING
          ev_html    = lv_html
          ev_subject = lv_subject.
      CALL METHOD lcl_technical=>send_html_mail
        EXPORTING
          iv_html    = lv_html
          iv_subject = lv_subject.

      lv_k_cnt = lines( lcl_business=>gt_kasa ).
      lv_i_cnt = lines( lcl_business=>gt_inv ).

      WRITE: / 'ZOR_RT_ERROR_NOTIF — E-Posta Gönderim Logu'.
      WRITE: / sy-uline.
      WRITE: / 'Kontrol Edilen Dönem :', p_begda, '-', p_endda.
      WRITE: / 'Fark Bulunan Kasa Sayısı :', lv_k_cnt.
      WRITE: / 'Eksik Tablolu Fiş Sayısı :', lv_i_cnt.
      WRITE: / sy-uline.
      WRITE: / 'Gönderilen e-posta konusu:', lv_subject.
      WRITE: / 'İşlem tamamlandı, e-posta gönderildi.'.

      RETURN.
    ENDIF.
    IF p_disp = 'X' AND sy-batch IS INITIAL.
      CALL SCREEN 0001.
    ENDIF.
  ENDMETHOD.

  METHOD pbo.
    CASE sy-dynnr.
      WHEN '0001'.
        SET PF-STATUS '0100'.
        SET TITLEBAR 'T01'.
        display_alv( p_fis ).
    ENDCASE.
  ENDMETHOD.

  METHOD pai.
    IF go_grid IS BOUND.
      go_grid->check_changed_data( ).
    ENDIF.
    CASE sy-dynnr.
      WHEN '0001'.
        CASE sy-ucomm.
          WHEN 'BACK'.
            free_alv_controls( ).
            SET SCREEN 0.
          WHEN 'EXIT' OR 'CANC'.
            free_alv_controls( ).
            LEAVE PROGRAM.
        ENDCASE.
    ENDCASE.
  ENDMETHOD.

  METHOD exclude_toolbar.
    APPEND '&DETAIL' TO ct_excl.
    APPEND '&SORT_ASC' TO ct_excl.
    APPEND '&SORT_DSC' TO ct_excl.
    APPEND '&FIND' TO ct_excl.
    APPEND cl_gui_alv_grid=>mc_mb_filter TO ct_excl.
    APPEND cl_gui_alv_grid=>mc_mb_sum TO ct_excl.
    APPEND cl_gui_alv_grid=>mc_mb_subtot TO ct_excl.
    APPEND '&VEXCEL' TO ct_excl.
  ENDMETHOD.

  METHOD build_fcat.
    DATA: lo_salv TYPE REF TO cl_salv_table,
          lr_list TYPE REF TO data,
          lo_cols TYPE REF TO cl_salv_columns_table,
          lo_aggs TYPE REF TO cl_salv_aggregations.
    FIELD-SYMBOLS: <lt> TYPE ANY TABLE,
                   <fc> TYPE lvc_s_fcat.

    CREATE DATA lr_list LIKE it_table.
    ASSIGN lr_list->* TO <lt>.

    cl_salv_table=>factory(
      IMPORTING
        r_salv_table = lo_salv
      CHANGING
        t_table      = <lt> ).

    lo_cols = lo_salv->get_columns( ).
    lo_aggs = lo_salv->get_aggregations( ).
    rt_fcat = cl_salv_controller_metadata=>get_lvc_fieldcatalog(
      r_columns      = lo_cols
      r_aggregations = lo_aggs ).

    LOOP AT rt_fcat ASSIGNING <fc>.
      <fc>-no_sign = abap_false.
    ENDLOOP.
  ENDMETHOD.

  METHOD apply_alv_field_labels.
    DATA lv_fn TYPE char30.
    FIELD-SYMBOLS <fc> TYPE lvc_s_fcat.

    LOOP AT ct_fcat ASSIGNING <fc>.
      lv_fn = <fc>-fieldname.
      TRANSLATE lv_fn TO UPPER CASE.

      IF lv_fn = 'MANDT'.
        <fc>-tech = abap_true.
        CONTINUE.
      ENDIF.

      IF iv_fis = 'X'.
        CASE lv_fn.
          WHEN 'TRANS_DATE'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f01.
            <fc>-reptext = <fc>-coltext.
            <fc>-datatype = 'DATS'.
            <fc>-inttype  = 'D'.
            <fc>-outputlen = 10.
            CLEAR: <fc>-currency, <fc>-cfieldname, <fc>-quantity, <fc>-qfieldname,
                   <fc>-ref_table, <fc>-ref_field.
          WHEN 'TRANS_TIME'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f02.
            <fc>-reptext = <fc>-coltext.
            <fc>-datatype = 'TIMS'.
            <fc>-inttype  = 'T'.
            <fc>-outputlen = 8.
            CLEAR: <fc>-currency, <fc>-cfieldname, <fc>-quantity, <fc>-qfieldname,
                   <fc>-ref_table, <fc>-ref_field.
          WHEN 'GO_TRANS_ID'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f03.
            <fc>-reptext = <fc>-coltext.
          WHEN 'RECEIPT_BARCODE'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f04.
            <fc>-reptext = <fc>-coltext.
          WHEN 'FK_STORE'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f05.
            <fc>-reptext = <fc>-coltext.
          WHEN 'FK_POS'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f06.
            <fc>-reptext = <fc>-coltext.
          WHEN 'BUSINESSDAYDATE'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f07.
            <fc>-reptext = <fc>-coltext.
            <fc>-datatype = 'DATS'.
            <fc>-inttype  = 'D'.
            <fc>-outputlen = 10.
            CLEAR: <fc>-currency, <fc>-cfieldname, <fc>-quantity, <fc>-qfieldname,
                   <fc>-ref_table, <fc>-ref_field.
          WHEN 'RETAILSTOREID'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f08.
            <fc>-reptext = <fc>-coltext.
          WHEN 'GROSS_TOTAL'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f24.
            <fc>-reptext = <fc>-coltext.
            <fc>-decimals_o = 2.
          WHEN 'REASON'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f09.
            <fc>-reptext = <fc>-coltext.
        ENDCASE.
      ELSE.
        CASE lv_fn.
          WHEN 'MAGAZA_ADI'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f10.
            <fc>-reptext = <fc>-coltext.
          WHEN 'URETIM_YERI'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f11.
            <fc>-reptext = <fc>-coltext.
          WHEN 'FK_POS'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f12.
            <fc>-reptext = <fc>-coltext.
          WHEN 'KASA_NO'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f13.
            <fc>-reptext = <fc>-coltext.
          WHEN 'IP_ADRESI'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f14.
            <fc>-reptext = <fc>-coltext.
          WHEN 'TARIH'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f15.
            <fc>-reptext = <fc>-coltext.
            <fc>-datatype = 'DATS'.
            <fc>-inttype  = 'D'.
            <fc>-outputlen = 10.
            CLEAR: <fc>-currency, <fc>-cfieldname, <fc>-quantity, <fc>-qfieldname,
                   <fc>-ref_table, <fc>-ref_field.
          WHEN 'SATIS_BW'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f16.
            <fc>-reptext = <fc>-coltext.
            <fc>-decimals_o = 2.
          WHEN 'SATIS_SAP'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f17.
            <fc>-reptext = <fc>-coltext.
            <fc>-decimals_o = 2.
          WHEN 'DIFF_SATIS'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f18.
            <fc>-reptext = <fc>-coltext.
            <fc>-decimals_o = 2.
          WHEN 'IADE_BW'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f19.
            <fc>-reptext = <fc>-coltext.
            <fc>-decimals_o = 2.
          WHEN 'IADE_SAP'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f20.
            <fc>-reptext = <fc>-coltext.
            <fc>-decimals_o = 2.
          WHEN 'DIFF_IADE'.
            <fc>-scrtext_s = <fc>-scrtext_m = <fc>-scrtext_l = <fc>-coltext = text-f21.
            <fc>-reptext = <fc>-coltext.
            <fc>-decimals_o = 2.
        ENDCASE.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD display_alv.
    DATA: lt_fcat TYPE lvc_t_fcat,
          ls_stbl TYPE lvc_s_stbl.

    CLEAR gt_excl.
    exclude_toolbar( CHANGING ct_excl = gt_excl ).

    IF iv_fis = 'X'.
      lt_fcat = build_fcat( lcl_business=>gt_inv ).
    ELSE.
      lt_fcat = build_fcat( lcl_business=>gt_kasa ).
    ENDIF.

    apply_alv_field_labels(
      EXPORTING
        iv_fis = iv_fis
      CHANGING
        ct_fcat = lt_fcat ).

    IF go_grid IS NOT BOUND.

      CREATE OBJECT go_grid
        EXPORTING
          i_lifetime        = cl_gui_control=>lifetime_dynpro
          i_parent          = cl_gui_custom_container=>screen0
          i_appl_events     = abap_true
        EXCEPTIONS
          error_cntl_create = 1
          error_cntl_init   = 2
          error_cntl_link   = 3
          error_dp_create   = 4
          OTHERS            = 5.
      CHECK sy-subrc = 0.

      CLEAR gs_layo.
      gs_layo-cwidth_opt = abap_true.
      gs_layo-sel_mode   = 'B'.
      gs_layo-no_rowmark = abap_true.

      IF iv_fis = 'X'.
        go_grid->set_table_for_first_display(
          EXPORTING
            is_layout                     = gs_layo
            it_toolbar_excluding          = gt_excl
          CHANGING
            it_outtab                     = lcl_business=>gt_inv
            it_fieldcatalog               = lt_fcat
          EXCEPTIONS
            invalid_parameter_combination = 1
            program_error                 = 2
            too_many_lines                = 3
            OTHERS                        = 4 ).
      ELSE.
        go_grid->set_table_for_first_display(
          EXPORTING
            is_layout                     = gs_layo
            it_toolbar_excluding          = gt_excl
          CHANGING
            it_outtab                     = lcl_business=>gt_kasa
            it_fieldcatalog               = lt_fcat
          EXCEPTIONS
            invalid_parameter_combination = 1
            program_error                 = 2
            too_many_lines                = 3
            OTHERS                        = 4 ).
      ENDIF.

    ELSE.

      go_grid->set_frontend_fieldcatalog( lt_fcat ).
      go_grid->set_frontend_layout( gs_layo ).

      ls_stbl-row = abap_true.
      ls_stbl-col = abap_true.
      go_grid->refresh_table_display(
        EXPORTING
          is_stable = ls_stbl
        EXCEPTIONS
          finished  = 1
          OTHERS    = 2 ).

    ENDIF.
  ENDMETHOD.

  METHOD free_alv_controls.
    IF go_grid IS BOUND.
      go_grid->free( ).
      CLEAR go_grid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.