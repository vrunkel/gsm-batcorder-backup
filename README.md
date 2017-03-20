# gsm-batcorder-backup

Ein einfaches Skript unter Nutzung von USBMOUNT für Raspberry Pi und ähnliche Systeme zum automatischen Sichern der Aufnahme eines GSM-batcorders auf ein USB-Speichermedium.

Das Skript nutzt diverse Pakete, die installiert sein müssen. Eine ausführliche Anleitung dazu finden Sie unter http://www.ecoobs.de/batcorder/SkriptAnleitungRaspi.pdf

u.a. sind das die Pakete :

- usbmount
- rsync
- at
- zip/unzip
- ssmtp
- mtools
- libmtp-runtime

Das Skript 01_GSMBackup.sh muss ins Verzeichnis /etc/usbmount/mount.d kopiert werden und mit Rechten zum Ausführen versehen werden (rwxr_xr_x).

Das Skript setzt voraus, dass der GSM-batcorder die SD-Karte als GSM_BC benennt. Das Medium fürs Backup muss das Label BACKUP tragen und als FAT32 formatiert sein.
