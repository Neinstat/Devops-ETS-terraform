FROM proxysql/proxysql:2.7.1

RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY proxysql.cnf /etc/proxysql.cnf

EXPOSE 6032 6033

CMD ["proxysql", "--idle-threads", "-f", "--config", "/etc/proxysql.cnf"]