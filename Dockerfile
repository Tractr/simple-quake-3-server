# Step 1: Fetch pak0 file
FROM cirrusci/wget:latest as pak0
RUN wget https://github.com/nrempel/q3-server/raw/master/baseq3/pak0.pk3

# Step 2: Fetch custom maps
FROM node:10-alpine as maps
ADD maps /maps
WORKDIR /maps
RUN npm i && npm start

# Step 3: Build GUI front-end
FROM node:10-alpine as front-builder
ADD gui/front /app
WORKDIR /app
RUN npm ci && \
    npm run ng build -- --prod --output-path=dist

# Step 4: Build GUI back-end
FROM node:10-alpine as back-builder
ADD gui/back /app
WORKDIR /app
RUN npm ci && \
    npm run build

# Step 5: Build ioquake
# Cloned from jberrenberg/quake3:1.1
FROM alpine:3.12.1 as ioquake-builder

# to reduce image size all build and cleanup steps are performed in one docker layer

# INSTALL DEPENDENCIES
RUN apk --no-cache add curl g++ gcc git make && mkdir -p /tmp/build
# FETCH INSTALLATION FILES
RUN curl https://raw.githubusercontent.com/ioquake/ioq3/master/misc/linux/server_compile.sh -o /tmp/build/compile.sh && \
  curl https://ioquake3.org/data/quake3-latest-pk3s.zip --referer https://ioquake3.org/extras/patch-data/ -o /tmp/build/quake3-latest-pk3s.zip
# NOW THE INSTALLATION
RUN echo "y" | sh /tmp/build/compile.sh && \
  unzip /tmp/build/quake3-latest-pk3s.zip -d /tmp/build/ && \
  cp -r /tmp/build/quake3-latest-pk3s/* ~/ioquake3

######################################
# Step 6: Build final image
# Cloned from jberrenberg/quake3:1.1
FROM alpine:3.12.1

RUN apk add --no-cache --update nginx nodejs supervisor pwgen
RUN mkdir -p /run/nginx && chown nginx:nginx /run/nginx

# Define user
RUN adduser ioq3srv -D

# Copy ioquake
COPY --chown=ioq3srv:ioq3srv --from=ioquake-builder /root/ioquake3 /home/ioq3srv/ioquake3
# Copy pak0
COPY --chown=ioq3srv:ioq3srv --from=pak0 /pak0.pk3 /home/ioq3srv/ioquake3/baseq3/
# Copy front-end
COPY --chown=ioq3srv:ioq3srv --from=front-builder /app/dist /home/ioq3srv/gui/front
# Copy back-end
COPY --chown=ioq3srv:ioq3srv --from=back-builder /app /home/ioq3srv/gui/back
# Copy maps
COPY --chown=ioq3srv:ioq3srv --from=maps /maps/pk3s /home/ioq3srv/ioquake3/baseq3/
COPY --chown=ioq3srv:ioq3srv --from=maps /maps/images /home/ioq3srv/gui/front/assets/images/
COPY --chown=ioq3srv:ioq3srv --from=maps /maps/custom.json /home/ioq3srv/gui/back/maps/
# Copy Q3 server config
COPY --chown=ioq3srv:ioq3srv q3server/server.cfg /home/ioq3srv/ioquake3/baseq3/
# Config NGINX config
COPY nginx/default.nginx /etc/nginx/conf.d/default.conf

# Export ports
EXPOSE 27960/udp
EXPOSE 8080
EXPOSE 8443

# Set entrypoint
COPY --chown=ioq3srv:ioq3srv entrypoint.sh /entrypoint.sh
COPY --chown=ioq3srv:ioq3srv supervisord.conf /etc/supervisord.conf
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
