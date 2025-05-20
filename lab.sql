
--***************************************************************************************************
-- FUNCIONES

-- Funcion que retorna un escalar
-- Devuelve el stock de una planta determinada en todos los huertos

CREATE OR REPLACE FUNCTION contar_stock_planta(p_id_planta INT)
RETURNS INT AS $$
DECLARE
  total INT;
BEGIN
  SELECT COUNT(*) INTO total
  FROM plantas_huerto
  WHERE id_planta = p_id_planta;

  RETURN total;
END;
$$ LANGUAGE plpgsql;

-- Llamar a la función
SELECT contar_stock_planta(1);

-- Funcion que retorna un conjunto de resultados
-- Devuelve las auditorías de una planta en un huerto

CREATE OR REPLACE FUNCTION obtener_auditorias_planta(p_id_planta_huerto INT)
RETURNS TABLE (
  fecha DATE,
  altura_promedio FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT ah.fecha, ah.altura_promedio
  FROM auditoria_huerto as ah
  WHERE ah.id_planta_huerto = p_id_planta_huerto
  ORDER BY ah.fecha;
END;
$$ LANGUAGE plpgsql;

-- Llamar a la función 
SELECT * FROM obtener_auditorias_planta(3);

-- Una que utilice múltiples parámetros o lógica condicional
-- Funcion para un reporte, obtiene las plantas tratadas en un día específico
-- y que no han sido cosechadas

CREATE OR REPLACE FUNCTION obtener_plantas_tratadas_no_cosechadas(
  p_id_tratamiento INT,
  p_fecha DATE
)
RETURNS TABLE (
  id_plantacion INT,
  nombre_planta VARCHAR,
  fecha_tratamiento TIMESTAMP,
  ubicacion_huerto VARCHAR
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ph.id,
    p.nombre,
    th.hora,
    h.ubicacion
  FROM tratamientos_huerto th
  JOIN auditoria_huerto ah ON th.id_auditoria_huerto = ah.id
  JOIN plantas_huerto ph ON ah.id_planta_huerto = ph.id
  JOIN plantas p ON ph.id_planta = p.id
  JOIN huertos h ON ph.id_huerto = h.id
  WHERE th.id_tratamiento = p_id_tratamiento
    AND DATE(th.hora) = p_fecha
    AND ph.fecha_cosecha IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Llamar a la función
SELECT * FROM obtener_plantas_tratadas_no_cosechadas(3, '2025-01-12');


--***************************************************************************************************
-- VISTAS 

-- View 1: Usa CASE, COALESCE y LEFT JOIN
CREATE OR REPLACE VIEW vista_estado_plantas AS
SELECT
  ph.id AS planta_huerto_id,
  p.nombre AS planta,
  h.ubicacion,
  COALESCE(ah.altura_promedio, 0) AS altura_promedio,
  CASE
    WHEN ah.altura_promedio IS NULL THEN 'Sin auditoría'
    WHEN ah.altura_promedio < 10 THEN 'Baja'
    WHEN ah.altura_promedio BETWEEN 10 AND 13 THEN 'Media'
    ELSE 'Alta'
  END AS estado_crecimiento,
  CASE
    WHEN ph.fecha_cosecha IS NULL THEN 'En crecimiento'
    ELSE 'Cosechada'
  END AS estado
FROM plantas_huerto ph
JOIN plantas p ON ph.id_planta = p.id
JOIN huertos h ON ph.id_huerto = h.id
LEFT JOIN auditoria_huerto ah ON ah.id_planta_huerto = ph.id;

-- View 2: Usa GROUP BY
CREATE OR REPLACE VIEW vista_promedio_altura_por_huerto AS
SELECT
  h.id AS huerto_id,
  h.ubicacion,
  AVG(ah.altura_promedio) AS promedio_altura,
  COUNT(DISTINCT ph.id) AS plantas_auditadas
FROM huertos h
JOIN plantas_huerto ph ON ph.id_huerto = h.id
JOIN auditoria_huerto ah ON ah.id_planta_huerto = ph.id
GROUP BY h.id, h.ubicacion;


-- View 3: Usa JOINs
CREATE OR REPLACE VIEW vista_detalle_plantas_huerto AS
SELECT
  ph.id AS id_plantacion,
  p.nombre AS nombre_planta,
  e.nombre_cientifico,
  e.nombre_comun,
  r.espacio_recomendado,
  h.ubicacion,
  h.luminosidad,
  ph.fecha_plantacion,
  ph.fecha_cosecha
FROM plantas_huerto ph
JOIN plantas p ON ph.id_planta = p.id
JOIN especies e ON p.id_especie = e.id
JOIN requerimientos_crecimiento r ON p.id_req_crecimiento = r.id
JOIN huertos h ON ph.id_huerto = h.id;


-- View 4: Vista simple
CREATE OR REPLACE VIEW vista_tratamientos_disponibles AS
SELECT
  id,
  nombre_producto,
  instrucciones,
  unidad_medida
FROM tratamientos;


-- 1. Vista con  CASE, COALESCE, etc.
SELECT * FROM vista_estado_plantas;
-- Salida deberia ser: filas con los atributos planta_huerto_id, planta, ubicacion, altura_promedio (0 if NULL), estado_crecimiento ('Sin auditoría', 'Baja', 'Media', 'Alta'), estado ('En crecimiento' or 'Cosechada').

-- 2. Vista con GROUP BY

SELECT * FROM vista_promedio_altura_por_huerto;
-- Salida deberia ser: filas con los atributos huerto_id, ubicacion, promedio_altura (average height), plantas_auditadas (count of audited plants per huerto).


-- 3. Vista con JOINs
SELECT * FROM vista_detalle_plantas_huerto;
-- Salida deberia ser: filas con los atributos id_plantacion, nombre_planta, nombre_cientifico, nombre_comun, espacio_recomendado, ubicacion, luminosidad, fecha_plantacion, fecha_cosecha.


-- 4. Vista simple
SELECT * FROM vista_tratamientos_disponibles;
-- Salida deberia ser: filas con los atributos id, nombre_producto, instrucciones, unidad_medida.


--***************************************************************************************************
-- STORED PROCEDURES

-- procedimiento para insertar una planta completa
CREATE OR REPLACE PROCEDURE insertar_planta_completa(
  nombre_planta VARCHAR,
  id_especie INT,
  id_req_crecimiento INT,
  tipo_planta VARCHAR,
  tipo_sustrato VARCHAR,
  id_huerto INT,
  fecha_plantacion DATE,
  altura_promedio FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
  nueva_planta_id INT;
  nueva_ph_id INT;
BEGIN
  -- Insertar en plantas
  INSERT INTO plantas (nombre, id_especie, id_req_crecimiento, tipo_planta, tipo_sustrato)
  VALUES (nombre_planta, id_especie, id_req_crecimiento, tipo_planta, tipo_sustrato)
  RETURNING id INTO nueva_planta_id;

  -- Insertar en plantas_huerto
  INSERT INTO plantas_huerto (id_planta, id_huerto, fecha_plantacion)
  VALUES (nueva_planta_id, id_huerto, fecha_plantacion)
  RETURNING id INTO nueva_ph_id;

  -- Insertar en auditoria_huerto
  INSERT INTO auditoria_huerto (id_planta_huerto, altura_promedio, fecha)
  VALUES (nueva_ph_id, altura_promedio, CURRENT_DATE);
END;
$$;

-- llamar al stored procedure
CALL insertar_planta_completa(
  'NuevaPlanta', 
  1,             
  1,             
  'cultivo',     
  'tierra negra',
  1,             
  '2025-03-01',  
  12.5           
);

-- stored procedure para actualizar la altura promedio de una planta
CREATE OR REPLACE PROCEDURE actualizar_altura_promedio(
    p_id_planta_huerto INT,
    p_nueva_altura FLOAT,
    p_fecha DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica si ya hay un registro para esa fecha
    IF EXISTS (
        SELECT 1 FROM auditoria_huerto
        WHERE id_planta_huerto = p_id_planta_huerto AND fecha = p_fecha
    ) THEN
        -- Si ya existe, actualiza
        UPDATE auditoria_huerto
        SET altura_promedio = p_nueva_altura
        WHERE id_planta_huerto = p_id_planta_huerto AND fecha = p_fecha;
    ELSE
        -- Si no existe, inserta uno nuevo
        INSERT INTO auditoria_huerto(id_planta_huerto, altura_promedio, fecha)
        VALUES (p_id_planta_huerto, p_nueva_altura, p_fecha);
    END IF;
END;
$$;

-- llamar al stored procedure

CALL actualizar_altura_promedio(5, 23.5);



--***************************************************************************************************
-- TRIGGERS 

-- trigger antes de realizar una plantacion, revisar que el 
-- huerto tenga espacio 

-- before insert

CREATE OR REPLACE FUNCTION check_huerto_space()
RETURNS TRIGGER AS $$
DECLARE
   disponibilidad boolean;
BEGIN
    SELECT disponible INTO disponibilidad FROM huertos WHERE id = NEW.id_huerto;
    IF NOT disponibilidad THEN
      RAISE EXCEPTION 'El huerto no tiene espacio disponible.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER before_insert_plantas_huerto
BEFORE INSERT ON plantas_huerto
FOR EACH ROW
EXECUTE FUNCTION check_huerto_space();






-- trigger para actualizar el estado del huerto a disponible
-- otra vez si ya hay una fecha de cosecha en la tabla PlantasHuerto
CREATE OR REPLACE FUNCTION update_disponibilidad_huerto()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_cosecha IS NOT NULL THEN
        UPDATE huertos SET disponible = TRUE WHERE id = NEW.id_huerto;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER after_update_plantas_huerto
AFTER UPDATE ON plantas_huerto
FOR EACH ROW
EXECUTE FUNCTION update_disponibilidad_huerto();





-- trigger antes de plantar, revisar que el huerto 
-- donde se desea hacer tiene luminosidad adecuada para la planta
CREATE OR REPLACE FUNCTION check_huerto_brightness()
RETURNS TRIGGER AS $$
DECLARE
   luminosidad_h float;
   luminosidad_min_p float;
   luminosidad_max_p float;
BEGIN
    SELECT luminosidad INTO luminosidad_h FROM huertos WHERE id = NEW.id_huerto;

    SELECT r.luminosidad_min, r.luminosidad_max
    INTO luminosidad_min_p, luminosidad_max_p
    FROM plantas p
    JOIN requerimientos_crecimiento r ON r.id = p.id_req_crecimiento
    WHERE p.id = NEW.id_planta;

    IF luminosidad_h < luminosidad_min_p OR luminosidad_h > luminosidad_max_p THEN
        RAISE EXCEPTION 'La luminosidad del huerto (%.2f) no es adecuada para esta planta (%.2f - %.2f).', luminosidad_h, luminosidad_min_p, luminosidad_max_p;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER before_insert_check_brightness
BEFORE INSERT ON plantas_huerto
FOR EACH ROW
EXECUTE FUNCTION check_huerto_brightness();




