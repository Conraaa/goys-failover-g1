# =============================================================================
# Configuracion Final: EDGE (RouterOS v7)
# Rol: R1 - Lider / Edge-WAN / Firewall | Grupo 1
# =============================================================================

/system identity
set name=EDGE

/system note
set show-at-login=no

/interface bridge
add name=loopback

/ip address
add address=3.3.3.3 interface=loopback network=3.3.3.3 comment="Loopback EDGE"
add address=10.0.1.2/30 interface=ether1 network=10.0.1.0 comment="WAN ISP-1 Primario"
add address=10.0.2.2/30 interface=ether2 network=10.0.2.0 comment="WAN ISP-2 Backup"
add address=10.0.3.1/30 interface=ether3 network=10.0.3.0 comment="Transito hacia CORE-1"
add address=10.0.4.1/30 interface=ether4 network=10.0.4.0 comment="Transito hacia CORE-2"

# Hardening de servicios de gestion
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes

# OSPF Area 0 (IGP)
/routing ospf instance
add disabled=no name=ospf1 originate-default=always redistribute=bgp router-id=3.3.3.3

/routing ospf area
add disabled=no instance=ospf1 name=backbone

/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 cost=10 disabled=no interfaces=ether3,ether4 type=ptp
add area=backbone disabled=no interfaces=loopback passive

# BGP Multi-Homing (EGP)
/routing bgp template
add as=65000 name=default router-id=3.3.3.3

/routing bgp connection
add as=65000 local.address=10.0.1.2 .role=ebgp name=to-ISP1 output.redistribute=ospf remote.address=10.0.1.1 .as=65001 tcp-md5-key=bgp-secret-g1 templates=default
add as=65000 local.address=10.0.2.2 .role=ebgp name=to-ISP2 output.redistribute=ospf remote.address=10.0.2.1 .as=65002 tcp-md5-key=bgp-secret-g1 templates=default

# Rutas estaticas de respaldo con check-gateway
/ip route
add check-gateway=ping distance=1 dst-address=0.0.0.0/0 gateway=10.0.1.1 comment="Ruta por defecto ISP-1 con sondeo ICMP"
add distance=2 dst-address=0.0.0.0/0 gateway=10.0.2.1 comment="Ruta por defecto ISP-2 flotante"

# Firewall perimetral y gestion segura
/ip firewall filter
add action=accept chain=input comment="Aceptar trafico de conexiones establecidas y relacionadas" connection-state=established,related
add action=accept chain=input comment="Aceptar pings de diagnostico" protocol=icmp
add action=accept chain=input comment="Permitir OSPF desde CORE-1" in-interface=ether3 protocol=ospf
add action=accept chain=input comment="Permitir OSPF desde CORE-2" in-interface=ether4 protocol=ospf
add action=accept chain=input comment="Permitir BGP desde ISP-1" dst-port=179 in-interface=ether1 protocol=tcp
add action=accept chain=input comment="Permitir BGP desde ISP-2" dst-port=179 in-interface=ether2 protocol=tcp
add action=accept chain=input comment="Acceso de gestion Winbox/SSH desde LAN via CORE-1" in-interface=ether3
add action=accept chain=input comment="Acceso de gestion Winbox/SSH desde LAN via CORE-2" in-interface=ether4
add action=drop chain=input comment="Bloquear todo trafico de entrada no autorizado desde WAN ISP-1" in-interface=ether1
add action=drop chain=input comment="Bloquear todo trafico de entrada no autorizado desde WAN ISP-2" in-interface=ether2
add action=accept chain=forward comment="Permitir retorno de trafico de Internet establecido/relacionado" connection-state=established,related
add action=drop chain=forward comment="Bloquear paquetes invalidos" connection-state=invalid
add action=drop chain=forward comment="Bloquear intentos de conexion nuevos iniciados desde ISP-1" connection-state=new in-interface=ether1
add action=drop chain=forward comment="Bloquear intentos de conexion nuevos iniciados desde ISP-2" connection-state=new in-interface=ether2

# Monitoreo activo Netwatch
/tool netwatch
add comment="Monitoreo ISP-1 Primario" down-script=":log warning \"[NETWATCH] ISP-1 DOWN - Failover a ISP-2\"" host=10.0.1.1 interval=10s up-script=":log info \"[NETWATCH] ISP-1 UP - Enlace Primario Restablecido\""
add comment="Monitoreo ISP-2 Backup" down-script=":log warning \"[NETWATCH] ISP-2 DOWN\"" host=10.0.2.1 interval=10s up-script=":log info \"[NETWATCH] ISP-2 UP\""

# Monitoreo SNMP
/snmp community
set [ find default=yes ] addresses=192.168.20.0/24 name=public read-access=yes
/snmp
set enabled=yes contact="admin@failover-g1.local" location="Datacenter Edge Rack 1"

