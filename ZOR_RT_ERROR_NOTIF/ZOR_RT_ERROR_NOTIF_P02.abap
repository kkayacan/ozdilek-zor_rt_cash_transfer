*&---------------------------------------------------------------------*
*& Include ZOR_RT_ERROR_NOTIF_P02 — Technical utility class implementations
*&---------------------------------------------------------------------*
CLASS lcl_technical IMPLEMENTATION.

  METHOD escape_html.
    rv_html = iv_str.
    REPLACE ALL OCCURRENCES OF '&' IN rv_html WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN rv_html WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN rv_html WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF `"` IN rv_html WITH '&quot;'.
  ENDMETHOD.

  METHOD send_html_mail.

    DATA: lo_send_request TYPE REF TO cl_bcs,
          lo_document     TYPE REF TO cl_document_bcs,
          lo_recipient    TYPE REF TO if_recipient_bcs,
          lt_body         TYPE soli_tab,
          lv_to           TYPE ad_smtpadr.

    lv_to = iv_to.
    IF lv_to IS INITIAL.
      lv_to = gc_email_to.
    ENDIF.

    TRY.
        lo_send_request = cl_bcs=>create_persistent( ).
        lt_body = cl_document_bcs=>string_to_soli( iv_html ).
        lo_document = cl_document_bcs=>create_document(
          i_type    = 'HTM'
          i_text    = lt_body
          i_subject = iv_subject ).
        lo_send_request->set_document( lo_document ).
        lo_recipient = cl_cam_address_bcs=>create_internet_address( lv_to ).
        lo_send_request->add_recipient( lo_recipient ).
        lo_send_request->send( i_with_error_screen = abap_false ).
        COMMIT WORK.
      CATCH cx_bcs INTO DATA(lx_bcs).
        ROLLBACK WORK.
        DATA lv_bcs TYPE string.
        lv_bcs = lx_bcs->get_text( ).
        MESSAGE e035 WITH lv_bcs.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
