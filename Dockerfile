# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

FROM centos:7 as env

ENV ERLANG_VERSION=20.3.8.26
ENV RIAK_VERSION=3.0
ENV RIAK_RPM="riak-${RIAK_VERSION}-1.el7x86_64.rpm"

FROM env as builder

RUN set -o errexit -o nounset;\
    yum -y update;\
	yum -y install \
        gcc-c++ \
        git \
        make \
        pam-devel \
        rpm-build \
        wget \
        which \
        epel-release;\
	yum -y install "https://packages.erlang-solutions.com/erlang/rpm/centos/7/x86_64/esl-erlang_${ERLANG_VERSION}-1~centos~7_amd64.rpm";\
    yum -y clean all;\
	cd /tmp;\
	git clone --depth=1 --branch="${RIAK_VERSION}" https://github.com/basho/riak;\
	cd riak;\
	make package;\
    mv "/tmp/riak/rel/pkg/out/packages/${RIAK_RPM}" /tmp/;

FROM env

EXPOSE 8087/tcp 8088/tcp 8098/tcp
ENV RIAK_HOME=/usr/lib64/riak

COPY --from=builder "/tmp/${RIAK_RPM}" .
COPY riak-cluster.sh "${RIAK_HOME}/"

RUN set -o errexit -o nounset;\
    yum -y update;\
    yum -y install java-1.8.0-openjdk-headless;\
    yum -y install "$RIAK_RPM";\
    yum -y clean all;\
    rm "$RIAK_RPM";\
    chown -R riak:riak /var/lib/riak/ "${RIAK_HOME}/";

CMD ["${RIAK_HOME}/riak-cluster.sh"]
