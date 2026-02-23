/*
================================================================================
Archivo: core_dicor_operaciones_reset_V001.sql
Módulo: Core
Descripción:
    Script de mantenimiento para reiniciar el entorno operativo de Dicor.

    Este script:
    - Vacía las tablas operativas principales del sistema.
    - Reinicia las secuencias (RESTART IDENTITY).
    - Elimina la tabla facturas_backup_iva si existe.
    
    Está pensado para:
    - Entornos de desarrollo
    - Pruebas controladas
    - Reinicialización completa antes de carga de datos

Advertencias:
    - Este script es destructivo.
    - Elimina permanentemente toda la información operativa.
    - No debe ejecutarse en producción sin respaldo previo.
    - Utiliza CASCADE, por lo que puede afectar dependencias relacionadas.

Tablas afectadas:
    - entregas
    - entregas_archivos
    - facturas
    - facturas_imagenes
    - notificaciones
    - operaciones_credito
    - operaciones_credito_adjuntos
    - operaciones_credito_aplicaciones
    - operaciones_credito_items
    - operaciones_dinero
    - operaciones_dinero_provisiones
    - facturas_backup_iva (DROP TABLE)

Versión:
    V001 – Creación inicial del script de reseteo operativo.
Fecha:
    2026-02
================================================================================
*/
BEGIN;

TRUNCATE TABLE 
    entregas,
    entregas_archivos,
    facturas,
    facturas_imagenes,
    notificaciones,
    operaciones_credito,
    operaciones_credito_adjuntos,
    operaciones_credito_aplicaciones,
    operaciones_credito_items,
    operaciones_dinero,
    operaciones_dinero_provisiones
RESTART IDENTITY CASCADE;
DROP TABLE IF EXISTS facturas_backup_iva CASCADE;
COMMIT;