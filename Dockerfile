FROM node:alpine

WORKDIR /splitter

ADD package.json .

RUN npm i

ADD . .
