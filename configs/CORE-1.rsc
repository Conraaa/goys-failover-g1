# =============================================================================
# Configuracion Final: CORE-1 (RouterOS v7)
# Rol: R3 - Core Switching & Routing | Grupo 1
# =============================================================================

/system identity
set name=CORE-1

/system note
set show-at-login=no

/interface bridge
add name=loopback

/ip address
add address=4.4.4.4 interface=loopback network=4.4.4.4 comment="Loopback CORE-1"
add address=10.0.3.2/30 interface=ether1 network=10.0.3.0 comment="Enlace hacia EDGE"
add address=10.0.5.1/30 interface=ether2 network=10.0.5.0 comment="Enlace redundante Core-Core hacia CORE-2"
add address=10.0.6.1/30 interface=ether3 network=10.0.6.0 comment="Enlace hacia DIST-1"
add address=10.0.7.1/30 interface=ether4 network=10.0.7.0 comment="Enlace hacia DIST-2"

# Hardening de servicios
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes

# OSPF Area 0 (IGP)
/routing ospf instance
add disabled=no name=ospf1 router-id=4.4.4.4

/routing ospf area
add disabled=no instance=ospf1 name=backbone

/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 cost=10 disabled=no interfaces=ether1,ether3,ether4 type=ptp
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 cost=10 disabled=no interfaces=ether2 type=ptp comment="Core-Core link"
add area=backbone disabled=no interfaces=loopback passive

