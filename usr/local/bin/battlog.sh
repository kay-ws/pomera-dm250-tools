#!/bin/sh
# DM250 battery logger. Battery capacity cannot be read from sysfs, so runtime is measured from the slope of capacity.
# WARNING: resuming from suspend can shift the clock by +9h. Exclude epoch discontinuities when analyzing.
LOG=/home/pomera/battlog.tsv
B=/sys/class/power_supply/battery
[ -e "$LOG" ] || printf "epoch\tdatetime\tstatus\tcap\tvolt_uV\tcur_uA\ttemp\n" > "$LOG"
while :; do
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$(date +%s)" "$(date +%Y-%m-%dT%H:%M:%S)" \
    "$(cat $B/status)" "$(cat $B/capacity)" \
    "$(cat $B/voltage_now)" "$(cat $B/current_now)" "$(cat $B/temp)" >> "$LOG"
  sleep 300
done
