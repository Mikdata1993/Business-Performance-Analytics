-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Verifica della struttura delle tabelle
-- Estrazione dei nomi delle colonne e dei relativi tipi
-- di dato delle tabelle presenti nel dataset.
-- L'obiettivo è verificare lo schema effettivo delle fonti
-- prima di progettare le viste per il modello Power BI.
-- =====================================================
SELECT
    table_name,
    column_name,
    data_type,
    ordinal_position
FROM
    `business-performance-analytics.olist_analytics.INFORMATION_SCHEMA.COLUMNS`
WHERE
    table_name IN (
        'orders',
        'order_items',
        'customers',
        'products',
        'category_translation',
        'orders_reviews'
    )
ORDER BY
    table_name,
    ordinal_position;

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Creazione vista delle righe d'ordine
-- Integrazione delle informazioni relative a ordini,
-- articoli, prodotti e categorie.
-- L'obiettivo è creare una vista al livello di dettaglio
-- della singola riga d'ordine per le analisi commerciali.
-- =====================================================

CREATE OR REPLACE VIEW
    `business-performance-analytics.olist_analytics.vw_fact_order_items`
AS

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,

    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    p.product_category_name AS categoria_originale,

    COALESCE(
        ct.string_field_1,
        p.product_category_name,
        'Non classificato'
    ) AS categoria_inglese,

    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    oi.shipping_limit_date,
    oi.price,
    oi.freight_value

FROM
    `business-performance-analytics.olist_analytics.order_items` oi

INNER JOIN
    `business-performance-analytics.olist_analytics.orders` o
    ON oi.order_id = o.order_id

LEFT JOIN
    `business-performance-analytics.olist_analytics.products` p
    ON oi.product_id = p.product_id

LEFT JOIN
    `business-performance-analytics.olist_analytics.category_translation` ct
    ON p.product_category_name = ct.string_field_0;

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Verifica della vista delle righe d'ordine
-- Controllo del numero di righe e dell'unicità delle chiavi.
-- L'obiettivo è verificare che le JOIN non abbiano
-- alterato il livello di dettaglio della tabella originale.
-- =====================================================

SELECT
    COUNT(*) AS righe_vista,

    COUNT(DISTINCT CONCAT(
        order_id,
        '-',
        CAST(order_item_id AS STRING)
    )) AS chiavi_uniche,

    COUNTIF(product_id IS NULL) AS product_id_null,

    COUNTIF(
        categoria_inglese = 'Non classificato'
    ) AS categorie_non_classificate

FROM
    `business-performance-analytics.olist_analytics.vw_fact_order_items`;

-- =====================================================
-- RISULTATI E CONCLUSIONI
-- =====================================================
-- La vista contiene 112.650 righe, esattamente come
-- la tabella originale order_items.
-- Le chiavi uniche sono 112.650: non sono state
-- introdotte duplicazioni durante le JOIN.
-- Non risultano product_id null.
-- Sono presenti 1.603 righe (1,42%) con categoria
-- non classificata, per assenza di una traduzione
-- inglese disponibile o della categoria originale.
--
-- La verifica conferma che la vista preserva
-- correttamente il livello di dettaglio della singola
-- riga d'ordine ed è utilizzabile per le analisi.
-- =====================================================

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Creazione vista degli ordini
-- Integrazione delle informazioni relative a ordini,
-- clienti, articoli e recensioni.
-- L'obiettivo è creare una vista con una sola riga
-- per ordine, contenente i principali KPI commerciali
-- e le informazioni utili per le analisi in Power BI.
-- =====================================================

CREATE OR REPLACE VIEW
    `business-performance-analytics.olist_analytics.vw_fact_orders`
AS

WITH

-- Aggregazione degli articoli per ordine
ordini_articoli AS (
    SELECT
        order_id,
        COUNT(*) AS numero_righe_ordine,
        SUM(price) AS ricavi_prodotti,
        SUM(freight_value) AS ricavi_spedizione,
        SUM(price + freight_value) AS valore_totale_ordine

    FROM
        `business-performance-analytics.olist_analytics.order_items`

    GROUP BY
        order_id
),

-- Aggregazione delle recensioni per ordine
ordini_recensioni AS (
    SELECT
        order_id,
        COUNT(*) AS numero_recensioni,
        AVG(review_score) AS voto_medio,
        COUNTIF(review_score <= 2) AS recensioni_negative,
        COUNTIF(review_score >= 4) AS recensioni_positive

    FROM
        `business-performance-analytics.olist_analytics.orders_reviews`

    GROUP BY
        order_id
)

SELECT
    o.order_id,
    o.customer_id,

    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    DATE_DIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_purchase_timestamp),
        DAY
    ) AS giorni_consegna,

    DATE_DIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_estimated_delivery_date),
        DAY
    ) AS giorni_ritardo,

    COALESCE(a.numero_righe_ordine, 0) AS numero_righe_ordine,
    COALESCE(a.ricavi_prodotti, 0) AS ricavi_prodotti,
    COALESCE(a.ricavi_spedizione, 0) AS ricavi_spedizione,
    COALESCE(a.valore_totale_ordine, 0) AS valore_totale_ordine,

    COALESCE(r.numero_recensioni, 0) AS numero_recensioni,
    r.voto_medio,
    COALESCE(r.recensioni_negative, 0) AS recensioni_negative,
    COALESCE(r.recensioni_positive, 0) AS recensioni_positive

FROM
    `business-performance-analytics.olist_analytics.orders` o

LEFT JOIN
    `business-performance-analytics.olist_analytics.customers` c
    ON o.customer_id = c.customer_id

LEFT JOIN
    ordini_articoli a
    ON o.order_id = a.order_id

LEFT JOIN
    ordini_recensioni r
    ON o.order_id = r.order_id;

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Verifica della vista degli ordini
-- Controllo del numero di ordini, dell'unicità delle
-- chiavi e della coerenza degli importi aggregati.
-- L'obiettivo è verificare che la vista mantenga
-- una sola riga per ordine e importi corretti.
-- =====================================================

SELECT
    COUNT(*) AS numero_righe,
    COUNT(DISTINCT order_id) AS ordini_unici,

    COUNTIF(customer_unique_id IS NULL) AS clienti_null,

    SUM(ricavi_prodotti) AS ricavi_prodotti,
    SUM(ricavi_spedizione) AS ricavi_spedizione,
    SUM(valore_totale_ordine) AS valore_totale,

    SUM(numero_righe_ordine) AS righe_articoli,

    COUNTIF(numero_recensioni > 0) AS ordini_con_recensione

FROM
    `business-performance-analytics.olist_analytics.vw_fact_orders`;

-- =====================================================
-- RISULTATI E CONCLUSIONI
-- =====================================================
-- La vista contiene 99.441 righe, corrispondenti
-- esattamente ai 99.441 ordini originali.
-- Tutti gli order_id sono univoci e non risultano
-- clienti mancanti.
-- Le aggregazioni restituiscono:
-- Ricavi prodotti: 13.591.643,70
-- Ricavi spedizione: 2.251.909,54
-- Valore complessivo: 15.843.553,24
-- Righe articoli: 112.650
-- Ordini con recensione: 98.673
-- La somma delle righe articolo conferma che tutti
-- i record della tabella order_items sono stati
-- correttamente aggregati per ordine.
-- I ricavi comprendono tutti gli stati degli ordini,
-- a differenza delle analisi della Fase 3, limitate
-- agli ordini consegnati.
-- La verifica conferma il mantenimento del livello
-- di dettaglio di un ordine per riga.
-- =====================================================

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Creazione dimensione clienti
-- Estrazione delle informazioni anagrafiche e
-- geografiche dei clienti.
-- L'obiettivo è creare una dimensione con una riga
-- per ogni customer_id, da collegare alla vista ordini.
-- =====================================================

CREATE OR REPLACE VIEW
    `business-performance-analytics.olist_analytics.vw_dim_customer`
AS

SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state

FROM
    `business-performance-analytics.olist_analytics.customers`;

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Verifica della dimensione clienti
-- Controllo del numero di record, dell'unicità
-- della chiave e della completezza dei dati.
-- L'obiettivo è verificare che la dimensione clienti
-- sia correttamente utilizzabile nel modello Power BI.
-- =====================================================

SELECT
    COUNT(*) AS numero_righe,

    COUNT(DISTINCT customer_id) AS customer_id_unici,

    COUNTIF(customer_id IS NULL) AS customer_id_null,

    COUNTIF(customer_unique_id IS NULL) AS customer_unique_id_null,

    COUNT(DISTINCT customer_unique_id) AS clienti_unici,

    COUNTIF(customer_state IS NULL) AS stati_null,

    COUNTIF(customer_city IS NULL) AS citta_null

FROM
    `business-performance-analytics.olist_analytics.vw_dim_customer`;

-- =====================================================
-- RISULTATI E CONCLUSIONI
-- =====================================================
-- La dimensione contiene 99.441 righe e altrettanti
-- customer_id unici.
-- Non risultano valori null nella chiave primaria
-- né nell'identificativo customer_unique_id.
-- Le informazioni geografiche (città e stato)
-- risultano complete.
--
-- Sono presenti 96.096 customer_unique_id distinti.
-- La differenza rispetto ai 99.441 customer_id
-- conferma che una stessa persona può essere associata
-- a più identificativi cliente.
--
-- La dimensione è correttamente utilizzabile nel
-- modello Power BI, collegandola alla vista degli
-- ordini tramite customer_id.
-- =====================================================

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Creazione dimensione prodotti
-- Integrazione delle caratteristiche dei prodotti
-- con le informazioni relative alle categorie.
-- L'obiettivo è creare una dimensione con una riga
-- per prodotto, utilizzabile per le analisi commerciali.
-- =====================================================

CREATE OR REPLACE VIEW
    `business-performance-analytics.olist_analytics.vw_dim_product`
AS

SELECT
    p.product_id,

    p.product_category_name AS categoria_originale,

    COALESCE(
        ct.string_field_1,
        p.product_category_name,
        'Non classificato'
    ) AS categoria_inglese,

    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm

FROM
    `business-performance-analytics.olist_analytics.products` p

LEFT JOIN
    `business-performance-analytics.olist_analytics.category_translation` ct
    ON p.product_category_name = ct.string_field_0;

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Verifica della dimensione prodotti
-- Controllo del numero di record, dell'unicità
-- della chiave e della completezza delle categorie.
-- L'obiettivo è verificare che la dimensione prodotti
-- sia correttamente utilizzabile nel modello Power BI.
-- =====================================================

SELECT
    COUNT(*) AS numero_righe,

    COUNT(DISTINCT product_id) AS product_id_unici,

    COUNTIF(product_id IS NULL) AS product_id_null,

    COUNTIF(
        categoria_inglese = 'Non classificato'
    ) AS categorie_non_classificate,

    COUNTIF(categoria_originale IS NULL) AS categorie_originali_null

FROM
    `business-performance-analytics.olist_analytics.vw_dim_product`;

-- =====================================================
-- RISULTATI E CONCLUSIONI
-- =====================================================
-- La dimensione contiene 32.951 righe e altrettanti
-- product_id unici.
-- Non risultano identificativi prodotto null
-- né duplicazioni introdotte dalla JOIN.
--
-- Sono presenti 610 prodotti (1,85%) senza categoria
-- originale nella tabella products.
-- Per questi prodotti la categoria viene valorizzata
-- come 'Non classificato' tramite COALESCE.
--
-- I prodotti senza categoria non devono essere
-- eliminati, poiché rappresentano record validi
-- del catalogo originale.
--
-- La dimensione è correttamente utilizzabile nel
-- modello Power BI tramite product_id.
-- =====================================================

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Creazione dimensione calendario
-- Generazione di un calendario continuo basato sulle
-- date di acquisto presenti nella tabella orders.
-- L'obiettivo è supportare le analisi temporali
-- e i confronti tra periodi in Power BI.
-- =====================================================

CREATE OR REPLACE VIEW
    `business-performance-analytics.olist_analytics.vw_dim_date`
AS

WITH intervallo_date AS (

    SELECT
        MIN(DATE(order_purchase_timestamp)) AS data_inizio,
        MAX(DATE(order_purchase_timestamp)) AS data_fine

    FROM
        `business-performance-analytics.olist_analytics.orders`

)

SELECT
    data AS data_completa,

    EXTRACT(YEAR FROM data) AS anno,

    EXTRACT(QUARTER FROM data) AS trimestre,

    EXTRACT(MONTH FROM data) AS mese_numero,

    FORMAT_DATE('%B', data) AS mese_nome,

    FORMAT_DATE('%Y-%m', data) AS anno_mese,

    EXTRACT(WEEK FROM data) AS settimana_anno,

    EXTRACT(DAY FROM data) AS giorno_mese,

    FORMAT_DATE('%A', data) AS giorno_settimana,

    MOD(
        EXTRACT(DAYOFWEEK FROM data) + 5,
        7
    ) + 1 AS giorno_settimana_numero

FROM
    intervallo_date,

    UNNEST(
        GENERATE_DATE_ARRAY(data_inizio, data_fine)
    ) AS data;

-- =====================================================
-- FASE 4: DATA MODELING E PREPARAZIONE POWER BI
-- ANALISI: Verifica della dimensione calendario
-- Controllo della continuità temporale, dell'unicità
-- delle date e della coerenza dell'intervallo.
-- L'obiettivo è verificare che il calendario sia
-- completo e utilizzabile nelle analisi temporali.
-- =====================================================

SELECT
    COUNT(*) AS numero_date,

    COUNT(DISTINCT data_completa) AS date_uniche,

    MIN(data_completa) AS data_inizio,

    MAX(data_completa) AS data_fine,

    DATE_DIFF(
        MAX(data_completa),
        MIN(data_completa),
        DAY
    ) + 1 AS giorni_attesi

FROM
    `business-performance-analytics.olist_analytics.vw_dim_date`;

-- =====================================================
-- RISULTATI E CONCLUSIONI
-- =====================================================
-- La dimensione calendario contiene 774 date uniche,
-- comprese tra il 04/09/2016 e il 17/10/2018.
-- Il numero di date coincide con i giorni attesi
-- nell'intervallo temporale considerato.
-- Non risultano duplicazioni o giorni mancanti.
-- Il calendario è stato generato utilizzando
-- l'intervallo delle date di acquisto degli ordini.
-- La dimensione è correttamente utilizzabile in
-- Power BI per le analisi temporali e i confronti
-- tra periodi.
-- =====================================================