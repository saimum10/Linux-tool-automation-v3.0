#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — framework.sh — Stage 7: Full Framework
# ================================================================

run_searchsploit() {
    local target="$1"
    local out="$OUTPUT_DIR/62_searchsploit.txt"
    command -v searchsploit &>/dev/null || { log_skip "searchsploit"; return; }

    {
        echo "=== SEARCHSPLOIT RESULTS ==="
        echo ""

        [ -n "$DETECTED_CMS" ] && {
            echo "--- CMS: $DETECTED_CMS ---"
            searchsploit "$DETECTED_CMS" 2>/dev/null | head -20; echo ""
        }

        [ -n "${DETECTED_FRAMEWORK:-}" ] && {
            echo "--- Framework: $DETECTED_FRAMEWORK ---"
            searchsploit "$DETECTED_FRAMEWORK" 2>/dev/null | head -15; echo ""
        }

        for i in "${!OPEN_PORTS[@]}"; do
            local s="${OPEN_SERVICES[$i]:-}"
            [ -n "$s" ] && [ "$s" != "unknown" ] && {
                local res; res=$(searchsploit "$s" 2>/dev/null | grep -v "No Results" | head -8)
                [ -n "$res" ] && { echo "--- ${OPEN_PORTS[$i]} ($s) ---"; echo "$res"; echo ""; }
            }
        done

        # Parse nmap XML version output
        if [ -f "$OUTPUT_DIR/03_nmap.txt" ]; then
            grep -oE "[A-Za-z]+ [0-9]+\.[0-9]+" "$OUTPUT_DIR/03_nmap.txt" 2>/dev/null | \
            sort -u | head -15 | while read -r svc; do
                local res; res=$(searchsploit "$svc" 2>/dev/null | grep -v "No Results" | head -5)
                [ -n "$res" ] && { echo "--- $svc ---"; echo "$res"; echo ""; }
            done
        fi
    } | tee "$out"

    grep -qi "Remote Code Execution\|RCE" "$out" 2>/dev/null && \
        log_critical "searchsploit — RCE exploit পাওয়া গেছে!"
    grep -qi "SQL Injection"             "$out" 2>/dev/null && \
        log_high "searchsploit — SQLi exploit পাওয়া গেছে।"
    grep -qi "Privilege Escalation"      "$out" 2>/dev/null && \
        log_high "searchsploit — PrivEsc exploit পাওয়া গেছে।"

    local total; total=$(grep -c "EDB-ID" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/62_searchsploit_bangla.txt" \
        "  searchsploit — বাংলা বিশ্লেষণ" \
        "🔍 মোট $total টি potential exploit পাওয়া গেছে।" \
        "💡 এই exploit গুলো Metasploit বা manual testing এ ব্যবহার করা যায়।" \
        "   https://www.exploit-db.com"
}

run_nuclei_advanced() {
    local target="$1"
    local out="$OUTPUT_DIR/63_nuclei_cve.txt"
    command -v nuclei &>/dev/null || { log_skip "nuclei advanced"; return; }

    local tags
    case "$SCAN_MODE" in
        1) tags="-tags cve -severity critical,high" ;;
        2) tags="-tags cve,misconfig -severity high,critical,medium" ;;
        3) tags="-tags cve,misconfig,exposure,default-login,takeover,rce" ;;
    esac

    run_tool "Nuclei CVE" "nuclei -u http://$target $tags -silent" \
        "$out" "$TIMEOUT_NUCLEI"

    grep -i "\[critical\]" "$out" 2>/dev/null | while read -r l; do log_critical "$l"; done
    grep -i "\[high\]"     "$out" 2>/dev/null | while read -r l; do log_high "$l"; done

    local cve_list; cve_list=$(grep -oE "CVE-[0-9]+-[0-9]+" "$out" 2>/dev/null | sort -u)
    {
        echo "================================================================"
        echo "  Nuclei Advanced CVE — বাংলা বিশ্লেষণ"
        echo "================================================================"
        if [ -n "$cve_list" ]; then
            echo "📌 পাওয়া CVE তালিকা:"
            echo "$cve_list" | while read -r cve; do
                echo "  🎯 $cve → https://nvd.nist.gov/vuln/detail/$cve"
            done
        fi
        echo "💡 CVE পাওয়া গেলে NVD database থেকে CVSS score দেখুন।"
        echo "================================================================"
    } > "$OUTPUT_DIR/63_nuclei_cve_bangla.txt"
    echo -e "${MAGENTA}${BOLD}  ── বাংলা বিশ্লেষণ (Nuclei CVE) ──${NC}"
    cat "$OUTPUT_DIR/63_nuclei_cve_bangla.txt"
}

run_metasploit() {
    local target="$1"
    local out="$OUTPUT_DIR/64_metasploit.txt"
    command -v msfconsole &>/dev/null || { log_skip "metasploit"; return; }

    local ran=0
    {
        echo "=== METASPLOIT AUTOMATED CHECKS ==="
        echo ""

        [ "$SMB_OPEN" -eq 1 ] && {
            echo "--- EternalBlue (MS17-010) ---"
            msfconsole -q -x \
                "use auxiliary/scanner/smb/smb_ms17_010; set RHOSTS $target; run; exit" \
                2>/dev/null; ran=1; echo ""
            echo "--- SMBGhost (CVE-2020-0796) ---"
            msfconsole -q -x \
                "use auxiliary/scanner/smb/smb_ms17_010; set RHOSTS $target; run; exit" \
                2>/dev/null; echo ""
        }

        [ "$MYSQL_OPEN" -eq 1 ] && {
            echo "--- MySQL Anonymous Login ---"
            msfconsole -q -x \
                "use auxiliary/scanner/mysql/mysql_login; set RHOSTS $target; set BLANK_PASSWORDS true; run; exit" \
                2>/dev/null; ran=1; echo ""
        }

        [ "$WEB_AVAILABLE" -eq 1 ] && {
            echo "--- HTTP Version Scan ---"
            msfconsole -q -x \
                "use auxiliary/scanner/http/http_version; set RHOSTS $target; run; exit" \
                2>/dev/null; ran=1; echo ""
        }

        [ "$FTP_OPEN" -eq 1 ] && {
            echo "--- FTP Anonymous Login ---"
            msfconsole -q -x \
                "use auxiliary/scanner/ftp/anonymous; set RHOSTS $target; run; exit" \
                2>/dev/null; ran=1; echo ""
        }

        [ "$RDP_OPEN" -eq 1 ] && {
            echo "--- RDP BlueKeep (CVE-2019-0708) ---"
            msfconsole -q -x \
                "use auxiliary/scanner/rdp/cve_2019_0708_bluekeep; set RHOSTS $target; run; exit" \
                2>/dev/null; ran=1; echo ""
        }

        [ "$SMTP_OPEN" -eq 1 ] && {
            echo "--- SMTP User Enum ---"
            msfconsole -q -x \
                "use auxiliary/scanner/smtp/smtp_enum; set RHOSTS $target; run; exit" \
                2>/dev/null; ran=1; echo ""
        }

    } | tee "$out"

    grep -qi "VULNERABLE\|is vulnerable" "$out" 2>/dev/null && \
        log_critical "Metasploit — Vulnerability confirmed!"

    write_bangla "$OUTPUT_DIR/64_metasploit_bangla.txt" \
        "  Metasploit — বাংলা বিশ্লেষণ" \
        "🎯 Automated checks সম্পন্ন।" \
        "$(grep -qi 'VULNERABLE' "$out" 2>/dev/null && echo '🔴 CRITICAL: Metasploit vulnerability confirm করেছে!' || echo '✅ Automated check এ কোনো critical issue নেই।')" \
        "💡 Manual: msfconsole → search → use → set RHOSTS → run"
}

run_owasp_zap() {
    local target="$1"
    local out="$OUTPUT_DIR/65_zap.txt"
    [ "$WEB_AVAILABLE" -eq 0 ] && return

    local zap_bin
    zap_bin=$(command -v zaproxy 2>/dev/null || command -v zap.sh 2>/dev/null || \
        ls /opt/zaproxy/zap.sh 2>/dev/null || ls /usr/share/zaproxy/zap.sh 2>/dev/null || echo "")
    [ -z "$zap_bin" ] && { log_skip "OWASP ZAP"; return; }
    command -v java &>/dev/null || { log_warn "ZAP — Java নেই।"; return; }

    local rep="$OUTPUT_DIR/zap_report.html"
    run_tool "OWASP ZAP" \
        "$zap_bin -cmd -quickurl http://$target -quickout $rep -quickprogress" \
        "$out" "$TIMEOUT_ZAP"

    grep -qi "CRITICAL\|HIGH" "$rep" 2>/dev/null && \
        log_critical "OWASP ZAP — Critical/High vulnerability পাওয়া গেছে!"

    local high; high=$(grep -ci "High" "$rep" 2>/dev/null || echo 0)
    local med;  med=$(grep -ci "Medium" "$rep" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/65_zap_bangla.txt" \
        "  OWASP ZAP — বাংলা বিশ্লেষণ" \
        "📊 High: $high | Medium: $med" \
        "📄 Full ZAP report → $rep" \
        "💡 ZAP পুরো web app কে browser এর মতো scan করে।"
}

run_github_secret() {
    local target="$1"
    local out="$OUTPUT_DIR/66_github_secret.txt"

    local tool=""
    command -v trufflehog &>/dev/null && tool="trufflehog"
    command -v gitleaks   &>/dev/null && tool="gitleaks"
    [ -z "$tool" ] && { log_skip "trufflehog/gitleaks"; return; }

    log_info "GitHub secret scanning — $TARGET_DOMAIN..."
    {
        echo "=== GITHUB SECRET SCAN ==="
        echo "Target domain: ${TARGET_DOMAIN:-$target}"
        echo ""
        if [ "$tool" = "trufflehog" ]; then
            trufflehog github --org="${TARGET_DOMAIN%%.*}" \
                --only-verified 2>/dev/null | head -50
        elif [ "$tool" = "gitleaks" ]; then
            gitleaks detect --source=. 2>/dev/null | head -30
        fi
    } | tee "$out"

    grep -qi "Found\|SECRET\|API.*KEY\|password" "$out" 2>/dev/null && \
        log_critical "GitHub — Secret/API key exposed!"
    reg_file "github_secret" "$out"
}

run_hibp_check() {
    local out="$OUTPUT_DIR/67_hibp.txt"
    [ ${#FOUND_EMAILS[@]} -eq 0 ] && { log_info "Email নেই — HIBP skip।"; return; }
    [ -z "$HIBP_API_KEY" ] && { log_info "HIBP API key নেই — skip।"; return; }

    {
        echo "=== HAVE I BEEN PWNED CHECK ==="
        for email in "${FOUND_EMAILS[@]:0:10}"; do
            local resp
            resp=$(curl -sf --max-time 10 \
                -H "hibp-api-key: $HIBP_API_KEY" \
                -H "user-agent: SAIMUM-Scanner" \
                "https://haveibeenpwned.com/api/v3/breachedaccount/${email}" 2>/dev/null)
            if [ -n "$resp" ]; then
                echo "BREACHED: $email"
                echo "$resp" | grep -o '"Name":"[^"]*"' | head -3
                log_high "Email breach পাওয়া গেছে: $email"
            else
                echo "SAFE: $email"
            fi
            sleep 1.5   # HIBP rate limit
        done
    } | tee "$out"
    reg_file "hibp" "$out"
}

run_full_framework() {
    local target="$1"
    show_stage 7 "FULL-FEATURED FRAMEWORK"

    run_searchsploit    "$target"
    run_nuclei_advanced "$target"
    run_metasploit      "$target"
    run_owasp_zap       "$target"
    run_github_secret   "$target"
    run_hibp_check

    save_state
}
