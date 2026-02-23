# emphasys-core
Emphasys Core es el repositorio base de la plataforma Emphasys. Centraliza la estructura oficial de base de datos, los módulos compartidos y las definiciones arquitectónicas utilizadas por todas las aplicaciones del ecosistema (ERP, CRM, WhatsApp y soluciones verticales).

Propósito

Este repositorio tiene como objetivo:
    Centralizar la estructura oficial de la base de datos.
    Mantener los scripts SQL y migraciones bajo control de versiones.
    Definir los módulos compartidos utilizados por múltiples aplicaciones.
    Establecer estándares arquitectónicos para la plataforma.
    Garantizar consistencia, escalabilidad y orden en la evolución del sistema.

Estructura
/database
    /core
    /shared
    /erp
    /crm
    /whatsapp
    /verticales

Pueden incluirse también:

    Documentación técnica
    Decisiones arquitectónicas
    Convenciones y estándares
    Scripts utilitarios

Principios

    Fuente única de verdad para la estructura de base de datos.
    Organización modular por dominio.
    Separación clara entre núcleo de plataforma y módulos específicos de aplicación.
    Evolución controlada mediante versionado.
    Preparado para entornos multiempresa.
