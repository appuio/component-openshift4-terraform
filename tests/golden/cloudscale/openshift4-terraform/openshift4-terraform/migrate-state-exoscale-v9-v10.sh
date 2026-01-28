#!/bin/bash
# vim: et sw=2 sts

set -e

zone=$(jq -r '.module.cluster.region' main.tf.json)

terraform state pull > state.json
# IMPORTANT: If this file is missing, the import will fail!
touch .mr_url.txt

# This jq expression should find all `exoscale_compute_instance` resources in
# the state (including additional node groups).
for item in $(jq -r \
  '.resources[]
    |select(.type == "exoscale_compute_instance")
    |.module as $module|.name as $name
    |.instances[]
    |"\($module).exoscale_compute_instance.\($name)[\(.index_key)];\(.attributes.id)"' \
  state.json)
do
  res=$(echo "$item" |cut -d';' -f1)
  uuid=$(echo "$item" | cut -d';' -f2)

  echo terraform state rm "$res"
  echo terraform import "$res" "${uuid}@${zone}"
done

rm state.json
