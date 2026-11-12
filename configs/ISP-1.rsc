# =============================================================================
# Configuracion Final: ISP-1 (RouterOS v7)
# Rol: R2 - WAN & Edge BGP | Grupo 1
# =============================================================================

/system identity
set name=ISP-1

/system note
set show-at-login=no

/interface bridge
add name=loopback

/ip address
add address=1.1.1.1 interface=loopback network=1.1.1.1 comment="Simulacion Internet Publica"
add address=10.0.1.1/30 interface=ether1 network=10.0.1.0 comment="Enlace WAN hacia EDGE"

# Hardening de servicios
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes

# BGP Exterior (AS 65001)
/ip firewall address-list
add address=1.1.1.1 list=bgp-networks

/routing bgp template
add as=65001 name=default router-id=1.1.1.1

/routing bgp connection
add as=65001 local.address=10.0.1.1 .role=ebgp name=to-EDGE output.network=bgp-networks,0.0.0.0/0 remote.address=10.0.1.2 .as=65000 tcp-md5-key=bgp-secret-g1 templates=default

