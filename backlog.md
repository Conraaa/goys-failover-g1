# Backlog - Laboratorio Failover Routing

### Grupo: 1

## Estado

- `[ ]` pendiente · `[~]` en curso · `[x]` hecho
- **Dueño** (rol): `[R1]` … `[R5]`.

---

## Epic F0 - Diseño y gestión de cambio

### IPAM / direccionamiento
- [x] [R5] Diseñar tabla IPAM sin solapamiento
- [x] [R5] Definir VRIDs y Router-IDs

### Corrección del diagrama (3 defectos)
- [x] [R1] Documentar 3 defectos del diagrama original y sus correcciones
- [x] [R1] Justificar las correcciones

### Política de seguridad
- [x] [R1] Definir usuarios y privilegios
- [x] [R2] Definir servicios a deshabilitar
- [x] [R3] Establecer claves de autenticación (OSPF/BGP/VRRP)

### Política de operación (change log + backup)
- [x] [R5] Definir formato del change log (Conventional Commits)
- [x] [R5] Definir política de backup

### Repositorio git
- [x] [R5] Crear estructura del repositorio y README
- [x] [R5] Copiar y configurar backlog
- [x] [R5] Completar F0 en memoria.md y hacer commit inicial

---

## Epic F1 - Topología + hardening + backup

### Despliegue (7 CHR + 2 switches + 2 hosts)
- [ ] [R1] Levantar nodos de la topología en GNS3
- [ ] [R1] Conectar los enlaces según topología

### IPs de enlace + loopbacks
- [ ] [R1] Configurar IP e interfaz en EDGE
- [ ] [R2] Configurar IP y loopbacks en ISP-1 e ISP-2
- [ ] [R3] Configurar IP y loopbacks en CORE-1 y CORE-2
- [ ] [R4] Configurar IP y loopbacks en DIST-1 y DIST-2
- [ ] [R5] Verificar ping entre vecinos directos

### Snapshot BASE
- [ ] [R5] Tomar snapshot en GNS3

### Hardening (los 7 routers)
- [ ] [R1] Aplicar hardening en EDGE
- [ ] [R2] Aplicar hardening en ISP-1 e ISP-2
- [ ] [R3] Aplicar hardening en CORE-1 y CORE-2
- [ ] [R4] Aplicar hardening en DIST-1 y DIST-2

### Backup inicial (/export)
- [ ] [R5] Exportar config de todos los routers y subir a repo

---

## Epic F2 - VRRP + OSPF

### VRRP (2 grupos, load-sharing, auth)
- [ ] [R4] configurar VRRP vrid 10 en DIST-1 (master)
- [ ] [R4] configurar VRRP vrid 20 en DIST-2 (master)
- [ ] [R4] activar auth simple en ambos grupos
- [ ] [R5] verificar master/backup con /interface vrrp print

### OSPF área 0 (con MD5, incluido core–core)
- [ ] [R3] Configurar OSPF en CORE-1 y CORE-2 (incluyendo core-core)
- [ ] [R4] Configurar OSPF en DIST-1 y DIST-2
- [ ] [R1] Configurar OSPF en EDGE
- [ ] [R3] Activar autenticación MD5 en todas las adyacencias

### Verificación L3 (ping intra-LAN + gateway virtual)
- [ ] [R5] Configurar IP estáticas en PC-USER y SRV
- [ ] [R5] Comprobar ping a gateways virtuales e intra-LAN

---

## Epic F3 - BGP + firewall

### eBGP multi-homing (2 sesiones, TCP-MD5)
- [ ] [R1] Configurar eBGP en EDGE hacia ISP-1 e ISP-2
- [ ] [R2] Configurar eBGP en ISP-1 e ISP-2 hacia EDGE
- [ ] [R1] Activar autenticación TCP-MD5

### Redistribución OSPF→BGP
- [ ] [R1] Configurar anuncio de LANs en EDGE hacia ISPs

### Salida a "Internet" (host → loopback ISP)
- [ ] [R5] Comprobar salida a loopback ISP desde host

### Firewall edge (filtro + plano de gestión)
- [ ] [R1] Configurar reglas de firewall en EDGE (forwarding y input)

---

## Epic F4 - Drills + monitoreo

### Los 5 drills (runbook + post-mortem + tiempo)
- [ ] [R5] Ejecutar Drill 1 (VRRP) y documentar
- [ ] [R5] Ejecutar Drill 2 (OSPF) y documentar
- [ ] [R5] Ejecutar Drill 3 (BGP) y documentar
- [ ] [R5] Ejecutar Drill 4 (check-gateway) y documentar
- [ ] [R5] Ejecutar Drill 5 (Load-sharing VRRP) y documentar

### Monitoreo (SNMP/chequeos)
- [ ] [R5] Habilitar SNMP y/o Netwatch en nodos

### Verificación de seguridad (clave incorrecta falla)
- [ ] [R5] Probar fallo de OSPF/BGP con clave incorrecta y documentar

---

## Epic F5 - Memoria + defensa

### Memoria (plantilla completa)
- [ ] [R5] Revisar que memoria.md esté 100% completada

### Backlog cerrado (todo en "hecho")
- [ ] [R5] Pasar todas las tareas a completadas

### Defensa oral (parte propia + ajena)
- [ ] [R1] Preparar defensa oral
- [ ] [R2] Preparar defensa oral
