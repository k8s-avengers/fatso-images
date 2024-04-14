#!/bin/bash
set -e



set -e # stop on errors

# Ensure /usr/local/bin is first in PATH
export PATH="/usr/local/bin:${PATH}"

export DEBIAN_FRONTEND=noninteractive

declare K3S_CLUSTER_NAME="${K3S_CLUSTER_NAME:-"$(hostname)"}"

# Grab some networking info
declare net_interface net_ipv4_gateway net_ipv4_addr
net_interface="$(ip -4 route get 8.8.8.8 | grep via | cut -d " " -f 5 | xargs echo -n)"
echo "Determined net_interface: ${net_interface}" >&2
net_ipv4_gateway="$(ip -4 route get 8.8.8.8 | grep via | cut -d " " -f 3 | xargs echo -n)"
net_ipv4_addr="$(ip -4 addr s dev "${net_interface}" | grep "scope global .* ${net_interface}" | tr -s " " | cut -d " " -f 3 | xargs echo -n | cut -d "/" -f 1)"
echo "Determined net_ipv4_gateway: ${net_ipv4_gateway}" >&2
echo "Determined net_ipv4_addr: ${net_ipv4_addr}" >&2

# Install some packages
declare -a pkgs_to_install=()
[[ ! -f /usr/sbin/iptables-save ]] && pkgs_to_install+=("iptables")
[[ ! -f /usr/bin/jq ]] && pkgs_to_install+=("jq")
[[ ! -f /usr/bin/nano ]] && pkgs_to_install+=("nano")
[[ ! -f /usr/bin/tree ]] && pkgs_to_install+=("tree")
[[ ! -f /usr/bin/wget ]] && pkgs_to_install+=("wget")
[[ ! -f /usr/bin/git ]] && pkgs_to_install+=("git")

if [[ ! -f /usr/bin/k9s ]]; then
	pkgs_to_install+=("/root/k9s_linux_amd64.deb")
	wget -q -O /root/k9s_linux_amd64.deb "https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_linux_amd64.deb"
fi

# Install packages if array is not empty
if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
	echo "Installing packages: ${pkgs_to_install[*]}" >&2
	apt -y install "${pkgs_to_install[@]}"
fi

# Get the current kernel's major version
declare -i current_kernel_major_version
current_kernel_major_version=$(uname -r | cut -d '.' -f 1)

# If not at least 6, install el-kernel-lts from k8s-avengers's repo
if [[ ${current_kernel_major_version} -lt 6 ]]; then
	echo "Unsupported kernel version ${current_kernel_major_version}" >&2
	exit 1
fi

# Config for k3s install
mkdir -p /etc/rancher/k3s/config.yaml.d
cat <<- K3S_MAIN_CONFIG > /etc/rancher/k3s/config.yaml.d/install_config.yaml
	node-label:
	  - "foo=bar"
	  - "something=amazing"
K3S_MAIN_CONFIG

# Array for cmdline opts
declare k3s_cmdline_opts=()

# Export some vars for envsubst
export BASE_DOMAIN_INGRESS="${BASE_DOMAIN_INGRESS:-"app.${net_ipv4_addr}.nip.io"}"
echo "BASE_DOMAIN_INGRESS: ${BASE_DOMAIN_INGRESS}" >&2

# Deploy some manifests to /var/lib/rancher/k3s/server/manifests
mkdir -p /var/lib/rancher/k3s/server/manifests

k3s_cmdline_opts+=("--cluster-init") # initialize a HA cluster, meaning: with embedded etcd
# k3s_cmdline_opts+=("--tls-san=${net_ipv4_addr}") # heh? why?
k3s_cmdline_opts+=("--disable-kube-proxy") # for cilium's replacement
k3s_cmdline_opts+=("--disable=servicelb")
#k3s_cmdline_opts+=("--cluster-domain k3s.cluster")

# kube-prom-stack, which Prometheus and a lot of friends; also the Prometheus CRDs.
cat << K3S_MANIFEST_PROM_STACK | envsubst > /var/lib/rancher/k3s/server/manifests/aaaa-prom-stack.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  namespace: kube-system
  name: promstack
spec:
  bootstrap: true # don't wait for CNI
  targetNamespace: monitoring
  createNamespace: true
  chart: kube-prometheus-stack
  repo: https://prometheus-community.github.io/helm-charts
  version: 56.7.0
  valuesContent: |-
    cleanPrometheusOperatorObjectNames: true
    commonLabels:
      global-values-version: "0001"
    kubeEtcd:
      enabled: false # k3s
    kubeControllerManager:
      enabled: false # k3s
    kubeScheduler:
      enabled: false # k3s
    kubeProxy:
      enabled: false # k3s
    alertmanager:
      enabled: true
      ingress:
        enabled: true
        ingressClassName: nginx
        hosts: [ "alertmanager.${BASE_DOMAIN_INGRESS}" ]
        #tls: [ { hosts: [ "alertmanager.${BASE_DOMAIN_INGRESS}" ], secretName: "alertmanager-ingress-tls" } ]
    grafana: # See https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
      adminPassword: grafanaAdmin
      deploymentStrategy:
        type: Recreate # destroy the old one before creating a new one, otherwise PVC is held hostage
      persistence:
        type: sts
        enabled: true
        accessModes: [ "ReadWriteOnce" ]
        size: "1Gi"
      plugins: [ "grafana-piechart-panel" ]
      ingress:
        enabled: true
        ingressClassName: nginx
        hosts: [ "grafana.${BASE_DOMAIN_INGRESS}" ]
        #tls: [ { hosts: [ "grafana.${BASE_DOMAIN_INGRESS}" ], secretName: "grafana-ingress-tls" } ]
    prometheus:
      ingress:
        enabled: true
        ingressClassName: nginx
        hosts: [ "prom.${BASE_DOMAIN_INGRESS}" ]
        #tls: [ { hosts: [ "prom.${BASE_DOMAIN_INGRESS}" ], secretName: "prom-ingress-tls" } ]
      prometheusSpec:
        ruleNamespaceSelector: { }
        serviceMonitorSelectorNilUsesHelmValues: false # work with non-helm ServiceMonitors
        serviceMonitorSelector: { }
        serviceMonitorNamespaceSelector: { }
        podMonitorSelector: { }
        podMonitorNamespaceSelector: { }
        retention: "7d"
        storageSpec:
          volumeClaimTemplate:
            spec:
              accessModes: [ "ReadWriteOnce" ]
              resources:
                requests:
                  storage: "16Gi"

K3S_MANIFEST_PROM_STACK

# Cilium, with Hubble
k3s_cmdline_opts+=("--disable-network-policy" "--flannel-backend=none") # Disable k3s's own CNI and policy stuff
cat << K3S_MANIFEST_CILIUM | envsubst > /var/lib/rancher/k3s/server/manifests/cilium.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  namespace: kube-system
  name: cilium
spec:
  bootstrap: true # don't wait for CNI
  targetNamespace: cilium
  createNamespace: true
  version: 1.14.9 # or: 1.15.3
  chart: cilium
  repo: https://helm.cilium.io/
  valuesContent: |-
    # specify k8s api server address
    k8sServiceHost: ${net_ipv4_addr}
    k8sServicePort: 6443
    # replace kube-proxy with strict mode
    kubeProxyReplacement: strict
    hubble:
      relay:
        enabled: true
      ui:
        enabled: true
        ingress:
          enabled: true
          #annotations: {}
          className: "nginx"
          hosts: [ "hubble.${BASE_DOMAIN_INGRESS}" ]
          #tls: [ { hosts: [ "hubble.${BASE_DOMAIN_INGRESS}" ], secretName: "hubble-ingress-tls" } ]
      enabled: true
      metrics:
        enabled: [ dns:query, drop, tcp, flow, icmp, http, port-distribution ]
        serviceMonitor:
          enabled: true
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true
      metrics: [ "+endpoint", "+services", "+datapath", "+ebpf" ]
    operator:
      replicas: 1
      prometheus:
        enabled: true
        serviceMonitor:
          enabled: true

K3S_MANIFEST_CILIUM

# Disable traefik, we're gonna use ingress-nginx # @TODO: k3s's svclb wastes the original client IP. metalLB, or run the ingress in hostNetwork?
k3s_cmdline_opts+=("--disable=traefik")
cat << 'K3S_MANIFEST_NGINX' | envsubst > /var/lib/rancher/k3s/server/manifests/ingress-nginx.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  namespace: kube-system
  name: ingress-nginx
spec:
  targetNamespace: ingress-nginx
  createNamespace: true
  version: 4.9.1
  chart: ingress-nginx
  repo: https://kubernetes.github.io/ingress-nginx
  valuesContent: |-
    controller:
      extraVolumeMounts: [ { name: geoip2-data, mountPath: "/etc/nginx/geoip" } ]
      extraVolumes: [ { name: geoip2-data, emptyDir: { } } ]
      extraInitContainers:
        - name: init-geoip
          image: ghcr.io/rpardini/maxmind-geoip:latest
          command: [ 'sh', '-c', 'ls -la /etc/nginx/geoip/; ls -la /geoip; time cp -v /geoip/* /etc/nginx/geoip/; ls -la /etc/nginx/geoip/' ]
          volumeMounts: [ { name: geoip2-data, mountPath: /etc/nginx/geoip } ]
      kind: Deployment
      replicaCount: 1
      addHeaders:
        X-client-geoip2-org: $geoip2_org
      proxySetHeaders:
        X-Request-Start: t=${msec}
        X-Original-Authorization: "$http_authorization"
        X-geoip2-city-country-code: $geoip2_city_country_code
        X-geoip2-city-country-name: $geoip2_city_country_name
        X-geoip2-city: $geoip2_city
        X-geoip2-postal-code: $geoip2_postal_code
        X-geoip2-dma-code: $geoip2_dma_code
        X-geoip2-latitude: $geoip2_latitude
        X-geoip2-longitude: $geoip2_longitude
        X-geoip2-time-zone: $geoip2_time_zone
        X-geoip2-region-code: $geoip2_region_code
        X-geoip2-region-name: $geoip2_region_name
        X-geoip2-subregion-code: $geoip2_subregion_code
        X-geoip2-subregion-name: $geoip2_subregion_name
        X-geoip2-asn: $geoip2_asn
        X-geoip2-org: $geoip2_org
        X-geoip-area-code: $geoip_area_code
        X-geoip-city-continent-code: $geoip_city_continent_code
        X-geoip-city-country-code: $geoip_city_country_code
        X-geoip-city-country-code3: $geoip_city_country_code3
        X-geoip-city-country-name: $geoip_city_country_name
        X-geoip-dma-code: $geoip_dma_code
        X-geoip-latitude: $geoip_latitude
        X-geoip-longitude: $geoip_longitude
        X-geoip-region: $geoip_region
        X-geoip-region-name: $geoip_region_name
        X-geoip-city: $geoip_city
        X-geoip-postal-code: $geoip_postal_code
      config:
        proxy-read-timeout: "7200" # https://kubernetes.github.io/ingress-nginx/user-guide/miscellaneous/#websockets
        proxy-send-timeout: "7200"
        use-geoip: "false" # we only have geoip2 mmdb databases, not old format .dat needed for v1
        use-geoip2: "true"
        enable-brotli: "true"
        gzip-level: "5"
        use-gzip: "true"
        ssl-protocols: "TLSv1.2 TLSv1.3"
      metrics:
        port: 10254
        enabled: true
        serviceMonitor:
          enabled: true
        prometheusRule:
          enabled: true
          additionalLabels: { }
          rules:
            # These are just examples rules, please adapt them to your needs
            - alert: NGINXConfigFailed
              expr: count(nginx_ingress_controller_config_last_reload_successful == 0) > 0
              for: 1s
              labels:
                severity: critical
              annotations:
                description: bad ingress config - nginx config test failed
                summary: uninstall the latest ingress changes to allow config reloads to resume
            - alert: NGINXCertificateExpiry
              expr: (avg(nginx_ingress_controller_ssl_expire_time_seconds) by (host) - time()) < 604800
              for: 1s
              labels:
                severity: critical
              annotations:
                description: ssl certificate(s) will expire in less then a week
                summary: renew expiring certificates to avoid downtime
            - alert: NGINXTooMany500s
              expr: 100 * ( sum( nginx_ingress_controller_requests{status=~"5.+"} ) / sum(nginx_ingress_controller_requests) ) > 5
              for: 1m
              labels:
                severity: warning
              annotations:
                description: Too many 5XXs
                summary: More than 5% of all requests returned 5XX, this requires your attention
            - alert: NGINXTooMany400s
              expr: 100 * ( sum( nginx_ingress_controller_requests{status=~"4.+"} ) / sum(nginx_ingress_controller_requests) ) > 5
              for: 1m
              labels:
                severity: warning
              annotations:
                description: Too many 4XXs
                summary: More than 5% of all requests returned 4XX, this requires your attention

K3S_MANIFEST_NGINX

# An echo server to ensure ingress/lb sanity
cat << K3S_MANIFEST_ECHO_SERVER | envsubst > /var/lib/rancher/k3s/server/manifests/echo-server.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: http-echo
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo-ingress-https
  namespace: http-echo
  annotations:
    # allow non-https traffic, for testing
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
spec:
  ingressClassName: nginx
  #tls: [ { hosts: [ "echo.${BASE_DOMAIN_INGRESS}" ], secretName: "echo-ingress-tls" } ]
  rules:
    - host: "echo.${BASE_DOMAIN_INGRESS}"
      http: { paths: [ { path: "/", pathType: Prefix, backend: { service: { name: http-echo, port: { number: 8080 } } } } ] }
---
apiVersion: v1
kind: Service
metadata:
  name: http-echo
  namespace: http-echo
spec:
  ports:
    - port: 8080
      targetPort: 8080
      name: http
      protocol: TCP
  selector:
    app: http-echo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-echo
  namespace: http-echo
spec:
  selector:
    matchLabels:
      app: http-echo
  replicas: 1
  template:
    metadata:
      labels:
        app: http-echo
    spec:
      containers:
        - name: http-echo
          image: ghcr.io/rpardini/http-echo:latest
          ports:
            - containerPort: 8080
              name: http
              protocol: TCP
          env:
            - name: "HTTP_PORT"
              value: "8080"
          resources:
            limits:
              memory: 32Mi
              cpu: 50m

K3S_MANIFEST_ECHO_SERVER

# eBPF instrumentation goodness (and to prove kernel is modern enough)
cat << K3S_MANIFEST_TETRAGON | envsubst > /var/lib/rancher/k3s/server/manifests/tetragon.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  namespace: kube-system
  name: tetragon
spec:
  targetNamespace: tetragon
  createNamespace: true
  version: "1.0.2" # https://artifacthub.io/packages/helm/cilium/tetragon
  chart: tetragon
  repo: https://helm.cilium.io/

K3S_MANIFEST_TETRAGON

# Install k3s using the standalone script
echo "Installing k3s '${k3s_cmdline_opts[*]}'" >&2
curl -sfL https://get.k3s.io | K3S_TOKEN=SECRET sh -s - "${k3s_cmdline_opts[@]}"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# shellcheck disable=SC2002 # my cat is most definitely not useless, mr. linter. also, don't you love sed'ing yaml?
cat "${KUBECONFIG}" | sed -e "s/: default/: k3s-${K3S_CLUSTER_NAME}/g" | sed -e "s/127\.0\.0\.1/${net_ipv4_addr}/g" > "/etc/rancher/k3s/k3s.${K3S_CLUSTER_NAME}.kubeconfig.yaml"
chmod ugo+r "/etc/rancher/k3s/k3s.${K3S_CLUSTER_NAME}.kubeconfig.yaml"

# Install cilium CLI directly from github releases
if [[ ! -f /usr/local/bin/cilium ]]; then
	declare CILIUM_CLI_VERSION
	CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
	echo "Installing cilium CLI version ${CILIUM_CLI_VERSION}" >&2
	curl -L --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz"
	tar -C /usr/local/bin -xzf cilium-linux-amd64.tar.gz
	rm -f cilium-linux-amd64.tar.gz
fi

# Install bat from
if [[ ! -f /usr/local/bin/bat ]]; then
	declare BAT_VERSION="0.24.0"
	declare BAT_BASE_FN="bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu"
	declare BAT_FN="${BAT_BASE_FN}.tar.gz"
	echo "Installing bat ${BAT_VERSION}" >&2
	curl -L --remote-name-all "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${BAT_FN}"
	tar xzf "${BAT_FN}"
	cp -v "${BAT_BASE_FN}/bat" /usr/local/bin/
	rm -rf "${BAT_BASE_FN}" "${BAT_FN}"
fi

# Install helm from the official script
if [[ ! -f /usr/local/bin/helm ]]; then
	echo "Installing helm" >&2
	curl -L https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Deploy autocompletion for k3s via /etc/profile.d/k3s.sh
cat <<- K3S_PROFILE > /etc/profile.d/k3s.sh
	export PATH="/usr/local/bin:\${PATH}"
	export KUBECONFIG="/etc/rancher/k3s/k3s.${K3S_CLUSTER_NAME}.kubeconfig.yaml"
	source <(kubectl completion bash)
	source <(k3s completion bash)
	source <(k9s completion bash)
	source <(helm completion bash)
	source <(cilium completion bash)
K3S_PROFILE

echo "Waiting for cilium to be ready" >&2
cilium status --namespace cilium --wait
cilium status --namespace cilium

echo "" >&2
echo "Cilium is ready. You can now use k9s, kubectl, and cilium CLI" >&2
echo "Go open a new shell to get KUBECONFIG & autocompletion goodness" >&2
bat --paging=never "/etc/rancher/k3s/k3s.${K3S_CLUSTER_NAME}.kubeconfig.yaml"

# Copy kubeconfig to iterm2's clipboard if it's installed
if [[ -f "${HOME}/.iterm2/it2copy" ]]; then
	# shellcheck disable=SC2002 # my cat has pedagogical future-piping properties, mr. linter
	cat "/etc/rancher/k3s/k3s.${K3S_CLUSTER_NAME}.kubeconfig.yaml" | "${HOME}/.iterm2/it2copy"
	echo -n "Kubeconfig copied to iterm2's clipboard" >&2
	"${HOME}/.iterm2/it2attention" fireworks
	echo ""
fi
