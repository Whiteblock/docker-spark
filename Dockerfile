FROM debian:stretch
MAINTAINER Whiteblock "https://whiteblock.io"

# Users with other locales should set this in their derivative image
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN apt-get update \
 && apt-get install -y \
    ca-certificates \
    curl \
    locales \
    lsb-release \
    gnupg2 \
    procps \
    python3 \
    python3-setuptools \
    unzip \
 && easy_install3 pip py4j \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN dpkg-reconfigure -f noninteractive locales \
 && locale-gen C.UTF-8 \
 && /usr/sbin/update-locale LANG=C.UTF-8 \
 && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
 && locale-gen

RUN pip install google-cloud google-cloud-storage google-cloud-pubsub pyspark

# https://cloud.google.com/sdk/docs/downloads-apt-get
# gcloud etc
WORKDIR /tmp
COPY install-google-sdk.sh install-google-sdk.sh
RUN ./install-google-sdk.sh
# force everything to python3
RUN ln -sf /usr/bin/python3 /usr/bin/python

# https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-latest.jar
# install google storage connector for hadoop
WORKDIR /opt/jars
RUN curl -LO https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-latest.jar

# install kubectl v1.14.1
WORKDIR /usr/local/bin
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/linux/amd64/kubectl
RUN chmod a+x kubectl

WORKDIR /sbin
# https://github.com/krallin/tini
ENV TINI_VERSION v0.18.0
RUN curl -LO https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini
RUN chmod a+x tini

# http://blog.stuart.axelbrooke.com/python-3-on-spark-return-of-the-pythonhashseed
ENV PYTHONHASHSEED 0
ENV PYTHONIOENCODING UTF-8
ENV PIP_DISABLE_PIP_VERSION_CHECK 1

# JAVA
ARG JAVA_MAJOR_VERSION=12
ARG JAVA_UPDATE_VERSION=0.1
ARG JAVA_BUILD_NUMBER=12
ENV JAVA_HOME /usr/jdk-${JAVA_MAJOR_VERSION}.${JAVA_UPDATE_VERSION}

ENV PATH $PATH:$JAVA_HOME/bin
RUN curl -sL --retry 3 --insecure \
  --header "Cookie: oraclelicense=accept-securebackup-cookie;" \
  "http://download.oracle.com/otn-pub/java/jdk/${JAVA_MAJOR_VERSION}.${JAVA_UPDATE_VERSION}+${JAVA_BUILD_NUMBER}/69cfe15208a647278a19ef0990eea691/jdk-${JAVA_MAJOR_VERSION}.${JAVA_UPDATE_VERSION}_linux-x64_bin.tar.gz" \
  | gunzip \
  | tar x -C /usr/ \
  && ln -s $JAVA_HOME /usr/java \
  && rm -rf $JAVA_HOME/man

# HADOOP
# TODO: upgrade to 3.1.2
ENV HADOOP_VERSION 3.0.0
ENV HADOOP_HOME /usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH $PATH:$HADOOP_HOME/bin
RUN curl -sL --retry 3 \
  "https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
  | gunzip \
  | tar -x -C /usr/

# HIVE
ENV HIVE_VERSION 3.1.1
ENV HIVE_HOME /usr/apache-hive-$HIVE_VERSION-bin
ENV PATH $PATH:$HIVE_HOME/bin
RUN curl -sL --retry 3 \
  "https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz" \
  | gunzip \
  | tar -x -C /usr/
COPY hive-site.xml /usr/apache-hive-3.1.1-bin/conf/hive-site.xml

# SPARK
ENV SPARK_VERSION 2.4.1
ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-without-hadoop
ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*:/opt/jars/gcs-connector-hadoop3-latest.jar"
ENV PATH $PATH:${SPARK_HOME}/bin
RUN curl -sL --retry 3 \
  "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
  | gunzip \
  | tar x -C /usr/ \
 && mv /usr/$SPARK_PACKAGE $SPARK_HOME

# https://cloud.google.com/dataproc/docs/concepts/connectors/install-storage-connector
COPY core-site.xml "${SPARK_HOME}/conf/core-site.xml"

WORKDIR $SPARK_HOME
COPY entrypoint.sh entrypoint.sh
RUN chmod a+x entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]

#CMD ["bin/spark-class", "org.apache.spark.deploy.master.Master"]
