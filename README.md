# Dragaonbaord 410c ubuntu core image on android layout

This build script produces ubuntu core image with recovery capabilities on top of original android parition layout. Most of processes and scripts were originated from Brando project.

## Prerequisite

* a working android on dragonboard 410c

   follow this [installation](https://github.com/96boards/documentation/blob/master/ConsumerEdition/DragonBoard-410c/Installation/LinuxSD.md) guide to flash android on eMMC

* needed packages

``` shell
apt-get install dosfstools snapd android-tools-fsutils android-tools-fastboot u-boot-tools
```

* skales tool (avaiable on ubuntu after 17.04) if you're on 16.04, use this PPA

``` shell
add-apt-repository ppa:julian-liu/skales
apt-get update
```

``` shell
apt-get install skales
```

## U-boot source

u-boot image is pre-built from [here](https://github.com/JulianLiu/u-boot-dragonboard410c) which were forked from [hallor](https://github.com/hallor/u-boot) and appied with patch by [kubiko](https://github.com/kubiko/dragonboard-gadget/tree/emmc-boot). FAT_ENV_DEVICE_AND_PART is re-defined at 0:16 (mmc device 0 part #22).

## Build images

```shell
./dragonboard-local-build.sh
```

## Partition layout

```shell
| Part # | Part Label     |  Will be flashed     |
|--------|:--------------:|:--------------------:|
|1       | modem          |                      |
|2       | fsc            |                      |
|3       | ssd            |                      |
|4       | sbl1           |                      |
|5       | sbl1bak        |                      |
|6       | rpm            |                      |
|7       | rpmbak         |                      |
|8       | tz             |                      |
|9       | tzbak          |                      |
|10      | hyp            |                      |
|11      | hypbak         |                      |
|12      | modemst1       |                      |
|13      | modemst2       |                      |
|14      | DDR            |                      |
|15      | fsg            |                      |
|16      | sec            |                      |
|17      | aboot          |                      |
|18      | abootbak       |                      |
|19      | boot           |   Y (u-boot.img)     |
|20      | recovery       |Y (uc kernel + initrd)|
|21      | devinfo        |                      |
|22      | system         |   Y (system-boot)    |
|23      | cache          |                      |
|24      | persist        |                      |
|25      | misc           |                      |
|26      | keystore       |                      |
|27      | config         |                      |
|28      | oem            |                      |
|29      | userdata       |   Y (writable)       |
```

## Flash images

let dragonboard entering fastboot mode (press VOL+ while powering up)

```shell
# replace YYYYmmddHHMM to the actual generated image name
fastboot flash recovery ./dragonboard-recovery-YYYYmmddHHMM.img
fastboot flash system ./dragonboard-systemboot-YYYYmmddHHMM.img
fastboot flash userdata ./dragonboard-userdata-YYYYmmddHHMM.img
fastboot flash boot gadget/u-boot.img
```