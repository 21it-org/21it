#!/bin/bash

# Target databox and keys
databox=book.res
key=all

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

if [ ! -d /var/www/tmp/${session}_log ];then
  mkdir /var/www/tmp/${session}_log
fi

# SET BASE_COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:book_search"

# -----------------
# Exec command
# -----------------

# gen %%log contents
if [ "$keys" = "all" ];then
  $DATA_SHELL databox:$databox \
  action:get id:$id type:log format:html_tag > /var/www/tmp/${session}_log/log
else
  GREP=`echo $keys | $SED "s/^/grep -e \"<pre>\" -e \"<\/pre>\" -e key:/g" | $SED "s/,/ -e key:/g"`
  LOG_GREP="$DATA_SHELL databox:$databox action:get id:$id type:log | $GREP"
  eval $LOG_GREP > /var/www/tmp/${session}_log/log
fi

# render HTML
cat /var/www/descriptor/location_search_log_viewer.html.def | $SED -r "s/^( *)</</1" \
| $SED "/%%log/r /var/www/tmp/${session}_log/log" \
| $SED "s/%%log//g"\
| $SED "s/%%id/$id/g"

if [ "$session" ];then
  rm -rf /var/www/tmp/${session}_log
fi

exit 0
