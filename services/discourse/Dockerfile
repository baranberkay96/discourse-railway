FROM discourse/discourse:2026.7.6@sha256:f8a7a3c0f7e5ee6c66e3d8b24d55ba860ed8f7f265384aba81a3c440b008108a

# runit initializes the mounted /shared volume and starts nginx, the app server
# and Sidekiq. Add setup to its pre-service phase, independent of being PID 1.
COPY --chmod=0755 zz-railway-bootstrap /etc/runit/1.d/zz-railway-bootstrap
COPY --chmod=0755 railway-config.rb wait-for-data.rb bootstrap-admin.rb /opt/railway/
RUN rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p /var/log/nginx \
    && find /var/www/discourse/plugins -mindepth 1 -maxdepth 1 -printf '%f\n' > /opt/railway/plugins.list \
    && sed -i 's|proxy_set_header X-Forwarded-For $remote_addr;|proxy_set_header X-Forwarded-For $http_x_forwarded_for;|g' /etc/nginx/conf.d/discourse.conf \
    && nginx -t

EXPOSE 80
CMD ["ruby", "/opt/railway/railway-config.rb"]
