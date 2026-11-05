-- ============================================================================
-- Vipricon ltda - DDL de PostgreSQL (14 tablas, esquema final V1-V9)
-- Para DbVisualizer / pgAdmin / psql. Solo estructura: sin datos de ejemplo
-- (los datos estan en db/migration/V2__seed.sql) y sin flyway_schema_history.
--
-- Como usarlo:
--  * Base nueva y vacia: crearla (CREATE DATABASE vipricon_demo;), conectarse a ella
--    y ejecutar este archivo completo (DbVisualizer: SQL Commander > Run as Script, Alt+X).
--  * Ver el diagrama: en DbVisualizer conectarse a la base, abrir la carpeta de
--    tablas (public > TABLE), seleccionar todas, clic derecho > "Show Diagram"
--    (o la pestana "References" de cada tabla).
--  * NO ejecutarlo sobre la base del back (vipricon): ya tiene las tablas y Flyway
--    las gestiona con las migraciones V1-V9.
--
-- Generado con pg_dump --schema-only a partir de una base creada por las migraciones.
-- Incluye: tablas, claves, CHECK, restricciones EXCLUDE (R2 y absence), las funciones
-- y los triggers de V9 (auditoria de contratos y 3 triggers de bajo riesgo).
-- Requiere las extensiones btree_gist y unaccent (vienen con PostgreSQL / contrib).
-- ============================================================================

--
-- PostgreSQL database dump
--


-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: asig_service_active_employee_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.asig_service_active_employee_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.status = 1
       AND (TG_OP = 'INSERT'
            OR OLD.status IS DISTINCT FROM NEW.status
            OR OLD.employ_employ_id IS DISTINCT FROM NEW.employ_employ_id)
       AND EXISTS (SELECT 1 FROM employ e
                    WHERE e.employ_id = NEW.employ_employ_id AND e.status = 0) THEN
        RAISE EXCEPTION 'El vigilante % esta inactivo y no puede recibir una asignacion vigente', NEW.employ_employ_id
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: contract_audit_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_audit_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_old     jsonb;
    v_new     jsonb;
    v_changed text[];
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_old := to_jsonb(OLD);
        v_new := to_jsonb(NEW);
        IF v_old = v_new THEN
            RETURN NULL;            -- no cambio nada: no se audita
        END IF;
        SELECT array_agg(n.key ORDER BY n.key) INTO v_changed
          FROM jsonb_each(v_new) AS n
         WHERE v_old -> n.key IS DISTINCT FROM n.value;
    ELSE
        v_old := to_jsonb(OLD);
    END IF;

    INSERT INTO contract_audit (action, contract_id, old_data, new_data, changed_fields,
                                db_user, client_ip, app_name, app_username)
    VALUES (left(TG_OP, 1),
            COALESCE((v_new ->> 'contract_id')::integer, (v_old ->> 'contract_id')::integer),
            v_old, v_new, v_changed,
            session_user,
            inet_client_addr(),
            nullif(current_setting('application_name', true), ''),
            nullif(current_setting('app.current_user', true), ''));
    RETURN NULL;
END;
$$;


--
-- Name: contract_audit_readonly_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_audit_readonly_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'contract_audit es de solo agregar: no se permite %', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$;


--
-- Name: customer_normalize_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_normalize_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.legal_name   := btrim(NEW.legal_name);
    NEW.contact_name := btrim(NEW.contact_name);
    NEW.phone        := btrim(NEW.phone);
    NEW.email        := lower(btrim(NEW.email));
    NEW.address      := btrim(NEW.address);
    RETURN NEW;
END;
$$;


--
-- Name: employ_normalize_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.employ_normalize_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.first_name      := btrim(NEW.first_name);
    NEW.last_name       := btrim(NEW.last_name);
    NEW.phone           := btrim(NEW.phone);
    NEW.email           := lower(btrim(NEW.email));
    NEW.address         := btrim(NEW.address);
    NEW.document_number := btrim(NEW.document_number);
    NEW.specially       := btrim(NEW.specially);
    RETURN NEW;
END;
$$;


--
-- Name: no_physical_delete_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.no_physical_delete_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'No se puede borrar de %: se conserva el historial. Desactive el registro con status.', TG_TABLE_NAME
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: absence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.absence (
    id bigint NOT NULL,
    employ_employ_id bigint NOT NULL,
    kind character varying(12) NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    detail character varying(300),
    status smallint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT absence_dates_chk CHECK ((date_to >= date_from)),
    CONSTRAINT absence_kind_check CHECK (((kind)::text = ANY ((ARRAY['INCAPACIDAD'::character varying, 'PERMISO'::character varying, 'FALTA'::character varying])::text[]))),
    CONSTRAINT absence_status_check CHECK ((status = ANY (ARRAY[0, 1])))
);


--
-- Name: absence_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.absence ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.absence_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: admin_invite; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_invite (
    id bigint NOT NULL,
    code_hash character varying(64) NOT NULL,
    note character varying(100),
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    used_at timestamp with time zone,
    used_by bigint
);


--
-- Name: admin_invite_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.admin_invite ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.admin_invite_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: app_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user (
    id bigint NOT NULL,
    username character varying(50) NOT NULL,
    password_hash character varying(100) NOT NULL,
    role character varying(20) NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    failed_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    must_change_password boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT app_user_role_check CHECK (((role)::text = ANY ((ARRAY['ADMIN'::character varying, 'OPERATOR'::character varying])::text[])))
);


--
-- Name: app_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.app_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.app_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: asig_service; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asig_service (
    assignment_id bigint NOT NULL,
    status smallint NOT NULL,
    observations character varying(300),
    employ_employ_id bigint NOT NULL,
    contract_contract_id integer NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    date date NOT NULL,
    description character varying(150),
    CONSTRAINT asig_service_status_check CHECK ((status = ANY (ARRAY[0, 1]))),
    CONSTRAINT asig_service_time_chk CHECK ((end_time > start_time))
);


--
-- Name: asig_service_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.asig_service ALTER COLUMN assignment_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.asig_service_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: attendance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance (
    id bigint NOT NULL,
    asig_service_assignment_id bigint NOT NULL,
    check_in_at timestamp with time zone NOT NULL,
    check_out_at timestamp with time zone,
    lateness_minutes integer DEFAULT 0 NOT NULL,
    punctuality character varying(10) NOT NULL,
    CONSTRAINT attendance_lateness_minutes_check CHECK ((lateness_minutes >= 0)),
    CONSTRAINT attendance_out_after_in_chk CHECK (((check_out_at IS NULL) OR (check_out_at >= check_in_at))),
    CONSTRAINT attendance_punctuality_check CHECK (((punctuality)::text = ANY ((ARRAY['ON_TIME'::character varying, 'LATE'::character varying])::text[])))
);


--
-- Name: attendance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.attendance ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.attendance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contract; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract (
    contract_id integer NOT NULL,
    customer_client_id bigint NOT NULL,
    contract_date date NOT NULL,
    start_date date NOT NULL,
    end_date date,
    CONSTRAINT contract_dates_chk CHECK (((end_date IS NULL) OR (end_date >= start_date)))
);


--
-- Name: contract_audit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_audit (
    audit_id bigint NOT NULL,
    action character(1) NOT NULL,
    contract_id integer NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    db_user character varying(63) NOT NULL,
    client_ip inet,
    app_name character varying(100),
    app_username character varying(50),
    CONSTRAINT contract_audit_action_check CHECK ((action = ANY (ARRAY['I'::bpchar, 'U'::bpchar, 'D'::bpchar]))),
    CONSTRAINT contract_audit_data_chk CHECK ((((action = 'I'::bpchar) AND (old_data IS NULL) AND (new_data IS NOT NULL)) OR ((action = 'U'::bpchar) AND (old_data IS NOT NULL) AND (new_data IS NOT NULL)) OR ((action = 'D'::bpchar) AND (old_data IS NOT NULL) AND (new_data IS NULL))))
);


--
-- Name: contract_audit_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.contract_audit ALTER COLUMN audit_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contract_audit_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contract_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.contract ALTER COLUMN contract_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contract_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: customer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer (
    client_id bigint NOT NULL,
    legal_name character varying(100) NOT NULL,
    contact_name character varying(100) NOT NULL,
    phone character varying(15),
    email character varying(100),
    address character varying(150),
    status smallint NOT NULL,
    CONSTRAINT customer_status_check CHECK ((status = ANY (ARRAY[0, 1])))
);


--
-- Name: customer_client_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.customer ALTER COLUMN client_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.customer_client_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: employ; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employ (
    employ_id bigint NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    birth_date date,
    phone character varying(15),
    email character varying(100),
    address character varying(150),
    hire_date date NOT NULL,
    status smallint NOT NULL,
    type_document_id bigint NOT NULL,
    document_number character varying(20) NOT NULL,
    experience_years integer,
    specially character varying(20),
    CONSTRAINT employ_experience_years_check CHECK (((experience_years IS NULL) OR (experience_years >= 0))),
    CONSTRAINT employ_status_check CHECK ((status = ANY (ARRAY[0, 1])))
);


--
-- Name: employ_employ_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.employ ALTER COLUMN employ_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employ_employ_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: location_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: location; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.location (
    location_id integer DEFAULT nextval('public.location_id_seq'::regclass) NOT NULL,
    contract_contract_id integer NOT NULL,
    name character varying(80) NOT NULL,
    address character varying(150) NOT NULL,
    latitude numeric(9,6),
    longitude numeric(9,6),
    CONSTRAINT location_coordinates_chk CHECK ((((latitude IS NULL) AND (longitude IS NULL)) OR ((latitude IS NOT NULL) AND (longitude IS NOT NULL) AND ((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric)) AND ((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric)))))
);


--
-- Name: novelty_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.novelty_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_log (
    novelty_id bigint DEFAULT nextval('public.novelty_id_seq'::regclass) NOT NULL,
    asig_service_assignment_id bigint NOT NULL,
    nolvelty_type_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    detail character varying(300)
);


--
-- Name: nolvelty_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nolvelty_type (
    id integer NOT NULL,
    description character varying(150)
);


--
-- Name: nolvelty_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.nolvelty_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nolvelty_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: refresh_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_token (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_hash character varying(64) NOT NULL,
    family_id uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    replaced_by_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ip character varying(45),
    user_agent character varying(255)
);


--
-- Name: refresh_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.refresh_token ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.refresh_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: type_document; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.type_document (
    id bigint NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL
);


--
-- Name: type_document_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.type_document ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.type_document_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: absence absence_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence
    ADD CONSTRAINT absence_no_overlap EXCLUDE USING gist (employ_employ_id WITH =, daterange(date_from, date_to, '[]'::text) WITH &&) WHERE ((status = 1));


--
-- Name: absence absence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence
    ADD CONSTRAINT absence_pkey PRIMARY KEY (id);


--
-- Name: admin_invite admin_invite_code_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_invite
    ADD CONSTRAINT admin_invite_code_hash_key UNIQUE (code_hash);


--
-- Name: admin_invite admin_invite_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_invite
    ADD CONSTRAINT admin_invite_pkey PRIMARY KEY (id);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (id);


--
-- Name: app_user app_user_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_username_key UNIQUE (username);


--
-- Name: asig_service asig_service_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asig_service
    ADD CONSTRAINT asig_service_no_overlap EXCLUDE USING gist (employ_employ_id WITH =, tsrange((date + start_time), (date + end_time), '[)'::text) WITH &&) WHERE ((status = 1));


--
-- Name: asig_service asig_service_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asig_service
    ADD CONSTRAINT asig_service_pkey PRIMARY KEY (assignment_id);


--
-- Name: attendance attendance_asig_service_assignment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_asig_service_assignment_id_key UNIQUE (asig_service_assignment_id);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: contract_audit contract_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_audit
    ADD CONSTRAINT contract_audit_pkey PRIMARY KEY (audit_id);


--
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (contract_id);


--
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (client_id);


--
-- Name: employ employ_document_uq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employ
    ADD CONSTRAINT employ_document_uq UNIQUE (type_document_id, document_number);


--
-- Name: employ employ_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employ
    ADD CONSTRAINT employ_pkey PRIMARY KEY (employ_id);


--
-- Name: location location_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (location_id, contract_contract_id);


--
-- Name: news_log news_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_log
    ADD CONSTRAINT news_log_pkey PRIMARY KEY (novelty_id, asig_service_assignment_id);


--
-- Name: nolvelty_type nolvelty_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nolvelty_type
    ADD CONSTRAINT nolvelty_type_pkey PRIMARY KEY (id);


--
-- Name: refresh_token refresh_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_pkey PRIMARY KEY (id);


--
-- Name: refresh_token refresh_token_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_token_hash_key UNIQUE (token_hash);


--
-- Name: type_document type_document_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.type_document
    ADD CONSTRAINT type_document_code_key UNIQUE (code);


--
-- Name: type_document type_document_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.type_document
    ADD CONSTRAINT type_document_pkey PRIMARY KEY (id);


--
-- Name: absence_employ_dates_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX absence_employ_dates_idx ON public.absence USING btree (employ_employ_id, date_from, date_to);


--
-- Name: admin_invite_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_invite_created_idx ON public.admin_invite USING btree (created_at DESC);


--
-- Name: asig_service_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX asig_service_contract_idx ON public.asig_service USING btree (contract_contract_id);


--
-- Name: asig_service_employ_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX asig_service_employ_date_idx ON public.asig_service USING btree (employ_employ_id, date);


--
-- Name: contract_audit_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_audit_contract_idx ON public.contract_audit USING btree (contract_id, changed_at DESC);


--
-- Name: contract_customer_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_customer_idx ON public.contract USING btree (customer_client_id);


--
-- Name: location_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX location_contract_idx ON public.location USING btree (contract_contract_id);


--
-- Name: news_log_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX news_log_type_idx ON public.news_log USING btree (nolvelty_type_id);


--
-- Name: refresh_token_family_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX refresh_token_family_idx ON public.refresh_token USING btree (family_id);


--
-- Name: refresh_token_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX refresh_token_user_idx ON public.refresh_token USING btree (user_id);


--
-- Name: asig_service asig_service_active_employee_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER asig_service_active_employee_trg BEFORE INSERT OR UPDATE ON public.asig_service FOR EACH ROW EXECUTE FUNCTION public.asig_service_active_employee_fn();


--
-- Name: asig_service asig_service_no_delete_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER asig_service_no_delete_trg BEFORE DELETE ON public.asig_service FOR EACH ROW EXECUTE FUNCTION public.no_physical_delete_fn();


--
-- Name: contract_audit contract_audit_no_truncate_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER contract_audit_no_truncate_trg BEFORE TRUNCATE ON public.contract_audit FOR EACH STATEMENT EXECUTE FUNCTION public.contract_audit_readonly_fn();


--
-- Name: contract_audit contract_audit_readonly_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER contract_audit_readonly_trg BEFORE DELETE OR UPDATE ON public.contract_audit FOR EACH ROW EXECUTE FUNCTION public.contract_audit_readonly_fn();


--
-- Name: contract contract_audit_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER contract_audit_trg AFTER INSERT OR DELETE OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.contract_audit_fn();


--
-- Name: customer customer_normalize_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER customer_normalize_trg BEFORE INSERT OR UPDATE ON public.customer FOR EACH ROW EXECUTE FUNCTION public.customer_normalize_fn();


--
-- Name: employ employ_no_delete_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER employ_no_delete_trg BEFORE DELETE ON public.employ FOR EACH ROW EXECUTE FUNCTION public.no_physical_delete_fn();


--
-- Name: employ employ_normalize_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER employ_normalize_trg BEFORE INSERT OR UPDATE ON public.employ FOR EACH ROW EXECUTE FUNCTION public.employ_normalize_fn();


--
-- Name: absence absence_employ_employ_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence
    ADD CONSTRAINT absence_employ_employ_id_fkey FOREIGN KEY (employ_employ_id) REFERENCES public.employ(employ_id);


--
-- Name: admin_invite admin_invite_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_invite
    ADD CONSTRAINT admin_invite_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: admin_invite admin_invite_used_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_invite
    ADD CONSTRAINT admin_invite_used_by_fkey FOREIGN KEY (used_by) REFERENCES public.app_user(id);


--
-- Name: asig_service asig_service_contract_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asig_service
    ADD CONSTRAINT asig_service_contract_contract_id_fkey FOREIGN KEY (contract_contract_id) REFERENCES public.contract(contract_id);


--
-- Name: asig_service asig_service_employ_employ_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asig_service
    ADD CONSTRAINT asig_service_employ_employ_id_fkey FOREIGN KEY (employ_employ_id) REFERENCES public.employ(employ_id);


--
-- Name: attendance attendance_asig_service_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_asig_service_assignment_id_fkey FOREIGN KEY (asig_service_assignment_id) REFERENCES public.asig_service(assignment_id);


--
-- Name: contract contract_customer_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_customer_client_id_fkey FOREIGN KEY (customer_client_id) REFERENCES public.customer(client_id);


--
-- Name: employ employ_type_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employ
    ADD CONSTRAINT employ_type_document_id_fkey FOREIGN KEY (type_document_id) REFERENCES public.type_document(id);


--
-- Name: location location_contract_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_contract_contract_id_fkey FOREIGN KEY (contract_contract_id) REFERENCES public.contract(contract_id);


--
-- Name: news_log news_log_asig_service_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_log
    ADD CONSTRAINT news_log_asig_service_assignment_id_fkey FOREIGN KEY (asig_service_assignment_id) REFERENCES public.asig_service(assignment_id);


--
-- Name: news_log news_log_nolvelty_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_log
    ADD CONSTRAINT news_log_nolvelty_type_id_fkey FOREIGN KEY (nolvelty_type_id) REFERENCES public.nolvelty_type(id);


--
-- Name: refresh_token refresh_token_replaced_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_replaced_by_id_fkey FOREIGN KEY (replaced_by_id) REFERENCES public.refresh_token(id);


--
-- Name: refresh_token refresh_token_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- PostgreSQL database dump complete
--


