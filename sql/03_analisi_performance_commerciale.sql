-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Andamento mensile delle vendite
-- =====================================================
SELECT
    FORMAT_DATE(
        '%Y-%m',
        DATE(o.order_purchase_timestamp)
    ) AS mese,

    COUNT(DISTINCT o.order_id) AS numero_ordini,

    SUM(oi.price) AS fatturato,

    SUM(oi.freight_value) AS costi_spedizione,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS valore_medio_ordine
FROM `business-performance-analytics.olist_analytics.orders` AS o

INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'
GROUP BY mese
ORDER BY mese;
-- Esito dell'analisi:
-- L'andamento mensile evidenzia una crescita significativa
-- delle vendite nel corso del 2017.
-- Novembre 2017 registra il massimo fatturato (987.765,37)
-- e il maggior numero di ordini consegnati (7.289).
-- Nel 2018 il fatturato mensile si mantiene su livelli elevati,
-- con un massimo di 977.544,69 a maggio.
-- Il valore medio dell'ordine mostra oscillazioni nel periodo,
-- senza seguire necessariamente l'andamento del fatturato.
-- L'analisi considera gli ordini in base alla data di acquisto
-- e include esclusivamente quelli con stato delivered.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Crescita mensile del fatturato (MoM)
-- Analisi della variazione mensile del fatturato (Month-over-Month).
-- L'obiettivo è misurare la crescita o la contrazione delle vendite
-- rispetto al mese precedente, includendo anche i mesi senza vendite.
-- =====================================================

WITH vendite_mensili AS (
    SELECT
        DATE_TRUNC(DATE(o.order_purchase_timestamp), MONTH) AS mese,
        SUM(oi.price) AS fatturato
    FROM `business-performance-analytics.olist_analytics.orders` AS o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY mese
),

calendario AS (
    SELECT mese
    FROM UNNEST(
        GENERATE_DATE_ARRAY(
            (SELECT MIN(mese) FROM vendite_mensili),
            (SELECT MAX(mese) FROM vendite_mensili),
            INTERVAL 1 MONTH
        )
    ) AS mese
),

fatturato_completo AS (
    SELECT
        c.mese,
        COALESCE(v.fatturato, 0) AS fatturato
    FROM calendario AS c
    LEFT JOIN vendite_mensili AS v
        ON c.mese = v.mese
),

con_fatturato_precedente AS (
    SELECT
        mese,
        fatturato,
        LAG(fatturato) OVER (ORDER BY mese) AS fatturato_mese_precedente
    FROM fatturato_completo
)

SELECT
    FORMAT_DATE('%Y-%m', mese) AS mese,
    ROUND(fatturato, 2) AS fatturato,
    ROUND(fatturato_mese_precedente, 2) AS fatturato_mese_precedente,

    ROUND(
        SAFE_DIVIDE(
            (fatturato - fatturato_mese_precedente) * 100.0,
            NULLIF(fatturato_mese_precedente, 0)
        ),
        2
    ) AS variazione_percentuale_mom

FROM con_fatturato_precedente
ORDER BY mese;
-- Esito dell'analisi:
-- Il fatturato presenta una crescita significativa nel corso del 2017,
-- con incrementi rilevanti a marzo (+53,36%) e novembre (+52,37%).
-- Novembre 2016 registra un fatturato nullo, con una contrazione
-- del 100% rispetto al mese precedente.
-- La variazione di dicembre 2016 non è calcolabile perché il mese
-- precedente presenta un fatturato pari a zero.
-- La crescita eccezionale di gennaio 2017 (+1.025.573,03%)
-- è influenzata dalla base di confronto particolarmente ridotta.
-- Nel 2018 il fatturato mostra un andamento relativamente più stabile,
-- pur mantenendo alcune oscillazioni mensili.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Performance commerciale per categoria di prodotto
-- Analisi del fatturato generato dalle diverse categorie.
-- L'obiettivo è individuare le categorie più rilevanti in termini
-- di fatturato e misurare il loro contributo sulle vendite totali.
-- =====================================================
WITH vendite_per_categoria AS (
    SELECT
        COALESCE(ct.string_field_1, p.product_category_name, 'Non classificato')
            AS categoria,

        SUM(oi.price) AS fatturato,

        COUNT(*) AS numero_articoli,

        COUNT(DISTINCT o.order_id) AS numero_ordini

    FROM `business-performance-analytics.olist_analytics.orders` AS o

    INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
        ON o.order_id = oi.order_id

    INNER JOIN `business-performance-analytics.olist_analytics.products` AS p
        ON oi.product_id = p.product_id

    LEFT JOIN `business-performance-analytics.olist_analytics.category_translation` AS ct
        ON p.product_category_name = ct.string_field_0

    WHERE o.order_status = 'delivered'

    GROUP BY categoria
)

SELECT
    categoria,

    ROUND(fatturato, 2) AS fatturato,

    ROUND(
        fatturato * 100.0 / SUM(fatturato) OVER (),
        2
    ) AS percentuale_fatturato,

    numero_articoli,

    numero_ordini,

    ROUND(
        fatturato / numero_ordini,
        2
    ) AS fatturato_medio_per_ordine

FROM vendite_per_categoria
ORDER BY fatturato DESC;
-- Esito dell'analisi:
-- Health & Beauty è la categoria con il fatturato più elevato
-- (1.233.131,72), seguita da Watches & Gifts (1.166.176,98).
-- Le prime cinque categorie generano complessivamente il 39,83%
-- del fatturato totale.
-- Bed, Bath & Table registra il maggior numero di articoli
-- e di ordini tra le categorie analizzate.
-- Computers presenta un fatturato medio per ordine elevato
-- (1.235,50), ma su un numero limitato di ordini (177).
-- La categoria Non classificato contribuisce per l'1,29%
-- al fatturato complessivo.
-- Il fatturato risulta distribuito tra diverse categorie,
-- senza una singola categoria dominante.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Performance commerciale per Stato
-- Analisi della distribuzione geografica delle vendite.
-- L'obiettivo è individuare gli Stati che contribuiscono
-- maggiormente al fatturato e agli ordini complessivi.
-- =====================================================

WITH vendite_per_stato AS (
    SELECT
        c.customer_state AS stato,

        SUM(oi.price) AS fatturato,

        COUNT(DISTINCT o.order_id) AS numero_ordini,

        COUNT(*) AS numero_articoli

    FROM `business-performance-analytics.olist_analytics.orders` AS o

    INNER JOIN `business-performance-analytics.olist_analytics.customers` AS c
        ON o.customer_id = c.customer_id

    INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_state
)

SELECT
    stato,

    ROUND(fatturato, 2) AS fatturato,

    ROUND(
        fatturato * 100.0 / SUM(fatturato) OVER (),
        2
    ) AS percentuale_fatturato,

    numero_ordini,

    ROUND(
        numero_ordini * 100.0 / SUM(numero_ordini) OVER (),
        2
    ) AS percentuale_ordini,

    numero_articoli,

    ROUND(
        fatturato / numero_ordini,
        2
    ) AS fatturato_medio_per_ordine

FROM vendite_per_stato
ORDER BY fatturato DESC;
-- =====================================================
-- COMMENTO AI RISULTATI
-- =====================================================
-- L'analisi evidenzia una forte concentrazione geografica
-- del fatturato. Lo Stato di São Paulo (SP) è il principale
-- mercato, con il 38,33% del fatturato e il 41,98% degli
-- ordini complessivi.
--
-- I primi tre Stati (SP, RJ e MG) generano insieme il
-- 63,38% del fatturato, confermando il peso predominante
-- del Sud-Est brasiliano.
--
-- Si osservano differenze nel fatturato medio per ordine
-- tra gli Stati. Alcuni mercati con volumi ridotti mostrano
-- valori medi elevati, da interpretare con cautela.
--
-- Il fatturato considera esclusivamente il prezzo degli
-- articoli e non include i costi di spedizione.
-- =====================================================
-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Clienti nuovi e clienti ricorrenti
-- Analisi del comportamento d'acquisto e della
-- fidelizzazione della clientela.
-- L'obiettivo è confrontare il contributo dei clienti
-- al primo acquisto con quello dei clienti ricorrenti.
-- =====================================================

WITH ordini_per_cliente AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS numero_ordini,
        SUM(oi.price) AS fatturato
    FROM `business-performance-analytics.olist_analytics.orders` AS o
    INNER JOIN `business-performance-analytics.olist_analytics.customers` AS c
        ON o.customer_id = c.customer_id
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
segmentazione_clienti AS (
    SELECT
        CASE
            WHEN numero_ordini = 1 THEN 'Cliente al primo acquisto'
            ELSE 'Cliente ricorrente'
        END AS segmento,
        COUNT(*) AS numero_clienti,
        SUM(numero_ordini) AS numero_ordini,
        SUM(fatturato) AS fatturato
    FROM ordini_per_cliente
    GROUP BY segmento
)
SELECT
    segmento,
    numero_clienti,
    ROUND(
        numero_clienti * 100.0 / SUM(numero_clienti) OVER (), 2
    ) AS percentuale_clienti,
    numero_ordini,
    ROUND(
        numero_ordini * 100.0 / SUM(numero_ordini) OVER (), 2
    ) AS percentuale_ordini,
    ROUND(fatturato, 2) AS fatturato,
    ROUND(
        fatturato * 100.0 / SUM(fatturato) OVER (), 2
    ) AS percentuale_fatturato,
    ROUND(fatturato / numero_clienti, 2) AS fatturato_medio_per_cliente
FROM segmentazione_clienti
ORDER BY fatturato DESC;
-- =====================================================
-- COMMENTO AI RISULTATI
-- =====================================================
-- L'analisi evidenzia una quota contenuta di clienti
-- ricorrenti: il 3,00% della clientela ha effettuato
-- almeno due ordini consegnati nel periodo osservato.
-- Nonostante il peso numerico ridotto, questi clienti
-- generano il 5,51% del fatturato complessivo.
-- Il fatturato medio per cliente ricorrente è pari a
-- 260,05, circa l'88,5% in più rispetto ai 137,96
-- registrati dai clienti al primo acquisto.
-- Il risultato suggerisce il potenziale valore economico
-- della fidelizzazione. La ricorrenza è calcolata
-- esclusivamente sugli ordini consegnati presenti
-- nel dataset e non rappresenta una misura di retention.
-- =====================================================

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Distribuzione della frequenza di acquisto
-- Analisi del numero di ordini effettuati da ciascun cliente.
-- L'obiettivo è individuare i livelli di frequenza
-- d'acquisto e il relativo contributo al fatturato.
-- =====================================================

WITH ordini_per_cliente AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS numero_ordini,
        SUM(oi.price) AS fatturato
    FROM `business-performance-analytics.olist_analytics.orders` AS o
    INNER JOIN `business-performance-analytics.olist_analytics.customers` AS c
        ON o.customer_id = c.customer_id
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    numero_ordini,
    COUNT(*) AS numero_clienti,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS percentuale_clienti,
    SUM(numero_ordini) AS totale_ordini,
    ROUND(SUM(fatturato), 2) AS fatturato,
    ROUND(
        SUM(fatturato) * 100.0 / SUM(SUM(fatturato)) OVER (), 2
    ) AS percentuale_fatturato,
    ROUND(AVG(fatturato), 2) AS fatturato_medio_per_cliente
FROM ordini_per_cliente
GROUP BY numero_ordini
ORDER BY numero_ordini;
-- =====================================================
-- COMMENTO AI RISULTATI
-- =====================================================
-- La distribuzione evidenzia una forte prevalenza di
-- clienti con un solo ordine consegnato (97,00%).
-- I clienti ricorrenti rappresentano il 3,00% della
-- clientela e sono costituiti prevalentemente da clienti
-- con due acquisti (2.573 su 2.801).
-- Il fatturato medio per cliente tende ad aumentare
-- con la frequenza di acquisto, passando da 137,96
-- per un ordine a 245,35 per due ordini e 364,50
-- per tre ordini.
-- I gruppi con frequenze di acquisto più elevate
-- presentano numerosità molto contenute e richiedono
-- cautela nell'interpretazione.
-- L'analisi considera esclusivamente gli ordini
-- consegnati presenti nel dataset.
-- =====================================================

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Distribuzione delle recensioni e soddisfazione
-- Analisi dei punteggi assegnati dai clienti agli ordini.
-- L'obiettivo è valutare il livello di soddisfazione
-- attraverso la distribuzione dei punteggi e il loro
-- raggruppamento in recensioni positive, neutre e negative.
-- =====================================================

WITH statistiche AS (
    SELECT
        COUNT(*) AS totale_recensioni,
        AVG(review_score) AS punteggio_medio
    FROM `business-performance-analytics.olist_analytics.orders_reviews`
),
distribuzione_punteggi AS (
    SELECT
        CONCAT('Punteggio ', CAST(review_score AS STRING)) AS categoria,
        COUNT(*) AS numero_recensioni
    FROM `business-performance-analytics.olist_analytics.orders_reviews`
    GROUP BY review_score
),
distribuzione_soddisfazione AS (
    SELECT
        CASE
            WHEN review_score IN (1, 2) THEN 'Recensioni negative'
            WHEN review_score = 3 THEN 'Recensioni neutre'
            WHEN review_score IN (4, 5) THEN 'Recensioni positive'
        END AS categoria,
        COUNT(*) AS numero_recensioni
    FROM `business-performance-analytics.olist_analytics.orders_reviews`
    GROUP BY categoria
),
risultati AS (
    SELECT * FROM distribuzione_punteggi
    UNION ALL
    SELECT * FROM distribuzione_soddisfazione
)
SELECT
    r.categoria,
    r.numero_recensioni,
    ROUND(
        r.numero_recensioni * 100.0 / s.totale_recensioni, 2
    ) AS percentuale_recensioni,
    ROUND(s.punteggio_medio, 2) AS punteggio_medio_generale
FROM risultati AS r
CROSS JOIN statistiche AS s
ORDER BY
    CASE
        WHEN r.categoria LIKE 'Punteggio %' THEN 1
        ELSE 2
    END,
    r.categoria;

-- =====================================================
-- COMMENTO AI RISULTATI
-- =====================================================
-- L'analisi delle 99.224 recensioni evidenzia un livello
-- complessivamente positivo di soddisfazione, con un
-- punteggio medio pari a 4,09 su 5.
-- Le recensioni positive (4-5 stelle) rappresentano
-- il 77,07% del totale, mentre quelle neutre (3 stelle)
-- costituiscono l'8,24%.
-- Le recensioni negative (1-2 stelle) rappresentano
-- il 14,69%. In particolare, l'11,51% assegna una sola
-- stella, evidenziando una possibile area di miglioramento.
-- Sarà utile approfondire le cause delle valutazioni
-- negative, considerando aspetti logistici e qualitativi
-- dell'esperienza di acquisto.
-- =====================================================

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Puntualità delle consegne e soddisfazione
-- Confronto tra data effettiva e data stimata di consegna.
-- L'obiettivo è valutare la relazione tra puntualità
-- e soddisfazione dei clienti.
-- =====================================================

WITH recensioni_per_ordine AS (
    SELECT
        order_id,
        AVG(review_score) AS punteggio_medio_ordine
    FROM `business-performance-analytics.olist_analytics.orders_reviews`
    GROUP BY order_id
),
ordini_consegna AS (
    SELECT
        o.order_id,
        CASE
            WHEN DATE(o.order_delivered_customer_date)
                 < DATE(o.order_estimated_delivery_date)
                THEN 'Consegnato in anticipo'
            WHEN DATE(o.order_delivered_customer_date)
                 = DATE(o.order_estimated_delivery_date)
                THEN 'Consegnato in tempo'
            WHEN DATE(o.order_delivered_customer_date)
                 > DATE(o.order_estimated_delivery_date)
                THEN 'Consegnato in ritardo'
        END AS puntualita,
        r.punteggio_medio_ordine
    FROM `business-performance-analytics.olist_analytics.orders` AS o
    INNER JOIN recensioni_per_ordine AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    puntualita,
    COUNT(*) AS numero_ordini,
    ROUND(AVG(punteggio_medio_ordine), 2) AS punteggio_medio,
    ROUND(
        COUNTIF(punteggio_medio_ordine > 3) * 100.0 / COUNT(*), 2
    ) AS percentuale_recensioni_positive,
    ROUND(
        COUNTIF(punteggio_medio_ordine = 3) * 100.0 / COUNT(*), 2
    ) AS percentuale_recensioni_neutre,
    ROUND(
        COUNTIF(punteggio_medio_ordine < 3) * 100.0 / COUNT(*), 2
    ) AS percentuale_recensioni_negative
FROM ordini_consegna
GROUP BY puntualita
ORDER BY
    CASE puntualita
        WHEN 'Consegnato in anticipo' THEN 1
        WHEN 'Consegnato in tempo' THEN 2
        WHEN 'Consegnato in ritardo' THEN 3
    END;

-- RISULTATI E CONSIDERAZIONI:
-- Sono stati analizzati 95.824 ordini consegnati e recensiti.
-- Il 92,01% è arrivato in anticipo, l'1,34% nel giorno
-- previsto e il 6,66% in ritardo.
-- Gli ordini consegnati in anticipo registrano un punteggio
-- medio di 4,29/5 e l'82,79% di valutazioni positive.
-- Gli ordini consegnati in ritardo presentano invece un
-- punteggio medio di 2,27/5 e il 62,44% di valutazioni
-- negative.
-- La differenza evidenzia una forte associazione tra ritardi
-- di consegna e minore soddisfazione dei clienti.
-- I risultati descrivono una correlazione osservata e non
-- dimostrano necessariamente un rapporto causale.
-- Nota metodologica: le recensioni sono state aggregate
-- per ordine e la puntualità è stata determinata confrontando
-- le date di calendario effettive e stimate.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Performance e fatturato dei venditori
-- Analisi del fatturato, degli ordini e degli articoli
-- associati a ciascun venditore.
-- L'obiettivo è individuare i venditori più rilevanti
-- e valutare la concentrazione del fatturato.
-- =====================================================

WITH performance_venditori AS (
    SELECT
        oi.seller_id,
        COUNT(*) AS numero_articoli,
        COUNT(DISTINCT o.order_id) AS numero_ordini,
        SUM(oi.price) AS fatturato
    FROM `business-performance-analytics.olist_analytics.orders` AS o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
fatturato_totale AS (
    SELECT
        SUM(fatturato) AS totale_fatturato
    FROM performance_venditori
)
SELECT
    pv.seller_id,
    pv.numero_articoli,
    pv.numero_ordini,
    ROUND(pv.fatturato, 2) AS fatturato,
    ROUND(
        pv.fatturato / pv.numero_ordini, 2
    ) AS fatturato_medio_per_ordine,
    ROUND(
        pv.fatturato * 100.0 / ft.totale_fatturato, 2
    ) AS quota_fatturato_percentuale
FROM performance_venditori AS pv
CROSS JOIN fatturato_totale AS ft
ORDER BY pv.fatturato DESC;

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Concentrazione del fatturato tra i venditori
-- Calcolo della quota di fatturato generata dai principali
-- venditori del marketplace.
-- L'obiettivo è misurare il livello di concentrazione
-- delle vendite tra i diversi operatori.
-- =====================================================

WITH performance_venditori AS (
    SELECT
        oi.seller_id,
        SUM(oi.price) AS fatturato
    FROM `business-performance-analytics.olist_analytics.orders` AS o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
classifica AS (
    SELECT
        seller_id,
        fatturato,
        ROW_NUMBER() OVER (
            ORDER BY fatturato DESC
        ) AS posizione
    FROM performance_venditori
)
SELECT
    COUNT(*) AS numero_venditori,
    ROUND(SUM(fatturato), 2) AS fatturato_totale,
    ROUND(
        SUM(IF(posizione <= 10, fatturato, 0))
        * 100.0 / SUM(fatturato), 2
    ) AS quota_top_10_percentuale,
    ROUND(
        SUM(IF(posizione <= 20, fatturato, 0))
        * 100.0 / SUM(fatturato), 2
    ) AS quota_top_20_percentuale,
    ROUND(
        SUM(IF(posizione <= 50, fatturato, 0))
        * 100.0 / SUM(fatturato), 2
    ) AS quota_top_50_percentuale
FROM classifica;
-- COMMENTO RISULTATI:
-- Sono stati analizzati 2.970 venditori, con un fatturato
-- complessivo di 13.221.498,11.
-- I primi 10 venditori generano il 13,27% del fatturato,
-- i primi 20 il 21,28% e i primi 50 il 33,20%.
-- Il restante 66,80% è distribuito tra gli altri 2.920
-- venditori. Il marketplace mostra una concentrazione
-- parziale delle vendite, senza una dipendenza dominante
-- dai primi operatori.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Tempi delle fasi logistiche
-- Calcolo dei tempi tra acquisto, approvazione,
-- consegna al corriere e consegna al cliente.
-- L'obiettivo è misurare la durata delle diverse fasi
-- logistiche attraverso media e mediana, individuando
-- anche eventuali anomalie cronologiche.
-- =====================================================

WITH tempi_logistici AS (

    SELECT
        'Acquisto - Approvazione' AS fase,
        TIMESTAMP_DIFF(
            order_approved_at,
            order_purchase_timestamp,
            MINUTE
        ) / 60.0 AS ore
    FROM `business-performance-analytics.olist_analytics.orders`
    WHERE order_approved_at IS NOT NULL

    UNION ALL

    SELECT
        'Acquisto - Corriere' AS fase,
        TIMESTAMP_DIFF(
            order_delivered_carrier_date,
            order_purchase_timestamp,
            MINUTE
        ) / 60.0 AS ore
    FROM `business-performance-analytics.olist_analytics.orders`
    WHERE order_delivered_carrier_date IS NOT NULL

    UNION ALL

    SELECT
        'Acquisto - Cliente' AS fase,
        TIMESTAMP_DIFF(
            order_delivered_customer_date,
            order_purchase_timestamp,
            MINUTE
        ) / 60.0 AS ore
    FROM `business-performance-analytics.olist_analytics.orders`
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)

SELECT
    fase,
    COUNTIF(ore >= 0) AS osservazioni_valide,
    COUNTIF(ore < 0) AS anomalie_cronologiche,

    ROUND(AVG(IF(ore >= 0, ore, NULL)), 2)
        AS media_ore,

    ROUND(
        APPROX_QUANTILES(
            IF(ore >= 0, ore, NULL), 100
        )[OFFSET(50)],
        2
    ) AS mediana_ore,

    ROUND(
        AVG(IF(ore >= 0, ore, NULL)) / 24,
        2
    ) AS media_giorni,

    ROUND(
        APPROX_QUANTILES(
            IF(ore >= 0, ore, NULL), 100
        )[OFFSET(50)] / 24,
        2
    ) AS mediana_giorni

FROM tempi_logistici
GROUP BY fase
ORDER BY
    CASE fase
        WHEN 'Acquisto - Approvazione' THEN 1
        WHEN 'Acquisto - Corriere' THEN 2
        WHEN 'Acquisto - Cliente' THEN 3
    END;
-- COMMENTO RISULTATI:
-- Il tempo medio tra acquisto e approvazione è di 10,41 ore,
-- con una mediana di circa 20 minuti.
-- Il tempo medio tra acquisto e affidamento al corriere
-- è di 3,24 giorni, con mediana di 2,21 giorni.
-- Sono state individuate 161 anomalie cronologiche
-- nella data di affidamento al corriere.
-- Il tempo medio tra acquisto e consegna al cliente
-- è di 12,56 giorni, con mediana di 10,22 giorni.
-- La differenza tra media e mediana evidenzia la presenza
-- di ordini con tempi di gestione e consegna più elevati.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Entità dell'anticipo e del ritardo
-- Calcolo dei giorni di scostamento tra la data effettiva
-- di consegna e quella stimata per gli ordini consegnati.
-- L'obiettivo è quantificare l'anticipo e il ritardo
-- rispetto alle aspettative di consegna del cliente.
-- =====================================================

WITH consegne AS (
    SELECT
        order_id,
        DATE_DIFF(
            DATE(order_estimated_delivery_date),
            DATE(order_delivered_customer_date),
            DAY
        ) AS giorni_anticipo
    FROM `business-performance-analytics.olist_analytics.orders`
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

classificazione AS (
    SELECT
        *,
        CASE
            WHEN giorni_anticipo > 0 THEN 'In anticipo'
            WHEN giorni_anticipo = 0 THEN 'Puntuale'
            ELSE 'In ritardo'
        END AS puntualita
    FROM consegne
)

SELECT
    puntualita,
    COUNT(*) AS numero_ordini,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentuale_ordini,

    ROUND(
        AVG(ABS(giorni_anticipo)),
        2
    ) AS giorni_medi_scostamento,

    APPROX_QUANTILES(
        ABS(giorni_anticipo), 100
    )[OFFSET(50)] AS mediana_giorni_scostamento

FROM classificazione
GROUP BY puntualita
ORDER BY
    CASE puntualita
        WHEN 'In anticipo' THEN 1
        WHEN 'Puntuale' THEN 2
        WHEN 'In ritardo' THEN 3
    END;

-- COMMENTO RISULTATI:
-- L'analisi evidenzia che il 91,89% degli ordini viene
-- consegnato in anticipo, con uno scostamento medio
-- di 13,71 giorni e mediano di 13 giorni.
-- Le consegne puntuali rappresentano l'1,34%,
-- mentre quelle in ritardo sono il 6,77%.
-- Per gli ordini in ritardo, lo scostamento medio
-- è di 10,62 giorni, con mediana di 7 giorni.
-- La differenza tra media e mediana suggerisce la presenza
-- di alcuni ritardi particolarmente elevati.
-- L'ampio anticipo medio potrebbe anche riflettere
-- una stima prudenziale delle date di consegna previste.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Performance logistica per area geografica
-- Analisi dei tempi di consegna e della puntualità
-- degli ordini in relazione allo stato del cliente.
-- L'obiettivo è individuare differenze geografiche
-- nell'efficienza delle consegne e nell'incidenza dei ritardi.
-- =====================================================

WITH consegne AS (
    SELECT
        c.customer_state,
        o.order_id,

        DATE_DIFF(
            DATE(o.order_delivered_customer_date),
            DATE(o.order_purchase_timestamp),
            DAY
        ) AS giorni_consegna,

        DATE_DIFF(
            DATE(o.order_estimated_delivery_date),
            DATE(o.order_delivered_customer_date),
            DAY
        ) AS giorni_anticipo

    FROM `business-performance-analytics.olist_analytics.orders` AS o

    INNER JOIN `business-performance-analytics.olist_analytics.customers` AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),

classificazione AS (
    SELECT
        *,
        CASE
            WHEN giorni_anticipo > 0 THEN 'In anticipo'
            WHEN giorni_anticipo = 0 THEN 'Puntuale'
            ELSE 'In ritardo'
        END AS puntualita
    FROM consegne
)

SELECT
    customer_state AS stato,
    COUNT(*) AS ordini_consegnati,

    ROUND(AVG(giorni_consegna), 2) AS media_giorni_consegna,

    APPROX_QUANTILES(
        giorni_consegna, 100
    )[OFFSET(50)] AS mediana_giorni_consegna,

    ROUND(
        COUNTIF(puntualita = 'In anticipo') * 100.0 / COUNT(*),
        2
    ) AS consegne_anticipo_percentuale,

    ROUND(
        COUNTIF(puntualita = 'Puntuale') * 100.0 / COUNT(*),
        2
    ) AS consegne_puntuali_percentuale,

    ROUND(
        COUNTIF(puntualita = 'In ritardo') * 100.0 / COUNT(*),
        2
    ) AS consegne_ritardo_percentuale,

    ROUND(
        AVG(IF(puntualita = 'In ritardo', ABS(giorni_anticipo), NULL)),
        2
    ) AS media_giorni_ritardo

FROM classificazione
GROUP BY customer_state
ORDER BY media_giorni_consegna DESC;
-- COMMENTO RISULTATI:
-- L'analisi evidenzia significative differenze geografiche
-- nei tempi di consegna.
-- RR registra il tempo medio più elevato (29,34 giorni),
-- seguito da AP (27,18) e AM (26,36).
-- SP presenta il tempo medio più contenuto (8,70 giorni),
-- con una percentuale di ritardi del 4,49%.
-- Le percentuali di ritardo più elevate si osservano
-- in AL (21,41%), MA (17,43%) e SE (15,22%).
-- RJ merita attenzione per il volume elevato di ordini
-- e una percentuale di ritardo del 12,11%.
-- I risultati degli stati con pochi ordini devono essere
-- interpretati con cautela.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Andamento temporale della puntualità
-- Analisi mensile dei tempi di consegna e degli scostamenti
-- rispetto alle date di consegna previste.
-- L'obiettivo è individuare eventuali variazioni temporali
-- nell'efficienza logistica e nell'incidenza dei ritardi.
-- =====================================================

WITH consegne AS (
    SELECT
        DATE_TRUNC(DATE(order_purchase_timestamp), MONTH) AS mese,

        DATE_DIFF(
            DATE(order_delivered_customer_date),
            DATE(order_purchase_timestamp),
            DAY
        ) AS giorni_consegna,

        DATE_DIFF(
            DATE(order_estimated_delivery_date),
            DATE(order_delivered_customer_date),
            DAY
        ) AS giorni_anticipo

    FROM `business-performance-analytics.olist_analytics.orders`

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

classificazione AS (
    SELECT
        *,
        CASE
            WHEN giorni_anticipo > 0 THEN 'In anticipo'
            WHEN giorni_anticipo = 0 THEN 'Puntuale'
            ELSE 'In ritardo'
        END AS puntualita
    FROM consegne
)

SELECT
    FORMAT_DATE('%Y-%m', mese) AS mese,

    COUNT(*) AS ordini_consegnati,

    ROUND(
        COUNTIF(puntualita = 'In anticipo') * 100.0 / COUNT(*),
        2
    ) AS anticipo_percentuale,

    ROUND(
        COUNTIF(puntualita = 'Puntuale') * 100.0 / COUNT(*),
        2
    ) AS puntuali_percentuale,

    ROUND(
        COUNTIF(puntualita = 'In ritardo') * 100.0 / COUNT(*),
        2
    ) AS ritardo_percentuale,

    ROUND(
        AVG(
            IF(puntualita = 'In ritardo',
               ABS(giorni_anticipo), NULL)
        ),
        2
    ) AS media_giorni_ritardo,

    ROUND(AVG(giorni_consegna), 2) AS media_giorni_consegna

FROM classificazione
GROUP BY mese
ORDER BY mese;
-- COMMENTO RISULTATI:
-- L'analisi temporale evidenzia variazioni significative
-- nella puntualità delle consegne.
-- Novembre 2017 registra una percentuale di ritardi
-- del 12,40%, mentre febbraio e marzo 2018 raggiungono
-- rispettivamente il 14,13% e il 18,96%.
-- Marzo 2018 rappresenta il periodo più critico
-- tra quelli con volumi significativi.
-- Da aprile 2018 si osserva un recupero della puntualità,
-- con ritardi pari al 4,50% e all'1,16% rispettivamente
-- ad aprile e giugno.
-- Il tempo medio di consegna diminuisce fino a 7,66 giorni
-- nell'agosto 2018.
-- I dati mostrano un'associazione temporale, ma non
-- consentono di identificare le cause dei peggioramenti.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Incidenza complessiva delle spese di spedizione
-- Analisi del rapporto tra valore dei prodotti e importi
-- di spedizione registrati per gli ordini consegnati.
-- L'obiettivo è quantificare il peso della spedizione
-- sul valore commerciale degli ordini.
-- =====================================================

WITH ordini_consegnati AS (
    SELECT
        o.order_id,
        oi.price,
        oi.freight_value
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),

metriche AS (
    SELECT
        COUNT(*) AS numero_articoli,
        COUNT(DISTINCT order_id) AS numero_ordini,
        SUM(price) AS fatturato_prodotti,
        SUM(freight_value) AS totale_spedizioni,
        SUM(price + freight_value) AS valore_complessivo
    FROM ordini_consegnati
)

SELECT
    numero_articoli,
    numero_ordini,
    ROUND(fatturato_prodotti, 2) AS fatturato_prodotti,
    ROUND(totale_spedizioni, 2) AS totale_spedizioni,
    ROUND(valore_complessivo, 2) AS valore_complessivo,

    ROUND(
        SAFE_DIVIDE(totale_spedizioni, fatturato_prodotti) * 100,
        2
    ) AS spedizione_su_prodotti_percentuale,

    ROUND(
        SAFE_DIVIDE(totale_spedizioni, valore_complessivo) * 100,
        2
    ) AS spedizione_su_totale_percentuale,

    ROUND(
        SAFE_DIVIDE(fatturato_prodotti, numero_ordini),
        2
    ) AS valore_medio_prodotti_ordine,

    ROUND(
        SAFE_DIVIDE(totale_spedizioni, numero_ordini),
        2
    ) AS spedizione_media_ordine,

    ROUND(
        SAFE_DIVIDE(totale_spedizioni, numero_articoli),
        2
    ) AS spedizione_media_articolo

FROM metriche;
-- COMMENTO RISULTATI:
-- Il fatturato dei prodotti ammonta a 13,22 milioni,
-- mentre le spese di spedizione registrate raggiungono
-- circa 2,20 milioni.
-- La spedizione incide per il 16,63% sul valore dei prodotti
-- e per il 14,26% sul valore complessivo.
-- In media, ogni ordine genera 137,04 di valore prodotti
-- e 22,79 di spese di spedizione.
-- La componente logistica rappresenta quindi una quota
-- rilevante del valore economico degli ordini.
-- I dati non consentono di calcolare il margine lordo
-- effettivo, in assenza dei costi di acquisto e dei costi
-- logistici realmente sostenuti.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Incidenza delle spedizioni per categoria
-- Analisi del valore dei prodotti e delle spese di
-- spedizione suddivisi per categoria merceologica.
-- L'obiettivo è individuare le categorie con maggiore
-- incidenza della componente logistica sul fatturato.
-- =====================================================

WITH analisi_categoria AS (
    SELECT
        COALESCE(
            ct.string_field_1,
            p.product_category_name,
            'Non classificato'
        ) AS categoria,

        COUNT(*) AS numero_articoli,
        COUNT(DISTINCT oi.order_id) AS numero_ordini,

        SUM(oi.price) AS fatturato_prodotti,
        SUM(oi.freight_value) AS totale_spedizioni

    FROM `business-performance-analytics.olist_analytics.orders` o

    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id

    LEFT JOIN `business-performance-analytics.olist_analytics.products` p
        ON oi.product_id = p.product_id

    LEFT JOIN `business-performance-analytics.olist_analytics.category_translation` ct
        ON p.product_category_name = ct.string_field_0

    WHERE o.order_status = 'delivered'

    GROUP BY categoria
)

SELECT
    categoria,
    numero_articoli,
    numero_ordini,

    ROUND(fatturato_prodotti, 2) AS fatturato_prodotti,
    ROUND(totale_spedizioni, 2) AS totale_spedizioni,

    ROUND(
        SAFE_DIVIDE(totale_spedizioni, fatturato_prodotti) * 100,
        2
    ) AS incidenza_spedizione_percentuale,

    ROUND(
        SAFE_DIVIDE(fatturato_prodotti, numero_articoli),
        2
    ) AS prezzo_medio_articolo,

    ROUND(
        SAFE_DIVIDE(totale_spedizioni, numero_articoli),
        2
    ) AS spedizione_media_articolo,

    ROUND(
        SAFE_DIVIDE(fatturato_prodotti, numero_ordini),
        2
    ) AS fatturato_medio_ordine

FROM analisi_categoria
ORDER BY incidenza_spedizione_percentuale DESC;
-- COMMENTO RISULTATI:
-- L'incidenza delle spese di spedizione varia sensibilmente
-- tra le categorie merceologiche.
-- I valori più elevati si osservano in Home Comfort 2
-- (53,97%), Flowers (44,04%) e Furniture Mattress
-- and Upholstery (36,58%), ma con volumi ridotti.
-- Tra le categorie con volumi più consistenti emerge
-- Electronics, con un'incidenza del 29,46% su 2.517 ordini.
-- Computers presenta invece un'incidenza contenuta
-- (4,42%), a fronte di un prezzo medio per articolo
-- di 1.098,92.
-- Furniture Decor e Housewares combinano fatturati
-- e spese di spedizione rilevanti.
-- Le percentuali devono essere interpretate considerando
-- anche i volumi, per evitare conclusioni basate
-- su campioni di dimensione limitata.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Distribuzione dei prodotti per fascia di prezzo
-- Classificazione degli articoli venduti in fasce di
-- prezzo e analisi del relativo contributo al fatturato.
-- L'obiettivo è individuare le fasce di prezzo con
-- maggiore volume di vendita e maggiore peso economico.
-- =====================================================

WITH prodotti AS (
    SELECT
        oi.price,
        CASE
            WHEN oi.price <= 50 THEN '1. Economica'
            WHEN oi.price <= 100 THEN '2. Medio-bassa'
            WHEN oi.price <= 250 THEN '3. Media'
            WHEN oi.price <= 500 THEN '4. Medio-alta'
            ELSE '5. Premium'
        END AS fascia_prezzo
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),

metriche AS (
    SELECT
        fascia_prezzo,
        COUNT(*) AS numero_articoli,
        SUM(price) AS fatturato,
        AVG(price) AS prezzo_medio
    FROM prodotti
    GROUP BY fascia_prezzo
)

SELECT
    fascia_prezzo,
    numero_articoli,

    ROUND(
        SAFE_DIVIDE(
            numero_articoli,
            SUM(numero_articoli) OVER ()
        ) * 100,
        2
    ) AS percentuale_articoli,

    ROUND(fatturato, 2) AS fatturato,

    ROUND(
        SAFE_DIVIDE(
            fatturato,
            SUM(fatturato) OVER ()
        ) * 100,
        2
    ) AS percentuale_fatturato,

    ROUND(prezzo_medio, 2) AS prezzo_medio

FROM metriche
ORDER BY fascia_prezzo;
-- RISULTATI E CONSIDERAZIONI:
-- La fascia media (100-250 euro) genera la quota maggiore
-- di fatturato, pari al 35,09% del totale.
-- La fascia premium (>500 euro), pur rappresentando
-- solamente il 2,80% degli articoli, contribuisce per
-- il 21,67% al fatturato complessivo.
-- Le fasce medio-alta e premium generano complessivamente
-- il 37,34% del fatturato con appena l'8,32% degli articoli.
-- La fascia economica presenta invece il volume più elevato
-- di articoli (34,96%), ma contribuisce per il 9,17%
-- al fatturato.
-- I risultati evidenziano una concentrazione del valore
-- economico nelle fasce di prezzo medio e alto.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Top 20 prodotti per fatturato
-- Identificazione dei prodotti che generano i maggiori
-- ricavi, con analisi dei volumi e del contributo economico.
-- L'obiettivo è valutare la concentrazione del fatturato
-- a livello di singolo prodotto.
-- =====================================================

WITH vendite_prodotti AS (
    SELECT
        p.product_id,
        COALESCE(
            ct.string_field_1,
            p.product_category_name,
            'Non classificato'
        ) AS categoria,
        SUM(oi.price) AS fatturato,
        COUNT(*) AS numero_articoli,
        COUNT(DISTINCT o.order_id) AS numero_ordini,
        AVG(oi.price) AS prezzo_medio
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    INNER JOIN `business-performance-analytics.olist_analytics.products` p
        ON oi.product_id = p.product_id
    LEFT JOIN `business-performance-analytics.olist_analytics.category_translation` ct
        ON p.product_category_name = ct.string_field_0
    WHERE o.order_status = 'delivered'
    GROUP BY
        p.product_id,
        categoria
),

fatturato_totale AS (
    SELECT
        SUM(fatturato) AS totale
    FROM vendite_prodotti
)

SELECT
    vp.product_id,
    vp.categoria,
    vp.numero_articoli,
    vp.numero_ordini,
    ROUND(vp.fatturato, 2) AS fatturato,
    ROUND(vp.prezzo_medio, 2) AS prezzo_medio,

    ROUND(
        SAFE_DIVIDE(vp.fatturato, ft.totale) * 100,
        4
    ) AS percentuale_fatturato

FROM vendite_prodotti vp
CROSS JOIN fatturato_totale ft
ORDER BY vp.fatturato DESC
LIMIT 20;
-- RISULTATI E CONSIDERAZIONI:
-- Il prodotto con il fatturato più elevato genera
-- 63.560 euro, pari allo 0,48% del fatturato totale.
-- I primi 20 prodotti contribuiscono complessivamente
-- per circa il 5,45% ai ricavi degli ordini consegnati.
-- La distribuzione evidenzia una limitata concentrazione
-- del fatturato a livello di singolo prodotto.
-- Nella classifica ricorrono soprattutto prodotti delle
-- categorie health_beauty, watches_gifts e computers.
-- Si osservano differenze significative tra prodotti
-- ad alto prezzo medio e prodotti caratterizzati da
-- un maggior numero di righe di vendita.
-- L'analisi misura il contributo ai ricavi e non
-- la redditività, non essendo disponibili i costi.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Concentrazione del fatturato - Pareto
-- Ordinamento dei prodotti in base al fatturato generato
-- e calcolo del contributo economico cumulativo.
-- L'obiettivo è misurare la concentrazione dei ricavi
-- e individuare quanti prodotti generano le principali
-- quote del fatturato complessivo.
-- =====================================================

WITH fatturato_prodotti AS (
    SELECT
        oi.product_id,
        SUM(oi.price) AS fatturato
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.product_id
),

prodotti_ordinati AS (
    SELECT
        product_id,
        fatturato,
        ROW_NUMBER() OVER (
            ORDER BY fatturato DESC, product_id
        ) AS posizione,
        SUM(fatturato) OVER (
            ORDER BY fatturato DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS fatturato_cumulativo
    FROM fatturato_prodotti
),

metriche_totali AS (
    SELECT
        COUNT(*) AS totale_prodotti,
        SUM(fatturato) AS fatturato_totale
    FROM prodotti_ordinati
)

SELECT
    mt.totale_prodotti,
    ROUND(mt.fatturato_totale, 2) AS fatturato_totale,

    ROUND(
        SAFE_DIVIDE(
            SUM(IF(
                po.posizione <= CEIL(mt.totale_prodotti * 0.01),
                po.fatturato,
                0
            )),
            mt.fatturato_totale
        ) * 100,
        2
    ) AS quota_top_1_percento,

    ROUND(
        SAFE_DIVIDE(
            SUM(IF(
                po.posizione <= CEIL(mt.totale_prodotti * 0.05),
                po.fatturato,
                0
            )),
            mt.fatturato_totale
        ) * 100,
        2
    ) AS quota_top_5_percento,

    ROUND(
        SAFE_DIVIDE(
            SUM(IF(
                po.posizione <= CEIL(mt.totale_prodotti * 0.10),
                po.fatturato,
                0
            )),
            mt.fatturato_totale
        ) * 100,
        2
    ) AS quota_top_10_percento,

    ROUND(
        SAFE_DIVIDE(
            SUM(IF(
                po.posizione <= CEIL(mt.totale_prodotti * 0.20),
                po.fatturato,
                0
            )),
            mt.fatturato_totale
        ) * 100,
        2
    ) AS quota_top_20_percento,

    MIN(IF(
        po.fatturato_cumulativo >= mt.fatturato_totale * 0.50,
        po.posizione,
        NULL
    )) AS prodotti_per_50_percento,

    MIN(IF(
        po.fatturato_cumulativo >= mt.fatturato_totale * 0.80,
        po.posizione,
        NULL
    )) AS prodotti_per_80_percento,

    MIN(IF(
        po.fatturato_cumulativo >= mt.fatturato_totale * 0.90,
        po.posizione,
        NULL
    )) AS prodotti_per_90_percento

FROM prodotti_ordinati po
CROSS JOIN metriche_totali mt
GROUP BY
    mt.totale_prodotti,
    mt.fatturato_totale;

-- RISULTATI E CONSIDERAZIONI:
-- L'analisi considera 32.216 prodotti con almeno una
-- riga di vendita associata a ordini consegnati.
-- Il primo 1% dei prodotti genera il 24,49% del
-- fatturato complessivo, mentre il primo 10% contribuisce
-- per il 60,85%.
-- Il 20% dei prodotti genera il 74,82% dei ricavi.
-- Per raggiungere l'80% del fatturato sono necessari
-- 8.352 prodotti, pari al 25,93% del totale.
-- La distribuzione evidenzia una concentrazione
-- significativa del fatturato su una parte del catalogo,
-- pur non rispettando esattamente la regola classica 80/20.
-- I risultati possono supportare decisioni di
-- assortimento e monitoraggio dei prodotti strategici.
-- La concentrazione dei ricavi non equivale tuttavia
-- alla concentrazione della redditività.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Fatturato per categoria e fascia di prezzo
-- Analisi congiunta delle categorie merceologiche e
-- delle fasce di prezzo dei prodotti venduti.
-- L'obiettivo è comprendere quali fasce di prezzo
-- contribuiscono maggiormente al fatturato di ciascuna
-- categoria e individuare differenti strutture commerciali.
-- =====================================================

WITH vendite AS (
    SELECT
        COALESCE(
            ct.string_field_1,
            p.product_category_name,
            'Non classificato'
        ) AS categoria,

        CASE
            WHEN oi.price <= 50 THEN '1. Economica'
            WHEN oi.price <= 100 THEN '2. Medio-bassa'
            WHEN oi.price <= 250 THEN '3. Media'
            WHEN oi.price <= 500 THEN '4. Medio-alta'
            ELSE '5. Premium'
        END AS fascia_prezzo,

        oi.price,
        oi.order_id

    FROM `business-performance-analytics.olist_analytics.orders` o

    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id

    INNER JOIN `business-performance-analytics.olist_analytics.products` p
        ON oi.product_id = p.product_id

    LEFT JOIN `business-performance-analytics.olist_analytics.category_translation` ct
        ON p.product_category_name = ct.string_field_0

    WHERE o.order_status = 'delivered'
),

aggregazione AS (
    SELECT
        categoria,
        fascia_prezzo,
        COUNT(*) AS numero_articoli,
        COUNT(DISTINCT order_id) AS numero_ordini,
        SUM(price) AS fatturato,
        AVG(price) AS prezzo_medio

    FROM vendite
    GROUP BY
        categoria,
        fascia_prezzo
)

SELECT
    categoria,
    fascia_prezzo,
    numero_articoli,
    numero_ordini,

    ROUND(fatturato, 2) AS fatturato,

    ROUND(prezzo_medio, 2) AS prezzo_medio,

    ROUND(
        SAFE_DIVIDE(
            fatturato,
            SUM(fatturato) OVER (PARTITION BY categoria)
        ) * 100,
        2
    ) AS percentuale_fatturato_categoria

FROM aggregazione

ORDER BY
    categoria,
    fascia_prezzo;

-- RISULTATI E CONSIDERAZIONI:
-- L'analisi evidenzia differenti strutture di fatturato
-- tra le categorie merceologiche.
-- Computers genera il 99,98% del proprio fatturato
-- nella fascia premium, mentre Computers Accessories
-- presenta una maggiore diversificazione, con il 42,58%
-- dei ricavi provenienti dalla fascia media.
-- Health & Beauty mostra una distribuzione più equilibrata:
-- le fasce media, medio-alta e premium contribuiscono
-- complessivamente per il 74,37% al fatturato.
-- Bed Bath Table dipende prevalentemente dalle fasce
-- medio-bassa e media, che insieme rappresentano il 78,38%
-- dei ricavi della categoria.
-- Watches & Gifts genera il 75,48% del fatturato
-- attraverso le fasce media e premium.
-- I risultati evidenziano mix commerciali differenti
-- e possono supportare decisioni relative ad assortimento,
-- posizionamento dei prodotti e strategie di vendita.
-- Le percentuali devono essere interpretate considerando
-- anche il numero di righe di vendita e di ordini.
-- L'analisi misura il fatturato e non la redditività.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Valore medio degli ordini e composizione carrello
-- Aggregazione delle righe di vendita a livello di ordine
-- e calcolo dei principali indicatori di acquisto.
-- L'obiettivo è misurare la spesa media per ordine,
-- il peso delle spedizioni e la composizione dei carrelli.
-- =====================================================

WITH ordini AS (
    SELECT
        o.order_id,
        SUM(oi.price) AS valore_prodotti,
        SUM(oi.freight_value) AS valore_spedizione,
        COUNT(*) AS numero_righe
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
)

SELECT
    COUNT(*) AS numero_ordini,

    ROUND(SUM(valore_prodotti), 2) AS fatturato_prodotti,
    ROUND(SUM(valore_spedizione), 2) AS totale_spedizioni,
    ROUND(SUM(valore_prodotti + valore_spedizione), 2)
        AS valore_complessivo,

    ROUND(AVG(valore_prodotti), 2) AS valore_medio_ordine,
    ROUND(AVG(valore_spedizione), 2) AS spedizione_media_ordine,
    ROUND(AVG(valore_prodotti + valore_spedizione), 2)
        AS valore_medio_ordine_inclusa_spedizione,

    ROUND(AVG(numero_righe), 2) AS righe_medie_per_ordine,
    ROUND(AVG(valore_prodotti / numero_righe), 2)
        AS valore_medio_per_riga,

    ROUND(
        SAFE_DIVIDE(
            SUM(valore_spedizione),
            SUM(valore_prodotti)
        ) * 100,
        2
    ) AS incidenza_spedizioni_su_prodotti,

    ROUND(
        APPROX_QUANTILES(valore_prodotti, 100)[OFFSET(50)],
        2
    ) AS mediana_valore_ordine

FROM ordini;
-- RISULTATI:
-- L'analisi dei 96.478 ordini consegnati evidenzia un valore medio
-- dei prodotti per ordine (AOV) pari a €137,04 e una mediana di €86,60.
-- La differenza tra i due indicatori suggerisce la presenza di ordini
-- di importo elevato che contribuiscono ad aumentare la media.
-- Il valore medio dell'ordine, includendo le spedizioni, raggiunge
-- €159,83. Le spese di spedizione ammontano mediamente a €22,79
-- per ordine e rappresentano il 16,63% del valore dei prodotti.
-- La composizione del carrello evidenzia una media di 1,14 righe
-- di vendita per ordine. Il valore medio per riga è pari a €125,23.
-- Il numero di righe non rappresenta necessariamente le unità fisiche
-- acquistate, poiché il dataset non contiene una colonna quantità.
-- Nel complesso, emerge un carrello mediamente poco articolato e una
-- distribuzione del valore degli ordini influenzata dagli acquisti
-- di importo più elevato.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Distribuzione degli ordini per fascia di valore
-- Classificazione degli ordini consegnati in fasce di spesa
-- sulla base del valore dei prodotti, esclusa la spedizione.
-- L'obiettivo è analizzare la distribuzione degli ordini
-- e il contributo di ciascuna fascia al fatturato totale.
-- =====================================================

WITH ordini AS (
    SELECT
        o.order_id,
        SUM(oi.price) AS valore_ordine
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
),

ordini_classificati AS (
    SELECT
        order_id,
        valore_ordine,
        CASE
            WHEN valore_ordine <= 50 THEN 'Economica'
            WHEN valore_ordine <= 100 THEN 'Medio-bassa'
            WHEN valore_ordine <= 250 THEN 'Media'
            WHEN valore_ordine <= 500 THEN 'Medio-alta'
            ELSE 'Premium'
        END AS fascia_valore
    FROM ordini
),

riepilogo AS (
    SELECT
        fascia_valore,
        COUNT(*) AS numero_ordini,
        SUM(valore_ordine) AS fatturato,
        AVG(valore_ordine) AS valore_medio_ordine
    FROM ordini_classificati
    GROUP BY fascia_valore
)

SELECT
    fascia_valore,
    numero_ordini,

    ROUND(
        SAFE_DIVIDE(
            numero_ordini,
            SUM(numero_ordini) OVER ()
        ) * 100,
        2
    ) AS percentuale_ordini,

    ROUND(fatturato, 2) AS fatturato,

    ROUND(
        SAFE_DIVIDE(
            fatturato,
            SUM(fatturato) OVER ()
        ) * 100,
        2
    ) AS percentuale_fatturato,

    ROUND(valore_medio_ordine, 2) AS valore_medio_ordine

FROM riepilogo
ORDER BY
    CASE fascia_valore
        WHEN 'Economica' THEN 1
        WHEN 'Medio-bassa' THEN 2
        WHEN 'Media' THEN 3
        WHEN 'Medio-alta' THEN 4
        WHEN 'Premium' THEN 5
    END;
    
-- RISULTATI:
-- La distribuzione degli ordini evidenzia una concentrazione
-- del numero di acquisti nelle fasce economica, medio-bassa
-- e media, che rappresentano complessivamente l'89,16% degli ordini.
-- Le prime due fasce raccolgono il 58,72% degli ordini,
-- ma generano soltanto il 22,86% del fatturato.
-- La fascia media (100,01-250 euro) costituisce il principale
-- contributore al fatturato, con una quota del 34,58%.
-- Particolarmente rilevante è il contributo degli ordini
-- superiori a 250 euro: rappresentano soltanto il 10,84%
-- degli ordini, ma generano il 42,56% del fatturato totale.
-- La sola fascia premium (>500 euro) contribuisce per il
-- 24,53% al fatturato, pur rappresentando il 3,60% degli ordini.
-- I risultati confermano che il valore medio degli ordini
-- è influenzato dagli acquisti di importo elevato.
-- L'analisi riguarda il fatturato dei prodotti e non consente
-- di valutare la redditività delle diverse fasce.

-- =====================================================
-- FASE 3: ANALISI ESPLORATIVA E PERFORMANCE COMMERCIALE
-- ANALISI: Comportamento temporale degli acquisti
-- Analisi della distribuzione degli ordini e del fatturato
-- per giorno della settimana e fascia oraria di acquisto.
-- L'obiettivo è individuare eventuali concentrazioni
-- temporali e differenze nel valore medio degli ordini.
-- =====================================================

WITH ordini AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS valore_ordine
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        o.order_purchase_timestamp
),

ordini_temporali AS (
    SELECT
        order_id,
        valore_ordine,

        CASE EXTRACT(DAYOFWEEK FROM order_purchase_timestamp)
            WHEN 1 THEN 'Domenica'
            WHEN 2 THEN 'Lunedì'
            WHEN 3 THEN 'Martedì'
            WHEN 4 THEN 'Mercoledì'
            WHEN 5 THEN 'Giovedì'
            WHEN 6 THEN 'Venerdì'
            WHEN 7 THEN 'Sabato'
        END AS giorno_settimana,

        EXTRACT(DAYOFWEEK FROM order_purchase_timestamp)
            AS numero_giorno,

        CASE
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp)
                BETWEEN 0 AND 5 THEN 'Notte'
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp)
                BETWEEN 6 AND 11 THEN 'Mattina'
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp)
                BETWEEN 12 AND 17 THEN 'Pomeriggio'
            ELSE 'Sera'
        END AS fascia_oraria,

        EXTRACT(HOUR FROM order_purchase_timestamp)
            AS ora_acquisto

    FROM ordini
),

segmenti AS (
    SELECT
        'Giorno settimana' AS tipo_analisi,
        giorno_settimana AS segmento,
        numero_giorno AS ordine_segmento,
        COUNT(*) AS numero_ordini,
        SUM(valore_ordine) AS fatturato,
        AVG(valore_ordine) AS aov
    FROM ordini_temporali
    GROUP BY giorno_settimana, numero_giorno

    UNION ALL

    SELECT
        'Fascia oraria' AS tipo_analisi,
        fascia_oraria AS segmento,
        CASE fascia_oraria
            WHEN 'Notte' THEN 1
            WHEN 'Mattina' THEN 2
            WHEN 'Pomeriggio' THEN 3
            WHEN 'Sera' THEN 4
        END AS ordine_segmento,
        COUNT(*) AS numero_ordini,
        SUM(valore_ordine) AS fatturato,
        AVG(valore_ordine) AS aov
    FROM ordini_temporali
    GROUP BY fascia_oraria
)

SELECT
    tipo_analisi,
    segmento,
    numero_ordini,

    ROUND(
        SAFE_DIVIDE(
            numero_ordini,
            SUM(numero_ordini) OVER (PARTITION BY tipo_analisi)
        ) * 100,
        2
    ) AS percentuale_ordini,

    ROUND(fatturato, 2) AS fatturato,

    ROUND(
        SAFE_DIVIDE(
            fatturato,
            SUM(fatturato) OVER (PARTITION BY tipo_analisi)
        ) * 100,
        2
    ) AS percentuale_fatturato,

    ROUND(aov, 2) AS valore_medio_ordine

FROM segmenti
ORDER BY
    tipo_analisi,
    ordine_segmento;

-- RISULTATI:
-- L'analisi temporale evidenzia una maggiore concentrazione
-- degli acquisti nel pomeriggio, che rappresenta il 38,54%
-- degli ordini e il 39,26% del fatturato.
-- La sera costituisce la seconda fascia per attività,
-- con il 34,32% degli ordini e il 34,22% del fatturato.
-- L'AOV più elevato si registra nel pomeriggio (€139,59),
-- mentre quello più basso si osserva durante la notte (€127,78).
--
-- Per quanto riguarda i giorni della settimana, il lunedì
-- registra il maggior numero di ordini (16,27%), seguito
-- dal martedì (16,07%). Il sabato presenta il volume più basso
-- (10,94%).
-- Il valore medio degli ordini risulta relativamente stabile
-- durante la settimana, con il massimo il venerdì (€139,61)
-- e il minimo la domenica (€132,84).
-- Nel complesso, gli acquisti si concentrano prevalentemente
-- nel pomeriggio e nella prima parte della settimana.
-- Le differenze osservate sono descrittive e non dimostrano
-- relazioni causali tra momento dell'acquisto e valore dell'ordine.

-- =====================================================
-- FASE 3: CONTROLLO FINALE E VALIDAZIONE KPI
-- ANALISI: Verifica di coerenza degli indicatori principali
-- Ricalcolo degli indicatori commerciali sugli ordini
-- consegnati e confronto tra valori aggregati.
-- L'obiettivo è verificare la consistenza dei KPI
-- utilizzati nelle precedenti analisi esplorative.
-- =====================================================

WITH ordini AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS fatturato_prodotti,
        SUM(oi.freight_value) AS spedizioni,
        COUNT(*) AS righe_vendita
    FROM `business-performance-analytics.olist_analytics.orders` o
    INNER JOIN `business-performance-analytics.olist_analytics.order_items` oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        o.order_purchase_timestamp
),

fasce_valore AS (
    SELECT
        CASE
            WHEN fatturato_prodotti <= 50 THEN 'Economica'
            WHEN fatturato_prodotti <= 100 THEN 'Medio-bassa'
            WHEN fatturato_prodotti <= 250 THEN 'Media'
            WHEN fatturato_prodotti <= 500 THEN 'Medio-alta'
            ELSE 'Premium'
        END AS fascia_valore,
        COUNT(*) AS numero_ordini,
        SUM(fatturato_prodotti) AS fatturato
    FROM ordini
    GROUP BY fascia_valore
),

fasce_orarie AS (
    SELECT
        CASE
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp)
                BETWEEN 0 AND 5 THEN 'Notte'
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp)
                BETWEEN 6 AND 11 THEN 'Mattina'
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp)
                BETWEEN 12 AND 17 THEN 'Pomeriggio'
            ELSE 'Sera'
        END AS fascia_oraria,
        COUNT(*) AS numero_ordini,
        SUM(fatturato_prodotti) AS fatturato
    FROM ordini
    GROUP BY fascia_oraria
),

giorni AS (
    SELECT
        EXTRACT(DAYOFWEEK FROM order_purchase_timestamp)
            AS giorno_settimana,
        COUNT(*) AS numero_ordini,
        SUM(fatturato_prodotti) AS fatturato
    FROM ordini
    GROUP BY giorno_settimana
)

SELECT
    'KPI GENERALI' AS controllo,
    COUNT(*) AS numero_ordini,
    SUM(righe_vendita) AS righe_vendita,
    ROUND(SUM(fatturato_prodotti), 2) AS fatturato,
    ROUND(SUM(spedizioni), 2) AS spedizioni,
    ROUND(AVG(fatturato_prodotti), 2) AS aov,
    ROUND(AVG(fatturato_prodotti + spedizioni), 2)
        AS aov_inclusa_spedizione,
    ROUND(
        SAFE_DIVIDE(SUM(spedizioni), SUM(fatturato_prodotti)) * 100,
        2
    ) AS incidenza_spedizioni,
    CAST(NULL AS INT64) AS numero_segmenti,
    CAST(NULL AS FLOAT64) AS somma_percentuali
FROM ordini

UNION ALL

SELECT
    'FASCE VALORE',
    SUM(numero_ordini),
    CAST(NULL AS INT64),
    ROUND(SUM(fatturato), 2),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    COUNT(*),
    ROUND(
        SAFE_DIVIDE(SUM(numero_ordini),
            (SELECT COUNT(*) FROM ordini)) * 100,
        2
    )
FROM fasce_valore

UNION ALL

SELECT
    'FASCE ORARIE',
    SUM(numero_ordini),
    CAST(NULL AS INT64),
    ROUND(SUM(fatturato), 2),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    COUNT(*),
    ROUND(
        SAFE_DIVIDE(SUM(numero_ordini),
            (SELECT COUNT(*) FROM ordini)) * 100,
        2
    )
FROM fasce_orarie

UNION ALL

SELECT
    'GIORNI SETTIMANA',
    SUM(numero_ordini),
    CAST(NULL AS INT64),
    ROUND(SUM(fatturato), 2),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    COUNT(*),
    ROUND(
        SAFE_DIVIDE(SUM(numero_ordini),
            (SELECT COUNT(*) FROM ordini)) * 100,
        2
    )
FROM giorni;

-- =====================================================
-- CONCLUSIONE FASE 3: ANALISI ESPLORATIVA E PERFORMANCE
-- =====================================================
-- La fase esplorativa ha permesso di analizzare le principali
-- dimensioni commerciali, geografiche, logistiche e temporali
-- del dataset Olist.
-- Il controllo finale ha confermato la coerenza dei principali
-- indicatori: 96.478 ordini consegnati, 110.197 righe di vendita,
-- €13.221.498,11 di fatturato prodotti e €2.198.275,64
-- di spedizioni registrate.
-- Il valore medio degli ordini è pari a €137,04, mentre
-- includendo le spedizioni raggiunge €159,83.
-- Le distribuzioni per fascia di valore, fascia oraria
-- e giorno della settimana riconciliano correttamente
-- con il totale degli ordini e del fatturato.
-- Le analisi hanno evidenziato differenze nella distribuzione
-- del fatturato tra categorie, aree geografiche, fasce di spesa
-- e segmenti temporali, oltre a relazioni tra puntualità
-- delle consegne e soddisfazione dei clienti.
-- I risultati sono di natura descrittiva e devono essere
-- interpretati considerando i limiti del dataset.
-- La Fase 3 è completata. I risultati costituiscono la base
-- per la successiva modellazione dei dati e la realizzazione
-- della dashboard in Power BI.
-- =====================================================