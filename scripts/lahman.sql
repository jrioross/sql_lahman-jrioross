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
	SUM(sb),
	SUM(sb + cs) AS sb_attempts,
	ROUND(SUM(sb)*100.0/SUM(sb+cs), 2) AS sb_perc
FROM people
INNER JOIN batting
	USING(playerid)
WHERE yearid = 2016
GROUP BY playerid, namefirst, namelast
HAVING SUM(sb + cs) >= 20
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
