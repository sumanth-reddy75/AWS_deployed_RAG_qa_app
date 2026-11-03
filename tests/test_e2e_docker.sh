#!/bin/bash
# ==================================================
# RAG Q&A System - End-to-End Docker Test Script (OpenAI)
# ==================================================
# Usage (run from WSL inside the project directory):
#   chmod +x tests/test_e2e_docker.sh
#   ./tests/test_e2e_docker.sh
# ==================================================

set -e

BASE_URL="http://localhost:8000"
PASS=0
FAIL=0
TOTAL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_test() {
    TOTAL=$((TOTAL + 1))
    echo -e "\n${YELLOW}[TEST $TOTAL] $1${NC}"
}

print_pass() {
    PASS=$((PASS + 1))
    echo -e "${GREEN}  ✓ PASSED: $1${NC}"
}

print_fail() {
    FAIL=$((FAIL + 1))
    echo -e "${RED}  ✗ FAILED: $1${NC}"
}

# ============================================
# PHASE 1: Build & Start Docker Containers
# ============================================
print_header "PHASE 1: Build & Start Containers"

print_test "Build Docker image"
docker compose build --no-cache 2>&1 | tail -5
if [ $? -eq 0 ]; then
    print_pass "Docker image built successfully"
else
    print_fail "Docker build failed"
    exit 1
fi

print_test "Start container (docker compose up)"
docker compose down 2>/dev/null || true
docker compose up -d 2>&1
if [ $? -eq 0 ]; then
    print_pass "Container started"
else
    print_fail "Failed to start container"
    exit 1
fi

print_test "Wait for service to be healthy"
echo "  Waiting for RAG app..."
for i in $(seq 1 60); do
    if curl -sf ${BASE_URL}/health > /dev/null 2>&1; then
        print_pass "RAG app is healthy"
        break
    fi
    if [ $i -eq 60 ]; then
        print_fail "RAG app did not start within 60s"
        echo "  --- Container Logs ---"
        docker compose logs rag-app | tail -30
        exit 1
    fi
    sleep 1
done

# ============================================
# PHASE 2: Test API Endpoints
# ============================================
print_header "PHASE 2: API Endpoint Tests"

# --- Test 1: Root endpoint ---
print_test "GET / (Root endpoint)"
RESPONSE=$(curl -s -w "\n%{http_code}" ${BASE_URL}/)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
if [ "$HTTP_CODE" -eq 200 ]; then
    print_pass "Root endpoint returned 200"
    echo "  Response: $BODY"
else
    print_fail "Root endpoint returned $HTTP_CODE"
    echo "  Response: $BODY"
fi

# --- Test 2: Health check ---
print_test "GET /health (Basic health check)"
RESPONSE=$(curl -s -w "\n%{http_code}" ${BASE_URL}/health)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
if [ "$HTTP_CODE" -eq 200 ] && echo "$BODY" | grep -q "healthy"; then
    print_pass "Health check passed"
    echo "  Response: $BODY"
else
    print_fail "Health check failed (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
fi

# --- Test 3: Readiness check (Qdrant Cloud + Embeddings) ---
print_test "GET /health/ready (Readiness - Qdrant & Cloud connection)"
RESPONSE=$(curl -s -w "\n%{http_code}" ${BASE_URL}/health/ready)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
if [ "$HTTP_CODE" -eq 200 ] && echo "$BODY" | grep -q "ready"; then
    print_pass "Readiness check passed - Cloud connection OK"
    echo "  Response: $BODY"
else
    print_fail "Readiness check failed (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
fi

# --- Test 4: OpenAPI docs ---
print_test "GET /docs (Swagger UI)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${BASE_URL}/docs)
if [ "$HTTP_CODE" -eq 200 ]; then
    print_pass "Swagger docs accessible"
else
    print_fail "Swagger docs returned $HTTP_CODE"
fi

# ============================================
# PHASE 3: Document Upload & Query E2E Test
# ============================================
print_header "PHASE 3: Document Upload & RAG Query Test"

print_test "Create and upload a test document"
TEST_FILE="/tmp/test_rag_document.txt"
cat > "$TEST_FILE" << 'EOF'
Artificial Intelligence and Machine Learning Overview

Machine learning is a subset of artificial intelligence that enables systems to learn
and improve from experience without being explicitly programmed. Deep learning is a
subset of machine learning that uses neural networks with multiple layers.

Retrieval-Augmented Generation (RAG) is a technique that combines information retrieval
with text generation. It retrieves relevant documents from a knowledge base and uses
them as context for generating accurate answers.
EOF

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/documents/upload" \
    -F "file=@${TEST_FILE}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
if [ "$HTTP_CODE" -eq 200 ]; then
    print_pass "Document uploaded successfully"
    echo "  Response: $BODY"
else
    print_fail "Document upload failed (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
fi

sleep 2

# --- Test: RAG Query ---
print_test "POST /query (RAG query - tests OpenAI LLM + Embeddings + Qdrant Cloud)"
RESPONSE=$(curl -s -w "\n%{http_code}" \
    --max-time 60 \
    -X POST "${BASE_URL}/query" \
    -H "Content-Type: application/json" \
    -d '{"question": "What is RAG?", "include_sources": true}')
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
if [ "$HTTP_CODE" -eq 200 ]; then
    print_pass "RAG query returned successfully!"
    echo "  Response: $BODY"
else
    print_fail "RAG query failed (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
fi

# Cleanup
rm -f "$TEST_FILE"

# ============================================
# RESULTS SUMMARY
# ============================================
print_header "TEST RESULTS SUMMARY"
echo ""
echo -e "  Total Tests: ${TOTAL}"
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
else
    echo -e "${RED}⚠ $FAIL TEST(S) FAILED${NC}"
fi
