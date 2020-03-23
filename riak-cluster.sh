#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Cluster start script to bootstrap a Riak 3.0 cluster.
#
set -o errexit -o nounset -o xtrace;

set -o allexport;
if [[ -x /usr/sbin/riak ]]; then
  RIAK=/usr/sbin/riak;
else
  RIAK=$RIAK_HOME/bin/riak;
fi;
RIAK_CONF=/etc/riak/riak.conf;
USER_CONF=/etc/riak/user.conf;
RIAK_ADVANCED_CONF=/etc/riak/advanced.config;
RIAK_ADMIN="${RIAK} admin";
SCHEMAS_DIR=/etc/riak/schemas/;

# Set ports for PB and HTTP
PB_PORT=${PB_PORT:-8087};
HTTP_PORT=${HTTP_PORT:-8098};

# Use ping to discover our HOSTNAME because it's easier and more reliable than other methods
HOST=$(ping -c1 $HOSTNAME | awk '/^PING/ {print $3}' | sed 's/[()]//g')||'127.0.0.1';

# CLUSTER_NAME is used to name the nodes and is the value used in the distributed cookie
CLUSTER_NAME=${CLUSTER_NAME:-riak};

# The COORDINATOR_NODE is the first node in a cluster to which other nodes will eventually join
COORDINATOR_NODE=${COORDINATOR_NODE:-$HOSTNAME};
COORDINATOR_NODE_HOST=$(ping -c1 $COORDINATOR_NODE | awk '/^PING/ {print $3}' | sed 's/[()]//g')||'127.0.0.1';
set +o allexport;

# Run all prestart scripts
PRESTART=$(find /etc/riak/prestart.d/ -name '*.sh' -print | sort);
for s in $PRESTART; do
  source $s;
done;

# Start the node and wait until fully up
$RIAK start;
until $RIAK_ADMIN wait-for-service riak_kv; do
  echo 'Waiting for riak_kv to start...';
  sleep 2;
done;

# Run all poststart scripts
POSTSTART=$(find /etc/riak/poststart.d/ -name '*.sh' -print | sort);
for s in $POSTSTART; do
  source $s;
done;

# Trap SIGTERM and SIGINT and tail the log file indefinitely
PID=$!;
tail -F /var/log/riak/console.log &
trap "$RIAK stop; kill $PID" SIGTERM SIGINT;
wait $PID;
