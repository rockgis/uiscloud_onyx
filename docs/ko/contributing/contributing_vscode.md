# VSCode 디버깅 설정

이 가이드는 이 프로젝트에서 VSCode의 디버깅 기능을 설정하고 사용하는 방법을 설명합니다.

---

## 초기 설정

1. **환경 설정**:
   - `.vscode/env_template.txt`를 `.vscode/.env`로 복사합니다.
   - `.vscode/.env`에 필요한 환경 변수를 입력합니다.

---

## 디버거 사용 방법

시작하기 전에 Docker Daemon이 실행 중인지 확인하세요.

1. VSCode에서 디버그 뷰를 엽니다 (macOS: `Cmd+Shift+D`)
2. 상단 드롭다운에서 **"Clear and Restart External Volumes and Containers"** 를 선택하고 초록색 실행 버튼을 누릅니다.
3. 상단 드롭다운에서 **"Run All Onyx Services"** 를 선택하고 초록색 실행 버튼을 누릅니다.
4. 브라우저에서 `http://localhost:3000`으로 이동하여 앱을 사용할 수 있습니다.
5. 줄 번호 왼쪽을 클릭하여 브레이크포인트를 설정하고 앱 실행 중 디버깅할 수 있습니다.
6. 디버그 툴바를 사용하여 코드를 단계별로 실행하고, 변수를 검사하는 등의 작업을 할 수 있습니다.

> **주의:** "Clear and Restart External Volumes and Containers"는 PostgreSQL과 Vespa(relational-db와 index)를 초기화합니다. 데이터를 지워도 괜찮을 때만 실행하세요.

---

## 기능

- **웹 서버와 API 서버**에 대한 핫 리로드 지원
- **debugpy**로 Python 디버깅 설정
- `.vscode/.env`에서 환경 변수 로드
- 레이블이 있는 탭으로 통합 터미널에서 정리된 콘솔 출력
