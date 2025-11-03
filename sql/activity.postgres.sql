-- Parameterized query for PostgreSQL
-- Named parameters bound via psycopg: %(username)s, %(start_ts)s, %(end_ts)s

SELECT DISTINCT 
    r.timestamp AS timestamp_est,
    p.unique_id AS username,
    r.remote_ip AS IP,
    r.user_agent,
    r.http_method,
    r.http_status,
    r.session_id,
    r.URL,
    r.web_application_controller AS controller,
    r.web_application_action AS action,
    r.web_application_context_type AS context_type,
    r.web_application_context_id AS context_id,
    d.title AS discussion_topic,
    c.subject AS conversation_subject,
    a.title AS assignment,
    q.title AS quiz,
    co.sis_source_id AS course_sis_id,
    co.name AS course_name
FROM web_logs r
LEFT JOIN pseudonyms p ON r.user_id = p.user_id
LEFT JOIN assignments a ON r.assignment_id = a.id
LEFT JOIN quizzes q ON r.quiz_id = q.id
LEFT JOIN conversations c ON r.conversation_id = c.id
LEFT JOIN discussion_topics d ON r.discussion_id = d.id
LEFT JOIN courses co ON r.course_id = co.id
WHERE p.unique_id = %(username)s
  AND r.timestamp >= %(start_ts)s
  AND r.timestamp <  %(end_ts)s
ORDER BY r.timestamp;