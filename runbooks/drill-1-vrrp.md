# Runbook — Drill 1: Caída de Gateway VRRP (DIST-1)

## 1. Información General
* **Drill ID:** DRILL-01
* **Capa afectada:** Distribución / First Hop Redundancy Protocol (FHRP)
* **Objetivo:** Validar que ante la falla total del router Master (DIST-1), el router Backup (DIST-2) asuma la IP virtual sin interrumpir el servicio de los hosts de la LAN USERS.
* **Nodos involucrados:** `DIST-1` (Master actual), `DIST-2` (Backup), `PC-USER` (Host cliente).

---

## 2. Procedimiento Operativo

### 2.1 Simulación del Incidente
1. Desde `PC-USER`, iniciar un ping continuo hacia la loopback pública de Internet:
   ```bash
   ping 1.1.1.1
   ```
2. En GNS3, apagar abruptamente el nodo `DIST-1` (clic derecho → *Stop* o *Suspend*).

### 2.2 Detección
* **Síntomas:** Pérdida momentánea de 1 o 2 paquetes ICMP en `PC-USER`.
* **Comprobación:** En `DIST-2`, verificar la tabla de interfaces VRRP:
   ```routeros
   /interface vrrp print detail
   ```
   Se observa que `vrrp10` pasa automáticamente del estado `B` (Backup) al estado `RM` (Running Master).

### 2.3 Respuesta Automática del Sistema
* Al no recibir anuncios Hello de VRRP (Dead Interval = 3 × Advertisement Interval + Skew Time ≈ 3.6s), `DIST-2` asume el rol de Master.
* `DIST-2` emite un Gratuitous ARP (GARP) en la LAN con la MAC virtual `00:00:5E:00:01:0A`, actualizando la tabla CAM de `SW-ACC-USERS` de forma transparente.

### 2.4 Recuperación y Retorno (Failback)
1. En GNS3, encender nuevamente el router `DIST-1`.
2. Al reiniciar, `DIST-1` evalúa las prioridades (`priority=150` vs `priority=100` de `DIST-2`). Con el parámetro *preemption* activo de fábrica, `DIST-1` retoma su rol como Master y `DIST-2` retorna a Backup.

---

## 3. Métricas y Post-Mortem
* **Tiempo de conmutación (RTO):** ~2 a 3 segundos (1-2 paquetes perdidos).
* **Causa Raíz / Mecanismo:** Protocolo VRRPv2 estándar (RFC 3768) con autenticación simple `vrrpg1`.
* **Lección aprendida:** La redundancia de primer salto aísla por completo la topología interna del cliente final: el host nunca cambia de configuración ni pierde su default gateway (192.168.10.1).

---

## 4. Evidencias
* Captura de topología con DIST-1 suspendido: `capturas/DRILL 1/F4 - TOPOLOGIA - DRILL 1 - DIST-1 apagado.png`
* Captura de estado Master en DIST-2: `capturas/DRILL 1/F4 - DIST-2 - DRILL 1 - vrrp print durante apagado de DIST-1.png`
* Captura de continuidad de ping en PC-USER: `capturas/DRILL 1/F4 - PC-USER - DRILL 1 - ping 1.1.1.1 durante apagado de DIST-1.png`

