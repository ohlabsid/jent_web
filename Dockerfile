# Runtime-only image — nginx serving the static Flutter web bundle.
# CI builds the bundle on the runner (see .github/workflows/
# deploy-dokploy.yml) so the VPS never needs the Flutter SDK.
# Run `flutter build web --release` first if building locally.
FROM nginx:stable-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html

EXPOSE 80
