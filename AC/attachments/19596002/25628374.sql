
use mail;

ALTER TABLE transactions 
	ADD COLUMN tr_parent_id INT(11) DEFAULT NULL;

ALTER TABLE transactions 
	ADD INDEX tr_origin (tr_type_id, tr_parent_id);

-- Backout
/*transactions
ALTER TABLE transactions 
	DROP COLUMN tr_parent_id;

ALTER TABLE transactions 
	DROP INDEX tr_origin;
*/
