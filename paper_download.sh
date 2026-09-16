#!/usr/bin/env bash

set -euo pipefail

# 인자 개수 확인
if [ "$#" -lt 2 ]; then
    echo "사용법: $0 <arXiv_URL> <논문_제목>"
    echo "예시: $0 \"https://arxiv.org/abs/2505.19591\" \"Multi-Agent Collaboration via Evolving Orchestration\""
    exit 1
fi

ARXIV_URL="$1"
PAPER_TITLE="$2"

# 1. arXiv ID 추출 (정규식 구분자 충돌 방지를 위해 grep -oP 사용)
# URL 끝의 ID 형식(예: 2505.19591 또는 2505.19591v1 또는 hep-th/9901001)을 정확히 추출
ARXIV_ID=$(echo "$ARXIV_URL" | grep -oE '([0-9]{4}\.[0-9]{4,5}(v[0-9]+)?|[a-z\-]+/[0-9]{7})' | head -n 1)

# grep으로 추출되지 않았을 경우를 위한 URL 끝부분 fallback
if [ -z "$ARXIV_ID" ]; then
    ARXIV_ID=$(basename "$ARXIV_URL" | sed 's/\.pdf$//')
fi

if [ -z "$ARXIV_ID" ]; then
    echo "[오류] 올바른 arXiv URL 또는 ID를 찾을 수 없습니다: $ARXIV_URL"
    exit 1
fi

# 2. 논문 제목을 기반으로 안전한 디렉터리 이름 생성 (공백 -> _, 특수문자 제거)
CLEAN_TITLE=$(echo "$PAPER_TITLE" | tr ' ' '_' | tr -cd '[:alnum:]_-')
TARGET_DIR="${CLEAN_TITLE}_${ARXIV_ID}"

echo "==> arXiv ID: ${ARXIV_ID}"
echo "==> 작업 디렉터리: ${TARGET_DIR}"

# 3. 디렉터리 생성 및 이동
mkdir -p "${TARGET_DIR}"
cd "${TARGET_DIR}"

TEMP_TAR="source_temp.tar.gz"

echo "==> 소스 다운로드 중..."
curl -sSL "https://arxiv.org/e-print/${ARXIV_ID}" -o "${TEMP_TAR}"

echo "==> 압축 해제 중..."
FILE_TYPE=$(file "${TEMP_TAR}")

if echo "$FILE_TYPE" | grep -q "gzip compressed"; then
    if tar -xzf "${TEMP_TAR}" 2>/dev/null; then
        echo "==> tar.gz 압축 해제 완료."
    else
        gunzip -c "${TEMP_TAR}" > "main.tex"
        echo "==> 단일 TeX 파일 감지 (main.tex로 저장 완료)."
    fi
elif echo "$FILE_TYPE" | grep -q "PDF document"; then
    echo "[경고] 소스 파일이 제공되지 않는 논문이거나 다운로드에 실패했습니다 (PDF 수신)."
    mv "${TEMP_TAR}" "${ARXIV_ID}.pdf"
    exit 1
else
    if tar -xf "${TEMP_TAR}" 2>/dev/null; then
        echo "==> tar 압축 해제 완료."
    else
        echo "[오류] 지원되지 않는 아카이브 형식이거나 파일이 손상되었습니다."
        rm -f "${TEMP_TAR}"
        exit 1
    fi
fi

# 임시 파일 정리
rm -f "${TEMP_TAR}"

echo "==> 완료! 저장 위치: $(pwd)"