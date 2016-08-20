CREATE OR REPLACE VIEW test_duration_stats AS
WITH
dist_ranks AS (
    SELECT
        test_id AS id,
        percentile_disc(0.25) WITHIN GROUP (ORDER BY duration) AS quartile1,
        percentile_disc(0.5) WITHIN GROUP (ORDER BY duration) AS quartile2,
        percentile_disc(0.75) WITHIN GROUP (ORDER BY duration) AS quartile3,
        percentile_disc(0.9) WITHIN GROUP (ORDER BY duration) AS perc90
    FROM user_test_durations
    WHERE role = 'Student'
    GROUP BY test_id
),
hist_limits AS (
    SELECT
        id,
        greatest(quartile3 + 2 * (quartile3 - quartile2), perc90) AS limit
    FROM dist_ranks
),
hist_thresholds AS (
    SELECT
        id,
        interval_hist_thresholds(hist_limits.limit) AS thresholds
    FROM hist_limits
),
stats_from_data AS (
    SELECT
        test_id AS id,
        min(duration) AS min,
        max(duration) AS max,
        avg(duration) AS mean,
        percentile_disc(0.5) WITHIN GROUP (ORDER BY duration) AS median,
        thresholds,
        interval_array_to_seconds(thresholds) AS threshold_seconds,
        interval_array_to_strings(thresholds) AS threshold_labels,
        array_histogram(duration, thresholds) AS hist
    FROM user_test_durations
    JOIN hist_thresholds ON (hist_thresholds.id = user_test_durations.test_id)
    WHERE role = 'Student'
    GROUP BY test_id,thresholds
),
zero_stats AS (
    SELECT
        id,
        interval '0' AS min,
        interval '0' AS max,
        interval '0' AS mean,
        interval '0' AS median,
        ARRAY[interval '0m', interval '10m'] AS thresholds,
        ARRAY[0, 600] AS threshold_seconds,
        ARRAY['0m', '10m'] AS threshold_labels,
        ARRAY[0] AS hist
    FROM tests AS t
    WHERE NOT EXISTS (
        SELECT * FROM stats_from_data WHERE stats_from_data.id = t.id
    )
    AND t.deleted_at IS NULL
)
SELECT * FROM stats_from_data
UNION ALL
SELECT * FROM zero_stats
;