# UISCloud 채팅 검색 파이프라인 분석

> 작성일: 2026-03-26
> 대상 버전: UISCloud Onyx (BGE-M3, qwen3:8b / qwen2.5:7b)

---

## 1. 전체 흐름 개요

```
사용자 질문
    │
    ▼
[api_server] POST /chat/send-chat-message
    │
    ▼
[LLM: qwen3:8b via Ollama]
 - 툴 호출 여부 판단 (AUTO)
 - 검색 쿼리 자동 생성
    │
    ▼ (internal_search 툴 호출)
[SearchTool]
 1. 쿼리 확장 (semantic + keyword 변형 생성)
 2. BGE-M3 임베딩 (inference_model_server)
 3. Vespa 하이브리드 검색 (semantic + BM25)
 4. RRF 병합 (여러 쿼리 결과 통합)
 5. LLM 관련도 선택 (상위 N개 청크 추림)
 6. 주변 청크 확장
 7. 포맷팅 (인용 번호 포함)
    │
    ▼
[LLM] 검색 결과 + 원본 질문 → 최종 답변 생성
    │
    ▼
사용자에게 스트리밍 응답
```

---

## 2. 단계별 상세 분석

### 2-1. 채팅 메시지 수신
**파일:** `backend/onyx/server/query_and_chat/chat_backend.py`
**함수:** `handle_send_chat_message()` (line ~525)

- API 엔드포인트: `POST /chat/send-chat-message`
- 요청 파라미터:
  - `message`: 사용자 질문 텍스트
  - `chat_session_id`: 대화 세션 ID
  - `stream`: 스트리밍 여부 (기본 true)
  - `internal_search_filters`: 문서 필터 (선택)
  - `forced_tool_id`: 특정 툴 강제 사용 (선택)
- 스트리밍 경로: `stream_generator()` → 실시간 패킷 전송
- 비스트리밍 경로: `gather_stream_full()` → 전체 응답 수집 후 반환

---

### 2-2. 메시지 처리 & 컨텍스트 구성
**파일:** `backend/onyx/chat/process_message.py`
**함수:** `handle_stream_message_objects()` (line ~436)

1. 대화 세션 + 페르소나 설정 로드
2. 전체 채팅 히스토리 불러오기
3. 첨부 파일 처리
4. 프로젝트 파일 추출:
   - 파일이 컨텍스트 윈도우의 60% 이하 → LLM에 직접 포함
   - 초과 → 검색 필터로 전환 (FileReaderTool 사용)
5. 툴 목록 구성 (`construct_tools()`):
   - **SearchToolConfig**: 검색 범위/필터 설정
   - Slack Search, Web Search 등 활성화 여부 포함
6. `run_llm_loop()` 호출

---

### 2-3. LLM 루프 실행
**파일:** `backend/onyx/chat/llm_loop.py`
**함수:** `run_llm_loop()` (line ~581)

```
최대 6 사이클 반복 (MAX_LLM_CYCLES = 6)

Cycle 0~4: tool_choice = AUTO
  ├─ 토큰 예산에 맞게 메시지 히스토리 구성
  ├─ LLM 호출 (툴 호출 or 직접 답변)
  └─ [툴 호출 시] 툴 실행 → 결과를 히스토리에 추가 → 다음 사이클

Cycle 5 (마지막): tool_choice = NONE
  ├─ LLM이 반드시 최종 답변 생성 (툴 사용 불가)
  └─ 답변 저장 & 스트리밍
```

---

### 2-4. 토큰 예산 관리
**파일:** `backend/onyx/chat/llm_loop.py`
**함수:** `construct_message_history()` (line ~273)

```
사용 가능 토큰 = max_input_tokens
    - 시스템 프롬프트 토큰
    - 커스텀 에이전트 프롬프트 토큰
    - 프로젝트 파일 텍스트 토큰
    - 리마인더 메시지 토큰
    = 남은 토큰으로 채팅 히스토리 배분
```

**히스토리 절삭 전략:**
- 마지막 사용자 메시지 + 이후 메시지는 항상 보존
- 오래된 히스토리부터 상단에서 절삭
- FileReaderTool 있을 경우 "forgotten-files" 메타데이터 메시지 삽입

---

### 2-5. SearchTool 실행 (핵심 단계)
**파일:** `backend/onyx/tools/tool_implementations/search/search_tool.py`
**함수:** `run()` (line ~536)

#### Step 1: DB 사전 조회
- ACL(접근 제어) 필터 로드
- SearchSettings (임베딩 모델 설정) 조회
- 페더레이션 소스(Slack, Salesforce 등) 토큰 사전 조회
- DB 세션 종료 → 이후 병렬 처리에서 DB 불필요

#### Step 2: 쿼리 확장
LLM이 원본 쿼리를 변형하여 여러 버전 생성:

| 쿼리 종류 | 설명 | 하이브리드 alpha |
|-----------|------|-----------------|
| Keyword Query | BM25 검색 최적화 | 0.4 (키워드 강화) |
| Semantic Query | 의미론적 검색 최적화 | 0.5 (균형) |
| Original Query | 원본 질문 그대로 | 0.5 |

중복 쿼리 제거 (대소문자 무관), 가중치 합산

#### Step 3: Vespa 병렬 검색
모든 쿼리 변형을 **동시에** Vespa에 요청:

```
각 쿼리 → BGE-M3 임베딩
        → Vespa 하이브리드 검색
          ├─ BM25 키워드 스코어 (1-alpha)
          └─ 벡터 코사인 유사도 (alpha)
        → 최대 50개 청크 반환
```

현재 사용 중인 Vespa 랭킹 프로파일:
- `hybrid_search_keyword_base_1024` (1024차원 키워드 강화)
- `hybrid_search_semantic_base_1024` (1024차원 시맨틱)

#### Step 4: RRF(Reciprocal Rank Fusion) 병합
여러 쿼리 결과를 하나로 통합:
- 쿼리별 가중치 × 순위 역수로 최종 스코어 산출
- 동일 문서의 인접 청크 병합
- 상위 50개 섹션 유지

#### Step 5: LLM 관련도 선택
```
50개 청크 후보
    │
    ▼ (MAX_CHUNKS_FED_TO_CHAT × DOC_EMBEDDING_CONTEXT_SIZE 토큰으로 절삭)
LLM이 관련 섹션 선택 (섹션당 최대 3청크)
    │
    ▼
MAX_CHUNKS_FED_TO_CHAT개 청크 선택 완료
```

#### Step 6: 주변 청크 확장
선택된 각 섹션에 대해 LLM이 앞뒤 청크 포함 여부 결정
- `CONTEXT_CHUNKS_ABOVE`, `CONTEXT_CHUNKS_BELOW` 환경변수로 제어
- 현재 설정: 둘 다 **0** (확장 없음)

#### Step 7: LLM용 포맷팅
```python
# 결과물 형태
[[1]](source_url) AhnLab TrusGuard 메뉴얼
내용: "TrusGuard는 통합 보안 플랫폼으로..."

[[2]](source_url) AhnLab AIPS 메뉴얼
내용: "AIPS는 침입 방지 시스템으로..."
```

두 가지 응답 생성:
- `rich_response`: 전체 검색 문서 (UI 표시용)
- `llm_facing_response`: `MAX_CHUNKS_FED_TO_CHAT`개로 절삭된 텍스트 (LLM 입력용)

---

### 2-6. 최종 LLM 답변 생성
1. SearchTool 응답을 `TOOL_CALL_RESPONSE` 메시지로 히스토리에 추가
2. LLM 루프 다음 사이클: 검색 결과 포함 히스토리로 최종 답변 생성
3. 답변 토큰 스트리밍 → 사용자
4. DB에 채팅 메시지 저장

---

## 3. 현재 설정값 (UISCloud 배포 기준)

| 설정 항목 | 현재 값 | 기본값 | 위치 |
|-----------|--------|--------|------|
| `MAX_CHUNKS_FED_TO_CHAT` | **7** | 25 | `.env` |
| `CONTEXT_CHUNKS_ABOVE` | **0** | 1 | `.env` |
| `CONTEXT_CHUNKS_BELOW` | **0** | 1 | `.env` |
| `persona.num_chunks` | **25** | 25 | DB (persona id=0) |
| `MAX_LLM_CYCLES` | **6** | 6 | 코드 상수 |
| `MAX_CHUNKS_FOR_RELEVANCE` | **3** | 3 | 코드 상수 |
| 임베딩 모델 | **BAAI/bge-m3** | — | search_settings (id=3) |
| 인덱스 차원 | **1024** | — | Vespa schema |
| LLM | **qwen3:8b** | — | LLM Provider 설정 |
| `LLM_SOCKET_READ_TIMEOUT` | **300초** | 60초 | `.env` |

---

## 4. 문제 분석: 왜 하나의 문서만 검색되는가

### 원인 1: `MAX_CHUNKS_FED_TO_CHAT=7` (너무 작음)

```
Vespa 검색 결과 (50개 청크, 6개 문서에서)
    ├─ TrusGuard 관련 청크: 15개 (유사도 상위)
    ├─ AIPS 관련 청크: 12개
    ├─ DPX 관련 청크: 10개
    ├─ ...
    └─ ...
                   │ (7개만 통과)
                   ▼
    상위 7개 → 대부분 1~2개 문서에서만
```

6개 문서를 모두 커버하려면 최소 6개 청크(문서당 1개) 필요하지만,
쿼리와의 유사도 불균형으로 특정 문서에 청크가 집중됩니다.

### 원인 2: "문서 목록" 질문은 벡터 검색에 부적합

```
질문: "검색 가능한 메뉴얼이 어떤 것이 있는지 요약 해줘"
    │
    ▼
BGE-M3 임베딩 → 쿼리 벡터 생성
    │
    ▼
Vespa 코사인 유사도 검색
    → 가장 유사한 문서 내용 청크 반환
    → "문서 목록"이라는 개념 자체는
       어떤 문서의 내용과도 유사하지 않음
```

벡터 검색은 **내용 기반 유사도** 검색입니다.
"문서 목록을 알려줘"라는 메타데이터 질문에는 내용 검색보다 **DB 직접 조회**가 적합합니다.

---

## 5. 해결 방안

### 방안 A: `MAX_CHUNKS_FED_TO_CHAT` 증가 (즉시 적용 가능)

```bash
# .env 수정
MAX_CHUNKS_FED_TO_CHAT=25  # 7 → 25
```

- 장점: 즉시 적용, 코드 변경 없음
- 단점: LLM에 전달되는 토큰 증가 → **응답 속도 약 2~3배 느려짐**
- 적합한 케이스: "넓은 범위의 문서에서 검색" 시

---

### 방안 B: 커스텀 `list_documents` 툴 추가 (권장)

DB에서 직접 문서 목록을 조회하는 새 툴을 구현합니다.

```
LLM: "문서 목록 조회 필요"
    │
    ▼
list_documents 툴 호출
    │
    ▼
DB 직접 조회:
  SELECT d.semantic_id, d.source_type
  FROM document d
  JOIN document_by_connector_credential_pair dcp ON d.id = dcp.id
  WHERE dcp.connector_id IN (...)
    │
    ▼
6개 문서명 + 설명 → LLM에 전달
    │
    ▼
LLM: "현재 검색 가능한 메뉴얼은 다음과 같습니다: ..."
```

- 장점: **정확한 전체 문서 목록** 반환, 빠름
- 단점: 신규 툴 구현 필요 (약 100~200줄 코드)
- 구현 위치: `backend/onyx/tools/tool_implementations/list_documents/`

---

### 방안 C: 시스템 프롬프트 개선 (중간 해결책)

페르소나 시스템 프롬프트에 각 문서를 개별 검색하도록 지시:

```
시스템 프롬프트 추가:
"문서 목록에 관한 질문을 받으면:
1. 각 문서 종류(TrusGuard, AIPS, DPX)별로 개별 검색을 수행하세요.
2. 각 검색 결과에서 문서 제목과 개요를 추출하세요.
3. 모든 검색 결과를 종합하여 전체 목록을 제공하세요."
```

- 장점: 코드 변경 없음, 즉시 적용
- 단점: LLM 최대 6사이클 제한으로 모든 문서 커버 불확실

---

## 6. 권장 적용 순서

```
단기 (즉시):
  → 방안 A: MAX_CHUNKS_FED_TO_CHAT=25 로 변경
  → 방안 C: 시스템 프롬프트 개선

중기 (1주일 내):
  → 방안 B: list_documents 커스텀 툴 구현
             (가장 정확하고 빠른 해결책)
```

---

## 7. 관련 파일 목록

| 파일 | 역할 |
|------|------|
| `backend/onyx/server/query_and_chat/chat_backend.py` | 채팅 API 엔드포인트 |
| `backend/onyx/chat/process_message.py` | 메시지 처리 & 툴 구성 |
| `backend/onyx/chat/llm_loop.py` | LLM 루프 + 토큰 예산 관리 |
| `backend/onyx/chat/llm_step.py` | 단일 LLM 호출 처리 |
| `backend/onyx/tools/tool_implementations/search/search_tool.py` | SearchTool 구현 |
| `backend/onyx/context/search/pipeline.py` | 검색 파이프라인 |
| `backend/onyx/document_index/vespa/chunk_retrieval.py` | Vespa 청크 검색 |
| `backend/onyx/tools/tool_runner.py` | 툴 실행 관리 |
| `backend/onyx/configs/chat_configs.py` | 채팅 설정 상수 |
| `backend/model_server/encoders.py` | BGE-M3 임베딩 (수정됨: 동시 로딩 Lock 추가) |
