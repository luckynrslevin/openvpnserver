#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ./04-Client.sh -d [fully qualified DynDNS name]
#%                     -c [clientname]
#%
#% DESCRIPTION
#%    This script generates the Certificate Authority to be able to issued
#%    and sign certificates for your OpenVPN server.
#%
#% OPTIONS
#%    -d <DynDNS Name>  MANDATORY! Your official Dynamic DNS hostname.
#%                      The hostname has to be reachable from the internet.
#%    -c <clientname>   create a client ovpn file for client <hostname>.
#%    -g <clientname>   get the ovpn text file of client <hostname>.
#%    -r <clientname>   remove client <hostname> from PKI.
#%    -l                list existsing client certifactes.
#%
#% EXAMPLES
#%    ./04-Client.sh -d name.dyndnsprovider.com -i myiphone
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
# Source config
if [ ! -r ".config" ]; then
  echo "Config file \".config\" does not exist or is not readable"
  exit 1
fi
. .config

HAS_DYNDNS_NAME=0
OVPN_FUNCTION=''

#============================
#  FUNCTIONS
#============================
#help function
help () {
  echo "
help documentation for handling openvpn client certificates
Usage: $0 [switch] <value>
Switches:
  -d <DynDNS Name>  MANDATORY! Your official Dynamic DNS hostname.
                    The hostname has to be reachable from the internet.
  -c <clientname>   create a client ovpn file for client <hostname>.
  -g <clientname>   get the ovpn text file of client <hostname>.
  -r <clientname>   remove client <hostname> from PKI.
  -l                list existsing client certifactes.
"
  exit 1
}

function create () {
  $USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_genconfig -a -z -C $OVPN_CIPHER -a $OVPN_AUTH $OVPN_DNS -E "tls-version-min 1.2" -T $OVPN_TLS_CIPHER -u udp://$OVPN_HOSTNAME
  $USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME easyrsa build-client-full $CLIENT nopass
  $USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_getclient $CLIENT > $CLIENT.ovpn

  # Secure file access rights
  chmod 600 $CLIENT.ovpn
}

function remove () {
  $USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_revokeclient $CLIENT remove
}

function get () {
  $USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_getclient $CLIENT
}

function list () {
  $USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_listclients
}

#============================
#  Check script prerequisites
#============================

# Requires exactly 4 input parameters
if [ "$#" -eq 0 ]; then
  echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  echo "The Script requires parameters"
  echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  help
fi

# Make sure we run as root or use sudo.
USE_SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  while true; do
    read -p "Not running with root, use sudo [y|n]?" yn
    case $yn in
        [Yy]* ) USE_SUDO="sudo"; break;;
        [Nn]* ) break;;
        * ) echo "Please answer y or n.";;
    esac
  done
fi

# Exit if docker daemon is not running
if [ $($USE_SUDO docker ps -a 2>&1 | grep -i 'Cannot connect to the Docker daemon' | wc -l) -eq 1 ]; then
  echo "Cannot connect to the Docker daemon. Is the docker daemon running on this host?"
  exit 1
else
   docker pull $OPEN_VPN_DOCKER_NAME:latest
fi


#============================
#  PARSE OPTIONS WITH getOPTS
#============================

while getopts d:c:r:g:l FLAG; do
  case $FLAG in
    d)
      OVPN_HOSTNAME=$OPTARG
      HAS_DYNDNS_NAME=1
      ;;
    c)
      CLIENT=$OPTARG
      OVPN_FUNCTION='create'
      ;;
    r)
      CLIENT=$OPTARG
      OVPN_FUNCTION='remove'
      ;;
    g)
      CLIENT=$OPTARG
      OVPN_FUNCTION='get'
      ;;
    l)
      list
      exit 0
      ;;
    /?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      ;;
  esac
done

if [ $HAS_DYNDNS_NAME -eq 1 ] && [ ! "X$OVPN_FUNCTION" = "X" ]; then
  $OVPN_FUNCTION
else
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "You have missing mandatory parameters!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  help
fi

exit 0
#============================
#  End
#============================
