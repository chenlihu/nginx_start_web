docker run -d \
  --name nginx_animon_poster \
  --restart always \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -p 8001:80 \
  -v $(pwd)/dockerfiles/config/nginx/conf.d:/etc/nginx/conf.d \
  -v $(pwd)/dockerfiles/config/nginx/nginx.conf:/etc/nginx/nginx.conf \
  -v /data/clh/animon_first_page:/data \
  nginx:latest