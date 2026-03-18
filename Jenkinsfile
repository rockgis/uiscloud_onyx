// =============================================================================
// UISCloud Onyx — Jenkins 배포 파이프라인
//
// 파이프라인 흐름:
//   Checkout → 빌드 정보 설정 → Docker 이미지 빌드 → GHCR 푸시 → 서버 배포
//
// 트리거:
//   - main 브랜치 push (GitHub Webhook)
//   - v*.*.* 태그 push (Release)
//   - 수동 실행 (파라미터로 배포 대상 지정)
//
// 필요한 Jenkins Credentials:
//   - ghcr-credentials   : GitHub Container Registry (Username/Password)
//   - deploy-ssh-key     : 배포 서버 SSH 키 (SSH Username with private key)
// =============================================================================

pipeline {

    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 45, unit: 'MINUTES')
        skipDefaultCheckout(true)
        ansiColor('xterm')
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(
            name: 'DEPLOY_HOST',
            defaultValue: '',
            description: '배포 서버 IP 또는 호스트명 (비워두면 배포 단계 생략)'
        )
        string(
            name: 'DEPLOY_USER',
            defaultValue: 'ubuntu',
            description: '배포 서버 SSH 접속 사용자'
        )
        string(
            name: 'DEPLOY_PATH',
            defaultValue: '/opt/uiscloud-onyx',
            description: '배포 서버의 배포 디렉토리 경로'
        )
        booleanParam(
            name: 'SKIP_DEPLOY',
            defaultValue: false,
            description: '이미지 빌드/푸시만 실행하고 서버 배포 생략'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: '빠른 배포를 위해 테스트 단계 생략'
        )
    }

    environment {
        REGISTRY        = 'ghcr.io'
        IMAGE_REPO      = 'rockgis/uiscloud_onyx/web-server'
        IMAGE_FULL      = "${REGISTRY}/${IMAGE_REPO}"
        DOCKER_BUILDKIT = '1'
        WEB_CONTEXT     = 'web'
        WEB_DOCKERFILE  = 'web/Dockerfile'
    }

    stages {

        // ── 소스 체크아웃 ────────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%s',
                        returnStdout: true
                    ).trim()
                    env.GIT_BRANCH_CLEAN = env.BRANCH_NAME?.replaceAll('[^a-zA-Z0-9._-]', '-') ?: 'unknown'
                }
            }
        }

        // ── 빌드 정보 및 이미지 태그 결정 ───────────────────────────────────
        stage('Set Build Info') {
            steps {
                script {
                    def tags = []

                    if (env.TAG_NAME && (env.TAG_NAME ==~ /^v\d+\.\d+\.\d+.*/)) {
                        // ─ Release 태그 빌드: v1.2.3 → :v1.2.3, :1.2.3, :1.2, :1, :latest
                        def rawVer = env.TAG_NAME.replaceFirst(/^v/, '')   // "1.2.3"
                        def parts  = rawVer.split('\\.')

                        tags = [
                            "${IMAGE_FULL}:${env.TAG_NAME}",
                            "${IMAGE_FULL}:${rawVer}",
                            "${IMAGE_FULL}:${parts[0]}.${parts[1]}",
                            "${IMAGE_FULL}:${parts[0]}",
                            "${IMAGE_FULL}:latest",
                        ]
                        env.DEPLOY_IMAGE       = "${IMAGE_FULL}:${env.TAG_NAME}"
                        env.BUILD_TYPE         = 'release'

                    } else if (env.BRANCH_NAME == 'main') {
                        // ─ main 브랜치 빌드: :main, :sha-abc1234
                        tags = [
                            "${IMAGE_FULL}:main",
                            "${IMAGE_FULL}:sha-${env.GIT_COMMIT_SHORT}",
                        ]
                        env.DEPLOY_IMAGE       = "${IMAGE_FULL}:sha-${env.GIT_COMMIT_SHORT}"
                        env.BUILD_TYPE         = 'snapshot'

                    } else {
                        // ─ 기타 브랜치 빌드 (푸시만, 배포 없음)
                        tags = [
                            "${IMAGE_FULL}:${env.GIT_BRANCH_CLEAN}",
                            "${IMAGE_FULL}:sha-${env.GIT_COMMIT_SHORT}",
                        ]
                        env.DEPLOY_IMAGE       = "${IMAGE_FULL}:sha-${env.GIT_COMMIT_SHORT}"
                        env.BUILD_TYPE         = 'branch'
                    }

                    env.IMAGE_TAGS   = tags.join('\n')
                    env.PRIMARY_TAG  = tags[0]

                    echo """
┌──────────────────────────────────────────────┐
│  빌드 정보                                    │
├──────────────────────────────────────────────┤
│  브랜치    : ${env.BRANCH_NAME ?: '-'}
│  태그      : ${env.TAG_NAME ?: '-'}
│  커밋      : ${env.GIT_COMMIT_SHORT}
│  메시지    : ${env.GIT_COMMIT_MSG}
│  빌드 타입 : ${env.BUILD_TYPE}
├──────────────────────────────────────────────┤
│  생성할 이미지 태그:
${tags.collect { "│    • ${it}" }.join('\n')}
└──────────────────────────────────────────────┘"""
                }
            }
        }

        // ── Docker 이미지 빌드 ───────────────────────────────────────────────
        stage('Build Image') {
            steps {
                script {
                    // 태그 목록을 -t 옵션으로 변환
                    def tagArgs = env.IMAGE_TAGS.split('\n')
                        .collect { "-t ${it.trim()}" }
                        .join(' \\\n            ')

                    sh """
                        docker build \\
                            ${tagArgs} \\
                            --file ${WEB_DOCKERFILE} \\
                            --build-arg BUILDKIT_INLINE_CACHE=1 \\
                            --cache-from ${IMAGE_FULL}:main \\
                            --label "org.opencontainers.image.revision=${env.GIT_COMMIT_SHORT}" \\
                            --label "org.opencontainers.image.source=https://github.com/rockgis/uiscloud_onyx" \\
                            ${WEB_CONTEXT}
                    """
                }
            }
        }

        // ── GHCR 이미지 푸시 ─────────────────────────────────────────────────
        stage('Push Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ghcr-credentials',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh 'echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin'

                    script {
                        env.IMAGE_TAGS.split('\n').each { tag ->
                            sh "docker push ${tag.trim()}"
                        }
                    }
                }
            }
            post {
                always {
                    sh 'docker logout ghcr.io || true'
                }
            }
        }

        // ── 서버 배포 ────────────────────────────────────────────────────────
        stage('Deploy') {
            when {
                allOf {
                    // 배포 호스트가 지정된 경우
                    expression { return params.DEPLOY_HOST?.trim() }
                    // SKIP_DEPLOY 가 false인 경우
                    expression { return !params.SKIP_DEPLOY }
                    // main 브랜치 또는 릴리즈 태그인 경우만 자동 배포
                    anyOf {
                        branch 'main'
                        expression { return env.TAG_NAME != null }
                    }
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'deploy-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    script {
                        def host      = params.DEPLOY_HOST.trim()
                        def user      = params.DEPLOY_USER.trim()
                        def path      = params.DEPLOY_PATH.trim()
                        def newImage  = env.DEPLOY_IMAGE
                        def sshBase   = "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 -i \$SSH_KEY ${user}@${host}"

                        echo "🚀 배포 시작 → ${user}@${host}:${path}"
                        echo "   이미지: ${newImage}"

                        // 원격 서버에서 배포 실행
                        sh """
                            ${sshBase} bash -s << 'REMOTE_SCRIPT'
set -euo pipefail
cd "${path}"

echo "──────────────────────────────────────"
echo "  UISCloud 배포 시작"
echo "  이미지: ${newImage}"
echo "──────────────────────────────────────"

# .env 파일 존재 확인
if [ ! -f .env ]; then
    echo "❌ .env 파일이 없습니다. 서버 초기 설정을 먼저 진행하세요."
    exit 1
fi

# 현재 실행 중인 이미지 백업 (롤백용)
CURRENT_IMAGE=\$(docker compose \\
    -f docker-compose.prod.yml \\
    -f docker-compose.uiscloud.yml \\
    images web_server 2>/dev/null | tail -1 | awk '{print \$1":"\$2}' || echo "")

if [ -n "\$CURRENT_IMAGE" ] && [ "\$CURRENT_IMAGE" != ":" ]; then
    echo "현재 이미지 백업: \$CURRENT_IMAGE"
    if grep -q '^PREVIOUS_WEB_IMAGE=' .env; then
        sed -i "s|^PREVIOUS_WEB_IMAGE=.*|PREVIOUS_WEB_IMAGE=\$CURRENT_IMAGE|" .env
    else
        echo "PREVIOUS_WEB_IMAGE=\$CURRENT_IMAGE" >> .env
    fi
fi

# 새 이미지 태그로 업데이트
if grep -q '^UISCLOUD_WEB_IMAGE=' .env; then
    sed -i "s|^UISCLOUD_WEB_IMAGE=.*|UISCLOUD_WEB_IMAGE=${newImage}|" .env
else
    echo "UISCLOUD_WEB_IMAGE=${newImage}" >> .env
fi

echo "✅ 이미지 태그 업데이트 완료"

# 배포 스크립트 실행
if [ -f scripts/deploy.sh ]; then
    bash scripts/deploy.sh
elif [ -f deploy.sh ]; then
    bash deploy.sh
else
    echo "❌ deploy.sh 스크립트를 찾을 수 없습니다."
    exit 1
fi

REMOTE_SCRIPT
                        """
                    }
                }
            }
        }

    } // end stages

    // ── 후처리 ───────────────────────────────────────────────────────────────
    post {
        always {
            script {
                // 로컬 이미지 정리
                sh """
                    echo "${env.IMAGE_TAGS ?: ''}" | tr '\\n' '\\0' | xargs -r0 docker rmi --force 2>/dev/null || true
                """
            }
        }
        success {
            echo """
┌──────────────────────────────────────────────┐
│  ✅ 빌드/배포 성공                             │
│  이미지: ${env.PRIMARY_TAG}
│  빌드 #: ${env.BUILD_NUMBER}
└──────────────────────────────────────────────┘"""
        }
        failure {
            echo """
┌──────────────────────────────────────────────┐
│  ❌ 빌드/배포 실패                             │
│  빌드 #: ${env.BUILD_NUMBER}
│  로그: ${env.BUILD_URL}console
└──────────────────────────────────────────────┘"""
        }
    }

}
