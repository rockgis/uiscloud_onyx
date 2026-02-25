<a name="readme-top"></a>

<h2 align="center">
    <a href="https://www.onyx.app/?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme"> <img width="50%" src="https://github.com/onyx-dot-app/onyx/blob/logo/OnyxLogoCropped.jpg?raw=true" /></a>
</h2>

<p align="center">오픈소스 AI 플랫폼</p>

<p align="center">
    <a href="https://discord.gg/TDJ59cGV2X" target="_blank">
        <img src="https://img.shields.io/badge/discord-참여-blue.svg?logo=discord&logoColor=white" alt="Discord" />
    </a>
    <a href="https://docs.onyx.app/?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme" target="_blank">
        <img src="https://img.shields.io/badge/문서-보기-blue" alt="Documentation" />
    </a>
    <a href="https://www.onyx.app/?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme" target="_blank">
        <img src="https://img.shields.io/website?url=https://www.onyx.app&up_message=방문&up_color=blue" alt="Website" />
    </a>
    <a href="https://github.com/onyx-dot-app/onyx/blob/main/LICENSE" target="_blank">
        <img src="https://img.shields.io/static/v1?label=라이선스&message=MIT&color=blue" alt="License" />
    </a>
</p>

<p align="center">
  <a href="https://trendshift.io/repositories/12516" target="_blank">
    <img src="https://trendshift.io/api/badge/repositories/12516" alt="onyx-dot-app/onyx | Trendshift" style="width: 250px; height: 55px;" />
  </a>
</p>

---

> 📖 **다른 언어로 읽기:** [English](README.md)

---

**[Onyx](https://www.onyx.app/?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme)**는 모든 LLM에서 동작하는 기능이 풍부한 자가 호스팅 Chat UI입니다. 배포가 쉽고 완전한 에어갭(air-gapped) 환경에서도 실행할 수 있습니다.

Onyx에는 에이전트, 웹 검색, RAG, MCP, 딥 리서치, 40개 이상의 지식 소스 커넥터 등 고급 기능이 탑재되어 있습니다.

> [!TIP]
> 단 하나의 명령으로 Onyx를 실행하세요 (또는 아래 배포 섹션 참고):
> ```
> curl -fsSL https://raw.githubusercontent.com/onyx-dot-app/onyx/main/deployment/docker_compose/install.sh > install.sh && chmod +x install.sh && ./install.sh
> ```

****

![Onyx Chat 데모](https://github.com/onyx-dot-app/onyx/releases/download/v0.21.1/OnyxChatSilentDemo.gif)



## ⭐ 주요 기능

- **🤖 커스텀 에이전트:** 고유한 지시사항, 지식, 작업을 갖춘 AI 에이전트를 구축하세요.
- **🌍 웹 검색:** Google PSE, Exa, Serper는 물론 자체 스크래퍼 또는 Firecrawl로 웹을 탐색하세요.
- **🔍 RAG:** 업로드된 파일과 커넥터에서 수집한 문서에 대한 최고 수준의 하이브리드 검색 + 지식 그래프.
- **🔄 커넥터:** 40개 이상의 애플리케이션에서 지식, 메타데이터, 접근 정보를 가져오세요.
- **🔬 딥 리서치:** 에이전틱 다단계 검색으로 심층적인 답변을 얻으세요.
- **▶️ Actions & MCP:** AI 에이전트가 외부 시스템과 상호작용할 수 있는 능력을 부여하세요.
- **💻 코드 인터프리터:** 코드를 실행하여 데이터를 분석하고, 그래프를 렌더링하고, 파일을 생성하세요.
- **🎨 이미지 생성:** 사용자 프롬프트를 기반으로 이미지를 생성하세요.
- **👥 협업:** 채팅 공유, 피드백 수집, 사용자 관리, 사용 분석 등.

Onyx는 모든 LLM(OpenAI, Anthropic, Gemini 등)과 자체 호스팅 LLM(Ollama, vLLM 등)에서 동작합니다.

기능에 대해 더 알아보려면 [공식 문서](https://docs.onyx.app/welcome?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme)를 확인하세요!



## 🚀 배포

Onyx는 Docker, Kubernetes, Terraform 배포를 지원하며, 주요 클라우드 제공자를 위한 가이드도 제공합니다.

아래 가이드를 참고하세요:
- [Docker](https://docs.onyx.app/deployment/local/docker?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme) 또는 [빠른 시작](https://docs.onyx.app/deployment/getting_started/quickstart?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme) (대부분의 사용자에게 최적)
- [Kubernetes](https://docs.onyx.app/deployment/local/kubernetes?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme) (대규모 팀에 최적)
- [Terraform](https://docs.onyx.app/deployment/local/terraform?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme) (이미 Terraform을 사용하는 팀에 최적)
- 클라우드별 가이드 ([AWS EKS](https://docs.onyx.app/deployment/cloud/aws/eks?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme), [Azure VMs](https://docs.onyx.app/deployment/cloud/azure?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme) 등)

> [!TIP]
> **배포 없이 Onyx를 무료로 사용해보려면 [Onyx Cloud](https://cloud.onyx.app/signup?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme)를 확인하세요.**

한국어 배포 가이드:
- [Docker Compose 배포](docs/ko/deployment/docker_compose.md)
- [Kubernetes (Helm) 배포](docs/ko/deployment/helm.md)
- [AWS Terraform 배포](docs/ko/deployment/terraform_aws.md)



## 🔍 주요 장점

Onyx는 개인 사용자부터 대규모 글로벌 기업까지 모든 규모의 팀을 위해 구축되었습니다.

- **엔터프라이즈 검색**: 단순한 RAG를 넘어, 수천만 건의 문서 규모에서도 성능과 정확도를 유지하는 커스텀 인덱싱 및 검색 기능.
- **보안**: SSO (OIDC/SAML/OAuth2), RBAC, 자격증명 암호화 등.
- **관리 UI**: 기본, 큐레이터, 관리자 등 다양한 사용자 역할.
- **문서 권한 관리**: RAG 사용 사례를 위해 외부 앱의 사용자 접근 권한을 미러링.



## 🚧 로드맵

진행 중이거나 예정된 프로젝트를 보려면 [로드맵](https://github.com/orgs/onyx-dot-app/projects/2)을 확인하세요!



## 📚 라이선스

Onyx는 두 가지 에디션으로 제공됩니다:

- **Onyx Community Edition (CE)**: MIT 라이선스로 자유롭게 사용 가능.
- **Onyx Enterprise Edition (EE)**: 주로 대형 조직에 유용한 추가 기능 포함.

기능 세부 사항은 [공식 웹사이트](https://www.onyx.app/pricing?utm_source=onyx_repo&utm_medium=github&utm_campaign=readme)를 확인하세요.



## 👪 커뮤니티

**[Discord](https://discord.gg/TDJ59cGV2X)**에서 오픈소스 커뮤니티에 참여하세요!



## 💡 기여하기

기여를 원하신다면 [기여 가이드](CONTRIBUTING.md) 또는 [한국어 기여 가이드](docs/ko/CONTRIBUTING.md)를 확인하세요.



## 📖 한국어 문서

| 문서 | 설명 |
|------|------|
| [프로젝트 종합 가이드](docs/ONYX_KO.md) | Onyx 전체 개요 (한국어) |
| [전체 문서 목차](docs/ko/README.md) | 모든 한국어 문서 목록 |
| [개발 환경 설정](docs/ko/contributing/dev_setup.md) | 로컬 개발 환경 구성 |
| [코드 품질 표준](docs/ko/contributing/best_practices.md) | 엔지니어링 원칙 및 스타일 가이드 |
| [웹 코딩 표준](docs/ko/web/STANDARDS.md) | TypeScript/React 코딩 규칙 |
| [배포 가이드 (Docker)](docs/ko/deployment/docker_compose.md) | Docker Compose 배포 |
| [백그라운드 워커](docs/ko/backend/background_workers.md) | Celery 작업 시스템 |
| [커넥터 개발](docs/ko/backend/connectors.md) | 새로운 커넥터 작성 방법 |
