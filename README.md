# codex-gemini-orchestrator

**Codex는 관리자(manager), Gemini CLI는 작업자(worker)로 쓰기 위한 Windows 중심의 간단한 오케스트레이션 도구입니다.**

목표는 단순합니다.

- Codex: 요구사항 이해, 작업 계획, 판단, 최종 검증
- Gemini CLI: 코드베이스 탐색, 구현, 반복 수정, 테스트처럼 토큰을 많이 쓰는 작업
- Gemini worker는 `YOLO` 모드로 실행해 중간 승인 없이 작업
- 작업이 끝나면 Codex가 실제 diff와 테스트 결과를 다시 검증

즉, 성능이 더 좋은 Codex의 토큰은 **기획·판단·검증에 아끼고**, 대량 작업은 Gemini CLI에 넘기는 구조입니다.

```text
사용자
  ↓
Codex CLI / Codex Desktop
  │
  ├─ 1. 문제 이해
  ├─ 2. 작업 분해 / acceptance criteria 작성
  │
  └─ 3. Gemini worker 호출
          ↓
       Gemini CLI
       --approval-mode=yolo
       --skip-trust
          │
          ├─ 코드 탐색
          ├─ 파일 수정
          ├─ 명령 실행
          └─ 테스트
          ↓
       결과 + working tree
          ↓
Codex
  ├─ diff 검토
  ├─ 테스트 재검증
  └─ 최종 판단
```

## 가장 쉬운 설치 방법

### 1. 저장소를 받습니다

PowerShell에서:

```powershell
git clone https://github.com/pikachu444/codex-gemini-orchestrator.git
cd codex-gemini-orchestrator
```

### 2. `bootstrap.cmd`를 실행합니다

탐색기에서 **`bootstrap.cmd`를 더블클릭**해도 되고, PowerShell에서 다음처럼 실행해도 됩니다.

```powershell
.\bootstrap.cmd
```

설치 스크립트가 다음을 자동으로 처리합니다.

1. Node.js 20 이상 확인
2. Node.js가 없으면 `winget`으로 LTS 설치 시도
3. Codex CLI 설치/업데이트
4. Gemini CLI 설치/업데이트
5. 이 저장소를 Codex의 전역 `gemini-worker` skill로 설치
6. `~/.codex/config.toml`을 백업한 뒤 필요한 설정 적용
7. 설치된 버전과 실행 가능 여부 검사

기본 설치 버전은 이 저장소에서 검증 기준으로 잡은 버전입니다.

| 구성요소 | 기준 버전 |
|---|---:|
| Codex CLI | `0.151.0` |
| Gemini CLI | `0.57.0` |
| Node.js | `20+` |
| OS | Windows 11 + PowerShell |

최신 버전을 설치하고 싶으면:

```powershell
.\scripts\Setup.ps1 -Latest
```

> 회사 PC에서 `winget` 또는 전역 npm 설치가 정책으로 막혀 있으면 해당 단계에서 명확히 실패하도록 되어 있습니다. 기존에 Node/Codex/Gemini가 설치되어 있으면 그대로 사용 가능합니다.

## 3. 최초 1회 로그인

CLI가 아직 인증되어 있지 않다면 각각 한 번 실행해서 회사 계정으로 로그인합니다.

```powershell
codex
gemini
```

기업 정책에 따라 브라우저 SSO 또는 별도 인증 절차가 나타날 수 있습니다. 이 인증 자체는 자동화할 수 없습니다.

## 4. Codex를 다시 시작합니다

설치 스크립트는 다음 위치에 skill을 설치합니다.

```text
%USERPROFILE%\.codex\skills\gemini-worker
```

Codex CLI나 Codex Desktop이 이미 열려 있었다면 한 번 종료 후 다시 실행하는 편이 안전합니다.

## 실제 사용법

이제 평소처럼 작업하려는 프로젝트 폴더에서 Codex를 실행합니다.

예를 들어:

```powershell
cd C:\work\my-project
codex
```

그리고 굳이 복잡한 명령어를 외울 필요 없이 자연어로 지시하면 됩니다.

```text
이 작업은 gemini-worker를 써서 진행해.
전체 계획과 최종 검증은 네가 하고,
코드 탐색과 구현, 테스트 반복은 Gemini CLI에 최대한 위임해.
```

또는 더 짧게:

```text
Gemini worker를 사용해서 이 이슈를 처리해. 계획과 최종 검토는 네가 해.
```

Codex는 설치된 `gemini-worker` skill의 지침에 따라 Gemini CLI를 별도 worker처럼 호출합니다.

### 권장 작업 분담

Gemini에 넘기기 좋은 일:

- 저장소 전체 탐색
- 관련 코드 위치 찾기
- 반복적인 구현 작업
- 여러 파일에 걸친 수정
- 테스트 실행 → 오류 수정 → 재실행 반복
- 로그 분석
- 초안 구현
- 독립적인 second opinion

Codex가 직접 맡는 것이 좋은 일:

- 사용자의 의도 해석
- 아키텍처/방향 결정
- 작업 범위와 acceptance criteria 확정
- Gemini가 낸 결과의 사실 확인
- `git diff` 검토
- 핵심 테스트의 최종 재검증
- 최종 답변

## Gemini는 왜 YOLO인가?

이 저장소에서는 의도적으로 Gemini worker를 다음과 같이 실행합니다.

```text
--approval-mode=yolo
--skip-trust
--output-format=json
```

`yolo`는 Gemini가 파일 편집이나 shell 명령을 실행할 때 매번 사람에게 승인을 묻지 않게 합니다. `--skip-trust`는 headless 실행 중 폴더 신뢰 확인 때문에 멈추는 것을 방지합니다.

따라서 이 구조는 다음과 같습니다.

```text
Gemini: 맡은 작업은 중간 승인 없이 수행
Codex: 끝난 결과를 다시 검토
```

이게 이 저장소의 핵심 설계입니다.

단, YOLO는 권한이 강합니다. 비밀키나 민감 자료가 섞인 디렉터리에서 무작정 실행하지 마십시오. 회사 관리자가 Gemini CLI 정책으로 YOLO 사용을 차단한 환경에서는 관리자 정책이 우선합니다.

## Codex 설정

Gemini CLI는 외부 Google 서비스에 접속해야 하므로 Codex sandbox에서 네트워크를 허용해야 합니다. 설치 스크립트는 기존 `~/.codex/config.toml`을 먼저 백업한 뒤 다음 설정을 반영합니다.

```toml
approval_policy = "never"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

의미는 다음과 같습니다.

- `approval_policy = "never"`: Codex도 정상적인 작업 중 반복 승인을 요구하지 않음
- `workspace-write`: Codex의 쓰기 범위는 기본적으로 workspace로 제한
- `network_access = true`: Codex가 실행한 Gemini CLI가 네트워크를 사용할 수 있도록 허용

설정 변경을 원하지 않으면 설치할 때:

```powershell
.\scripts\Setup.ps1 -SkipCodexConfig
```

## Gemini worker를 직접 호출하고 싶다면

Codex를 통하지 않고 wrapper만 테스트할 수도 있습니다.

먼저 작업 내용을 Markdown 파일로 만듭니다.

```markdown
# Task

현재 저장소를 분석해서 테스트가 실패하는 원인을 찾고 수정하라.
수정 후 관련 테스트를 실행하라.
커밋이나 push는 하지 마라.
```

예를 들어 `task.md`로 저장한 뒤:

```powershell
& "$env:USERPROFILE\.codex\skills\gemini-worker\scripts\Invoke-GeminiWorker.ps1" `
  -TaskFile .\task.md `
  -WorkingDirectory .
```

wrapper는 Gemini의 JSON 결과, stderr, 실행 전후 git 상태를 임시 run 디렉터리에 보존하고 마지막에 해당 경로를 출력합니다.

## 환경 점검

설치 상태만 다시 확인하고 싶다면:

```powershell
.\scripts\Test-Environment.ps1
```

또는 전역 skill 설치 후:

```powershell
& "$env:USERPROFILE\.codex\skills\gemini-worker\scripts\Test-Environment.ps1"
```

## 이 저장소와 비슷한 프로젝트

이 아이디어 자체가 완전히 새로운 것은 아닙니다. 구현 방향을 잡을 때 특히 아래 저장소들을 참고할 가치가 있습니다.

### [OkamiFeng/gemini-subagent](https://github.com/OkamiFeng/gemini-subagent)

Codex가 Gemini CLI에 **명확히 제한된 subtask를 맡기고**, 결과를 다시 Codex가 검토·통합하는 구조입니다. 이 저장소의 아이디어와 가장 직접적으로 가깝습니다.

- Codex skill 형태
- Gemini CLI wrapper 포함
- 모델 선택 / preflight / 결과 수집 구현
- Windows도 고려
- 현재는 archived 상태

이 프로젝트는 여기서 아이디어를 참고하되, 회사 Windows 환경에서 더 단순하게 쓰고 승인 대기 없이 Gemini가 실제 구현을 수행하도록 YOLO 중심으로 구성했습니다.

### [otakumesi/subagent-cli](https://github.com/otakumesi/subagent-cli)

더 범용적인 multi-agent orchestration 도구입니다. Codex, Gemini, Claude Code 등을 worker로 시작하고 turn 전달, wait, handoff, continue 등을 관리합니다.

- 여러 종류의 coding agent 지원
- ACP 기반
- worker lifecycle 관리
- 복수 agent orchestration에 적합

기능은 훨씬 강력하지만 현재 목적에는 다소 무겁습니다. 이 저장소는 우선 **Codex → Gemini 한 방향 위임**에 집중해 설치와 동작을 최대한 단순화했습니다.

## 왜 MCP/ACP부터 쓰지 않았나?

가능합니다. 하지만 첫 단계부터 MCP 서버나 ACP controller를 넣으면 다음이 추가됩니다.

- 별도 프로세스 관리
- 추가 dependency
- 상태 관리
- protocol debugging
- 승인/세션 lifecycle 처리

현재 목적은 `Codex가 Gemini CLI를 값싼 worker처럼 많이 사용한다`이므로 subprocess + JSON 결과 회수가 더 단순합니다.

실사용 후 다음이 필요해지면 ACP/MCP 구조로 확장할 수 있습니다.

- Gemini worker 여러 개 병렬 실행
- 장기 persistent session
- Claude Code까지 worker로 추가
- agent별 역할/큐 관리
- 작업 상태 UI

## 저장소 구조

```text
codex-gemini-orchestrator/
├─ README.md
├─ AGENTS.md
├─ GEMINI.md
├─ SKILL.md
├─ VERSION_MATRIX.md
├─ bootstrap.cmd
├─ .codex/
│  └─ config.toml
├─ scripts/
│  ├─ Setup.ps1
│  ├─ Invoke-GeminiWorker.ps1
│  └─ Test-Environment.ps1
└─ templates/
   └─ task.md
```

## 현재 설계 원칙

1. Codex가 manager다.
2. Gemini는 worker다.
3. Gemini에게는 큰 작업을 적극적으로 넘긴다.
4. Gemini는 YOLO로 중간 승인 없이 작업한다.
5. Gemini 결과를 그대로 믿지 않는다.
6. Codex가 최종 diff와 핵심 테스트를 검증한다.
7. 자동 commit/push는 기본적으로 하지 않는다.
8. 복잡한 orchestration framework는 실제 필요가 생길 때 추가한다.

## 상태

현재 단계는 **Windows에서 Codex CLI / Codex Desktop이 Gemini CLI를 실제 worker로 호출하는 최소 실용 버전**입니다.

먼저 실제 프로젝트 몇 개에서 사용해보고, 필요하면 다음 단계로 persistent Gemini session, 병렬 worker, ACP/MCP bridge를 추가할 예정입니다.
