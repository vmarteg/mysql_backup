
#!/bin/bash -x

ulimit -n 999999

BACKUP_DIR="/tmp/backup";

#**********************************************************************

FILE="/etc/mysql/my.cnf";
PASSWORD="password";

DAY_OF_MONTH=$(date +%d);
STORAGE_DIR=$(date +%m-%Y);

TARGET_DIR="$BACKUP_DIR/$STORAGE_DIR/$DAY_OF_MONTH";
INCREMENTAL_BASEDIR="$BACKUP_DIR/$STORAGE_DIR/incremental-basedir";


function createFullBackup {
    innobackupex --defaults-file=$FILE --password=$PASSWORD --no-timestamp --rsync ${TARGET_DIR} 2>&1
    innobackupex --apply-log --redo-only --defaults-file=$FILE --password=$PASSWORD  --throttle=40 ${TARGET_DIR} 2>&1
    ln -s ${TARGET_DIR} ${INCREMENTAL_BASEDIR};
}

function createIncrementBackup {
    innobackupex --defaults-file=$FILE --password=$PASSWORD --no-timestamp --rsync \
      --incremental ${TARGET_DIR} --incremental-basedir=${INCREMENTAL_BASEDIR} 2>&1
    innobackupex --apply-log ${INCREMENTAL_BASEDIR} --redo-only --defaults-file=$FILE --password=$PASSWORD  --throttle=40 \
      --incremental-dir=${TARGET_DIR} 2>&1
}

if [ "$DAY_OF_MONTH" == "01" ] || [ ! -L "${INCREMENTAL_BASEDIR}" ]; then
        cd $BACKUP_DIR && rm -rf *
        mkdir -p $BACKUP_DIR/$STORAGE_DIR
        createFullBackup;
        rsync -e "ssh -c arcfour" -v -aSH $TARGET_DIR mysqlbackup@gorilko.lan.local:~/backup/db/$STORAGE_DIR/
    else
        mkdir -p $BACKUP_DIR/$STORAGE_DIR
        createIncrementBackup;
        rsync -e "ssh -c arcfour" -v -aSH $TARGET_DIR mysqlbackup@server:~/backup/db/$STORAGE_DIR/
        cd $BACKUP_DIR/$STORAGE_DIR && rm -rf $TARGET_DIR
    exit 0;
fi;

exit 0;
