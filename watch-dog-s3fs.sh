#!/bin/bash
#
# s3fs-watchdog.sh
#
# Run from the root user's crontab to keep an eye on s3fs which should always
# be mounted.
#
# Note:  If getting the amazon S3 credentials from environment variables
#   these must be entered in the actual crontab file (otherwise use one
#   of the s3fs other ways of getting credentials).
#
# Example:  To run it once every minute getting credentials from envrironment
# variables enter this via "sudo crontab -e":
#
#   AWSACCESSKEYID=XXXXXXXXXXXXXX
#   AWSSECRETACCESSKEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
#   * * * * * /root/s3fs-watchdog.sh
#

NAME=s3fs
BUCKET=<yourbucket>
MOUNTPATH=<yourmountpath>
MOUNT=/bin/mount
UMOUNT=/bin/umount
NOTIFY=<whotoemail>
NOTIFYCC=<whoelsetoemail>
GREP=/bin/grep
PS=/bin/ps
NOP=/bin/true
DATE=/bin/date
MAIL=/bin/mail
RM=/bin/rm

$PS -ef|$GREP -v grep|$GREP $NAME|grep $BUCKET >/dev/null 2>&1
case "$?" in
   0)
   # It is running in this case so we do nothing.
   $NOP
   ;;
   1)
   echo "$NAME is NOT RUNNING for bucket $BUCKET. Remounting $BUCKET with $NAME and sending notices."
   $UMOUNT $MOUNTPATH >/dev/null 2>&1
   $MOUNT $MOUNTPATH >/tmp/watchdogmount.out 2>&1
   NOTICE=/tmp/watchdog.txt
   echo "$NAME for $BUCKET was not running and was started on `$DATE`" > $NOTICE
   $MAIL -n -s "$BUCKET $NAME mount point lost and remounted" -c $NOTIFYCC $NOTIFY < $NOTICE
   $RM -f $NOTICE
   ;;
esac

exit
