#!/usr/bin/env sh
if [ ! -e logs ]; then
mkdir logs | true
fi
$(rm logs/*.log 2> /dev/null)
{
set -e
oscheck=$(uname)

version="$1"

major=$(echo "$version" | awk -F. '{print $1}')
minor=$(echo "$version" | awk -F. '{print $2}')
patch=$(echo "$version" | awk -F. '{print $3}')
major=${major:-0}
minor=${minor:-0}
patch=${patch:-0}

#if [ ! -e mysshtars/README.md ]; then
#    git submodule update --init --recursive
#fi

if [ -e mysshtars/ssh.tar.gz ]; then
    if [ "$oscheck" = 'Linux' ]; then
        gzip -d mysshtars/ssh.tar.gz
        gzip -d mysshtars/t2ssh.tar.gz
        gzip -d mysshtars/atvssh.tar.gz
    fi
fi

#if [ ! -e "$oscheck"/gaster ]; then
#    curl -sLO https://nightly.link/verygenericname/gaster/workflows/makefile/main/gaster-"$oscheck".zip
#    unzip gaster-"$oscheck".zip
#    mv gaster "$oscheck"/
#    rm -rf gaster gaster-"$oscheck".zip
#fi

chmod +x "$oscheck"/*

if [ "$1" = 'clean' ]; then
    rm -rf boot/${deviceid} work
    echo "[*] Removed the current created SSH ramdisk"
    exit
elif [ "$1" = 'dump-blobs' ]; then
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    version=$("$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "sw_vers -productVersion")
    version=${version%%.*}
    if [ "$version" -ge 16 ]; then
        device=rdisk2
    else
        device=rdisk1
    fi
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "cat /dev/$device" | dd of=dump.raw bs=256 count=$((0x4000))
    "$oscheck"/img4tool --convert -s dumped.shsh dump.raw
    killall iproxy 2>/dev/null | true
    echo "[*] Onboard blobs should have dumped to the dumped.shsh file"
    exit
elif [ "$1" = 'reboot' ]; then
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot"
    echo "[*] Device should now reboot"
    exit
elif [ "$1" = 'ssh' ]; then
    killall iproxy 2>/dev/null | true
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost || true
    killall iproxy 2>/dev/null | true
    exit
elif [ "$oscheck" = 'Darwin' ]; then
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
else
    if ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
fi

echo "[*] Getting device info and pwning... this may take a second"
check=$("$oscheck"/irecovery -q | grep CPID | sed 's/CPID: //')
replace=$("$oscheck"/irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$("$oscheck"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'$1'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)

if [ -e work ]; then
    rm -rf work
fi

if [ -e 12rd ]; then
    rm -rf 12rd
fi

mkdir -p boot/
mkdir -p boot/${deviceid}

if [ "$1" = 'reset' ]; then
    if [ ! -e boot/${deviceid}/iBSS.img4 ]; then
        echo "[-] Please create an SSH ramdisk first!"
        exit
    fi

    if [ "$check" = '0x8960' ]; then
        "$oscheck"/ipwnder > /dev/null
    else
        "$oscheck"/gaster pwn > /dev/null
    fi
    "$oscheck"/gaster reset > /dev/null
    "$oscheck"/irecovery -f boot/${deviceid}/iBSS.img4
    sleep 2
    "$oscheck"/irecovery -f boot/${deviceid}/iBEC.img4

    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        "$oscheck"/irecovery -c go
    fi

    sleep 2
    "$oscheck"/irecovery -c "setenv oblit-inprogress 5"
    "$oscheck"/irecovery -c saveenv
    "$oscheck"/irecovery -c reset

    echo "[*] Device should now show a progress bar and erase all data"
    exit
fi

if [ "$2" = 'TrollStore' ]; then
    if [ -z "$3" ]; then
        echo "[-] Please pass an uninstallable system app to use (Tips is a great choice)"
        exit
    fi
fi

if [ "$1" = 'boot' ]; then
    if [ ! -e boot/${deviceid}/iBSS.img4 ]; then
        echo "[-] Please create an SSH ramdisk first!"
        exit
    fi

    major=$(cat boot/${deviceid}/version.txt | awk -F. '{print $1}')
    minor=$(cat boot/${deviceid}/version.txt | awk -F. '{print $2}')
    patch=$(cat boot/${deviceid}/version.txt | awk -F. '{print $3}')
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    if [ "$check" = '0x8960' ]; then
        "$oscheck"/ipwnder > /dev/null
    else
        "$oscheck"/gaster pwn > /dev/null
    fi
    "$oscheck"/gaster reset > /dev/null
    "$oscheck"/irecovery -f boot/${deviceid}/iBSS.img4
    sleep 2
    "$oscheck"/irecovery -f boot/${deviceid}/iBEC.img4

    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        "$oscheck"/irecovery -c go
    fi
    sleep 2
    "$oscheck"/irecovery -f boot/${deviceid}/logo.img4
    "$oscheck"/irecovery -c "setpicture 0x1"
    "$oscheck"/irecovery -f boot/${deviceid}/ramdisk.img4
    "$oscheck"/irecovery -c ramdisk
    "$oscheck"/irecovery -f boot/${deviceid}/devicetree.img4
    "$oscheck"/irecovery -c devicetree
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
    :
    else
    "$oscheck"/irecovery -f boot/${deviceid}/trustcache.img4
    "$oscheck"/irecovery -c firmware
    fi
    "$oscheck"/irecovery -f boot/${deviceid}/kernelcache.img4
    "$oscheck"/irecovery -c bootx

    echo "[*] Device should now show text on screen"
    exit
fi

if [ ! -e boot/${deviceid} ]; then
    mkdir "boot/$deviceid"
fi

if [ -e boot/${deviceid}/iBSS.img4 ]; then
    echo "[-] Ramdisk is already created so SKIPPING ..."
    exit
fi

if [ -z "$1" ]; then
    printf "1st argument: iOS version for the ramdisk\nExtra arguments:\nreset: wipes the device, without losing version.\nTrollStore: install trollstore to system app\n"
    exit
fi

if [ ! -e work ]; then
    mkdir work
fi

"$oscheck"/gaster pwn > /dev/null
"$oscheck"/img4tool -e -s other/shsh/"${check}".shsh -m work/IM4M

cd work
../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
    :
    else
    ../"$oscheck"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
    fi
else
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
    :
    else
    ../"$oscheck"/pzb -g Firmware/"$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache "$ipswurl"
    fi
fi

../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    ../"$oscheck"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
else
    ../"$oscheck"/pzb -g "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl"
fi

cd ..
"$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBSS.dec
"$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBEC.dec
"$oscheck"/iBoot64Patcher work/iBSS.dec work/iBSS.patched
"$oscheck"/img4 -i work/iBSS.patched -o boot/${deviceid}/iBSS.img4 -M work/IM4M -A -T ibss
"$oscheck"/iBoot64Patcher work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ -z "$2" ]; then :; else echo "$2=$3"; fi` `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi`" -n
"$oscheck"/img4 -i work/iBEC.patched -o boot/${deviceid}/iBEC.img4 -M work/IM4M -A -T ibec

"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o work/kcache.raw
"$oscheck"/KPlooshFinder work/kcache.raw work/kcache.patched
"$oscheck"/kerneldiff work/kcache.raw work/kcache.patched work/kc.bpatch
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o boot/${deviceid}/kernelcache.img4 -M work/IM4M -T rkrn -P work/kc.bpatch `if [ "$oscheck" = 'Linux' ]; then echo "-J"; fi`
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o boot/${deviceid}/devicetree.img4 -M work/IM4M -T rdtr

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
        :
        else
        "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache -o boot/${deviceid}/trustcache.img4 -M work/IM4M -T rtsc
    fi
    "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o work/ramdisk.dmg
else
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
    :
    else
    "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache -o boot/${deviceid}/trustcache.img4 -M work/IM4M -T rtsc
    fi
    "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o work/ramdisk.dmg
fi

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
    :
    else
        hdiutil resize -size 220MB work/ramdisk.dmg
    fi
    hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk.dmg -owners off

    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
        hdiutil create -size 220m -imagekey diskimage-class=CRawDiskImage -format UDZO -fs HFS+ -layout NONE -srcfolder /tmp/SSHRD -copyuid root work/ramdisk1.dmg
        hdiutil detach -force /tmp/SSHRD
        hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk1.dmg -owners off
        if [ -d "other/trollstore/" ]; then 
            cp -rv other/trollstore/ /tmp/SSHRD/
        fi

    else
    :
    fi
    
    if [ "$replace" = 'j42dap' ]; then
        "$oscheck"/gtar -x --no-overwrite-dir -f mysshtars/atvssh.tar.gz -C /tmp/SSHRD/
    elif [ "$check" = '0x8012' ]; then
        "$oscheck"/gtar -x --no-overwrite-dir -f mysshtars/t2ssh.tar.gz -C /tmp/SSHRD/
        echo "[!] WARNING: T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
    else
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ])); then
        mkdir 12rd
        ipswurl12=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'12.0'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)
        cd 12rd
        ../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl12"
        ../"$oscheck"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl12"
                ../"$oscheck"/img4 -i "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o ramdisk.dmg
        hdiutil attach -mountpoint /tmp/12rd ramdisk.dmg -owners off
        if [ -d "other/trollstore/" ]; then 
            cp -rv other/trollstore/ /tmp/SSHRD/
        fi
        
        cp /tmp/12rd/usr/lib/libiconv.2.dylib /tmp/12rd/usr/lib/libcharset.1.dylib /tmp/SSHRD/usr/lib/
        hdiutil detach -force /tmp/12rd
        cd ..
        rm -rf 12rd
    else
        :
            fi
        "$oscheck"/gtar -x --no-overwrite-dir -f mysshtars/ssh.tar.gz -C /tmp/SSHRD/
    fi

    hdiutil detach -force /tmp/SSHRD
    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
        hdiutil resize -sectors min work/ramdisk1.dmg
    else
        hdiutil resize -sectors min work/ramdisk.dmg
    fi
else
    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
        echo "Sorry, 16.1 and above doesn't work on Linux at the moment!"
        exit
        else
        :
        fi
    "$oscheck"/hfsplus work/ramdisk.dmg grow 220000000 > /dev/null

    if [ "$replace" = 'j42dap' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar mysshtars/atvssh.tar > /dev/null
    elif [ "$check" = '0x8012' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar mysshtars/t2ssh.tar > /dev/null
        echo "[!] WARNING: T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
    else
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ])); then
        mkdir 12rd
        ipswurl12=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'12.0'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)
        cd 12rd
        ../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl12"
        ../"$oscheck"/pzb -g "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl12"
        ../"$oscheck"/img4 -i "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o ramdisk.dmg
        ../"$oscheck"/hfsplus ramdisk.dmg extract usr/lib/libcharset.1.dylib libcharset.1.dylib
        ../"$oscheck"/hfsplus ramdisk.dmg extract usr/lib/libiconv.2.dylib libiconv.2.dylib
        ../"$oscheck"/hfsplus ../work/ramdisk.dmg add libiconv.2.dylib usr/lib/libiconv.2.dylib
        ../"$oscheck"/hfsplus ../work/ramdisk.dmg add libcharset.1.dylib usr/lib/libcharset.1.dylib
        cd ..
        rm -rf 12rd
    else
    :
        fi
        "$oscheck"/hfsplus work/ramdisk.dmg untar mysshtars/ssh.tar > /dev/null
    fi
    if [ -d "other/trollstore/" ]; then 
        "$oscheck"/hfsplus work/ramdisk.dmg addall other/trollstore > /dev/null
    fi
fi

if [ "$oscheck" = 'Darwin' ]; then
if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
"$oscheck"/img4 -i work/ramdisk1.dmg -o boot/${deviceid}/ramdisk.img4 -M work/IM4M -A -T rdsk
else
"$oscheck"/img4 -i work/ramdisk.dmg -o boot/${deviceid}/ramdisk.img4 -M work/IM4M -A -T rdsk
fi
else
"$oscheck"/img4 -i work/ramdisk.dmg -o boot/${deviceid}/ramdisk.img4 -M work/IM4M -A -T rdsk
fi
"$oscheck"/img4 -i other/bootlogo.im4p -o boot/${deviceid}/logo.img4 -M work/IM4M -A -T rlgo
echo ""
echo "[*] Cleaning up work directory"
rm -rf work 12rd

echo ""
echo "[*] Finished! Please use ./sshrd.sh boot to boot your device"
echo $1 > boot/${deviceid}/version.txt

 } | tee logs/"$(date +%T)"-"$(date +%F)"-"$(uname)"-"$(uname -r)".log
