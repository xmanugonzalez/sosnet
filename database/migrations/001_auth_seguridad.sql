-- Migración 001: autenticación real, configuración persistente y auditoría.
-- Ejecutar una sola vez sobre una base sosnet creada con el esquema anterior.
--   docker compose exec -T mysql mysql --protocol=TCP -h 127.0.0.1 \
--     -usosnet -psosnet_dev sosnet < database/migrations/001_auth_seguridad.sql

USE sosnet;

SET NAMES utf8mb4;

ALTER TABLE Usuarios
    ADD COLUMN correo VARCHAR(120) NULL
        COMMENT 'Correo electrónico para iniciar sesión' AFTER usuario,
    ADD COLUMN activo TINYINT(1) NOT NULL DEFAULT 1
        COMMENT 'Indica si el usuario puede iniciar sesión' AFTER rol,
    ADD COLUMN ultimo_acceso DATETIME NULL
        COMMENT 'Último inicio de sesión correcto' AFTER activo;

CREATE UNIQUE INDEX UQ_Usuarios_Correo
    ON Usuarios (correo);

UPDATE Usuarios
SET correo = 'operador@sosnet.local',
    contrasena = 'scrypt:32768:8:1$3VXPvpbwneBrVL6S$1ddce3db24eaf66fbd24a130dc1ea9cc3074c821fa76e4a9276c5f215c844b307309d6aae0fc6a85fa8ff4afbc2cf6993e2ebf1dee5c60e8609e7e23e2130583',
    activo = 1
WHERE usuario = 'operador';

UPDATE Usuarios
SET activo = 0,
    correo = NULL
WHERE usuario = 'sistema';

INSERT INTO Usuarios (nombre, usuario, correo, contrasena, rol, activo, fecha_registro)
SELECT 'Administrador SOSNET', 'admin', 'admin@sosnet.local',
       'scrypt:32768:8:1$gPNoK63RGggCffmo$34431a8a16bb87e5e2373cb8445924a4c86c482ad579dcdda7f53a3e185675eacebfa221761cb5ce6b8fb9e8a7707b89f0e95b298660dba7d03fa32d11146b65',
       'admin', 1, NOW()
WHERE NOT EXISTS (SELECT 1 FROM Usuarios WHERE usuario = 'admin');

CREATE TABLE IF NOT EXISTS ConfiguracionCentral (
    id_configuracion INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador de la configuración',
    nombre VARCHAR(100) NOT NULL
        COMMENT 'Nombre visible de la central',
    ubicacion VARCHAR(150) NOT NULL
        COMMENT 'Ciudad o comunidad de la central',
    actualizado_en DATETIME NOT NULL
        COMMENT 'Fecha de la última actualización',
    CONSTRAINT PK_ConfiguracionCentral PRIMARY KEY (id_configuracion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Configuración institucional de la central SOSNET';

INSERT INTO ConfiguracionCentral (nombre, ubicacion, actualizado_en)
SELECT 'Central de rescate', 'Asunción, Paraguay', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ConfiguracionCentral);

CREATE TABLE IF NOT EXISTS Actividad (
    id_actividad INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador del evento de auditoría',
    id_usuario INT NULL
        COMMENT 'Usuario que realizó la acción',
    accion VARCHAR(50) NOT NULL
        COMMENT 'Tipo de acción registrada',
    descripcion VARCHAR(255) NOT NULL
        COMMENT 'Descripción legible del evento',
    entidad VARCHAR(40) NULL
        COMMENT 'Entidad afectada por la acción',
    entidad_id INT NULL
        COMMENT 'Identificador de la entidad afectada',
    fecha DATETIME NOT NULL
        COMMENT 'Fecha y hora del evento',
    CONSTRAINT PK_Actividad PRIMARY KEY (id_actividad)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Auditoría de acciones administrativas y de operación';

CREATE INDEX IX_Actividad_Fecha ON Actividad (fecha);
CREATE INDEX IX_Actividad_Usuario ON Actividad (id_usuario);

ALTER TABLE Actividad
    ADD CONSTRAINT Usuarios_Actividad_fk
    FOREIGN KEY (id_usuario)
    REFERENCES Usuarios (id_usuario)
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
