#!/bin/bash
#-------------------------------------------------------------
# This is the script for update status of book.master
#-------------------------------------------------------------

# global.conf load
SCRIPT_DIR=`dirname $0`
. ${SCRIPT_DIR}/../../global.conf

# load authkey
. ${SCRIPT_DIR}/.authkey

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "small-shell" ];then
  echo "error: user must be small-shell"
  exit 1
fi

# dump non available books
$ROOT/bin/DATA_shell authkey:$authkey databox:book.master command:show_all[keys=id,name][match=available{-}] format:csv \
> ${SCRIPT_DIR}/tmp/book_master_dump.tmp

# check latest resource status
count=1
while read line
do

  if [ $count -gt 1  ];then
    book_id=`echo $line | $AWK -F "," '{print $1}'`
    book_name=`echo $line | $AWK -F "," '{print $2}'`

    # check on_the_shelve book
    check_shelv=`$ROOT/bin/DATA_shell authkey:$authkey databox:book.res \
    command:show_all[match=name{$book_name}][filter=status{on{%%%%%%%}the{%%%%%%%}shelve}] format:none`

    if [ "$check_shelv" ];then
      # update available status
      $ROOT/bin/DATA_shell authkey:$authkey databox:book.master action:set id:$book_id key:available value:yes
      echo "$ROOT/bin/DATA_shell authkey:$authkey databox:book.master action:set id:$book_id key:available value:yes"
    fi
  fi

  ((count += 1))

done < ${SCRIPT_DIR}/tmp/book_master_dump.tmp

exit 0
