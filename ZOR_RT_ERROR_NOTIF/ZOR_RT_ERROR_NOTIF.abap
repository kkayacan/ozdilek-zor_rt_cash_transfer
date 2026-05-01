REPORT zor_rt_error_notif MESSAGE-ID zor_rt.

INCLUDE zor_rt_error_notif_top.

LOAD-OF-PROGRAM.
  lcl_controller=>load_of_program( ).

INITIALIZATION.
  lcl_controller=>initialization( ).

AT SELECTION-SCREEN OUTPUT.
  lcl_controller=>at_selection_screen_output( ).

START-OF-SELECTION.
  lcl_controller=>start_of_selection( ).

END-OF-SELECTION.
  lcl_controller=>end_of_selection( ).

INCLUDE zor_rt_error_notif_o01.    " PBO-Modules
INCLUDE zor_rt_error_notif_i01.    " PAI-Modules
INCLUDE zor_rt_error_notif_p00.    " Controller class implementation
INCLUDE zor_rt_error_notif_p01.    " Business model class implementations
INCLUDE zor_rt_error_notif_p02.    " Technical utility class implementations