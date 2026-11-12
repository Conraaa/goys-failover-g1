# Runbook — Drill 2: Corte de Camino Interno OSPF (EDGE ↔ CORE-1)

## 1. Información General
* **Drill ID:** DRILL-02
* **Capa afectada:** Core / Interior Gateway Protocol (IGP - OSPF área 0)
* **Objetivo:** Verificar la reconvergencia de OSPF ante la caída del enlace ascendente principal entre EDGE y CORE-1, demostrando la necesidad y función del enlace redundante Core-Core (`CORE-1 ↔ CORE-2`).
* **Nodos involucrados:** `EDGE`, `CORE-1`, `CORE-2`, `PC-USER`.

---

## 2. Procedimiento Operativo

### 2.1 Simulación del Incidente
1. Mantener el ping continuo desde `PC-USER` hacia `1.1.1.1`.
2. En GNS3, eliminar o suspender el enlace físico (cable) entre `EDGE` (interfaz ether3) y `CORE-1` (interfaz ether1).

### 2.2 Detección
* **Síntomas:** El enlace físico pasa a estado *link-down*.
* **Comprobación:** En `CORE-1` y `EDGE`, consultar vecinos OSPF:
   ```routeros
   /routing ospf neighbor print
   ```
   La adyacencia entre `3.3.3.3` (EDGE) y `4.4.4.4` (CORE-1) desaparece inmediatamente.

### 2.3 Respuesta Automática del Sistema
* OSPF genera nuevos LSA Tipo 1 (Router LSA) notificando la caída del enlace punto a punto `10.0.3.0/30`.
* Se ejecuta el algoritmo Dijkstra (SPF) en todos los nodos del área 0.
* El tráfico originado en `DIST-1` con destino a Internet que llega a `CORE-1` ahora es desviado a través del enlace Core-Core (`10.0.5.0/30`) hacia `CORE-2`, subiendo hacia `EDGE` por el enlace `CORE-2 ↔ EDGE` (`10.0.4.0/30`).

### 2.4 Recuperación y Retorno (Failback)
1. En GNS3, restablecer el cable entre `EDGE` (ether3) y `CORE-1` (ether1).
2. Los paquetes OSPF Hello se intercambian y autentican con MD5 (`ospf-secret-g1`).
3. La adyacencia vuelve a estado `Full` y el tráfico reasume el camino más corto directo hacia EDGE.

---

## 3. Métricas y Post-Mortem
* **Tiempo de conmutación (RTO):** Inmediato a nivel de enlace (< 1 segundo, 0 pérdidas apreciables de ping).
* **Causa Raíz / Mecanismo:** Detección de pérdida de port carrier L1/L2 y recálculo SPF de OSPF v2 con enlace Core-Core operativo.
* **Lección aprendida:** Corrige el Defecto #3 del diagrama original de Cisco. Sin el enlace Core-Core, la pérdida del enlace `EDGE ↔ CORE-1` habría aislado a `CORE-1` y a toda la distribución dependiente de él.

---

## 4. Evidencias
* Captura de topología con cable cortado: `capturas/DRILL 2/F4 - TOPOLOGIA - DRILL 2 - cable EDGE-CORE-1 cortado.png`
* Captura de continuidad de ping en PC-USER: `capturas/DRILL 2/F4 - PC-USER - DRILL 2 - ping 1.1.1.1 durante corte de cable EDGE-CORE-1.png`

