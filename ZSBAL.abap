*&---------------------------------------------------------------------*
*&  Include           ZSBAL
*&---------------------------------------------------------------------*
DATA:
  gv_handle TYPE balloghndl,
  gs_msg    TYPE bal_s_msg,
  g_s_log   TYPE bal_s_log,
  extnumber TYPE balnrext,
  subobject TYPE balsubobj.
*&---------------------------------------------------------------------*
*& Form LOG_CREATE
*&---------------------------------------------------------------------*
* text
*----------------------------------------------------------------------*
* --> p1 text
* <-- p2 text
*----------------------------------------------------------------------*
FORM log_create USING p_extnumber p_object p_subobject
 CHANGING e_handle TYPE balloghndl.
  g_s_log-extnumber = p_extnumber.
  g_s_log-object = p_object.
  g_s_log-subobject = p_subobject.
  g_s_log-aldate = sy-datum.
  g_s_log-altime = sy-uzeit.
  g_s_log-aluser = sy-uname.
  g_s_log-alprog = sy-repid.
  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      i_s_log      = g_s_log
    IMPORTING
      e_log_handle = e_handle
    EXCEPTIONS
      OTHERS       = 1.
ENDFORM. " LOG_CREATE
*&---------------------------------------------------------------------*
*& Form LOG_MSG
*&---------------------------------------------------------------------*
* text
*----------------------------------------------------------------------*
* --> p1 text
* <-- p2 text
*----------------------------------------------------------------------*
FORM log_msg USING p_msgty
 p_msgid
 p_msgno
 p_msgv1
 p_msgv2
 p_msgv3
 p_msgv4
 p_handle .
  CLEAR gs_msg .
  gs_msg-msgty = p_msgty.
  gs_msg-msgid = p_msgid.
  gs_msg-msgno = p_msgno.
  gs_msg-msgv1 = p_msgv1.
  gs_msg-msgv2 = p_msgv2.
  gs_msg-msgv3 = p_msgv3.
  gs_msg-msgv4 = p_msgv4.

  gs_msg-detlevel = 1.
  gs_msg-probclass = 2.
  CALL FUNCTION 'BAL_LOG_MSG_ADD'
    EXPORTING
      i_s_msg       = gs_msg
      i_log_handle  = p_handle
    EXCEPTIONS
      log_not_found = 1
      OTHERS        = 2.
ENDFORM. " LOG_MSG
*&---------------------------------------------------------------------*
*& Form LOG_SAVE
*&---------------------------------------------------------------------*
* text
*----------------------------------------------------------------------*
* --> p1 text
* <-- p2 text
*----------------------------------------------------------------------*
FORM log_save .

  DATA i_t_log_handle TYPE bal_t_logh.

  APPEND gv_handle TO i_t_log_handle.

  CALL FUNCTION 'BAL_DB_SAVE'
    EXPORTING
      i_t_log_handle   = i_t_log_handle
    EXCEPTIONS
      log_not_found    = 1
      save_not_allowed = 2
      numbering_error  = 3.

ENDFORM. " LOG_SAVE
