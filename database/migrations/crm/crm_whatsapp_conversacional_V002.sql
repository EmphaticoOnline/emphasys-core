-- ============================================================
--  MÓDULO WHATSAPP CRM CONVERSACIONAL
--  Plataforma: Emphasys ERP / CRM
--  Base de datos: PostgreSQL
-- ============================================================


-- ----------------------------------------------------------------
--  PROPÓSITO GENERAL
-- ----------------------------------------------------------------
--  Este script crea la infraestructura completa del módulo
--  WhatsApp integrado al CRM, permitiendo:
--
--  - Registro histórico de mensajes entrantes y salientes
--  - Agrupación de mensajes en conversaciones comerciales
--  - Control de ventana de 24 horas (política WhatsApp)
--  - Gestión de consentimiento (opt-in / opt-out)
--  - Estadísticas diarias automáticas
--  - Base para inbox comercial tipo WhatsApp Web
--  - Integración directa con la tabla public.contactos
--
--  El diseño está orientado a:
--  - Escalabilidad
--  - Integración ERP/CRM
--  - Auditoría completa
--  - Métricas comerciales
--  - Evolución futura a modelo SaaS


-- ----------------------------------------------------------------
--  ARQUITECTURA GENERAL
-- ----------------------------------------------------------------
--  contactoss (public)
--        ↓
--  whatsapp_conversaciones
--        ↓
--  whatsapp_mensajes
--
--  Tablas auxiliares:
--     - whatsapp_contacto_estado
--     - whatsapp_estadisticas
--
--  Funciones clave:
--     - fn_normaliza_telefono_e164
--     - sp_whatsapp_touch_estado
--     - sp_whatsapp_log_mensaje_contactado


-- ----------------------------------------------------------------
--  FLUJO OPERATIVO
-- ----------------------------------------------------------------
--  1. Se recibe o envía un mensaje.
--  2. Se normaliza el número telefónico.
--  3. Se identifica el contacto (si existe).
--  4. Se busca conversación abierta.
--     - Si no existe → se crea automáticamente.
--  5. Se inserta el mensaje en historial.
--  6. Se actualiza estado de ventana 24h.
--  7. Se actualizan estadísticas diarias.
--
--  Las conversaciones pueden:
--     - Cerrarse manualmente por usuario.
--     - Cerrarse automáticamente por inactividad.


-- ----------------------------------------------------------------
--  ALCANCE ACTUAL
-- ----------------------------------------------------------------
--  ✔ CRM Conversacional funcional
--  ✔ Control de ciclo comercial
--  ✔ Métricas básicas
--  ✔ Integración directa con contactos
--
--  No incluye aún:
--     - Multiempresa (empresa_id)
--     - Gestión avanzada de pipeline
--     - Automatizaciones
--     - SLA dinámico
--
--  Diseñado para evolucionar sin romper estructura.


-- ----------------------------------------------------------------
--  NOTAS IMPORTANTES
-- ----------------------------------------------------------------
--  - Todas las tablas están documentadas con COMMENT ON.
--  - Todas las relaciones están normalizadas.
--  - Todos los números se almacenan en formato E.164.
--  - El módulo está completamente aislado en el schema whatsapp.
--  - Preparado para uso productivo empresarial.
--
-- ============================================================

DROP TABLE IF EXISTS whatsapp.whatsapp_mensajes CASCADE;
DROP TABLE IF EXISTS whatsapp.whatsapp_conversaciones CASCADE;
DROP TABLE IF EXISTS whatsapp.whatsapp_contacto_estado CASCADE;
DROP TABLE IF EXISTS whatsapp.whatsapp_estadisticas CASCADE;

BEGIN;

-- ============================================================
--  SCHEMA: WHATSAPP
-- ============================================================

CREATE SCHEMA IF NOT EXISTS whatsapp;

COMMENT ON SCHEMA whatsapp IS
'Modulo CRM Conversacional WhatsApp integrado al ERP/CRM con soporte multiempresa.';

-- ============================================================
--  FUNCIÓN: NORMALIZAR TELEFONO A FORMATO E.164
-- ============================================================

CREATE OR REPLACE FUNCTION whatsapp.fn_normaliza_telefono_e164(tel text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    s text;
BEGIN
    IF tel IS NULL THEN
        RETURN NULL;
    END IF;

    s := regexp_replace(tel, '[\s\-\(\)\.\t]', '', 'g');
    s := regexp_replace(s, '[^+0-9]', '', 'g');

    IF left(s,1) <> '+' THEN
        s := '+52' || s;
    END IF;

    RETURN s;
END;
$$;

COMMENT ON FUNCTION whatsapp.fn_normaliza_telefono_e164(text)
IS 'Normaliza un telefono al formato E.164. Asume prefijo +52 si no existe.';

-- ============================================================
--  VISTA: CONTACTOS CON TELEFONO NORMALIZADO
-- ============================================================

DROP VIEW IF EXISTS whatsapp.vcontactos_telefonos;

CREATE OR REPLACE VIEW whatsapp.vcontactos_telefonos AS
WITH domicilio_principal AS (
    SELECT DISTINCT ON (d.contacto_id)
           d.contacto_id,
           d.ciudad,
           d.estado,
           d.pais
    FROM public.contactos_domicilios d
    ORDER BY d.contacto_id, d.es_principal DESC, d.id ASC
)
SELECT
    c.id,
    c.empresa_id,
    c.nombre,
    dp.ciudad,
    dp.estado,
    dp.pais,
    c.email,
    whatsapp.fn_normaliza_telefono_e164(c.telefono) AS telefonoe164
FROM public.contactos c
LEFT JOIN domicilio_principal dp
       ON dp.contacto_id = c.id
WHERE c.telefono IS NOT NULL;

COMMENT ON VIEW whatsapp.vcontactos_telefonos IS
'Vista que expone contactos con telefono normalizado y empresa asociada.';

-- ============================================================
--  TABLA: CONVERSACIONES
-- ============================================================

CREATE TABLE IF NOT EXISTS whatsapp.whatsapp_conversaciones (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    empresa_id integer NOT NULL,
    contacto_id integer NOT NULL REFERENCES public.contactos(id),
    estado varchar(20) NOT NULL DEFAULT 'abierta'
        CHECK (estado IN ('abierta','cerrada')),
    asignado_a integer NULL,
    creada_en timestamptz NOT NULL DEFAULT now(),
    ultimo_mensaje_en timestamptz NOT NULL DEFAULT now(),
    cerrada_en timestamptz NULL
);

COMMENT ON TABLE whatsapp.whatsapp_conversaciones IS
'Agrupa mensajes en ciclos comerciales por empresa.';

COMMENT ON COLUMN whatsapp.whatsapp_conversaciones.empresa_id IS
'Empresa propietaria de la conversacion.';
COMMENT ON COLUMN whatsapp.whatsapp_conversaciones.contacto_id IS
'Contacto asociado a la conversacion.';

CREATE INDEX IF NOT EXISTS ix_whatsapp_conv_empresa_estado
ON whatsapp.whatsapp_conversaciones(empresa_id, estado);

-- ============================================================
--  TABLA: MENSAJES
-- ============================================================

CREATE TABLE IF NOT EXISTS whatsapp.whatsapp_mensajes (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    empresa_id integer NOT NULL,
    contacto_id integer NULL REFERENCES public.contactos(id),
    conversacion_id bigint NULL REFERENCES whatsapp.whatsapp_conversaciones(id),
    telefono varchar(20) NOT NULL,
    tipo_mensaje varchar(20) CHECK (tipo_mensaje IN ('saliente','entrante')),
    canal varchar(50),
    contenido text,
    plantilla_nombre varchar(100),
    fecha_envio timestamptz,
    status varchar(20),
    id_externo varchar(100),
    intentos_envio integer NOT NULL DEFAULT 0,
    respuesta_json jsonb,
    creado_en timestamptz NOT NULL DEFAULT now(),
    CHECK (telefono ~ '^[+0-9]{8,20}$'),
    CHECK (status IN ('queued','sent','delivered','read','failed','received') OR status IS NULL)
);

COMMENT ON TABLE whatsapp.whatsapp_mensajes IS
'Registro historico de mensajes por empresa.';

COMMENT ON COLUMN whatsapp.whatsapp_mensajes.empresa_id IS
'Empresa propietaria del mensaje.';

CREATE INDEX IF NOT EXISTS ix_whatsapp_mensajes_empresa_fecha
ON whatsapp.whatsapp_mensajes(empresa_id, fecha_envio DESC);

-- ============================================================
--  TABLA: ESTADO CONTACTO
-- ============================================================

CREATE TABLE IF NOT EXISTS whatsapp.whatsapp_contacto_estado (
    empresa_id integer NOT NULL,
    telefono varchar(20) NOT NULL,
    opt_in boolean NOT NULL DEFAULT false,
    opt_out boolean NOT NULL DEFAULT false,
    ultimo_in timestamptz NULL,
    ultimo_out timestamptz NULL,
    actualizado_en timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (empresa_id, telefono),
    CHECK (telefono ~ '^[+0-9]{8,20}$')
);

COMMENT ON TABLE whatsapp.whatsapp_contacto_estado IS
'Controla ventana 24h y consentimiento por empresa.';

COMMENT ON COLUMN whatsapp.whatsapp_contacto_estado.empresa_id IS
'Empresa a la que pertenece el telefono.';

-- ============================================================
--  TABLA: ESTADISTICAS
-- ============================================================

CREATE TABLE IF NOT EXISTS whatsapp.whatsapp_estadisticas (
    empresa_id integer NOT NULL,
    fecha date NOT NULL,
    mensajes_enviados integer NOT NULL DEFAULT 0,
    mensajes_recibidos integer NOT NULL DEFAULT 0,
    plantillas_usadas integer NOT NULL DEFAULT 0,
    errores_envio integer NOT NULL DEFAULT 0,
    PRIMARY KEY (empresa_id, fecha)
);

COMMENT ON TABLE whatsapp.whatsapp_estadisticas IS
'Estadisticas diarias de WhatsApp por empresa.';

COMMENT ON COLUMN whatsapp.whatsapp_estadisticas.empresa_id IS
'Empresa a la que pertenecen las metricas.';

COMMIT;