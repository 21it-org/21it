#!/bin/bash

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


# -----------------
# Exec command
# -----------------

# BASE COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:booking_req"

# form type check
form_chk=`$META chk.form:request.db`
if [ "$form_chk" = "multipart" ];then
  file_key=`cat /var/www/tmp/$session/binary_file/input_name`
  cat /var/www/tmp/$session/binary_file/file_name > /var/www/tmp/$session/$file_key 2>/dev/null
fi

# check posted param
if [ -d /var/www/tmp/$session ];then
  keys=`ls /var/www/tmp/$session | grep -v binary_file | $SED -z "s/\n/,/g" | $SED "s/,$//g"`
else
  echo "error: No param posted"
  exit 1
fi

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

# push datas to databox
#$DATA_SHELL databox:request.db action:set id:$id keys:$keys input_dir:/var/www/tmp/$session  > /var/www/tmp/$session/result

# result check
#updated_id=`cat /var/www/tmp/$session/result | grep "^successfully set" | $AWK -F "id:" '{print $2}' | $SED '/^$/d' | sort | uniq`

# load book resource
book_name=`cat ../tmp/$session/book_name`
resource_id=`$DATA_SHELL databox:book.res command:show_all[match=name{$book_name}][filter=status{on{%%%%%%%}the{%%%%%%%}shelve}] format:json \
| jq '.[] | .id'| $SED -s "s/\"//g" | head -1`

if [ "$resource_id" ];then
  # push datas to databox
  echo "$resource_id" > ../tmp/$session/book_resource_id
  echo "requested" > ../tmp/$session/status
  keys="book_resource_id,status,$keys"
  $DATA_SHELL databox:request.db action:set id:new keys:$keys input_dir:../tmp/$session  > ../tmp/$session/result

  # result check
  updated_id=`cat ../tmp/$session/result | grep "^successfully set" | $AWK -F "id:" '{print $2}' | $SED '/^$/d' | sort | uniq`
  avail_num=`$DATA_SHELL databox:book.res command:show_all[match=name{$book_name}][filter=status{on{%%%%%%%}the{%%%%%%%}shelve}] format:none | wc -l`

  if [ "$updated_id" -a $avail_num -ge 1 ];then
    # update staus of resource.db
    $DATA_SHELL databox:book.res action:set id:$resource_id key:status value:reserved  >> ../tmp/$session/result

    # update status of book.master
    (( avail_num -= 1 ))
    if [ $avail_num -eq 0 ];then
      book_master_id=`$DATA_SHELL databox:book.master command:show_all[match=name{$book_name}] format:json | jq '.[] | .id'| $SED -s "s/\"//g"`
      $DATA_SHELL databox:book.master action:set id:$book_master_id key:available value:-  >> ../tmp/$session/result
    fi
  fi
fi

# set message
if [ "$updated_id" ];then
  echo "<h2>SUCCESSFULLY SUBMITTED</h2>" > /var/www/tmp/$session/message
  echo "<a href=\"./booking_req?req=get&id=$updated_id\"><p><b>YOUR LINK</b></p></a>" >> /var/www/tmp/$session/message
else
  echo "<h2>Failed, something is wrong. please contact to your web admin</h2>" > /var/www/tmp/$session/message
fi

# -----------------
# render HTML
# -----------------
cat /var/www/descriptor/booking_req_set.html.def | $SED -r "s/^( *)</</1" \
| $SED "/%%message/r /var/www/tmp/$session/message" \
| $SED "s/%%message/$message/g" \
| $SED "s/%%id/$updated_id/g"

if [ "$session" ];then
  rm -rf /var/www/tmp/$session
fi

exit 0
