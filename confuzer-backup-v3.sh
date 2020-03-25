#!/bin/bash
echo 'Put "-n" to skip the snapshot'

snapshot_file="$HOME/snapshot.txt"
log="$HOME/backup.log"
remote="loser@confuzer.cloud"
remote_snapshot_script="/home/loser/make-snapshot.sh"
remote_send_script="/home/loser/send-incremental.sh"
port=2222
pool="lump"
remote_pool="brick"
ignore_datasets="apt-mirror
offline
tmp"

echo "Getting list of datasets from the server..." | tee -a "$log"
datasets=`ssh -p "$port" "$remote" "zfs list" | grep "${remote_pool}/" | cut -d' ' -f1 | cut -d/ -f2`

echo "Removing ignored datasets from list..." | tee -a "$log"
datasets_not_ignored=
for dataset in $datasets
do
  if echo "$ignore_datasets" | grep "^${dataset}$" > /dev/null; then
    continue
  fi
  datasets_not_ignored="$datasets_not_ignored $dataset"
done

if [[ "$1" != "-n" ]]; then
### START SNAPSHOT ###
echo "----------------------------------------------------" | tee -a "$log"
echo "Starting new round of shots. Snapshots! date: `date`" | tee -a "$log"

echo "making snapshot of \"$datasets_not_ignored\" on \"$remote\" current time: `date`" | tee -a "$log"
ssh -o MACs=hmac-md5 -p "$port" "$remote" "$remote_snapshot_script $datasets_not_ignored" | tee "$snapshot_file"
### END SNAPSHOT ###
fi






### START BACKUP ###
echo "----------------------------------------------------" | tee -a "$log"
echo "Starting new round of backups. Backups! date: `date`" | tee -a "$log"

new_snapshot=`cat "$snapshot_file"`

for dataset in $datasets_not_ignored
do
  #https://stackoverflow.com/questions/41328041/shell-script-to-check-most-recent-zfs-snapshot#41329639
  old_snapshot=`zfs list -t snapshot -o name,creation -s creation -r "${pool}/${dataset}" | tail -1 | cut -d ' ' -f 1 | cut -d '@' -f 2`

  until zfs list -t snapshot | grep "$dataset@$new_snapshot"
  do
    echo "receiving \"$dataset\" from \"$remote\", old: \"$old_snapshot\"" | tee -a "$log"
    ssh -o MACs=hmac-md5 -p "$port" "$remote" \
      "$remote_send_script $dataset $old_snapshot $new_snapshot" | \
      pv | zfs recv -Fdu "$pool"
  done
done
### END BACKUP ###
