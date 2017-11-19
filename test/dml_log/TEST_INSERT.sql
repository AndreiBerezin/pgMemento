-- TEST_INSERT.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This script is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- Script that checks log tables when an INSERT event happens
-- (also for logging initial state with pgmemento.log_table_state)
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                    | Author
-- 0.1.0     2017-11-18   initial commit                                   FKun
--

-- get test number
SELECT nextval('pgmemento.test_seq') AS n \gset

\echo
\echo 'TEST ':n': pgMemento audit INSERT events'

\echo
\echo 'TEST ':n'.1: Log content as inserted'
DO
$$
DECLARE
  test_txid BIGINT := txid_current();
  test_event INTEGER;
BEGIN
  -- log content of table
  PERFORM pgmemento.log_table_state('cityobject', 'citydb');

  -- query for logged transaction
  ASSERT (
    SELECT EXISTS (
      SELECT
        txid
      FROM
        pgmemento.transaction_log
      WHERE
        txid = test_txid
    )
  ), 'Error: Did not find test entry in transaction_log table!';

  -- query for logged table event
  SELECT
    id
  INTO
    test_event
  FROM
    pgmemento.table_event_log
  WHERE
    transaction_id = test_txid
    AND op_id = 3;

  ASSERT test_event IS NOT NULL, 'Error: Did not find test entry in table_event_log table!';

  -- join table with entries from row_log table to check if every row has been logged
  ASSERT (
    SELECT NOT EXISTS (
      SELECT
        c.id
      FROM
        citydb.cityobject c
      LEFT JOIN
        pgmemento.row_log r
        ON c.audit_id = r.audit_id 
      WHERE
        r.audit_id IS NULL
    )
  ),
  'Error: Entries of test table were not entirely logged in row_log table!';
END;
$$
LANGUAGE plpgsql;

\echo
\echo 'TEST ':n'.1: Log content as inserted - correct'

\echo
\echo 'TEST ':n'.2: Log INSERT command'
DO
$$
DECLARE
  insert_audit_id INTEGER; 
  test_txid BIGINT := txid_current();
  test_event INTEGER;
  jsonb_log JSONB;
BEGIN
  -- INSERT new entry in table
  INSERT INTO citydb.cityobject (objectclass_id, lineage) VALUES (0, 'pgm_insert_test')
    RETURNING audit_id INTO insert_audit_id;

  -- query for logged transaction
  ASSERT (
    SELECT EXISTS (
      SELECT
        txid
      FROM
        pgmemento.transaction_log
      WHERE
        txid = test_txid
    )
  ), 'Error: Did not find test entry in transaction_log table!';

  -- query for logged table event
  SELECT
    id
  INTO
    test_event
  FROM
    pgmemento.table_event_log
  WHERE
    transaction_id = test_txid
    AND op_id = 3;

  ASSERT test_event IS NOT NULL, 'Error: Did not find test entry in table_event_log table!';

  -- query for logged row
  SELECT
    changes
  INTO
    jsonb_log
  FROM
    pgmemento.row_log
  WHERE
    audit_id = insert_audit_id
    AND event_id = test_event;

  ASSERT jsonb_log IS NULL, 'Error: Wrong content in row_log table: %' jsonb_log;
END;
$$
LANGUAGE plpgsql;

\echo
\echo 'TEST ':n'.2: Log INSERT command - correct'

\echo
\echo 'TEST ':n': pgMemento audit INSERT events - correct'