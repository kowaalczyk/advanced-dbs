FROM neo4j:3.5

COPY plugins/* plugins/
COPY conf/* conf/

COPY *.sh /graph/
RUN chmod +x /graph/*sh
