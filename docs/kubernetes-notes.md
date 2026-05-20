# Kubernetes Engineering Notes

## Deployment

A Deployment ensures application replicas are running consistently inside the Kubernetes cluster.

Key benefits:
- self-healing
- scaling
- rolling updates
- replica management

---

## Service

A Service exposes pods internally or externally.

Types:
- ClusterIP
- NodePort
- LoadBalancer

Current implementation uses:
- LoadBalancer

---

## Observability Goals

This project focuses on:
- monitoring
- alerting
- infrastructure visibility
- operational reliability

---

## Monitoring Stack

### Prometheus
Used for metrics collection.

### Grafana
Used for visualization dashboards.

### Alertmanager
Used for alert routing and notifications.

---

## Learning Notes

Important Kubernetes concepts explored:
- pods
- deployments
- services
- observability
- monitoring
- YAML manifests
