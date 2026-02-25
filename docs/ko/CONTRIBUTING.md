# Onyx 기여 가이드

Onyx에 관심을 가져주셔서 정말 기쁩니다!

---

## 기여 기회

[GitHub Issues](https://github.com/onyx-dot-app/onyx/issues) 페이지는 기여 아이디어를 찾고 공유하기에 좋은 곳입니다.

직접 만들고 싶은 기능이 있다면 이슈를 생성하고, 커뮤니티 멤버들이 공통적인 필요성을 느낀다면 추천(thumbs up)을 눌러줄 것입니다.

---

## 코드 기여 방법

코드베이스를 높은 수준으로 유지하기 위해 `contributing_guides` 폴더의 문서를 참고하세요.

1. **[개발 환경 설정](contributing/dev_setup.md)** (여기서 시작): 로컬 개발 환경 설정 가이드
2. **[기여 프로세스](contributing/contribution_process.md)**: 검토 및 병합될 가치 있는 기능을 만드는 방법
3. **[코드 품질 표준](contributing/best_practices.md)**: 리뷰를 요청하기 전에 코드가 저장소의 품질 기준을 충족하는지 확인

기여하려면 ["포크 및 풀 리퀘스트"](https://docs.github.com/en/get-started/quickstart/contributing-to-projects) 워크플로를 따르세요.

---

## 도움 받기

[Discord](https://discord.gg/4NA5SbzrWb)에서 지원 채널과 흥미로운 토론에 참여할 수 있습니다.

---

## 릴리스 프로세스

Onyx는 SemVer 버전 표준을 대략적으로 따릅니다.

- **주요 변경**: "마이너" 버전 업(예: `0.21` → `0.22`)
- **소규모 기능 변경**: 패치 릴리스 버전 사용
- 모든 태그마다 Docker 컨테이너가 DockerHub에 자동으로 푸시됩니다.
- 컨테이너는 [여기](https://hub.docker.com/search?q=onyx%2F)에서 확인할 수 있습니다.
