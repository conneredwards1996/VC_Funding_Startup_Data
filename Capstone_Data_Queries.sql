-- this file contains all SQL queries run against the Capstone_VCFundingData Database
-- for the purposes of the GA DA Immersive Capstone Project

--Ideas for Queries
--Define success - what startups in this list are considered successful?
	-- companies that IPOd or were acquired
	--from that list apply queries below
-- Sum of all funding per startup
--Avg time b/w funding rounds
--Avg time from first funding round to IPO/Acquisition
--Count of successful exits per investor
	--tie investments to (acquisitions unioned ipos) group count by investors
	
--Queries:

--Union of Object_Ids for IPO & Acquisition Data (Acquired Object)
--list of "successful" object IDs to investigate further
select object_id, public_at as Success_Date
from public."IPOs"
UNION
select acquired_object_id, acquired_at as Success_Date
from public."Acquisitions"

--10,787/196,553

select count(*)
from public."Objects"
where id ilike '%c%';


-- query to figure out how much each successful startup raised in total (in $USD)
--2818 results, ordered descending

select object_id, sum(raised_amount_usd)::numeric::money as raised_total
-- pull the object_id, and total money raised across all funds
from public."Funding_Rounds"
--from funding rounds table
where object_id in (
-- where the company either IPOd or was acquired (based on object id)
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
	)
group by object_id
--group by object_id
having sum(raised_amount_usd) > 0
order by sum(raised_amount_usd) desc
;

--Query to find the average total funding raised per successful startup:
-- the average successful startup raised ~35 Million USD in total

select avg(raised_total)::numeric::money as avg_raised_total_successful_co
from (
	select object_id, sum(raised_amount_usd) as raised_total -- had to remove money cast to get avg
-- pull the object_id, and total money raised across all funds
	from public."Funding_Rounds"
--from funding rounds table
	where object_id in (
-- where the company either IPOd or was acquired (based on object id)
		select object_id`
		from public."IPOs"
		UNION
		select acquired_object_id
		from public."Acquisitions")
	group by object_id
--group by object_id
	having sum(raised_amount_usd) > 0
	order by sum(raised_amount_usd) desc) as total_raised_values
;


--Query for the avg size of each funding round
Select funding_round_code, avg(raised_amount_usd)::numeric::money
from public."Funding_Rounds"
where raised_amount_usd > 0
group by funding_round_code
order by funding_round_code
;


--Query for the avg size of each funding round for successful startups
Select funding_round_code, avg(raised_amount_usd)::numeric::money
from public."Funding_Rounds"
where raised_amount_usd > 0 and object_id in (
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions")
group by funding_round_code
order by funding_round_code
;

-- Query to find average time from first funding date to ipo
--avg of 1055 days (2.89 years)
select avg(funded_at::date - public_at::date)::int
--taking the average of funded date minus public at date to get the duration of time it took these
-- companies to go public from the first funding round
from public."IPOs"
left join (
	select object_id, funded_at
	from public."Funding_Rounds"
	where is_first_round = 1 and funded_at is not null
) as initial_funding_info
-- this is a subquery of a table from funding rounds where the funding round was the first one
using (object_id)
where public_at is not null
;

--Query to find average time from first funding date to acquisition date
-- 707 days, 1.94 years
select avg(funded_at::date - acquired_at::date)::int
-- difference between the date of initial funding and acquisition, on average
from public."Acquisitions"
left join (
	select object_id, funded_at
	from public."Funding_Rounds"
	where is_first_round = 1 and funded_at is not null
	-- joining a table of object ID and funding dates where first round is true and date exists
) as initial_funding_info
on object_id = acquired_object_id
where acquired_at is not null;
-- making sure there are no nulls in the data

-- Query to find location of offices of successful companies
-- group by state code
-- where state code is not null
-- not suprisingly, top states are CA, NY, MA, TX, WA in that order

select city, state_code, count(object_id) as loc_count
-- pull the state code and count of objects (companies) with that state code
from public."Offices"
-- from the offices table which has state code and object id
where object_id in (
-- include only the rows that have an object_id that is in the 'successful' objects list
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
) and state_code is not null
-- ^ disclude nulls
group by city, state_code
-- group them by state so that we can see which state has the most successful states
order by count(object_id) desc
-- order them in descending order by count of successful companies per state



-- Query to find average time between rounds (seed to A) of successful companies
-- use 2 CTEs (one for seed, one for series A)

WITH Series_Seed as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'seed'
-- first CTE is all seed round rows
),
Series_A as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'a'
-- second CTE is all series A round rows
)


SELECT avg(Series_Seed.funded_at::date - Series_A.funded_at::date)
-- remove the dates from each other
FROM Series_Seed
Left JOIN Series_A
-- join series A to seed stage
USING(object_id)
WHERE object_id in (select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions")
	-- -- this is a list of all object_ids where company IPOd or was acquired
;

-- Query to find the average time for ALL companies between seed and A

WITH Series_Seed as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'seed'
-- first CTE is all seed round rows
),
Series_A as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'a'
-- second CTE is all series A round rows
)


SELECT avg(Series_Seed.funded_at::date - Series_A.funded_at::date)
-- remove the dates from each other
FROM Series_Seed
Left JOIN Series_A
-- join series A to seed stage
USING(object_id)
;

-- Query to find average time between rounds (A to B) of successful companies

WITH Series_A as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'a'
-- first CTE is all series A round rows
),
Series_B as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'b'
-- second CTE is all series B round rows
)


SELECT avg(Series_A.funded_at::date - Series_B.funded_at::date)
-- remove the dates from each other
FROM Series_A
Left JOIN Series_B
-- join series B to A stage
USING(object_id)
WHERE object_id in (select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions")
	-- -- this is a list of all object_ids where company IPOd or was acquired
;

-- Query to find the average for all companies between A&B

WITH Series_A as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'a'
-- first CTE is all series A round rows
),
Series_B as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'b'
-- second CTE is all series B round rows
)


SELECT avg(Series_A.funded_at::date - Series_B.funded_at::date)
-- remove the dates from each other
FROM Series_A
Left JOIN Series_B
-- join series B to A stage
USING(object_id)

;

--Query to find average time between rounds (B to C) of successful companies

WITH Series_B as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'b'
-- first CTE is all series B round rows
),
Series_C as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'c'
-- second CTE is all series C round rows
)


SELECT avg(Series_B.funded_at::date - Series_C.funded_at::date)
-- remove the dates from each other
FROM Series_B
Left JOIN Series_C
-- join series B to A stage
USING(object_id)
WHERE object_id in (select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions")
	-- -- this is a list of all object_ids where company IPOd or was acquired
;

-- Query to find average time between Series B & C for ALL companies

WITH Series_B as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'b'
-- first CTE is all series B round rows
),
Series_C as (
	SELECT object_id, funded_at, funding_round_code
	FROM public."Funding_Rounds"
	WHERE funding_round_code ilike 'c'
-- second CTE is all series C round rows
)


SELECT avg(Series_B.funded_at::date - Series_C.funded_at::date)
-- remove the dates from each other
FROM Series_B
Left JOIN Series_C
-- join series B to A stage
USING(object_id)

;


-- New Query to find the avg number of funding rounds for successful companies vs avg of all
-- excluding nulls (0)

-- this is the average for all companies - 1.660 rounds
select avg(funding_rounds)
from public."Objects"
where funding_rounds != 0;

-- this is the avg for successful companies - 1.997 rounds
select avg(funding_rounds)
from public."Objects"
where funding_rounds != 0 and id in (
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
)
;

-- new query to group successful companies by category code - then group total, compare

select category_code, count(id)
from public."Objects"
where id in (
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
)
group by category_code
order by count(id) desc

-- Total count of startups by category_code
select category_code, count(id)
from public."Objects"
group by category_code
order by category_code


-- total funding per category
select category_code, sum(funding_total_usd)::numeric::money
from public."Objects"
group by category_code
order by sum(funding_total_usd) desc
;

-- total funding per category for successful startups
select category_code, sum(funding_total_usd)::numeric::money
from public."Objects"
where id in (
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
)
group by category_code
order by sum(funding_total_usd) desc
;

-- total funding per category for last few years

select category_code, sum(funding_total_usd)::numeric::money
from public."Objects"
where id in (
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
) and DATE_PART('Year', last_investment_at::date) in (2012,2013)
group by category_code
order by sum(funding_total_usd) desc
;

select max(last_investment_at::date) -- latest investment in the list is 12/12/2013
from public."Objects"
;


-- Query for difference in time from founded to IPO (12.66 years)

select avg(public_at::date - founded_at::date)
 -- difference between the date of founding and the ipo date
from public."IPOs"
left join public."Objects"
 -- left join so as to drop any objects that did not ipo
on object_id = public."Objects".id
;

-- same query, but for companies founded in the last 10 years (avg 7.06 years to IPO)

select avg(public_at::date - founded_at::date)
 -- difference between the date of founding and the ipo date
from public."IPOs"
left join public."Objects"
 -- left join so as to drop any objects that did not ipo
on object_id = public."Objects".id
where date_part('year', founded_at::date) in 
	(2013, 2012, 2011, 2010, 2009, 2008, 2007, 2006, 2005, 2004, 2003, 2002, 2001, 2000, 1999, 1998)
;

-- avg time to IPO for companies founded before 1998 (19.18 Years)

select avg(public_at::date - founded_at::date)
 -- difference between the date of founding and the ipo date
from public."IPOs"
left join public."Objects"
 -- left join so as to drop any objects that did not ipo
on object_id = public."Objects".id
where date_part('year', founded_at::date) < 1998
;

-- Query for difference in time from founded to Acquisition (9.68 Years)

select avg(acquired_at::date - founded_at::date)
 -- difference between the date of founding and the acquisition date
from public."Acquisitions"
left join public."Objects"
 -- left join so as to drop any objects that did have an acquisition
on acquired_object_id = public."Objects".id
;

-- Same Query, but for companies founded in the past 15 years (5.88 years)

select avg(acquired_at::date - founded_at::date)
 -- difference between the date of founding and the acquisition date
from public."Acquisitions"
left join public."Objects"
 -- left join so as to drop any objects that did have an acquisition
on acquired_object_id = public."Objects".id
where date_part('year', founded_at::date) in 
	(2013, 2012, 2011, 2010, 2009, 2008, 2007, 2006, 2005, 2004, 2003, 2002, 2001, 2000, 1999, 1998)
;

-- AVG Time it took to acquired prior to 1998 (21.82 years on avg)

select avg(acquired_at::date - founded_at::date)
 -- difference between the date of founding and the acquisition date
from public."Acquisitions"
left join public."Objects"
 -- left join so as to drop any objects that did have an acquisition
on acquired_object_id = public."Objects".id
where date_part('year', founded_at::date) < 1998 
;

-- query to find avg time from founding to first investment
select avg(public."Funding_Rounds".funded_at::date - public."Objects".founded_at::date)
from public."Objects"
join public."Funding_Rounds"
on public."Objects".id = public."Funding_Rounds".object_id
where public."Objects".id in (
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions") and funding_round_code ilike '%seed%' and funded_at is not null
;

-- group by of people tied to successful startups by count of occurrence

select person_object_id, public."People".first_name, public."People".last_name, count(*)
-- select the person's object id, their name, and the count of their occurrences
from public."Relationships"
left join public."People"
on person_object_id = object_id
-- object id of the person equals the object id titled person_object_id
where relationship_object_id in ( -- where the relationship_object_id matches one of the successful co obj ids
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
)
group by 1, 2, 3
order by count(*) desc
;

-- query to find how many successful cos each investor invested in

select investor_object_id, public."Objects".name, count(*)
-- pull investor object id, name and count of occurrences
from public."Investments"
left join public."Objects"
-- left join objects, since we only need the ones that are in the investment list
on public."Investments".investor_object_id = public."Objects".id
where funded_object_id in (  -- list of object ids of successful cos
	select object_id
	from public."IPOs"
	UNION
	select acquired_object_id
	from public."Acquisitions"
)
group by 1, 2 -- group by investors
order by 3 Desc -- order descending by the count
;

-- query to find how many total companies each investor invested in:

select investor_object_id, public."Objects".name, count(*)
from public."Investments"
left join public."Objects"
on public."Investments".investor_object_id = public."Objects".id
group by 1, 2
order by 3 Desc
;



select count(*)
from public."Funding_Rounds"
where funding_round_code ilike '%G%'
;

select count(*)
from public."Objects"
where entity_type ilike '%company%';