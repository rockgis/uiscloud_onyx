# macOS 사용자를 위한 추가 설정

기본 개발 환경 설정 지침은 [개발 환경 설정](dev_setup.md)을 참고하세요.

---

## Python 설정

[Homebrew](https://brew.sh/)가 이미 설치되어 있어야 합니다.

Python 3.11 설치:

```bash
brew install python@3.11
```

PATH에 Python 3.11 추가 — `~/.zshrc`에 다음 줄을 추가하세요:

```bash
export PATH="$(brew --prefix)/opt/python@3.11/libexec/bin:$PATH"
```

> **참고:** 위의 경로 변경이 적용되려면 새 터미널을 열어야 합니다.

---

## Docker 설정

macOS에서는 [Docker Desktop](https://www.docker.com/products/docker-desktop/)을 설치하고, Docker 명령을 실행하기 전에 반드시 실행 중인지 확인하세요.

---

## 포매팅 및 린팅

macOS에서는 일부 훅을 올바르게 실행하기 위해 격리(quarantine) 속성을 제거해야 할 수 있습니다. pre-commit 설치 후 다음 명령을 실행하세요:

```bash
sudo xattr -r -d com.apple.quarantine ~/.cache/pre-commit
```
