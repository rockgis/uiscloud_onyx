# AWS Terraform 모듈 가이드

---

## 개요

이 디렉토리는 Onyx를 위한 핵심 AWS 인프라를 프로비저닝하는 Terraform 모듈을 포함합니다:

| 모듈 | 설명 |
|------|------|
| `vpc` | EKS용 공용/사설 서브넷을 포함한 VPC 생성 |
| `eks` | Amazon EKS 클러스터, 필수 애드온(EBS CSI, 메트릭 서버, 클러스터 자동 스케일러), S3 접근을 위한 IRSA(선택) 프로비저닝 |
| `postgres` | Amazon RDS for PostgreSQL 인스턴스 생성 및 연결 URL 반환 |
| `redis` | ElastiCache for Redis 복제 그룹 생성 |
| `s3` | S3 버킷 생성 및 제공된 S3 VPC 엔드포인트로 접근 제한 |
| `onyx` | 위 모듈들을 조합하는 상위 레벨 합성 모듈 |

완전한 EKS + PostgreSQL + Redis + S3 스택을 원한다면 `onyx` 모듈을 사용하세요. 세분화된 제어가 필요하면 개별 모듈을 사용하세요.

---

## 빠른 시작

최소 작동 예시:

```hcl
locals {
  region = "us-west-2"
}

provider "aws" {
  region = local.region
}

module "onyx" {
  source = "./modules/aws/onyx"

  region            = local.region
  name              = "onyx"            # 프리픽스 및 워크스페이스 인식
  postgres_username = "pgusername"
  postgres_password = "your-postgres-password"
  # create_vpc    = true  # 기본값 true; 기존 VPC 사용 시 false로 설정
}

resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "aws eks wait cluster-active --name ${module.onyx.cluster_name} --region ${local.region}"
  }
}

data "aws_eks_cluster" "eks" {
  name       = module.onyx.cluster_name
  depends_on = [null_resource.wait_for_cluster]
}

data "aws_eks_cluster_auth" "eks" {
  name       = module.onyx.cluster_name
  depends_on = [null_resource.wait_for_cluster]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

# 선택: 루트 모듈 레벨에서 편리한 출력 노출
output "cluster_name" {
  value = module.onyx.cluster_name
}
output "postgres_connection_url" {
  value     = module.onyx.postgres_connection_url
  sensitive = true
}
output "redis_connection_url" {
  value     = module.onyx.redis_connection_url
  sensitive = true
}
```

적용:

```bash
terraform init
terraform apply
```

---

## 기존 VPC 사용

기존 VPC와 서브넷이 있는 경우:

```hcl
module "onyx" {
  source = "./modules/aws/onyx"

  region            = local.region
  name              = "onyx"
  postgres_username = "pgusername"
  postgres_password = "your-postgres-password"

  create_vpc         = false
  vpc_id             = "vpc-xxxxxxxx"
  private_subnets    = ["subnet-aaaa", "subnet-bbbb", "subnet-cccc"]
  public_subnets     = ["subnet-dddd", "subnet-eeee", "subnet-ffff"]
  vpc_cidr_block     = "10.0.0.0/16"
  s3_vpc_endpoint_id = "vpce-xxxxxxxxxxxxxxxxx"
}
```

---

## 각 모듈 설명

### `onyx` 모듈

- `vpc`, `eks`, `postgres`, `redis`, `s3`를 오케스트레이션
- `name`과 현재 Terraform 워크스페이스를 사용하여 리소스 이름 지정
- 편리한 출력 노출:
  - `cluster_name`: EKS 클러스터 이름
  - `postgres_connection_url` (민감): `postgres://...`
  - `redis_connection_url` (민감): hostname:port

**주요 입력:**
- `name` (기본값 `onyx`), `region` (기본값 `us-west-2`), `tags`
- `postgres_username`, `postgres_password`
- `create_vpc` (기본값 true) 또는 기존 VPC 세부 정보 및 `s3_vpc_endpoint_id`

### `vpc` 모듈

- 여러 사설 및 공용 서브넷을 포함한 EKS용 VPC 구축
- **출력**: `vpc_id`, `private_subnets`, `public_subnets`, `vpc_cidr_block`, `s3_vpc_endpoint_id`

### `eks` 모듈

- EKS 클러스터 및 노드 그룹 생성
- 애드온 활성화: EBS CSI 드라이버, 메트릭 서버, 클러스터 자동 스케일러
- 선택적으로 S3 접근을 위한 IRSA 설정
- **주요 입력**: `cluster_name`, `cluster_version` (기본값 `1.33`), `vpc_id`, `subnet_ids`

### `postgres` 모듈

- 인스턴스 크기, 스토리지, 버전이 매개변수화된 Amazon RDS for PostgreSQL
- VPC/서브넷과 인그레스 CIDR을 받아 준비된 연결 URL 반환

### `redis` 모듈

- ElastiCache for Redis (기본적으로 전송 암호화 활성화)
- 선택적 `auth_token` 및 인스턴스 크기 지원
- 엔드포인트, 포트, SSL 활성화 여부 출력

### `s3` 모듈

- 파일 스토리지용 S3 버킷 생성 및 제공된 S3 게이트웨이 VPC 엔드포인트로 접근 제한

---

## Terraform 이후 Onyx Helm 차트 설치

클러스터가 활성화되면 Helm으로 애플리케이션 워크로드를 배포하세요:

```bash
# 새 클러스터에 맞게 kubeconfig 설정
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region ${AWS_REGION:-us-west-2}

kubectl create namespace onyx --dry-run=client -o yaml | kubectl apply -f -

# EKS 모듈이 생성한 IRSA를 통해 AWS S3를 사용하는 경우 MinIO 비활성화 고려
helm upgrade --install onyx /path/to/onyx/deployment/helm/charts/onyx \
  --namespace onyx \
  --set minio.enabled=false \
  --set serviceAccount.create=false \
  --set serviceAccount.name=onyx-s3-access
```

**참고:**
- EKS 모듈은 `s3_bucket_names`가 제공되면 IRSA 역할과 `onyx-s3-access` Kubernetes `ServiceAccount`(기본적으로 `onyx` 네임스페이스)를 생성할 수 있습니다. 정적 S3 자격증명을 피하기 위해 Helm 차트에서 해당 서비스 계정을 사용하세요.
- 클러스터 내에 MinIO를 선호한다면 `minio.enabled=true`(기본값)를 유지하고 IRSA를 건너뛰세요.

---

## 워크플로 팁

- 첫 번째 적용은 인프라만 가능합니다. EKS가 활성화되면 Helm 차트를 설치하세요.
- Terraform 워크스페이스를 사용하여 격리된 환경을 만드세요. `onyx` 모듈은 자동으로 워크스페이스를 리소스 이름에 포함합니다.

---

## 보안

- 데이터베이스 및 Redis 연결 출력은 민감으로 표시됩니다. 신중하게 처리하세요.
- IRSA를 사용하는 경우, 시크릿에 수명이 긴 S3 자격증명을 저장하지 마세요.
