#! /bin/bash

help()
{
	  echo " sudo rpi_mesh_ibss_setup.sh -install/-clean -i wlan0 -a "192.168.4.5""
  }

  if [ "$1" = "-install" ];
  then
  do_install=1;
  fi

  if [ "$1" = "-clean" ];
  then
  do_clean=1;
  fi

  while getopts ":a:i:h" option; do
	    case $option in
		        a)
				       ip_addr=${OPTARG};;
				           i)
						          if=${OPTARG};;
								      h) help
									             exit;;
										         esac
										 done

										 echo "Setting up MESH IBSS mode(batman-adv) setup in RPI"
										 if [ "$do_install" = "1" ];
										 then
											 echo "install RPI MESH IBSS configuration"
											 echo $if $ip_addr
											 apt-get update
											 apt-get install udhcpd dnsmasq iptables-persistent
											 touch /var/lib/misc/udhcpd.lease

											 test -f /etc/dhcpcd.conf && cp /etc/dhcpcd.conf /etc/dhcpcd.conf.ibss
											 test -f /etc/udhcpd.conf && cp /etc/udhcpd.conf /etc/udhcpd.conf.ibss

											 cat > /etc/dhcpcd.conf <<EOF
denyinterfaces $if
EOF
#echo 'denyinterfaces $if' | tee  /etc/dhcpcd.conf

cat > /etc/udhcpd.conf <<EOF
start    $ip_addr
stop    192.168.4.254
interface   bat0
max_leases    64
EOF


test -f /etc/rc.local | cp /etc/rc.local /etc/rc.local.ibss
cat > ./tmp.conf<<EOF
#!/bin/bash
modprobe batman-adv
ifconfig $if down
iwconfig $if mode ad-hoc
ifconfig $if mtu 1560
iwconfig $if essid RPI-MESH-IBSS
sleep 5
#ifconfig $if $ip_addr
ifconfig $if up
udhcpd /etc/udhcpd.conf

sleep5
batctl if add $if
ifconfig bat0 $ip_addr
ifconfig bat0 up

exit 0
EOF

rm -f /etc/rc.local
mv ./tmp.conf /etc/rc.local
rm -f ./tmp.conf

chmod ug+x /etc/rc.local
echo "configuration completed!"
fi

if [ "$do_clean" = "1" ];
then
	echo "cleaning MESH IBSS configuration!"
	test -f /etc/dhcpcd.conf.ibss && cp /etc/dhcpcd.conf.ibss /etc/dhcpcd.conf
	test -f /etc/udhcpd.conf && cp /etc/udhcpd.conf.ibss /etc/udhcpd.conf
	test -f /etc/rc.local && cp /etc/rc.local.ibss /etc/rc.local
	rm /etc/dhcpcd.conf.ibss
	rm /etc/udhcpd.conf.ibss
	rm /etc/rc.local.ibss
fi
