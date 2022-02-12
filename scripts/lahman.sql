/*
1. Find all players in the database who played at Vanderbilt University. 
Create a list showing each player's first and last names 
as well as the total salary they earned in the major leagues. 
Sort this list in descending order by the total salary earned. 
Which Vanderbilt player earned the most money in the majors?
*/

SELECT 
	namefirst, 
	namelast, 
	SUM(salary)::numeric::money AS total_salary
FROM people
INNER JOIN salaries
	USING (playerid)
WHERE playerid IN
	(
	SELECT playerid
	FROM collegeplaying
	WHERE schoolid = 'vandy'
	)
GROUP BY namefirst, namelast
ORDER BY total_salary DESC;

-- David Price earned the most money in the majors ($81,851,296)

----------------------------------------------------------------------------------------2

/*
2. Using the fielding table, group players into three groups based on their position: 
label players with position OF as "Outfield", 
those with position "SS", "1B", "2B", and "3B" as "Infield", 
and those with position "P" or "C" as "Battery". 
Determine the number of putouts made by each of these three groups in 2016.
*/

SELECT
	CASE WHEN pos = 'OF' THEN 'Outfield' 
	 	 WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
	 	 WHEN pos IN ('P', 'C') THEN 'Battery'
	 	 END AS pos_group,
	SUM(po) AS total_po
FROM fielding
WHERE yearid = 2016
GROUP BY pos_group;


/*
Battery 41,424
Infield 58,934
Outfield 29,560
*/

----------------------------------------------------------------------------------------3

/*
3. Find the average number of strikeouts per game by decade since 1920.
Round the numbers you report to 2 decimal places. 
Do the same for home runs per game. Do you see any trends? 
(Hint: For this question, you might find it helpful to look at the generate_series function 
(https://www.postgresql.org/docs/9.1/functions-srf.html). 
If you want to see an example of this in action, check out this DataCamp video: 
https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)
*/

SELECT
	FLOOR(yearid/10)*10 AS decade,
	ROUND(SUM(so)*2.0/(SUM(g)), 2) AS so_per_game,
	ROUND(SUM(hr)*2.0/(SUM(g)), 2) AS hr_per_game
FROM teams
GROUP BY decade
ORDER BY decade;

-- Over time, both so/g and hr/g are increasing.

----------------------------------------------------------------------------------------4

/*
4. Find the player who had the most success stealing bases in 2016, 
where success is measured as the percentage of stolen base attempts which are successful. 
(A stolen base attempt results either in a stolen base or being caught stealing.) 
Consider only players who attempted at least 20 stolen bases. 
Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.
*/

SELECT
	namefirst,
	namelast,
	sb,
	(sb + cs) AS sb_attempts,
	ROUND(sb*100.0/(sb+cs), 2) AS sb_perc
FROM people
INNER JOIN batting
	USING(playerid)
WHERE yearid = 2016
	AND sb + cs >= 20
ORDER BY sb_perc DESC;
	
-- Chris Owings had the highest sb percentage with 91.30%

----------------------------------------------------------------------------------------5

/*
5. From 1970 to 2016, what is the largest number of wins for a team 
that did not win the world series? 
What is the smallest number of wins for a team that did win the world series? 

Doing this will probably result in an unusually small number of wins 
for a world series champion; determine why this is the case. 
Then redo your query, excluding the problem year. 

How often from 1970 to 2016 was it the case that a team with the most wins 
also won the world series? What percentage of the time?
*/

(SELECT
	name,
	yearid,
	wswin,
	w,
	g
FROM teams
WHERE wswin = 'N'
 AND yearid BETWEEN 1970 AND 2016
ORDER BY w DESC
LIMIT 1
)
UNION
(SELECT
	name,
	yearid,
	wswin,
	w,
	g
FROM teams
WHERE wswin = 'Y'
  AND yearid BETWEEN 1970 AND 2016
ORDER BY w
LIMIT 1)

-- My blessed Mariners won 116 games but did not win the WS in 2001.
-- The '81 Dodgers only won 63 games and still won the WS; however,
-- there was a strike that year and only 110 regular-season games were played.

(SELECT
	name,
	yearid,
	wswin,
	w,
	g
FROM teams
WHERE wswin = 'N'
 AND yearid BETWEEN 1970 AND 2016
ORDER BY w DESC
LIMIT 1
)
UNION
(SELECT
	name,
	yearid,
	wswin,
	w,
	g
FROM teams
WHERE wswin = 'Y'
  AND yearid BETWEEN 1970 AND 2016
  AND yearid <> 1981
ORDER BY w
LIMIT 1)

-- The 2006 St. Louis Cardinals won only 83 games but still won the WS.

WITH max_w AS(
	SELECT 
		yearid, 
		max(w) AS w
	FROM teams
	GROUP BY yearid
)
SELECT 
	SUM(CASE WHEN wswin = 'Y' THEN 1 ELSE 0 END) AS maxw_ws_count,
	ROUND(100*AVG(CASE WHEN wswin = 'Y' THEN 1 ELSE 0 END),2) AS maxw_ws_perc
FROM teams
INNER JOIN max_w
	ON teams.yearid = max_w.yearid AND teams.w = max_w.w
WHERE teams.yearid BETWEEN 1970 AND 2016
	AND teams.yearid <> 1994;

-- 12 max win teams won the WS, which was 23.08% of eligible teams.
-- 1994 is excluded because there was no WS due to a player strike.

----------------------------------------------------------------------------------------6

/*
6. Which managers have won the TSN Manager of the Year award in both the National League (NL)
and the American League (AL)? Give their full name and the teams that they were managing 
when they won the award.
*/

WITH TSN_ALNL AS (
	(SELECT playerid
	FROM awardsmanagers
	WHERE awardid LIKE 'TSN%'
		AND lgid = 'AL')
	INTERSECT
	(SELECT playerid
	FROM awardsmanagers
	WHERE awardid LIKE 'TSN%'
		AND lgid = 'NL')
	)
SELECT 
	namefirst, 
	namelast,
	yearid,
	awardid,
	awardsmanagers.lgid,
	teamid
FROM awardsmanagers
INNER JOIN TSN_ALNL
	USING (playerid)
INNER JOIN people
	USING (playerid)
INNER JOIN managers
	USING (playerid, yearid)
WHERE awardid LIKE 'TSN%'
ORDER BY namelast, yearid;

-- Davey Johnson and Jim Leyland

----------------------------------------------------------------------------------------7

/*
7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? 
Only consider pitchers who started at least 10 games (across all teams). 
Note that pitchers often play for more than one team in a season, 
so be sure that you are counting all stats for each player.
*/

SELECT
	namefirst,
	namelast,
	(MAX(salary)/SUM(so))::numeric::money AS salary_per_so
FROM pitching
INNER JOIN people
	USING (playerid)
INNER JOIN salaries
	USING (playerid, yearid)
WHERE yearid = 2016
GROUP BY playerid, namefirst, namelast
HAVING sum(gs) >= 10
ORDER BY salary_per_so DESC;

-- Matt Cain made a whopping $289,351.85 per so

----------------------------------------------------------------------------------------8

/*
8. Find all players who have had at least 3000 career hits. 
Report those players' names, total number of hits, and the year they were inducted 
into the hall of fame 
(If they were not inducted into the hall of fame, put a null in that column.) 
Note that a player being inducted into the hall of fame is indicated by a 'Y' 
in the inducted column of the halloffame table.
*/

WITH hof AS (
	SELECT *
	FROM halloffame
	WHERE inducted = 'Y'
)
SELECT
	namefirst,
	namelast,
	SUM(h),
	hof.yearid
FROM batting
INNER JOIN people
	USING (playerid)
LEFT JOIN hof
	USING (playerid)
GROUP BY playerid, namefirst, namelast, hof.yearid
HAVING sum(h) >= 3000
ORDER BY hof.yearid;

----------------------------------------------------------------------------------------9

/*
9. Find all players who had at least 1,000 hits for two different teams. 
Report those players' full names.
*/

WITH khits AS (
	SELECT
		playerid,
		teamid,
		SUM(h)
	FROM batting
	GROUP BY playerid, teamid
	HAVING SUM(h) >= 1000
	ORDER BY playerid
	)
SELECT
	namefirst,
	namelast
FROM khits
INNER JOIN people
	USING (playerid)
GROUP BY playerid, namefirst, namelast
HAVING COUNT(DISTINCT teamid) = 2
ORDER BY namelast;

----------------------------------------------------------------------------------------10

/*
10. Find all players who hit their career highest number of home runs in 2016. 
Consider only players who have played in the league for at least 10 years, 
and who hit at least one home run in 2016. 
Report the players' first and last names and the number of home runs they hit in 2016.
*/

-- First pass, 1.6 s

WITH hr AS (
	SELECT
		playerid,
		yearid,
		SUM(batting.hr) AS season_hr,
		RANK() OVER(PARTITION BY playerid ORDER BY playerid, yearid) AS year_in_league
	FROM batting
	GROUP BY playerid, yearid
	),
max_hr AS (
	SELECT
		playerid,
		MAX(season_hr) AS max_season_hr
	FROM hr
	GROUP BY playerid
)
SELECT
	namefirst,
	namelast,
	season_hr AS hr_2016
FROM hr
INNER JOIN people
	USING (playerid)
INNER JOIN max_hr
	ON (hr.playerid = max_hr.playerid) AND (hr.season_hr = max_hr.max_season_hr)
WHERE yearid = 2016 
	AND year_in_league >= 10
	AND season_hr > 0
ORDER BY hr_2016 DESC;

-- cleaner but slower, 2.1 s

WITH hr2016 AS (
	SELECT
		playerid,
		namefirst,
		namelast,
		yearid,
		SUM(batting.hr) AS season_hr,
		RANK() OVER(PARTITION BY playerid ORDER BY playerid, yearid) AS year_in_league,
		MAX(SUM(batting.hr)) OVER(PARTITION BY playerid) AS max_season_hr
	FROM batting
	INNER JOIN people
		USING (playerid)
	GROUP BY playerid, namefirst, namelast, yearid 
	)
SELECT
	namefirst,
	namelast,
	season_hr AS hr_2016
FROM hr2016
WHERE yearid = 2016 
	AND year_in_league >= 10
	AND season_hr > 0
	AND season_hr = max_season_hr
ORDER BY hr_2016 DESC;

-----------------------/* OPEN-ENDED FROM WHEN I TOOK DA4 */----------------------------

----------------------------------------------------------------------------------------11

--Solution using ranks
WITH ts AS(
	SELECT yearid,
			teamid,
			SUM(salary) AS team_salary
	FROM salaries
	GROUP BY yearid, teamid
	ORDER BY yearid, teamid
),
sal_w_rk AS(
	SELECT t.yearid,
		t.teamid,
		ts.team_salary,
		t.w,
		RANK() OVER(PARTITION BY t.yearid ORDER BY ts.team_salary DESC) AS team_sal_rk,
		RANK() OVER(PARTITION BY t.yearid ORDER BY t.w DESC) AS team_w_rk
FROM teams AS t
LEFT JOIN ts
USING (yearid, teamid)
WHERE t.yearid >= 2000
ORDER BY t.yearid, t.w DESC
	)
SELECT team_sal_rk,
		ROUND(AVG(team_w_rk), 1) AS avg_w_rk
FROM sal_w_rk
GROUP BY team_sal_rk
ORDER BY team_sal_rk;
--Salary is correlated with wins, though the slope isn't as steep as I'd expect (till #1)

--Solution using correlation coefficient and regression slope
WITH ts AS(
	SELECT yearid,
			teamid,
			SUM(salary) AS team_salary
	FROM salaries
	GROUP BY yearid, teamid
	ORDER BY yearid, teamid
)
SELECT corr(t.w, ts.team_salary) AS r_value,
		regr_slope(t.w, ts.team_salary) * 10^7 AS w_per_ten_mil
FROM teams AS t
LEFT JOIN ts
USING (yearid, teamid)
WHERE t.yearid >= 2000;
--Pretty high r-value considering the number of data values. About 1 win per 10 million dollars.

----------------------------------------------------------------------------------------12
/*
12
	a. Does there appear to be any correlation between attendance at home games and number of wins? 
*/
WITH w_att_rk AS (
SELECT yearid,
		teamid,
		w,
		attendance / ghome AS avg_h_att,
		RANK() OVER(PARTITION BY yearid ORDER BY w) AS w_rk,
		RANK() OVER(PARTITION BY yearid ORDER BY attendance / ghome) AS avg_h_att_rk
FROM teams
WHERE attendance / ghome IS NOT NULL
AND yearid >= 1961 						--MLB institutes 162 game season
ORDER BY yearid, teamid
)
SELECT avg_h_att_rk,
		ROUND(AVG(w_rk), 1) AS avg_w_rk,
		CORR(avg_h_att_rk, AVG(w_rk)) OVER() as correlation
FROM w_att_rk
GROUP BY avg_h_att_rk
ORDER BY avg_h_att_rk;
--Very strong correlation between wins and home game attendance.


/*
12

	b. Do teams that win the world series see a boost in attendance the following year?
	   What about teams that made the playoffs?
	   Making the playoffs means either being a division winner or a wild card winner.
*/
--After World Series Win
WITH att_comp AS (
SELECT yearid,
		name,
		attendance / ghome AS att_g,
		lead(attendance / ghome) OVER(PARTITION BY name ORDER BY yearid) AS att_g_next_year,
		lead(attendance / ghome) OVER(PARTITION BY name ORDER BY yearid) - (attendance/ghome) AS difference
FROM teams AS t
)
SELECT ROUND(AVG(difference), 1) AS avg_att_dif
FROM att_comp
INNER JOIN teams AS t
USING (yearid, name)
WHERE wswin = 'Y';
--Attendance improves, on average, by 267.1 people per home game.

--After Playoff Berth
WITH att_comp AS (
SELECT yearid,
		name,
		attendance / ghome AS att_g,
		lead(attendance / ghome) OVER(PARTITION BY name ORDER BY yearid) AS att_g_next_year,
		lead(attendance / ghome) OVER(PARTITION BY name ORDER BY yearid) - (attendance/ghome) AS difference
FROM teams AS t
)
SELECT ROUND(AVG(difference), 1) AS avg_att_dif
FROM att_comp
INNER JOIN teams AS t
USING (yearid, name)
WHERE wcwin = 'Y' OR divwin = 'Y';
--Attendance improves, on average, by 561.9 people per home game.

----------------------------------------------------------------------------------------13
/*
13. It is thought that since left-handed pitchers are more rare,
causing batters to face them less often, that they are more effective.
Investigate this claim and present evidence to either support or dispute this claim.
First, determine just how rare left-handed pitchers are compared with right-handed pitchers.
Are left-handed pitchers more likely to win the Cy Young Award?
Are they more likely to make it into the hall of fame?
*/
--Relative frequency of L vs R pitchers
SELECT SUM(CASE WHEN throws = 'L' THEN 1 ELSE 0 END) AS ct_L,
		ROUND(AVG(CASE WHEN throws = 'L' THEN 1 ELSE 0 END), 4) AS perc_L,
		SUM(CASE WHEN throws = 'R' THEN 1 ELSE 0 END) AS ct_R,
		ROUND(AVG(CASE WHEN throws = 'R' THEN 1 ELSE 0 END), 4) AS perc_R
FROM people
WHERE playerid IN
	(SELECT DISTINCT playerid
	FROM pitching
	)
--L: 26.63%, R: 71.01%

--Relative frequency of Cy Young Awards (relative to all and relative to group size)

WITH cy_young AS (
	SELECT *
	FROM awardsplayers
	WHERE awardid = 'Cy Young Award'
	),
left_pitchers AS (
	SELECT *
	FROM people
	WHERE playerid IN
		(SELECT DISTINCT playerid
		FROM pitching
		)
	AND throws = 'L'
	),
right_pitchers AS (
	SELECT *
	FROM people
	WHERE playerid IN
		(SELECT DISTINCT playerid
		FROM pitching
		)
	AND throws = 'R'
	)
SELECT ROUND(AVG(CASE WHEN p.throws = 'L' THEN 1
		  		WHEN p.throws = 'R' THEN 0 END), 4) AS perc_CY_L,
		ROUND(AVG(CASE WHEN p.throws = 'R' THEN 1
		  		WHEN p.throws = 'L' THEN 0 END), 4) AS perc_CY_R
FROM people AS p
INNER JOIN cy_young
USING (playerid)
--L: 33.04%, R: 66.96%

WITH cy_young AS (
	SELECT *
	FROM awardsplayers
	WHERE awardid = 'Cy Young Award'
	),
left_pitchers AS (
	SELECT *
	FROM people
	WHERE playerid IN
		(SELECT DISTINCT playerid
		FROM pitching
		)
	AND throws = 'L'
	),
right_pitchers AS (
	SELECT *
	FROM people
	WHERE playerid IN
		(SELECT DISTINCT playerid
		FROM pitching
		)
	AND throws = 'R'
	)
SELECT 'Left' AS Arm,
		ROUND(AVG(CASE WHEN awardid = 'Cy Young Award' THEN 1
		  				ELSE 0 END), 4) AS perc_CY
FROM left_pitchers AS l
LEFT JOIN cy_young
USING (playerid)
UNION
SELECT 'Right' AS Arm,
		ROUND(AVG(CASE WHEN awardid = 'Cy Young Award' THEN 1
		  				ELSE 0 END), 4) AS perc_CY
FROM right_pitchers AS r
LEFT JOIN cy_young
USING (playerid)
--1.49% of left handers win the Cy Young, while 1.13% of right handers win the Cy Young

--Relative frequency of HOF Induction
WITH hof_pitchers AS (
	SELECT *
	FROM halloffame
	INNER JOIN pitching
	USING (playerid)
	WHERE inducted = 'Y'
	)
SELECT ROUND(AVG(CASE WHEN throws = 'L' THEN 1
		  		ELSE 0 END), 4) AS perc_HOF_L_pitch,
		ROUND(AVG(CASE WHEN throws = 'R' THEN 1
		  		ELSE 0 END), 4) AS perc_HOF_R_pitch
FROM hof_pitchers
INNER JOIN people
USING (playerid)
--Percent of HOF pitchers who are lefty: 22.51%, righty: 77.49%
				
WITH hof_pitchers AS (
	SELECT *
	FROM halloffame
	INNER JOIN pitching
	USING (playerid)
	WHERE inducted = 'Y'
	),
left_pitchers AS (
	SELECT *
	FROM people
	WHERE playerid IN
		(SELECT DISTINCT playerid
		FROM pitching
		)
	AND throws = 'L'
	),
right_pitchers AS (
	SELECT *
	FROM people
	WHERE playerid IN
		(SELECT DISTINCT playerid
		FROM pitching
		)
	AND throws = 'R'
	)
SELECT 'Left' AS Arm,
		ROUND(AVG(CASE WHEN inducted = 'Y' THEN 1
		  				ELSE 0 END), 4) AS perc_HOF
FROM left_pitchers AS l
LEFT JOIN hof_pitchers
USING (playerid)
UNION
SELECT 'Right' AS Arm,
		ROUND(AVG(CASE WHEN inducted = 'Y' THEN 1
		  				ELSE 0 END), 4) AS perc_HOF
FROM right_pitchers AS r
LEFT JOIN hof_pitchers
USING (playerid)
--Percent of lefty pitchers who enter HOF: 11.18%, Righties: 14.02%

---------------------------------------------------------------------------------------- Bonus 1

/*
1. In this question, you'll get to practice correlated subqueries and learn about 
the LATERAL keyword. Note: This could be done using window functions, 
but we'll do it in a different way in order to revisit correlated subqueries 
and see another keyword - LATERAL.

a. First, write a query utilizing a correlated subquery to find the team with the most wins from each league in 2016.

If you need a hint, you can structure your query as follows:

SELECT DISTINCT lgid, ( <Write a correlated subquery here that will pull the teamid for the team with the highest number of wins from each league> )
FROM teams t
WHERE yearid = 2016;
*/

SELECT DISTINCT 
	lgid,
	(SELECT name
	 FROM teams AS st
	 WHERE t.lgid = st.lgid
	 	AND yearid = 2016
	 ORDER BY w DESC
	 LIMIT 1)
FROM teams AS t
WHERE yearid = 2016;

/*
b. One downside to using correlated subqueries is that you can only return exactly
one row and one column. This means, for example that if we wanted to pull in
not just the teamid but also the number of wins, we couldn't do so using just 
a single subquery. (Try it and see the error you get). 
Add another correlated subquery to your query on the previous part so that 
your result shows not just the teamid but also the number of wins by that team.
*/

SELECT DISTINCT 
	lgid,
	(SELECT name
	 FROM teams AS st
	 WHERE t.lgid = st.lgid
	 	AND yearid = 2016
	 ORDER BY w DESC
	 LIMIT 1),
	(SELECT w
	 FROM teams AS st
	 WHERE t.lgid = st.lgid
	 	AND yearid = 2016
	 ORDER BY w DESC
	 LIMIT 1)	 
FROM teams AS t
WHERE yearid = 2016;

/*
c. If you are interested in pulling in the top (or bottom) values by group,
you can also use the DISTINCT ON expression (https://www.postgresql.org/docs/9.5/sql-select.html#SQL-DISTINCT). 
Rewrite your previous query into one which uses DISTINCT ON to return 
the top team by league in terms of number of wins in 2016. 
Your query should return the league, the teamid, and the number of wins.
*/

SELECT DISTINCT ON (lgid)
	lgid,
	name,
	w
FROM teams AS t
WHERE yearid = 2016
ORDER BY lgid, w DESC;

/*
d. If we want to pull in more than one column in our correlated subquery, 
another way to do it is to make use of the LATERAL keyword 
(https://www.postgresql.org/docs/9.4/queries-table-expressions.html#QUERIES-LATERAL). 
This allows you to write subqueries in FROM that make reference to 
columns from previous FROM items. This gives us the flexibility to 
pull in or calculate multiple columns or multiple rows (or both). 
Rewrite your previous query using the LATERAL keyword so that 
your result shows the teamid and number of wins for the team with 
the most wins from each league in 2016. 

If you want a hint, you can structure your query as follows:

SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL ( <Fill in a subquery here to retrieve the teamid and number of wins> ) as top_teams;
*/

SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL (SELECT
			  		name,
			  		w
			  	FROM teams AS t
			  	WHERE leagues.lgid = t.lgid
			   		AND yearid = 2016
			  	ORDER BY w DESC
			  	LIMIT 1) as top_teams;

/*
e. Finally, another advantage of the LATERAL keyword over using correlated 
subqueries is that you return multiple result rows. 
(Try to return more than one row in your correlated subquery from above 
and see what type of error you get). Rewrite your query on the previous 
problem sot that it returns the top 3 teams from each league 
in term of number of wins. Show the teamid and number of wins.
*/

SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL (SELECT
			  		name,
			  		w
			  	FROM teams AS t
			  	WHERE leagues.lgid = t.lgid
			   		AND yearid = 2016
			  	ORDER BY w DESC
			  	LIMIT 3) as top_teams;

---------------------------------------------------------------------------------------- Bonus 2

/*
2. Another advantage of lateral joins is for when you create calculated columns. 
In a regular query, when you create a calculated column, you cannot refer to it when you create other 
calculated columns. This is particularly useful if you want to reuse a calculated column multiple times. 
For example,

SELECT 
	teamid,
	w,
	l,
	w + l AS total_games,
	w*100.0 / total_games AS winning_pct
FROM teams
WHERE yearid = 2016
ORDER BY winning_pct DESC;

results in the error that "total_games" does not exist. However, I can restructure this query using the LATERAL keyword.

SELECT
	teamid,
	w,
	l,
	total_games,
	w*100.0 / total_games AS winning_pct
FROM teams t,
LATERAL (
	SELECT w + l AS total_games
) AS tg
WHERE yearid = 2016
ORDER BY winning_pct DESC;

a. Write a query which, for each player in the player table, assembles their 
birthyear, birthmonth, and birthday into a single column called birthdate which is of the date type.
*/

SELECT (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate
FROM people;

/*
b. Use your previous result inside a subquery using LATERAL to calculate for each player their age at debut and age at retirement.
(Hint: It might be useful to check out the PostgreSQL date and time functions 
https://www.postgresql.org/docs/8.4/functions-datetime.html).
*/

SELECT 
	namefirst,
	namelast,
	AGE(debut::date, birthdate) AS age_debut, 
	AGE(finalgame::date, birthdate) AS age_retire
FROM people,
LATERAL (
	SELECT (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate
	) AS bd

/*
c. Who is the youngest player to ever play in the major leagues?
*/

SELECT 
	namefirst,
	namelast,
	AGE(debut::date, birthdate) AS age_debut, 
	AGE(finalgame::date, birthdate) AS age_retire
FROM people,
LATERAL (
	SELECT (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate
	) AS bd
ORDER BY age_debut
LIMIT 1;

-- Joe Nuxhall debuted at age 15 years, 10 months, and 11 days

/*
d. Who is the oldest player to player in the major leagues? You'll likely have a lot of null values 
resulting in your age at retirement calculation. Check out the documentation on sorting rows here 
https://www.postgresql.org/docs/8.3/queries-order.html about how you can change how null values are sorted.
*/

SELECT 
	namefirst,
	namelast,
	AGE(debut::date, birthdate) AS age_debut, 
	AGE(finalgame::date, birthdate) AS age_retire
FROM people,
LATERAL (
	SELECT (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate
	) AS bd
ORDER BY age_retire DESC NULLS LAST
LIMIT 1;

-- Satchel Paige's last game was at age 59 years, 2 months, 18 days

---------------------------------------------------------------------------------------- Bonus 3

/*
3. For this question, you will want to make use of RECURSIVE CTEs 
(see https://www.postgresql.org/docs/13/queries-with.html). 
The RECURSIVE keyword allows a CTE to refer to its own output. Recursive CTEs are useful for navigating 
network datasets such as social networks, logistics networks, or employee hierarchies 
(who manages who and who manages that person). To see an example of the last item, see this tutorial: 
https://www.postgresqltutorial.com/postgresql-recursive-query/. 
In the next couple of weeks, you'll see how the graph database Neo4j can easily work with such datasets, 
but for now we'll see how the RECURSIVE keyword can pull it off (in a much less efficient manner) in PostgreSQL. 
(Hint: You might find it useful to look at this blog post when attempting to answer the following questions: 
https://data36.com/kevin-bacon-game-recursive-sql/.)

a. Willie Mays holds the record of the most All Star Game starts with 18. 
How many players started in an All Star Game with Willie Mays? 
(A player started an All Star Game if they appear in the allstarfull 
table with a non-null startingpos value).
*/

WITH as_named AS (
	SELECT 
		playerid,
		namefirst,
		namelast,
		yearid,
		gameid,
		startingpos
	FROM allstarfull
	INNER JOIN people
		USING (playerid)
)
SELECT COUNT(DISTINCT as2.playerid)
FROM as_named AS as1
LEFT JOIN as_named AS as2
	USING (gameid)
WHERE as1.playerid <> as2.playerid
	AND as1.startingpos IS NOT NULL
	AND as2.startingpos IS NOT NULL
	AND as1.namefirst || ' ' || as1.namelast = 'Willie Mays';

-- 125 distinct players started in a game with Willie Mays

-- Using RECURSIVE

WITH RECURSIVE as_named AS (
	SELECT 
		playerid,
		namefirst,
		namelast,
		yearid,
		gamenum,
		gameid,
		startingpos
	FROM allstarfull
	INNER JOIN people
		USING (playerid)
),
as_pairs AS (
	SELECT
		as1.playerid AS target_id,
		as1.namefirst || ' ' || as1.namelast AS target_player,
		as1.startingpos,
		gameid,
		yearid,
		gamenum,
		as2.playerid AS other_id,
		as2.namefirst || ' ' || as2.namelast AS other_player,
		as2.startingpos
	FROM as_named AS as1
	LEFT JOIN as_named AS as2
		USING (gameid, yearid, gamenum)
	WHERE as1.playerid <> as2.playerid
		AND as1.startingpos IS NOT NULL
		AND as2.startingpos IS NOT NULL
),
tree AS (
	SELECT
		i.target_player,
		i.target_id,
		i.other_player,
		i.other_id,
		0 AS link_count,
		i.other_player || '--(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player AS route
	FROM as_pairs AS i
	WHERE i.target_player = 'Willie Mays'
	UNION ALL
	SELECT
		t.target_player,
		t.target_id,
		i.other_player,
		i.other_id,
		t.link_count + 1,
		i.other_player || ' --(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player || chr(10) || t.route AS route
	FROM as_pairs AS i
	INNER JOIN tree AS t
		ON i.target_id = t.other_id
	AND t.link_count < 0
)
SELECT COUNT(DISTINCT other_player)
FROM tree;

-- 125 distinct players started in a game with Willie Mays

/*
b. How many players didn't start in an All Star Game with Willie Mays but started an All Star Game 
with another player who started an All Star Game with Willie Mays? 
For example, Graig Nettles never started an All Star Game with Willie Mayes, but he did start the 
1975 All Star Game with Blue Vida who started the 1971 All Star Game with Willie Mays.
*/

WITH RECURSIVE as_named AS (
	SELECT 
		playerid,
		namefirst,
		namelast,
		yearid,
		gamenum,
		gameid,
		startingpos
	FROM allstarfull
	INNER JOIN people
		USING (playerid)
),
as_pairs AS (
	SELECT
		as1.playerid AS target_id,
		as1.namefirst || ' ' || as1.namelast AS target_player,
		as1.startingpos,
		gameid,
		yearid,
		gamenum,
		as2.playerid AS other_id,
		as2.namefirst || ' ' || as2.namelast AS other_player,
		as2.startingpos
	FROM as_named AS as1
	LEFT JOIN as_named AS as2
		USING (gameid, yearid, gamenum)
	WHERE as1.playerid <> as2.playerid
		AND as1.startingpos IS NOT NULL
		AND as2.startingpos IS NOT NULL
),
tree AS (
	SELECT
		i.target_player,
		i.target_id,
		i.other_player,
		i.other_id,
		0 AS link_count,
		i.other_player || '--(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player AS route
	FROM as_pairs AS i
	WHERE i.target_player = 'Willie Mays'
	UNION ALL
	SELECT
		t.target_player,
		t.target_id,
		i.other_player,
		i.other_id,
		t.link_count + 1,
		i.other_player || ' --(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player || chr(10) || t.route AS route
	FROM as_pairs AS i
	INNER JOIN tree AS t
		ON i.target_id = t.other_id
	AND t.link_count < 1
)
SELECT COUNT(DISTINCT other_player)
FROM tree
WHERE other_player IN (
	SELECT other_player
	FROM tree
	WHERE link_count = 1
	EXCEPT
	SELECT other_player
	FROM tree
	WHERE link_count = 0
	);

/*
218 distinct players who started with a player who started with Willie Mays,
but who did not start with Willie Mays
*/

/*
c. We'll call two players connected if they both started in the same All Star Game. Using this, we can 
find chains of players. For example, one chain from Carlton Fisk to Willie Mays is as follows: 
Carlton Fisk started in the 1973 All Star Game with Rod Carew who started in the 1972 All Star Game 
with Willie Mays. Find a chain of All Star starters connecting Babe Ruth to Willie Mays. 
*/

WITH RECURSIVE as_named AS (
	SELECT 
		playerid,
		namefirst,
		namelast,
		yearid,
		gamenum,
		gameid,
		startingpos
	FROM allstarfull
	INNER JOIN people
		USING (playerid)
),
as_pairs AS (
	SELECT
		as1.playerid AS target_id,
		as1.namefirst || ' ' || as1.namelast AS target_player,
		as1.startingpos,
		gameid,
		yearid,
		gamenum,
		as2.playerid AS other_id,
		as2.namefirst || ' ' || as2.namelast AS other_player,
		as2.startingpos
	FROM as_named AS as1
	LEFT JOIN as_named AS as2
		USING (gameid, yearid, gamenum)
	WHERE as1.playerid <> as2.playerid
		AND as1.startingpos IS NOT NULL
		AND as2.startingpos IS NOT NULL
),
tree AS (
	SELECT
		i.target_player,
		i.target_id,
		i.other_player,
		i.other_id,
		0 AS link_count,
		i.other_player || '--(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player AS route
	FROM as_pairs AS i
	WHERE i.target_player = 'Willie Mays'
	UNION ALL
	SELECT
		t.target_player,
		t.target_id,
		i.other_player,
		i.other_id,
		t.link_count + 1,
		i.other_player || ' --(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player || chr(10) || t.route AS route
	FROM as_pairs AS i
	INNER JOIN tree AS t
		ON i.target_id = t.other_id
	AND t.link_count < 2
)
SELECT
	target_player,
	other_player,
	link_count,
	route
FROM tree
WHERE other_player = 'Babe Ruth'
LIMIT 1;

/* (You have to double-click or hover over the route to see the full output.)
Babe Ruth --(1933 - Game: #0)--> Joe Cronin
Joe Cronin --(1941 - Game: #0)--> Ted Williams
Ted Williams--(1957 - Game: #0)--> Willie Mays
*/

/*
d. How large a chain do you need to connect Derek Jeter to Willie Mays?
*/

WITH RECURSIVE as_named AS (
	SELECT 
		playerid,
		namefirst,
		namelast,
		yearid,
		gamenum,
		gameid,
		startingpos
	FROM allstarfull
	INNER JOIN people
		USING (playerid)
),
as_pairs AS (
	SELECT
		as1.playerid AS target_id,
		as1.namefirst || ' ' || as1.namelast AS target_player,
		as1.startingpos,
		gameid,
		yearid,
		gamenum,
		as2.playerid AS other_id,
		as2.namefirst || ' ' || as2.namelast AS other_player,
		as2.startingpos
	FROM as_named AS as1
	LEFT JOIN as_named AS as2
		USING (gameid, yearid, gamenum)
	WHERE as1.playerid <> as2.playerid
		AND as1.startingpos IS NOT NULL
		AND as2.startingpos IS NOT NULL
),
tree AS (
	SELECT
		i.target_player,
		i.target_id,
		i.other_player,
		i.other_id,
		0 AS link_count,
		i.other_player || '--(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player AS route
	FROM as_pairs AS i
	WHERE i.target_player = 'Derek Jeter'
	UNION ALL
	SELECT
		t.target_player,
		t.target_id,
		i.other_player,
		i.other_id,
		t.link_count + 1,
		i.other_player || ' --(' || yearid || ' - Game: #' || gamenum || ')--> ' || i.target_player || chr(10) || t.route AS route
	FROM as_pairs AS i
	INNER JOIN tree AS t
		ON i.target_id = t.other_id
	AND t.link_count < 3
)
SELECT
	target_player,
	other_player,
	link_count,
	route
FROM tree
WHERE other_player = 'Willie Mays'
LIMIT 1;

/*
3 links:
Willie Mays --(1971 - Game: #0)--> Rod Carew
Rod Carew --(1984 - Game: #0)--> Tony Gwynn
Tony Gwynn --(1997 - Game: #0)--> Alex Rodriguez
Alex Rodriguez--(2008 - Game: #0)--> Derek Jeter
*/
