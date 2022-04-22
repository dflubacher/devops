# DFRobot CM4 IoT Router Board Mini (v1.0)
- [DFRobot web page, SKU:DFR0767](https://wiki.dfrobot.com/Compute_Module_4_IoT_Router_Board_Mini_SKU_DFR0767)
- Used in conjunction with a Compute Module 4 with 32GB eMMC, therefore an SD card flash is not needed.

## Boot method to eMMC directly
- [Jeff Geerling's instructions](https://www.jeffgeerling.com/blog/2020/how-flash-raspberry-pi-os-compute-module-4-emmc-usbboot)

1. Download OpenWRT image from the DFRobot site.
2. On the DFRobot Board, toggle the DIP switch 'RPIBOOT' to 1 (disables eMMC boot).
3. Connect
    * USB-C port 'USB' to USB of host
    * USB-C port 'POWER' to power supply
4. Make sure `libusb` is installed:
    ```sh
    sudo apt-get -y install libusb-1.0-0-dev
    ```
5. Clone usbboot:
    ```sh
    cd /tmp && git clone --depth=1 https://github.com/raspberrypi/usbboot
    
    # Change to usbboot directory:
    cd /tmp/usbboot
    make

    # Run the executable to mount disk.
    sudo ./rpiboot
    ```
6. Open balenaEtcher and flash target:
    * Select OpenWRT file from step 1
    * Select target, in dialog select Compute Module 4 (32GB, depending on CM4 model)
7. Power off/on the board and once again `sudo ./rpiboot` to mount the eMMC.
8. Open GParted GUI and select the corresponding drive.
9. Expand the ext4 partition (rootfs) to cover the whole eMMC.
    * TODO: GParted showed a cryptic error message, but it still seemed to expand the disk.
10. Not described, but switch the DIP switch back to 0, restart. Normal OpenWRT setup from here (default credentials are `root` and empty password).

