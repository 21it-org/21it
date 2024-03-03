#!/bin/bash
app=book_search

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

done

if [ ! -d /var/www/tmp/$session ];then
  mkdir /var/www/tmp/$session
fi

# -----------------
# Exec command
# -----------------

# SET BASE_COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:$app"

# -----------------
# Handle markdown
# -----------------
num_of_md_def=`$META get.num:${app}.UI.md.def`
if [ $num_of_md_def -ge 1 ];then
  if [ -f /var/www/descriptor/.${app}.UI.md.def.hash ];then
    hash=`$META get.chain:${app}.UI.md.def | tail -1 | $AWK -F ":" '{print $4}'`
    org_hash="`cat /var/www/descriptor/.${app}.UI.md.def.hash`"
    if [ ! "$hash" = "$org_hash" ];then
      echo "$hash" > /var/www/descriptor/.${app}.UI.md.def.hash
      /var/www/bin/md_parse.sh $app $session $pin
    fi
  else
    hash=`$META get.chain:${app}.UI.md.def | tail -1 | $AWK -F ":" '{print $4}'`
    echo "$hash" > /var/www/descriptor/.${app}.UI.md.def.hash
    /var/www/bin/md_parse.sh $app $session $pin
  fi
fi


# -----------------
# render HTML
# -----------------

cat /var/www/descriptor/book_search_main.html.def | $SED -r "s/^( *)</</1" \
| $SED "/%%common_menu/r /var/www/descriptor/common_parts/book_search_common_menu" \
| $SED "s/%%common_menu//g"\
| $SED "s/%%user_name/$user_name/g" \
| $SED "s/%%session/session=$session\&pin=$pin/g" \
| $SED "s/%%params/session=$session\&pin=$pin/g"

if [ "$session" ];then
  rm -rf /var/www/tmp/$session
fi

exit 0
