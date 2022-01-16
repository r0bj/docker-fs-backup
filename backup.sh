#!/bin/bash

prometheus_pushgateway_url=${PUSHGATEWAY_URL}
prometheus_job=${PROMETHEUS_JOB:-filesystem-backup}
override_hostname=${OVERRIDE_HOSTNAME}
auth_user=${BASIC_AUTH_USER}
auth_password=${BASIC_AUTH_PASSWORD}

function write_log {
	echo "`date +'%Y%m%d %H%M%S'`: $1"
}

function notify_prometheus {
	local success="$1"
	local duration="$2"

	if [ -n "$auth_user" ] && [ -n "$auth_password" ]; then
		curl_opts="-u ${auth_user}:$auth_password"
	fi

	if [ -n "$prometheus_pushgateway_url" ] && [ -n "$prometheus_job" ]; then
		if [ "$success" -eq 1 ]; then
			write_log "INFO: notify prometheus: backup success; duration: $duration"
cat <<EOF | curl -v --max-time 60 $curl_opts -s -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP filesystem_backup_duration_seconds Duration of filesystem backup
# TYPE filesystem_backup_duration_seconds gauge
filesystem_backup_duration_seconds $duration
# HELP filesystem_backup_last_success_timestamp_seconds Unixtime filesystem backup last succeeded
# TYPE filesystem_backup_last_success_timestamp_seconds gauge
filesystem_backup_last_success_timestamp_seconds $(date +%s.%7N)
# HELP filesystem_backup_last_success Success of filesystem backup
# TYPE filesystem_backup_last_success gauge
filesystem_backup_last_success 1
EOF
		else
			write_log "INFO: notify prometheus: backup failed"
cat <<EOF | curl -v --max-time 60 $curl_opts -s -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP filesystem_backup_last_success Success of filesystem backup
# TYPE filesystem_backup_last_success gauge
filesystem_backup_last_success 0
EOF
		fi
	fi
}

if [ -n "$override_hostname" ]; then
	hostname=$override_hostname
else
	hostname=$(hostname)
fi

start_timastamp=$(date +'%s')

bash /fs-backup.sh
if [ "$?" -eq 0 ]; then
	duration=$(($(date +'%s') - $start_timastamp))
	notify_prometheus 1 $duration
	exit 0
else
	notify_prometheus 0
	exit 1
fi
