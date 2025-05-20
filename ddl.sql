CREATE TABLE especies (
  id SERIAL PRIMARY KEY,
  nombre_cientifico VARCHAR(255) UNIQUE NOT NULL,
  nombre_comun VARCHAR(255) UNIQUE NOT NULL,
  familia VARCHAR(100)
);

CREATE TABLE requerimientos_crecimiento (
  id SERIAL PRIMARY KEY,
  temp_min FLOAT NOT NULL,
  temp_max FLOAT NOT NULL,
  espacio_recomendado FLOAT NOT NULL,
  luminosidad_min FLOAT NOT NULL,
  luminosidad_max FLOAT NOT NULL,
  ph_sustrato_min FLOAT,
  ph_sustrato_max FLOAT,
  irrigacion_agua FLOAT NOT NULL,
  frecuencia_irrigacion FLOAT NOT NULL
);

CREATE TABLE tratamientos (
  id SERIAL PRIMARY KEY,
  nombre_producto VARCHAR(100) NOT NULL,
  instrucciones TEXT,
  unidad_medida VARCHAR(20) NOT NULL
);

CREATE TABLE plantas (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) UNIQUE NOT NULL,
  id_especie INT NOT NULL REFERENCES especies(id),
  id_req_crecimiento INT NOT NULL REFERENCES requerimientos_crecimiento(id),
  tipo_planta VARCHAR(50) NOT NULL CHECK (tipo_planta IN ('cultivo', 'decoracion', 'medicinal')),
  tipo_sustrato VARCHAR(50) NOT NULL 
);

CREATE TABLE huertos (
  id SERIAL PRIMARY KEY,
  area_total FLOAT NOT NULL,
  ubicacion VARCHAR(255) NOT NULL,
  luminosidad FLOAT NOT NULL,
  tipo_sustrato VARCHAR(50) NOT NULL,
  disponible BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE plantas_huerto (
  id SERIAL PRIMARY KEY,
  id_planta INT NOT NULL REFERENCES plantas(id),
  id_huerto INT NOT NULL REFERENCES huertos(id),
  fecha_plantacion DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_cosecha DATE
);

CREATE TABLE auditoria_huerto (
  id SERIAL PRIMARY KEY,
  id_planta_huerto INT NOT NULL REFERENCES plantas_huerto(id),
  altura_promedio FLOAT NOT NULL,
  fecha DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE tratamientos_huerto (
  id SERIAL PRIMARY KEY,
  id_auditoria_huerto INT NOT NULL REFERENCES auditoria_huerto(id),
  id_tratamiento INT NOT NULL REFERENCES tratamientos(id),
  cantidad FLOAT NOT NULL,
  hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
