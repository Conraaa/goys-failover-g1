# Grupo 1 - Laboratorio Failover Routing

**Materia:** Gestión Operativa y Seguridad en Redes (GOYS)

## Integrantes y Roles

- **Conrado Cemino** (Leg.: 32058)
  - R1 - Líder / Edge-WAN
  - R3 - Core
  - R5 - Hosts / QA / Operación
- **Romeo Monfroglio** (Leg.: 31143)
  - R2 - Proveedores
  - R4 - Distribución

## Resumen del Laboratorio
Este repositorio contiene la configuración, documentación y runbooks para implementar una red empresarial jerárquica de 5 capas (Edge, Core, Distribution, Access, Internet) capaz de tolerar fallas (Failover).

Utilizamos redundancia de primer salto (VRRP), redundancia en el enrutamiento interno (OSPF) y múltiples salidas a Internet (BGP multi-homing) sobre MikroTik CHR.
