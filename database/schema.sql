-- Esquema SOSNET para MySQL 8.
-- Traducción del modelo original de SQL Server:
--   * INT IDENTITY      -> INT AUTO_INCREMENT
--   * GO                -> eliminado (separador de lotes de SQL Server)
--   * NONCLUSTERED INDEX -> INDEX / UNIQUE INDEX (InnoDB)
--   * Comentarios       -> COMMENT en tablas y columnas
--   * Base de datos     -> sosnet (minúsculas, igual que DATABASE_URL)

CREATE DATABASE IF NOT EXISTS sosnet
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE sosnet;

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS TiposEmergencia (
    id_tipo INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador único del tipo de emergencia',
    nombre VARCHAR(100) NOT NULL
        COMMENT 'Nombre del tipo de emergencia',
    descripcion VARCHAR(255) NULL
        COMMENT 'Descripción del tipo de emergencia',
    CONSTRAINT PK_TiposEmergencia PRIMARY KEY (id_tipo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Almacena los tipos de emergencia registrados en SOSNET';

CREATE TABLE IF NOT EXISTS Dispositivos (
    id_dispositivo INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador único del dispositivo',
    codigo VARCHAR(50) NOT NULL
        COMMENT 'Código único del dispositivo ESP32',
    nombre VARCHAR(100) NOT NULL
        COMMENT 'Nombre identificador del dispositivo',
    tipo VARCHAR(30) NOT NULL
        COMMENT 'Función del dispositivo en la red',
    estado VARCHAR(20) NOT NULL
        COMMENT 'Estado del dispositivo',
    fecha_registro DATETIME NOT NULL
        COMMENT 'Fecha de registro del dispositivo',
    CONSTRAINT PK_Dispositivos PRIMARY KEY (id_dispositivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Almacena los dispositivos ESP32 de SOSNET';

CREATE UNIQUE INDEX UQ_Dispositivos_Codigo
    ON Dispositivos (codigo);

CREATE TABLE IF NOT EXISTS SolicitudesSOS (
    id_solicitud INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador único de la solicitud',
    codigo_mensaje VARCHAR(50) NOT NULL
        COMMENT 'Código único del mensaje SOS',
    nombre_solicitante VARCHAR(100) NULL
        COMMENT 'Nombre de la persona que solicita ayuda',
    id_tipo INT NOT NULL
        COMMENT 'Tipo de emergencia de la solicitud',
    id_dispositivo INT NOT NULL
        COMMENT 'Dispositivo ESP32 que originó la solicitud',
    ubicacion VARCHAR(255) NOT NULL
        COMMENT 'Ubicación indicada por la persona afectada',
    cantidad_personas INT NOT NULL
        COMMENT 'Cantidad de personas afectadas',
    descripcion VARCHAR(500) NULL
        COMMENT 'Descripción de la situación de emergencia',
    prioridad VARCHAR(20) NOT NULL
        COMMENT 'Nivel de prioridad de la emergencia',
    estado VARCHAR(30) NOT NULL
        COMMENT 'Estado actual de la solicitud SOS',
    fecha_recepcion DATETIME NOT NULL
        COMMENT 'Fecha y hora de recepción de la solicitud',
    CONSTRAINT PK_SolicitudesSOS PRIMARY KEY (id_solicitud)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Almacena las solicitudes de emergencia recibidas por SOSNET';

CREATE UNIQUE INDEX UQ_SolicitudesSOS_CodigoMensaje
    ON SolicitudesSOS (codigo_mensaje);

CREATE TABLE IF NOT EXISTS RegistrosComunicacion (
    id_registro INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador único del registro de comunicación',
    id_solicitud INT NOT NULL
        COMMENT 'Solicitud SOS relacionada con la comunicación',
    fecha_recepcion DATETIME NOT NULL
        COMMENT 'Fecha y hora de recepción del mensaje',
    estado_recepcion VARCHAR(30) NOT NULL
        COMMENT 'Estado de recepción del mensaje',
    id_dispositivo INT NOT NULL
        COMMENT 'Dispositivo que recibió o retransmitió el mensaje',
    CONSTRAINT PK_RegistrosComunicacion PRIMARY KEY (id_registro)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Registra la recepción de mensajes SOS entre dispositivos';

CREATE TABLE IF NOT EXISTS Usuarios (
    id_usuario INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador único del usuario',
    nombre VARCHAR(100) NOT NULL
        COMMENT 'Nombre completo del usuario',
    usuario VARCHAR(50) NOT NULL
        COMMENT 'Nombre de usuario para iniciar sesión',
    contrasena VARCHAR(255) NOT NULL
        COMMENT 'Contraseña protegida mediante hash',
    rol VARCHAR(30) NOT NULL
        COMMENT 'Rol del usuario en el sistema',
    fecha_registro DATETIME NOT NULL
        COMMENT 'Fecha de registro del usuario',
    CONSTRAINT PK_Usuarios PRIMARY KEY (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Almacena los usuarios autorizados del sistema SOSNET';

CREATE UNIQUE INDEX UQ_Usuarios_Usuario
    ON Usuarios (usuario);

CREATE TABLE IF NOT EXISTS HistorialEstados (
    id_historial INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador único del historial',
    id_solicitud INT NOT NULL
        COMMENT 'Solicitud de emergencia relacionada',
    id_usuario INT NOT NULL
        COMMENT 'Usuario que realizó la modificación',
    estado_anterior VARCHAR(30) NULL
        COMMENT 'Estado anterior de la solicitud',
    estado_nuevo VARCHAR(30) NOT NULL
        COMMENT 'Nuevo estado de la solicitud',
    fecha_cambio DATETIME NOT NULL
        COMMENT 'Fecha y hora del cambio de estado',
    observacion VARCHAR(255) NULL
        COMMENT 'Observaciones sobre el cambio realizado',
    CONSTRAINT PK_HistorialEstados PRIMARY KEY (id_historial)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Registra los cambios de estado de las solicitudes SOS';

ALTER TABLE SolicitudesSOS
    ADD CONSTRAINT TiposEmergencia_SolicitudesSOS_fk
    FOREIGN KEY (id_tipo)
    REFERENCES TiposEmergencia (id_tipo)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE SolicitudesSOS
    ADD CONSTRAINT Dispositivos_SolicitudesSOS_fk
    FOREIGN KEY (id_dispositivo)
    REFERENCES Dispositivos (id_dispositivo)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE RegistrosComunicacion
    ADD CONSTRAINT Dispositivos_RegistrosComunicacion_fk
    FOREIGN KEY (id_dispositivo)
    REFERENCES Dispositivos (id_dispositivo)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE HistorialEstados
    ADD CONSTRAINT SolicitudesSOS_HistorialEstados_fk
    FOREIGN KEY (id_solicitud)
    REFERENCES SolicitudesSOS (id_solicitud)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE RegistrosComunicacion
    ADD CONSTRAINT SolicitudesSOS_RegistrosComunicacion_fk
    FOREIGN KEY (id_solicitud)
    REFERENCES SolicitudesSOS (id_solicitud)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE HistorialEstados
    ADD CONSTRAINT Usuarios_HistorialEstados_fk
    FOREIGN KEY (id_usuario)
    REFERENCES Usuarios (id_usuario)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
