#!/bin/bash

PERL5LIB=/home/koha/kohaclone
KOHA_CONF=/home/koha/koha-dev/etc/koha-conf.xml

KOHA_CRON_PATH=/home/koha/kohaclone/misc/cronjobs
LOGFILE=${KOHA_CRON_PATH}/UHMessageQueue.log

echo 'Deleting dups' > ${LOGFILE}
date >> ${LOGFILE}
/home/koha/Local/DuplicateHolds/Scripts/dedupHoldMessages.pl >> ${LOGFILE}
date >> ${LOGFILE}

sleep 5

echo 'Sending emails starting at....' >> ${LOGFILE}
date >> ${LOGFILE}
$KOHA_CRON_PATH/process_message_queue.pl >> ${LOGFILE}
echo 'Sending emails finishing at....' >> ${LOGFILE}
date >> ${LOGFILE}

# sleep 5

#mail -s "Koha Message Queue Report" s.graham4@herts.ac.uk < ${LOGFILE}

