#!/bin/bash

snapshot_file="$HOME/snapshot.txt"
log="$HOME/backup.log"
remote="loser@confuzer.cloud"
remote_script="/home/loser/send-incremental.sh"
port=2222
pool="lump"
remote_pool="brick"

echo "----------------------------------------------------" | tee -a "$log"
echo "Starting new round of backups. Backups! date: `date`" | tee -a "$log"

new_snapshot=`cat "$snapshot_file"`
datasets=`ssh -p "$port" "$remote" "zfs list" | grep "${remote_pool}/" | cut -d' ' -f1 | cut -d/ -f2`

ignore="apt-mirror
offline"

for dataset in $datasets
do
  if echo "$ignore" | grep "^${dataset}$" > /dev/null; then
    continue
  fi
  #https://stackoverflow.com/questions/41328041/shell-script-to-check-most-recent-zfs-snapshot#41329639
  old_snapshot=`zfs list -t snapshot -o name,creation -s creation -r "${pool}/${dataset}" | tail -1 | cut -d ' ' -f 1 | cut -d '@' -f 2`

  until zfs list -t snapshot | grep "$dataset@$new_snapshot"
  do
    echo "receiving \"$dataset\" from \"$remote\", old: \"$old_snapshot\"" | tee -a "$log"
    ssh -o MACs=hmac-md5 -p "$port" "$remote" \
      "$remote_script $dataset $old_snapshot $new_snapshot" | \
      pv | zfs recv -Fdu "$pool"
  done
done
