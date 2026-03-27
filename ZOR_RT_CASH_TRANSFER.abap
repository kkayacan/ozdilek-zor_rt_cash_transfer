*---------------------------------------------------------------------*
* Geliştirme Danışmanı    : Arif YILDIZ
* Uygulama Danışmanı      :
* Geliştirme No           :
* Tarih                   : 06.04.2017 11:40:01
* Referans Id             :
*---------------------------------------------------------------------*
* Değişiklik Günlüğü
*---------------------------------------------------------------------*
* Değişiklik/Request No   :
* Tarih                   :
* Geliştirme Danışmanı    :
*---------------------------------------------------------------------*
* t code dbco add
* db connection : GENIUS3  DMBS : MSS User Name : GENIUS3
* conn info :MSSQL_SERVER=172.21.10.29 MSSQL_DBNAME=Genius3

REPORT zor_rt_cash_transfer.
INCLUDE zor_rt_cash_transfer_top.
INCLUDE zsbal.
INCLUDE zor_rt_cash_transfer_d01.
INCLUDE zor_rt_cash_transfer_p01.

START-OF-SELECTION.

  go_interface = NEW lcl_file_interface( ).

  "Bağlantı aç
  go_interface->db_connection( ).

END-OF-SELECTION.

  PERFORM log_create USING space 'ZPOS' 'ZPOS_SQL'
                  CHANGING gv_handle.

  go_pipe_inbound = NEW lcl_pipe_inbound( ).

  "Veri alınıp internal tablolara dolduruluyor
  go_pipe_inbound->populate_bapi_from_go( ).

  gv_done = go_pipe_inbound->call_bapi( ).
  IF gv_done IS NOT INITIAL.
    go_interface->update_db( ).
*    go_interface->delete_db( ).
  ENDIF.
