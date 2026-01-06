# vPAC on RSAPC 
## this is a repository showcasing fine tuning of the RSAPC MK2 platform for realtime applications.

[!NOTE]
This repository is still new and under construction - there might be errors
ahead. Please reach out if you find any.

This repo was prepared to set up the SSC600 SW by ABB as it was the first
commercially available vPAC solution that we could get our hands on. Some of the
setup is specific to the SSC600 SW and was taken from their engineering manual.

This repo contains ansible scripts which will setup the system as well as the
SSC600 SW virtual machine. It is currently only tested against Debian 13 and
requires a working internet connection. For a simple local setup it is easiest
to run the setup.sh script as root once you've gone through a basic debian
installation. During the debian installation select regions and local settings
as you prefer, the extra non root user is assumed to be 'ansible'. When prompted
for basic packages to install, it is recommended to uncheck options for
'Desktop' and 'GNOME'. Stick with the recommended disk layout or make sure that
there is ~35G free space under /var for the VM image. After the setup.sh runs
through successfully, follow the instructions on screen, to reboot the machine
and run the two extra download and install scripts for the SSC600 SW. To do so it
is required that provide a downloadlink for the SSC600, which you can get from
the ABB website for the SSC600. You have to register with an E-Mail and when
there is a downloadlink, instead of klicking on it to download, right click to
copy the hyperlink. This is the link you will have to provide to the download
script.


## Thirdparty Copyrights, Trademarks, and Licenses acknowledgements

Parts of these files are taken from ABBs engineering Manuals or were part of
the SSW600 SW distribution
- templates/ssc600-deb.xml

Others were taken from the LF ENERGY SEAPATH project and modified.

- templates/timemaster.conf
- templates/tuned.conf


