#!/usr/bin/env bash

DB=$(echo $DATABASE_URL | perl -lne 'print "$1 $2 $3 $4 $5 $6 $7" if /^postgres:\/\/([^:]+):([^@]+)@(.*?):(.*?)\/(.*?)(\\?.*)?$/')
DB_URI=( $DB )
DB_USER=${DB_URI[0]}
DB_PASS=${DB_URI[1]}
DB_HOST=${DB_URI[2]}
DB_PORT=${DB_URI[3]}
DB_NAME=${DB_URI[4]}

QB=$(echo $QC_DATABASE_URL | perl -lne 'print "$1 $2 $3 $4 $5 $6 $7" if /^postgres:\/\/([^:]+):([^@]+)@(.*?):(.*?)\/(.*?)(\\?.*)?$/')
QB_URI=( $DB )
QB_USER=${DB_URI[0]}
QB_PASS=${DB_URI[1]}
QB_HOST=${DB_URI[2]}
QB_PORT=${DB_URI[3]}
QB_NAME=${DB_URI[4]}

if [ "$PGBOUNCER_PREPARED_STATEMENTS" == "false" ]
then
  export PGBOUNCER_URI=postgres://$DB_USER:$DB_PASS@127.0.0.1:6000/$DB_NAME?prepared_statements=false
  export QC_PGBOUNCER_URI=postgres://$QB_USER:$QB_PASS@127.0.0.1:6000/$QB_NAME?prepared_statements=false
else
  export PGBOUNCER_URI=postgres://$DB_USER:$DB_PASS@127.0.0.1:6000/$DB_NAME
  export QC_PGBOUNCER_URI=postgres://$QB_USER:$QB_PASS@127.0.0.1:6000/$QB_NAME
fi


mkdir -p /app/vendor/stunnel/var/run/stunnel/
cat >> /app/vendor/stunnel/stunnel-pgbouncer.conf << EOFEOF
foreground = yes

options = NO_SSLv2
options = SINGLE_ECDH_USE
options = SINGLE_DH_USE
socket = r:TCP_NODELAY=1
options = NO_SSLv3
ciphers = HIGH:!ADH:!AECDH:!LOW:!EXP:!MD5:!3DES:!SRP:!PSK:@STRENGTH

[heroku-postgres]
client = yes
protocol = pgsql
accept  = localhost:6002
connect = $DB_HOST:$DB_PORT
retry = yes

[qc-heroku-postgres]
client = yes
protocol = pgsql
accept  = localhost:6102
connect = $QB_HOST:$QB_PORT
retry = yes

EOFEOF

cat >> /app/vendor/pgbouncer/users.txt << EOFEOF
"$DB_USER" "$DB_PASS"
"$QB_USER" "$QB_PASS"
EOFEOF

cat >> /app/vendor/pgbouncer/pgbouncer.ini << EOFEOF
[databases]
$DB_NAME = host=localhost port=6002
$QB_NAME = host=localhost port=6102
[pgbouncer]
listen_addr = localhost
listen_port = 6000
auth_type = md5
auth_file = /app/vendor/pgbouncer/users.txt

; When server connection is released back to pool:
;   session      - after client disconnects
;   transaction  - after transaction finishes
;   statement    - after statement finishes
pool_mode = ${PGBOUNCER_POOL_MODE:-transaction}
server_reset_query =
max_client_conn = 100
default_pool_size = ${PGBOUNCER_DEFAULT_POOL_SIZE:-1}
reserve_pool_size = ${PGBOUNCER_RESERVE_POOL_SIZE:-1}
reserve_pool_timeout = ${PGBOUNCER_RESERVE_POOL_TIMEOUT:-5.0}
EOFEOF

