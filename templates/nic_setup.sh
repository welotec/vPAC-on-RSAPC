#!/bin/env bash

CPU_LIST=3
# set affinity of IRQs and related kthreads of the PRP Interface to core3
#sleep 1m

grep lanPRP /proc/interrupts | awk '{print $1}' | cut -d: -f1 | xargs -I{} bash -c "echo $CPU_LIST > /proc/irq/{}/smp_affinity_list"
#pgrep -P 2 lanPRP | xargs -I{} taskset -p -c $CPU_LIST {}
ps axo pid,command | grep lanPRP | grep irq | grep -v grep | awk {'print $1'} | xargs -I{} taskset -p -c $CPU_LIST {}
