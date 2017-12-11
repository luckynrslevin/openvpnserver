#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ./01-InitCAandCreateServerKeys.sh -d [fully qualified DynDNS name]
#%                     -i [IP adress of you local DNS server]
#%
#% DESCRIPTION
#%    This script generates the Certificate Authority to be able to issued
#%    and sign certificates for your OpenVPN server.
#%
#% OPTIONS
#%    -d        Your official Dynamic DNS hostname.
#%              The hostname has to be reachable from the internet.
#%    -i        The IP address of the DNS server in your local home network
#%              Usually this is the IP address of your internet router.
#%    -e        Your E-Mail address, if you want to get notified on debian updates
#%              that have been automatically installed.
#%    -p        The password of your E-Mail account. This is needed for the notification
#%              on debian updates. If you do not trust me and my script, just type in
#%              something, e.g. verysecure. But in this case you later on have to manually
#%              change it in the file /etc/exim4/passwd.client on the server.
#%    -s        smtp server and port of your E-Mail provider in the format:
#%              <smtpserver.providerdomain.something>:<port>, e.g. smtp.myprovider.com:587
#%
#% EXAMPLES
#%      ./01-InitCAandCreateServerKeys.sh -d name.dyndnsprovider.com \
#%                                          -i 192.168.0.1 \
#%                                          -e Firstname.Lastname@mydomain.com \
#%                                          -p your E-Mail Password \
#%                                          -s smtp.mydomain.com:587
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

#

#============================
#  FUNCTIONS
#============================

#== help function ==#
function help {
  echo "
Usage: ./01-InitCAandCreateServerKeys.sh -d <your DynamicDNS hostname> -i <IP address of your local DNS server>
Switches:
  -d        Your official Dynamic DNS hostname.
            The hostname has to be reachable from the internet.
  -i        The IP address of the DNS server in your local home network
            Usually this is the IP address of your internet router.
  -e        Your E-Mail address, if you want to get notified on debian updates
            that have been automatically installed.
  -p        The password of your E-Mail account. This is needed for the notification
            on debian updates. If you do not trust me and my script, just type in
            something, e.g. verysecure. But in this case you later on have to manually
            change it in the file /etc/exim4/passwd.client on the server.
  -s        smtp server and port of your E-Mail provider in the format:
            <smtpserver.providerdomain.something>:<port>, e.g. smtp.myprovider.com:587
Example:
  ./01-InitCAandCreateServerKeys.sh -d name.dyndnsprovider.com \
                                    -i 192.168.0.1 \
                                    -e Firstname.Lastname@mydomain.com \
                                    -p your E-Mail Password \
                                    -s smtp.mydomain.com:587
"
  exit 1
}


#============================
#  Check script prerequisites
#============================

# Requires exactly 4 input parameters
if [ "$#" -ne 10 ]; then
  echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  echo "The Script requires all input parameters"
  echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  help
fi

# Exit if CA was already created before.
if [ -d "PKI_CA" ]; then
  echo '!!!!!!!!!!!!!!!!!!'
  echo 'Directory PKI_CA already exists, that means you already have created a CA
and certificates. If you really want to recreate all your certificates please
manually remove the directory before you start this script.'
  echo '!!!!!!!!!!!!!!!!!!'
  exit 1
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

# Is docker up and running?
if [ $($USE_SUDO docker ps -a 2>&1 | grep -i 'Cannot connect to the Docker daemon' | wc -l) -eq 1 ]; then
  echo "Cannot connect to the Docker daemon. Is the docker daemon running on this host?"
  exit 1
else
   docker pull $OPEN_VPN_DOCKER_NAME:latest
fi

#============================
#  PARSE OPTIONS WITH GETOPTS
#============================
# Getopts
while getopts d:i:e:p:s: FLAG; do
  case $FLAG in
    d)
      OVPN_HOSTNAME=$OPTARG
      ;;
    i)
      OVPN_DNS=$OPTARG
      ;;
    e)
      EMAIL=$OPTARG
      ;;
    p)
      EMAIL_PW=$OPTARG
      ;;
    s)
      EMAIL_SMTP=$OPTARG
      ;;
    h)  #show help
      help
      ;;
    /?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      ;;
  esac
done

#============================
#  Main
#============================

echo 'Create OpenVPN Server and Root CA configuration ...'
$USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_genconfig -u udp://$OVPN_HOSTNAME -n $OVPN_DNS -s $OVPN_SERVER -z -N -d -b -C $OVPN_CIPHER -a $OVPN_AUTH  -T $OVPN_TLS_CIPHER -e "tls-version-min 1.2" -e "remote-cert-tls client" -p "redirect-gateway def1"
echo 'Initialize Root CA and create OpenVPN Server certificates ...'
$USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_initpki
echo 'Copy OpenVPN Server certificates to local machine ...'
$USE_SUDO docker run --net=none --rm -t -i -v $PWD/PKI_CA:/etc/openvpn $OPEN_VPN_DOCKER_NAME ovpn_copy_server_files

sed -i.bak 's/user nobody/user openvpn/' PKI_CA/server/openvpn.conf
sed -i.bak 's/user nobody/user openvpn/' PKI_CA/openvpn.conf

# Generate root password:
ROOT_PW=$(openssl rand -base64 20 | tr -d '\n')
sed -i.bak "s/rootpw=.*/rootpw=$ROOT_PW/" raspberrypi-ua-netinst/config/installer-config.txt
rm raspberrypi-ua-netinst/config/installer-config.txt.bak

USER_PW=$(openssl rand -base64 20 | tr -d '\n')
sed -i.bak "s/userpw=.*/userpw=$USER_PW/" raspberrypi-ua-netinst/config/installer-config.txt
rm raspberrypi-ua-netinst/config/installer-config.txt.bak

# Copy the server files to the raspberrypi-ua-netinst/config Directory
SRC_DIR='PKI_CA/server'
DST_DIR='raspberrypi-ua-netinst/config/files'
mkdir -p $DST_DIR/root/etc/openvpn/pki/issued
mkdir -p $DST_DIR/root/etc/openvpn/pki/private
mkdir -p $DST_DIR/root/etc/openvpn/server
cp $SRC_DIR/pki/ca.crt $DST_DIR/root/etc/openvpn/pki
cp $SRC_DIR/pki/dh.pem $DST_DIR/root/etc/openvpn/pki
cp $SRC_DIR/pki/ta.key $DST_DIR/root/etc/openvpn/pki
cp $SRC_DIR/pki/private/$OVPN_HOSTNAME.key $DST_DIR/root/etc/openvpn/pki/private/$OVPN_HOSTNAME.key
echo "root:root 600 /etc/openvpn/pki/private/$OVPN_HOSTNAME.key" > $DST_DIR/ovpn4.list
cp $SRC_DIR/pki/issued/$OVPN_HOSTNAME.crt $DST_DIR/root/etc/openvpn/pki/issued/$OVPN_HOSTNAME.crt
echo "root:root 600 /etc/openvpn/pki/issued/$OVPN_HOSTNAME.crt" > $DST_DIR/ovpn5.list
cp $SRC_DIR/openvpn.conf $DST_DIR/root/etc/openvpn/server/openvpn.conf
cp $SRC_DIR/ovpn_env.sh $DST_DIR/root/etc/openvpn/server/ovpn_env.sh


# exmim4 - Configure /etc/email-addresses
cat <<EOF > raspberrypi-ua-netinst/config/files/root/etc/email-addresses
# setup exim4 configuration for E-Mail notification on debian updates

# This is /etc/email-addresses. It is part of the exim package
#
# This file contains email addresses to use for outgoing mail. Any local
# part not in here will be qualified by the system domain as normal.
#
# It should contain lines of the form:
#
#user: someone@isp.com
#otheruser: someoneelse@anotherisp.com
vpn: $EMAIL
root: $EMAIL
EOF
echo "root:root 644 /etc/email-addresses" > raspberrypi-ua-netinst/config/files/exim1.list

# exmim4 - Configure /etc/aliases
cat <<EOF > raspberrypi-ua-netinst/config/files/root/etc/aliases
# /etc/aliases
mailer-daemon: postmaster
postmaster: root
nobody: root
hostmaster: root
usenet: root
news: root
webmaster: root
www: root
ftp: root
abuse: root
noc: root
security: root
vpn: $EMAIL
EOF
echo "root:root 644 /etc/aliases" > raspberrypi-ua-netinst/config/files/exim2.list

# exim4 - configure /etc/exim4/passwd.client
EMAIL_SMTP_SERVER=$(echo $EMAIL_SMTP |  awk -F: '{print $1}')
mkdir -p raspberrypi-ua-netinst/config/files/root/etc/exim4/
echo "$EMAIL_SMTP_SERVER:$EMAIL:$EMAIL_PW" > raspberrypi-ua-netinst/config/files/root/etc/exim4/passwd.client
echo "root:Debian-exim 640 /etc/exim4/passwd.client" > raspberrypi-ua-netinst/config/files/exim3.list

# exim4 - configure /etc/exim4/update-exim4.conf.conf
EMAIL_SMTP_TMP=$(echo $EMAIL_SMTP | sed 's/:/::/')
cat <<EOF > raspberrypi-ua-netinst/config/files/root/etc/exim4/update-exim4.conf.conf
# /etc/exim4/update-exim4.conf.conf
#
# Edit this file and /etc/mailname by hand and execute update-exim4.conf
# yourself or use 'dpkg-reconfigure exim4-config'
#
# Please note that this is _not_ a dpkg-conffile and that automatic changes
# to this file might happen. The code handling this will honor your local
# changes, so this is usually fine, but will break local schemes that mess
# around with multiple versions of the file.
#
# update-exim4.conf uses this file to determine variable values to generate
# exim configuration macros for the configuration file.
#
# Most settings found in here do have corresponding questions in the
# Debconf configuration, but not all of them.
#
# This is a Debian specific file

dc_eximconfig_configtype='smarthost'
dc_other_hostnames=''
dc_local_interfaces='127.0.0.1'
dc_readhost=''
dc_relay_domains=''
dc_minimaldns='false'
dc_relay_nets=''
dc_smarthost='$EMAIL_SMTP_TMP'
CFILEMODE='644'
dc_use_split_config='false'
dc_hide_mailname='false'
dc_mailname_in_oh='true'
dc_localdelivery='mail_spool'
EOF
echo "root:root 644 /etc/exim4/update-exim4.conf.conf" > raspberrypi-ua-netinst/config/files/exim4.list


# Print passwords
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
echo "ATTENTION  remember the passwords for YOUR installation"
echo "User:vpn          Password:$USER_PW"
echo "User:root         Password:$ROOT_PW"
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

exit 0
#============================
#  End
#============================
