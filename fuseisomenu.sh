#!/bin/bash
# fuseisomenu script for fuseiso konqueror service menu
# by Jason Farrell <farrellj@gmail.com>, 2008
# note: user must be in group "fuse" for fuse permission
TITLE="FuseISOMenu"     # title prefix for all dialogs
ERRORTMPFILE="/tmp/fuseiso.err.tmp"   # stderr tmpfile for kdialog
MTAB_FUSEISO="${HOME}/.mtab.fuseiso"   # use users' mtab instead of global /proc/mounts
FUSEPREFIX="FUSEMNT-"  # mountdir prefix when not asking for specific mountdir
QUIET_KDIALOG=1       # no annoying confirmation dialogs. use kdialog only when necessary

usage() {
#cat >/dev/null<<EOF
cat <<EOF
-m arg == mount iso(s) in this mountbasedir
-u     == unmount selected iso(s).
-a     == ask for mount directory name in mountbasedir rather than auto-creating it
-x     == unmount ALL fuseiso mounts
-s     == show all fuseiso mounts
-h     == help
EOF
}

mountbasedir=""; unmount=0; askformountpoint=0; unmountall=0; showmounts=0; showhelp=0;
while getopts "m:uaxsh" arg
do
    case "$arg" in
        m)
            mountbasedir="$OPTARG" ;;
        u)
            unmount=1 ;;
        a)
            askformountpoint=1 ;;
        x)
            unmountall=1 ;;
        s)
            showmounts=1 ;;
        h)
            showhelp=1 ;;
        ?)
            kdialog --title "$TITLE" --error "Invalid option"
            exit 1
            ;;
    esac
done
# todo: warn about mutually exclusive options at some point
shift $(($OPTIND - 1))

unmount_by_isofile_or_mountpoint () {
    awk '{print $1, $2}' "$MTAB_FUSEISO" | while read iso mnt; do
        iso="${iso//\040/ }"    # convert to spaces
        mnt="${mnt//\040/ }"
        #echo $1
        #echo "$iso -> $mnt"
        if [ "$1" = "$iso" -o "$1" = "$mnt" ]; then
            echo "fusermount -u $mnt"
            fusermount -u "$mnt" 2>"$ERRORTMPFILE"
            if [ $? -ne 0 ]; then
                ERROR="$(cat $ERRORTMPFILE)"
                if [ -n "$ERROR" ]; then
                    kdialog --title "${TITLE}" --error "COULD NOT UNMOUNT\n${iso}\nFROM\n${mnt}\nBECAUSE OF ERROR--------------------:\n$ERROR"
                else
                    kdialog --title "${TITLE}" --error "COULD NOT UNMOUNT\n${iso}\nFROM\n${mnt}"
                fi
            else
                if [ $QUIET_KDIALOG -ne 1 ]; then
                    kdialog --title "${TITLE}" --msgbox "SUCCESSFULLY UNMOUNTED\n${iso}\nFROM\n${mnt}"
                fi
            fi
        fi
    done
}


if [ -n "$mountbasedir" ]; then
    for arg in "$@"; do
        if [ "$askformountpoint" -eq 1 ]; then
            MOUNTDIR="$(kdialog --title "Select Mount Directory for ${arg}" --getexistingdirectory "$(dirname "$arg")")"
            [ $? -ne 0 ] && exit 1      # user cancelled
        else
            if [ "$mountbasedir" = "." ]; then # relative to the ISO's directory
                MOUNTDIR="$(dirname "$arg")/${FUSEPREFIX}$(basename "${arg}")"
            else  # absolute dir (just Desktop for now)
                MOUNTDIR="${mountbasedir}/${FUSEPREFIX}$(basename "${arg}")"
            fi
        fi

        fuseiso -p "$arg" "$MOUNTDIR" 2>"$ERRORTMPFILE"
        if [ $? -ne 0 ]; then
            ERROR="$(cat $ERRORTMPFILE)"
            if [ -n "$ERROR" ]; then
                kdialog --title "${TITLE}" --error "COULD NOT MOUNT\n${arg}\nON\n${MOUNTDIR}\nBECAUSE OF ERROR--------------------:\n$ERROR"
            else
                kdialog --title "${TITLE}" --error "COULD NOT MOUNT\n${arg}\nON\n${MOUNTDIR}"
            fi
        else
            if [ $QUIET_KDIALOG -ne 1 ]; then
                kdialog --title "${TITLE}" --msgbox "SUCCESSFULLY MOUNTED\n${arg}\nON\n${MOUNTDIR}"
            fi
        fi
    done


elif [ "$unmount" -eq 1 ]; then
    for arg in "$@"; do
        unmount_by_isofile_or_mountpoint "$(readlink -f "$arg")"
    done

elif [ "$unmountall" -eq 1 ]; then
    #if [ $QUIET_KDIALOG -ne 1 ]; then
        kdialog --title "$TITLE" --warningyesno "Are you sure you want to unmount all the following FUSEISOs?
            $(awk '{printf "%s -> %s\n", $1, $2}' $MTAB_FUSEISO)"
    #fi
    if [ $? -eq 0 ]; then
        for mnt in $(cat "$MTAB_FUSEISO" | awk '{print $2}'); do 
            mnt="${mnt//\\040/ }"
            unmount_by_isofile_or_mountpoint "$mnt"
        done
    fi

elif [ "$showmounts" -eq 1 ]; then
    if [ -s "$MTAB_FUSEISO" ]; then
        kdialog --title "$TITLE" --msgbox "$(awk '{printf "%s -> %s\n", $1, $2}' $MTAB_FUSEISO)"
    else
        kdialog --title "$TITLE" --sorry "Nothing appears to be mounted, according to $MTAB_FUSEISO"
    fi
    exit 0

elif [ "$showhelp" -eq 1 ]; then
    kdialog --title "$TITLE - Help" --msgbox "FUSEISO mounts ISO filesystem images as a non-root user. Currently supports plain ISO9660 Level 1 and 2, Rock Ridge, Joliet, zisofs. Supported image types: ISO, BIN (single track only), NRG, MDF, IMG (CCD).\n
    The most common reasons why a user can't mount using fuseiso:\n
    1) fuse and fuseiso isn't installed
    2) The user has not yet been added to the \"fuse\" system group and re-logged in
    3) The image is corrupt, invalid, or is unsupported"
    exit 0

else
    usage
    kdialog --title "$TITLE" --error "Nothing to do. Need some valid options."
    exit 1
fi
