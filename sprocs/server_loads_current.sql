CREATE OR REPLACE FUNCTION
    server_loads_current(
        IN group_name text,
        IN current_interval interval,
        OUT instance_count integer,
        OUT current_jobs double precision,
        OUT max_jobs double precision,
        OUT load_perc double precision,
        OUT timestamp_formatted text
    )
AS $$
BEGIN
    SELECT
        count(*),
        coalesce(sum(gl.average_jobs), 0),
        coalesce(sum(gl.max_jobs), 0)
    INTO
        instance_count,
        current_jobs,
        max_jobs
    FROM
        server_loads AS gl
    WHERE
        gl.group_name = server_loads_current.group_name
        AND (now() - gl.date) < current_interval;

    IF max_jobs <= 0 THEN
        load_perc = 0;
    ELSE
        load_perc = current_jobs / max_jobs * 100;
    END IF;

    SET LOCAL timezone TO 'UTC';
    timestamp_formatted = to_char(now(), 'YYYY-MM-DD') || 'T' || to_char(now(), 'HH24:MI:SS') || 'Z';
END;
$$ LANGUAGE plpgsql VOLATILE;
