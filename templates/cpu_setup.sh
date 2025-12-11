#!/bin/bash

# TODO: do proper error checking and check if files are present

# setup Cache-Way masks for COS 0-3
wrmsr 0xc90 0xc00 # 1100 0000 0000
wrmsr 0xc91 0x300 # 0011 0000 0000
wrmsr 0xc92 0x0f0 # 0000 1111 0000
wrmsr 0xc93 0x00f # 0000 0000 1111

# cores 0 and 8 remain in default COS 0
# set core 1,9,11 to use COS 1
wrmsr -p 1 0xc8f 0x100000000
#wrmsr -p 9 0xc8f 0x100000000
#wrmsr -p 11 0xc8f 0x100000000
# set core 4,5 to use COS 2
wrmsr -p 4 0xc8f 0x200000000
wrmsr -p 5 0xc8f 0x200000000
# set core 2,3,6,7,10 to use COS 3
wrmsr -p 2 0xc8f 0x300000000
wrmsr -p 3 0xc8f 0x300000000
wrmsr -p 6 0xc8f 0x300000000
wrmsr -p 7 0xc8f 0x300000000
wrmsr -p 10 0xc8f 0x300000000

# set GPU mask to the same as COS 0
wrmsr 0x18b0 0xe00
wrmsr 0x18b1 0xe00
wrmsr 0x18b2 0xe00
wrmsr 0x18b3 0xe00

# set WRC mask to the same as COS 0
wrmsr 0x18d0 0xe00
wrmsr 0x18d1 0xe00
wrmsr 0x18d2 0xe00
wrmsr 0x18d3 0xe00

rt_freq=2400000
non_rt_freq=1500000

# setting max limit for non-rt cores.
# can still clock lower depending on load and pstate settings
echo $non_rt_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo $non_rt_freq > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq
echo $non_rt_freq > /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq
#echo $non_rt_freq > /sys/devices/system/cpu/cpu8/cpufreq/scaling_max_freq
#echo $non_rt_freq > /sys/devices/system/cpu/cpu9/cpufreq/scaling_max_freq
#echo $non_rt_freq > /sys/devices/system/cpu/cpu10/cpufreq/scaling_max_freq
#echo $non_rt_freq > /sys/devices/system/cpu/cpu11/cpufreq/scaling_max_freq

# pinning both upper and lower bounds of pstate scaling to the same frequency
# for all the rt cores, which makes the frequency static.
echo $rt_freq > /sys/devices/system/cpu/cpu3/cpufreq/scaling_max_freq
echo $rt_freq > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
echo $rt_freq > /sys/devices/system/cpu/cpu5/cpufreq/scaling_max_freq
echo $rt_freq > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq
echo $rt_freq > /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu12/cpufreq/scaling_max_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu13/cpufreq/scaling_max_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu14/cpufreq/scaling_max_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu15/cpufreq/scaling_max_freq
#
echo $rt_freq > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
echo $rt_freq > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
echo $rt_freq > /sys/devices/system/cpu/cpu5/cpufreq/scaling_min_freq
echo $rt_freq > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq
echo $rt_freq > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu12/cpufreq/scaling_min_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu13/cpufreq/scaling_min_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu14/cpufreq/scaling_min_freq
#echo $rt_freq > /sys/devices/system/cpu/cpu15/cpufreq/scaling_min_freq

# this effectively puts the core into polling mode (idle.poll) thereby keeping it in C0
echo "n/a" > /sys/devices/system/cpu/cpu3/power/pm_qos_resume_latency_us
echo "n/a" > /sys/devices/system/cpu/cpu4/power/pm_qos_resume_latency_us
echo "n/a" > /sys/devices/system/cpu/cpu5/power/pm_qos_resume_latency_us
echo "n/a" > /sys/devices/system/cpu/cpu6/power/pm_qos_resume_latency_us
echo "n/a" > /sys/devices/system/cpu/cpu7/power/pm_qos_resume_latency_us

# take sibling cores of cores 4-7 offline (effectively disabling HT)
until echo 0 > /sys/devices/system/cpu/cpu8/online; do :; done
until echo 0 > /sys/devices/system/cpu/cpu9/online; do :; done
until echo 0 > /sys/devices/system/cpu/cpu10/online; do :; done
until echo 0 > /sys/devices/system/cpu/cpu11/online; do :; done
until echo 0 > /sys/devices/system/cpu/cpu12/online; do :; done
until echo 0 > /sys/devices/system/cpu/cpu13/online; do :; done
until echo 0 > /sys/devices/system/cpu/cpu14/online; do :; done
until echo 0 > /sys/devices/system/cpu/cpu15/online; do :; done
