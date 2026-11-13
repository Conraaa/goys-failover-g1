# Memoria del Laboratorio - Failover Routing

**Grupo:** Grupo 1

**Materia:** Gestión Operativa y Seguridad en Redes (GOYS)

## Integrantes y roles

| Integrante | Rol |
|-----------|-----|
| Conrado Cemino | R1 (Edge-WAN), R3 (Core), R5 (Hosts/QA/Operación) |
| Romeo Monfroglio | R2 (Proveedores), R4 (Distribución) |

---

## 1. Diseño (F0)

### 1.1 Corrección del diagrama

| # | Defecto detectado | Corrección aplicada | Justificación |
|:-:|-------------------|---------------------|---------------|
| 1 | El ASA 5506-X es single point of failure (SPOF) | Implementar par de firewalls en HA (Activo/Standby) | Si falla el único firewall, la red entera pierde salida a Internet y protección. La redundancia en esta capa es crítica. |
| 2 | Subredes/VLANs repetidas entre sitios | Plan de direccionamiento IP limpio sin solapamientos (VLAN 10/20 separadas de otros sitios) | Previene problemas de enrutamiento y superposición de direcciones al interconectar sitios, asegurando rutas únicas. |
| 3 | Falta enlace core-core | Agregar enlace entre CORE-1 y CORE-2 | Permite sincronización directa, mejora la reconvergencia de OSPF y previene escenarios de path pinhole o aislamiento si se corta un enlace Edge-Core. |

### 1.2 Plan de direccionamiento (IPAM)

| Enlace / Red | Subred | Dispositivo A (IP/iface) | Dispositivo B (IP/iface) |
|--------------|:------:|--------------------------|--------------------------|
| ISP-1 ↔ EDGE | 10.0.1.0/30 | ISP-1 (.1) | EDGE (.2) |
| ISP-2 ↔ EDGE | 10.0.2.0/30 | ISP-2 (.1) | EDGE (.2) |
| EDGE ↔ CORE-1 | 10.0.3.0/30 | EDGE (.1) | CORE-1 (.2) |
| EDGE ↔ CORE-2 | 10.0.4.0/30 | EDGE (.1) | CORE-2 (.2) |
| CORE-1 ↔ CORE-2 (core-core) | 10.0.5.0/30 | CORE-1 (.1) | CORE-2 (.2) |
| CORE ↔ DIST-1 (×2) | 10.0.6.0/30 (desde C1) | CORE-1 (.1) | DIST-1 (.2) |
| CORE ↔ DIST-2 (×2) | 10.0.7.0/30 (desde C1) | CORE-1 (.1) | DIST-2 (.2) |
| CORE ↔ DIST-1 (×2) | 10.0.8.0/30 (desde C2) | CORE-2 (.1) | DIST-1 (.2) |
| CORE ↔ DIST-2 (×2) | 10.0.9.0/30 (desde C2) | CORE-2 (.1) | DIST-2 (.2) |
| USERS (gateway VRRP) | 192.168.10.0/24 | DIST-1 (.2) | DIST-2 (.3) |
| SERVERS (gateway VRRP) | 192.168.20.0/24 | DIST-1 (.2) | DIST-2 (.3) |

**VRRP:**

| Grupo | VRID | Master | Priority | IP virtual |
|-------|:----:|:------:|:--------:|:----------:|
| USERS | 10 | DIST-1 | 150 (DIST-2 = 100) | 192.168.10.1 |
| SERVERS | 20 | DIST-2 | 150 (DIST-1 = 100) | 192.168.20.1 |

**Router-IDs:** 
- ISP-1: 1.1.1.1
- ISP-2: 2.2.2.2
- EDGE: 3.3.3.3
- CORE-1: 4.4.4.4
- CORE-2: 5.5.5.5
- DIST-1: 6.6.6.6
- DIST-2: 7.7.7.7

### 1.3 Política de seguridad

- **Usuarios y privilegios:** Creación de usuario "admin-g1" con grupo full (reemplaza admin por defecto) y usuario "monitor-g1" con grupo read.
- **Servicios que se deshabilitan:** Se deshabilitan telnet, ftp, www, api, api-ssl (solo ssh y winbox habilitados).
- **Claves de autenticación** (OSPF / BGP / VRRP): ospf-secret-g1 / bgp-secret-g1 / vrrpg1 (se ajustó la clave de VRRP de `vrrp-secret-g1` a `vrrpg1` debido a que el estándar VRRPv2 / RFC 3768 restringe la contraseña de autenticación simple a un máximo de 8 caracteres).

### 1.4 Política de operación

- **Formato del change log:** Conventional Commits (ej. tipo(alcance): descripcion). Un commit por cambio lógico, cada rol commitea lo propio.
- **Política de backup:** Se ejecuta un /export file=backup-nombre al terminar cada epic (F1 a F4) y se almacena versionado en la carpeta backups/ del repositorio Git.

---

## 2. Topología (F1)

Se implementó la topología jerárquica de 5 capas en GNS3 compuesta por 11 nodos y 15 enlaces:
- **Internet:** 2 routers MikroTik CHR (`ISP-1` y `ISP-2`).
- **Edge:** 1 router MikroTik CHR (`EDGE`).
- **Core:** 2 routers MikroTik CHR (`CORE-1` y `CORE-2`) interconectados mediante enlace Core-Core.
- **Distribución:** 2 routers MikroTik CHR (`DIST-1` y `DIST-2`).
- **Acceso:** 2 switches Ethernet (`SW-ACC-USERS` y `SW-ACC-SERVERS`) conectados a 2 hosts (`PC-USER` y `SRV`).

```
[ INTERNET ]               ISP-1 (AS 65001)       ISP-2 (AS 65002)
                                   \                 /
                                    \               /
[ EDGE ]                             EDGE (AS 65000)
                                       /         \
                                      /           \
[ CORE ]                         CORE-1 ───────── CORE-2
                                   │    \       /    │
                                   │     \     /     │
                                   │      \   /      │
                                   │        X        │
                                   │       / \       │
                                   │      /   \      │
[ DISTRIBUTION ]                 DIST-1 ─┘     └─ DIST-2
                                   │    \       /    │
                                   │     \     /     │
                                   │      \   /      │
                                   │        X        │
                                   │       / \       │
                                   │      /   \      │
[ ACCESS ]                 SW-ACC-USERS ─┘     └─ SW-ACC-SERVERS
                                   │                 │
                                PC-USER             SRV
```

> **Diagrama visual de la arquitectura:** El diagrama vectorial de la topología completa de 5 capas se encuentra disponible en [`diagramas/topologia_5_capas.svg`](diagramas/topologia_5_capas.svg).
>
> **Snapshots de GNS3:**
> - `BASE`: Estado inicial con nodos cableados, direccionamiento base y conectividad L3 directa comprobada (F1).
> - `F2-VRRP-OSPF`: Convergencia interna completa con OSPF área 0 autenticado y VRRP activo-activo (F2).
> - `F3-BGP-FW`: Peering eBGP multi-homing con MD5 hacia ISPs, redistribución de rutas y firewall perimetral (F3).
> - `F5-FINAL`: Estado consolidado post-drills con monitoreo Netwatch/SNMP activo, listo para defensa operativa (F5).

---

## 3. Configuraciones finales

Las siguientes configuraciones representan la versión definitiva, limpia y consolidada de toda la red empresarial y proveedores tras completar las fases de diseño, enrutamiento dinámico, firewall perimetral, resiliencia y monitoreo. Los archivos `.rsc` listos para aprovisionar cada router desde cero se encuentran almacenados y versionados en la carpeta [`configs/`](../configs/).

### 3.1 ISP-1
```routeros
/interface bridge add name=loopback
/routing bgp template add as=65001 name=default router-id=1.1.1.1
/ip address
add address=1.1.1.1 interface=loopback network=1.1.1.1
add address=10.0.1.1/30 interface=ether1 network=10.0.1.0
/ip firewall address-list add address=1.1.1.1 list=bgp-networks
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65001 local.address=10.0.1.1 .role=ebgp name=to-EDGE \
    output.network=bgp-networks,0.0.0.0/0 remote.address=10.0.1.2 .as=65000 \
    tcp-md5-key=bgp-secret-g1 templates=default
/system identity set name=ISP-1
/system note set show-at-login=no
```

### 3.2 ISP-2
```routeros
/interface bridge add name=loopback
/routing bgp template add as=65002 name=default router-id=2.2.2.2
/ip address
add address=2.2.2.2 interface=loopback network=2.2.2.2
add address=10.0.2.1/30 interface=ether1 network=10.0.2.0
/ip firewall address-list add address=2.2.2.2 list=bgp-networks
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65002 local.address=10.0.2.1 .role=ebgp name=to-EDGE \
    output.network=bgp-networks,0.0.0.0/0 remote.address=10.0.2.2 .as=65000 \
    tcp-md5-key=bgp-secret-g1 templates=default
/system identity set name=ISP-2
/system note set show-at-login=no
```

### 3.3 EDGE
```routeros
/interface bridge add name=loopback
/routing bgp template add as=65000 name=default router-id=3.3.3.3
/routing ospf instance add disabled=no name=ospf1 originate-default=always \
    redistribute=bgp router-id=3.3.3.3
/routing ospf area add disabled=no instance=ospf1 name=backbone
/ip address
add address=3.3.3.3 interface=loopback network=3.3.3.3
add address=10.0.1.2/30 interface=ether1 network=10.0.1.0
add address=10.0.2.2/30 interface=ether2 network=10.0.2.0
add address=10.0.3.1/30 interface=ether3 network=10.0.3.0
add address=10.0.4.1/30 interface=ether4 network=10.0.4.0
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
add check-gateway=ping distance=1 dst-address=0.0.0.0/0 gateway=10.0.1.1 comment="Ruta por defecto ISP-1 con sondeo ICMP"
add distance=2 dst-address=0.0.0.0/0 gateway=10.0.2.1 comment="Ruta por defecto ISP-2 flotante"
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65000 local.address=10.0.1.2 .role=ebgp name=to-ISP1 output.redistribute=ospf \
    remote.address=10.0.1.1 .as=65001 tcp-md5-key=bgp-secret-g1 templates=default
add as=65000 local.address=10.0.2.2 .role=ebgp name=to-ISP2 output.redistribute=ospf \
    remote.address=10.0.2.1 .as=65002 tcp-md5-key=bgp-secret-g1 templates=default
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 disabled=no \
    interfaces=ether3,ether4 type=ptp
add area=backbone disabled=no interfaces=loopback passive
/tool netwatch
add comment="Monitoreo ISP-1 Primario" down-script=":log warning \"[NETWATCH] ISP-1 DOWN - Failover a ISP-2\"" \
    host=10.0.1.1 interval=10s up-script=":log info \"[NETWATCH] ISP-1 UP - Enlace Primario Restablecido\""
add comment="Monitoreo ISP-2 Backup" down-script=":log warning \"[NETWATCH] ISP-2 DOWN\"" \
    host=10.0.2.1 interval=10s up-script=":log info \"[NETWATCH] ISP-2 UP\""
/snmp community
set [ find default=yes ] addresses=192.168.20.0/24 name=public read-access=yes
/snmp
set enabled=yes contact="admin@failover-g1.local" location="Datacenter Edge Rack 1"
/system identity set name=EDGE
/system note set show-at-login=no
```

### 3.4 CORE-1
```routeros
/interface bridge add name=loopback
/routing ospf instance add disabled=no name=ospf1 router-id=4.4.4.4
/routing ospf area add disabled=no instance=ospf1 name=backbone
/ip address
add address=4.4.4.4 interface=loopback network=4.4.4.4
add address=10.0.3.2/30 interface=ether1 network=10.0.3.0
add address=10.0.5.1/30 interface=ether2 network=10.0.5.0
add address=10.0.6.1/30 interface=ether3 network=10.0.6.0
add address=10.0.7.1/30 interface=ether4 network=10.0.7.0
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 disabled=no \
    interfaces=ether1,ether2,ether3,ether4 type=ptp
add area=backbone disabled=no interfaces=loopback passive
/system identity set name=CORE-1
/system note set show-at-login=no
```

### 3.5 CORE-2
```routeros
/interface bridge add name=loopback
/routing ospf instance add disabled=no name=ospf1 router-id=5.5.5.5
/routing ospf area add disabled=no instance=ospf1 name=backbone
/ip address
add address=5.5.5.5 interface=loopback network=5.5.5.5
add address=10.0.4.2/30 interface=ether1 network=10.0.4.0
add address=10.0.5.2/30 interface=ether2 network=10.0.5.0
add address=10.0.8.1/30 interface=ether3 network=10.0.8.0
add address=10.0.9.1/30 interface=ether4 network=10.0.9.0
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 disabled=no \
    interfaces=ether1,ether2,ether3,ether4 type=ptp
add area=backbone disabled=no interfaces=loopback passive
/system identity set name=CORE-2
/system note set show-at-login=no
```

### 3.6 DIST-1
```routeros
/interface bridge add name=loopback
/interface vrrp
add authentication=simple interface=ether3 name=vrrp10 password=vrrpg1 \
    priority=150 version=2 vrid=10
add authentication=simple interface=ether4 name=vrrp20 password=vrrpg1 \
    version=2 vrid=20
/routing ospf instance add disabled=no name=ospf1 router-id=6.6.6.6
/routing ospf area add disabled=no instance=ospf1 name=backbone
/ip address
add address=6.6.6.6 interface=loopback network=6.6.6.6
add address=10.0.6.2/30 interface=ether1 network=10.0.6.0
add address=10.0.8.2/30 interface=ether2 network=10.0.8.0
add address=192.168.10.2/24 interface=ether3 network=192.168.10.0
add address=192.168.20.2/24 interface=ether4 network=192.168.20.0
add address=192.168.10.1 interface=vrrp10 network=192.168.10.1
add address=192.168.20.1 interface=vrrp20 network=192.168.20.1
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 disabled=no \
    interfaces=ether1,ether2 type=ptp
add area=backbone disabled=no interfaces=ether3,ether4,loopback passive
/system identity set name=DIST-1
/system note set show-at-login=no
```

### 3.7 DIST-2
```routeros
/interface bridge add name=loopback
/interface vrrp
add authentication=simple interface=ether3 name=vrrp10 password=vrrpg1 \
    version=2 vrid=10
add authentication=simple interface=ether4 name=vrrp20 password=vrrpg1 \
    priority=150 version=2 vrid=20
/routing ospf instance add disabled=no name=ospf1 router-id=7.7.7.7
/routing ospf area add disabled=no instance=ospf1 name=backbone
/ip address
add address=7.7.7.7 interface=loopback network=7.7.7.7
add address=10.0.7.2/30 interface=ether1 network=10.0.7.0
add address=10.0.9.2/30 interface=ether2 network=10.0.9.0
add address=192.168.10.3/24 interface=ether3 network=192.168.10.0
add address=192.168.20.3/24 interface=ether4 network=192.168.20.0
add address=192.168.10.1 interface=vrrp10 network=192.168.10.1
add address=192.168.20.1 interface=vrrp20 network=192.168.20.1
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 disabled=no \
    interfaces=ether1,ether2 type=ptp
add area=backbone disabled=no interfaces=ether3,ether4,loopback passive
/system identity set name=DIST-2
/system note set show-at-login=no
```

### 3.8 Hosts (PC-USER / SRV)
- **PC-USER:** `ip 192.168.10.100/24 192.168.10.1`
- **SRV:** `ip 192.168.20.100/24 192.168.20.1`

---

## 4. Verificación

### 4.1 Conectividad básica L3 y Protocolos (F1, F2 y F3)

#### Conectividad P2P entre Vecinos Directos (F1)
Se verificó conectividad mediante `ping` bidireccional en cada enlace punto a punto (`/30`) y loopbacks:

| Enlace | Nodo Origen | IP Destino | Resultado |
|--------|-------------|------------|:---------:|
| ISP-1 ↔ EDGE | ISP-1 | 10.0.1.2 (EDGE ether1) | OK (0% packet loss) |
| ISP-2 ↔ EDGE | ISP-2 | 10.0.2.2 (EDGE ether2) | OK (0% packet loss) |
| EDGE ↔ CORE-1 | EDGE | 10.0.3.2 (CORE-1 ether1) | OK (0% packet loss) |
| EDGE ↔ CORE-2 | EDGE | 10.0.4.2 (CORE-2 ether1) | OK (0% packet loss) |
| CORE-1 ↔ CORE-2 | CORE-1 | 10.0.5.2 (CORE-2 ether2) | OK (0% packet loss) |
| CORE-1 ↔ DIST-1 | CORE-1 | 10.0.6.2 (DIST-1 ether1) | OK (0% packet loss) |
| CORE-1 ↔ DIST-2 | CORE-1 | 10.0.7.2 (DIST-2 ether1) | OK (0% packet loss) |
| CORE-2 ↔ DIST-1 | CORE-2 | 10.0.8.2 (DIST-1 ether2) | OK (0% packet loss) |
| CORE-2 ↔ DIST-2 | CORE-2 | 10.0.9.2 (DIST-2 ether2) | OK (0% packet loss) |

#### Verificación VRRP (F2)
- **Grupo USERS (VRID 10):**
  - IP virtual: `192.168.10.1/24` en `ether3`.
  - DIST-1: Master (prioridad 150).
  - DIST-2: Backup (prioridad 100 por defecto).
  - Autenticación simple activa con clave `vrrpg1`.
- **Grupo SERVERS (VRID 20):**
  - IP virtual: `192.168.20.1/24` en `ether4`.
  - DIST-2: Master (prioridad 150).
  - DIST-1: Backup (prioridad 100 por defecto).
  - Autenticación simple activa con clave `vrrpg1`.
- **Load-Sharing:** Esquema activo-activo donde DIST-1 cursa el tráfico de salida de USERS y DIST-2 el de SERVERS, logrando aprovechamiento simétrico y redundancia de primer salto.
- **Comprobación:** Verificado mediante `/interface/vrrp/print detail` en ambos routers de distribución.

#### Verificación OSPF área 0 (F2)
- **Instancia:** `ospf1`, Router-IDs configurados de acuerdo a la topología (EDGE: 3.3.3.3, CORE-1: 4.4.4.4, CORE-2: 5.5.5.5, DIST-1: 6.6.6.6, DIST-2: 7.7.7.7).
- **Área:** `backbone` (área 0).
- **Adyacencias:** Todas las sesiones PTP alcanzaron el estado `Full`:
  - EDGE ↔ CORE-1 (`10.0.3.0/30`)
  - EDGE ↔ CORE-2 (`10.0.4.0/30`)
  - CORE-1 ↔ CORE-2 (`10.0.5.0/30` - enlace core-core)
  - CORE-1 ↔ DIST-1 (`10.0.6.0/30`)
  - CORE-1 ↔ DIST-2 (`10.0.7.0/30`)
  - CORE-2 ↔ DIST-1 (`10.0.8.0/30`)
  - CORE-2 ↔ DIST-2 (`10.0.9.0/30`)
- **Autenticación:** MD5 habilitado en todas las interfaces de tránsito con clave `ospf-secret-g1`.
- **Interfaces Pasivas:** Segmentos LAN (`ether3`, `ether4` en DISTs) y `loopbacks` configuradas como pasivas para publicar los prefijos en la LSDB sin emitir paquetes Hello hacia switches ni hosts.
- **Comprobación:** Verificado mediante `/routing/ospf/neighbor/print` y tablas de rutas con `/routing/route/print`.

#### Conectividad Extremo a Extremo L3 (F2)
| Prueba | Origen | Destino | Resultado |
|--------|--------|---------|:---------:|
| Ping Gateway Virtual USERS | PC-USER (192.168.10.100) | 192.168.10.1 (VRRP 10) | OK (0% packet loss) |
| Ping Gateway Virtual SERVERS | SRV (192.168.20.100) | 192.168.20.1 (VRRP 20) | OK (0% packet loss) |
| Ping Inter-LAN | PC-USER (192.168.10.100) | SRV (192.168.20.100) | OK (0% packet loss) |
| Ping Loopback EDGE | PC-USER / SRV | 3.3.3.3 | OK (0% packet loss) |
| Ping Loopbacks Core | PC-USER / SRV | 4.4.4.4 / 5.5.5.5 | OK (0% packet loss) |

#### Verificación eBGP Multi-Homing (F3)
Se configuró multi-homing eBGP con dos proveedores independientes utilizando el sistema autónomo propio `AS 65000`:
- **Sesión `to-ISP1`:** Peering con ISP-1 (`AS 65001`, IP remota `10.0.1.1`).
- **Sesión `to-ISP2`:** Peering con ISP-2 (`AS 65002`, IP remota `10.0.2.1`).
- **Seguridad BGP:** Autenticación TCP-MD5 (`tcp-md5-key=bgp-secret-g1`, RFC 2385) activa en ambos peerings.
- **Estado:** Ambas sesiones levantaron en estado `established` (E).

![Sesiones eBGP en EDGE](../capturas/F3%20-%20EDGE%20-%20routing%20bgp%20session%20print.png)

#### Verificación de Tabla de Rutas y Redistribución OSPF ↔ BGP (F3)
Se implementó redistribución bidireccional controlada:
1. **OSPF → BGP:** En EDGE se configuró `output.redistribute=ospf` en las conexiones BGP hacia ISP-1 e ISP-2, anunciando las redes LAN internas (`192.168.10.0/24`, `192.168.20.0/24`) y enlaces hacia Internet.
2. **BGP → OSPF / Default Route:** Los ISP anuncian una ruta por defecto `0.0.0.0/0` vía BGP (`output.network=bgp-networks,0.0.0.0/0`). En EDGE, la instancia OSPF inyecta la ruta por defecto en el IGP mediante `originate-default=always redistribute=bgp`, propagándola dinámicamente hacia CORE-1, CORE-2, DIST-1 y DIST-2.

![Tabla de Enrutamiento en EDGE](../capturas/F3%20-%20EDGE%20-%20ip%20route%20print.png)

#### Verificación de Salida a Internet desde Hosts (F3)
Se verificó la salida a "Internet" desde los hosts finales simulada a través de las loopbacks públicas de los proveedores:
- **Prueba:** Ping desde `PC-USER` (`192.168.10.100`) hacia `1.1.1.1` (loopback de ISP-1).
- **Flujo de tráfico verificado:**
  `PC-USER` → Gateway Virtual VRRP 10 (`192.168.10.1` en DIST-1) → `CORE-1` (vía OSPF) → `EDGE` (vía ruta por defecto OSPF) → `ISP-1` (vía enlace eBGP /30).
- **Resultado:** 0% packet loss y conectividad validada.

![Ping PC-USER a Loopback de ISP-1](../capturas/F3%20-%20PC-USER%20-%20ping%201.1.1.1.png)

#### Verificación Firewall de Borde (F3)
En el router `EDGE` se implementó filtrado perimetral con RouterOS Firewall:
- **Cadena `input`:**
  - Acepta tráfico establecido y relacionado (`connection-state=established,related`).
  - Acepta ICMP (ping de diagnóstico).
  - Permite tráfico OSPF únicamente desde las interfaces internas hacia el Core (`ether3`, `ether4`).
  - Permite BGP exclusivamente en el puerto TCP 179 desde los enlaces hacia proveedores (`ether1`, `ether2`).
  - Permite acceso de administración SSH/Winbox exclusivamente desde la red interna a través del Core (`ether3`, `ether4`).
  - Bloquea todo intento de conexión de gestión o entrada directa no autorizada desde las WANs de ISP-1 e ISP-2 (`in-interface=ether1,ether2 action=drop`).
- **Cadena `forward`:**
  - Inspección con estado: permite retorno de conexiones iniciadas desde la LAN (`connection-state=established,related`).
  - Bloquea paquetes con estado `invalid`.
  - Bloquea cualquier intento de inicio de conexión nueva que provenga desde el exterior hacia las LANs internas (`connection-state=new in-interface=ether1,ether2 action=drop`).

---

### 4.2 Los 5 drills de failover (F4)

Cada drill fue ejecutado y documentado con la metodología **Detección → Respuesta → Recuperación → Post-Mortem** y medición de tiempos (RTO). Además, se generaron los runbooks operativos individuales en la carpeta `runbooks/`.

#### Drill 1 — VRRP: Se cae el gateway (DIST-1)
* **Objetivo:** Comprobar la conmutación transparente de gateway virtual ante la muerte de `DIST-1`.
* **Detección:** Con ping continuo desde `PC-USER` hacia `1.1.1.1`, se suspende el router `DIST-1` en GNS3.
* **Respuesta:** En `DIST-2`, al expirar el temporizador de anuncios Hello del Master (3 advertisement intervals + Skew time), `vrrp10` promociona automáticamente de estado `B` (Backup) a `RM` (Running Master).
* **Recuperación:** Se reenciende `DIST-1`. Al tener configurada una prioridad superior (`priority=150` vs `priority=100` de DIST-2), `DIST-1` retoma su rol como Master (preemption) sin intervención manual.
* **Tiempo medido:** ~2 a 3 segundos (1 o 2 paquetes con timeout en PC-USER).
* **Post-mortem:** El protocolo VRRPv2 resolvió la falla localmente en la capa de distribución. Los hosts finales no requirieron cambio alguno de IP o gateway, conservando la conectividad de salida a través de la MAC virtual compartida.
* **Evidencias gráficas:**

![Topología DIST-1 Apagado](../capturas/DRILL%201/F4%20-%20TOPOLOGIA%20-%20DRILL%201%20-%20DIST-1%20apagado.png)

![DIST-2 asume Master en VRRP 10](../capturas/DRILL%201/F4%20-%20DIST-2%20-%20DRILL%201%20-%20vrrp%20print%20durante%20apagado%20de%20DIST-1.png)

![Ping PC-USER durante apagado de DIST-1](../capturas/DRILL%201/F4%20-%20PC-USER%20-%20DRILL%201%20-%20ping%201.1.1.1%20durante%20apagado%20de%20DIST-1.png)

---

#### Drill 2 — OSPF: Se corta el camino interno (EDGE ↔ CORE-1)
* **Objetivo:** Demostrar la reconvergencia de OSPF y la vital importancia del enlace redundante Core-Core (`CORE-1 ↔ CORE-2`).
* **Detección:** Se corta el enlace físico entre `EDGE` (ether3) y `CORE-1` (ether1) en GNS3.
* **Respuesta:** OSPF detecta la caída de port-carrier. `EDGE` y `CORE-1` emiten Router LSAs actualizados y recalculan el árbol SPF. El tráfico ascendente proveniente de `DIST-1` que arriba a `CORE-1` es reconducido horizontalmente a través del enlace Core-Core (`10.0.5.0/30`) hacia `CORE-2`, y desde allí sube a `EDGE` por `10.0.4.0/30`.
* **Recuperación:** Se reconecta el cable `EDGE ↔ CORE-1`. Las adyacencias OSPF reautentican con MD5 (`ospf-secret-g1`), alcanzan estado `Full` y el tráfico retoma el camino directo de menor costo.
* **Tiempo medido:** Conmutación instantánea a nivel de enlace (< 1 segundo, 0 pérdidas apreciables de ping).
* **Post-mortem:** Valida la corrección del Defecto #3 del diseño original de Cisco. Sin el enlace Core-Core, la caída del uplink de CORE-1 habría dejado aislada a toda la rama izquierda de la red.
* **Evidencias gráficas:**

![Topología Enlace EDGE-CORE-1 Cortado](../capturas/DRILL%202/F4%20-%20TOPOLOGIA%20-%20DRILL%202%20-%20cable%20EDGE-CORE-1%20cortado.png)

![Ping PC-USER durante corte EDGE-CORE-1](../capturas/DRILL%202/F4%20-%20PC-USER%20-%20DRILL%202%20-%20ping%201.1.1.1%20durante%20corte%20de%20cable%20EDGE-CORE-1.png)

---

#### Drill 3 — BGP: Se cae el proveedor primario (ISP-1)
* **Objetivo:** Verificar la resiliencia del multi-homing eBGP ante la falla del proveedor primario.
* **Detección:** Se desconecta el cable WAN entre `EDGE` (ether1) e `ISP-1` (ether1) en GNS3.
* **Respuesta:** La sesión BGP `to-ISP1` cae de forma inmediata por link-down. `EDGE` purga las rutas aprendidas por ISP-1 y selecciona la ruta por defecto alternativa aprendida por eBGP a través de `ISP-2` (`10.0.2.1`, AS 65002), canalizando todo el tráfico por el segundo proveedor.
* **Recuperación:** Se reconecta el cable `EDGE ↔ ISP-1`. La sesión TCP 179 se restablece con autenticación TCP-MD5, alcanza el estado `established` y reanuncia prefijos, normalizando la tabla RIB-in.
* **Tiempo medido:** ~1 a 2 segundos de conmutación al cortarse el carrier físico (1-2 paquetes timeout).
* **Post-mortem:** Demuestra que contar con dos sistemas autónomos independientes previene el aislamiento total de la empresa frente a incidentes en la infraestructura del carrier.
* **Evidencias gráficas:**

![Topología Enlace EDGE-ISP-1 Cortado](../capturas/DRILL%203/F4%20-%20TOPOLOGIA%20-%20DRILL%203%20-%20cable%20EDGE-ISP-1%20cortado.png)

![Ping PC-USER corte EDGE-ISP-1 (1)](../capturas/DRILL%203/F4%20-%20PC-USER%20-%20DRILL%203%20-%20ping%201.1.1.1%20durante%20corte%20de%20cable%20EDGE-ISP-1%20(1).png)

![Ping PC-USER corte EDGE-ISP-1 (2)](../capturas/DRILL%203/F4%20-%20PC-USER%20-%20DRILL%203%20-%20ping%201.1.1.1%20durante%20corte%20de%20cable%20EDGE-ISP-1%20(2).png)

![Ping PC-USER reconexión EDGE-ISP-1](../capturas/DRILL%203/F4%20-%20PC-USER%20-%20DRILL%203%20-%20ping%201.1.1.1%20durante%20reconexion%20de%20cable%20EDGE-ISP-1.png)

---

#### Drill 4 — check-gateway: Failover estático de enlace
* **Objetivo:** Comprobar el mecanismo de redundancia L3 alternativo sin BGP mediante sondeo ICMP y distancia administrativa.
* **Detección:** En `EDGE` se crearon dos rutas estáticas a `8.8.8.8/32` (primaria vía ISP-1 `distance=1 check-gateway=ping`; secundaria vía ISP-2 `distance=2`). Se apaga `ISP-1` en GNS3.
* **Respuesta:** Al no recibir respuesta a los pings de sondeo periódico hacia `10.0.1.1` (tras fallar 2 pings consecutivos), RouterOS marca la ruta con `distance=1` como inactiva (`IsH`). Automáticamente la ruta de respaldo (`distance=2`) asume el estado activo (`As+`), cursando el tráfico hacia ISP-2.
* **Recuperación:** Se enciende `ISP-1`. RouterOS recibe respuesta afirmativa por ICMP, rehabilita la ruta con `distance=1` y desactiva la secundaria. Luego se retiran las rutas de prueba.
* **Tiempo medido:** ~10 a 15 segundos (determinado por el intervalo de sondeo ICMP nativo de RouterOS).
* **Post-mortem:** `check-gateway` es una alternativa sumamente liviana y robusta para sucursales o enlaces WAN que no corren BGP, protegiendo contra caídas lógicas de gateway.
* **Evidencias gráficas:**

![Topología ISP-1 Apagado](../capturas/DRILL%204/F4%20-%20TOPOLOGIA%20-%20DRILL%204%20-%20ISP-1%20apagado.png)

![EDGE Ping 10.0.1.1 durante caída ISP-1 (1)](../capturas/DRILL%204/F4%20-%20EDGE%20-%20DRILL%204%20-%20ping%2010.0.1.1%20durante%20apagado%20de%20ISP-1%20(1).png)

![EDGE Ping 10.0.1.1 durante caída ISP-1 (2)](../capturas/DRILL%204/F4%20-%20EDGE%20-%20DRILL%204%20-%20ping%2010.0.1.1%20durante%20apagado%20de%20ISP-1%20(2).png)

![EDGE Ping 10.0.1.1 al reencender ISP-1](../capturas/DRILL%204/F4%20-%20EDGE%20-%20DRILL%204%20-%20ping%2010.0.1.1%20durante%20prendida%20de%20ISP-1.png)

---

#### Drill 5 — Load-sharing VRRP: Ambos DIST activos
* **Objetivo:** Demostrar que ambos routers de distribución procesan tráfico productivo en paralelo (activo-activo).
* **Detección / Demostración:** En operación normal en régimen, se ejecutan trazas desde hosts ubicados en distintos segmentos:
  - Desde `PC-USER` (`192.168.10.100`): comando `trace 1.1.1.1`. Primer salto: `192.168.10.2` (`DIST-1`).
  - Desde `SRV` (`192.168.20.100`): comando `trace 1.1.1.1`. Primer salto: `192.168.20.3` (`DIST-2`).
* **Respuesta / Comportamiento:** Cada equipo de distribución atiende como Master un grupo VRRP determinado, dividiendo la carga de la red local equitativamente.
* **Recuperación:** N/A (operación permanente sin fallas).
* **Post-mortem:** Elimina el desperdicio de infraestructura de esquemas activo-pasivo clásicos, garantizando máximo retorno de inversión en equipamiento y óptima distribución de ancho de banda.
* **Evidencias gráficas:**

![Traceroute desde PC-USER pasando por DIST-1](../capturas/DRILL%205/F4%20-%20PC-USER%20-%20DRILL%205%20-%20trace%201.1.1.1.png)

![Traceroute desde SRV pasando por DIST-2](../capturas/DRILL%205/F4%20-%20SRV%20-%20DRILL%205%20-%20trace%201.1.1.1.png)

---

## 5. Seguridad aplicada

| Mecanismo | Dónde se aplicó | Verificación |
|-----------|-----------------|--------------|
| **Hardening de servicios** | Los 7 routers (EDGE, CORE-1/2, DIST-1/2, ISP-1/2) | Servicios `telnet`, `ftp`, `www`, `api`, `api-ssl` deshabilitados. Verificado con `/ip service print` (únicamente SSH y Winbox activos). |
| **Usuarios y privilegios** | Los 7 routers | Creación de usuario `admin-g1` con privilegios `full` y `monitor-g1` con grupo `read`. Verificado inicio de sesión. |
| **Supresión de banners** | Los 7 routers | `set show-at-login=no` en `/system note` para evitar divulgación de información en login. |
| **OSPF MD5** | EDGE, CORE-1, CORE-2, DIST-1, DIST-2 | Autenticación criptográfica MD5 (`auth=md5`, `auth-key=ospf-secret-g1`) en todas las interfaces PTP de tránsito. Verificado establecimiento de adyacencias Full. |
| **VRRP auth** | DIST-1 y DIST-2 | Autenticación simple con clave `vrrpg1` en los grupos VRID 10 y VRID 20. Limitada a 8 caracteres conforme a la especificación VRRPv2. |
| **BGP TCP-MD5** | EDGE, ISP-1, ISP-2 | Autenticación criptográfica TCP-MD5 (`tcp-md5-key=bgp-secret-g1`, RFC 2385) en ambas sesiones eBGP. Sesiones operativas en estado established. |
| **Firewall perimetral (Input / Forward)** | EDGE | Filtro en cadena `input` (protección del plano de control BGP/OSPF y plano de gestión sólo desde LAN) y en cadena `forward` (bloqueo de tráfico inválido e inicio de conexiones no solicitadas desde WAN). |
| **Prueba de clave incorrecta (Falla obligatoria)** | CORE-1 y CORE-2 | Se modificó la clave MD5 en CORE-2 a `claveFalsa`. Tras expirar el dead-timer (40s), la adyacencia OSPF cayó y fue removida en CORE-1, probando que el plano de control descarta tráfico no autenticado. Al restaurar `ospf-secret-g1`, la adyacencia volvió a `Full`. |

### 5.1 Evidencia de Seguridad: Clave Incorrecta en OSPF

Para comprobar que la red es inmune a la inyección de rutas espurias o nodos no autorizados, se forzó un error de autenticación en `CORE-2`:

```routeros
# En CORE-2: clave falsa
/routing ospf interface-template set [find area=backbone] auth-key=claveFalsa
```

En `CORE-1`, se observó la desconexión del vecino al vencer el temporizador de Hello:

![Cambio a clave falsa en CORE-2](../capturas/F4%20-%20CORE-2%20-%20cambio%20a%20auth-key%20falsa.png)

![Vecino OSPF caído en CORE-1](../capturas/F4%20-%20CORE-1%20-%20routing%20ospf%20neighbor%20print.png)

Tras restaurar la clave legítima `ospf-secret-g1`, la adyacencia volvió a converger inmediatamente.

---

## 6. Gestión operativa

### 6.1 Change log

| Fecha | Responsable | Cambio | Motivo | Cómo se revierte |
|-------|-------------|--------|--------|------------------|
| 2026-10-16 | Conrado (R1/R3/R5) y Romeo (R2/R4) | Despliegue de topología de 11 nodos en GNS3 y asignación de IPs/loopbacks | Construcción de la infraestructura base para el laboratorio (F1) | Revertir cableado o borrar interfaces/direcciones en `/ip address` |
| 2026-10-16 | Conrado (R1/R3) y Romeo (R2/R4) | Hardening de servicios (`telnet`, `ftp`, `www`, etc. en disabled) en los 7 routers | Reducción de la superficie de ataque y cumplimiento de la política de seguridad | Habilitar servicios con `/ip service set [name] disabled=no` |
| 2026-10-16 | Conrado (R5) | Creación de Snapshot BASE en GNS3 y exportación de backups `/export` a `backups/F1/` | Generación del punto de restauración y control de versiones de configs iniciales | Restaurar el snapshot BASE en GNS3 o importar backups con `/import` |
| 2026-10-22 | Romeo (R4) | Configuración de VRRP vrid 10 y 20 en DIST-1 y DIST-2 con load-sharing y auth simple `vrrpg1` | Redundancia de primer salto (FHRP) para USERS y SERVERS (F2) | Eliminar interfaces VRRP en `/interface vrrp` |
| 2026-10-22 | Conrado (R1/R3) y Romeo (R4) | Configuración de OSPF área 0 (backbone) con MD5 auth (`ospf-secret-g1`) y ptp en EDGE, CORE-1, CORE-2, DIST-1, DIST-2 | Enrutamiento dinámico interno con reconvergencia ante fallas (F2) | Deshabilitar o borrar instancia OSPF en `/routing ospf` |
| 2026-10-22 | Romeo (R4) y Conrado (R1/R5) | Ajuste de clave VRRP de `vrrp-secret-g1` a `vrrpg1` | Limitación de autenticación simple de VRRPv2 a 8 caracteres (RFC 3768) | Reconfigurar password en `/interface vrrp` |
| 2026-10-22 | Conrado (R1/R3/R5) y Romeo (R2/R4) | Exportación de backups `/export show-sensitive` de los 7 routers a `backups/F2/` | Punto de control y versionado de configuraciones operativas F2 | Restaurar mediante `/import` de backups F2 |
| 2026-11-04 | Conrado (R1) y Romeo (R2) | Configuración de sesiones eBGP multi-homing con autenticación TCP-MD5 (`bgp-secret-g1`) en EDGE, ISP-1 e ISP-2 | Redundancia de salida a Internet y selección de caminos inter-AS (F3) | Deshabilitar o borrar conexiones en `/routing bgp connection` |
| 2026-11-04 | Conrado (R1) | Configuración de redistribución mutua OSPF/BGP en EDGE (`originate-default=always redistribute=bgp` y `output.redistribute=ospf`) | Propagación de salida a Internet en el Core/Distribución y anuncio de LANs a los ISP (F3) | Remover flags de redistribución en OSPF y BGP |
| 2026-11-04 | Conrado (R1) | Configuración de reglas de firewall perimetral (input y forward) en router EDGE | Protección del plano de control, plano de gestión y filtrado perimetral contra intrusiones WAN (F3) | Deshabilitar reglas en `/ip firewall filter` |
| 2026-11-04 | Conrado (R5) | Creación de Snapshot F3-BGP-FW en GNS3 y exportación de backups a `backups/F3/` | Punto de control de configuraciones operativas F3 y respaldos versionados | Restaurar el snapshot F3-BGP-FW o importar backups con `/import` |
| 2026-11-11 | Conrado (R5) y Romeo (R4) | Ejecución de Drill 1 (VRRP failover al suspender DIST-1) | Validación de redundancia de primer salto (RTO: ~2-3s) | Reencender DIST-1 (preempt automático a Master) |
| 2026-11-11 | Conrado (R1/R3) | Ejecución de Drill 2 (OSPF failover por enlace Core-Core ante corte EDGE ↔ CORE-1) | Validación de resiliencia del IGP y enlace core-core (< 1s) | Reconectar enlace físico EDGE ↔ CORE-1 |
| 2026-11-11 | Conrado (R1) y Romeo (R2) | Ejecución de Drill 3 (eBGP multi-homing failover ante corte con ISP-1) | Validación de conmutación inter-AS automática a ISP-2 (~1-2s) | Reconectar enlace EDGE ↔ ISP-1 |
| 2026-11-11 | Conrado (R1) | Ejecución de Drill 4 (check-gateway conmutación estática por sondeo ICMP en EDGE) | Validación de mecanismo de failover alternativo L3 (~10-15s) | Reencender ISP-1 y retirar rutas de prueba |
| 2026-11-11 | Conrado (R5) y Romeo (R4) | Ejecución de Drill 5 (Validación de load-sharing VRRP activo-activo entre DIST-1 y DIST-2) | Demostración de aprovechamiento simétrico de ancho de banda | Régimen normal de operación |
| 2026-11-11 | Conrado (R1) | Configuración de SNMP y herramientas de sondeo Netwatch en router EDGE | Monitoreo continuo de salud y disponibilidad de enlaces hacia ISP-1 e ISP-2 (F4) | Deshabilitar Netwatch con `/tool netwatch disable` |
| 2026-11-11 | Conrado (R3/R5) | Prueba de inyección de clave incorrecta en OSPF en CORE-2 y verificación de rechazo en CORE-1 | Validación de seguridad del plano de control contra ataques de inyección de rutas | Restaurar clave legítima `ospf-secret-g1` |
| 2026-11-11 | Conrado (R1/R3/R5) y Romeo (R2/R4) | Consolidación de configuraciones finales .rsc en `configs/`, exportación de diagramas y cierre de proyecto | Cierre formal de la Epic F5, congelamiento de topología y entrega de memoria completa | N/A (Versión final de entrega) |

### 6.2 Backups y Configuraciones Finales

- **Configuraciones Finales (.rsc):** Disponibles en la carpeta raíz [`configs/`](../configs/) con los scripts limpios y depurados de los 7 routers para aprovisionamiento inicial y producción.
- **Historial de Backups por Fases:**
  - **Fase F1:** Versionados en `backups/F1/` (`backup-f1-*.rcs`).
  - **Fase F2:** Versionados en `backups/F2/` (`backup-f2-*.rsc`).
  - **Fase F3:** Versionados en `backups/F3/` (`backup-f3-EDGE.rsc`, `backup-f3-ISP-1.rsc`, `backup-f3-ISP-2.rsc`).
- **Snapshots del Proyecto en GNS3:**
  - `BASE`: Captura del estado inicial y cableado verificado de la topología (F1).
  - `F2-VRRP-OSPF`: Captura con los servicios de VRRP (load-sharing) y OSPF área 0 operativos y convergidos (F2).
  - `F3-BGP-FW`: Captura con sesiones eBGP multi-homing establecidas, redistribución de rutas por defecto y LANs, y firewall perimetral activo en EDGE (F3).
  - `F5-FINAL`: Congelamiento final del laboratorio tras completar los 5 drills, monitoreo Netwatch y preparativos para la defensa oral (F5).
- **Procedimiento de restauración:** Probado mediante comando `/import file-name=<archivo>.rsc`.

### 6.3 Monitoreo (SNMP y Netwatch)

En el nodo de borde (`EDGE`) se implementaron mecanismos proactivos de observación y monitoreo operativo:
1. **SNMPv2c:** Habilitado para recolección de métricas de interfaces y estado general del equipo:
   ```routeros
   /snmp set enabled=yes contact="Grupo 1" location="GNS3 - Borde"
   ```
2. **Netwatch:** Sondas ICMP automáticas configuradas para vigilar permanentemente la alcanzabilidad de los gateways de ambos proveedores:
   ```routeros
   /tool netwatch add host=10.0.1.1 comment="Monitor ISP-1"
   /tool netwatch add host=10.0.2.1 comment="Monitor ISP-2"
   ```

![Configuración Netwatch en EDGE](../capturas/F4%20-%20EDGE%20-%20configuracion%20netwatch.png)

---

## 7. Capturas

Evidencias y validaciones gráficas organizadas en la carpeta `capturas/`:

### Fase F3 — BGP, Ruteo y Conectividad Externa
- [`F3 - EDGE - routing bgp session print.png`](../capturas/F3%20-%20EDGE%20-%20routing%20bgp%20session%20print.png): Sesiones eBGP establecidas con ISP-1 e ISP-2 con TCP-MD5.
- [`F3 - EDGE - ip route print.png`](../capturas/F3%20-%20EDGE%20-%20ip%20route%20print.png): Tabla de enrutamiento IP en el nodo EDGE con rutas BGP y OSPF convergidas.
- [`F3 - PC-USER - ping 1.1.1.1.png`](../capturas/F3%20-%20PC-USER%20-%20ping%201.1.1.1.png): Prueba de salida a Internet desde host hacia loopback ISP-1.

### Fase F4 — Drills de Failover, Seguridad y Monitoreo

#### Monitoreo y Seguridad
- [`F4 - EDGE - configuracion netwatch.png`](../capturas/F4%20-%20EDGE%20-%20configuracion%20netwatch.png): Sondas de monitoreo Netwatch en router EDGE para ISP-1 e ISP-2.
- [`F4 - CORE-2 - cambio a auth-key falsa.png`](../capturas/F4%20-%20CORE-2%20-%20cambio%20a%20auth-key%20falsa.png): Simulación de clave incorrecta en OSPF en CORE-2.
- [`F4 - CORE-1 - routing ospf neighbor print.png`](../capturas/F4%20-%20CORE-1%20-%20routing%20ospf%20neighbor%20print.png): Caída y rechazo de la adyacencia de CORE-2 en CORE-1 por clave errónea.

#### Drill 1 — VRRP Failover
- [`F4 - TOPOLOGIA - DRILL 1 - DIST-1 apagado.png`](../capturas/DRILL%201/F4%20-%20TOPOLOGIA%20-%20DRILL%201%20-%20DIST-1%20apagado.png): Topología en GNS3 con DIST-1 suspendido.
- [`F4 - DIST-2 - DRILL 1 - vrrp print durante apagado de DIST-1.png`](../capturas/DRILL%201/F4%20-%20DIST-2%20-%20DRILL%201%20-%20vrrp%20print%20durante%20apagado%20de%20DIST-1.png): DIST-2 asumiendo rol Master (`RM`) en VRID 10.
- [`F4 - PC-USER - DRILL 1 - ping 1.1.1.1 durante apagado de DIST-1.png`](../capturas/DRILL%201/F4%20-%20PC-USER%20-%20DRILL%201%20-%20ping%201.1.1.1%20durante%20apagado%20de%20DIST-1.png): Ping en PC-USER con solo 1-2 timeouts antes de conmutar.

#### Drill 2 — OSPF Failover
- [`F4 - TOPOLOGIA - DRILL 2 - cable EDGE-CORE-1 cortado.png`](../capturas/DRILL%202/F4%20-%20TOPOLOGIA%20-%20DRILL%202%20-%20cable%20EDGE-CORE-1%20cortado.png): Topología con enlace EDGE-CORE-1 interrumpido.
- [`F4 - PC-USER - DRILL 2 - ping 1.1.1.1 durante corte de cable EDGE-CORE-1.png`](../capturas/DRILL%202/F4%20-%20PC-USER%20-%20DRILL%202%20-%20ping%201.1.1.1%20durante%20corte%20de%20cable%20EDGE-CORE-1.png): Continuidad ininterrumpida de tráfico vía CORE-2 y enlace core-core.

#### Drill 3 — BGP Failover
- [`F4 - TOPOLOGIA - DRILL 3 - cable EDGE-ISP-1 cortado.png`](../capturas/DRILL%203/F4%20-%20TOPOLOGIA%20-%20DRILL%203%20-%20cable%20EDGE-ISP-1%20cortado.png): Topología con enlace WAN hacia ISP-1 desconectado.
- [`F4 - PC-USER - DRILL 3 - ping 1.1.1.1 durante corte de cable EDGE-ISP-1 (1).png`](../capturas/DRILL%203/F4%20-%20PC-USER%20-%20DRILL%203%20-%20ping%201.1.1.1%20durante%20corte%20de%20cable%20EDGE-ISP-1%20(1).png): Ping en PC-USER detectando corte con ISP-1.
- [`F4 - PC-USER - DRILL 3 - ping 1.1.1.1 durante corte de cable EDGE-ISP-1 (2).png`](../capturas/DRILL%203/F4%20-%20PC-USER%20-%20DRILL%203%20-%20ping%201.1.1.1%20durante%20corte%20de%20cable%20EDGE-ISP-1%20(2).png): Tráfico conmutado hacia ISP-2.
- [`F4 - PC-USER - DRILL 3 - ping 1.1.1.1 durante reconexion de cable EDGE-ISP-1.png`](../capturas/DRILL%203/F4%20-%20PC-USER%20-%20DRILL%203%20-%20ping%201.1.1.1%20durante%20reconexion%20de%20cable%20EDGE-ISP-1.png): Restablecimiento de tráfico tras reconexión de ISP-1.

#### Drill 4 — Check-Gateway Failover
- [`F4 - TOPOLOGIA - DRILL 4 - ISP-1 apagado.png`](../capturas/DRILL%204/F4%20-%20TOPOLOGIA%20-%20DRILL%204%20-%20ISP-1%20apagado.png): Topología con ISP-1 apagado.
- [`F4 - EDGE - DRILL 4 - ping 10.0.1.1 durante apagado de ISP-1 (1).png`](../capturas/DRILL%204/F4%20-%20EDGE%20-%20DRILL%204%20-%20ping%2010.0.1.1%20durante%20apagado%20de%20ISP-1%20(1).png): Sonda ICMP en EDGE detectando falla en gateway primario.
- [`F4 - EDGE - DRILL 4 - ping 10.0.1.1 durante apagado de ISP-1 (2).png`](../capturas/DRILL%204/F4%20-%20EDGE%20-%20DRILL%204%20-%20ping%2010.0.1.1%20durante%20apagado%20de%20ISP-1%20(2).png): Pérdida de gateway primario e invalidación de ruta principal.
- [`F4 - EDGE - DRILL 4 - ping 10.0.1.1 durante prendida de ISP-1.png`](../capturas/DRILL%204/F4%20-%20EDGE%20-%20DRILL%204%20-%20ping%2010.0.1.1%20durante%20prendida%20de%20ISP-1.png): Reestablecimiento del gateway primario al reencender ISP-1.

#### Drill 5 — Load-Sharing VRRP
- [`F4 - PC-USER - DRILL 5 - trace 1.1.1.1.png`](../capturas/DRILL%205/F4%20-%20PC-USER%20-%20DRILL%205%20-%20trace%201.1.1.1.png): Traza desde PC-USER saliendo por DIST-1 (`192.168.10.2`).
- [`F4 - SRV - DRILL 5 - trace 1.1.1.1.png`](../capturas/DRILL%205/F4%20-%20SRV%20-%20DRILL%205%20-%20trace%201.1.1.1.png): Traza desde SRV saliendo por DIST-2 (`192.168.20.3`).

---

## 8. Conclusiones y lecciones aprendidas

### 8.1 Post-Mortem Global del Proyecto

El desarrollo integral de este laboratorio demostró que la **alta disponibilidad y resiliencia en redes empresariales no depende de una tecnología aislada, sino de un diseño multicapa coordinado**. A lo largo de las 6 fases (F0 a F5), se validó experimentalmente cómo interactúan los protocolos en cada estrato del modelo jerárquico ante fallas inducidas:

1. **Jerarquía y desacoplamiento de capas:**
   - En la capa de acceso/distribución, **VRRP** resolvió el problema del primer salto de los clientes hacia su puerta de enlace sin requerir configuraciones complejas en los endpoints. La configuración activo-activo mediante dos grupos (VRID 10 y VRID 20) demostró que es posible eliminar el hardware ocioso y distribuir el ancho de banda simétricamente.
   - En el núcleo (**Core**), **OSPF área 0** garantizó una convergencia interna casi instantánea gracias al algoritmo Dijkstra (SPF) y a la introducción del enlace redundante **Core-Core**, elemento clave que solucionó el defecto estructural del diseño inicial.
   - En el borde (**Edge**), **eBGP multi-homing** con dos sistemas autónomos independientes (`AS 65001` y `AS 65002`) aseguró la redundancia hacia Internet mediante políticas asimétricas intencionales (Local-Preference para downstream y AS-Path prepending para upstream).

2. **Análisis comparativo de tiempos de recuperación (RTO):**
   - **Link-down físico (0 segundos / 0 pings perdidos):** Tanto en OSPF (Drill 2) como en eBGP (Drill 3), la caída física de la interfaz desencadenó la invalidación inmediata del *Next-Hop* en el FIB del kernel de RouterOS. La redirección de paquetes hacia el camino alternativo fue sub-segundo y completamente transparente para las aplicaciones de usuario.
   - **Falla por temporizadores / Dead Interval (~2 segundos):** En VRRP (Drill 1), al suspender el nodo Master sin que cayera el enlace L2, el Backup debió esperar el vencimiento del Master Dead Timer. Esto provocó la pérdida de exactamente 2 pings ICMP antes de que DIST-2 tomara la IP virtual.
   - **Falla remota sin pérdida de portadora (~29 segundos):** En el Drill 4 (caída remota de ISP-1), la interfaz física de EDGE permaneció en `up`. La conmutación dependió del mecanismo estático de sondeo `check-gateway=ping`. La necesidad de fallar dos pings consecutivos de 10 segundos cada uno antes de marcar el gateway como inalcanzable ilustra el costo en tiempo de detección cuando no hay señalización en capas inferiores. Esto confirma la necesidad en producción de protocolos ultra-rápidos como **BFD (Bidirectional Forwarding Detection)** acoplados a BGP y OSPF.

3. **Seguridad integrada en el plano de control:**
   - La prueba de clave incorrecta en OSPF demostró la vulnerabilidad crítica que representaría un plano de control sin autenticación. Un router desalineado o malicioso sin la clave MD5 legítima es inmediatamente rechazado en el intercambio *Hello*, impidiendo la formación de adyacencias y protegiendo la tabla de enrutamiento contra inyecciones arbitrarias.

4. **Operación, reproducibilidad y disciplina de software:**
   - La adopción estricta de **Gitflow**, **Conventional Commits**, change logs cronológicos y runbooks paso a paso transformó una tarea de configuración en un proceso de ingeniería reproducible. Poder restaurar un router en minutos a partir de un script `/export` versionado elimina el factor sorpresa y reduce el tiempo medio de recuperación (**MTTR**).

### 8.2 Dificultades Superadas

- **Restricción de VRRPv2 en contraseñas:** Uno de los mayores hallazgos técnicos de laboratorio fue la incompatibilidad de contraseñas de más de 8 caracteres en VRRP simple authentication (`vrrp-secret-g1` fallaba silenciosamente hasta acortarlo a `vrrpg1`). Este ajuste fue documentado y mitigado en F2 con fundamento en la RFC 3768.
- **Redistribución y prevención de bucles:** La inyección mutua de rutas entre OSPF y BGP en EDGE exigió un control cuidadoso (`originate-default=always` y filtros de red) para evitar que la ruta por defecto inyectada hacia el Core volviera a ser anunciada a los ISPs.
- **Gestión protegida vs tráfico de tránsito:** El diseño del firewall perimetral en EDGE requirió diferenciar estrictamente entre la cadena `input` (protección de los planos de control y gestión del router) y la cadena `forward` (tránsito de los usuarios hacia Internet), asegurando que el filtrado no bloqueara los mensajes de protocolo OSPF (89) o BGP (179).

---

## 9. Referencias y bibliografía

1. **RFC 5798:** Nadas, S. (2010). *Virtual Router Redundancy Protocol (VRRP) Version 3 for IPv4 and IPv6*. IETF.
2. **RFC 3768:** Hinden, R. (2004). *Virtual Router Redundancy Protocol (VRRP)*. IETF.
3. **RFC 2328:** Moy, J. (1998). *OSPF Version 2*. IETF Network Working Group.
4. **RFC 4271:** Rekhter, Y., Li, T., Hares, S. (2006). *A Border Gateway Protocol 4 (BGP-4)*. IETF.
5. **RFC 2385:** Heffernan, A. (1998). *Protection of BGP Sessions via the TCP MD5 Signature Option*. IETF.
6. **RFC 5709:** Bhatia, M., et al. (2009). *OSPFv2 HMAC-SHA Cryptographic Authentication*. IETF.
7. **MikroTik RouterOS v7 Documentation:** *Routing (BGP, OSPF), VRRP, IP Firewall & Tools (Netwatch)*. help.mikrotik.com.
8. **Beyer, B., Jones, C., Petoff, J., Murphy, N. R. (2016):** *Site Reliability Engineering: How Google Runs Production Systems*. O'Reilly Media.
9. **Halabi, B. (2000):** *Internet Routing Architectures* (2nd ed.). Cisco Press.
10. **Doyle, J., Carroll, J. (2005):** *Routing TCP/IP, Volume 1 & 2*. Cisco Press.

---

## 10. Checklist de entrega final

### Diseño (F0)
- [x] IPAM completo y sin solapamiento (enlaces /30 y LANs /24)
- [x] Corrección del diagrama original justificada (≥ 3 defectos analizados y resueltos)
- [x] Política de seguridad definida (usuarios, privilegios, servicios apagados, claves)
- [x] Política de operación definida (formato de change log, Gitflow y backups)

### Redes (F1 - F3)
- [x] 7 MikroTik CHR + 2 switches L2 + 2 VPCs levantados y cableados en GNS3
- [x] VRRP operativo con 2 grupos en load-sharing activo-activo (VRID 10 y 20)
- [x] OSPF área 0 con adyacencias FULL en todos los enlaces internos (incluyendo enlace Core-Core)
- [x] BGP eBGP ×2 establecido en multi-homing con AS 65001 y AS 65002
- [x] Los 5 drills ejecutados y documentados (runbooks en `runbooks/` + post-mortem + RTO medido)

### Seguridad (F0 - F4)
- [x] Hardening de servicios aplicado en los 7 routers (telnet, ftp, www, api desactivados)
- [x] OSPF con autenticación criptográfica MD5 activa (`ospf-secret-g1`)
- [x] BGP con autenticación TCP-MD5 activa (`bgp-secret-g1`)
- [x] VRRP con autenticación simple activa (`vrrpg1`)
- [x] Firewall de borde implementado en EDGE (cadenas input y forward protegidas)
- [x] Prueba de clave incorrecta en OSPF ejecutada y documentada (falla demostrada)

### Operación (F0 - F4)
- [x] Change log completo y consistente con los commits del repositorio
- [x] Historial de backups por fases (`backups/F1`, `F2`, `F3`) y configuraciones finales en `configs/`
- [x] Monitoreo implementado y documentado (Netwatch ICMP y SNMPv2c en EDGE)
- [x] Runbook independiente por cada uno de los 5 drills en `runbooks/`

### Entrega (F5)
- [x] Memoria técnica completa con todas las secciones de la plantilla oficial
- [x] Repositorio Git estructurado según convención, con trazabilidad de commits por rol
- [x] Backlog del proyecto (`backlog.md`) con el 100% de las tareas cerradas
- [x] Catálogo probatorio completo con capturas organizadas en `capturas/` y diagramas en `docs/diagramas/`
- [x] Defensa oral preparada entre Conrado (R1/R3/R5) y Romeo (R2/R4) con dominio de temas propios y cruzados
