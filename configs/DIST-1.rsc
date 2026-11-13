# =============================================================================
# Configuracion Final: DIST-1 (RouterOS v7)
# Rol: R4 - Distribucion & VRRP | Grupo 1
# =============================================================================

/system identity
set name=DIST-1

/system note
set show-at-login=no

/interface bridge
add name=loopback

/interface vrrp
add authentication=simple disabled=no interface=ether3 name=vrrp-users password=vrrpg1 priority=150 version=2 vrid=10 comment="Master USERS"
add authentication=simple disabled=no interface=ether4 name=vrrp-servers password=vrrpg1 priority=100 version=2 vrid=20 comment="Backup SERVERS"

/ip address
add address=6.6.6.6 interface=loopback network=6.6.6.6 comment="Loopback DIST-1"
add address=10.0.6.2/30 interface=ether1 network=10.0.6.0 comment="Enlace hacia CORE-1"
add address=10.0.8.2/30 interface=ether2 network=10.0.8.0 comment="Enlace hacia CORE-2"
add address=192.168.10.2/24 interface=ether3 network=192.168.10.0 comment="IP real LAN USERS"
add address=192.168.20.2/24 interface=ether4 network=192.168.20.0 comment="IP real LAN SERVERS"
add address=192.168.10.1/24 interface=vrrp-users network=192.168.10.0 comment="VIP Gateway USERS"
add address=192.168.20.1/24 interface=vrrp-servers network=192.168.20.0 comment="VIP Gateway SERVERS"

# Hardening de servicios
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes

# OSPF Area 0 (IGP)
/routing ospf instance
add disabled=no name=ospf1 router-id=6.6.6.6

/routing ospf area
add disabled=no instance=ospf1 name=backbone

/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 cost=10 disabled=no interfaces=ether1,ether2 type=ptp
add area=backbone disabled=no interfaces=ether3,ether4,loopback passive

