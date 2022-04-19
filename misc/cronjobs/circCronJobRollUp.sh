#!/bin/bash

PERL5LIB=/home/koha/kohaclone
KOHA_CONF=/home/koha/koha-dev/etc/koha-conf.xml

KOHA_CRON_PATH=/home/koha/kohaclone/misc/cronjobs
LOGFILE=${KOHA_CRON_PATH}/circCronJob.log

echo 'Number of Items to renew' > ${LOGFILE}
$KOHA_CRON_PATH/runreport.pl --format=text 138 >> ${LOGFILE}
echo 'Auto Renewals starting at....' >> ${LOGFILE}
date >> ${LOGFILE}
$KOHA_CRON_PATH/automatic_renewals.pl -c >> ${LOGFILE}
echo 'Auto Renewals finishing at....' >> ${LOGFILE}
date >> ${LOGFILE}

sleep 1m

echo 'Overdue notices starting at....' >> ${LOGFILE}
date >> ${LOGFILE}
$KOHA_CRON_PATH/overdue_notices.pl -t -html /home/koha/koha-dev/var/www/intranet/notices -itemscontent date_due,title,barcode,author >> ${LOGFILE}
echo 'Overdue notices finishing at....' >> ${LOGFILE}
date >> ${LOGFILE}

sleep 1m

echo 'Advance notices starting at....' >> ${LOGFILE}
date >> ${LOGFILE}
$KOHA_CRON_PATH/advance_notices.pl -c -i date_due,title,barcode,author >> ${LOGFILE}
echo 'Advance notices finishing at....' >> ${LOGFILE}
date >> ${LOGFILE}

sleep 1m

echo 'Sending emails starting at....' >> ${LOGFILE}
date >> ${LOGFILE}
$KOHA_CRON_PATH/process_message_queue.pl >> ${LOGFILE}
echo 'Sending emails finishing at....' >> ${LOGFILE}
date >> ${LOGFILE}

sleep 1m

echo 'Fines starting at....' >> ${LOGFILE}
date >> ${LOGFILE}
$KOHA_CRON_PATH/fines.pl >> ${LOGFILE}
echo 'Fines finishing at....' >> ${LOGFILE}
date >> ${LOGFILE}

mail -s "Koha Cronjob Report" s.graham4@herts.ac.uk d.m.peacock@herts.ac.uk < ${LOGFILE}
