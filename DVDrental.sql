--Section B starts below--

CREATE TABLE rental_frequency_sum (
title VARCHAR(255),
times_rented INT,
gross_rev NUMERIC(7,2)
);

CREATE TABLE rental_frequency (
rf_ID SERIAL,
title VARCHAR(255),
rental_rate NUMERIC(7,2),
times_rented INT,
PRIMARY KEY (rf_ID)
);

--TEST--
SELECT * FROM rental_frequency;
SELECT * FROM rental_frequency_sum;

--Section C starts below--

INSERT INTO rental_frequency(title, rental_rate, times_rented)
SELECT film.title, film.rental_rate,
COUNT(film.title)AS times_rented
FROM film INNER JOIN inventory
ON film.film_id=inventory.film_id INNER JOIN rental
ON inventory.inventory_id=rental.inventory_id
GROUP BY film.title, film.rental_rate
ORDER BY times_rented DESC;

--TEST--
SELECT * FROM rental_frequency;

--I have sanity checked the accuracy of the data.--
--The title field has titles, rental rate has rate --
--values, rf_ID is in order and the data is sorted--
--correctly by times_rented.--

--Section D starts below--

CREATE OR REPLACE FUNCTION gross_rev
(rental_rate NUMERIC(7,2), times_rented INT)
RETURNS NUMERIC (7,2)
LANGUAGE plpgsql
AS
$$
DECLARE revenue NUMERIC (7,2);
BEGIN
SELECT rental_rate * times_rented INTO revenue;
RETURN revenue;
END;
$$;

--TEST--
SELECT title, gross_rev(rental_rate, times_rented)
FROM rental_frequency;

SELECT * FROM rental_frequency;

-- Section E starts below--

CREATE OR REPLACE FUNCTION upd_summary()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
DELETE FROM rental_frequency_sum;
INSERT INTO rental_frequency_sum
(title, times_rented, gross_rev)
SELECT title, times_rented, gross_rev(rental_rate, times_rented)
FROM rental_frequency
WHERE times_rented IN ((
SELECT MAX(times_rented)
FROM rental_frequency), (
SELECT MIN(times_rented)
FROM rental_frequency))
ORDER BY times_rented DESC, gross_rev DESC, title;
RETURN NEW;
END;
$$;

CREATE TRIGGER ref_summary
AFTER INSERT
ON rental_frequency
FOR EACH STATEMENT
EXECUTE PROCEDURE upd_summary();

SELECT * FROM rental_frequency_sum;

INSERT INTO rental_frequency(title, rental_rate, times_rented)
VALUES ('SHREK', 2.99, 90);

SELECT * FROM rental_frequency_sum;

--Section F is below--

CREATE OR REPLACE PROCEDURE create_rf()
LANGUAGE plpgsql
AS $$
BEGIN
DROP TABLE IF EXISTS rental_frequency;
DROP TABLE IF EXISTS rental_frequency_sum;

CREATE TABLE rental_frequency_sum (
title VARCHAR(255),
times_rented INT,
gross_rev NUMERIC(7,2)
);

CREATE TABLE rental_frequency (
rf_ID SERIAL,
title VARCHAR(255),
rental_rate NUMERIC(4,2),
times_rented INT,
PRIMARY KEY (rf_ID)
);

INSERT INTO rental_frequency(title, rental_rate, times_rented)
SELECT film.title, film.rental_rate,
COUNT(film.title)AS times_rented
FROM film INNER JOIN inventory
ON film.film_id=inventory.film_id INNER JOIN rental
ON inventory.inventory_id=rental.inventory_id
GROUP BY film.title, film.rental_rate
ORDER BY times_rented DESC;

INSERT INTO rental_frequency_sum
(title, times_rented, gross_rev)
SELECT title, times_rented, gross_rev(rental_rate, times_rented)
FROM rental_frequency
WHERE times_rented IN ((
SELECT MAX(times_rented)
FROM rental_frequency), (
SELECT MIN(times_rented)
FROM rental_frequency))
ORDER BY times_rented DESC, gross_rev DESC, title;
RETURN;
END;
$$;

--I recommend the procedure is run weekly so the--
--business has time to adjust their strategies effectively.--

--TEST--
CALL create_rf();
SELECT * FROM rental_frequency;
SELECT * FROM rental_frequency_sum;
