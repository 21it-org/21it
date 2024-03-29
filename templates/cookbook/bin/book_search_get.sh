#!/bin/bash

# Target databox and keys
databox=book.master
keys=all

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

  if [[ $param == duplicate:* ]]; then
    duplicate=`echo $param | $AWK -F":" '{print $2}'`
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
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:book_search"
# add block1
book_name=`$DATA_SHELL databox:book.master action:get key:name id:$id format:none | $AWK -F ":" '{print $2}'`

# load permission
if [ ! "$user_name" = "guest" ];then
  permission=`$META get.attr:book_search/$user_name{permission}`
else
  permission="ro"
fi

if [ ! "$duplicate" = "yes" ];then
  if [ ! "$permission" = "ro"  ];then

    # gen read/write datas
    $DATA_SHELL databox:$databox action:get id:$id keys:$keys format:html_tag > /var/www/tmp/$session/dataset

  else

    # gen read only datas
    $DATA_SHELL databox:$databox action:get id:$id keys:$keys format:none | grep -v hashid > /var/www/tmp/$session/dataset.0.1
    cat /var/www/tmp/$session/dataset.0.1 | $SED "s/^/<li><label>/g" | $SED "s/:/<\/label><pre>/1" | $SED "s/$/<\/pre><\/li>/g" \
    | $SED "s/<pre><\/pre>/<pre>-<\/pre>/g" | $SED "s/_%%enter_/\n/g" >> /var/www/tmp/$session/dataset

  fi

else

  # else means copying data
  if [ "$keys" = "all" ];then
    keys=`$META get.key:$databox{all}`
    primary_key=`$META get.key:$databox{primary}`
  fi
  for key in $keys
  do
    # gen %%data by conpying
    if [ "$primary_key" = "$key" ];then
      $DATA_SHELL databox:$databox \
      action:get id:new key:$key format:html_tag > /var/www/tmp/$session/dataset
    else
      data=`$DATA_SHELL databox:$databox \
      action:get id:$id key:$key format:html_tag `
      file_chk=`echo $data | grep "<div class=\"file_form\">" `

      if [ ! "$file_chk" ];then
        echo "$data" >> /var/www/tmp/$session/dataset
      else
        $DATA_SHELL databox:$databox \
        action:get id:new key:$key format:html_tag  >> /var/www/tmp/$session/dataset
      fi
    fi
  done
  id=new
fi

# error check
error_chk=`cat /var/www/tmp/$session/dataset | grep "^error:"`

# form type check
form_chk=`$META chk.form:$databox`

# set view
if [ "$error_chk" ];then
  view="book_search_get_err.html.def"

elif [ "$permission"  = "ro" ];then
  view="book_search_get_ro.html.def"

elif [ "$form_chk" = "urlenc" ];then
  if [ "$id" = "new" ];then
    view="book_search_get_new.html.def"
  else
    view="book_search_get_rw.html.def"
  fi
elif [ "$form_chk" = "multipart" ];then
  if [ "$id" = "new" ];then
    view="book_search_get_new_incf.html.def"
  else
    view="book_search_get_rw_incf.html.def"
  fi
fi

# render HTML
cat ../descriptor/${view} | $SED "s/^ *</</g" \
| $SED "/%%common_menu/r ../descriptor/common_parts/book_search_common_menu" \
| $SED "/%%common_menu/d" \
| $SED "/%%dataset/r ../tmp/$session/dataset" \
| $SED "s/%%dataset//g"\
| $SED "/%%history/r ../tmp/$session/history" \
| $SED "s/%%history//g"\
| $SED "s/%%id/$id/g" \
| $SED "s/%%book_name/$book_name/g" \
| $SED "s/%%pdls/session=$session\&pin=$pin\&req=get/g" \
| $SED "s/%%session/session=$session\&pin=$pin/g" \
| $SED "s/%%params/session=$session\&pin=$pin/g"

if [ "$session" ];then
  rm -rf /var/www/tmp/$session
fi

exit 0
