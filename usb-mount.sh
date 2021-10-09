#!/usr/bin/env bash

username="$(ps au | awk '$11 ~ /^xinit/ { print $1; exit }')"

PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"
log="logger -t usb-mount.sh -s "

usage()
{
    ${log} "Usage: $0 {add|remove} device_name (e.g. sdb1)"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"

# See if this drive is already mounted, and if so where
MOUNT_POINT=$(mount | grep ${DEVICE} | awk '{ print $3 }')

DEV_LABEL=""

do_mount()
{
    if [[ -n ${MOUNT_POINT} ]]; then
        ${log} "Warning: ${DEVICE} is already mounted at ${MOUNT_POINT}"
        exit 1
    fi

    # Get info for this drive: $ID_FS_LABEL and $ID_FS_TYPE
    eval $(blkid -o udev ${DEVICE} | grep -i -e "ID_FS_LABEL" -e "ID_FS_TYPE")

    # Figure out a mount point to use
    LABEL=${ID_FS_LABEL}
    if grep -q " /media/${LABEL} " /etc/mtab; then
        # Already in use, make a unique one
        LABEL+="-${DEVBASE}"
    fi
    DEV_LABEL="${LABEL}"

    # Use the device name in case the drive doesn't have label
    if [ -z ${DEV_LABEL} ]; then
        DEV_LABEL="${DEVBASE}"
    fi

    MOUNT_POINT="/media/shyciii/${DEV_LABEL}"

    ${log} "Mount point: ${MOUNT_POINT}"

    mkdir -p ${MOUNT_POINT}

    # Global mount options
    OPTS="rw,relatime"

	TYPE=${ID_FS_TYPE}

	case $TYPE in
	    vfat)
		OPTS="$OPTS,uid=$username,gid=users,fmask=113,dmask=002"
		;;
		exfat)
		OPTS="$OPTS,uid=$username,gid=users,fmask=113,dmask=002"
		;;
	    ntfs)
		OPTS="$OPTS,flush"
		hash ntfs-3g && mtype="ntfs-3g"
		;;
	    *)
		OPTS="$OPTS,sync"
		;;
	esac
	
	if mount -t "${mtype:-auto}" -o "$OPTS" "$DEVICE" "$MOUNT_POINT"
	then
	    [[ "$username" ]] && DISPLAY=:0 runuser -u "$username" notify-send "Device is successfully mounted" "$MOUNT_POINT"
	    ${log} "Device is successfully mounted: $dir"
	    exit 0
	else
	    ${log} "Mount error: $?"
	    rmdir "$dir"
	    exit 1
	fi
	
}

do_unmount()
{
    if [[ -z ${MOUNT_POINT} ]]; then
	    [[ "$username" ]] && DISPLAY=:0 runuser -u "$username" notify-send "$DEVICE is not mounted"
        ${log} "Warning: ${DEVICE} is not mounted"
    else
        umount -l ${DEVICE}
		${log} "Unmounted ${DEVICE} from ${MOUNT_POINT}"
        /bin/rmdir "${MOUNT_POINT}"
        [[ "$username" ]] && DISPLAY=:0 runuser -u "$username" notify-send "Device is successfully unmounted" "$MOUNT_POINT"
        sed -i.bak "\@${MOUNT_POINT}@d" /var/log/usb-mount.track
    fi

}

case "${ACTION}" in
    add)
        do_mount
        ;;
    remove)
        do_unmount
        ;;
    *)
        usage
        ;;
esac
