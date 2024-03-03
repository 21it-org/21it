#!/bin/bash

# Target databox and keys
databox=book.res

# load small-shell conf
. /var/www/descriptor/.small_shell_conf

# load query string param
for param in `echo $@`
do

  if [[ $param == session:* ]]; then
    session=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == pin:* ]]; then
    pin=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | $AWK -F":" '{print $2}'`
  fi

done

# BASE COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:book_search"

# form type check
form_chk=`$META chk.form:$databox`
if [ "$form_chk" = "multipart" ];then
  file_key=`cat /var/www/tmp/$session/binary_file/input_name`
  cat /var/www/tmp/$session/binary_file/file_name > /var/www/tmp/$session/$file_key 2>/dev/null
fi


# check posted param
if [ -d /var/www/tmp/$session ];then
  keys=`ls /var/www/tmp/$session | $SED -z "s/\n/,/g" | $SED "s/,$//g" | $SED "s/binary_file//g"`
else
  echo "error: No param posted"
  exit 1
fi

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

# -----------------
# Exec command
# -----------------

# push datas to databox
$DATA_SHELL databox:$databox action:set id:$id keys:$keys input_dir:/var/www/tmp/$session  > /var/www/tmp/$session/result

error_chk=`grep "^error" /var/www/tmp/$session/result`

if [ "$error_chk" ];then
  cat /var/www/descriptor/location_search_set_err.html.def | $SED -r "s/^( *)</</1" \
  | $SED "/%%common_menu/r /var/www/descriptor/common_parts/book_search_common_menu" \
  | $SED "s/%%common_menu//g"\
  | $SED "/%%message/r /var/www/tmp/$session/result" \
  | $SED "/%%message/d"\
  | $SED "s/%%session/session=$session\&pin=$pin/g"
else
  # wait index update
  numcol=`$META get.header:${databox}{csv} | $SED "s/,/\n/g" | wc -l | tr -d " "`
  buffer=`expr $numcol / 8`
  index_update_time="0.$buffer"
  sleep $index_update_time

  # redirect to the table
  echo "<meta http-equiv=\"refresh\" content=\"0; url=./book_search?subapp=location_search&session=$session&pin=$pin&req=table\">"
fi

if [ "$session" ];then
  rm -rf /var/www/tmp/$session
fi

exit 0
