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

-- ===========================
-- How to test the views/procedure
-- ===========================

-- 1. Test the view with CASE, COALESCE, etc.
-- Usage:
SELECT * FROM vista_estado_plantas;
-- Output: Each row shows planta_huerto_id, planta, ubicacion, altura_promedio (0 if NULL), estado_crecimiento ('Sin auditoría', 'Baja', 'Media', 'Alta'), estado ('En crecimiento' or 'Cosechada').

-- 2. Test the view with GROUP BY
-- Usage:
SELECT * FROM vista_promedio_altura_por_huerto;
-- Output: Each row shows huerto_id, ubicacion, promedio_altura (average height), plantas_auditadas (count of audited plants per huerto).

-- 3. Test the stored procedure for complex insert
-- Usage:
CALL insertar_planta_completa(
  'NuevaPlanta', 
  1,             
  1,             
  'cultivo',     
  'tierra negra',
  1,             
  '2024-03-01',  
  12.5           
);
-- Output: No direct output (unless you add RAISE NOTICE), but new rows will be added to plantas, plantas_huerto, and auditoria_huerto.
-- You can verify by running:
--   SELECT * FROM plantas WHERE nombre = 'NuevaPlanta';
--   SELECT * FROM plantas_huerto WHERE id_planta = (SELECT id FROM plantas WHERE nombre = 'NuevaPlanta');
--   SELECT * FROM auditoria_huerto WHERE id_planta_huerto = (SELECT id FROM plantas_huerto WHERE id_planta = (SELECT id FROM plantas WHERE nombre = 'NuevaPlanta'));
