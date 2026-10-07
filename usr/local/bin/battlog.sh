#!/bin/sh
# DM250 battery logger. Works on both kernels (3.10: power_supply/battery, 6.18: power_supply/BATTERY).
# On 3.10 the capacity cannot be read from sysfs, so runtime is measured from the slope of capacity.
# 6.18 exposes charge_now (logged as chg_uAh) and has no temp; a missing value is logged as "-".
# WARNING: resuming from suspend can shift the clock by +9h. Exclude epoch discontinuities when analyzing.
# The interval is 5 minutes, and 1 minute below 3.6V: the last half hour before the battery runs out is
# where the moment of power-off and the charge left at that moment are read from.
LOG=/home/pomera/battlog.tsv
B=/sys/class/power_supply/battery
[ -e "$B" ] || B=/sys/class/power_supply/BATTERY
rd() { cat "$B/$1" 2>/dev/null || echo -; }
[ -e "$LOG" ] || printf "epoch\tdatetime\tstatus\tcap\tvolt_uV\tcur_uA\ttemp\tchg_uAh\n" > "$LOG"
while :; do
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$(date +%s)" "$(date +%Y-%m-%dT%H:%M:%S)" \
    "$(rd status)" "$(rd capacity)" \
    "$(rd voltage_now)" "$(rd current_now)" "$(rd temp)" "$(rd charge_now)" >> "$LOG"
  v=$(rd voltage_now)
  if [ "$v" -lt 3600000 ] 2>/dev/null; then sleep 60; else sleep 300; fi
done
