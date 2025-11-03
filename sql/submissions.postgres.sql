-- Parameterized query for PostgreSQL
-- Named parameters bound via psycopg: %(username)s, %(start_ts)s, %(end_ts)s

WITH fs AS (
  -- Step 1: get all relevant submissions for the user
  SELECT
      s.user_id,
      s.assignment_id,
      s.attempt,
      s.submitted_at,
      s.workflow_state,
      s.submission_type,
      s.score,
      s.graded_at
  FROM submissions s
  JOIN pseudonyms p ON p.user_id = s.user_id
  WHERE p.unique_id = %(username)s
    AND s.submitted_at >= %(start_ts)s
    AND s.submitted_at <  %(end_ts)s
    AND s.workflow_state IN ('submitted','graded')
    AND s.submission_type IS NOT NULL
),
matched AS (
  -- Step 2: join each submission to web_logs in a ±20 minute window
  -- and rank logs to prefer real submission routes > participated events > fallback
  SELECT
      fs.user_id,
      fs.assignment_id,
      fs.submitted_at,
      fs.attempt,
      fs.workflow_state,
      fs.submission_type,
      fs.score,
      fs.graded_at,

      -- forensic info
      r.remote_ip,
      r.url,
      r.session_id,
      r.http_method,
      r.http_status,
      r.user_agent,
      r.web_application_controller AS controller,
      r.web_application_action     AS action,
      r.timestamp                  AS log_time,

      -- assign a tier/rank: 1=submit event, 2=participated, 3=any nearby
      CASE
        WHEN r.web_application_controller IN ('submissions','assignment_submissions','quiz_submissions')
         AND r.web_application_action     IN ('create','update','submit','finish','complete')
         AND r.http_method                IN ('POST','PUT')
         AND (
              r.assignment_id = fs.assignment_id
           OR (r.web_application_context_type = 'Assignment' AND r.web_application_context_id = fs.assignment_id)
           OR (r.url LIKE '%%/assignments/' || fs.assignment_id || '%%')
         )
        THEN 1
        WHEN r.participated = 1
         AND (
              r.assignment_id = fs.assignment_id
           OR (r.web_application_context_type = 'Assignment' AND r.web_application_context_id = fs.assignment_id)
           OR (r.url LIKE '%%/assignments/' || fs.assignment_id || '%%')
         )
        THEN 2
        ELSE 3
      END AS source_rank,

      -- pick the single best log per submission:
      --  first by tier (1 > 2 > 3), then by closest timestamp
      ROW_NUMBER() OVER (
        PARTITION BY fs.user_id, fs.assignment_id, fs.submitted_at
        ORDER BY
          CASE
            WHEN r.web_application_controller IN ('submissions','assignment_submissions','quiz_submissions')
             AND r.web_application_action     IN ('create','update','submit','finish','complete')
             AND r.http_method IN ('POST','PUT')
             AND (
                  r.assignment_id = fs.assignment_id
               OR (r.web_application_context_type = 'Assignment' AND r.web_application_context_id = fs.assignment_id)
               OR (r.url LIKE '%%/assignments/' || fs.assignment_id || '%%')
             ) THEN 1
            WHEN r.participated = 1
             AND (
                  r.assignment_id = fs.assignment_id
               OR (r.web_application_context_type = 'Assignment' AND r.web_application_context_id = fs.assignment_id)
               OR (r.url LIKE '%%/assignments/' || fs.assignment_id || '%%')
             ) THEN 2
            ELSE 3
          END,
          ABS( EXTRACT(EPOCH FROM (r.timestamp - fs.submitted_at)) )
      ) AS rn
  FROM fs
  LEFT JOIN web_logs r
    ON r.user_id = fs.user_id
   AND r.timestamp BETWEEN fs.submitted_at - INTERVAL '20' MINUTE
                       AND fs.submitted_at + INTERVAL '20' MINUTE
)
SELECT
    fs.submitted_at                      AS timestamp_est,
    p.unique_id                          AS username,
    co.sis_source_id                     AS course_sis_id,
    co.name                              AS course_name,
    a.title                              AS assignment,
    fs.attempt,
    fs.workflow_state,
    fs.submission_type,
    fs.score,
    fs.graded_at AS graded_at,

    -- final forensic fields
    m.remote_ip                          AS ip_at_submit,
    m.url                                AS url_at_submit,
    m.http_method,
    m.http_status,
    m.controller,
    m.action,
    m.user_agent,
    m.log_time AS log_time,
    m.source_rank                        AS match_tier  -- 1=submit, 2=participated, 3=nearby

FROM fs
JOIN assignments a
  ON a.id = fs.assignment_id
JOIN courses co
  ON a.context_type = 'Course' AND a.context_id = co.id
JOIN enrollments e
  ON e.user_id = fs.user_id
 AND e.course_id = co.id
 AND e.type = 'StudentEnrollment'
 AND e.workflow_state = 'active'
JOIN pseudonyms p
  ON p.user_id = fs.user_id
LEFT JOIN matched m
  ON m.user_id = fs.user_id
 AND m.assignment_id = fs.assignment_id
 And m.submitted_at = fs.submitted_at
 AND m.rn = 1
ORDER BY fs.submitted_at;
