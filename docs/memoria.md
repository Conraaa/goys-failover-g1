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
*(se agregarán secciones en proximas fases)*
