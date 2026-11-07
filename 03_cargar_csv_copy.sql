-- Vipricon ltda - carga de datos con COPY desde los CSV de la carpeta data/ (las mismas tablas de data/vipricon_datos.xlsx).
-- Uso, desde la carpeta raíz del repositorio y sobre el esquema VACÍO creado con 01_vipricon_ddl_postgres.sql:
--     psql -d vipricon -v ON_ERROR_STOP=1 -f 03_cargar_csv_copy.sql
-- \copy lee los archivos en el cliente (psql); las rutas son relativas al directorio desde donde se ejecuta psql.
-- Todo va en una transacción: si un archivo falla, no queda ninguna tabla a medias.
-- Los CSV ya incluyen las correcciones de 04_correccion_datos.sql, así que este script reemplaza a 02 + 04.
-- El orden de los archivos (01..14) respeta las llaves foráneas: primero los padres y al final contract_audit.

\set ON_ERROR_STOP on
BEGIN;

-- contract_audit se carga desde su propio CSV: se apaga el trigger de auditoría mientras se carga contract,
-- de lo contrario cada contrato generaría una fila de auditoría adicional y quedarían duplicadas.
ALTER TABLE contract DISABLE TRIGGER contract_audit_trg;

\copy type_document (id, code, name) FROM 'data/01_type_document.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy customer (client_id, legal_name, contact_name, phone, email, address, status) FROM 'data/02_customer.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy nolvelty_type (id, description) FROM 'data/03_nolvelty_type.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy contract (contract_id, customer_client_id, contract_date, start_date, end_date) FROM 'data/04_contract.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy location (location_id, contract_contract_id, name, address, latitude, longitude) FROM 'data/05_location.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy employ (employ_id, first_name, last_name, birth_date, phone, email, address, hire_date, status, type_document_id, document_number, experience_years, specially) FROM 'data/06_employ.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy asig_service (assignment_id, status, observations, employ_employ_id, contract_contract_id, start_time, end_time, date, description) FROM 'data/07_asig_service.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy news_log (novelty_id, asig_service_assignment_id, nolvelty_type_id, created_at, detail) FROM 'data/08_news_log.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy attendance (id, asig_service_assignment_id, check_in_at, check_out_at, lateness_minutes, punctuality) FROM 'data/09_attendance.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy absence (id, employ_employ_id, kind, date_from, date_to, detail, status, created_at) FROM 'data/10_absence.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy app_user (id, username, password_hash, role, enabled, failed_attempts, locked_until, must_change_password, created_at) FROM 'data/11_app_user.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy refresh_token (id, user_id, token_hash, family_id, expires_at, revoked_at, replaced_by_id, created_at, ip, user_agent) FROM 'data/12_refresh_token.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy admin_invite (id, code_hash, note, created_by, created_at, expires_at, revoked_at, used_at, used_by) FROM 'data/13_admin_invite.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy contract_audit (audit_id, action, contract_id, old_data, new_data, changed_fields, changed_at, db_user, client_ip, app_name, app_username) FROM 'data/14_contract_audit.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

ALTER TABLE contract ENABLE TRIGGER contract_audit_trg;

-- Los ids vienen en los CSV: se ajustan las secuencias para que los INSERT nuevos sigan sin choques.
SELECT setval(pg_get_serial_sequence('type_document', 'id'), (SELECT max(id) FROM type_document));
SELECT setval(pg_get_serial_sequence('customer', 'client_id'), (SELECT max(client_id) FROM customer));
SELECT setval(pg_get_serial_sequence('nolvelty_type', 'id'), (SELECT max(id) FROM nolvelty_type));
SELECT setval(pg_get_serial_sequence('contract', 'contract_id'), (SELECT max(contract_id) FROM contract));
SELECT setval(pg_get_serial_sequence('employ', 'employ_id'), (SELECT max(employ_id) FROM employ));
SELECT setval(pg_get_serial_sequence('asig_service', 'assignment_id'), (SELECT max(assignment_id) FROM asig_service));
SELECT setval(pg_get_serial_sequence('attendance', 'id'), (SELECT max(id) FROM attendance));
SELECT setval(pg_get_serial_sequence('absence', 'id'), (SELECT max(id) FROM absence));
SELECT setval(pg_get_serial_sequence('app_user', 'id'), (SELECT max(id) FROM app_user));
SELECT setval(pg_get_serial_sequence('refresh_token', 'id'), (SELECT max(id) FROM refresh_token));
SELECT setval(pg_get_serial_sequence('admin_invite', 'id'), (SELECT max(id) FROM admin_invite));
SELECT setval(pg_get_serial_sequence('contract_audit', 'audit_id'), (SELECT max(audit_id) FROM contract_audit));
SELECT setval('location_id_seq', (SELECT max(location_id) FROM location));
SELECT setval('novelty_id_seq', (SELECT max(novelty_id) FROM news_log));

COMMIT;
