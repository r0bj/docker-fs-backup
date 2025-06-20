#!/bin/bash

set -eo pipefail

paths=${BACKUP_FILESYSTEM_PATHS}
s3_bucket=${S3_BUCKET}
s3_access_key=${S3_ACCESS_KEY}
s3_secret_key=${S3_SECRET_KEY}
aws_endpoint_url=${AWS_ENDPOINT_URL}
override_hostname=${OVERRIDE_HOSTNAME}
directory=${DIRECTORY}

function log {
	echo "`date +'%Y%m%d %H%M%S'`: $1"
}

if [[ -z "$paths" || -z "$s3_bucket" || -z "$s3_access_key" || -z "$s3_secret_key" ]]; then
	log "One or more parameter empty"
	exit 1
fi

if [[ -n "$override_hostname" ]]; then
	hostname=$override_hostname
else
	hostname=$(hostname)
fi

date=$(date +'%Y%m%d')
timestamp=$(date +'%Y%m%d_%H%M%S')
if [[ -n "$directory" ]]; then
	object="s3://${s3_bucket}/${hostname}/${directory}/${date}/${timestamp}/"
else
	object="s3://${s3_bucket}/${hostname}/${date}/${timestamp}/"
fi

IFS=','
paths_arr=($paths)
unset IFS

if [[ -n "$aws_endpoint_url" ]]; then
	opts="--endpoint-url=$aws_endpoint_url"
fi

for path in "${paths_arr[@]}"; do
	if [[ ! -e "$path" ]]; then
		log "Path $path does not exists"
		exit 1
	fi
done

export AWS_ACCESS_KEY_ID=$s3_access_key
export AWS_SECRET_ACCESS_KEY=$s3_secret_key
export AWS_RETRY_MODE=standard
export AWS_MAX_ATTEMPTS=6

for path in "${paths_arr[@]}"; do
	log "Uploading path $path"
	if [[ -d "$path" ]]; then
		aws $opts s3 sync "$path" $object --no-progress
	else
		aws $opts s3 cp "$path" $object --no-progress
	fi
	log "Uploading path $path done"
done
