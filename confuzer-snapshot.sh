#!/bin/bash

snapshot_file="$HOME/snapshot.txt"
log="$HOME/backup.log"
remote="loser@confuzer.cloud"
remote_script="/home/loser/make-snapshot.sh"
port=2222
pool="lump"
remote_pool="brick"


echo "----------------------------------------------------" | tee -a "$log"
echo "Starting new round of shots. Snapshots! date: `date`" | tee -a "$log"

datasets=`ssh -p "$port" "$remote" "zfs list" | grep "${remote_pool}/" | cut -d' ' -f1 | cut -d/ -f2`

ignore="apt-mirror
offline"

datasets_not_ignored=
for dataset in $datasets
do
  if echo "$ignore" | grep "^${dataset}$" > /dev/null; then
    continue
  fi
  #https://stackoverflow.com/questions/41328041/shell-script-to-check-most-recent-zfs-snapshot#41329639
  #old_snapshot=`zfs list -t snapshot -o name,creation -s creation -r "${pool}/${dataset}" | tail -1 | cut -d ' ' -f 1 | cut -d '@' -f 2`
  datasets_not_ignored="$datasets_not_ignored $dataset"
done

echo "making snapshot of \"$datasets_not_ignored\" on \"$remote\" current time: `date`" | tee -a "$log"
ssh -o MACs=hmac-md5 -p "$port" "$remote" "$remote_script $datasets_not_ignored" | tee "$snapshot_file"
