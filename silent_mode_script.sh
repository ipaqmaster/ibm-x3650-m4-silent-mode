#!/bin/bash

[ $UID -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO=sudo # Use sudo if not root

ipmi_output=$(ipmitool sdr 2>/dev/null)
fan_zones=($(echo "$ipmi_output" | grep 'Fan [0-9][A-Z] Tach' | awk -F'|' '{print $1}' | awk '{print $2}'))

while true; do
  ipmi_output=$(ipmitool sdr 2>/dev/null)
  cpu_output=$(echo "$ipmi_output" | grep -i "CPU .* Temp")
  cpu_temps=($(echo "$ipmi_output" | grep 'CPU [0-9] Temp' | awk -F'|' '{print $2}' | awk '{print $1}'))

  echo "Currrent CPU temp: ${cpu_temps[@]}"

  # Initialize the max variable with the first element of the array
  max=${cpu_temps[0]}

  # Loop through the array elements
  for temp in "${cpu_temps[@]}"; do
    # If the current element is greater than the current max, update max
    if (( temp > max )); then
      max=$temp
    fi
  done

  # Define temperature range
  min_temp=30  # Minimum temperature for fan control
  max_temp=80  # Maximum temperature for fan control

  # Calculate fan speed as a percentage
  if (( max <= min_temp )); then
    fan_speed=0
  elif (( max >= max_temp )); then
    fan_speed=255
  else
    # Calculate the fan speed based on the temperature
    # Linearly scale between min_temp and max_temp
    fan_speed=$(( (max - min_temp) * 255 / (max_temp - min_temp) ))
  fi

  # Print the calculated fan speed
  echo "Calculated fan speed (0-255 scale): $fan_speed"

  # Convert fan speed to hexadecimal
  fan_speed_hex=$(printf '%02x' $fan_speed)

  # Set fan speed using ipmitool
  i=0
  for fan_zone in "${fan_zones[@]}"; do
    if [[ "$fan_zone" == *A ]]; then
      i=$((i+1))
      ${SUDO} ipmitool raw 0x3a 0x07 0x0${i} 0x$fan_speed_hex 0x01 > /dev/null 2>&1 &
    fi
  done

  # Apply the changes
  ${SUDO} ipmitool raw 0x3a 0x06 > /dev/null 2>&1

done
