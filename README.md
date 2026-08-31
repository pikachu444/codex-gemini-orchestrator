# codex-gemini-orchestrator

**Codex는 관리자(manager), Gemini CLI는 작업자(worker)로 쓰기 위한 Windows 중심의 간단한 오케스트레이션 도구입니다.**

목표는 단순합니다.

- Codex: 요구사항 이해, 작업 계획, 판단, 최종 검증
- Gemini CLI: 코드베이스 탐색, 구현, 반복 수정, 테스트처럼 토큰을 많이 쓰는 작업
- Gemini worker는 `YOLO` 모드로 실행해 중간 승인 없이 작업
- 작업이 끝나면 Codex가 실제 diff와 테스트 결과를 다시 검증

즉, Codex의 토큰은 **기획·판단·검증에 아끼고**, 대량 실행 작업은 Gemini CLI에 넘기는 구조입니다.

```text
사용자
  ↓
Codex CLI / Codex Desktop
  │
  ├─ 문제 이해
  ├─ 작업 분해 / acceptance criteria 작성
  │
  └─ Gemini worker 호출
          ↓
       Gemini CLI
       --approval-mode=yolo
       --skip-trust
          │
          ├─ 코드 탐색
          ├─ 파일 수정
          ├─ 명령 실행
          └─ 테스트 반복
          ↓
       결과 + 실제 working tree
          ↓
Codex
  ├─ diff 검토
  ├─ 핵심 테스트 재검증
  └─ 최종 판단
```

## 제일 쉬운 설치

### Git을 잘 모르면: ZIP + 더블클릭

1. 이 GitHub 저장소에서 **Code → Download ZIP**을 누릅니다.
2. ZIP을 풉니다.
3. 폴더 안의 **`bootstrap.cmd`를 더블클릭**합니다.

끝입니다. Git은 없어도 worker 자체는 동작합니다. 다만 Git이 설치되어 있으면 Gemini 작업 전후의 `git status`를 자동 기록할 수 있어 검증이 더 편합니다.

### Git을 쓰면

PowerShell에서:

```powershell
git clone https://github.com/pikachu444/codex-gemini-orchestrator.git
cd codex-gemini-orchestrator
.\bootstrap.cmd
```

`bootstrap.cmd`는 `scripts/Setup.ps1`을 실행합니다.

설치 스크립트가 자동으로 하는 일:

1. Node.js 20 이상 확인
2. Node.js가 없거나 너무 오래됐으면 `winget`으로 LTS 설치 시도
3. Codex CLI 설치/업데이트
4. Gemini CLI 설치/업데이트
5. `gemini-worker`를 Codex 사용자 전역 skill로 설치
6. 기존 `~/.codex/config.toml`을 백업
7. Gemini worker 실행에 필요한 Codex sandbox/network 설정 적용
8. 설치된 버전과 실행 가능 여부 검사

기본 설치 버전은 재현성을 위해 고정했습니다.

| 구성요소 | 기본 기준 |
|---|---:|
| Codex CLI | `0.151.0` |
| Gemini CLI | `0.57.0` |
| Node.js | `20+` |
| OS | Windows 11 + PowerShell |

최신 npm 버전을 설치하고 싶다면:

```powershell
.\scripts\Setup.ps1 -Latest
```

CLI는 이미 설치되어 있고 skill/config만 설치하고 싶다면:

```powershell
.\scripts\Setup.ps1 -SkipCliInstall
```

Codex 전역 설정을 건드리고 싶지 않다면:

```powershell
.\scripts\Setup.ps1 -SkipCodexConfig
```

> 회사 PC에서 `winget`, npm 전역 설치, Gemini YOLO 등의 사용이 관리자 정책으로 차단되어 있으면 해당 정책이 우선합니다.

## 최초 1회 로그인

CLI 인증이 아직 안 되어 있다면 각각 한 번 실행해 회사 계정으로 로그인합니다.

```powershell
codex
gemini
```

회사 환경에 따라 브라우저 SSO나 별도 인증 화면이 나올 수 있습니다. 인증 자체는 사용자 계정 확인이 필요하므로 완전 자동화할 수 없습니다.

## skill은 어디에 설치되나?

현재 Codex의 사용자 전역 skill 위치를 사용합니다.

```text
%USERPROFILE%\.agents\skills\gemini-worker
```

이 위치를 쓰는 이유가 있습니다. 최신 Codex는 사용자 skill을 `$HOME/.agents/skills`에서 읽습니다. 또한 2026년 8월 기준 Windows Codex Desktop에는 repo-local `.agents/skills`를 발견하지 못하는 버그 보고가 있어, 이 프로젝트는 **사용자 전역 skill**로 설치하는 방식을 기본으로 잡았습니다.

관련 이슈:

- https://github.com/openai/codex/issues/40458

설치 후 Codex CLI나 Codex Desktop이 이미 실행 중이었다면 한 번 종료 후 다시 실행하는 것이 안전합니다.

## 실제 사용법

설치 후에는 작업하려는 프로젝트에서 평소처럼 Codex를 엽니다.

CLI라면:

```powershell
cd C:\work\my-project
codex
```

Codex Desktop이라면 해당 프로젝트 폴더를 workspace로 열면 됩니다.

그리고 자연어로 지시합니다.

```text
이 작업은 gemini-worker를 써서 진행해.
전체 계획과 최종 검증은 네가 하고,
코드 탐색과 구현, 테스트 반복은 Gemini CLI에 최대한 위임해.
```

더 짧게 해도 됩니다.

```text
Gemini worker를 사용해서 이 이슈를 처리해. 계획과 최종 검토는 네가 해.
```

이후 같은 작업 흐름에서는 매번 복잡한 CLI 명령을 직접 칠 필요가 없습니다. Codex가 skill 지침을 읽고 task를 만들어 Gemini wrapper를 호출하도록 설계했습니다.

## 어떤 일을 Gemini에 넘기나?

Gemini에 넘기기 좋은 일:

- 저장소 전체 탐색
- 관련 코드 위치 찾기
- 반복적인 구현
- 여러 파일에 걸친 수정
- 테스트 실행 → 오류 분석 → 수정 → 재실행 반복
- 로그 분석
- 초안 구현
- 독립적인 second opinion

Codex가 직접 잡아야 할 일:

- 사용자 의도 해석
- 아키텍처/방향 결정
- 작업 범위 확정
- acceptance criteria 작성
- Gemini 결과 검토
- `git diff` 검토
- 핵심 테스트 최종 재검증
- 최종 답변

## 실제 Gemini 호출 방식

wrapper는 Gemini CLI를 대략 다음 옵션으로 실행합니다.

```text
--approval-mode yolo
--skip-trust
--output-format json
--prompt <짧은 headless 지시>
```

긴 task 본문은 Windows command-line 길이/quoting 문제를 피하기 위해 **stdin**으로 넘깁니다.

Gemini CLI 문서상 stdin 입력과 `--prompt`를 같이 사용할 수 있으며, `--prompt`는 headless 실행을 강제합니다.

공식 문서:

- https://geminicli.com/docs/cli/headless/
- https://geminicli.com/docs/cli/cli-reference/

## 왜 YOLO인가?

이 저장소에서는 YOLO가 실수로 켜진 게 아니라 **의도된 기본값**입니다.

```text
Gemini: 맡은 작업은 중간 승인 없이 수행
Codex: 작업이 끝난 뒤 실제 파일과 diff를 검증
```

`--approval-mode yolo`는 Gemini의 tool call을 자동 승인합니다. `--skip-trust`는 headless worker가 폴더 신뢰 팝업 때문에 멈추는 것을 막습니다.

Gemini는 그래서 실제로 파일 수정, shell 실행, 테스트 반복까지 맡을 수 있습니다.

단, YOLO는 권한이 강합니다. 민감한 비밀키/자격증명이 섞여 있는 디렉터리에서 함부로 실행하지 마십시오. `GEMINI.md`에도 credential/secret 탐색, 자동 commit/push, 외부 쓰기를 기본 금지하도록 적어두었습니다.

## Codex 설정

Gemini CLI는 외부 Google 서비스에 접속해야 하므로 Codex가 child process에 네트워크를 허용해야 합니다.

설치 스크립트는 기존 `~/.codex/config.toml`을 timestamp가 붙은 backup 파일로 복사한 다음 필요한 키를 수정/추가합니다.

```toml
approval_policy = "never"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

의미:

- `approval_policy = "never"`: Codex도 정상적인 로컬 작업에서 반복 승인을 요구하지 않음
- `workspace-write`: Codex의 쓰기는 기본적으로 workspace로 제한
- `network_access = true`: Codex가 실행한 Gemini CLI의 네트워크 사용 허용

Gemini의 YOLO는 **Codex sandbox를 뚫는 옵션이 아닙니다.** Gemini는 여전히 Codex child process가 허용받은 OS/sandbox 범위 안에서 동작합니다.

## Gemini worker를 직접 테스트하기

Codex를 통하지 않고 wrapper만 실행해볼 수도 있습니다.

`task.md`를 하나 만듭니다.

```markdown
# Task

현재 저장소를 분석해서 테스트가 실패하는 원인을 찾고 수정하라.
수정 후 관련 테스트를 실행하라.
커밋이나 push는 하지 마라.
```

그 다음:

```powershell
& "$env:USERPROFILE\.agents\skills\gemini-worker\scripts\Invoke-GeminiWorker.ps1" `
  -TaskFile .\task.md `
  -WorkingDirectory .
```

실행할 때마다 `%TEMP%\codex-gemini-orchestrator\<run-id>` 아래에 다음 자료를 남깁니다.

```text
prompt.md       Gemini에 실제 전달한 전체 prompt
raw.json        Gemini CLI의 원본 JSON 출력
result.md       사람이 읽기 쉬운 결과
stderr.txt      stderr
 git-before.txt  실행 전 git status
 git-after.txt   실행 후 git status
```

Codex는 Gemini의 말만 믿는 대신 이 결과와 실제 working tree를 같이 확인합니다.

## 환경 점검

저장소에서:

```powershell
.\scripts\Test-Environment.ps1
```

Gemini 인증/네트워크까지 작은 실제 요청으로 확인하려면:

```powershell
.\scripts\Test-Environment.ps1 -TestGeminiAuth
```

전역 skill 설치 후에는:

```powershell
& "$env:USERPROFILE\.agents\skills\gemini-worker\scripts\Test-Environment.ps1"
```

## 비슷한 프로젝트 / 선행 구현

이 아이디어 자체가 완전히 새로운 것은 아닙니다. 조사 과정에서 특히 다음 두 프로젝트가 직접적으로 관련 있었습니다.

### [OkamiFeng/gemini-subagent](https://github.com/OkamiFeng/gemini-subagent)

Codex가 Gemini CLI에 **제한된 subtask를 맡기고**, 결과를 다시 Codex가 검토·통합하는 구조입니다. 이 프로젝트와 아이디어가 가장 직접적으로 비슷합니다.

특징:

- Codex skill 형태
- Gemini CLI wrapper
- 모델 선택 / preflight / 결과 수집
- Windows 고려
- 현재 archived 상태

이 저장소는 이 접근에서 아이디어를 참고하되, Windows 회사 환경에서 더 단순하게 쓰고 **Gemini에게 실제 구현을 YOLO로 맡기는 것**에 초점을 맞췄습니다.

### [otakumesi/subagent-cli](https://github.com/otakumesi/subagent-cli)

더 범용적인 multi-agent orchestration CLI입니다. Codex, Gemini, Claude Code 등을 worker로 띄우고 turn 전달, wait, approval, handoff, continue 등을 관리합니다.

특징:

- 여러 coding agent 지원
- ACP 기반
- worker lifecycle 관리
- multi-agent orchestration에 적합

기능은 훨씬 강력하지만, `Codex → Gemini` 한 방향 위임만 필요할 때는 구조가 더 무겁습니다. 그래서 이 저장소는 subprocess + JSON 결과 회수로 먼저 시작합니다.

## 왜 MCP/ACP부터 쓰지 않았나?

MCP/ACP로도 만들 수 있습니다. 다만 첫 단계부터 넣으면 다음이 추가됩니다.

- 별도 controller/process 관리
- 추가 dependency
- agent 상태 관리
- protocol debugging
- 세션 lifecycle
- approval event 처리

현재 목표는 단순합니다.

```text
Codex가 계획한다
→ Gemini가 많이 일한다
→ Codex가 검사한다
```

실제 사용 후 다음이 필요해지면 ACP/MCP 구조로 확장할 수 있습니다.

- Gemini worker 여러 개 병렬 실행
- persistent Gemini session
- Claude Code worker 추가
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
3. 토큰을 많이 쓰는 실행 작업은 Gemini에 적극 위임한다.
4. Gemini는 YOLO로 중간 승인 없이 작업한다.
5. Gemini의 결과 보고를 그대로 믿지 않는다.
6. Codex가 실제 diff와 핵심 테스트를 최종 검증한다.
7. 자동 commit/push는 기본 금지한다.
8. 복잡한 orchestration framework는 실제 필요가 생길 때 추가한다.

## 상태

현재 단계는 **Windows에서 Codex CLI / Codex Desktop이 Gemini CLI를 실제 worker로 호출하는 최소 실용 버전**입니다.

먼저 실제 프로젝트에서 `계획 → Gemini 실행 → Codex 검증` 흐름을 검증한 뒤 persistent session, 병렬 worker, ACP/MCP bridge를 추가하는 방향을 권장합니다.
