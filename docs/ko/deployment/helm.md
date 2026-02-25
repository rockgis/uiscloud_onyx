# Kubernetes Helm 배포 가이드

---

## 의존성 업데이트 (서브차트 버전 변경 시)

```bash
cd charts/onyx
helm dependency update .
```

---

## 로컬 테스트

### 초기 설정 (1회)

```bash
brew install kind
# ~/.kube/config에 기존 설정이 없는지 확인
kind create cluster
mv ~/.kube/config ~/.kube/kind-config
```

### ct를 이용한 자동 설치 및 테스트

```bash
export KUBECONFIG=~/.kube/kind-config
kubectl config use-context kind-kind

# 소스 루트에서 실행. 웹 서버에 대한 기본 테스트 수행
ct install --all --helm-extra-set-args="--set=nginx.enabled=false" --debug --config ct.yaml
```

### 템플릿을 파일로 출력하고 검사

```bash
cd charts/onyx
helm template test-output . > test-output.yaml
```

### 전체 클러스터 수동 테스트

```bash
cd charts/onyx

# 설치
helm install onyx . -n onyx --set postgresql.primary.persistence.enabled=false
# postgresql 플래그는 테스트를 위해 스토리지를 임시로 유지합니다. 프로덕션에서는 설정하지 마세요.

# 로컬 포트 8080을 설치된 차트로 포워딩
kubectl -n onyx port-forward service/onyx-nginx 8080:80

# 완료 후 정리
helm uninstall onyx -n onyx
# Vespa는 PVC를 남깁니다. 완전히 종료하려면 삭제하세요:
k -n onyx get pvc
k -n onyx delete pvc vespa-storage-da-vespa-0
```

---

## 비루트 사용자로 실행

기본적으로 일부 Onyx 컨테이너는 루트로 실행됩니다. 비루트 사용자로 명시적으로 실행하려면 다음 컴포넌트의 `values.yaml`을 업데이트하세요:

**`celery_shared`, `api`, `webserver`, `indexCapability`, `inferenceCapability`:**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
```

**`vespa`:**

```yaml
podSecurityContext:
  fsGroup: 1000
securityContext:
  privileged: false
  runAsUser: 1000
```

---

## 리소스 설정

Helm 차트에는 모든 Onyx 소유 컴포넌트에 대한 리소스 제안이 있습니다. 이것은 초기 제안일 뿐이며 특정 사용 사례에 맞게 조정해야 할 수 있습니다.

질문이 있으면 Slack에서 문의하세요!

---

## 자동 스케일링 옵션

차트는 기본적으로 Kubernetes `HorizontalPodAutoscaler`를 렌더링합니다.

### HPA 사용 (기본값)

`autoscaling.engine`을 `hpa`로 유지하고 컴포넌트별 `autoscaling.*` 값을 조정하세요.

### KEDA 사용

1. 클러스터에 KEDA 오퍼레이터를 직접 설치하고 관리하세요 (공식 KEDA Helm 차트 사용 예). KEDA는 더 이상 Onyx 차트의 의존성으로 패키징되지 않습니다.
2. `values.yaml`에서 `autoscaling.engine: keda`를 설정하고 스케일링하려는 컴포넌트에 대해 자동 스케일링을 활성화하세요.

`autoscaling.engine`이 `keda`로 설정되면 차트가 기존 ScaledObject 템플릿을 렌더링합니다. 그렇지 않으면 HPA가 렌더링됩니다.

---

## Onyx Helm 차트 위치

```
deployment/helm/charts/onyx/
```

기본 설치:

```bash
helm install onyx ./deployment/helm/charts/onyx \
  --namespace onyx \
  --create-namespace
```
