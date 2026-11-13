# =============================================================================
# Configuracion Final: CORE-2 (RouterOS v7)
# Rol: R3 - Core Switching & Routing | Grupo 1
# =============================================================================

/system identity
set name=CORE-2

/system note
set show-at-login=no

/interface bridge
add name=loopback

/ip address
add address=5.5.5.5 interface=loopback network=5.5.5.5 comment="Loopback CORE-2"
add address=10.0.4.2/30 interface=ether1 network=10.0.4.0 comment="Enlace hacia EDGE"
add address=10.0.5.2/30 interface=ether2 network=10.0.5.0 comment="Enlace redundante Core-Core hacia CORE-1"
add address=10.0.8.1/30 interface=ether3 network=10.0.8.0 comment="Enlace hacia DIST-1"
add address=10.0.9.1/30 interface=ether4 network=10.0.9.0 comment="Enlace hacia DIST-2"

# Hardening de servicios
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes

# OSPF Area 0 (IGP)
/routing ospf instance
add disabled=no name=ospf1 router-id=5.5.5.5

/routing ospf area
add disabled=no instance=ospf1 name=backbone

/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 cost=10 disabled=no interfaces=ether1,ether3,ether4 type=ptp
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 cost=10 disabled=no interfaces=ether2 type=ptp comment="Core-Core link"
add area=backbone disabled=no interfaces=loopback passive

