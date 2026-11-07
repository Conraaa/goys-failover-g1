# 2026-11-05 00:43:38 by RouterOS 7.15.3
# software id =
#
/disk
set slot1 media-interface=none media-sharing=no slot=slot1
set slot2 media-interface=none media-sharing=no slot=slot2
set slot3 media-interface=none media-sharing=no slot=slot3
set slot4 media-interface=none media-sharing=no slot=slot4
set slot5 media-interface=none media-sharing=no slot=slot5
set slot6 media-interface=none media-sharing=no slot=slot6
set slot7 media-interface=none media-sharing=no slot=slot7
set slot8 media-interface=none media-sharing=no slot=slot8
set slot9 media-interface=none media-sharing=no slot=slot9
/interface bridge
add name=loopback
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
/port
set 0 name=serial0
/routing bgp template
add as=65001 name=default router-id=1.1.1.1
/ip address
add address=1.1.1.1 interface=loopback network=1.1.1.1
add address=10.0.1.1/30 interface=ether1 network=10.0.1.0
/ip dhcp-client
add interface=ether1
/ip firewall address-list
add address=1.1.1.1 list=bgp-networks
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65001 local.address=10.0.1.1 .role=ebgp name=to-EDGE output.network=bgp-networks,0.0.0.0/0 remote.address=10.0.1.2 .as=65000 tcp-md5-key=bgp-secret-g1 templates=default
/system identity
set name=ISP-1
/system note
set show-at-login=no