#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ./ovpn_setup_iptables.sh
#%
#% DESCRIPTION
#%    This script generates and persists
#%    1) the iptables & ip6tables configuration
#%    and
#%    2) the OpenVPN configuration
#%    for all future startups.
#%
#%    It only needs to be run once!
#%
#% OPTIONS
#%
#% EXAMPLES
#%      ./ovpn_setup_iptables.sh
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

#########################################
# Variables
#########################################
SUCCESS='/var/log/ovpn_setup_iptables.SUCCESS'
IP_V4_RULES='/tmp/ipv4rules'
IP_V6_RULES='/tmp/ipv6rules'
OVPN_SUBNET='10.73.67.0/24'

#########################################
# functions
#########################################
fail () {
  echo "An error occured, exiting"
  exit 1
}

#########################################
# Start main
#########################################

# Script needs to run with root privilidges
echo -n "Checking whether we are running as root ..."
if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires root privilidges"
  fail
fi
echo "OK"

# Check if we were already run successfully before.
# No need for a second run ...
echo -n "Checking if we need to run ..."
if [ -f  $SUCCESS ]; then
  echo "NOT OK"
  echo "NO need to run a second time, everything is already configured."
  exit 0
fi
echo "OK"

# Get active network interface
echo -n "Get active network interface ..."
IFACE=$(ip link show |grep LOWER_UP | grep 'state UP' | awk -F ' ' '{print $2}' | tr -d '\n' | tr -d ':') || fail
echo "$IFACE"

# define iptables rules
echo -n "Creating $IP_V4_RULES ..."
cat <<EOF > $IP_V4_RULES
# IPv4 filters
*filter
# Loopback rules, tell iptables to only accept looback traffic originating from localhost.
-A INPUT -i lo -j ACCEPT
-A INPUT ! -i lo -s 127.0.0.0/8 -j REJECT
-A OUTPUT -o lo -j ACCEPT
# Allow all incoming traffic related to allowed outgoing traffic initiated by the server
-I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# Allowing Ping
-A INPUT -p icmp -m state --state NEW --icmp-type 8 -j ACCEPT
-A INPUT -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -p icmp -j ACCEPT
# Allow ssh
-A INPUT -i $IFACE -p tcp -m state --state NEW,ESTABLISHED --dport 22 -j ACCEPT
-A OUTPUT -o $IFACE -p tcp -m state --state ESTABLISHED --sport 22 -j ACCEPT
# Allow VPN
-A INPUT -i $IFACE -p udp -m state --state NEW,ESTABLISHED --dport 1194 -j ACCEPT
-A OUTPUT -o $IFACE -p udp -m state --state ESTABLISHED --sport 1194 -j ACCEPT
# Allow DNS
-A OUTPUT -o $IFACE -p udp -m state --state NEW,ESTABLISHED --dport 53 -j ACCEPT
-A OUTPUT -o $IFACE -p tcp -m state --state NEW,ESTABLISHED --dport 53 -j ACCEPT
# Allow http/s for updates
-A OUTPUT -o $IFACE -p tcp -m state --state NEW,ESTABLISHED --dport 80 -j ACCEPT
-A OUTPUT -o $IFACE -p tcp -m state --state NEW,ESTABLISHED --dport 443 -j ACCEPT
# Allow sending E-Mails / smtp
-A OUTPUT -o $IFACE -p tcp -m state --state NEW,ESTABLISHED --dport 465 -j ACCEPT
-A OUTPUT -o $IFACE -p tcp -m state --state NEW,ESTABLISHED --dport 587 -j ACCEPT
# Allow ntp to sync clock
-A OUTPUT -o $IFACE -p udp -m state --state NEW,ESTABLISHED --dport 123 -j ACCEPT
# Allow TUN to tunnel through the VPN
-A INPUT -i tun0 -j ACCEPT
-A FORWARD -i tun0 -j ACCEPT
-A OUTPUT -o tun0 -j ACCEPT
# For the VPN to forward your traffic to the Internet,
# you need to enable forwarding from TUN to your physical network interface
-A FORWARD -i tun0 -o $IFACE -s $OVPN_SUBNET -j ACCEPT
-A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
# Log blocked traffic
-A INPUT -m limit --limit 3/min -j LOG --log-prefix "iptables_INPUT_denied: " --log-level 4
-A FORWARD -m limit --limit 3/min -j LOG --log-prefix "iptables_FORWARD_denied: " --log-level 4
-A OUTPUT -m limit --limit 3/min -j LOG --log-prefix "iptables_OUTPUT_denied: " --log-level 4
# Reject all other traffic
-A INPUT -j REJECT
-A FORWARD -j REJECT
-A OUTPUT -j REJECT
COMMIT
EOF
echo "OK"

# define ip6tables rules
echo -n "Creating $IP_V6_RULES ..."
cat <<EOF > $IP_V6_RULES
# IPv6 filters
*filter
# Block all IPv6 traffic
-A INPUT -j REJECT
-A FORWARD -j REJECT
-A OUTPUT -j REJECT
COMMIT
EOF
echo "OK"

#Flush existing rules and commit new rules
echo -n "Flush all existing iptables rules ..."
iptables -F && iptables -t nat -F && iptables -X || fail
echo "OK"
echo -n "Flush all existing ip6tables rules ..."
ip6tables -F && ip6tables -t nat -F && ip6tables -X || fail
echo "OK"

# NAT
# This next part requires a different table. You can't add it to the same file,
# so you'll just have to run the command manually.
# Make traffic from the VPN masquerade as traffic from the physical network interface.
echo -n "Enable NAT in iptables ..."
iptables -t nat -A POSTROUTING -s $OVPN_SUBNET -o $IFACE -j MASQUERADE || fail
echo "OK"

echo -n "Import IPv4 rules to iptables ..."
iptables-restore < $IP_V4_RULES || fail
echo "OK"

echo -n "Import IPv6 rules to iptables ..."
ip6tables-restore < $IP_V6_RULES || fail
echo "OK"

echo -n "Persist iptables ..."
service netfilter-persistent save || fail
echo "OK"

# Next, open /etc/sysctl.d/99-sysctl.conf. Find and uncomment the following line.
# net.ipv4.ip_forward=1
echo -n "Enable IPv4 forwarding in /etc/sysctl.d/99-sysctl.conf ..."
sed -i.bak 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.d/99-sysctl.conf || fail
echo 1 > /proc/sys/net/ipv4/ip_forward || fail
echo "OK"

# Dsable IPv6 completely.
VAR_LIST="net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6 \
net.ipv6.conf.lo.disable_ipv6 net.ipv6.conf.eth0.disable_ipv6"

for VAR in $VAR_LIST; do
  EXISTS=$(cat /etc/sysctl.d/99-sysctl.conf | grep -P "^$VAR.*" | wc -l)

  if [ $EXISTS -eq 0 ]; then
    echo -n "$VAR does not exist in /etc/sysctl.d/99-sysctl.conf, create it ..."
    echo "$VAR = 1" >> /etc/sysctl.d/99-sysctl.conf || fail
    echo "OK"
  else
    echo "$VAR already exists in etc/sysctl.d/99-sysctl.conf"
  fi
done

# Apply changes
echo -n "Apply all changes with sysctl ..."
sysctl -p || fail
echo "OK"

echo "Successfully finished configuring iptables"

echo -n "Starting OpenVPN server ..."
systemctl start openvpn && systemctl start openvpn@server || fail
echo "OK"

echo -n "Enable OpenVPN server startup on boot ..."
systemctl enable openvpn && systemctl enable openvpn@server || fail
echo "OK"
echo "Successfully finished OpenVPN server configuration"

touch $SUCCESS
exit 0
