#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ./03-CopyConfiguration2SDCard.sh
#%
#% DESCRIPTION
#%    This script copies the raspberrypi-ua-netinst configuration files
#%    from your mac to the SD-CARD
#%    See https://github.com/FooDeas/raspberrypi-ua-netinst for more
#%    informatiom on the configuration.
#%
#% OPTIONS
#%
#% EXAMPLES
#%    ./03-CopyConfiguration2SDCard.sh
#%
#================================================================
#- IMPLEMENTATION
#-    version         1.0
#-    author          luckynrslevin
#-    license         GNU General Public License v3.0
#-
#================================================================
#  HISTORY
#     2017/12/08 : luckynrslevin : Script creation
#
#================================================================
#  DEBUG OPTION
#    set -n  # Uncomment to check your syntax, without execution.
#    set -x  # Uncomment to debug this shell script
#
#================================================================
# END_OF_HEADER
#================================================================

#============================
#  FUNCTIONS
#============================

copyConfig () {
  echo "SD-CADRD found, copying files ..."
  cp -r raspberrypi-ua-netinst/config/files /Volumes/NO\ NAME/raspberrypi-ua-netinst/config || exit 1
  cp raspberrypi-ua-netinst/config/installer-config.txt /Volumes/NO\ NAME/raspberrypi-ua-netinst/config/installer-config.txt || exit 1
  cp raspberrypi-ua-netinst/config/post-install.txt /Volumes/NO\ NAME/raspberrypi-ua-netinst/config/post-install.txt || exit 1
}

waitForSdCard () {
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "Your SD-CARD with the raspberrypi-ua-netinst image does not seem to be"
  echo "mounted on your mac. Please use etcher to write the raspberrypi-ua-netinst"
  echo "image to your SD-CARD. If you cannot see it as a volume in mac finder you"
  echo "should unplug it and plug it in again, so that it gets mounted."
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

  read -r -p "Try again? [Y/n]" response
  response=$(echo "$response" | tr "[:upper:]" "[:lower:]") # tolower
  if ([[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]] ) \
            && [ -d /Volumes/NO\ NAME/raspberrypi-ua-netinst ]; then
    copyConfig
  elif [[ $response =~ ^(no|n| ) ]] ; then
    echo "OK, exiting, according to your whish ..."
    return 0
  else
    waitForSdCard
  fi
  # we should never reach this point since we wait until
  # we found the SD-Card or the user typed Ctrl-C
}

#============================
#  Main
#============================

if [ -d '/Volumes/NO\ NAME/raspberrypi-ua-netinst/config' ]; then
  copyConfig
else
  waitForSdCard
fi

exit 0
#============================
#  End
#============================
