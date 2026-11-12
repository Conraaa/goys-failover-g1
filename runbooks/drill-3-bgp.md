# Runbook — Drill 3: Caída de Proveedor de Internet (ISP-1)

## 1. Información General
* **Drill ID:** DRILL-03
* **Capa afectada:** Internet / WAN / Exterior Gateway Protocol (eBGP Multi-Homing)
* **Objetivo:** Demostrar que ante la pérdida total de conexión con el proveedor primario (ISP-1), el tráfico de salida a Internet conmuta automáticamente al proveedor secundario (ISP-2).
* **Nodos involucrados:** `EDGE` (AS 65000), `ISP-1` (AS 65001), `ISP-2` (AS 65002), `PC-USER`.

---

## 2. Procedimiento Operativo

### 2.1 Simulación del Incidente
1. Ejecutar ping continuo en `PC-USER` hacia la dirección de Internet `1.1.1.1`.
2. En GNS3, desconectar el cable WAN entre `EDGE` (ether1) e `ISP-1` (ether1) o suspender el nodo `ISP-1`.

### 2.2 Detección
* **Síntomas:** Pérdida transitoria de conexión mientras expira la sesión BGP o se detecta el link-down.
* **Comprobación:** En `EDGE`, verificar las sesiones BGP:
   ```routeros
   /routing bgp session print
   ```
   La sesión `to-ISP1` pasa a estado inactivo/down, manteniéndose activa `to-ISP2`.

### 2.3 Respuesta Automática del Sistema
* BGP retira las rutas recibidas por el vecino `10.0.1.1`.
* La ruta por defecto principal (`0.0.0.0/0` vía `10.0.1.1`) queda invalidada en la FIB.
* El enrutador conmuta la salida por la ruta alternativa provista por `ISP-2` (`10.0.2.1`), restableciendo el flujo de paquetes salientes.

### 2.4 Recuperación y Retorno (Failback)
1. Reconectar el cable entre `EDGE` e `ISP-1`.
2. La sesión TCP (puerto 179) se establece y valida con `tcp-md5-key=bgp-secret-g1`.
3. Al alcanzar el estado `established`, ISP-1 reenvía sus anuncios de prefijos y la convergencia BGP se completa automáticamente.

---

## 3. Métricas y Post-Mortem
* **Tiempo de conmutación (RTO):** Inmediato con link-down (~1-2 timeouts de ping).
* **Causa Raíz / Mecanismo:** eBGP multi-homing dual-homed con retiro de prefijos dinámicos y selección de mejor ruta BGP.
* **Lección aprendida:** Multi-homing con dos AS distintos garantiza disponibilidad continua del negocio ante cortes de fibra de última milla o problemas de tránsito en un proveedor ISP específico.

---

## 4. Evidencias
* Captura de topología con cable EDGE-ISP-1 cortado: `capturas/DRILL 3/F4 - TOPOLOGIA - DRILL 3 - cable EDGE-ISP-1 cortado.png`
* Captura de conmutación de ping en PC-USER (corte 1 y 2): `capturas/DRILL 3/F4 - PC-USER - DRILL 3 - ping 1.1.1.1 durante corte de cable EDGE-ISP-1 (1).png` y `capturas/DRILL 3/F4 - PC-USER - DRILL 3 - ping 1.1.1.1 durante corte de cable EDGE-ISP-1 (2).png`
* Captura de recuperación de ping en PC-USER tras reconexión: `capturas/DRILL 3/F4 - PC-USER - DRILL 3 - ping 1.1.1.1 durante reconexion de cable EDGE-ISP-1.png`

