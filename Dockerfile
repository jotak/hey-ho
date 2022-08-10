# quay.io/jotak/hey:0.1 is just a build of https://github.com/rakyll/hey (commit 898582754e00405372f0686641441168f4e2f489)
FROM quay.io/jotak/hey:0.1 as hey

FROM docker.io/nginxinc/nginx-unprivileged:1.23

COPY --from=hey /hey /tmp/

USER nginx
