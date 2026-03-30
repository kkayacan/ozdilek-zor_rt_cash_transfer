*&---------------------------------------------------------------------*
*& Include ZOR_RT_ERROR_NOTIF_D00 — Controller class definition
*&---------------------------------------------------------------------*
*& lcl_business / lcl_technical tam tanımları D01, D02 (ön bildirim burada).
*&---------------------------------------------------------------------*
CLASS lcl_business DEFINITION DEFERRED.
CLASS lcl_technical DEFINITION DEFERRED.

CLASS lcl_controller DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS:
      load_of_program,
      initialization,
      at_selection_screen_output,
      start_of_selection,
      end_of_selection,
      pbo,
      pai.

  PRIVATE SECTION.

    CLASS-DATA:
      go_grid TYPE REF TO cl_gui_alv_grid,
      gs_layo TYPE lvc_s_layo,
      gt_excl TYPE ui_functions.

    CLASS-METHODS:
      exclude_toolbar
        CHANGING
          ct_excl TYPE ui_functions,
      build_fcat
        IMPORTING it_table       TYPE ANY TABLE
        RETURNING VALUE(rt_fcat) TYPE lvc_t_fcat,
      display_alv
        IMPORTING
          iv_fis TYPE char1,
      free_alv_controls.

ENDCLASS.
