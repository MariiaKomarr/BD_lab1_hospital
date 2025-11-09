--
-- PostgreSQL database dump
--

\restrict MmnVdAmRo6S6OCBVc7QA9OEsIdDPc8eu3H0vj3ZyrKsCchRFymvZrssSI4zZGbq

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: calc_invoice_total(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calc_invoice_total(p_invoice_id uuid) RETURNS numeric
    LANGUAGE sql
    AS $$
    SELECT COALESCE(SUM(ii.qty * ii.unit_price), 0.00)
    FROM "invoice_items" ii
    WHERE ii.invoice_id = p_invoice_id;
$$;


ALTER FUNCTION public.calc_invoice_total(p_invoice_id uuid) OWNER TO postgres;

--
-- Name: discharge_patient(uuid, uuid, timestamp with time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.discharge_patient(IN p_admission_id uuid, IN p_user_id uuid, IN p_discharged_at timestamp with time zone DEFAULT now())
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_bed_id uuid;
BEGIN
    UPDATE "admissions" a
    SET discharged_at = COALESCE(p_discharged_at, now()),
        status        = 'discharged',
        updated_at    = now(),
        updated_by    = p_user_id
    WHERE a.id = p_admission_id
    RETURNING a.bed_id INTO v_bed_id;

    IF v_bed_id IS NOT NULL THEN
        UPDATE "beds" b
        SET is_occupied = FALSE,
            updated_at  = now(),
            updated_by  = p_user_id
        WHERE b.id = v_bed_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.discharge_patient(IN p_admission_id uuid, IN p_user_id uuid, IN p_discharged_at timestamp with time zone) OWNER TO postgres;

--
-- Name: get_patient_balance(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_patient_balance(p_patient_id uuid) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_invoices numeric(12,2);
    v_payments numeric(12,2);
BEGIN
    SELECT COALESCE(SUM(ii.qty * ii.unit_price), 0)
    INTO v_invoices
    FROM "invoices" i
    JOIN "invoice_items" ii ON ii.invoice_id = i.id
    WHERE i.patient_id = p_patient_id;

    SELECT COALESCE(SUM(p.amount), 0)
    INTO v_payments
    FROM "payments" p
    WHERE p.patient_id = p_patient_id;

    RETURN v_invoices - v_payments;
END;
$$;


ALTER FUNCTION public.get_patient_balance(p_patient_id uuid) OWNER TO postgres;

--
-- Name: set_audit_fields(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_audit_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.created_at IS NULL THEN
            NEW.created_at := now();
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_at := now();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_audit_fields() OWNER TO postgres;

--
-- Name: soft_delete_patient(uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.soft_delete_patient(IN p_patient_id uuid, IN p_user_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Позначити пацієнта як видаленого
    UPDATE "patients" p
    SET deleted_at = now(),
        deleted_by = p_user_id
    WHERE p.id = p_patient_id
      AND p.deleted_at IS NULL;

    -- Відмінити майбутні візити
    UPDATE "appointments" a
    SET status     = 'cancelled',
        deleted_at = now(),
        deleted_by = p_user_id
    WHERE a.patient_id = p_patient_id
      AND a.deleted_at IS NULL
      AND a.starts_at > now();
END;
$$;


ALTER PROCEDURE public.soft_delete_patient(IN p_patient_id uuid, IN p_user_id uuid) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admissions (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    bed_id uuid,
    admitted_at timestamp with time zone NOT NULL,
    discharged_at timestamp with time zone,
    status text DEFAULT 'admitted'::text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid
);


ALTER TABLE public.admissions OWNER TO postgres;

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    status text DEFAULT 'scheduled'::text NOT NULL,
    note text,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: beds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.beds (
    id uuid NOT NULL,
    room_id uuid NOT NULL,
    bed_no text NOT NULL,
    is_occupied boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.beds OWNER TO postgres;

--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departments (
    id uuid NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: diagnoses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.diagnoses (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    admission_id uuid,
    code text NOT NULL,
    description text,
    diagnosed_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.diagnoses OWNER TO postgres;

--
-- Name: doctors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doctors (
    id uuid NOT NULL,
    user_id uuid,
    department_id uuid,
    license_no text NOT NULL,
    speciality text,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.doctors OWNER TO postgres;

--
-- Name: invoice_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_items (
    id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    item_type text NOT NULL,
    ref_id uuid,
    description text NOT NULL,
    qty numeric(12,2) DEFAULT 1 NOT NULL,
    unit_price numeric(12,2) NOT NULL
);


ALTER TABLE public.invoice_items OWNER TO postgres;

--
-- Name: invoices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoices (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid
);


ALTER TABLE public.invoices OWNER TO postgres;

--
-- Name: lab_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lab_orders (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    admission_id uuid,
    lab_test_id uuid NOT NULL,
    ordered_at timestamp with time zone NOT NULL,
    result text,
    price numeric(12,2) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.lab_orders OWNER TO postgres;

--
-- Name: lab_tests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lab_tests (
    id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    default_price numeric(12,2) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.lab_tests OWNER TO postgres;

--
-- Name: medications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medications (
    id uuid NOT NULL,
    name text NOT NULL,
    form text,
    strength text,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.medications OWNER TO postgres;

--
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    id uuid NOT NULL,
    mrn text NOT NULL,
    full_name text NOT NULL,
    birth_date date,
    phone text,
    address text,
    emergency_contact text,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- Name: COLUMN patients.mrn; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.patients.mrn IS 'medical record number';


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    paid_at timestamp with time zone NOT NULL,
    amount numeric(12,2) NOT NULL,
    method text NOT NULL
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: prescriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prescriptions (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    admission_id uuid,
    medication_id uuid NOT NULL,
    dose text,
    frequency text,
    days integer,
    start_at date,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.prescriptions OWNER TO postgres;

--
-- Name: procedures; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.procedures (
    id uuid NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    admission_id uuid,
    name text NOT NULL,
    cost numeric(12,2) NOT NULL,
    performed_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.procedures OWNER TO postgres;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: rooms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rooms (
    id uuid NOT NULL,
    department_id uuid,
    code text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.rooms OWNER TO postgres;

--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_roles (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL
);


ALTER TABLE public.user_roles OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    full_name text,
    created_at timestamp with time zone NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: COLUMN users.email; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.email IS 'unique among active';


--
-- Name: v_active_patients; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_active_patients AS
 SELECT id,
    mrn,
    full_name,
    birth_date,
    phone,
    address,
    emergency_contact
   FROM public.patients p
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_active_patients OWNER TO postgres;

--
-- Name: v_current_inpatients; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_current_inpatients AS
 SELECT a.id AS admission_id,
    p.id AS patient_id,
    p.full_name AS patient_name,
    a.admitted_at,
    a.status,
    b.id AS bed_id,
    b.bed_no,
    r.code AS room_code,
    d.name AS department_name
   FROM ((((public.admissions a
     JOIN public.patients p ON ((p.id = a.patient_id)))
     LEFT JOIN public.beds b ON ((b.id = a.bed_id)))
     LEFT JOIN public.rooms r ON ((r.id = b.room_id)))
     LEFT JOIN public.departments d ON ((d.id = r.department_id)))
  WHERE (a.status = 'admitted'::text);


ALTER VIEW public.v_current_inpatients OWNER TO postgres;

--
-- Name: v_doctor_schedule; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_doctor_schedule AS
 SELECT a.id AS appointment_id,
    a.starts_at,
    a.ends_at,
    a.status,
    d.id AS doctor_id,
    u.full_name AS doctor_name,
    dep.name AS department_name,
    p.full_name AS patient_name
   FROM ((((public.appointments a
     JOIN public.doctors d ON ((d.id = a.doctor_id)))
     LEFT JOIN public.users u ON ((u.id = d.user_id)))
     JOIN public.patients p ON ((p.id = a.patient_id)))
     LEFT JOIN public.departments dep ON ((dep.id = d.department_id)))
  WHERE (a.deleted_at IS NULL);


ALTER VIEW public.v_doctor_schedule OWNER TO postgres;

--
-- Data for Name: admissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admissions (id, patient_id, doctor_id, bed_id, admitted_at, discharged_at, status, created_at, created_by, updated_at, updated_by) FROM stdin;
4c6d3127-0a66-4f8c-ae58-4968606bfe06	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	925a2548-bf60-450e-a308-f89f484a9c37	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
c8e41ca4-9fb6-4391-9bcc-946869fc8662	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	a2688603-47b2-4c8e-a2c5-8878a8d925fe	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
8f8a3d89-cdb9-44ea-b1e6-e2b58667ad37	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	188247d6-c32f-4025-beb7-74625a757962	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
9225d202-da8d-4fa8-87c3-2ee10d0af68e	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	1d342059-d7c1-481a-92d9-700c62d389b5	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
b734bba6-1804-430c-a936-65cdfe122675	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	575b8982-7c17-42a2-a761-98ed0705aa06	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
76ae3e46-35a8-4d03-8140-f2de0c5bffa3	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	931ed8ce-44de-4c57-b2b7-783a193ad2d2	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
8b9d77f4-7b27-4f4d-9370-8a52e0a31ca7	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	087a40f8-d340-425a-ae4c-edbc9a14b9bd	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
10982e67-863f-4c78-a912-d4ebec79a95e	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	89a05107-f86b-487c-93c9-caf22392c17c	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
c4ec39bb-fa0a-48a5-bd15-f0e998605305	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	672512a2-cda0-4a4a-a04e-f9899b572161	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
fad54992-5bdd-4c60-bdd1-03d0b35dd381	c1628332-f3c6-44f4-beda-7a5f370ba25c	3d0c931c-5357-45e9-a047-11d7f54267ce	280af65a-fb65-466e-89b2-1d78121cbe3a	2025-11-09 23:24:06.369784+02	\N	admitted	2025-11-09 23:24:06.369784+02	\N	\N	\N
\.


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointments (id, patient_id, doctor_id, starts_at, ends_at, status, note, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
\.


--
-- Data for Name: beds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.beds (id, room_id, bed_no, is_occupied, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
925a2548-bf60-450e-a308-f89f484a9c37	819c3cb1-cc50-4d53-82f3-ff10cee58555	B1	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
a2688603-47b2-4c8e-a2c5-8878a8d925fe	0913cfb6-debc-4f42-92e6-c9a7db598199	B2	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
188247d6-c32f-4025-beb7-74625a757962	fed1d557-3239-445c-9b5e-039c68255f14	B3	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
1d342059-d7c1-481a-92d9-700c62d389b5	827a314b-564a-4071-9682-8492ba4c7243	B4	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
575b8982-7c17-42a2-a761-98ed0705aa06	bf549a46-ad28-4400-bc8b-4b4fa73ff7ba	B5	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
931ed8ce-44de-4c57-b2b7-783a193ad2d2	3ca46d72-5bbe-495b-9d55-c351cbe9f2a8	B6	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
087a40f8-d340-425a-ae4c-edbc9a14b9bd	4030e1b5-4370-4019-85d1-938b421b75b7	B7	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
89a05107-f86b-487c-93c9-caf22392c17c	6a60bb5d-3b74-43b2-9aa4-e1419037e2fa	B8	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
672512a2-cda0-4a4a-a04e-f9899b572161	5519b0dc-a2a4-4b1c-8a6c-17066567e29e	B9	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
280af65a-fb65-466e-89b2-1d78121cbe3a	ec8a9f7c-3656-4eac-bd07-5f4c23190e41	B10	f	2025-11-09 23:23:41.391361+02	\N	\N	\N	\N	\N
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.departments (id, name, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
ca5e7823-4d83-4d73-ad19-d8e5b0d47988	Cardiology	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
3c5a4cb1-b6c7-45c4-80e2-014643fc14f0	Neurology	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
c8a79a5f-fa97-48fe-9799-0fcc51a84076	Therapy	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
989e0ec2-9f40-4d0a-9fc1-dd9d4cf3db91	Surgery	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
38f760a4-9ec4-4d67-84a8-6d5907508f46	Pediatrics	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
1f7fe544-9234-4d1a-b775-da129ff21b38	Oncology	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
49af69a1-85f5-481d-a84f-08402a3deb69	Ophthalmology	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
c661be3f-19f9-4bd0-9f45-4837fdd82493	ENT	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
e6561e33-e020-4c00-b60b-292e315b18e2	Urology	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
6e72e61c-c105-45e8-9c26-4def8105bac3	Orthopedics	2025-11-09 23:23:09.612615+02	\N	\N	\N	\N	\N
\.


--
-- Data for Name: diagnoses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.diagnoses (id, patient_id, doctor_id, admission_id, code, description, diagnosed_at, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
\.


--
-- Data for Name: doctors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.doctors (id, user_id, department_id, license_no, speciality, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
3d0c931c-5357-45e9-a047-11d7f54267ce	6fe9d275-60f0-49b5-9415-7c2238a627f4	ca5e7823-4d83-4d73-ad19-d8e5b0d47988	L001	Cardiology Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
06beeb9a-66ba-4c38-b30e-2b4a5a3da668	6fe9d275-60f0-49b5-9415-7c2238a627f4	3c5a4cb1-b6c7-45c4-80e2-014643fc14f0	L002	Neurology Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
52019877-cd1c-47a2-8507-a96050222dd5	6fe9d275-60f0-49b5-9415-7c2238a627f4	c8a79a5f-fa97-48fe-9799-0fcc51a84076	L003	Therapy Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
ca0e7c60-0353-4cc2-a092-7f6226c66f5e	6fe9d275-60f0-49b5-9415-7c2238a627f4	989e0ec2-9f40-4d0a-9fc1-dd9d4cf3db91	L004	Surgery Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
71c1a85b-94ce-4fc9-bb67-a6345ab829b8	6fe9d275-60f0-49b5-9415-7c2238a627f4	38f760a4-9ec4-4d67-84a8-6d5907508f46	L005	Pediatrics Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
8a069d11-1323-42d7-b65f-76dcf2c1b1a6	6fe9d275-60f0-49b5-9415-7c2238a627f4	1f7fe544-9234-4d1a-b775-da129ff21b38	L006	Oncology Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
7a3c37f2-4d30-4a71-b600-635f900e2987	6fe9d275-60f0-49b5-9415-7c2238a627f4	49af69a1-85f5-481d-a84f-08402a3deb69	L007	Ophthalmology Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
82335a9f-86a5-4c4d-b5a0-8422faa80504	6fe9d275-60f0-49b5-9415-7c2238a627f4	c661be3f-19f9-4bd0-9f45-4837fdd82493	L008	ENT Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
06513873-f32c-4bb8-89d7-947757112dcf	6fe9d275-60f0-49b5-9415-7c2238a627f4	e6561e33-e020-4c00-b60b-292e315b18e2	L009	Urology Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
9d57bf2b-850a-4106-9852-1b6eba44f43f	6fe9d275-60f0-49b5-9415-7c2238a627f4	6e72e61c-c105-45e8-9c26-4def8105bac3	L0010	Orthopedics Specialist	2025-11-09 23:23:52.181688+02	\N	\N	\N	\N	\N
\.


--
-- Data for Name: invoice_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice_items (id, invoice_id, item_type, ref_id, description, qty, unit_price) FROM stdin;
3a079b30-f6b2-4f20-a822-0e3922bc048d	decdf1da-3b4b-4654-9aec-fcafc068e75d	procedure	\N	Medical Service	1.00	861.49
50a90106-eae9-4748-aca5-12cf0db2dc77	82e18ec8-e7d2-4630-84b2-e63413b2ecb1	procedure	\N	Lab Test	1.00	652.44
655b0f7b-7d46-48da-8be8-4f7d1c6d5584	ae1a812b-f8ec-460c-aef7-963a221f0af3	procedure	\N	Lab Test	1.00	748.50
56e29fba-377a-400d-8645-b2341576cb32	0fdd9188-78a6-4ffd-a4a8-148d78fe7d9a	lab	\N	Medical Service	1.00	585.14
f07bd83b-9fa7-4a0d-ab56-a79800f55228	74ed63b3-1e57-4849-b80f-d59419adb40b	procedure	\N	Lab Test	1.00	621.69
e9b034de-0873-418a-8b5e-113b8d300d77	f28a9009-099d-4968-af0f-99456930b460	lab	\N	Medical Service	1.00	448.82
ffc636c5-5c9c-4323-8335-01e46ba02c83	1c4496de-fe51-4d7a-a0af-a391bad3a691	procedure	\N	Lab Test	1.00	918.08
c7bac790-4c20-42b0-abee-fa4984cd5c4d	02a5b6dc-fbfb-4c32-8c1a-16df118fad39	procedure	\N	Medical Service	1.00	504.42
3f9fa5e8-b3bd-47b4-ba80-1d0dfdd5b8e6	8edbcf58-f7cf-4045-a3d2-bd071c8ff7f4	procedure	\N	Medical Service	1.00	321.58
3b09c4ac-8c9a-43e3-93aa-c24be467e55e	2c870419-b50d-427e-aca6-c47657aa1914	lab	\N	Medical Service	1.00	555.76
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoices (id, patient_id, issued_at, status, created_at, created_by, updated_at, updated_by) FROM stdin;
decdf1da-3b4b-4654-9aec-fcafc068e75d	c1628332-f3c6-44f4-beda-7a5f370ba25c	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
82e18ec8-e7d2-4630-84b2-e63413b2ecb1	f28f4a93-6ac3-4e24-9f8f-0af2e6824050	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
ae1a812b-f8ec-460c-aef7-963a221f0af3	b01bd372-2237-42fe-a1f6-1541cfe84811	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
0fdd9188-78a6-4ffd-a4a8-148d78fe7d9a	86f10bf4-2488-4c34-93d3-92e3af37f52f	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
74ed63b3-1e57-4849-b80f-d59419adb40b	32267c01-b33c-454a-a5d3-0fb0b8b3308c	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
f28a9009-099d-4968-af0f-99456930b460	c4005390-b2e5-4215-9978-fd278350f4cb	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
1c4496de-fe51-4d7a-a0af-a391bad3a691	1da0b1a0-d1bb-4e12-8150-5511bac22d99	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
02a5b6dc-fbfb-4c32-8c1a-16df118fad39	edffea00-4a97-4aba-9522-83f6cfa917f4	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
8edbcf58-f7cf-4045-a3d2-bd071c8ff7f4	2ee39c43-fbe3-4ec1-9449-e68db4fb91e7	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
2c870419-b50d-427e-aca6-c47657aa1914	18508a5b-4dd3-4ebb-9348-003b4b13b230	2025-11-09 23:24:16.894114+02	open	2025-11-09 23:24:16.894114+02	\N	\N	\N
\.


--
-- Data for Name: lab_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lab_orders (id, patient_id, doctor_id, admission_id, lab_test_id, ordered_at, result, price, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
\.


--
-- Data for Name: lab_tests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lab_tests (id, code, name, default_price, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
\.


--
-- Data for Name: medications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medications (id, name, form, strength, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patients (id, mrn, full_name, birth_date, phone, address, emergency_contact, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
c1628332-f3c6-44f4-beda-7a5f370ba25c	13	23	2002-12-10	32	13	23	2025-11-09 22:48:49.509471+02	\N	\N	\N	\N	\N
f28f4a93-6ac3-4e24-9f8f-0af2e6824050	MR101	Patient 1	1980-04-10	+380971111111	Kyiv	Contact 1	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
b01bd372-2237-42fe-a1f6-1541cfe84811	MR102	Patient 2	1980-07-19	+380971111112	Kyiv	Contact 2	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
86f10bf4-2488-4c34-93d3-92e3af37f52f	MR103	Patient 3	1980-10-27	+380971111113	Kyiv	Contact 3	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
32267c01-b33c-454a-a5d3-0fb0b8b3308c	MR104	Patient 4	1981-02-04	+380971111114	Kyiv	Contact 4	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
c4005390-b2e5-4215-9978-fd278350f4cb	MR105	Patient 5	1981-05-15	+380971111115	Kyiv	Contact 5	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
1da0b1a0-d1bb-4e12-8150-5511bac22d99	MR106	Patient 6	1981-08-23	+380971111116	Kyiv	Contact 6	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
edffea00-4a97-4aba-9522-83f6cfa917f4	MR107	Patient 7	1981-12-01	+380971111117	Kyiv	Contact 7	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
2ee39c43-fbe3-4ec1-9449-e68db4fb91e7	MR108	Patient 8	1982-03-11	+380971111118	Kyiv	Contact 8	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
18508a5b-4dd3-4ebb-9348-003b4b13b230	MR109	Patient 9	1982-06-19	+380971111119	Kyiv	Contact 9	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
f279f397-83c8-4117-8edf-0160d71cc483	MR110	Patient 10	1982-09-27	+380971111110	Kyiv	Contact 10	2025-11-09 23:23:59.676652+02	\N	\N	\N	\N	\N
951977eb-4431-4a1d-bb2e-d7f1900ca55e	My	My	2025-09-09	\N	\N	101	2025-11-09 23:37:27.835502+02	\N	\N	\N	\N	\N
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, patient_id, invoice_id, paid_at, amount, method) FROM stdin;
81354c7f-bd95-4bae-8a58-d5e94271e2f5	c1628332-f3c6-44f4-beda-7a5f370ba25c	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	197.18	card
c76e2db8-4f46-4015-a8e8-c6d75e782669	f28f4a93-6ac3-4e24-9f8f-0af2e6824050	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	453.15	card
ad189dd2-0492-4741-93dc-a2ce6efedb63	b01bd372-2237-42fe-a1f6-1541cfe84811	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	382.74	card
f3db566b-286a-4441-a34d-d0b0f1f68e57	86f10bf4-2488-4c34-93d3-92e3af37f52f	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	403.58	cash
e0372ed6-6385-4e6a-8559-433ad9ae9a19	32267c01-b33c-454a-a5d3-0fb0b8b3308c	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	470.95	card
80c97fa7-cfc9-4987-a5d9-2d9bdf2bef52	c4005390-b2e5-4215-9978-fd278350f4cb	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	150.58	card
a06e0a0c-228b-47de-8bd8-ea7de5c146dc	1da0b1a0-d1bb-4e12-8150-5511bac22d99	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	319.79	card
b9e4feac-aff1-4796-b270-c22899536c54	edffea00-4a97-4aba-9522-83f6cfa917f4	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	253.12	cash
77022d6e-75c6-4d99-aff9-3cb93befc4f5	2ee39c43-fbe3-4ec1-9449-e68db4fb91e7	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	136.54	card
0e521256-dbe1-4d16-90af-1ea461beec1b	18508a5b-4dd3-4ebb-9348-003b4b13b230	decdf1da-3b4b-4654-9aec-fcafc068e75d	2025-11-09 23:24:31.100321+02	380.58	cash
\.


--
-- Data for Name: prescriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prescriptions (id, patient_id, doctor_id, admission_id, medication_id, dose, frequency, days, start_at, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
\.


--
-- Data for Name: procedures; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.procedures (id, patient_id, doctor_id, admission_id, name, cost, performed_at, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, code, name) FROM stdin;
b02e6844-185f-4427-8c51-b468dd342b30	admin	Administrator
e54208d2-eb79-489f-a173-7c57310e599e	doctor	Doctor
129ce5cf-a8a9-402d-9a8d-d0fa880b7729	nurse	Nurse
1ef61bd0-6e45-409a-86da-1c5fd8cbb34d	labtech	Lab Technician
ff9153bf-204c-4de9-b2c4-9f5fb320b488	manager	Manager
5e531405-93a0-44fe-9359-eac4105fdafb	reception	Receptionist
9ff9f9f0-3bbb-4cf1-80c7-7e68c67ece3f	it	IT Support
641ee348-840b-4174-8c49-4ff359cb98e3	intern	Intern
b546df95-6cf5-467f-90bc-c1a759000572	finance	Finance
2884bf0b-7f85-47ec-954d-8cac51c382e0	patient	Patient
\.


--
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rooms (id, department_id, code, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
819c3cb1-cc50-4d53-82f3-ff10cee58555	ca5e7823-4d83-4d73-ad19-d8e5b0d47988	R1	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
0913cfb6-debc-4f42-92e6-c9a7db598199	3c5a4cb1-b6c7-45c4-80e2-014643fc14f0	R2	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
fed1d557-3239-445c-9b5e-039c68255f14	c8a79a5f-fa97-48fe-9799-0fcc51a84076	R3	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
827a314b-564a-4071-9682-8492ba4c7243	989e0ec2-9f40-4d0a-9fc1-dd9d4cf3db91	R4	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
bf549a46-ad28-4400-bc8b-4b4fa73ff7ba	38f760a4-9ec4-4d67-84a8-6d5907508f46	R5	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
3ca46d72-5bbe-495b-9d55-c351cbe9f2a8	1f7fe544-9234-4d1a-b775-da129ff21b38	R6	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
4030e1b5-4370-4019-85d1-938b421b75b7	49af69a1-85f5-481d-a84f-08402a3deb69	R7	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
6a60bb5d-3b74-43b2-9aa4-e1419037e2fa	c661be3f-19f9-4bd0-9f45-4837fdd82493	R8	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
5519b0dc-a2a4-4b1c-8a6c-17066567e29e	e6561e33-e020-4c00-b60b-292e315b18e2	R9	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
ec8a9f7c-3656-4eac-bd07-5f4c23190e41	6e72e61c-c105-45e8-9c26-4def8105bac3	R10	2025-11-09 23:23:35.112925+02	\N	\N	\N	\N	\N
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_roles (user_id, role_id) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, password_hash, full_name, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
91f7edd2-ed26-460b-a306-b1cc3c20bd95	admin@clinic.com	123	Admin User	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
837f9a91-dc1d-474a-8661-c21cb44efef8	doc1@clinic.com	123	Dr. Alice	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
a0178ea4-1142-4b2d-aeb2-9455a3257e8a	doc2@clinic.com	123	Dr. Bob	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
e3b4e06a-6fe4-40d8-948a-79ba2d5ce788	doc3@clinic.com	123	Dr. Carol	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
af5c4002-ec02-46fb-8bf3-4546f7c0ada2	nurse@clinic.com	123	Nurse John	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
af3dea56-fbad-4c9d-8153-1d25abd12d91	recept@clinic.com	123	Reception Ann	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
6fe9d275-60f0-49b5-9415-7c2238a627f4	tech@clinic.com	123	Lab Tech	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
17c7d5c5-0003-4cf3-9162-d7a59a8604bb	manager@clinic.com	123	Manager Joe	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
75c227a8-02da-4bc0-a74d-c744e052c6d5	it@clinic.com	123	IT Support	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
79fe6c74-540e-44fa-a51a-e7aeb48e6608	student@clinic.com	123	Intern Tom	2025-11-09 23:22:35.77271+02	\N	\N	\N	\N	\N
\.


--
-- Name: admissions admissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admissions
    ADD CONSTRAINT admissions_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: beds beds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.beds
    ADD CONSTRAINT beds_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: diagnoses diagnoses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diagnoses
    ADD CONSTRAINT diagnoses_pkey PRIMARY KEY (id);


--
-- Name: doctors doctors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_pkey PRIMARY KEY (id);


--
-- Name: invoice_items invoice_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: lab_orders lab_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_orders
    ADD CONSTRAINT lab_orders_pkey PRIMARY KEY (id);


--
-- Name: lab_tests lab_tests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_tests
    ADD CONSTRAINT lab_tests_pkey PRIMARY KEY (id);


--
-- Name: medications medications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medications
    ADD CONSTRAINT medications_pkey PRIMARY KEY (id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: prescriptions prescriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_pkey PRIMARY KEY (id);


--
-- Name: procedures procedures_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.procedures
    ADD CONSTRAINT procedures_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ix_appt_doctor_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_appt_doctor_time ON public.appointments USING btree (doctor_id, starts_at);


--
-- Name: ix_appt_patient_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_appt_patient_time ON public.appointments USING btree (patient_id, starts_at);


--
-- Name: ux_beds_room_bedno; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ux_beds_room_bedno ON public.beds USING btree (room_id, bed_no);


--
-- Name: ux_doctors_license; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ux_doctors_license ON public.doctors USING btree (license_no);


--
-- Name: ux_lab_tests_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ux_lab_tests_code ON public.lab_tests USING btree (code);


--
-- Name: ux_patients_mrn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ux_patients_mrn ON public.patients USING btree (mrn);


--
-- Name: ux_roles_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ux_roles_code ON public.roles USING btree (code);


--
-- Name: ux_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ux_users_email ON public.users USING btree (email);


--
-- Name: admissions trg_admissions_audit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_admissions_audit BEFORE INSERT OR UPDATE ON public.admissions FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();


--
-- Name: doctors trg_doctors_audit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_doctors_audit BEFORE INSERT OR UPDATE ON public.doctors FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();


--
-- Name: patients trg_patients_audit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_patients_audit BEFORE INSERT OR UPDATE ON public.patients FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();


--
-- Name: admissions admissions_bed_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admissions
    ADD CONSTRAINT admissions_bed_id_fkey FOREIGN KEY (bed_id) REFERENCES public.beds(id);


--
-- Name: admissions admissions_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admissions
    ADD CONSTRAINT admissions_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: admissions admissions_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admissions
    ADD CONSTRAINT admissions_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: appointments appointments_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: appointments appointments_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: beds beds_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.beds
    ADD CONSTRAINT beds_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id);


--
-- Name: diagnoses diagnoses_admission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diagnoses
    ADD CONSTRAINT diagnoses_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES public.admissions(id);


--
-- Name: diagnoses diagnoses_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diagnoses
    ADD CONSTRAINT diagnoses_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: diagnoses diagnoses_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.diagnoses
    ADD CONSTRAINT diagnoses_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: doctors doctors_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: doctors doctors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: invoice_items invoice_items_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: invoices invoices_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: lab_orders lab_orders_admission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_orders
    ADD CONSTRAINT lab_orders_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES public.admissions(id);


--
-- Name: lab_orders lab_orders_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_orders
    ADD CONSTRAINT lab_orders_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: lab_orders lab_orders_lab_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_orders
    ADD CONSTRAINT lab_orders_lab_test_id_fkey FOREIGN KEY (lab_test_id) REFERENCES public.lab_tests(id);


--
-- Name: lab_orders lab_orders_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_orders
    ADD CONSTRAINT lab_orders_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: payments payments_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: payments payments_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: prescriptions prescriptions_admission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES public.admissions(id);


--
-- Name: prescriptions prescriptions_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: prescriptions prescriptions_medication_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_medication_id_fkey FOREIGN KEY (medication_id) REFERENCES public.medications(id);


--
-- Name: prescriptions prescriptions_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: procedures procedures_admission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.procedures
    ADD CONSTRAINT procedures_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES public.admissions(id);


--
-- Name: procedures procedures_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.procedures
    ADD CONSTRAINT procedures_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: procedures procedures_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.procedures
    ADD CONSTRAINT procedures_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: rooms rooms_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict MmnVdAmRo6S6OCBVc7QA9OEsIdDPc8eu3H0vj3ZyrKsCchRFymvZrssSI4zZGbq

