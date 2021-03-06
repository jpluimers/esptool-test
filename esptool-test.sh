#!/bin/bash

# Originally by Max Vilimpoc, use this under the MIT license.
#
# Script to test the performance of various USB serial adapters
# when programming an esp8266 module.

if [[ $# -ne 2 ]]; then
    echo
    echo "Usage:   $0 PORT         FLASH_SIZE"
    echo "Example: $0 /dev/ttyUSBx 0x100000"
    echo
    exit 1
fi

BAUDS=(3000000 1500000 921600 460800 230400 115200)

PORT=$1
FLASH_SIZE=$2
FLASH_SIZE_DECIMAL=$(printf "%d\n" ${FLASH_SIZE})

get_real_name() {
    # Stolen shamelessly from:
    # http://unix.stackexchange.com/questions/144029/command-to-determine-ports-of-a-device-like-dev-ttyusb0

    local port=$1

    for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev); do
        (
            syspath="${sysdevpath%/dev}"
            devname="$(udevadm info -q name -p $syspath)"
            [[ "$devname" == "bus/"* ]] && continue
            eval "$(udevadm info -q property --export -p $syspath)"
            [[ -z "$ID_SERIAL" ]] && continue

            if [[ "/dev/$devname" == "$port" ]]; then
                echo "$ID_SERIAL"
            fi
        )
    done
}

generate_write_bin() {
    echo
    echo "Generating write.bin"

    rm -f write.bin
    dd if=/dev/urandom of=write.bin bs=${FLASH_SIZE_DECIMAL} count=1
}

for baud in "${BAUDS[@]}"; do
    echo
    echo "Testing '$(get_real_name $PORT)' at $baud:"

    echo
    ./esptool.py --port $PORT --baud $baud read_mac

    echo
    ./esptool.py --port $PORT --baud $baud chip_id

    echo
    ./esptool.py --port $PORT --baud $baud flash_id

    echo
    ./esptool.py --port $PORT --baud $baud read_flash 0x0 $FLASH_SIZE read.bin

    echo
    ./esptool.py --port $PORT --baud $baud erase_flash
    sleep 7

    generate_write_bin

    echo
    ./esptool.py --port $PORT --baud $baud write_flash 0x0 write.bin

    echo
    ./esptool.py --port $PORT --baud $baud verify_flash 0x0 write.bin
done
