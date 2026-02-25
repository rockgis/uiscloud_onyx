# Onyx 데스크탑 앱

[Onyx Cloud](https://cloud.onyx.app)를 위한 경량 macOS 데스크탑 애플리케이션입니다.

최소 번들 크기를 위해 [Tauri](https://tauri.app)로 구축되었습니다 (~10MB vs Electron의 150MB+).

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **경량** | 번들된 Chromium 없는 네이티브 macOS WebKit |
| **키보드 단축키** | 빠른 탐색 및 작업 |
| **네이티브 느낌** | 신호등 버튼이 있는 macOS 스타일 타이틀 바 |
| **창 상태 저장** | 세션 간 크기/위치 기억 |
| **다중 창** | 여러 Onyx 창 열기 |

---

## 키보드 단축키

| 단축키 | 작업 |
|--------|------|
| `⌘ N` | 새 채팅 |
| `⌘ ⇧ N` | 새 창 |
| `⌘ R` | 새로고침 |
| `⌘ [` | 뒤로 가기 |
| `⌘ ]` | 앞으로 가기 |
| `⌘ ,` | 설정 파일 열기 |
| `⌘ W` | 창 닫기 |
| `⌘ Q` | 종료 |

---

## 사전 요구사항

### 1. Rust (최신 안정 버전)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 2. Node.js (18+)

```bash
# Homebrew 사용
brew install node

# 또는 nvm 사용
nvm install 18
```

### 3. Xcode 커맨드 라인 도구

```bash
xcode-select --install
```

---

## 개발

```bash
# 의존성 설치
npm install

# 개발 모드로 실행
npm run dev
```

---

## 빌드

### 현재 아키텍처용 빌드

```bash
npm run build
```

### 유니버설 바이너리 빌드 (Intel + Apple Silicon)

```bash
# 먼저 타겟 추가
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-darwin

# 유니버설 바이너리 빌드
npm run build:dmg
```

빌드된 `.dmg`는 `src-tauri/target/release/bundle/dmg/`에 있습니다.

---

## 프로젝트 구조

```
onyx-desktop/
├── package.json          # Node 의존성 및 스크립트
├── src/
│   └── index.html        # 폴백/로딩 페이지
└── src-tauri/
    ├── Cargo.toml        # Rust 의존성
    ├── tauri.conf.json   # Tauri 설정
    ├── build.rs          # 빌드 스크립트
    ├── icons/            # 앱 아이콘
    └── src/
        └── main.rs       # Rust 백엔드 코드
```

---

## 아이콘

빌드 전에 `src-tauri/icons/`에 앱 아이콘을 추가하세요:

- `32x32.png`
- `128x128.png`
- `128x128@2x.png`
- `icon.icns` (macOS)
- `icon.ico` (Windows, 선택)

1024x1024 소스 이미지에서 생성하는 방법:

```bash
npm run tauri icon path/to/your-icon.png
```

---

## 커스터마이징

### 자체 호스팅 / 커스텀 서버 URL

앱은 기본적으로 `https://cloud.onyx.app`을 사용하지만 모든 Onyx 인스턴스를 지원합니다.

**설정 파일 위치:**
- macOS: `~/Library/Application Support/app.onyx.desktop/config.json`
- Linux: `~/.config/app.onyx.desktop/config.json`
- Windows: `%APPDATA%/app.onyx.desktop/config.json`

**자체 호스팅 인스턴스 사용 방법:**

1. 앱을 한 번 실행합니다 (기본 설정 파일 생성)
2. `⌘ ,`를 눌러 설정 파일을 열거나 수동으로 편집합니다
3. `server_url`을 변경합니다:

```json
{
  "server_url": "https://your-onyx-instance.company.com",
  "window_title": "Onyx"
}
```

4. 앱을 재시작합니다

**터미널에서 빠른 편집:**

```bash
# macOS
open -t ~/Library/Application\ Support/app.onyx.desktop/config.json
```

### 빌드 기본 URL 변경

`src-tauri/tauri.conf.json` 편집:

```json
{
  "app": {
    "windows": [
      {
        "url": "https://your-onyx-instance.com"
      }
    ]
  }
}
```

### 단축키 추가

`src-tauri/src/main.rs`의 `setup_shortcuts` 함수를 편집하세요.

---

## 문제 해결

### "호스트를 확인할 수 없음"

인터넷 연결이 있는지 확인하세요. 앱이 `cloud.onyx.app`에서 콘텐츠를 로드합니다.

### M1/M2 Mac에서 빌드 실패

```bash
# 올바른 타겟이 있는지 확인
rustup target add aarch64-apple-darwin
```

### 배포를 위한 코드 서명

App Store 외에서 배포하려면:

1. Apple Developer 인증서 취득
2. 앱 서명: `codesign --deep --force --sign "Developer ID" target/release/bundle/macos/Onyx.app`
3. Apple로 공증(Notarize)

---

## 라이선스

MIT
