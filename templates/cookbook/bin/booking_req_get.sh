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

  if [[ $param == user_name:* ]]; then
    user_name=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | $AWK -F":" '{print $2}'`
  fi
   # add block1
   if [[ $param == book_name:* ]]; then
      book_name=`echo $param | $AWK -F":" '{print $2}'`
   fi

done

if [ ! "$id"  ];then
  id="new"
fi

if [ ! -d /var/www/tmp/$session ];then
  mkdir /var/www/tmp/$session
fi

# SET BASE_COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:booking_req"

if [ $id = "new" ];then

  # gen reqd/write form #new
  # comment out original line
  #$DATA_SHELL databox:request.db action:get id:$id keys:requester,email,book_name format:html_tag > /var/www/tmp/$session/dataset

  # insert new lines
  $DATA_SHELL databox:request.db action:get id:$id keys:requester,email,book_name format:html_tag > ../tmp/$session/dataset.0.1
  cat ../tmp/$session/dataset.0.1 \
  | $SED "s/name=\"book_name\" value=\"\"/name=\"book_name\" value=\"$book_name\"/g" > ../tmp/$session/dataset

else

  # gen read only contents
  # comment out original lines
  #$DATA_SHELL databox:request.db action:get id:$id keys:requester,email,book_name format:none > /var/www/tmp/$session/dataset.0.1
  #cat /var/www/tmp/$session/dataset.0.1 | $SED "s/^/<li><label>/g" | $SED "s/:/<\/label><pre>/1" | $SED "s/$/<\/pre><\/li>/g" \
  #| $SED "s/<pre><\/pre>/<pre>-<\/pre>/g" | $SED "s/_%%enter_/\n/g" > /var/www/tmp/$session/dataset

  # insert new lines 
  $DATA_SHELL databox:request.db action:get id:$id keys:requester,email,book_name,status,message format:none | grep -v hashid > ../tmp/$session/dataset.0.1
  cat ../tmp/$session/dataset.0.1 | $SED "s/^/<li><label>/g" | $SED "s/:/<\/label><pre>/g" | $SED "s/$/<\/pre><\/li>/g" \
  | $SED "s/<pre><\/pre>/<pre>-<\/pre>/g" | $SED "s/_%%enter_/\n/g" > ../tmp/$session/dataset

  # history #default is head -1
  $DATA_SHELL databox:request.db action:get type:log id:$id format:none | head -1 > /var/www/tmp/$session/history

  # error check
  error_chk=`cat /var/www/tmp/$session/dataset.0.1 | grep "^error:"`
fi


# form type check
form_chk=`$META chk.form:request.db`

# set view
if [ "$error_chk" ];then
  view="booking_req_get_err.html.def"

elif [ "$form_chk" = "urlenc" ];then
  if [ "$id" = "new" ];then
    view="booking_req_get_new.html.def"
  else
    view="booking_req_get.html.def"
  fi
elif [ "$form_chk" = "multipart" ];then
  if [ "$id" = "new" ];then
    view="booking_req_get_new_incf.html.def"
  else
    view="booking_req_get.html.def"
  fi
fi

# render HTML
cat /var/www/descriptor/${view} | $SED -r "s/^( *)</</1" \
| $SED "/%%dataset/r /var/www/tmp/$session/dataset" \
| $SED "s/%%dataset//g"\
| $SED "/%%history/r /var/www/tmp/$session/history" \
| $SED "s/%%history//g"\
| $SED "s/%%id/$id/g" \
| $SED "s/%%pdls/session=$session\&pin=$pin\&req=get/g" \
| $SED "s/%%session/session=$session\&pin=$pin/g" \
| $SED "s/%%params/session=$session\&pin=$pin/g"

if [ "$session" ];then
  rm -rf /var/www/tmp/$session
fi

exit 0
