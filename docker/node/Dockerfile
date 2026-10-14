FROM node:24-alpine

WORKDIR /opt/gotacna-bootstrap

COPY bootstrap.cjs ./bootstrap.cjs
COPY entrypoint.sh /usr/local/bin/gotacna-node-entrypoint

RUN chmod +x /usr/local/bin/gotacna-node-entrypoint

ENV NODE_PATH=/app/node_modules
WORKDIR /app
EXPOSE 3001

ENTRYPOINT ["gotacna-node-entrypoint"]