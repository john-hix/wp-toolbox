-- This query finds attachments the same title. Each column should be saved
-- to a text file, then fed to dedupe-attachments.sh via positional arguments
SELECT wp_posts.post_title, COUNT(wp_posts.post_title) FROM wp_posts
WHERE wp_posts.post_type="attachment"
GROUP BY wp_posts.post_title
HAVING COUNT(wp_posts.post_title) > 1
ORDER BY COUNT(wp_posts.post_title) DESC

-- This query gets all the posts that have the meta jh_delete_duplicate,
-- which means it is the query to run to get a list of IDs to feed to a deletion script
SELECT wp_posts.ID
FROM wp_posts
WHERE post_type="attachment"
AND wp_posts.ID
IN (
    SELECT wp_term_relationships.object_id
    FROM wp_term_relationships
	WHERE wp_term_relationships.term_taxonomy_id
    IN (
        SELECT wp_terms.term_id
        FROM wp_terms
        WHERE wp_terms.slug IN ("jh_delete_duplicate")
    )
)

-- Find all the posts with either jh_save or jh_delete_duplicate as post meta,
-- mostly for resetting these posts during development of the dedupe script
SELECT wp_posts.id
FROM wp_posts
WHERE wp_posts.id
IN (
    SELECT wp_term_relationships.object_id
    FROM wp_term_relationships
	WHERE wp_term_relationships.term_taxonomy_id
    IN (
        SELECT wp_terms.term_id
        FROM wp_terms
        WHERE wp_terms.slug IN ("jh_save", "jh_delete_duplicate")
    )
)
