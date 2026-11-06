const String kBuiltinVlessConfig = '''
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: true
find-process-mode: off

dns:
  enable: true
  ipv6: false
  enhanced-mode: normal
  nameserver:
    - 223.5.5.5
    - 119.29.29.29

proxies:
  - name: "Geto-Reality-61494"
    type: vless
    server: 64.83.14.86
    port: 61494
    uuid: efc6fdd0-8f7f-48f1-b5c5-88034df99aac
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: www.samsung.com
    client-fingerprint: chrome
    reality-opts:
      public-key: SU7pSsRZGubzrFFmEFwFAeWfQfirjwJnaN5JXPrl_Us
      short-id: 56281cd5

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - "Geto-Reality-61494"

rules:
  - MATCH,PROXY
''';
