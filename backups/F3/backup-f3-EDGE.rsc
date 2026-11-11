# 2026-11-05 00:41:26 by RouterOS 7.15.3
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
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/port
set 0 name=serial0
/routing bgp template
add as=65000 name=default router-id=3.3.3.3
/routing ospf instance
add disabled=no name=ospf1 originate-default=always redistribute=bgp router-id=3.3.3.3
/routing ospf area
add disabled=no instance=ospf1 name=backbone
/ip address
add address=3.3.3.3 interface=loopback network=3.3.3.3
add address=10.0.1.2/30 interface=ether1 network=10.0.1.0
add address=10.0.2.2/30 interface=ether2 network=10.0.2.0
add address=10.0.3.1/30 interface=ether3 network=10.0.3.0
add address=10.0.4.1/30 interface=ether4 network=10.0.4.0
/ip dhcp-client
add interface=ether1
/ip firewall filter
add action=accept chain=input comment="Aceptar trafico de conexiones establecidas" connection-state=established,related
add action=accept chain=input comment="Aceptar pings" protocol=icmp
add action=accept chain=input comment="Permitir OSPF desde CORE-1" in-interface=ether3 protocol=ospf
add action=accept chain=input comment="Permitir OSPF desde CORE-2" in-interface=ether4 protocol=ospf
add action=accept chain=input comment="Permitir BGP ISP-1" dst-port=179 in-interface=ether1 protocol=tcp
add action=accept chain=input comment="Permitir BGP ISP-2" dst-port=179 in-interface=ether2 protocol=tcp
add action=accept chain=input comment="Acceso gestion desde LAN via CORE-1" in-interface=ether3
add action=accept chain=input comment="Acceso gestion desde LAN via CORE-2" in-interface=ether4
add action=drop chain=input comment="Bloquear input desde WAN ISP-1" in-interface=ether1
add action=drop chain=input comment="Bloquear input desde WAN ISP-2" in-interface=ether2
add action=accept chain=forward comment="Permitir retorno de trafico de Internet" connection-state=established,related
add action=drop chain=forward comment="Bloquear paquetes invalidos" connection-state=invalid
add action=drop chain=forward comment="Bloquear inicio de conexiones desde ISP-1" connection-state=new in-interface=ether1
add action=drop chain=forward comment="Bloquear inicio de conexiones desde ISP-2" connection-state=new in-interface=ether2
/ip route
add dst-address=0.0.0.0/0 gateway=10.0.1.1
add dst-address=0.0.0.0/0 gateway=10.0.1.1
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65000 local.address=10.0.1.2 .role=ebgp name=to-ISP1 output.redistribute=ospf remote.address=10.0.1.1 .as=65001 tcp-md5-key=bgp-secret-g1 templates=default
add as=65000 local.address=10.0.2.2 .role=ebgp name=to-ISP2 output.redistribute=ospf remote.address=10.0.2.1 .as=65002 tcp-md5-key=bgp-secret-g1 templates=default
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 disabled=no interfaces=ether3,ether4 type=ptp
add area=backbone disabled=no interfaces=loopback passive
/system identity
set name=EDGE
/system note
set show-at-login=no