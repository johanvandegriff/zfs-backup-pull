#!/bin/bash
echo 'Put "-n" to skip the snapshot'

snapshot_file="$HOME/snapshot.txt"
log="$HOME/backup.log"
remote="johanv@confuzer.cloud"
remote_snapshot_script="/home/loser/make-snapshot.sh"
remote_send_script="/home/loser/send-incremental.sh"
port=2230
local_pool="tool"
remote_pool="brick"
ignore_datasets="apt-mirror
offline
tmp
storj"

#need these permissions for this script
#sudo zfs allow johanv compression,mountpoint,create,mount,receive tool

echo "Getting list of datasets from the server..." | tee -a "$log"
datasets=`ssh -o MACs=hmac-md5 -p "$port" "$remote" \
  "zfs list" | grep "${remote_pool}/" | cut -d' ' -f1 | cut -d/ -f2`

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
new_snapshot=`ssh -o MACs=hmac-md5 -p "$port" "$remote" "date +%Y-%m-%d_%H:%M:%S"`_backup
for dataset in $datasets_not_ignored
do
  echo "snapshotting $dataset"
  ssh -o MACs=hmac-md5 -p "$port" "$remote" \
    "zfs snapshot ${remote_pool}/${dataset}@${new_snapshot}"
done

echo "$new_snapshot"  | tee "$snapshot_file"
### END SNAPSHOT ###
fi






### START BACKUP ###
echo "----------------------------------------------------" | tee -a "$log"
echo "Starting new round of backups. Backups! date: `date`" | tee -a "$log"

new_snapshot=`cat "$snapshot_file"`

for dataset in $datasets_not_ignored
do
  #https://stackoverflow.com/questions/41328041/shell-script-to-check-most-recent-zfs-snapshot#41329639
  old_snapshot=`zfs list -t snapshot -o name,creation -s creation -r "${local_pool}/${dataset}" | tail -1 | cut -d ' ' -f 1 | cut -d '@' -f 2`

  until zfs list -t snapshot | grep "$dataset@$new_snapshot"
  do
    echo "receiving \"$dataset\" from \"$remote\", old: \"$old_snapshot\"" | tee -a "$log"
    if [[ -z "$old_snapshot" ]]; then
        echo "receiving for the first time, not incremental" | tee -a "$log"
        ssh -o MACs=hmac-md5 -p "$port" "$remote" \
            "zfs send -R ${remote_pool}/${dataset}@${new_snapshot}" | \
            pv | zfs recv -Fdu "$local_pool"
    else
        echo "receiving incremental" | tee -a "$log"
        ssh -o MACs=hmac-md5 -p "$port" "$remote" \
            "zfs send -R -I ${remote_pool}/${dataset}@${old_snapshot} ${remote_pool}/${dataset}@${new_snapshot}" | \
            pv | zfs recv -Fdu "$local_pool"
    fi
  done
done
### END BACKUP ###
