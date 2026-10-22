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
- **Claves de autenticación** (OSPF / BGP / VRRP): ospf-secret-g1 / bgp-secret-g1 / vrrp-secret-g1.

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

## 3. Configuración (Línea Base F1)

Las configuraciones base de direccionamiento, interfaces y hardening aplicadas en cada dispositivo fueron extraídas y versionadas en `backups/F1/`.

### 3.1 ISP-1
```routeros
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
/system identity set name=EDGE
/system note set show-at-login=no
```

### 3.4 CORE-1
```routeros
/interface bridge add name=loopback
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
/system identity set name=CORE-1
/system note set show-at-login=no
```

### 3.5 CORE-2
```routeros
/interface bridge add name=loopback
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
/system identity set name=CORE-2
/system note set show-at-login=no
```

### 3.6 DIST-1
```routeros
/interface bridge add name=loopback
/ip address
add address=6.6.6.6 interface=loopback network=6.6.6.6
add address=10.0.6.2/30 interface=ether1 network=10.0.6.0
add address=10.0.8.2/30 interface=ether2 network=10.0.8.0
add address=192.168.10.2/24 interface=ether3 network=192.168.10.0
add address=192.168.20.2/24 interface=ether4 network=192.168.20.0
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/system identity set name=DIST-1
/system note set show-at-login=no
```

### 3.7 DIST-2
```routeros
/interface bridge add name=loopback
/ip address
add address=7.7.7.7 interface=loopback network=7.7.7.7
add address=10.0.7.2/30 interface=ether1 network=10.0.7.0
add address=10.0.9.2/30 interface=ether2 network=10.0.9.0
add address=192.168.10.3/24 interface=ether3 network=192.168.10.0
add address=192.168.20.3/24 interface=ether4 network=192.168.20.0
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/system identity set name=DIST-2
/system note set show-at-login=no
```

### 3.8 Hosts (PC-USER / SRV)
- **PC-USER:** `ip 192.168.10.100/24 192.168.10.1`
- **SRV:** `ip 192.168.20.100/24 192.168.20.1`

---

## 4. Verificación (F1)

### 4.1 Conectividad básica L3 (Vecinos directos)

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


---

## 5. Seguridad aplicada (F1)

| Mecanismo | Dónde se aplicó | Verificación |
|-----------|-----------------|--------------|
| **Hardening de servicios** | Los 7 routers (EDGE, CORE-1/2, DIST-1/2, ISP-1/2) | Servicios `telnet`, `ftp`, `www`, `api`, `api-ssl` deshabilitados. Verificado con `/ip service print` (únicamente SSH y Winbox activos). |
| **Usuarios y privilegios** | Los 7 routers | Creación de usuario `admin-g1` con privilegios `full` y `monitor-g1` con grupo `read`. Verificado inicio de sesión. |
| **Supresión de banners** | Los 7 routers | `set show-at-login=no` en `/system note` para evitar divulgación de información en login. |

---

## 6. Gestión operativa (F1)

### 6.1 Change log

| Fecha | Responsable | Cambio | Motivo | Cómo se revierte |
|-------|-------------|--------|--------|------------------|
| 2026-10-16 | Conrado (R1/R3/R5) y Romeo (R2/R4) | Despliegue de topología de 11 nodos en GNS3 y asignación de IPs/loopbacks | Construcción de la infraestructura base para el laboratorio (F1) | Revertir cableado o borrar interfaces/direcciones en `/ip address` |
| 2026-10-16 | Conrado (R1/R3) y Romeo (R2/R4) | Hardening de servicios (`telnet`, `ftp`, `www`, etc. en disabled) en los 7 routers | Reducción de la superficie de ataque y cumplimiento de la política de seguridad | Habilitar servicios con `/ip service set [name] disabled=no` |
| 2026-10-16 | Conrado (R5) | Creación de Snapshot BASE en GNS3 y exportación de backups `/export` a `backups/F1/` | Generación del punto de restauración y control de versiones de configs iniciales | Restaurar el snapshot BASE en GNS3 o importar backups con `/import` |

### 6.2 Backups

- **Archivos exportados:**
  - `backups/F1/backup-f1-ISP-1.rcs`
  - `backups/F1/backup-f1-ISP-2.rcs`
  - `backups/F1/backup-f1-EDGE.rcs`
  - `backups/F1/backup-f1-CORE-1.rcs`
  - `backups/F1/backup-f1-CORE-2.rcs`
  - `backups/F1/backup-f1-DIST-1.rcs`
  - `backups/F1/backup-f1-DIST-2.rcs`
- **Snapshot GNS3:** `BASE` (captura del estado inicial verificado).
- **Procedimiento de restauración:** Probado mediante comando `/import file-name=<archivo>.rcs`.

---

*(Secciones de F2 a F5 a completar en las fases siguientes)*
