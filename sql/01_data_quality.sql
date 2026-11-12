
--conteggio delle righe per tabella

SELECT 'orders' AS tabella, COUNT(*) AS numero_righe
FROM `business-performance-analytics.olist_analytics.orders`

UNION ALL

SELECT 'order_items', COUNT(*)
FROM `business-performance-analytics.olist_analytics.order_items`

UNION ALL

SELECT 'customers', COUNT(*)
FROM `business-performance-analytics.olist_analytics.customers`

UNION ALL

SELECT 'products', COUNT(*)
FROM `business-performance-analytics.olist_analytics.products`

UNION ALL

SELECT 'category_translation', COUNT(*)
FROM `business-performance-analytics.olist_analytics.category_translation`

UNION ALL

SELECT 'orders_reviews', COUNT(*)
FROM `business-performance-analytics.olist_analytics.orders_reviews`

ORDER BY tabella;


-- =====================================================
-- PROGETTO: Business Performance Analytics
-- FASE 1: Data Quality
-- TABELLA: orders
-- ANALISI: Controllo delle chiavi identificative
-- =====================================================
-- Obiettivo:
-- Verificare la completezza delle chiavi e l'unicità
-- degli identificativi degli ordini.
-- Perché:
-- Eventuali order_id mancanti o duplicati possono
-- compromettere il conteggio degli ordini e le analisi
-- successive basate sull'identificativo dell'ordine.

SELECT
    COUNT(*) AS numero_righe,
    COUNTIF(order_id IS NULL) AS order_id_null,
    COUNTIF(customer_id IS NULL) AS customer_id_null,
    COUNT(DISTINCT order_id) AS order_id_distinti,
    COUNT(DISTINCT customer_id) AS customer_id_distinti
FROM
    `business-performance-analytics.olist_analytics.orders`;

-- Esito dell'analisi:
-- Il controllo della tabella orders ha restituito un esito positivo.
-- La tabella contiene 99.441 righe e altrettanti order_id distinti.
-- Non sono stati rilevati valori nulli nei campi order_id e customer_id.
-- Ogni ordine è quindi identificato da una chiave univoca e associato
-- a un identificativo cliente.
-- Non emergono anomalie di completezza o duplicazione nelle chiavi
-- analizzate. Restano da verificare la coerenza delle date, la
-- distribuzione degli stati degli ordini e le relazioni con le altre
-- tabelle del dataset.


-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: ORDERS
-- ANALISI: Distribuzione degli stati degli ordini
-- =====================================================

-- Obiettivo:
-- Contare quanti ordini appartengono a ciascuno stato.

-- Motivazione:
-- La distribuzione degli stati ci aiuta a comprendere
-- la composizione degli ordini e a definire in seguito
-- il perimetro delle analisi commerciali e logistiche.

SELECT
    order_status,
    COUNT(*) AS numero_ordini
FROM
    `business-performance-analytics.olist_analytics.orders`
GROUP BY
    order_status
ORDER BY
    numero_ordini DESC;

-- Esito dell'analisi:
-- La distribuzione degli stati evidenzia una netta prevalenza
-- di ordini consegnati, pari a 96.478 record su 99.441,
-- corrispondenti a circa il 97,02% del totale.
-- Gli ordini con stato diverso da delivered sono 2.963 e
-- comprendono ordini spediti, annullati, non disponibili
-- o ancora in una fase precedente del processo.
-- Queste categorie devono essere distinte nelle successive
-- analisi commerciali e logistiche, evitando di considerare
-- automaticamente tutti gli ordini non consegnati come falliti.
-- La distribuzione osservata descrive la composizione del dataset
-- e non costituisce, da sola, una valutazione della qualità
-- o dell'efficienza del processo di vendita.


-- ANALISI: Completezza delle date
-- Obiettivo:
-- Contare i valori mancanti nelle cinque colonne temporali.

-- Motivazione:
-- Le date mancanti possono limitare le analisi sui tempi
-- di approvazione, spedizione e consegna.
-- Il controllo serve a individuare le colonne da approfondire,
-- senza classificare automaticamente ogni valore mancante
-- come un errore.

SELECT
    COUNT(*) AS numero_ordini,
    COUNTIF(order_purchase_timestamp IS NULL)
        AS acquisto_null,
    COUNTIF(order_approved_at IS NULL)
        AS approvazione_null,
    COUNTIF(order_delivered_carrier_date IS NULL)
        AS affidamento_corriere_null,
    COUNTIF(order_delivered_customer_date IS NULL)
        AS consegna_effettiva_null,
    COUNTIF(order_estimated_delivery_date IS NULL)
        AS consegna_stimata_null
FROM
    `business-performance-analytics.olist_analytics.orders`;

-- Esito dell'analisi:
-- Il controllo della completezza delle date evidenzia che tutti
-- i 99.441 ordini dispongono della data di acquisto e della data
-- di consegna stimata. Sono invece presenti 160 valori mancanti
-- nella data di approvazione, 1.783 nella data di affidamento
-- al corriere e 2.965 nella data di consegna effettiva.
-- L'assenza di queste informazioni può limitare alcune analisi
-- temporali, in particolare la misurazione dei tempi di consegna.
-- I valori mancanti non vengono considerati automaticamente
-- errori, poiché potrebbero essere coerenti con lo stato
-- dell'ordine. Sarà quindi necessario verificare la loro
-- distribuzione tra gli stati prima di valutarne l'impatto.


-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders
-- ANALISI: Date mancanti per stato dell'ordine
-- =====================================================

-- Obiettivo:
-- Verificare come si distribuiscono le date mancanti
-- nei diversi stati degli ordini.

-- Motivazione:
-- Una data mancante può essere coerente con un ordine
-- non ancora consegnato o annullato.
-- La sua assenza in un ordine dichiarato delivered
-- richiede invece un controllo più approfondito.

SELECT
    order_status,
    COUNT(*) AS numero_ordini,
    COUNTIF(order_delivered_carrier_date IS NULL)
        AS affidamento_corriere_mancante,
    COUNTIF(order_delivered_customer_date IS NULL)
        AS consegna_effettiva_mancante
FROM
    `business-performance-analytics.olist_analytics.orders`
GROUP BY
    order_status
ORDER BY
    numero_ordini DESC;

-- Esito dell'analisi:
-- Il confronto tra gli stati degli ordini e le date di
-- spedizione e consegna mostra una distribuzione generalmente
-- coerente con le diverse fasi del processo.
-- Tutti i 1.107 ordini con stato shipped presentano la data
-- di affidamento al corriere, ma non la data di consegna effettiva.
-- Per gli ordini con stato delivered sono presenti 8 date di
-- consegna mancanti e 2 date di affidamento al corriere mancanti.
-- Questi record richiedono un approfondimento, poiché lo stato
-- indica che la consegna è avvenuta.
-- Tra i 625 ordini canceled, 619 non presentano la data di
-- consegna effettiva, mentre 6 la riportano.
-- Quest'ultima situazione deve essere verificata per valutare
-- la coerenza tra stato dell'ordine e informazioni temporali.
-- Le date mancanti negli altri stati possono essere compatibili
-- con ordini che non hanno raggiunto la fase di consegna.
-- Il controllo individua quindi alcuni casi da approfondire,
-- senza consentire da solo di stabilire se siano errori effettivi.


-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders
-- ANALISI: Coerenza cronologica delle date
-- =====================================================

-- Obiettivo:
-- Individuare ordini con date che non rispettano
-- la sequenza temporale attesa del processo.

-- Motivazione:
-- Una sequenza cronologica incoerente può indicare
-- anomalie nei dati o situazioni da approfondire.
-- Il controllo riguarda soltanto le date presenti.

SELECT
    COUNT(*) AS numero_ordini,

    COUNTIF(
        order_approved_at < order_purchase_timestamp
    ) AS approvazione_prima_acquisto,

    COUNTIF(
        order_delivered_carrier_date < order_purchase_timestamp
    ) AS corriere_prima_acquisto,

    COUNTIF(
        order_delivered_customer_date < order_delivered_carrier_date
    ) AS consegna_prima_affidamento,

    COUNTIF(
        order_delivered_customer_date < order_purchase_timestamp
    ) AS consegna_prima_acquisto

FROM
    `business-performance-analytics.olist_analytics.orders`;

-- Esito dell'analisi:
-- Il controllo della coerenza cronologica delle date ha evidenziato 166 ordini con data di affidamento al corriere precedente alla data
-- di acquisto e 23 ordini con data di consegna al cliente precedente alla data di affidamento al corriere.
-- Non sono stati rilevati ordini con data di approvazione precedente alla data di acquisto né ordini con data di consegna precedente
-- alla data di acquisto. Le anomalie individuate richiedono un approfondimento sui singoli
-- record per verificare la loro natura e le possibili cause. I conteggi non devono essere sommati senza verificare l'eventuale
-- sovrapposizione tra gli insiemi di ordini interessati. Non sono state apportate modifiche ai dati.


-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders
-- ANALISI: Identificazione delle date incoerenti
-- =====================================================

-- Obiettivo:
-- Estrarre gli ordini che presentano almeno una delle
-- anomalie cronologiche individuate nel controllo precedente.

-- Motivazione:
-- L'esame dei singoli record permette di confrontare le date,
-- verificare lo stato dell'ordine e individuare eventuali
-- sovrapposizioni tra le due categorie di anomalie.

SELECT DISTINCT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    -- Indica se l'affidamento al corriere precede l'acquisto.
    order_delivered_carrier_date < order_purchase_timestamp
        AS anomalia_corriere_prima_acquisto,

    -- Indica se la consegna al cliente precede l'affidamento.
    order_delivered_customer_date < order_delivered_carrier_date
        AS anomalia_consegna_prima_affidamento

FROM
    `business-performance-analytics.olist_analytics.orders`

WHERE
    order_delivered_carrier_date < order_purchase_timestamp
    OR order_delivered_customer_date < order_delivered_carrier_date

ORDER BY
    order_purchase_timestamp;

-- Esito dell'analisi:
-- L'estrazione ha restituito 189 ordini distinti con almeno una delle due anomalie cronologiche esaminate.
-- In particolare, 166 ordini presentano una data di affidamento al corriere precedente alla data di acquisto, mentre 23 ordini presentano una -- data di consegna al cliente precedente alla data di affidamento al corriere. I due gruppi risultano distinti nei record estratti.
-- Dei 189 ordini, 188 hanno stato delivered e uno ha stato shipped. Alcune differenze temporali sono contenute, mentre almeno
-- un record presenta una discrepanza di diversi mesi tra la data di acquisto e quella di affidamento al corriere. 
-- Le anomalie richiedono ulteriori verifiche per distinguere eventuali problemi nei dati da possibili particolarità nella registrazione 
-- degli eventi. Non sono state apportate modifiche alla tabella originale.
-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders
-- ANALISI: Entità delle anomalie temporali
-- =====================================================

-- Obiettivo:
-- Misurare quanto la data di affidamento al corriere
-- precede la data di acquisto nei record anomali.

SELECT
    CASE
        WHEN minuti_anomalia <= 60
            THEN 'Entro 1 ora'
        WHEN minuti_anomalia <= 1440
            THEN 'Da 1 a 24 ore'
        ELSE 'Oltre 24 ore'
    END AS fascia_temporale,
    COUNT(*) AS numero_ordini
FROM (
    SELECT
        TIMESTAMP_DIFF(
            order_purchase_timestamp,
            order_delivered_carrier_date,
            MINUTE
        ) AS minuti_anomalia
    FROM
        `business-performance-analytics.olist_analytics.orders`
    WHERE
        order_delivered_carrier_date < order_purchase_timestamp
)
GROUP BY
    fascia_temporale
ORDER BY
    numero_ordini DESC;

-- Esito dell'analisi:
-- Dei 166 ordini con data di affidamento al corriere precedente alla data di acquisto, 124 presentano una differenza entro un'ora,
-- 40 tra un'ora e 24 ore e 2 superiore a 24 ore. Le anomalie sono prevalentemente concentrate in intervalli brevi,
-- ma la loro causa non è determinabile con i controlli effettuati. I record sono mantenuti invariati e le anomalie saranno 
-- tenute in considerazione nelle successive analisi.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: order_items
-- ANALISI: Completezza e validità dei dati
-- =====================================================

-- Obiettivo:
-- Verificare i valori mancanti negli identificativi
-- e individuare prezzi o costi di spedizione non validi.

SELECT
    COUNT(*) AS numero_righe,

    COUNTIF(order_id IS NULL) AS order_id_null,
    COUNTIF(order_item_id IS NULL) AS order_item_id_null,
    COUNTIF(product_id IS NULL) AS product_id_null,
    COUNTIF(seller_id IS NULL) AS seller_id_null,

    COUNTIF(shipping_limit_date IS NULL)
        AS shipping_limit_date_null,

    COUNTIF(price IS NULL) AS price_null,
    COUNTIF(price <= 0) AS price_non_positivo,

    COUNTIF(freight_value IS NULL) AS freight_value_null,
    COUNTIF(freight_value < 0) AS freight_value_negativo

FROM
    `business-performance-analytics.olist_analytics.order_items`;

-- Esito dell'analisi:
-- La tabella order_items contiene 112.650 righe. Non sono stati rilevati valori mancanti negli identificativi,
-- nella data limite di spedizione, nei prezzi o nei costi di spedizione. Non sono presenti prezzi nulli o non positivi
-- né costi di spedizione nulli o negativi. I controlli di completezza e validità effettuati hanno dato esito positivo.
-- Restano da verificare l'unicità delle righe e la coerenza delle relazioni con le altre tabelle del dataset.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: order_items
-- ANALISI: Unicità della chiave composta
-- =====================================================

SELECT
    (SELECT COUNT(*)
     FROM `business-performance-analytics.olist_analytics.order_items`)
        AS numero_righe_totali,

    COUNT(*) AS combinazioni_distinte,

    COUNTIF(numero_occorrenze > 1)
        AS combinazioni_duplicate,

    SUM(numero_occorrenze - 1)
        AS righe_duplicate
FROM (
    SELECT
        order_id,
        order_item_id,
        COUNT(*) AS numero_occorrenze
    FROM
        `business-performance-analytics.olist_analytics.order_items`
    GROUP BY
        order_id,
        order_item_id);

-- Esito dell'analisi:
-- La tabella order_items contiene 112.650 righe e altrettante combinazioni distinte di order_id e order_item_id.
-- Non sono state rilevate combinazioni duplicate, pertanto la chiave composta risulta univoca per tutte le righe.
-- Il controllo conferma che ogni posizione articolo è identificata univocamente all'interno del relativo ordine.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLE: order_items e orders
-- ANALISI: Coerenza della data limite di spedizione
-- =====================================================

-- Obiettivo:
-- Individuare gli articoli con data limite di spedizione
-- precedente alla data di acquisto dell'ordine associato.

SELECT
    COUNT(*) AS numero_articoli,
    COUNTIF(
        oi.shipping_limit_date < o.order_purchase_timestamp
    ) AS date_limite_precedenti_acquisto
FROM
    `business-performance-analytics.olist_analytics.order_items` AS oi
INNER JOIN
    `business-performance-analytics.olist_analytics.orders` AS o
    ON oi.order_id = o.order_id;
-- Esito dell'analisi:
-- La INNER JOIN tra order_items e orders ha restituito 112.650 righe articolo.
-- Non sono state rilevate date limite di spedizione precedenti alla data di acquisto dell'ordine associato.
-- Il controllo non ha evidenziato anomalie cronologiche in questo confronto e conferma la corrispondenza
-- degli articoli con i rispettivi ordini. La verifica riguarda esclusivamente le date confrontate.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: products
-- ANALISI: Completezza e validità dei dati
-- =====================================================

-- Obiettivo:
-- Controllare gli identificativi, i valori mancanti
-- e i valori non positivi nelle colonne numeriche.

SELECT
    COUNT(*) AS numero_righe,
    COUNT(DISTINCT product_id) AS product_id_distinti,
    COUNTIF(product_id IS NULL) AS product_id_null,

    COUNTIF(product_category_name IS NULL)
        AS categoria_null,

    COUNTIF(product_name_lenght IS NULL)
        AS nome_lunghezza_null,
    COUNTIF(product_name_lenght <= 0)
        AS nome_lunghezza_non_positiva,

    COUNTIF(product_description_lenght IS NULL)
        AS descrizione_lunghezza_null,
    COUNTIF(product_description_lenght <= 0)
        AS descrizione_lunghezza_non_positiva,

    COUNTIF(product_photos_qty IS NULL)
        AS foto_null,
    COUNTIF(product_photos_qty < 0)
        AS foto_negative,

    COUNTIF(product_weight_g IS NULL)
        AS peso_null,
    COUNTIF(product_weight_g <= 0)
        AS peso_non_positivo,

    COUNTIF(product_length_cm IS NULL)
        AS lunghezza_null,
    COUNTIF(product_length_cm <= 0)
        AS lunghezza_non_positiva,

    COUNTIF(product_height_cm IS NULL)
        AS altezza_null,
    COUNTIF(product_height_cm <= 0)
        AS altezza_non_positiva,

    COUNTIF(product_width_cm IS NULL)
        AS larghezza_null,
    COUNTIF(product_width_cm <= 0)
        AS larghezza_non_positiva

FROM
    `business-performance-analytics.olist_analytics.products`;

-- Esito dell'analisi:
-- La tabella products contiene 32.951 righe, con altrettanti product_id distinti e nessun identificativo nullo.
-- Sono presenti 610 prodotti senza categoria, lunghezza del nome, lunghezza della descrizione e numero di foto.
-- Due prodotti non hanno peso e dimensioni registrati, mentre quattro presentano un peso non positivo.
-- Non sono stati rilevati valori non positivi nelle dimensioni né valori negativi nel numero di foto.
-- Le informazioni mancanti possono limitare alcune analisi commerciali e logistiche; i casi individuati saranno
-- considerati nelle successive analisi senza modificare i dati originali.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: products
-- ANALISI: Sovrapposizione dei valori mancanti
-- =====================================================

-- Obiettivo:
-- Verificare se le quattro colonne con 610 valori mancanti
-- presentano le stesse mancanze negli stessi prodotti.

SELECT
    COUNTIF(
        product_category_name IS NULL
        AND product_name_lenght IS NULL
        AND product_description_lenght IS NULL
        AND product_photos_qty IS NULL
    ) AS tutte_e_quattro_null,

    COUNTIF(
        product_category_name IS NULL
        OR product_name_lenght IS NULL
        OR product_description_lenght IS NULL
        OR product_photos_qty IS NULL
    ) AS almeno_una_colonna_null,

    COUNTIF(
        (product_category_name IS NULL)
        != (product_name_lenght IS NULL)
        OR (product_category_name IS NULL)
        != (product_description_lenght IS NULL)
        OR (product_category_name IS NULL)
        != (product_photos_qty IS NULL)
    ) AS mancanze_non_coincidenti

FROM
    `business-performance-analytics.olist_analytics.products`;
-- Esito dell'analisi:
-- Tutti i 610 prodotti privi di categoria presentano anche valori mancanti nella lunghezza del nome,
-- nella lunghezza della descrizione e nel numero di foto. Le quattro mancanze coincidono negli stessi record,
-- senza casi aggiuntivi. Questo suggerisce un unico gruppo di prodotti con informazioni descrittive incomplete.
-- I record saranno mantenuti invariati e tenuti in considerazione nelle successive analisi.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLE: order_items e products
-- ANALISI: Integrità referenziale dei prodotti
-- =====================================================

-- Obiettivo:
-- Verificare che tutti i prodotti presenti negli articoli
-- degli ordini siano registrati nella tabella products.

SELECT
    COUNT(*) AS numero_articoli,
    COUNTIF(p.product_id IS NOT NULL) AS articoli_con_prodotto,
    COUNTIF(p.product_id IS NULL) AS articoli_senza_corrispondenza,
    COUNT(DISTINCT oi.product_id) AS prodotti_distinti_negli_ordini,
    COUNT(DISTINCT p.product_id) AS prodotti_distinti_trovati

FROM
    `business-performance-analytics.olist_analytics.order_items` AS oi

LEFT JOIN
    `business-performance-analytics.olist_analytics.products` AS p
    ON oi.product_id = p.product_id;

-- Esito dell'analisi:
-- Tutti i 112.650 articoli presenti in order_items trovano una corrispondenza nella tabella products.
-- I 32.951 prodotti distinti referenziati negli ordini risultano tutti presenti nell'anagrafica prodotti.
-- Non sono state rilevate anomalie di integrità referenziale nella relazione tra le due tabelle.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: customers
-- ANALISI: Completezza e validità dei dati
-- =====================================================

-- Obiettivo:
-- Verificare identificativi, valori mancanti e completezza
-- delle informazioni geografiche dei clienti.

SELECT
    COUNT(*) AS numero_righe,

    COUNT(DISTINCT customer_id) AS customer_id_distinti,
    COUNTIF(customer_id IS NULL) AS customer_id_null,

    COUNT(DISTINCT customer_unique_id) AS customer_unique_id_distinti,
    COUNTIF(customer_unique_id IS NULL) AS customer_unique_id_null,

    COUNTIF(customer_zip_code_prefix IS NULL) AS cap_null,
    COUNTIF(customer_city IS NULL) AS citta_null,
    COUNTIF(customer_state IS NULL) AS stato_null

FROM
    `business-performance-analytics.olist_analytics.customers`;
-- Esito dell'analisi:
-- La tabella customers contiene 99.441 righe e altrettanti customer_id distinti, senza identificativi nulli.
-- I customer_unique_id distinti sono 96.096, un numero inferiore alle righe totali, compatibile con la presenza
-- di clienti che hanno effettuato più ordini. I campi relativi a CAP, città e stato non presentano valori mancanti.
-- I controlli di completezza effettuati hanno dato esito positivo; resta da verificare la coerenza delle relazioni
-- con la tabella orders.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: customers
-- ANALISI: Verifica dei clienti ricorrenti
-- =====================================================

-- Obiettivo:
-- Individuare customer_unique_id associati a più customer_id
-- e quantificare le righe coinvolte.

WITH clienti AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS numero_record,
        COUNT(DISTINCT customer_id) AS customer_id_distinti
    FROM
        `business-performance-analytics.olist_analytics.customers`
    GROUP BY
        customer_unique_id
)

SELECT
    COUNT(*) AS clienti_unici_totali,

    COUNTIF(numero_record > 1)
        AS clienti_con_piu_record,

    SUM(IF(numero_record > 1, numero_record, 0))
        AS righe_coinvolte,

    SUM(IF(numero_record > 1, numero_record - 1, 0))
        AS righe_in_eccesso,

    COUNTIF(customer_id_distinti > 1)
        AS clienti_con_piu_customer_id

FROM clienti;

-- Esito dell'analisi:
-- Su 96.096 customer_unique_id distinti, 2.997 risultano associati a più record,
-- per un totale di 6.342 righe e 3.345 righe in eccesso rispetto a una riga per cliente.
-- Tutti i clienti ricorrenti presentano più customer_id distinti. Il risultato è compatibile
-- con la struttura del dataset, in cui customer_id identifica il record associato all'ordine
-- e customer_unique_id consente di riconoscere lo stesso cliente. Non sono stati eliminati record.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLE: orders e customers
-- ANALISI: Integrità referenziale dei clienti
-- =====================================================

-- Obiettivo:
-- Verificare che ogni customer_id presente in orders
-- trovi una corrispondenza nella tabella customers.

SELECT
    COUNT(*) AS numero_ordini,
    COUNTIF(c.customer_id IS NOT NULL) AS ordini_con_cliente,
    COUNTIF(c.customer_id IS NULL) AS ordini_senza_corrispondenza,
    COUNT(DISTINCT o.customer_id) AS clienti_distinti_negli_ordini,
    COUNT(DISTINCT c.customer_id) AS clienti_distinti_trovati

FROM
    `business-performance-analytics.olist_analytics.orders` AS o

LEFT JOIN
    `business-performance-analytics.olist_analytics.customers` AS c
    ON o.customer_id = c.customer_id;

-- Esito dell'analisi:
-- Tutti i 99.441 ordini trovano una corrispondenza nella tabella customers.
-- Non sono stati rilevati ordini senza un cliente associato e tutti i customer_id distinti
-- presenti in orders risultano presenti nella tabella customers.
-- Il controllo conferma l'integrità referenziale della relazione tra ordini e clienti.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders_reviews
-- ANALISI: Completezza e validità dei dati
-- =====================================================

-- Obiettivo:
-- Verificare identificativi, valori mancanti e validità
-- del punteggio assegnato alle recensioni.

SELECT
    COUNT(*) AS numero_righe,

    COUNT(DISTINCT review_id) AS review_id_distinti,
    COUNTIF(review_id IS NULL) AS review_id_null,

    COUNTIF(order_id IS NULL) AS order_id_null,

    COUNTIF(review_score IS NULL) AS review_score_null,
    COUNTIF(review_score < 1 OR review_score > 5)
        AS review_score_fuori_intervallo,

    COUNTIF(review_comment_title IS NULL)
        AS titolo_recensione_null,
    COUNTIF(review_comment_message IS NULL)
        AS messaggio_recensione_null

FROM
    `business-performance-analytics.olist_analytics.orders_reviews`;

-- Esito dell'analisi:
-- La tabella orders_reviews contiene 99.224 righe e 98.410 review_id distinti.
-- Non sono presenti identificativi o order_id nulli, né punteggi mancanti o fuori dall'intervallo 1-5.
-- I titoli sono nulli in 87.656 righe e i messaggi in 58.247; trattandosi di campi testuali,
-- tali mancanze non costituiscono necessariamente anomalie.
-- La differenza tra righe totali e identificativi distinti richiede una verifica mirata
-- per distinguere eventuali duplicati da recensioni associate allo stesso identificativo.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders_reviews
-- ANALISI: Verifica dei review_id duplicati
-- =====================================================

-- Obiettivo:
-- Individuare i review_id ripetuti e quantificare
-- le righe in eccesso rispetto a un record per identificativo.

WITH recensioni AS (
    SELECT
        review_id,
        COUNT(*) AS numero_record
    FROM
        `business-performance-analytics.olist_analytics.orders_reviews`
    GROUP BY
        review_id)

SELECT
    COUNT(*) AS review_id_distinti,
    COUNTIF(numero_record > 1) AS review_id_ripetuti,
    SUM(IF(numero_record > 1, numero_record, 0))
        AS righe_con_id_ripetuto,
    SUM(IF(numero_record > 1, numero_record - 1, 0))
        AS righe_in_eccesso,
    MAX(numero_record) AS massimo_record_per_review_id

FROM recensioni;
-- Esito dell'analisi:
-- Sono stati individuati 789 review_id ripetuti, associati a 1.603 righe complessive,
-- con 814 righe in eccesso rispetto a un record per identificativo.
-- Un singolo review_id compare al massimo tre volte.
-- Non è ancora possibile stabilire se si tratti di duplicati effettivi o di recensioni
-- con contenuti differenti. È necessaria una verifica mirata prima di qualsiasi intervento.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders_reviews
-- ANALISI: Confronto dei record con review_id ripetuto
-- =====================================================

-- Obiettivo:
-- Distinguere le righe completamente identiche da quelle
-- che presentano contenuti differenti a parità di review_id.

WITH recensioni_ripetute AS (
    SELECT
        review_id,
        COUNT(*) AS numero_record,
        COUNT(DISTINCT TO_JSON_STRING(STRUCT(
            order_id,
            review_score,
            review_comment_title,
            review_comment_message
        ))) AS versioni_distinte
    FROM
        `business-performance-analytics.olist_analytics.orders_reviews`
    GROUP BY
        review_id
    HAVING
        COUNT(*) > 1
)

SELECT
    COUNT(*) AS review_id_ripetuti,

    COUNTIF(versioni_distinte = 1)
        AS id_con_record_identici,

    COUNTIF(versioni_distinte > 1)
        AS id_con_contenuti_differenti,

    SUM(numero_record) AS righe_analizzate,

    SUM(numero_record - versioni_distinte)
        AS righe_eccedenti_identiche,

    MAX(numero_record) AS massimo_record_per_id

FROM recensioni_ripetute;
-- Esito dell'analisi:
-- Tutti i 789 review_id ripetuti presentano contenuti differenti tra le righe associate,
-- considerando order_id, review_score, review_comment_title e review_comment_message.
-- Non sono stati individuati gruppi di righe completamente identiche.
-- Le ripetizioni non possono quindi essere considerate semplici duplicati tecnici da eliminare automaticamente.
-- È necessario approfondire le differenze nei campi prima di stabilire come gestire questi record.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders_reviews
-- ANALISI: Differenze nei campi dei review_id ripetuti
-- =====================================================

-- Obiettivo:
-- Individuare quali campi presentano valori differenti
-- tra le righe associate allo stesso review_id.

WITH recensioni_ripetute AS (
    SELECT
        review_id,
        COUNT(*) AS numero_record,

        COUNT(DISTINCT order_id)
            AS order_id_distinti,

        COUNT(DISTINCT review_score)
            AS punteggi_distinti,

        COUNT(DISTINCT review_comment_title)
            AS titoli_distinti,

        COUNT(DISTINCT review_comment_message)
            AS messaggi_distinti

    FROM
        `business-performance-analytics.olist_analytics.orders_reviews`

    GROUP BY
        review_id

    HAVING COUNT(*) > 1
)

SELECT
    COUNT(*) AS review_id_ripetuti,

    COUNTIF(order_id_distinti > 1)
        AS id_con_order_id_differenti,

    COUNTIF(punteggi_distinti > 1)
        AS id_con_punteggi_differenti,

    COUNTIF(titoli_distinti > 1)
        AS id_con_titoli_differenti,

    COUNTIF(messaggi_distinti > 1)
        AS id_con_messaggi_differenti,

    COUNTIF(
        order_id_distinti = 1
        AND punteggi_distinti = 1
        AND titoli_distinti = 1
        AND messaggi_distinti = 1
    ) AS id_senza_differenze_rilevate

FROM recensioni_ripetute;
-- Esito dell'analisi:
-- Tutti i 789 review_id ripetuti risultano associati a order_id differenti.
-- Non sono state rilevate differenze nei punteggi, nei titoli o nei messaggi delle recensioni.
-- L'anomalia riguarda quindi l'associazione tra identificativo della recensione e ordine,
-- mentre i campi di contenuto analizzati risultano coerenti tra i record con lo stesso review_id.
-- Non è possibile stabilire la causa sulla base dei controlli effettuati; nessun record è stato modificato.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: orders_reviews
-- ANALISI: Esempi di review_id ripetuti
-- =====================================================

-- Obiettivo:
-- Esaminare alcuni casi concreti di review_id associati
-- a più ordini, confrontando i relativi campi.

WITH recensioni_ripetute AS (
    SELECT
        review_id
    FROM
        `business-performance-analytics.olist_analytics.orders_reviews`
    GROUP BY
        review_id
    HAVING COUNT(*) > 1
)

SELECT
    r.review_id,
    r.order_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message
FROM
    `business-performance-analytics.olist_analytics.orders_reviews` AS r
INNER JOIN
    recensioni_ripetute AS rr
    ON r.review_id = rr.review_id
ORDER BY
    r.review_id,
    r.order_id
LIMIT 20;
-- Esito dell'analisi:
-- Gli esempi esaminati confermano che lo stesso review_id può essere associato a più order_id.
-- Nei casi osservati, punteggio, titolo e messaggio della recensione sono identici tra le righe.
-- Il pattern è coerente con una recensione replicata su ordini differenti, ma gli esempi non bastano
-- a stabilire la causa né a determinare quale record debba essere mantenuto.
-- I dati originali sono conservati; eventuali deduplicazioni richiederanno una regola esplicita.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLE: orders_reviews e orders
-- ANALISI: Integrità referenziale delle recensioni
-- =====================================================

-- Obiettivo:
-- Verificare che gli order_id delle recensioni
-- trovino una corrispondenza nella tabella orders.

SELECT
    COUNT(*) AS numero_recensioni,

    COUNTIF(o.order_id IS NOT NULL)
        AS recensioni_con_ordine,

    COUNTIF(o.order_id IS NULL)
        AS recensioni_senza_corrispondenza,

    COUNT(DISTINCT r.order_id)
        AS ordini_distinti_nelle_recensioni,

    COUNT(DISTINCT o.order_id)
        AS ordini_distinti_trovati

FROM
    `business-performance-analytics.olist_analytics.orders_reviews` AS r

LEFT JOIN
    `business-performance-analytics.olist_analytics.orders` AS o
    ON r.order_id = o.order_id;
-- Esito dell'analisi:
-- Tutte le 99.224 righe di orders_reviews trovano una corrispondenza nella tabella orders.
-- Non sono stati rilevati order_id senza corrispondenza; i 98.673 ordini distinti presenti
-- nelle recensioni risultano tutti esistenti nella tabella orders.
-- Il controllo conferma l'integrità referenziale tra le due tabelle. Le ripetizioni di review_id
-- rilevate in precedenza restano da considerare nelle analisi successive, senza modificare i dati originali.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLA: category_translation
-- ANALISI: Completezza e unicità delle traduzioni
-- =====================================================

SELECT
    COUNT(*) AS righe_totali,
    COUNTIF(string_field_0 IS NULL) AS categorie_originali_nulle,
    COUNTIF(string_field_1 IS NULL) AS traduzioni_nulle,
    COUNT(DISTINCT string_field_0) AS categorie_originali_distinte,
    COUNT(DISTINCT string_field_1) AS traduzioni_distinte,
    COUNT(*) - COUNT(DISTINCT string_field_0)
        AS righe_in_eccesso_su_categoria_originale
FROM `business-performance-analytics.olist_analytics.category_translation`;

-- Esito dell'analisi:
-- La tabella contiene 72 righe, senza valori nulli nelle due colonne.
-- Sono presenti 72 categorie originali distinte e 72 traduzioni inglesi distinte.
-- Non sono stati rilevati duplicati sulla categoria originale.
-- La struttura dei dati risulta completa e univoca; resta da verificare
-- la corrispondenza delle categorie con la tabella products.

-- =====================================================
-- FASE 1: DATA QUALITY
-- TABELLE: products e category_translation
-- ANALISI: Corrispondenza delle categorie
-- =====================================================

SELECT
    COUNT(DISTINCT p.product_category_name)
        AS categorie_prodotti_non_nulle,
    COUNT(DISTINCT IF(
        t.string_field_0 IS NOT NULL,
        p.product_category_name,
        NULL
    )) AS categorie_con_traduzione,
    COUNT(DISTINCT IF(
        t.string_field_0 IS NULL,
        p.product_category_name,
        NULL
    )) AS categorie_senza_traduzione
FROM `business-performance-analytics.olist_analytics.products` AS p
LEFT JOIN `business-performance-analytics.olist_analytics.category_translation` AS t
    ON p.product_category_name = t.string_field_0
WHERE p.product_category_name IS NOT NULL;
-- Esito dell'analisi:
-- Sono state individuate 73 categorie distinte non nulle nella tabella products.
-- Di queste, 71 trovano una corrispondenza nella tabella category_translation,
-- mentre 2 non risultano associate ad alcuna traduzione.
-- Le categorie senza corrispondenza saranno identificate con un controllo dedicato
-- prima di decidere come gestirle nelle successive analisi.

-- =====================================================
-- FASE 1: DATA QUALITY
-- ANALISI: Identificazione categorie senza traduzione
-- =====================================================

SELECT DISTINCT
    p.product_category_name AS categoria_senza_traduzione
FROM `business-performance-analytics.olist_analytics.products` AS p
LEFT JOIN `business-performance-analytics.olist_analytics.category_translation` AS t
    ON p.product_category_name = t.string_field_0
WHERE p.product_category_name IS NOT NULL
  AND t.string_field_0 IS NULL
ORDER BY categoria_senza_traduzione;

-- Esito dell'analisi:
-- Sono state individuate due categorie presenti in products
-- senza corrispondenza nella tabella delle traduzioni:
-- pc_gamer e portateis_cozinha_e_preparadores_de_alimentos.
-- Le categorie saranno mantenute nei dati originali.
-- Nelle analisi per categoria, le traduzioni mancanti dovranno
-- essere gestite senza escludere i prodotti interessati.