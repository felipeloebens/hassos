
###########################################

part start mmc ${devnum} 9 mmc_env
mmc dev ${devnum}
setenv loadbootstate "\
echo 'loading env...';\
mmc read ${ramdisk_addr_r} ${mmc_env} 0x10;\
env import -c ${ramdisk_addr_r} 0x2000;"

setenv storebootstate "\
echo 'storing env...';\
env export -c -s 0x2000 ${ramdisk_addr_r} BOOT_ORDER BOOT_A_LEFT BOOT_B_LEFT;\
mmc write ${ramdisk_addr_r} ${mmc_env} 0x10;"

run loadbootstate
test -n "${BOOT_ORDER}" || setenv BOOT_ORDER "A B"
test -n "${BOOT_A_LEFT}" || setenv BOOT_A_LEFT 3
test -n "${BOOT_B_LEFT}" || setenv BOOT_B_LEFT 3

if load mmc ${devnum}:1 ${ramdisk_addr_r} config.txt; then
  env import -t ${ramdisk_addr_r} ${filesize};
fi

# Board bootargs
if test "${m}" = "custombuilt"; then setenv cmode "modeline=${modeline}"; fi
setenv bootargs_odroidc2 "${condev} no_console_suspend hdmimode=${m} ${cmode} m_bpp=${m_bpp} vout=${vout} fsck.repair=yes net.ifnames=0 elevator=noop disablehpd=${hpd} max_freq=${max_freq} maxcpus=${maxcpus} monitor_onoff=${monitor_onoff} disableuhs=${disableuhs} mmc_removable=${mmc_removable} usbmulticam=${usbmulticam}"

# HassOS bootargs
setenv bootargs_hassos "zram.enabled=1 zram.num_devices=3 apparmor=1 security=apparmor cgroup_enable=memory"

# HassOS system A/B
setenv bootargs_a "root=PARTUUID=48617373-06 rootfstype=squashfs ro rootwait"
setenv bootargs_b "root=PARTUUID=48617373-08 rootfstype=squashfs ro rootwait"

usb start

# Load extraargs
fileenv mmc ${devnum}:1 ${ramdisk_addr_r} cmdline.txt cmdline
fatload mmc ${devnum}:1 ${fdt_addr_r} meson-gxbb-odroidc2.dtb
#fdt addr ${fdt_addr_r}

# logical volumes get numbered after physical ones.
# 1. boot
# 2. Extended partition
# 3. Overlay
# 4. Data
# 5. KernelA
# 6. SystemA
# 7. KernelB
# 8. SystemB
# 9. BootInfo
setenv bootargs
for BOOT_SLOT in "${BOOT_ORDER}"; do
  if test "x${bootargs}" != "x"; then
    # skip remaining slots
  elif test "x${BOOT_SLOT}" = "xA"; then
    if test ${BOOT_A_LEFT} -gt 0; then
      setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
      echo "Found valid slot A, ${BOOT_A_LEFT} attempts remaining"
      setenv load_kernel "ext4load mmc ${devnum}:5 ${kernel_addr_r} Image"
      setenv bootargs "${bootargs_hassos} ${bootargs_odroidc2} ${bootargs_a} rauc.slot=A ${cmdline}"
    fi
  elif test "x${BOOT_SLOT}" = "xB"; then
    if test ${BOOT_B_LEFT} -gt 0; then
      setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
      echo "Found valid slot B, ${BOOT_B_LEFT} attempts remaining"
      setenv load_kernel "ext4load mmc ${devnum}:7 ${kernel_addr_r} Image"
      setenv bootargs "${bootargs_hassos} ${bootargs_odroidc2} ${bootargs_b} rauc.slot=B ${cmdline}"
    fi
  fi
done

if test -n "${bootargs}"; then
  run storebootstate
else
  echo "No valid slot found, resetting tries to 3"
  setenv BOOT_A_LEFT 3
  setenv BOOT_B_LEFT 3
  run storebootstate
  reset
fi

echo "Loading kernel"
run load_kernel
echo " Starting kernel"
printenv load_kernel
printenv bootargs
booti ${kernel_addr_r} - ${fdt_addr_r}

echo "Fails on boot"
reset
