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

> **Snapshot GNS3:** Se tomó el snapshot `BASE` del proyecto en GNS3 tras completar el cableado y verificar el encendido y conectividad de los nodos.

---

## 3. Configuración (Estado Operativo F2)

Las configuraciones operativas con VRRP, OSPF área 0 y autenticación aplicadas en cada dispositivo fueron extraídas y versionadas en `backups/F2/`.

### 3.1 ISP-1
```routeros
# F2: sin cambios respecto de F1 (ISP no participa en VRRP/OSPF)
/interface bridge add name=loopback
/ip address
add address=1.1.1.1 interface=loopback network=1.1.1.1
add address=10.0.1.1/30 interface=ether1 network=10.0.1.0
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/system identity set name=ISP-1
/system note set show-at-login=no
```

### 3.2 ISP-2
```routeros
# F2: sin cambios respecto de F1 (ISP no participa en VRRP/OSPF)
/interface bridge add name=loopback
/ip address
add address=2.2.2.2 interface=loopback network=2.2.2.2
add address=10.0.2.1/30 interface=ether1 network=10.0.2.0
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/system identity set name=ISP-2
/system note set show-at-login=no
```

### 3.3 EDGE
```routeros
/interface bridge add name=loopback
/routing ospf instance add disabled=no name=ospf1 router-id=3.3.3.3
/routing ospf area add disabled=no instance=ospf1 name=backbone
/ip address
add address=3.3.3.3 interface=loopback network=3.3.3.3
add address=10.0.1.2/30 interface=ether1 network=10.0.1.0
add address=10.0.2.2/30 interface=ether2 network=10.0.2.0
add address=10.0.3.1/30 interface=ether3 network=10.0.3.0
add address=10.0.4.1/30 interface=ether4 network=10.0.4.0
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 auth-key=ospf-secret-g1 disabled=no \
    interfaces=ether3,ether4 type=ptp
add area=backbone disabled=no interfaces=loopback passive
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

### 4.1 Conectividad básica L3 y Protocolos (F1 y F2)

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

---

## 5. Seguridad aplicada

| Mecanismo | Dónde se aplicó | Verificación |
|-----------|-----------------|--------------|
| **Hardening de servicios** | Los 7 routers (EDGE, CORE-1/2, DIST-1/2, ISP-1/2) | Servicios `telnet`, `ftp`, `www`, `api`, `api-ssl` deshabilitados. Verificado con `/ip service print` (únicamente SSH y Winbox activos). |
| **Usuarios y privilegios** | Los 7 routers | Creación de usuario `admin-g1` con privilegios `full` y `monitor-g1` con grupo `read`. Verificado inicio de sesión. |
| **Supresión de banners** | Los 7 routers | `set show-at-login=no` en `/system note` para evitar divulgación de información en login. |
| **OSPF MD5** | EDGE, CORE-1, CORE-2, DIST-1, DIST-2 | Autenticación criptográfica MD5 (`auth=md5`, `auth-key=ospf-secret-g1`) en todas las interfaces PTP de tránsito. Verificado establecimiento de adyacencias Full. |
| **VRRP auth** | DIST-1 y DIST-2 | Autenticación simple con clave `vrrpg1` en los grupos VRID 10 y VRID 20. Limitada a 8 caracteres conforme a la especificación VRRPv2. |
| **BGP TCP-MD5 / Firewall** | F3 | *(se implementará en F3).* |

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

### 6.2 Backups

- **Archivos exportados F1:** Versionados en `backups/F1/` (`backup-f1-*.rcs`).
- **Archivos exportados F2:**
  - `backups/F2/backup-f2-ISP-1.rsc`
  - `backups/F2/backup-f2-ISP-2.rsc`
  - `backups/F2/backup-f2-EDGE.rsc`
  - `backups/F2/backup-f2-CORE-1.rsc`
  - `backups/F2/backup-f2-CORE-2.rsc`
  - `backups/F2/backup-f2-DIST-1.rsc`
  - `backups/F2/backup-f2-DIST-2.rsc`
- **Snapshots GNS3:**
  - `BASE`: Captura del estado inicial y cableado verificado de la topología (F1).
  - `F2-VRRP-OSPF`: Captura con los servicios de VRRP (load-sharing) y OSPF área 0 operativos y convergidos (F2).
- **Procedimiento de restauración:** Probado mediante comando `/import file-name=<archivo>.rsc`.

---

*(Secciones de F3 a F5 a completar en las fases siguientes)*
