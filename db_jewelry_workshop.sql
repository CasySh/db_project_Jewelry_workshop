--
-- PostgreSQL database dump
--

\restrict 0wOql8E7F5chvhsUYSfnuSaUBbns7CM0xTyF9q4H9hKyxKWS69ib8vDFSCKjm3t

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

-- Started on 2026-05-24 15:21:24

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
-- TOC entry 233 (class 1255 OID 16771)
-- Name: add_product_attribute(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_product_attribute(p_attr_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN

    IF EXISTS (SELECT 1 FROM product_extra_attrs WHERE attr_name = p_attr_name) THEN
        RETURN 'Предупреждение: атрибут "' || p_attr_name || '" уже существует';
    END IF;
    
    RETURN 'Атрибут "' || p_attr_name || '" готов';
END;
$$;


ALTER FUNCTION public.add_product_attribute(p_attr_name text) OWNER TO postgres;

--
-- TOC entry 232 (class 1255 OID 16745)
-- Name: check_sale_price(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_sale_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    full_price NUMERIC;
    customer_discount INTEGER;
    expected_price NUMERIC;
BEGIN

    SELECT product_price INTO full_price
    FROM products
    WHERE product_id = NEW.product_id;
    
    SELECT discount INTO customer_discount
    FROM customers
    WHERE customer_id = NEW.customer_id;
    
    expected_price := full_price * (1 - customer_discount / 100.0);
    
    IF NEW.final_price <> expected_price THEN
        RAISE EXCEPTION 'Ошибка: цена со скидкой должна быть %, а не %', expected_price, NEW.final_price;
    END IF;    
    RETURN NEW;

END;


$$;


ALTER FUNCTION public.check_sale_price() OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 16750)
-- Name: delete_customer_with_sales(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_customer_with_sales(IN p_customer_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_customer_exists BOOLEAN;
    v_sales_count INTEGER;
BEGIN

    SELECT EXISTS(
        SELECT 1 FROM customers WHERE customer_id = p_customer_id
    ) INTO v_customer_exists;
    
    IF NOT v_customer_exists THEN
        RAISE EXCEPTION 'Клиент с ID % не найден', p_customer_id;
    END IF;
    
    SELECT COUNT(*) INTO v_sales_count
    FROM sales
    WHERE customer_id = p_customer_id;

    DELETE FROM sales
    WHERE customer_id = p_customer_id;
    
    RAISE NOTICE 'Удалено % продаж(а) клиента с ID %', v_sales_count, p_customer_id;
    
    DELETE FROM customers
    WHERE customer_id = p_customer_id;
    
    RAISE NOTICE 'Клиент с ID % успешно удалён', p_customer_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка при удалении клиента %: %', p_customer_id, SQLERRM;
        RAISE;
END;
$$;


ALTER PROCEDURE public.delete_customer_with_sales(IN p_customer_id integer) OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 16749)
-- Name: increase_discount_for_loyal_customers(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.increase_discount_for_loyal_customers()
    LANGUAGE plpgsql
    AS $$
DECLARE

    cur_customers CURSOR FOR
        SELECT customer_id, last_name, first_name, discount
        FROM customers
        WHERE is_permanent = TRUE AND discount < 15
        FOR UPDATE;
    
    v_customer_id INTEGER;
    v_last_name TEXT;
    v_first_name TEXT;
    v_discount INTEGER;
    v_purchase_count BIGINT;
    v_new_discount INTEGER;
    
BEGIN

    OPEN cur_customers;
    
    LOOP
        FETCH cur_customers INTO v_customer_id, v_last_name, v_first_name, v_discount;
        
        EXIT WHEN NOT FOUND;
        
        SELECT COUNT(*) INTO v_purchase_count
        FROM sales
        WHERE customer_id = v_customer_id;
        
        IF v_purchase_count > 2 THEN
            v_new_discount := v_discount + 5;
            
            RAISE NOTICE 'Клиенту % % (скидка была %) повышаем скидку до % (покупок: %)', v_first_name, v_last_name, v_discount, v_new_discount, v_purchase_count;
            
            UPDATE customers 
            SET discount = v_new_discount
            WHERE CURRENT OF cur_customers;
        ELSE
            RAISE NOTICE 'Клиент % % (скидка %) — пропускаем, покупок: % (нужно >2)', v_first_name, v_last_name, v_discount, v_purchase_count;
        END IF;
        
    END LOOP;
    
    CLOSE cur_customers;
    
    RAISE NOTICE 'Процедура завершена.';
    
END;
$$;


ALTER PROCEDURE public.increase_discount_for_loyal_customers() OWNER TO postgres;

--
-- TOC entry 234 (class 1255 OID 16772)
-- Name: set_product_attribute(integer, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_product_attribute(p_product_id integer, p_attr_name text, p_attr_value text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_product_exists BOOLEAN;
BEGIN

    SELECT EXISTS(SELECT 1 FROM products WHERE product_id = p_product_id) 
    INTO v_product_exists;
    
    IF NOT v_product_exists THEN
        RETURN 'Ошибка: изделие с ID ' || p_product_id || ' не найдено';
    END IF;
    
    INSERT INTO product_extra_attrs (product_id, attr_name, attr_value)
    VALUES (p_product_id, p_attr_name, p_attr_value)
    ON CONFLICT (product_id, attr_name) 
    DO UPDATE SET attr_value = EXCLUDED.attr_value;
    
    RETURN 'Атрибут "' || p_attr_name || '" = "' || p_attr_value || '" добавлен изделию ' || p_product_id;
END;
$$;


ALTER FUNCTION public.set_product_attribute(p_product_id integer, p_attr_name text, p_attr_value text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 225 (class 1259 OID 16680)
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    customer_id integer NOT NULL,
    last_name text NOT NULL,
    first_name text NOT NULL,
    middle_name text,
    is_permanent boolean DEFAULT false NOT NULL,
    discount integer NOT NULL,
    CONSTRAINT customers_discount_check CHECK (((discount >= 0) AND (discount <= 100)))
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16696)
-- Name: sales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sales (
    sale_id integer NOT NULL,
    product_id integer NOT NULL,
    customer_id integer NOT NULL,
    sale_date date NOT NULL,
    final_price numeric NOT NULL,
    CONSTRAINT sales_final_price_check CHECK ((final_price >= (0)::numeric)),
    CONSTRAINT sales_sale_date_check CHECK ((sale_date <= CURRENT_DATE))
);


ALTER TABLE public.sales OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16779)
-- Name: customer_rating_analytics; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.customer_rating_analytics AS
 WITH customer_totals AS (
         SELECT c.customer_id,
            c.last_name,
            c.first_name,
            c.is_permanent,
            c.discount,
            COALESCE(round(sum(s.final_price), 2), (0)::numeric) AS total_spent,
            count(s.sale_id) AS purchase_count
           FROM (public.customers c
             LEFT JOIN public.sales s ON ((c.customer_id = s.customer_id)))
          GROUP BY c.customer_id, c.last_name, c.first_name, c.is_permanent, c.discount
        ), ranked AS (
         SELECT customer_totals.customer_id,
            customer_totals.last_name,
            customer_totals.first_name,
            customer_totals.is_permanent,
            customer_totals.discount,
            customer_totals.total_spent,
            customer_totals.purchase_count,
            rank() OVER (ORDER BY customer_totals.total_spent DESC) AS rating,
            lead(customer_totals.total_spent) OVER (ORDER BY customer_totals.total_spent DESC) AS next_total
           FROM customer_totals
        )
 SELECT customer_id,
    last_name,
    first_name,
    is_permanent,
    discount,
    purchase_count,
    total_spent,
    rating,
        CASE
            WHEN (next_total IS NULL) THEN (0)::numeric
            ELSE (total_spent - next_total)
        END AS lead_to_next
   FROM ranked
  ORDER BY rating;


ALTER VIEW public.customer_rating_analytics OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16786)
-- Name: customer_rating_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customer_rating_table (
    customer_id integer,
    last_name text,
    first_name text,
    is_permanent boolean,
    discount integer,
    purchase_count bigint,
    total_spent numeric,
    rating bigint,
    lead_to_next numeric
);


ALTER TABLE public.customer_rating_table OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16679)
-- Name: customers_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_customer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_customer_id_seq OWNER TO postgres;

--
-- TOC entry 5091 (class 0 OID 0)
-- Dependencies: 224
-- Name: customers_customer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customers_customer_id_seq OWNED BY public.customers.customer_id;


--
-- TOC entry 222 (class 1259 OID 16646)
-- Name: materials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.materials (
    material_id integer NOT NULL,
    material_name text NOT NULL,
    material_price numeric NOT NULL,
    CONSTRAINT materials_material_price_check CHECK ((material_price > (0)::numeric))
);


ALTER TABLE public.materials OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16645)
-- Name: materials_material_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.materials_material_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.materials_material_id_seq OWNER TO postgres;

--
-- TOC entry 5092 (class 0 OID 0)
-- Dependencies: 221
-- Name: materials_material_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.materials_material_id_seq OWNED BY public.materials.material_id;


--
-- TOC entry 229 (class 1259 OID 16752)
-- Name: product_extra_attrs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_extra_attrs (
    attr_id integer NOT NULL,
    product_id integer NOT NULL,
    attr_name text NOT NULL,
    attr_value text NOT NULL
);


ALTER TABLE public.product_extra_attrs OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16751)
-- Name: product_extra_attrs_attr_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_extra_attrs_attr_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_extra_attrs_attr_id_seq OWNER TO postgres;

--
-- TOC entry 5093 (class 0 OID 0)
-- Dependencies: 228
-- Name: product_extra_attrs_attr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_extra_attrs_attr_id_seq OWNED BY public.product_extra_attrs.attr_id;


--
-- TOC entry 223 (class 1259 OID 16658)
-- Name: product_materials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_materials (
    product_id integer NOT NULL,
    material_id integer NOT NULL,
    grams numeric NOT NULL,
    CONSTRAINT product_materials_grams_check CHECK ((grams > (0)::numeric))
);


ALTER TABLE public.product_materials OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16631)
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    product_id integer NOT NULL,
    product_name text NOT NULL,
    product_type text NOT NULL,
    product_price numeric NOT NULL,
    CONSTRAINT products_product_price_check CHECK ((product_price > (0)::numeric)),
    CONSTRAINT products_product_type_check CHECK ((product_type = ANY (ARRAY['серьги'::text, 'кольца'::text, 'броши'::text, 'браслеты'::text])))
);


ALTER TABLE public.products OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16630)
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_product_id_seq OWNER TO postgres;

--
-- TOC entry 5094 (class 0 OID 0)
-- Dependencies: 219
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_product_id_seq OWNED BY public.products.product_id;


--
-- TOC entry 226 (class 1259 OID 16695)
-- Name: sales_sale_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sales_sale_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sales_sale_id_seq OWNER TO postgres;

--
-- TOC entry 5095 (class 0 OID 0)
-- Dependencies: 226
-- Name: sales_sale_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sales_sale_id_seq OWNED BY public.sales.sale_id;


--
-- TOC entry 4895 (class 2604 OID 16683)
-- Name: customers customer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers ALTER COLUMN customer_id SET DEFAULT nextval('public.customers_customer_id_seq'::regclass);


--
-- TOC entry 4894 (class 2604 OID 16649)
-- Name: materials material_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materials ALTER COLUMN material_id SET DEFAULT nextval('public.materials_material_id_seq'::regclass);


--
-- TOC entry 4898 (class 2604 OID 16755)
-- Name: product_extra_attrs attr_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_extra_attrs ALTER COLUMN attr_id SET DEFAULT nextval('public.product_extra_attrs_attr_id_seq'::regclass);


--
-- TOC entry 4893 (class 2604 OID 16634)
-- Name: products product_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products ALTER COLUMN product_id SET DEFAULT nextval('public.products_product_id_seq'::regclass);


--
-- TOC entry 4897 (class 2604 OID 16699)
-- Name: sales sale_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales ALTER COLUMN sale_id SET DEFAULT nextval('public.sales_sale_id_seq'::regclass);


--
-- TOC entry 5085 (class 0 OID 16786)
-- Dependencies: 231
-- Data for Name: customer_rating_table; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customer_rating_table (customer_id, last_name, first_name, is_permanent, discount, purchase_count, total_spent, rating, lead_to_next) FROM stdin;
2	Петрова	Екатерина	t	15	2	92930.50	1	20858.50
3	Сидоров	Алексей	f	0	1	72072.00	2	20358.00
4	Козлова	Мария	t	10	1	51714.00	3	14274.00
5	Смирнов	Дмитрий	f	0	1	37440.00	4	2974.40
6	Федорова	Анна	t	20	1	34465.60	5	0
\.


--
-- TOC entry 5080 (class 0 OID 16680)
-- Dependencies: 225
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (customer_id, last_name, first_name, middle_name, is_permanent, discount) FROM stdin;
2	Петрова	Екатерина	Алексеевна	t	15
3	Сидоров	Алексей	Владимирович	f	0
4	Козлова	Мария	Дмитриевна	t	10
5	Смирнов	Дмитрий	Николаевич	f	0
6	Федорова	Анна	Сергеевна	t	20
\.


--
-- TOC entry 5077 (class 0 OID 16646)
-- Dependencies: 222
-- Data for Name: materials; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.materials (material_id, material_name, material_price) FROM stdin;
1	Платина 950	6500.00
2	Золото 585	4500.00
3	Золото 750	5200.00
4	Серебро 925	120.00
5	Бриллиант 1кл	35000.00
6	Рубин	15000.00
7	Сапфир	12000.00
8	Изумруд	18000.00
\.


--
-- TOC entry 5084 (class 0 OID 16752)
-- Dependencies: 229
-- Data for Name: product_extra_attrs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.product_extra_attrs (attr_id, product_id, attr_name, attr_value) FROM stdin;
3	1	размер_кольца	17.5
4	2	тип_застежки	английская
\.


--
-- TOC entry 5078 (class 0 OID 16658)
-- Dependencies: 223
-- Data for Name: product_materials; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.product_materials (product_id, material_id, grams) FROM stdin;
1	2	3.5
1	5	0.5
2	1	4.2
2	5	0.8
3	4	12.0
3	6	1.2
3	7	1.5
3	8	1.0
4	3	8.5
5	2	2.8
5	8	0.9
6	3	3.2
6	6	1.1
\.


--
-- TOC entry 5075 (class 0 OID 16631)
-- Dependencies: 220
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (product_id, product_name, product_type, product_price) FROM stdin;
1	Кольцо "Классика"	кольца	43225.0000
2	Серьги "Ангелина"	серьги	71890.0000
3	Брошь "Павлин"	броши	72072.0000
4	Браслет "Золотая нить"	браслеты	57460.0000
5	Кольцо "Изумрудная роса"	кольца	37440.0000
6	Серьги "Алые паруса"	серьги	43082.0000
\.


--
-- TOC entry 5082 (class 0 OID 16696)
-- Dependencies: 227
-- Data for Name: sales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sales (sale_id, product_id, customer_id, sale_date, final_price) FROM stdin;
2	2	2	2025-05-10	61106.500000000000000000000000
3	3	3	2025-05-15	72072.000000000000000000000000
4	4	4	2025-05-20	51714.000000000000000000000000
5	5	5	2025-05-25	37440.000000000000000000000000
6	6	6	2025-06-01	34465.600000000000000000000000
8	5	2	2025-06-10	31824.000000000000000000000000
\.


--
-- TOC entry 5096 (class 0 OID 0)
-- Dependencies: 224
-- Name: customers_customer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_customer_id_seq', 6, true);


--
-- TOC entry 5097 (class 0 OID 0)
-- Dependencies: 221
-- Name: materials_material_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.materials_material_id_seq', 8, true);


--
-- TOC entry 5098 (class 0 OID 0)
-- Dependencies: 228
-- Name: product_extra_attrs_attr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.product_extra_attrs_attr_id_seq', 4, true);


--
-- TOC entry 5099 (class 0 OID 0)
-- Dependencies: 219
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_product_id_seq', 6, true);


--
-- TOC entry 5100 (class 0 OID 0)
-- Dependencies: 226
-- Name: sales_sale_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sales_sale_id_seq', 11, true);


--
-- TOC entry 4913 (class 2606 OID 16694)
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);


--
-- TOC entry 4909 (class 2606 OID 16657)
-- Name: materials materials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materials
    ADD CONSTRAINT materials_pkey PRIMARY KEY (material_id);


--
-- TOC entry 4917 (class 2606 OID 16763)
-- Name: product_extra_attrs product_extra_attrs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_extra_attrs
    ADD CONSTRAINT product_extra_attrs_pkey PRIMARY KEY (attr_id);


--
-- TOC entry 4919 (class 2606 OID 16765)
-- Name: product_extra_attrs product_extra_attrs_product_id_attr_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_extra_attrs
    ADD CONSTRAINT product_extra_attrs_product_id_attr_name_key UNIQUE (product_id, attr_name);


--
-- TOC entry 4911 (class 2606 OID 16668)
-- Name: product_materials product_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_materials
    ADD CONSTRAINT product_materials_pkey PRIMARY KEY (product_id, material_id);


--
-- TOC entry 4907 (class 2606 OID 16644)
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- TOC entry 4915 (class 2606 OID 16710)
-- Name: sales sales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_pkey PRIMARY KEY (sale_id);


--
-- TOC entry 4925 (class 2620 OID 16746)
-- Name: sales tr_check_sale_price; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_check_sale_price BEFORE INSERT ON public.sales FOR EACH ROW EXECUTE FUNCTION public.check_sale_price();


--
-- TOC entry 4924 (class 2606 OID 16766)
-- Name: product_extra_attrs product_extra_attrs_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_extra_attrs
    ADD CONSTRAINT product_extra_attrs_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id) ON DELETE CASCADE;


--
-- TOC entry 4920 (class 2606 OID 16674)
-- Name: product_materials product_materials_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_materials
    ADD CONSTRAINT product_materials_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(material_id);


--
-- TOC entry 4921 (class 2606 OID 16669)
-- Name: product_materials product_materials_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_materials
    ADD CONSTRAINT product_materials_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- TOC entry 4922 (class 2606 OID 16716)
-- Name: sales sales_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id);


--
-- TOC entry 4923 (class 2606 OID 16711)
-- Name: sales sales_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


-- Completed on 2026-05-24 15:21:24

--
-- PostgreSQL database dump complete
--

\unrestrict 0wOql8E7F5chvhsUYSfnuSaUBbns7CM0xTyF9q4H9hKyxKWS69ib8vDFSCKjm3t

