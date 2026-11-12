# Runbook — Drill 5: Load-Sharing Activo-Activo con VRRP

## 1. Información General
* **Drill ID:** DRILL-05
* **Capa afectada:** Distribución / Acceso / FHRP Load-Sharing
* **Objetivo:** Demostrar que la topología opera en modalidad activo-activo en la capa de distribución, cursando tráfico simultáneamente por DIST-1 y DIST-2 sin equipos ociosos.
* **Nodos involucrados:** `DIST-1` (Master VRID 10), `DIST-2` (Master VRID 20), `PC-USER` (LAN USERS), `SRV` (LAN SERVERS).

---

## 2. Procedimiento Operativo

### 2.1 Verificación de Roles en Distribución
1. En `DIST-1`:
   - `vrrp10` (USERS, IP 192.168.10.1): Master (`RM`, `priority=150`).
   - `vrrp20` (SERVERS, IP 192.168.20.1): Backup (`B`, `priority=100`).
2. En `DIST-2`:
   - `vrrp10` (USERS, IP 192.168.10.1): Backup (`B`, `priority=100`).
   - `vrrp20` (SERVERS, IP 192.168.20.1): Master (`RM`, `priority=150`).

### 2.2 Ejecución de Trazas desde Hosts
1. Desde `PC-USER` (`192.168.10.100`), ejecutar traceroute hacia la loopback de Internet:
   ```bash
   trace 1.1.1.1
   ```
   *Resultado observado:* El primer salto es `192.168.10.2` (`DIST-1`).
2. Desde `SRV` (`192.168.20.100`), ejecutar traceroute hacia la misma loopback:
   ```bash
   trace 1.1.1.1
   ```
   *Resultado observado:* El primer salto es `192.168.20.3` (`DIST-2`).

---

## 3. Métricas y Post-Mortem
* **RTO / Tiempo de caída:** 0 segundos (operación nominal en régimen).
* **Causa Raíz / Mecanismo:** Despliegue de múltiples grupos VRRP con asignación cruzada de prioridades por subred/VLAN.
* **Lección aprendida:** El load-sharing por VLAN/subred duplica la capacidad de procesamiento útil de la capa de distribución frente a esquemas activo-pasivo clásicos donde un equipo permanece en reposo total consumiendo recursos energéticos y de hardware sin cursar tráfico.

---

## 4. Evidencias
* Captura de traza desde PC-USER pasando por DIST-1: `capturas/DRILL 5/F4 - PC-USER - DRILL 5 - trace 1.1.1.1.png`
* Captura de traza desde SRV pasando por DIST-2: `capturas/DRILL 5/F4 - SRV - DRILL 5 - trace 1.1.1.1.png`

