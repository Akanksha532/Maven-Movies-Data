USE mavenmovies;
-- ===========================
-- Question 1
-- Display the names of customers who have rented more movies than the
-- average number of rentals made by all customers.
-- ===========================
WITH customer_rentals AS (
SELECT customer_id, COUNT(*) AS rental_count
FROM rental
GROUP BY customer_id
),
avg_rentals AS (
SELECT AVG(rental_count) AS avg_rental_count
FROM customer_rentals
)
SELECT 
    c.first_name,
    c.last_name,
    cr.rental_count
FROM customer c
JOIN customer_rentals cr
    ON c.customer_id = cr.customer_id
CROSS JOIN avg_rentals ar
WHERE cr.rental_count > ar.avg_rental_count
ORDER BY rental_count DESC;
-- ==========================================

-- ==========================================
-- Question 2
-- Display each film along with its rental rate and assign a rank based on rental
-- rate from highest to lowest.
-- ==========================================
SELECT title, rental_rate,
DENSE_RANK() OVER(ORDER BY rental_rate DESC) AS Ranking
FROM film;

-- ========================================
-- Question 3
-- Create a view that displays customer names along with their email and active status
-- ========================================
CREATE VIEW CustomerDetails AS 
SELECT c.customer_id, c.first_name, c.last_name,
c.email, c.active 
FROM customer c;

SELECT * FROM CustomerDetails;

-- ==================================

-- ==================================
-- Question 4
-- Find the top 10 customers who generated the highest payment amount
-- ==================================
SELECT c.customer_id, c.first_name, c.last_name, 
SUM(p.amount) AS 'Payment'
FROM customer c JOIN payment p 
on c.customer_id=p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY SUM(p.amount) DESC
LIMIT 10;

-- ====================================
-- ====================================
-- Question 5
-- Identify the customers whose total spending on rentals falls within the top
-- 20% of all customers.
-- ====================================
WITH customer_spending AS (
SELECT c.customer_id, c.first_name, c.last_name, SUM(p.amount) AS total_spending
FROM customer c JOIN payment p
ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
),
ranked_customers AS (
SELECT *, NTILE(5) OVER (ORDER BY total_spending DESC) AS spending_group
FROM customer_spending
)
SELECT customer_id, first_name, last_name, total_spending
FROM ranked_customers
WHERE spending_group = 1;

-- =========================================
-- Question 6
-- Display every actor along with the number of movies they acted in and assign
-- Dense Rank based on movie count
-- ==========================================
WITH FilmCount as (SELECT a.actor_id, a.first_name, a.last_name , Count(f.film_id) as MovieCount 
FROM actor a JOIN film_actor f
ON a.actor_id=f.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name )
SELECT *,
DENSE_RANK() OVER(ORDER BY MovieCount DESC) as 'Rank'
FROM FilmCount;
-- =================================

-- ================================
-- Question 7
-- Create a view showing movie title, category, rental rate and replacement cost
-- ================================
CREATE VIEW MovieRentalRates AS
SELECT f.title, c.`name`, f.rental_rate, f.replacement_cost
FROM film f JOIN film_category fc
ON f.film_id=fc.film_id
JOIN category c 
ON c.category_id=fc.category_id;
SELECT * FROM MovieRentalRates; 

-- =================================
-- Question 8
-- Create a stored procedure that returns the top 20 most rented movies.
-- =================================
DELIMITER //
CREATE procedure Top_20_Rented_Movies()
BEGIN
SELECT 
f.title, count(r.rental_id) AS RentalCount
FROM film f JOIN inventory i
ON f.film_id=i.film_id
JOIN rental r
on i.inventory_id=r.inventory_id
GROUP BY f.film_id, f.title
ORDER BY rentalcount DESC
LIMIT 20;
END //

DELIMITER ;

call Top_20_Rented_Movies();


-- ===================================
-- Question 9
-- Create a procedure that accepts a movie rating and returns all movies of that rating.
-- ===================================
DELIMITER //
CREATE PROCEDURE MovieRating(IN rate VARCHAR(10))
BEGIN
IF rate NOT IN ('G', 'PG', 'PG-13', 'R', 'NC-17') THEN
	SELECT 'Invalid rating. Please enter G, PG, PG-13, R, or NC-17.' AS Message;
ELSE
	SELECT f.title, f.rating
	FROM film f
	WHERE f.rating = rate;
    END IF;

END //
DELIMITER ;
call MovieRating('G');

-- ============================
-- Question 10
-- Identify the top 3 films in each category based on their rental counts.
-- ============================
WITH FilmRentals AS (
SELECT c.category_id, c.name AS category, f.film_id, f.title, COUNT(r.rental_id) AS rental_count
FROM film f JOIN film_category fc
ON f.film_id = fc.film_id
JOIN category c
ON fc.category_id = c.category_id
JOIN inventory i
ON f.film_id = i.film_id
JOIN rental r
ON i.inventory_id = r.inventory_id
GROUP BY c.category_id, c.name, f.film_id, f.title
),
RankedFilms AS (
SELECT *, DENSE_RANK() OVER ( PARTITION BY category_id ORDER BY rental_count DESC) AS film_rank
FROM FilmRentals)
SELECT category, title, rental_count, film_rank
FROM RankedFilms
WHERE film_rank <= 3
ORDER BY category, film_rank;

-- =======================================
-- Question 11
-- Calculate the running total of rentals per category, ordered by rental count.
-- =======================================
WITH CategoryRentals AS (
SELECT c.category_id, c.name AS category, COUNT(r.rental_id) AS rental_count
FROM category c
JOIN film_category fc
ON c.category_id = fc.category_id
JOIN film f
ON fc.film_id = f.film_id
JOIN inventory i
ON f.film_id = i.film_id
JOIN rental r
ON i.inventory_id = r.inventory_id
GROUP BY c.category_id, c.name
)
SELECT category, rental_count, 
SUM(rental_count) OVER (ORDER BY rental_count DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM CategoryRentals
ORDER BY rental_count DESC;

-- ===================================
-- Question 12
-- Create a CTE to generate a report showing pairs of actors who have
-- appeared in the same film together, using the film_actor table
-- ===========================
WITH ActorPairs AS (
SELECT fa1.film_id, fa1.actor_id AS actor1_id, fa2.actor_id AS actor2_id
FROM film_actor fa1 JOIN film_actor fa2
ON fa1.film_id = fa2.film_id
AND fa1.actor_id < fa2.actor_id
)
SELECT ap.film_id, CONCAT(a1.first_name, ' ', a1.last_name) AS actor1, 
CONCAT(a2.first_name, ' ', a2.last_name) AS actor2
FROM ActorPairs ap JOIN actor a1
ON ap.actor1_id = a1.actor_id
JOIN actor a2
ON ap.actor2_id = a2.actor_id;




-- ==================================
-- Question 13:
-- Create a procedure that accepts a customer ID as input and returns the
-- customer's total payment as an output parameter. 
-- ==================================
DELIMITER //
CREATE PROCEDURE CustomerTotalPayments(IN custID INT, OUT TotalPayment DECIMAL(5,2))
BEGIN
SELECT SUM(AMOUNT) INTO TotalPayment FROM Payment
WHERE customer_id=custID;
END //
DELIMITER ;

set @tp=0;


call CustomerTotalPayments(1, @tp);


