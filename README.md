<div align="center">

<pre>
  ███████╗ █████╗ ██╗███╗   ███╗██╗   ██╗███╗   ███╗
  ╚════██╗ ╚═══██╗██║████╗ ████║██║   ██║████╗ ████║
      ██╔╝ ███████║██║██╔████╔██║██║   ██║██╔████╔██║
     ██╔╝  ██╔══██║██║██║╚██╔╝██║██║   ██║██║╚██╔╝██║
    ███████╗╚█████╔╝██║██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║
    ╚══════╝ ╚════╝ ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝
</pre>

# SAIMUM v3.0 — Web Vulnerability Automation Pipeline

**একটি সম্পূর্ণ Bash-based automated web penetration testing framework**

[![Version](https://img.shields.io/badge/Version-3.0-red?style=for-the-badge)](https://github.com)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Kali%20Linux-557C94?style=for-the-badge&logo=kali-linux&logoColor=white)](https://www.kali.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Tools](https://img.shields.io/badge/Tools-78+-orange?style=for-the-badge)](#tools)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)](LICENSE)

</div>

---

## 📸 Preview

```
  ╔══════════════════════════════════════════════════════════════════════╗
  ║              SAIMUM v3.0 — Web Vulnerability Pipeline               ║
  ╠══════════════════════════════════════════════════════════════════════╣
  ║  Target  : target.com                                               ║
  ║  Mode    : Normal  |  Stages: All  |  Proxy: None                   ║
  ╚══════════════════════════════════════════════════════════════════════╝

  STAGE 1/9: RECONNAISSANCE                              [████████░░░░] 33%
  ──────────────────────────────────────────────────────────────────────
  [✓] WHOIS                  Domain info collected
  [✓] NMAP                   32 open ports found
  [✓] subfinder              47 subdomains discovered
  [✓] Amass                  12 additional subdomains
  [✓] crt.sh                 59 certificate entries
  [✓] theHarvester           8 emails, 3 hostnames
  [✓] httpx                  23 live hosts verified
  [✓] gowitness              Screenshots captured
  [✓] WAF Detection          Cloudflare detected
  ── বাংলা বিশ্লেষণ ──
  ✅ Recon সম্পন্ন। ৪৭টি subdomain, ৩২টি port, WAF: Cloudflare

  STAGE 5/9: INJECTION TESTING                          [████████████░] 55%
  ──────────────────────────────────────────────────────────────────────
  [✓] sqlmap                 ⚠ SQL Injection FOUND!
  [✓] Dalfox                 ⚠ XSS Vulnerability FOUND!
  [✓] XSStrike               3 XSS payloads confirmed
  [CRITICAL] SQL Injection — parameter: id
  [HIGH]     Reflected XSS  — parameter: search
  ── বাংলা বিশ্লেষণ ──
  🔴 CRITICAL: SQL Injection পাওয়া গেছে! তাৎক্ষণিক ব্যবস্থা নিন।

  ╔══════════════════════════════════════════════════════════════════════╗
  ║  🏁 SCAN COMPLETE — target.com                                      ║
  ║  Duration: 1h 23m  |  🔴 Critical: 2  🟠 High: 5  🟡 Medium: 8    ║
  ║  📄 TXT  HTML  PDF  JSON  XML  reports generated                    ║
  ╚══════════════════════════════════════════════════════════════════════╝
```

---

## 🎯 What It Does

SAIMUM v3.0 একটি **9-stage automated web vulnerability assessment pipeline** যা একটি target domain বা IP address দিলে reconnaissance থেকে শুরু করে professional report তৈরি পর্যন্ত সব কাজ স্বয়ংক্রিয়ভাবে করে।

### মূল সক্ষমতা

| ক্যাটাগরি | বিবরণ |
|-----------|-------|
| 🔍 **Reconnaissance** | Subdomain enumeration, port scanning, WAF/CDN detection, screenshot capture |
| 🌐 **Web Analysis** | Header security audit, SSL/TLS analysis, technology fingerprinting |
| 🕷️ **Vulnerability Scan** | CMS scanning (WordPress, Joomla, Drupal), nuclei CVE check, CORS |
| 📂 **Content Discovery** | Directory brute force, parameter fuzzing, virtual host discovery |
| 💉 **Injection Testing** | SQLi, XSS (reflected/stored/blind), SSRF, XXE, SSTI, Command Injection |
| 🔐 **Auth Testing** | Brute force (10 protocols), hash cracking, default credentials, password spray |
| 🔧 **Exploit Matching** | SearchSploit, Metasploit integration, nuclei CVE templates |
| 📊 **Reporting** | TXT + HTML + PDF + JSON + XML, বাংলা বিশ্লেষণ, severity scoring |

---

## 🗂️ Project Structure

```
saimum/
├── main_saimum.sh              ← Entry point / Main menu
├── Dockerfile                  ← Docker environment
├── config/
│   └── .saimum.conf.example    ← Configuration template
└── modules/
    ├── utils.sh                ← Core engine, logging, state, menus
    ├── recon.sh                ← Stage 1: Reconnaissance (24 tool calls)
    ├── headers.sh              ← Stage 2: Headers & Fingerprint
    ├── webscanning.sh          ← Stage 3: Web Scanning (9 tool calls)
    ├── directory.sh            ← Stage 4: Directory Discovery (13 tool calls)
    ├── injection.sh            ← Stage 5: Injection Testing (9 tool calls)
    ├── auth.sh                 ← Stage 6: Auth & Password (16 tool calls)
    ├── framework.sh            ← Stage 7: Framework & Exploits
    ├── ssl.sh                  ← Stage 8: SSL/TLS Testing
    └── report.sh               ← Stage 9: Report Generation
```

---

## ⚙️ Pipeline — ৯টি Stage

### Stage 1 — Reconnaissance
<details>
<summary>বিস্তারিত দেখুন</summary>

| Tool | কাজ |
|------|-----|
| `whois` | Domain registration, registrar, expiry |
| `nmap` | Full port scan, OS detection, service version |
| `nmap --script` | SMB, SMTP, RDP, SNMP, FTP-anon script scan |
| `masscan` | High-speed TCP port scan |
| `traceroute` | Network path mapping |
| `dnsrecon` | DNS record enum, zone transfer attempt |
| `subfinder` | Passive subdomain enumeration (100+ sources) |
| `amass` | Active + passive subdomain enumeration |
| `crt.sh` | Certificate transparency log search |
| `theHarvester` | Email, subdomain, IP, social harvest |
| `waybackurls` | Wayback Machine URL extraction |
| `gau` | Google, AlienVault URL harvest |
| `httpx` | Live host detection, title, status, tech |
| `whatweb` | Technology fingerprinting |
| `wafw00f` | WAF detection (Cloudflare, Akamai, F5...) |
| `tshark` | Passive network traffic analysis |
| `gowitness` | Subdomain screenshot capture |
| HIBP API | Email breach check |
| Shodan API | External threat intelligence (optional) |

</details>

### Stage 2 — Headers & Fingerprint
<details>
<summary>বিস্তারিত দেখুন</summary>

- HTTP/HTTPS response header collection
- Security header audit: `Content-Security-Policy`, `HSTS`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`
- Cookie flag check: `HttpOnly`, `Secure`, `SameSite`
- Server/technology disclosure detection
- `robots.txt` ও `sitemap.xml` analysis

</details>

### Stage 3 — Web Scanning
<details>
<summary>বিস্তারিত দেখুন</summary>

| Tool | কাজ |
|------|-----|
| `nikto` | Web server misconfiguration, known vulnerabilities |
| `nuclei` | Template-based vulnerability scan |
| `nuclei -t takeovers` | Subdomain takeover check |
| `wpscan` | WordPress plugin/theme/user enumeration |
| `droopescan` | Drupal/Joomla vulnerability scan |
| `corscanner` | CORS misconfiguration check |
| `paramspider` | URL parameter discovery from web archives |
| `arjun` | Hidden HTTP parameter discovery |
| OWASP ZAP | Dynamic application security testing |

</details>

### Stage 4 — Directory Discovery
<details>
<summary>বিস্তারিত দেখুন</summary>

| Tool | Mode |
|------|------|
| `gobuster` | DIR, DNS, VHOST |
| `ffuf` | DIR, GET params, POST, VHOST, Header fuzzing |
| `wfuzz` | DIR, POST data, Cookie fuzzing |
| `dirb` | Classic directory brute force |
| `feroxbuster` | Recursive content discovery |

</details>

### Stage 5 — Injection Testing
<details>
<summary>বিস্তারিত দেখুন</summary>

| Attack | Tool |
|--------|------|
| SQL Injection | `sqlmap` (URL, Forms, Wayback URLs) |
| XSS (Reflected/Stored) | `dalfox pipe`, `dalfox url`, `xsstrike` |
| XSS (Blind) | `dalfox --blind` |
| Command Injection | `commix` |
| JWT Attacks | `jwt_tool` (alg:none, RS→HS, brute) |
| SSRF | Manual payload injection |
| XXE | XML external entity payloads |
| SSTI | Template injection detection |
| Open Redirect | Header-based detection |

</details>

### Stage 6 — Authentication Testing
<details>
<summary>বিস্তারিত দেখুন</summary>

**Hydra — 10 protocols:**
`SSH` · `FTP` · `HTTP/HTTPS` · `RDP` · `Telnet` · `MySQL` · `SMTP` · `SMB` · `VNC` · `PostgreSQL`

**Password Cracking:**
- `john` — Dictionary attack (all formats)
- `hashcat` — Dictionary + Mask + Hybrid attack (GPU-accelerated)

**Other:**
- `medusa` — Multi-protocol parallel brute force
- Default/vendor credential check
- Rate-limited password spray

</details>

### Stage 7 — Framework & Exploits
<details>
<summary>বিস্তারিত দেখুন</summary>

- `searchsploit` — Detected version এর CVE খুঁজে
- `nuclei -t cves` — CVE template scan
- `metasploit` — Auxiliary module integration
- OWASP ZAP — Active scan

</details>

### Stage 8 — SSL/TLS Testing
<details>
<summary>বিস্তারিত দেখুন</summary>

- `sslscan` — Cipher suite, protocol version, certificate
- `testssl.sh` — Comprehensive TLS/SSL audit (BEAST, POODLE, Heartbleed...)
- `sslyze` — Python-based TLS analysis
- `openssl` — Manual certificate inspection

</details>

### Stage 9 — Reporting
<details>
<summary>বিস্তারিত দেখুন</summary>

- **TXT** — Plain text summary + বাংলা বিশ্লেষণ
- **HTML** — Dark-theme professional report, screenshot embed, severity badges
- **PDF** — Print-ready professional report (`wkhtmltopdf`)
- **JSON** — Machine-readable structured output
- **XML** — Integration-ready format
- **Comparison** — Multi-scan comparison report
- **SQLite** — Scan history database

</details>

---

## 🛠️ Installation

### Prerequisites

```bash
# Kali Linux recommended
# Go 1.21+ required for Go-based tools

sudo apt-get update
sudo apt-get install -y git golang python3 python3-pip
```

### Clone & Setup

```bash
git clone https://github.com/saimumhabib/saimum.git
cd saimum
chmod +x main_saimum.sh modules/*.sh
```

### Docker (Recommended)

```bash
# Build
docker build -t saimum:v3 .

# Run
docker run -it --rm \
  -v $(pwd)/results:/saimum/results \
  saimum:v3
```

### Manual Tool Installation

```bash
# Go-based tools
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/ffuf/ffuf/v2@latest
go install github.com/hahwul/dalfox/v2@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/sensepost/gowitness@latest

# Python tools
pip3 install --break-system-packages paramspider arjun corscanner droopescan

# APT tools
sudo apt-get install -y nmap masscan nikto sqlmap hydra medusa \
  john hashcat wpscan gobuster feroxbuster wfuzz dirb \
  sslscan testssl.sh sslyze dnsrecon whatweb wafw00f \
  wkhtmltopdf amass

# Nuclei templates
nuclei -update-templates
```

---

## 🚀 How to Use

### Basic Usage

```bash
./main_saimum.sh
```

Interactive menu আসবে — target, scan mode, stages সব select করা যাবে।

### Quick Scan (Non-interactive)

```bash
# Normal scan, all stages
./main_saimum.sh -t target.com

# Stealth mode
./main_saimum.sh -t target.com -m 1

# Aggressive mode, specific stages
./main_saimum.sh -t target.com -m 3 -s 1,3,5

# With proxy (Burp Suite)
./main_saimum.sh -t target.com -p http://127.0.0.1:8080

# With Tor
./main_saimum.sh -t target.com -p socks5://127.0.0.1:9050
```

### Scan Modes

| Mode | Flag | Speed | Stealth | Coverage | Best For |
|------|------|-------|---------|----------|----------|
| 🕵️ Stealth | `-m 1` | Slow | Maximum | Basic | Bug Bounty, Production |
| ⚖️ Normal | `-m 2` | Medium | Moderate | Full | Standard Pentest |
| 🔥 Aggressive | `-m 3` | Fast | Minimal | Maximum | Lab / CTF |

### Stage Selection

```bash
# শুধু Recon + Injection
./main_saimum.sh -t target.com -s 1,5

# Recon থেকে Web Scan পর্যন্ত
./main_saimum.sh -t target.com -s 1,2,3

# সব stage
./main_saimum.sh -t target.com -s all
```

### Pause & Resume

```bash
# চলতে থাকা scan pause করতে:
touch /tmp/.saimum_pause

# Resume করতে main_saimum.sh আবার চালু করুন
# "Resume last scan" option select করুন
./main_saimum.sh
```

---

## ⚙️ Configuration

```bash
cp config/.saimum.conf.example ~/.saimum.conf
nano ~/.saimum.conf
```

```bash
# ~/.saimum.conf — প্রধান সেটিংস

# Output directory
OUTPUT_BASE="$HOME/saimum_scans"

# Default scan mode: 1=Stealth, 2=Normal, 3=Aggressive
DEFAULT_SCAN_MODE=2

# Report format: 1=TXT, 2=TXT+HTML, 3=TXT+HTML+PDF
DEFAULT_REPORT_FORMAT=2

# Proxy (optional)
DEFAULT_PROXY=""              # e.g. socks5://127.0.0.1:9050

# API Keys (optional — কিছু feature এর জন্য দরকার)
SHODAN_API_KEY=""             # Shodan threat intelligence
HIBP_API_KEY=""               # HaveIBeenPwned breach check
WPSCAN_API_TOKEN=""           # WPScan vulnerability database
VIRUSTOTAL_API_KEY=""         # VirusTotal reputation

# Timeouts (seconds)
TIMEOUT_NMAP=300
TIMEOUT_NUCLEI=300
TIMEOUT_SQLMAP=300
TIMEOUT_HYDRA=180
TIMEOUT_ZAP=600

# Wordlists
WORDLIST_SMALL="/usr/share/wordlists/dirb/small.txt"
WORDLIST_MEDIUM="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
WORDLIST_DNS="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"

# Screenshot
GOWITNESS_ENABLED=1

# SQLite scan history
SQLITE_HISTORY=1
SQLITE_DB="$HOME/.saimum_history.db"
```

---

## 📊 Example Output

### Terminal Dashboard (Scan Complete)

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     🏁 SAIMUM v3.0 — SCAN COMPLETE
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    Target   : demo.testfire.net
    Duration : 1h 17m 42s

    Findings:
     🔴 Critical :  3
     🟠 High     :  7
     🟡 Medium   : 12
     🟢 Low      :  6
     🔵 Info     : 24

    Reports:
     📄 TXT  → ~/saimum_scans/demo.testfire.net_20240115/report.txt
     🌐 HTML → ~/saimum_scans/demo.testfire.net_20240115/report.html
     📑 PDF  → ~/saimum_scans/demo.testfire.net_20240115/report.pdf
     📋 JSON → ~/saimum_scans/demo.testfire.net_20240115/report.json
     📰 XML  → ~/saimum_scans/demo.testfire.net_20240115/report.xml

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### HTML Report Preview

```
┌─────────────────────────────────────────────────────┐
│  SAIMUM v3.0 Security Report          [CRITICAL: 3] │
│  Target: demo.testfire.net                          │
│  Date: 2024-01-15  |  Mode: Normal                  │
├─────────────────────────────────────────────────────┤
│  🔴 SQL Injection                      CRITICAL     │
│  Parameter: account  |  Tool: sqlmap                │
│  Evidence: SLEEP(5) — time-based confirmed          │
├─────────────────────────────────────────────────────┤
│  🔴 Reflected XSS                      CRITICAL     │
│  Parameter: search  |  Tool: dalfox                 │
│  POC: <script>alert(1)</script>                     │
├─────────────────────────────────────────────────────┤
│  🟠 Missing HSTS Header                HIGH         │
│  URL: https://demo.testfire.net/                    │
│  Fix: Strict-Transport-Security: max-age=31536000   │
└─────────────────────────────────────────────────────┘
```

### JSON Output Structure

```json
{
  "meta": {
    "target": "demo.testfire.net",
    "scan_date": "2024-01-15",
    "scan_mode": "Normal",
    "duration": "1h 17m 42s",
    "tool": "SAIMUM v3.0"
  },
  "summary": {
    "critical": 3,
    "high": 7,
    "medium": 12,
    "low": 6,
    "info": 24
  },
  "findings": [
    {
      "severity": "CRITICAL",
      "title": "SQL Injection",
      "parameter": "account",
      "tool": "sqlmap",
      "evidence": "time-based blind confirmed (SLEEP 5)",
      "remediation": "Use parameterized queries / prepared statements"
    }
  ]
}
```

### বাংলা বিশ্লেষণ (প্রতিটি stage শেষে)

```
── বাংলা বিশ্লেষণ ──
🔴 CRITICAL: SQL Injection পাওয়া গেছে! parameter 'account' vulnerable।
   তাৎক্ষণিক ব্যবস্থা নিন — Prepared Statement ব্যবহার করুন।
🟠 HIGH: XSS vulnerability 'search' parameter এ। Input sanitize করুন।
✅ SSL/TLS: Certificate valid, TLS 1.3 enabled।
ℹ️ ৪৭টি subdomain, ৩২টি open port, WAF: Cloudflare detected।
```

---

## 📁 Output Directory Structure

```
~/saimum_scans/
└── target.com_20240115_143022/
    ├── report.txt                  ← Main report + বাংলা analysis
    ├── report.html                 ← Dark theme HTML report
    ├── report.pdf                  ← Professional PDF
    ├── report.json                 ← Machine-readable JSON
    ├── report.xml                  ← XML format
    ├── screenshots/                ← gowitness subdomain screenshots
    │   ├── sub1.target.com.png
    │   └── sub2.target.com.png
    ├── 01_whois.txt
    ├── 02_nmap.txt
    ├── 05_subfinder.txt
    ├── 06_amass.txt
    ├── 40_sqlmap.txt
    ├── 41_dalfox.txt
    ├── 59_john.txt
    ├── 60_hashcat.txt
    └── [stage]_[tool]_bangla.txt   ← বাংলা per-tool analysis
```

---

## 🛡️ Tool Arsenal (78+)

<details>
<summary>সম্পূর্ণ tool list দেখুন</summary>

**Reconnaissance:** `nmap` `masscan` `whois` `dnsrecon` `subfinder` `amass` `theHarvester` `httpx` `waybackurls` `gau` `gowitness` `whatweb` `wafw00f` `tshark` `traceroute`

**Web Scanning:** `nikto` `nuclei` `wpscan` `droopescan` `corscanner` `arjun` `paramspider` `zaproxy`

**Directory Discovery:** `gobuster` `ffuf` `wfuzz` `dirb` `feroxbuster`

**Injection:** `sqlmap` `dalfox` `xsstrike` `commix` `jwt_tool`

**Auth & Password:** `hydra` `medusa` `john` `hashcat` `hashid`

**Framework:** `searchsploit` `metasploit` `nuclei-cve`

**SSL/TLS:** `sslscan` `testssl.sh` `sslyze` `openssl`

**Reporting:** `wkhtmltopdf` `sqlite3`

**APIs:** Shodan · HaveIBeenPwned · WPScan API · VirusTotal · crt.sh

</details>

---

## 🔌 API Integration (Optional)

| API | কাজ | কোথায় পাবেন |
|-----|-----|-------------|
| **Shodan** | External IP intelligence, open port history | [shodan.io](https://shodan.io) |
| **HaveIBeenPwned** | Email breach detection | [haveibeenpwned.com](https://haveibeenpwned.com/API/v3) |
| **WPScan** | WordPress CVE database | [wpscan.com](https://wpscan.com/api) |
| **VirusTotal** | Domain/IP reputation | [virustotal.com](https://www.virustotal.com/gui/my-apikey) |

```bash
# ~/.saimum.conf এ API key যোগ করুন
SHODAN_API_KEY="your_key_here"
HIBP_API_KEY="your_key_here"
WPSCAN_API_TOKEN="your_key_here"
```

---

## ❓ FAQ

<details>
<summary><b>Kali Linux ছাড়া অন্য distro তে চলবে?</b></summary>

Ubuntu/Debian এ চলবে তবে কিছু tool manually install করতে হতে পারে। Kali Linux এ সবচেয়ে সহজে চলে কারণ বেশিরভাগ security tool pre-installed থাকে।
</details>

<details>
<summary><b>Scan কতক্ষণ লাগে?</b></summary>

| Mode | Estimate |
|------|----------|
| Stealth | 2–4 ঘন্টা |
| Normal | 45 মিনিট – 2 ঘন্টা |
| Aggressive | 20–45 মিনিট |

Target এর size এবং enabled stage এর উপর নির্ভর করে।
</details>

<details>
<summary><b>Scan মাঝপথে বন্ধ হয়ে গেলে?</b></summary>

```bash
./main_saimum.sh
# Menu তে "Resume last scan" select করুন
# SQLite state থেকে automatically resume হবে
```
</details>

<details>
<summary><b>Proxy কীভাবে ব্যবহার করব?</b></summary>

```bash
# Burp Suite
./main_saimum.sh -t target.com -p http://127.0.0.1:8080

# Tor
./main_saimum.sh -t target.com -p socks5://127.0.0.1:9050
```
</details>

<details>
<summary><b>শুধু নির্দিষ্ট stage চালাতে চাই?</b></summary>

```bash
# শুধু Recon আর Injection
./main_saimum.sh -t target.com -s 1,5

# Stage 3 থেকে 6 পর্যন্ত
./main_saimum.sh -t target.com -s 3,4,5,6
```
</details>

---

## ⚠️ Troubleshooting

| সমস্যা | সমাধান |
|--------|--------|
| `Permission denied` | `chmod +x main_saimum.sh modules/*.sh` |
| Tool not found | `sudo apt-get install <tool>` বা Go install দেখুন |
| Nuclei templates missing | `nuclei -update-templates` চালান |
| wkhtmltopdf error | `sudo apt-get install wkhtmltopdf` |
| Go tools not in PATH | `export PATH=$PATH:$(go env GOPATH)/bin` |
| Docker permission | `sudo usermod -aG docker $USER` তারপর logout |

---

## 🤝 Contributing

Pull request welcome! বড় পরিবর্তনের আগে একটি issue খুলুন।

```bash
# Fork করুন
git clone https://github.com/YOUR_USERNAME/saimum.git
cd saimum

# নতুন branch
git checkout -b feature/new-module

# Changes করুন, commit করুন
git commit -m "Add: new scanning module"

# Push ও PR
git push origin feature/new-module
```

### Contribution Guidelines
- নতুন module `modules/` এ যোগ করুন
- প্রতিটি tool call এ `run_tool` wrapper ব্যবহার করুন
- বাংলা analysis `write_bangla` function দিয়ে লিখুন
- Timeout সবসময় pass করুন

---

## 📜 Changelog

### v3.0 (Latest)
- ✅ Stage 2: Headers & Fingerprint module যোগ
- ✅ Hashcat mask ও hybrid attack mode
- ✅ XML report format যোগ
- ✅ Multi-scan comparison report
- ✅ Password spray (rate-limited)
- ✅ Vendor default credential check
- ✅ gowitness screenshot capture
- ✅ CDN detection (Cloudflare, Fastly, Akamai)
- ✅ SQLite scan history

### v2.0
- ✅ Pause/Resume support
- ✅ Proxy integration
- ✅ JSON output format
- ✅ বাংলা analysis

### v1.0
- ✅ Initial 8-stage pipeline
- ✅ HTML/PDF report

---

## ⚖️ Legal Disclaimer

```
╔══════════════════════════════════════════════════════════════════════╗
║                        ⚠  IMPORTANT NOTICE                         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  SAIMUM v3.0 শুধুমাত্র authorized penetration testing এবং          ║
║  educational purpose এর জন্য তৈরি।                                  ║
║                                                                      ║
║  এই tool ব্যবহার করার আগে নিশ্চিত করুন যে:                         ║
║                                                                      ║
║  ✅ আপনার কাছে target system এর লিখিত অনুমতি আছে                    ║
║  ✅ Bug bounty program এর scope এর মধ্যে আছেন                        ║
║  ✅ আপনার নিজের owned/lab environment এ test করছেন                  ║
║                                                                      ║
║  অনুমতি ছাড়া যেকোনো system এ এই tool ব্যবহার করা:                  ║
║  • বাংলাদেশে Digital Security Act 2018 এর অধীনে শাস্তিযোগ্য        ║
║  • আন্তর্জাতিকভাবে Computer Fraud and Abuse Act (CFAA)               ║
║    সহ বিভিন্ন সাইবার অপরাধ আইনে দণ্ডনীয়                           ║
║                                                                      ║
║  Author এবং contributors কোনো অপব্যবহারের জন্য                     ║
║  দায়ী নন।                                                           ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

**This tool is provided "as is" for educational and authorized security testing purposes only. The author assumes no liability for any misuse or damage caused by this tool. Always obtain proper written authorization before testing any system you do not own.**

---

## 👤 Author

<div align="center">

**Md Saimum Habib**

[![Blog](https://img.shields.io/badge/Blog-saimumhabib.blogspot.com-orange?style=for-the-badge&logo=blogger&logoColor=white)](https://saimumhabib.blogspot.com)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black?style=for-the-badge&logo=github)](https://github.com)

*Security Researcher · Penetration Tester · Tool Developer*

*"Automate the boring parts of pentesting, focus on what matters."*

</div>

---

## 📄 License

```
MIT License

Copyright (c) 2024 Md Saimum Habib

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
USE AT YOUR OWN RISK. FOR AUTHORIZED TESTING ONLY.
```

---

<div align="center">

**SAIMUM v3.0** — Made with ❤️ by [Md Saimum Habib](https://saimumhabib.blogspot.com)

⭐ যদি useful মনে হয়, একটা star দিন!

</div>
