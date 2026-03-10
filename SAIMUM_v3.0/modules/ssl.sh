#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — ssl.sh — Stage 8: SSL/TLS Testing
# ================================================================

run_sslscan() {
    local target="$1"
    local out="$OUTPUT_DIR/68_sslscan.txt"
    command -v sslscan &>/dev/null || { log_skip "sslscan"; return; }

    run_tool "sslscan" \
        "sslscan --no-colour --show-ciphers --show-certificate $target" \
        "$out" 120

    grep -qi "SSLv2\|SSLv3\|TLSv1\.0\b"         "$out" 2>/dev/null && log_high "Deprecated SSL/TLS version!"
    grep -qi "POODLE\|BEAST\|HEARTBLEED\|ROBOT"  "$out" 2>/dev/null && log_critical "SSL Attack vulnerability!"
    grep -qi "expired\|self.signed"               "$out" 2>/dev/null && log_medium "SSL Certificate issue।"

    {
        echo "================================================================"
        echo "  sslscan — বাংলা বিশ্লেষণ"
        echo "================================================================"
        grep -qi "SSLv2"       "$out" 2>/dev/null && echo "🔴 SSLv2 চালু — অবিলম্বে বন্ধ করুন!"
        grep -qi "SSLv3"       "$out" 2>/dev/null && echo "🔴 SSLv3 — POODLE attack সম্ভব!"
        grep -qi "TLSv1\.0\b"  "$out" 2>/dev/null && echo "🟠 TLS 1.0 — BEAST attack সম্ভব।"
        grep -qi "TLSv1\.1"    "$out" 2>/dev/null && echo "🟡 TLS 1.1 deprecated।"
        grep -qi "expired"     "$out" 2>/dev/null && echo "🟠 Certificate মেয়াদ শেষ!"
        grep -qi "self.signed" "$out" 2>/dev/null && echo "🟡 Self-signed certificate।"
        echo ""
        echo "✅ শুধু TLS 1.2 ও TLS 1.3 চালু রাখুন।"
        echo "================================================================"
    } > "$OUTPUT_DIR/68_sslscan_bangla.txt"
    echo -e "${MAGENTA}${BOLD}  ── বাংলা বিশ্লেষণ (sslscan) ──${NC}"
    cat "$OUTPUT_DIR/68_sslscan_bangla.txt"
}

run_testssl() {
    local target="$1"
    local out="$OUTPUT_DIR/69_testssl.txt"
    local bin
    bin=$(command -v testssl.sh 2>/dev/null || command -v testssl 2>/dev/null || echo "")
    [ -z "$bin" ] && { log_skip "testssl.sh"; return; }

    local flags="--sneaky"
    [ "$SCAN_MODE" -eq 2 ] && flags="--sneaky --heartbleed --robot"
    [ "$SCAN_MODE" -eq 3 ] && flags="--full --parallel --json $OUTPUT_DIR/testssl.json"

    run_tool "testssl.sh" "$bin $flags $target:443" "$out" 300

    grep -qi "CRITICAL\|HIGH.*VULNERABLE" "$out" 2>/dev/null && \
        log_critical "testssl.sh — Critical SSL vulnerability!"

    {
        echo "================================================================"
        echo "  testssl.sh — বাংলা বিশ্লেষণ"
        echo "================================================================"
        grep -i "CRITICAL" "$out" 2>/dev/null | head -5 | while read -r l; do echo "  🔴 $l"; done
        grep -i "HIGH"     "$out" 2>/dev/null | head -5 | while read -r l; do echo "  🟠 $l"; done
        grep -i "MEDIUM"   "$out" 2>/dev/null | head -5 | while read -r l; do echo "  🟡 $l"; done
        echo ""
        echo "💡 testssl.sh HEARTBLEED, POODLE, BEAST, ROBOT সব check করে।"
        echo "================================================================"
    } > "$OUTPUT_DIR/69_testssl_bangla.txt"
    echo -e "${MAGENTA}${BOLD}  ── বাংলা বিশ্লেষণ (testssl.sh) ──${NC}"
    cat "$OUTPUT_DIR/69_testssl_bangla.txt"
}

run_sslyze() {
    local target="$1"
    local out="$OUTPUT_DIR/70_sslyze.txt"
    command -v sslyze &>/dev/null || { log_skip "sslyze"; return; }

    run_tool "sslyze" \
        "sslyze $target:443 --regular --certinfo --compression --reneg" \
        "$out" 120

    grep -qi "VULNERABLE\|ERROR" "$out" 2>/dev/null && \
        log_high "sslyze — SSL issue পাওয়া গেছে।"

    write_bangla "$OUTPUT_DIR/70_sslyze_bangla.txt" \
        "  sslyze — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'VULNERABLE' "$out" 2>/dev/null && echo '🟠 SSL vulnerability পাওয়া গেছে!' || echo '✅ sslyze তে কোনো critical issue নেই।')" \
        "💡 sslscan + testssl.sh + sslyze — তিনটি মিলে সম্পূর্ণ SSL coverage।"
}

run_openssl_ciphers() {
    local target="$1"
    local out="$OUTPUT_DIR/71_openssl_ciphers.txt"
    command -v openssl &>/dev/null || return
    [ "$SSL_AVAILABLE" -eq 0 ] && return
    [ "$SCAN_MODE" -lt 2 ] && return

    log_info "OpenSSL cipher enumeration করা হচ্ছে..."
    {
        echo "=== OPENSSL CIPHER ENUMERATION ==="
        for cipher in $(openssl ciphers 'ALL:eNULL' 2>/dev/null | tr ':' ' '); do
            result=$(echo Q | timeout 5 openssl s_client \
                -cipher "$cipher" -connect "$target:443" \
                -servername "$target" 2>/dev/null)
            echo "$result" | grep -q "Cipher is" && \
                echo "[ACCEPTED] $cipher" || echo "[REJECTED] $cipher"
        done 2>/dev/null | grep "ACCEPTED"

        echo ""
        echo "=== OCSP STAPLING ==="
        echo Q | openssl s_client -connect "$target:443" \
            -servername "$target" -status 2>/dev/null | \
            grep -i "OCSP"

        echo ""
        echo "=== MIXED CONTENT CHECK ==="
        curl -sf --max-time 10 "https://$target/" 2>/dev/null | \
            grep -Ei "src=.http://" | head -5
    } | tee "$out"

    grep -i "ACCEPTED" "$out" 2>/dev/null | grep -iE "NULL|EXPORT|RC4|DES\b|MD5" && \
        log_high "Weak cipher accepted: NULL/EXPORT/RC4/DES!"
    reg_file "openssl_ciphers" "$out"
}

run_ssl_testing() {
    local target="$1"
    if [ "$SSL_AVAILABLE" -eq 0 ]; then
        log_info "HTTPS/SSL port নেই — Stage 8 skip।"
        return
    fi

    show_stage 8 "SSL/TLS TESTING"

    run_sslscan        "$target"
    run_testssl        "$target"
    run_sslyze         "$target"
    run_openssl_ciphers "$target"

    save_state
}
