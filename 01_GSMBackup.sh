#!/bin/bash
########################################################################
# the following is probably double, already inside the standard 
# usbmount mount script
########################
# nevertheless we rely on some mount points and leave it as it is
# version 1.0 - 1. August 2016 um 14:56:21 MESZ
# (c) volker runkel, ecoObs GmbH
########################################################################
# Copyright for parts of this script
# This script creates the volume label symlink in /var/run/usbmount.
# Copyright (C) 2014 Oliver Sauder
#
# This file is free software; the copyright holder gives unlimited
# permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.
#

#########
# This script runs on mounting volumes via usbmount
# we do have a critical problem - runtime is limited
# so after ca. 5 seconds it gets killed
# currently this is circumvented by calling the long lasting rsync 
# using the at command ... yet, we shouldn't add much more and move to a better
# longer lasting runtime system sooner or later
# especially all the file logging might slow down
#########

set -e

# **** Delete Threshold / Schwelle zum Löschen der SD-Karte ****
# set the threshold to any value between 0 and 99
# to initiate relabeling of SD card for deletion as soon as card is filled
# up to that number in percentage
# if automatic deletion is not wanted, set the value to above 100
# * * *
# Schwelle auf Wert zwischen 0 und 99
# die SD-Karte wird dann zum Löschen markiert, wenn die Füllung
# in Prozent diesen Wert erreicht hat
# bei Werten über 100 wird niemals gelöscht
# ****************************************************************
DELETE_THRESHOLD=90

# **** Mail to / Mail an ****
# the mail adress reports will get sent to if mail is configured 
# and internet available
# * * *
# Empfänger-Adresse für Status Mails
# wenn Mail konfiguriert und Internet verfügbar ist
# ****************************************************************
MAIL_TO="runkel@ecoobs.de"

# **** Raspi ID for Mail / Raspi ID für Mails ****
# a string that is appended to mail messages 
# to identify this raspi
# * * *
# Text für Mails um diesen Raspi zu identifizieren
# ****************************************************************
MAIL_ID="WKA1-Raspi"

date >> /home/pi/GSM-Logging.txt


# Exit if device or mountpoint is empty.
test -z "$UM_DEVICE" && test -z "$UM_MOUNTPOINT" && exit 0
 
# get volume label name of the newly mounted volume
label=`blkid -s LABEL -o value $UM_DEVICE`
 
# If the symlink does not yet exist, create it.
# that should already happen with the default 00_ script, but does no harm
test -z $label || test -e "/var/run/usbmount/$label" || ln -sf "$UM_MOUNTPOINT" "/var/run/usbmount/$label"

################################################
### work horse operation starts here ####
########################
## most commands leave a trail in /home/pi/Documents/GSM-Logging.txt
# so you can later on check the script runtime behaviour
#######

# check mountpoint for backups : needs to be BACKUP
if ! mountpoint -q /var/run/usbmount/BACKUP/
  then
    echo "backup filesystem not mounted" >> /home/pi/GSM-Logging.txt
    exit 0
	else 
	echo "backup filesystem mounted" >> /home/pi/GSM-Logging.txt
fi

########################
# check mountpoint for batcorder : volume name/label needs to be GSM_BC
# set automatically by the gsm-batcorder when formatting the card
if ! mountpoint -q /var/run/usbmount/GSM_BC/
  then
    echo "batcorder filesystem not mounted"  >> /home/pi/GSM-Logging.txt
    exit 0
   	else 
	echo "batcorder filesystem mounted" >> /home/pi/GSM-Logging.txt

fi

# now we need to get the device node for possible relabeling later on
GSM_DEVICE=""
if [[ $label = "GSM_BC" ]]; then
	GSM_DEVICE=$UM_DEVICE
	echo "batcorder filesystem on $GSM_DEVICE"  >> /home/pi/GSM-Logging.txt
fi

########################
# create filename for logfile copy based on current timestamp
# and create a zip with logfile
# NEEDS TESTING -> what happens if no LOGFILE.TXT exists!?
# what happens if no correct clock is running ?
# running number just as a revision might be better
echo "Backing up logfile" >> /home/pi/GSM-Logging.txt
current_timestamp=$(date +%Y%m%d-%H%M%S) 
echo "zip /var/run/usbmount/BACKUP/GSM_Backups/LOGFILE-$current_timestamp /var/run/usbmount/BACKUP/GSM_Backups/LOGFILE.TXT" | at now

########################
# Test if Backup volume is at least 90% full
# if it is, no further backups!
#
backupUsedSpace=$(df -k /var/run/usbmount/BACKUP/ | tail -1 | awk '{sub (/%/, "", $5); print $5;}')
if [[ "$backupUsedSpace" -gt 90 ]]; then
	exit 0;
fi

########################
# Test if Batcorder volume is at least 90% full
# if it is, the mlabel command initiates delete of card
# else we do a normal rsync
#

myUsedSpace=$(df -k /var/run/usbmount/GSM_BC/ | tail -1 | awk '{sub (/%/, "", $5); print $5;}')
if [[ "$myUsedSpace" -gt "$DELETE_THRESHOLD" ]]; then
	if [[ -n "$GSM_DEVICE" ]]; then
		echo "Rsync and DELETEME relabeling, used on BACKUP $backupUsedSpace" >> /home/pi/GSM-Logging.txt
	    echo "rsync -a /var/run/usbmount/GSM_BC/* /var/run/usbmount/BACKUP/GSM_Backups && umount $GSM_DEVICE && mlabel -i $GSM_DEVICE ::DELETEME" | at now
	   	echo "Normal rsync started, sd card delete initiated, used on BACKUP $backupUsedSpace" | mail -s "$MAIL_ID: Raspi update" $MAIL_TO

	else 
		echo "Normal Rsync, GSM device not available, no DELETEME relabeling! Used on BACKUP $backupUsedSpace" > /home/pi/GSM-Logging.txt
		echo "rsync -a /var/run/usbmount/GSM_BC/* /var/run/usbmount/BACKUP/GSM_Backups" | at now
	echo "Normal Rsync, GSM device not available, no DELETEME relabeling! Used on BACKUP $backupUsedSpace" | mail -s "$MAIL_ID: Raspi update" $MAIL_TO
	fi
else
	echo "Normal Rsync, used on BACKUP $backupUsedSpace" >> /home/pi/GSM-Logging.txt
	echo "rsync -a /var/run/usbmount/GSM_BC/* /var/run/usbmount/BACKUP/GSM_Backups" | at now
	echo "Normal rsync started, used on BACKUP $backupUsedSpace" | mail -s "$MAIL_ID: Raspi update" $MAIL_TO
fi

######## MISSING #####
####
# we could also unmount Batcorder after rsync
####
# error management: rsync fails ?!, currently an email is sent to root on raspi
# once sd card BACKUP showed i/o error, and was then mounted ro
####
# other errors, can they be detected and acted upon? 
# sending mails if email is available
# writing a logfile in pi
####
# A script that tests if names/labels are correct
# user inserts new backup card, and then ssh's and starts a script
######## MISSING #####

exit 0
