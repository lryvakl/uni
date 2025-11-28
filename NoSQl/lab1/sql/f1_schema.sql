--
-- PostgreSQL database dump
--

\restrict cfMLcyNzeczMZot9ZgSuFahZJYMdd9vCFMOgx4Kwr5EcA3DgDfQDFq6G3nt0bxX

-- Dumped from database version 18.0 (Postgres.app)
-- Dumped by pg_dump version 18.0 (Postgres.app)

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
-- Name: f1; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA f1;


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA f1;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA f1;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: calc_points(integer); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.calc_points(p_position integer) RETURNS integer
    LANGUAGE sql
    AS $$
  SELECT CASE
    WHEN p_position = 1 THEN 25
    WHEN p_position = 2 THEN 18
    WHEN p_position = 3 THEN 15
    WHEN p_position = 4 THEN 12
    WHEN p_position = 5 THEN 10
    WHEN p_position = 6 THEN 8
    WHEN p_position = 7 THEN 6
    WHEN p_position = 8 THEN 4
    WHEN p_position = 9 THEN 2
    WHEN p_position = 10 THEN 1
    ELSE 0
  END;
$$;


--
-- Name: get_app_user(); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.get_app_user() RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN 1;
END;
$$;


--
-- Name: set_app_user(bigint); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.set_app_user(p_user_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
END$$;


--
-- Name: sp_cancel_order(bigint); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.sp_cancel_order(p_order_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE tickets t
  SET is_sold = FALSE
  FROM order_items oi
  WHERE oi.order_id = p_order_id AND oi.ticket_id = t.id;

  UPDATE orders
  SET status='REFUNDED'
  WHERE id=p_order_id;
END$$;


--
-- Name: sp_record_race_result(bigint, bigint, bigint, integer); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.sp_record_race_result(p_session_id bigint, p_driver_id bigint, p_constructor_id bigint, p_position integer) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'f1', 'public'
    AS $$
DECLARE v_season BIGINT;
BEGIN
  INSERT INTO f1.session_results(session_id, driver_id, constructor_id, position, points)
  VALUES(p_session_id, p_driver_id, p_constructor_id, p_position, f1.calc_points(p_position))
  ON CONFLICT (session_id, driver_id) DO UPDATE
    SET position = EXCLUDED.position,
        points = EXCLUDED.points;

  SELECT gp.season_id INTO v_season
  FROM f1.sessions ss
  JOIN f1.grand_prix gp ON ss.grand_prix_id = gp.id
  WHERE ss.id = p_session_id;

  INSERT INTO f1.standings_drivers(season_id, driver_id, points, wins)
  VALUES (v_season, p_driver_id, f1.calc_points(p_position), (p_position=1)::int)
  ON CONFLICT (season_id, driver_id) DO UPDATE
    SET points = standings_drivers.points + f1.calc_points(p_position),
        wins = standings_drivers.wins + (p_position=1)::int;
END$$;


--
-- Name: sp_sell_ticket(bigint, bigint); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.sp_sell_ticket(p_ticket_id bigint, p_user_id bigint) RETURNS bigint
    LANGUAGE plpgsql
    SET search_path TO 'f1', 'public'
    AS $$
DECLARE v_price NUMERIC; v_order_id BIGINT;
BEGIN
  SELECT pt.base_price INTO v_price
  FROM f1.tickets t 
  JOIN f1.price_tiers pt ON t.price_tier_id = pt.id
  WHERE t.id = p_ticket_id AND t.is_sold = FALSE
  FOR UPDATE;

  UPDATE f1.tickets
  SET is_sold = TRUE
  WHERE id = p_ticket_id;

  INSERT INTO f1.orders(user_id, status, total)
  VALUES(p_user_id, 'PAID', v_price)
  RETURNING id INTO v_order_id;

  INSERT INTO f1.order_items(order_id, ticket_id, price)
  VALUES(v_order_id, p_ticket_id, v_price);

  RETURN v_order_id;
END$$;


--
-- Name: trg_audit_generic(); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.trg_audit_generic() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO f1.audit_log(table_name, row_id, action, changed_by)
  VALUES (
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id)::text,
    TG_OP,
    f1.get_app_user()
  );
  RETURN NEW;
END;
$$;


--
-- Name: trg_soft_delete(); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.trg_soft_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.deleted_at := now();
  NEW.deleted_by := get_app_user();
  RETURN NEW;
END$$;


--
-- Name: trg_touch_row(); Type: FUNCTION; Schema: f1; Owner: -
--

CREATE FUNCTION f1.trg_touch_row() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'f1', 'public'
    AS $$
BEGIN
  NEW.updated_at := now();
  NEW.updated_by := get_app_user();
  RETURN NEW;
END$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.audit_log (
    id bigint NOT NULL,
    table_name text,
    row_id text,
    action text,
    changed_at timestamp with time zone DEFAULT now(),
    changed_by bigint
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.audit_log_id_seq OWNED BY f1.audit_log.id;


--
-- Name: constructors; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.constructors (
    id bigint NOT NULL,
    name text NOT NULL,
    country text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: constructors_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.constructors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: constructors_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.constructors_id_seq OWNED BY f1.constructors.id;


--
-- Name: drivers; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.drivers (
    id bigint NOT NULL,
    full_name text,
    nationality text,
    birthdate date,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: drivers_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.drivers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.drivers_id_seq OWNED BY f1.drivers.id;


--
-- Name: grand_prix; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.grand_prix (
    id bigint NOT NULL,
    season_id bigint,
    track_id bigint,
    name text,
    round_number integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: grand_prix_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.grand_prix_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grand_prix_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.grand_prix_id_seq OWNED BY f1.grand_prix.id;


--
-- Name: officials; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.officials (
    id bigint NOT NULL,
    full_name text,
    role text,
    nationality text,
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: officials_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.officials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: officials_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.officials_id_seq OWNED BY f1.officials.id;


--
-- Name: order_items; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.order_items (
    id bigint NOT NULL,
    order_id bigint,
    ticket_id bigint,
    price numeric
);


--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.order_items_id_seq OWNED BY f1.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.orders (
    id bigint NOT NULL,
    user_id bigint,
    status text DEFAULT 'PENDING'::text,
    total numeric DEFAULT 0,
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.orders_id_seq OWNED BY f1.orders.id;


--
-- Name: price_tiers; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.price_tiers (
    id bigint NOT NULL,
    track_id bigint,
    name text,
    base_price numeric,
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: price_tiers_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.price_tiers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: price_tiers_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.price_tiers_id_seq OWNED BY f1.price_tiers.id;


--
-- Name: roles; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.roles (
    id bigint NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.roles_id_seq OWNED BY f1.roles.id;


--
-- Name: seasons; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.seasons (
    id bigint NOT NULL,
    year integer NOT NULL,
    is_active boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: seasons_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.seasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seasons_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.seasons_id_seq OWNED BY f1.seasons.id;


--
-- Name: session_officials; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.session_officials (
    session_id bigint NOT NULL,
    official_id bigint NOT NULL,
    role text
);


--
-- Name: session_results; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.session_results (
    id bigint NOT NULL,
    session_id bigint,
    driver_id bigint,
    constructor_id bigint,
    "position" integer,
    points integer
);


--
-- Name: session_results_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.session_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: session_results_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.session_results_id_seq OWNED BY f1.session_results.id;


--
-- Name: sessions; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.sessions (
    id bigint NOT NULL,
    grand_prix_id bigint,
    session_type text,
    session_datetime timestamp with time zone,
    status text DEFAULT 'Scheduled'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.sessions_id_seq OWNED BY f1.sessions.id;


--
-- Name: standings_drivers; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.standings_drivers (
    id bigint NOT NULL,
    season_id bigint,
    driver_id bigint,
    points integer,
    wins integer
);


--
-- Name: standings_drivers_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.standings_drivers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: standings_drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.standings_drivers_id_seq OWNED BY f1.standings_drivers.id;


--
-- Name: standings_teams; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.standings_teams (
    id bigint NOT NULL,
    season_id bigint,
    constructor_id bigint,
    points integer,
    wins integer
);


--
-- Name: standings_teams_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.standings_teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: standings_teams_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.standings_teams_id_seq OWNED BY f1.standings_teams.id;


--
-- Name: tickets; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.tickets (
    id bigint NOT NULL,
    session_id bigint,
    section text,
    "row" text,
    seat text,
    price_tier_id bigint,
    is_sold boolean DEFAULT false,
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: tickets_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.tickets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.tickets_id_seq OWNED BY f1.tickets.id;


--
-- Name: tracks; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.tracks (
    id bigint NOT NULL,
    name text,
    country text,
    city text,
    length_km numeric,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: tracks_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.tracks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tracks_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.tracks_id_seq OWNED BY f1.tracks.id;


--
-- Name: user_roles; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.user_roles (
    user_id bigint NOT NULL,
    role_id bigint NOT NULL,
    assigned_at timestamp with time zone DEFAULT now()
);


--
-- Name: users; Type: TABLE; Schema: f1; Owner: -
--

CREATE TABLE f1.users (
    id bigint NOT NULL,
    email f1.citext NOT NULL,
    full_name text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: f1; Owner: -
--

CREATE SEQUENCE f1.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: f1; Owner: -
--

ALTER SEQUENCE f1.users_id_seq OWNED BY f1.users.id;


--
-- Name: v_audit_recent_changes; Type: VIEW; Schema: f1; Owner: -
--

CREATE VIEW f1.v_audit_recent_changes AS
 SELECT a.id,
    a.table_name,
    a.row_id,
    a.action,
    a.changed_at,
    u.full_name AS changed_by_name
   FROM (f1.audit_log a
     LEFT JOIN f1.users u ON ((u.id = a.changed_by)))
  ORDER BY a.changed_at DESC
 LIMIT 50;


--
-- Name: v_dashboard_summary; Type: VIEW; Schema: f1; Owner: -
--

CREATE VIEW f1.v_dashboard_summary AS
 SELECT gp.id AS grand_prix_id,
    gp.name AS grand_prix,
    s.year AS season_year,
    t.name AS track_name,
    t.country,
    (ss.session_datetime)::date AS session_date,
    ss.status,
    count(tk.id) AS total_tickets,
    count(tk.id) FILTER (WHERE tk.is_sold) AS sold_tickets,
    count(tk.id) FILTER (WHERE (tk.is_sold = false)) AS available_tickets,
    COALESCE(sum(oi.price), (0)::numeric) AS total_revenue
   FROM (((((f1.grand_prix gp
     JOIN f1.seasons s ON ((gp.season_id = s.id)))
     JOIN f1.tracks t ON ((gp.track_id = t.id)))
     JOIN f1.sessions ss ON ((ss.grand_prix_id = gp.id)))
     LEFT JOIN f1.tickets tk ON ((tk.session_id = ss.id)))
     LEFT JOIN f1.order_items oi ON ((oi.ticket_id = tk.id)))
  GROUP BY gp.id, gp.name, s.year, t.name, t.country, ss.session_datetime, ss.status
  ORDER BY s.year DESC, gp.id;


--
-- Name: v_driver_standings_full; Type: VIEW; Schema: f1; Owner: -
--

CREATE VIEW f1.v_driver_standings_full AS
 SELECT s.year,
    d.full_name,
    st.points,
    st.wins
   FROM ((f1.standings_drivers st
     JOIN f1.seasons s ON ((st.season_id = s.id)))
     JOIN f1.drivers d ON ((st.driver_id = d.id)));


--
-- Name: v_sessions_extended; Type: VIEW; Schema: f1; Owner: -
--

CREATE VIEW f1.v_sessions_extended AS
 SELECT ss.id,
    ss.session_type,
    ss.session_datetime,
    gp.name AS grand_prix,
    tr.name AS track,
    tr.country
   FROM ((f1.sessions ss
     JOIN f1.grand_prix gp ON ((ss.grand_prix_id = gp.id)))
     JOIN f1.tracks tr ON ((gp.track_id = tr.id)));


--
-- Name: v_ticket_sales; Type: VIEW; Schema: f1; Owner: -
--

CREATE VIEW f1.v_ticket_sales AS
 SELECT ss.session_type,
    tr.name AS track,
    count(t.id) FILTER (WHERE t.is_sold) AS sold,
    count(t.id) AS total
   FROM (((f1.tickets t
     JOIN f1.sessions ss ON ((t.session_id = ss.id)))
     JOIN f1.grand_prix gp ON ((ss.grand_prix_id = gp.id)))
     JOIN f1.tracks tr ON ((gp.track_id = tr.id)))
  GROUP BY ss.session_type, tr.name;


--
-- Name: audit_log id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.audit_log ALTER COLUMN id SET DEFAULT nextval('f1.audit_log_id_seq'::regclass);


--
-- Name: constructors id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.constructors ALTER COLUMN id SET DEFAULT nextval('f1.constructors_id_seq'::regclass);


--
-- Name: drivers id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.drivers ALTER COLUMN id SET DEFAULT nextval('f1.drivers_id_seq'::regclass);


--
-- Name: grand_prix id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.grand_prix ALTER COLUMN id SET DEFAULT nextval('f1.grand_prix_id_seq'::regclass);


--
-- Name: officials id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.officials ALTER COLUMN id SET DEFAULT nextval('f1.officials_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.order_items ALTER COLUMN id SET DEFAULT nextval('f1.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.orders ALTER COLUMN id SET DEFAULT nextval('f1.orders_id_seq'::regclass);


--
-- Name: price_tiers id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.price_tiers ALTER COLUMN id SET DEFAULT nextval('f1.price_tiers_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.roles ALTER COLUMN id SET DEFAULT nextval('f1.roles_id_seq'::regclass);


--
-- Name: seasons id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.seasons ALTER COLUMN id SET DEFAULT nextval('f1.seasons_id_seq'::regclass);


--
-- Name: session_results id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_results ALTER COLUMN id SET DEFAULT nextval('f1.session_results_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.sessions ALTER COLUMN id SET DEFAULT nextval('f1.sessions_id_seq'::regclass);


--
-- Name: standings_drivers id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_drivers ALTER COLUMN id SET DEFAULT nextval('f1.standings_drivers_id_seq'::regclass);


--
-- Name: standings_teams id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_teams ALTER COLUMN id SET DEFAULT nextval('f1.standings_teams_id_seq'::regclass);


--
-- Name: tickets id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.tickets ALTER COLUMN id SET DEFAULT nextval('f1.tickets_id_seq'::regclass);


--
-- Name: tracks id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.tracks ALTER COLUMN id SET DEFAULT nextval('f1.tracks_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.users ALTER COLUMN id SET DEFAULT nextval('f1.users_id_seq'::regclass);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: constructors constructors_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.constructors
    ADD CONSTRAINT constructors_pkey PRIMARY KEY (id);


--
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (id);


--
-- Name: grand_prix grand_prix_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.grand_prix
    ADD CONSTRAINT grand_prix_pkey PRIMARY KEY (id);


--
-- Name: officials officials_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.officials
    ADD CONSTRAINT officials_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_ticket_id_key; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.order_items
    ADD CONSTRAINT order_items_ticket_id_key UNIQUE (ticket_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: price_tiers price_tiers_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.price_tiers
    ADD CONSTRAINT price_tiers_pkey PRIMARY KEY (id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: seasons seasons_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.seasons
    ADD CONSTRAINT seasons_pkey PRIMARY KEY (id);


--
-- Name: seasons seasons_year_key; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.seasons
    ADD CONSTRAINT seasons_year_key UNIQUE (year);


--
-- Name: session_officials session_officials_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_officials
    ADD CONSTRAINT session_officials_pkey PRIMARY KEY (session_id, official_id);


--
-- Name: session_results session_results_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_results
    ADD CONSTRAINT session_results_pkey PRIMARY KEY (id);


--
-- Name: session_results session_results_session_id_driver_id_key; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_results
    ADD CONSTRAINT session_results_session_id_driver_id_key UNIQUE (session_id, driver_id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: standings_drivers standings_drivers_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_drivers
    ADD CONSTRAINT standings_drivers_pkey PRIMARY KEY (id);


--
-- Name: standings_drivers standings_drivers_season_id_driver_id_key; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_drivers
    ADD CONSTRAINT standings_drivers_season_id_driver_id_key UNIQUE (season_id, driver_id);


--
-- Name: standings_teams standings_teams_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_teams
    ADD CONSTRAINT standings_teams_pkey PRIMARY KEY (id);


--
-- Name: standings_teams standings_teams_season_id_constructor_id_key; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_teams
    ADD CONSTRAINT standings_teams_season_id_constructor_id_key UNIQUE (season_id, constructor_id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: tracks tracks_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.tracks
    ADD CONSTRAINT tracks_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_sessions_grand_prix_id; Type: INDEX; Schema: f1; Owner: -
--

CREATE INDEX idx_sessions_grand_prix_id ON f1.sessions USING btree (grand_prix_id);


--
-- Name: idx_tickets_available; Type: INDEX; Schema: f1; Owner: -
--

CREATE INDEX idx_tickets_available ON f1.tickets USING btree (session_id) WHERE (is_sold = false);


--
-- Name: idx_tracks_name_trgm; Type: INDEX; Schema: f1; Owner: -
--

CREATE INDEX idx_tracks_name_trgm ON f1.tracks USING gin (name f1.gin_trgm_ops);


--
-- Name: orders trg_audit_orders; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_audit_orders AFTER INSERT OR DELETE OR UPDATE ON f1.orders FOR EACH ROW EXECUTE FUNCTION f1.trg_audit_generic();


--
-- Name: sessions trg_audit_sessions; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_audit_sessions AFTER INSERT OR DELETE OR UPDATE ON f1.sessions FOR EACH ROW EXECUTE FUNCTION f1.trg_audit_generic();


--
-- Name: users trg_audit_users; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_audit_users AFTER INSERT OR DELETE OR UPDATE ON f1.users FOR EACH ROW EXECUTE FUNCTION f1.trg_audit_generic();


--
-- Name: drivers trg_soft_delete_drivers; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_soft_delete_drivers BEFORE DELETE ON f1.drivers FOR EACH ROW EXECUTE FUNCTION f1.trg_soft_delete();


--
-- Name: tickets trg_soft_delete_tickets; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_soft_delete_tickets BEFORE DELETE ON f1.tickets FOR EACH ROW EXECUTE FUNCTION f1.trg_soft_delete();


--
-- Name: users trg_soft_delete_users; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_soft_delete_users BEFORE DELETE ON f1.users FOR EACH ROW EXECUTE FUNCTION f1.trg_soft_delete();


--
-- Name: constructors trg_touch_constructors; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_constructors BEFORE UPDATE ON f1.constructors FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: drivers trg_touch_drivers; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_drivers BEFORE UPDATE ON f1.drivers FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: grand_prix trg_touch_grand_prix; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_grand_prix BEFORE UPDATE ON f1.grand_prix FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: officials trg_touch_officials; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_officials BEFORE UPDATE ON f1.officials FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: orders trg_touch_orders; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_orders BEFORE UPDATE ON f1.orders FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: price_tiers trg_touch_price_tiers; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_price_tiers BEFORE UPDATE ON f1.price_tiers FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: roles trg_touch_roles; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_roles BEFORE UPDATE ON f1.roles FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: seasons trg_touch_seasons; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_seasons BEFORE UPDATE ON f1.seasons FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: sessions trg_touch_sessions; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_sessions BEFORE UPDATE ON f1.sessions FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: tickets trg_touch_tickets; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_tickets BEFORE UPDATE ON f1.tickets FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: tracks trg_touch_tracks; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_tracks BEFORE UPDATE ON f1.tracks FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: users trg_touch_users; Type: TRIGGER; Schema: f1; Owner: -
--

CREATE TRIGGER trg_touch_users BEFORE UPDATE ON f1.users FOR EACH ROW EXECUTE FUNCTION f1.trg_touch_row();


--
-- Name: grand_prix grand_prix_season_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.grand_prix
    ADD CONSTRAINT grand_prix_season_id_fkey FOREIGN KEY (season_id) REFERENCES f1.seasons(id);


--
-- Name: grand_prix grand_prix_track_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.grand_prix
    ADD CONSTRAINT grand_prix_track_id_fkey FOREIGN KEY (track_id) REFERENCES f1.tracks(id);


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES f1.orders(id);


--
-- Name: order_items order_items_ticket_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.order_items
    ADD CONSTRAINT order_items_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES f1.tickets(id);


--
-- Name: orders orders_user_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.orders
    ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES f1.users(id);


--
-- Name: price_tiers price_tiers_track_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.price_tiers
    ADD CONSTRAINT price_tiers_track_id_fkey FOREIGN KEY (track_id) REFERENCES f1.tracks(id);


--
-- Name: session_officials session_officials_official_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_officials
    ADD CONSTRAINT session_officials_official_id_fkey FOREIGN KEY (official_id) REFERENCES f1.officials(id);


--
-- Name: session_officials session_officials_session_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_officials
    ADD CONSTRAINT session_officials_session_id_fkey FOREIGN KEY (session_id) REFERENCES f1.sessions(id);


--
-- Name: session_results session_results_constructor_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_results
    ADD CONSTRAINT session_results_constructor_id_fkey FOREIGN KEY (constructor_id) REFERENCES f1.constructors(id);


--
-- Name: session_results session_results_driver_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_results
    ADD CONSTRAINT session_results_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES f1.drivers(id);


--
-- Name: session_results session_results_session_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.session_results
    ADD CONSTRAINT session_results_session_id_fkey FOREIGN KEY (session_id) REFERENCES f1.sessions(id);


--
-- Name: sessions sessions_grand_prix_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.sessions
    ADD CONSTRAINT sessions_grand_prix_id_fkey FOREIGN KEY (grand_prix_id) REFERENCES f1.grand_prix(id);


--
-- Name: standings_drivers standings_drivers_driver_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_drivers
    ADD CONSTRAINT standings_drivers_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES f1.drivers(id);


--
-- Name: standings_drivers standings_drivers_season_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_drivers
    ADD CONSTRAINT standings_drivers_season_id_fkey FOREIGN KEY (season_id) REFERENCES f1.seasons(id);


--
-- Name: standings_teams standings_teams_constructor_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_teams
    ADD CONSTRAINT standings_teams_constructor_id_fkey FOREIGN KEY (constructor_id) REFERENCES f1.constructors(id);


--
-- Name: standings_teams standings_teams_season_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.standings_teams
    ADD CONSTRAINT standings_teams_season_id_fkey FOREIGN KEY (season_id) REFERENCES f1.seasons(id);


--
-- Name: tickets tickets_price_tier_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.tickets
    ADD CONSTRAINT tickets_price_tier_id_fkey FOREIGN KEY (price_tier_id) REFERENCES f1.price_tiers(id);


--
-- Name: tickets tickets_session_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.tickets
    ADD CONSTRAINT tickets_session_id_fkey FOREIGN KEY (session_id) REFERENCES f1.sessions(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES f1.roles(id);


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: f1; Owner: -
--

ALTER TABLE ONLY f1.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES f1.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict cfMLcyNzeczMZot9ZgSuFahZJYMdd9vCFMOgx4Kwr5EcA3DgDfQDFq6G3nt0bxX


CREATE TABLE IF NOT EXISTS lap_times (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL, 
    driver_id BIGINT NOT NULL, 
    lap_number INT NOT NULL,
    sector_1 NUMERIC(6,3),
    sector_2 NUMERIC(6,3),
    sector_3 NUMERIC(6,3),
    tyre_compound TEXT
);

CREATE INDEX IF NOT EXISTS idx_lap_times_search ON lap_times(session_id, driver_id);