#!/bin/bash

find /home/koha/koha-dev/var/www/intranet/notices -type f -mtime +7 -exec rm {} \;
