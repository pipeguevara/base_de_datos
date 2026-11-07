-- Vipricon ltda - correcciones de datos tras la revisión crítica del primer lote (02_poblar_vipricon.sql).
-- Hallazgos (consultas de comprobación en el informe, Anexo 1, E4):
--   C1. 16 filas de refresh_token creadas ANTES que su propio usuario (usuarios 8 y 87).
--   C2. 2 vigilantes (15 y 27) con más años de experiencia que años transcurridos desde que cumplieron 18.
-- Es idempotente: cada UPDATE solo actúa si el dato todavía está mal, así que puede ejecutarse más de una vez.
-- Se aplica DESPUÉS de 02_poblar_vipricon.sql. Los CSV de data/ ya incluyen estas correcciones.

BEGIN;

-- C1a. Usuario 87 (OPERATOR): su primer token es del 2026-10-08; pasa a existir desde el 2026-10-07.
UPDATE app_user
   SET created_at = TIMESTAMPTZ '2026-10-07 09:00:00-05'
 WHERE id = 87
   AND created_at > TIMESTAMPTZ '2026-10-07 09:00:00-05';

-- C1b. Usuario 8 (ADMIN): nace al canjear la invitación 5 y su primer token es del 2026-10-03.
--      La invitación se genera el 2026-09-30, se canjea el 2026-10-01 y vence 7 días después de generarse.
UPDATE admin_invite
   SET created_at = TIMESTAMPTZ '2026-09-30 10:15:00-05',
       expires_at = TIMESTAMPTZ '2026-10-07 10:15:00-05',
       used_at    = TIMESTAMPTZ '2026-10-01 09:00:00-05'
 WHERE id = 5
   AND used_by = 8;

UPDATE app_user
   SET created_at = TIMESTAMPTZ '2026-10-01 09:00:00-05'
 WHERE id = 8
   AND created_at > TIMESTAMPTZ '2026-10-01 09:00:00-05';

-- C2. Experiencia máxima posible = edad al 2026-11-04 menos 18 años.
UPDATE employ SET experience_years = 11 WHERE employ_id = 15 AND experience_years > 11;
UPDATE employ SET experience_years = 10 WHERE employ_id = 27 AND experience_years > 10;

COMMIT;
