-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: orders e order_items
-- ANALISI: Cardinalità della relazione
-- =====================================================
-- Obiettivo:
-- Verificare quanti articoli sono associati a ciascun ordine
-- e analizzare la distribuzione degli articoli per ordine.

SELECT
    numero_articoli,
    COUNT(*) AS numero_ordini
FROM (
    SELECT
        order_id,
        COUNT(*) AS numero_articoli
    FROM `business-performance-analytics.olist_analytics.order_items`
    GROUP BY order_id
)
GROUP BY numero_articoli
ORDER BY numero_articoli;
-- Esito dell'analisi:
-- Sono stati individuati 98.666 ordini con almeno un articolo associato. Il 90,06% degli ordini contiene un solo articolo, mentre il 7,62%
-- ne contiene due. Complessivamente, il 97,68% degli ordini contiene uno o due articoli.
-- La distribuzione evidenzia una relazione di tipo uno-a-molti (1:N) tra orders e order_items.

-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: orders e order_items
-- ANALISI: Copertura degli ordini
-- =====================================================

-- Obiettivo:
-- Verificare quanti ordini hanno almeno un articolo associato
-- e quanti non presentano corrispondenze in order_items.

WITH articoli_per_ordine AS (
    SELECT
        order_id,
        COUNT(*) AS numero_articoli
    FROM `business-performance-analytics.olist_analytics.order_items`
    GROUP BY order_id
)

SELECT
    COUNT(*) AS ordini_totali,

    COUNTIF(a.order_id IS NOT NULL) AS ordini_con_articoli,

    COUNTIF(a.order_id IS NULL) AS ordini_senza_articoli,

    ROUND(
        COUNTIF(a.order_id IS NOT NULL) * 100.0 / COUNT(*),
        2
    ) AS percentuale_ordini_con_articoli,

    ROUND(
        COUNTIF(a.order_id IS NULL) * 100.0 / COUNT(*),
        2
    ) AS percentuale_ordini_senza_articoli

FROM `business-performance-analytics.olist_analytics.orders` AS o
LEFT JOIN articoli_per_ordine AS a
    ON o.order_id = a.order_id;
-- Esito dell'analisi:
-- Su 99.441 ordini complessivi, 98.666 (99,22%) presentano
-- almeno un articolo associato nella tabella order_items.
-- I restanti 775 ordini (0,78%) non presentano articoli associati.
-- Il risultato conferma la copertura quasi totale degli ordini.
-- Gli ordini senza articoli saranno approfonditi attraverso
-- la distribuzione per stato, senza considerarli automaticamente errori.

-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: orders e order_items
-- ANALISI: Stato degli ordini senza articoli
-- =====================================================

SELECT
    o.order_status,
    COUNT(*) AS numero_ordini,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentuale
FROM `business-performance-analytics.olist_analytics.orders` AS o
LEFT JOIN `business-performance-analytics.olist_analytics.order_items` AS i
    ON o.order_id = i.order_id
WHERE i.order_id IS NULL
GROUP BY o.order_status
ORDER BY numero_ordini DESC;
-- Esito dell'analisi:
-- Dei 775 ordini senza articoli associati, 603 (77,81%) risultano
-- unavailable e 164 (21,16%) canceled.
-- Queste due categorie rappresentano complessivamente il 98,97% del totale.
-- Sono presenti anche 5 ordini created, 2 invoiced e 1 shipped.
-- Quest'ultimo caso, pur essendo isolato, merita un approfondimento
-- nelle successive verifiche.

-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: orders e order_items
-- ANALISI: Integrità referenziale inversa
-- =====================================================

SELECT
    COUNT(*) AS righe_totali_order_items,
    COUNTIF(o.order_id IS NOT NULL) AS righe_con_ordine,
    COUNTIF(o.order_id IS NULL) AS righe_senza_ordine,

    ROUND(
        COUNTIF(o.order_id IS NOT NULL) * 100.0 / COUNT(*),
        2
    ) AS percentuale_righe_con_ordine,

    ROUND(
        COUNTIF(o.order_id IS NULL) * 100.0 / COUNT(*),
        2
    ) AS percentuale_righe_senza_ordine

FROM `business-performance-analytics.olist_analytics.order_items` AS i
LEFT JOIN `business-performance-analytics.olist_analytics.orders` AS o
    ON i.order_id = o.order_id;
-- Esito dell'analisi:
-- Tutte le 112.650 righe di order_items trovano una corrispondenza
-- nella tabella orders (100%).
-- Non sono state rilevate righe prive di un ordine associato.
-- L'integrità referenziale tra orders e order_items è confermata.

-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: order_items e products
-- ANALISI: Distribuzione degli articoli per prodotto
-- =====================================================

WITH articoli_per_prodotto AS (
    SELECT
        product_id,
        COUNT(*) AS numero_articoli_venduti
    FROM `business-performance-analytics.olist_analytics.order_items`
    GROUP BY product_id
)

SELECT
    numero_articoli_venduti,
    COUNT(*) AS numero_prodotti,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentuale_prodotti
FROM articoli_per_prodotto
GROUP BY numero_articoli_venduti
ORDER BY numero_articoli_venduti;
-- Esito dell'analisi:
-- Sono stati analizzati 32.951 prodotti presenti in order_items.
-- Il 54,98% dei prodotti compare una sola volta, mentre il 17,65%
-- compare due volte.
-- Complessivamente, il 72,63% dei prodotti presenta al massimo
-- due occorrenze negli ordini.
-- La frequenza massima osservata è di 527 occorrenze per prodotto.
-- La distribuzione evidenzia una concentrazione eterogenea
-- delle occorrenze tra i prodotti del catalogo.

-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: orders e customers
-- ANALISI: Distribuzione degli ordini per cliente
-- =====================================================

WITH ordini_per_cliente AS (
    SELECT
        c.customer_unique_id,
        COUNT(*) AS numero_ordini
    FROM `business-performance-analytics.olist_analytics.orders` AS o
    INNER JOIN `business-performance-analytics.olist_analytics.customers` AS c
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    numero_ordini,
    COUNT(*) AS numero_clienti,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentuale_clienti
FROM ordini_per_cliente
GROUP BY numero_ordini
ORDER BY numero_ordini;
-- Esito dell'analisi:
-- Sono stati individuati 96.096 clienti reali.
-- Il 96,88% ha effettuato un solo ordine, mentre il 3,12%
-- ha effettuato più di un ordine.
-- La maggior parte dei clienti ricorrenti (2.745) ha effettuato
-- esattamente due ordini.
-- È stato rilevato un caso isolato di un cliente con 17 ordini.
-- La relazione evidenzia una prevalenza di clienti con un solo
-- acquisto, elemento utile per le successive analisi di fidelizzazione.

-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: orders e orders_reviews
-- ANALISI: Distribuzione delle recensioni per ordine
-- =====================================================

WITH recensioni_per_ordine AS (
    SELECT
        order_id,
        COUNT(*) AS numero_recensioni
    FROM `business-performance-analytics.olist_analytics.orders_reviews`
    GROUP BY order_id
)

SELECT
    numero_recensioni,
    COUNT(*) AS numero_ordini,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentuale_ordini
FROM recensioni_per_ordine
GROUP BY numero_recensioni
ORDER BY numero_recensioni;
-- Esito dell'analisi:
-- Sono stati individuati 98.673 ordini con almeno una recensione.
-- Il 99,45% presenta una sola recensione, mentre lo 0,55%
-- presenta più di una recensione.
-- In particolare, 543 ordini hanno due recensioni e 4 ne hanno tre.
-- La relazione prevalente è uno-a-uno (1:1), ma sono presenti
-- eccezioni che determinano una cardinalità effettiva uno-a-molti (1:N).
-- Nelle successive analisi sarà necessario considerare queste
-- eccezioni per evitare duplicazioni nei calcoli a livello di ordine.

-- =====================================================
-- FASE 2: RELAZIONI TRA LE TABELLE
-- TABELLE: orders e orders_reviews
-- ANALISI: Copertura delle recensioni sugli ordini
-- =====================================================

SELECT
    COUNT(*) AS totale_ordini,

    COUNT(r.order_id) AS ordini_con_recensione,

    COUNTIF(r.order_id IS NULL) AS ordini_senza_recensione,

    ROUND(
        COUNT(r.order_id) * 100.0 / COUNT(*),
        2
    ) AS percentuale_ordini_con_recensione,

    ROUND(
        COUNTIF(r.order_id IS NULL) * 100.0 / COUNT(*),
        2
    ) AS percentuale_ordini_senza_recensione

FROM `business-performance-analytics.olist_analytics.orders` AS o

LEFT JOIN (
    SELECT DISTINCT order_id
    FROM `business-performance-analytics.olist_analytics.orders_reviews`
) AS r
    ON o.order_id = r.order_id;
-- Esito dell'analisi:
-- Su 99.441 ordini complessivi, 98.673 (99,23%) presentano
-- almeno una recensione.
-- I restanti 768 ordini (0,77%) non hanno recensioni associate.
-- La copertura della tabella orders_reviews è quindi molto elevata.
-- Gli ordini senza recensione saranno mantenuti nelle analisi
-- commerciali e considerati separatamente nelle analisi di soddisfazione.

-- =====================================================
-- FASE 2 - DATA MODELING
-- ANALISI: Creazione vista recensioni ordini
-- DESCRIZIONE: Selezione dei dati essenziali relativi
--              alle recensioni dei clienti.
-- OBIETTIVO: Rendere disponibili i punteggi delle
--            recensioni in Power BI per le analisi
--            di customer satisfaction.
-- =====================================================

CREATE OR REPLACE VIEW
`business-performance-analytics.olist_analytics.vw_fact_order_reviews`
AS

SELECT
    review_id,
    order_id,
    review_score

FROM
    `business-performance-analytics.olist_analytics.orders_reviews`;
