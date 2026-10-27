#!/usr/bin/env bash
# Claude Code PreToolUse 훅: Claude가 git commit을 실행하기 직전에 lint → build → test를 돌린다.
# 하나라도 실패하면 exit 2로 커밋을 막고, 실패 출력을 stderr로 Claude에게 돌려줘서 고치게 한다.
#
# 플러그인으로 설치하면 이 파일은 프로젝트 밖에 있으므로, 단계별 명령은 환경 변수
# PRE_COMMIT_LINT_CMD / PRE_COMMIT_BUILD_CMD / PRE_COMMIT_TEST_CMD로 받는다
# (프로젝트 .claude/settings.json의 "env"에 적으면 된다). 비워 두면 package.json에 같은 이름의
# 스크립트(lint / build / test)가 있을 때 `npm run <이름>`으로 실행하고, 없으면 그 단계는 건너뛴다.
LINT_CMD="${PRE_COMMIT_LINT_CMD:-}"
BUILD_CMD="${PRE_COMMIT_BUILD_CMD:-}"
TEST_CMD="${PRE_COMMIT_TEST_CMD:-}"

input=$(cat)

# git commit이 들어 있는 명령에만 반응한다. "git add . && git commit -m ..."처럼 이어 붙인 명령과
# "git -C dir commit"도 잡고, "git commit-tree" 같은 다른 명령은 건너뛴다.
if ! printf '%s' "$input" | grep -Eq '(^|[^[:alnum:]_-])git[[:space:]]+([^"]*[[:space:]])?commit([^[:alnum:]_-]|$)'; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

passed=()
skipped=()
report=""

run_step() {
  local name=$1 cmd=$2 out
  if [ -z "$cmd" ]; then
    if [ -f package.json ] && grep -Eq "\"$name\"[[:space:]]*:" package.json; then
      cmd="npm run --silent $name"
    else
      skipped+=("$name")
      return
    fi
  fi
  if out=$(NO_COLOR=1 FORCE_COLOR=0 bash -c "$cmd" 2>&1); then
    passed+=("$name")
  else
    report+=$'\n\n'"✗ $name 실패 ($cmd) — 출력 마지막 40줄:"$'\n'"$(printf '%s\n' "$out" | tail -n 40)"
  fi
}

list() { local s; printf -v s '%s, ' "$@"; printf '%s' "${s%, }"; }

run_step lint "$LINT_CMD"
run_step build "$BUILD_CMD"
run_step test "$TEST_CMD"

if [ -n "$report" ]; then
  echo "커밋 전 검사에 실패해서 커밋을 막았습니다. 아래 문제를 고친 뒤 다시 커밋하세요.$report" >&2
  exit 2
fi

# 명령이 하나도 없을 때 막아 버리면 커밋 자체를 못 하게 되므로, 경고만 띄우고 통과시킨다
if [ ${#passed[@]} -eq 0 ]; then
  msg="⚠️ 커밋 전 검사: 실행할 lint/build/test 명령이 없어 검사 없이 커밋합니다 (PRE_COMMIT_LINT_CMD 등 환경 변수로 설정)"
else
  msg="✅ 커밋 전 검사 통과: $(list "${passed[@]}")"
  [ ${#skipped[@]} -gt 0 ] && msg+=" (명령 없음: $(list "${skipped[@]}"))"
fi
printf '{"systemMessage": "%s"}\n' "$msg"
