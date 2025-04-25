#!/bin/bash
set -e

NS="netbox"

echo "Creating namespace..."
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

echo "Creating PostgreSQL deployment and service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: $NS
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: $NS
data:
  POSTGRES_DB: netbox
  POSTGRES_USER: netbox
  POSTGRES_PASSWORD: netbox
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: $NS
spec:
  selector:
    matchLabels:
      app: postgres
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          valueFrom:
            configMapKeyRef:
              name: postgres-config
              key: POSTGRES_DB
        - name: POSTGRES_USER
          valueFrom:
            configMapKeyRef:
              name: postgres-config
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: postgres-config
              key: POSTGRES_PASSWORD
        resources:
          limits:
            memory: 256Mi
          requests:
            memory: 128Mi
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: postgres-data
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: $NS
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
EOF

echo "Creating Redis deployment and service..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: $NS
spec:
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:6
        ports:
        - containerPort: 6379
        resources:
          limits:
            memory: 128Mi
          requests:
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $NS
spec:
  selector:
    app: redis
  ports:
  - port: 6379
EOF

echo "Waiting for Redis and PostgreSQL to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/postgres -n $NS
kubectl wait --for=condition=available --timeout=120s deployment/redis -n $NS

echo "Creating NetBox deployment and service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: netbox-media
  namespace: $NS
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: netbox-config
  namespace: $NS
data:
  POSTGRES_DB: netbox
  POSTGRES_USER: netbox
  POSTGRES_PASSWORD: netbox
  POSTGRES_HOST: postgres
  REDIS_HOST: redis
  SKIP_SUPERUSER: "false"
  SUPERUSER_NAME: admin
  SUPERUSER_EMAIL: admin@example.com
  SUPERUSER_PASSWORD: admin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netbox
  namespace: $NS
spec:
  selector:
    matchLabels:
      app: netbox
  template:
    metadata:
      labels:
        app: netbox
    spec:
      containers:
      - name: netbox
        image: netboxcommunity/netbox:v4.2.6
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: 512Mi
          requests:
            memory: 256Mi
        envFrom:
        - configMapRef:
            name: netbox-config
        volumeMounts:
        - name: netbox-media
          mountPath: /opt/netbox/netbox/media
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 120
          periodSeconds: 20
      volumes:
      - name: netbox-media
        persistentVolumeClaim:
          claimName: netbox-media
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netbox-worker
  namespace: $NS
spec:
  selector:
    matchLabels:
      app: netbox-worker
  template:
    metadata:
      labels:
        app: netbox-worker
    spec:
      containers:
      - name: netbox-worker
        image: netboxcommunity/netbox:v4.2.6
        command: ["/opt/netbox/launch-netbox-worker.sh"]
        resources:
          limits:
            memory: 256Mi
          requests:
            memory: 128Mi
        envFrom:
        - configMapRef:
            name: netbox-config
        volumeMounts:
        - name: netbox-media
          mountPath: /opt/netbox/netbox/media
      volumes:
      - name: netbox-media
        persistentVolumeClaim:
          claimName: netbox-media
---
apiVersion: v1
kind: Service
metadata:
  name: netbox
  namespace: $NS
spec:
  selector:
    app: netbox
  ports:
  - port: 80
    targetPort: 8080
EOF

echo "NetBox deployment complete!"
echo "To access NetBox, run: kubectl port-forward svc/netbox 8000:80 -n $NS"
echo "Then open http://localhost:8000 in your browser"
echo "Default credentials: admin / admin"