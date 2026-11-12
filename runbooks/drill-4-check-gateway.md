# Runbook — Drill 4: Failover Estático con Check-Gateway

## 1. Información General
* **Drill ID:** DRILL-04
* **Capa afectada:** Enlace / Enrutamiento Estático con Sondeo L3
* **Objetivo:** Demostrar la alternativa de failover a nivel de enlace para entornos sin enrutamiento dinámico BGP, empleando `check-gateway=ping` y distancia administrativa (`distance`).
* **Nodos involucrados:** `EDGE`, `ISP-1`, `ISP-2`.

---

## 2. Procedimiento Operativo

### 2.1 Configuración de Prueba en EDGE
Se configuran dos rutas estáticas hacia una dirección de prueba (`8.8.8.8/32`):
```routeros
/ip route add dst-address=8.8.8.8/32 gateway=10.0.1.1 check-gateway=ping distance=1
/ip route add dst-address=8.8.8.8/32 gateway=10.0.2.1 distance=2
```

### 2.2 Simulación del Incidente
1. Desde `EDGE`, iniciar un ping continuo hacia el gateway de ISP-1 (`10.0.1.1`).
2. En GNS3, apagar el router `ISP-1`.

### 2.3 Detección
* **Síntomas:** El router `EDGE` deja de recibir respuestas ICMP desde `10.0.1.1`.
* **Comprobación:** En `EDGE`, verificar la tabla de rutas:
   ```routeros
   /ip route print
   ```
   Tras 2 pings fallidos consecutivos (10 a 20 segundos), la ruta con `distance=1` pasa a estado inactivo (`IsH` / inactive).

### 2.4 Respuesta Automática del Sistema
* Al invalidarse la ruta primaria por fallo de `check-gateway`, la ruta de respaldo hacia `8.8.8.8` vía ISP-2 (`distance=2`) se activa automáticamente (`As+`), asumiendo el reenvío del tráfico.

### 2.5 Recuperación y Retorno (Failback)
1. Encender nuevamente el nodo `ISP-1` en GNS3.
2. Al recibir respuestas ICMP exitosas, RouterOS marca la ruta con `distance=1` como activa nuevamente y devuelve la ruta secundaria a estado inactivo.
3. Se remueven las rutas estáticas de prueba:
   ```routeros
   /ip route remove [find dst-address="8.8.8.8/32"]
   ```

---

## 3. Métricas y Post-Mortem
* **Tiempo de conmutación (RTO):** ~10 a 15 segundos (determinado por la frecuencia de sondeo ICMP de RouterOS).
* **Causa Raíz / Mecanismo:** Sonda ICMP periódica (`check-gateway=ping`) combinada con métrica de distancia administrativa.
* **Lección aprendida:** `check-gateway` es una herramienta fundamental, económica y altamente efectiva para detectar caídas "invisibles" de enlace (donde el cable local sigue arriba pero el gateway upstream no responde), ideal para sucursales sin BGP.

---

## 4. Evidencias
* Captura de topología con ISP-1 apagado: `capturas/DRILL 4/F4 - TOPOLOGIA - DRILL 4 - ISP-1 apagado.png`
* Capturas de ping hacia 10.0.1.1 durante la caída: `capturas/DRILL 4/F4 - EDGE - DRILL 4 - ping 10.0.1.1 durante apagado de ISP-1 (1).png` y `capturas/DRILL 4/F4 - EDGE - DRILL 4 - ping 10.0.1.1 durante apagado de ISP-1 (2).png`
* Captura de recuperación del ping al reencender ISP-1: `capturas/DRILL 4/F4 - EDGE - DRILL 4 - ping 10.0.1.1 durante prendida de ISP-1.png`

