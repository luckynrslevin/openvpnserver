#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ./02-DownloadIMG.sh
#%
#% DESCRIPTION
#%    This script downloads the latest raspberrypi-ua-netinstaller image
#%    from github repository https://github.com/FooDeas/raspberrypi-ua-netinst
#%
#% OPTIONS
#%
#% EXAMPLES
#%    ./02-DownloadIMG.sh
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
#  FILES AND VARIABLES
#============================
# Download latest Image from https://api.github.com/repos/FooDeas/raspberrypi-ua-netinst/
DL_URL=$(curl -s https://api.github.com/repos/FooDeas/raspberrypi-ua-netinst/releases/latest | grep 'browser_' | grep '.bz2' | cut -d\" -f4)
FILENAME=$(echo $DL_URL | sed 's|^https://github.com/FooDeas/raspberrypi-ua-netinst/releases/download/v.*/\(raspberrypi-ua-netinst-.*\.bz2\)$|\1|')
FILENAME_SHORT=$(echo $FILENAME | sed 's/.bz2//')

#============================
#  FUNCTIONS
#============================

downLoadImage () {
  echo "Download image from:"
  echo "$DL_URL"
  rm $FILENAME_SHORT 2> /dev/null
  wget $DL_URL -q --show-progress || exit 1
  bzip2 -d $FILENAME || exit 1
}

#============================
#  Main
#============================

if [ -f  $FILENAME ] || [ -f  $FILENAME_SHORT ]; then
  read -r -p "File already exists, download again? [y/N]" response
  response=$(echo "$response" | tr "[:upper:]" "[:lower:]") # tolower
  if [[ $response =~ ^(yes|y| ) ]]; then
     downLoadImage
  elif [[ $response =~ ^(no|n| ) ]] || [[ -z $response ]]; then
     echo "Continue with existing file ..."
  else
    echo "Not a valid answer"
    exit 1
  fi
else
  downLoadImage
fi

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo " Now copy the image file $FILENAME to your SD-CARD"
echo " ATTENTION - You will loose all existing files on the SD-CARD."
echo " You can e.g. use etcher (https://etcher.io/) to do this."
echo " After you are finished with etcher unplug the SD-CARD from your mac"
echo " and plug it in again, so that it gets mounted!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

exit 0
#============================
#  End
#============================
