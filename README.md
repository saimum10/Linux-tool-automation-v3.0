<div align="center">

<pre>
 ███████╗ █████╗ ██╗███╗   ███╗██╗   ██╗███╗   ███╗
 ██╔════╝██╔══██╗██║████╗ ████║██║   ██║████╗ ████║
 ███████╗███████║██║██╔████╔██║██║   ██║██╔████╔██║
 ╚════██║██╔══██║██║██║╚██╔╝██║██║   ██║██║╚██╔╝██║
 ███████║██║  ██║██║██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║
 ╚══════╝╚═╝  ╚═╝╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝
</pre>

# SAIMUM v3.0 — Web Vulnerability Automation Pipeline

**A complete Bash-based automated web penetration testing framework**

[![Version](https://img.shields.io/badge/Version-3.0-red?style=for-the-badge)](https://github.com)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Kali%20Linux-557C94?style=for-the-badge&logo=kali-linux&logoColor=white)](https://www.kali.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Tools](https://img.shields.io/badge/Tools-78+-orange?style=for-the-badge)](#tool-arsenal)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)](LICENSE)

</div>

---

## Preview

```
  ╔══════════════════════════════════════════════════════════════════════╗
  ║              SAIMUM v3.0 — Web Vulnerability Pipeline               ║
  ╠══════════════════════════════════════════════════════════════════════╣
  ║  Target  : target.com                                               ║
  ║  Mode    : Normal  |  Stages: All  |  Proxy: None                   ║
  ╚══════════════════════════════════════════════════════════════════════╝

  STAGE 1/9: RECONNAISSANCE                              [████████░░░░] 33%
  ──────────────────────────────────────────────────────────────────────
  [✓] WHOIS             Domain info collected
  [✓] NMAP              32 open ports found
  [✓] subfinder         47 subdomains discovered
  [✓] Amass             12 additional subdomains
  [✓] crt.sh            59 certificate transparency entries
  [✓] theHarvester      8 emails, 3 hostnames
  [✓] httpx             23 live hosts verified
  [✓] gowitness         Screenshots captured
  [✓] WAF Detection     Cloudflare detected

  STAGE 5/9: INJECTION TESTING                          [████████████░] 55%
  ──────────────────────────────────────────────────────────────────────
  [✓] sqlmap            ⚠  SQL Injection FOUND — parameter: id
  [✓] Dalfox            ⚠  XSS Vulnerability FOUND — parameter: search
  [✓] XSStrike          3 XSS payloads confirmed
  [CRITICAL] SQL Injection — parameter: id
  [HIGH]     Reflected XSS — parameter: search

  ╔══════════════════════════════════════════════════════════════════════╗
  ║  SCAN COMPLETE — target.com                                         ║
  ║  Duration: 1h 23m  |  Critical: 2  High: 5  Medium: 8  Low: 4      ║
  ║  Reports: TXT  HTML  PDF  JSON  XML  generated                      ║
  ╚══════════════════════════════════════════════════════════════════════╝
```

---

## What It Does

SAIMUM v3.0 is a **9-stage automated web vulnerability assessment pipeline**. Provide a target domain or IP address and it automatically handles everything from reconnaissance all the way through to generating a professional report.

| Category | Description |
|----------|-------------|
| **Reconnaissance** | Subdomain enumeration, port scanning, WAF/CDN detection, screenshot capture |
| **Web Analysis** | Header security audit, SSL/TLS analysis, technology fingerprinting |
| **Vulnerability Scan** | CMS scanning (WordPress, Joomla, Drupal), Nuclei CVE check, CORS testing |
| **Content Discovery** | Directory brute force, parameter fuzzing, virtual host discovery |
| **Injection Testing** | SQLi, XSS (reflected/stored/blind), SSRF, XXE, SSTI, Command Injection |
| **Auth Testing** | Brute force (10 protocols), hash cracking, default credentials, password spray |
| **Exploit Matching** | SearchSploit, Metasploit integration, Nuclei CVE templates |
| **Reporting** | TXT + HTML + PDF + JSON + XML with severity scoring |

---

## Pipeline Overview

```
TARGET
  │
  ├── Stage 1 ──► RECONNAISSANCE        (24 tool calls)
  ├── Stage 2 ──► HEADERS & FINGERPRINT
  ├── Stage 3 ──► WEB SCANNING          (9 tool calls)
  ├── Stage 4 ──► DIRECTORY DISCOVERY   (13 tool calls)
  ├── Stage 5 ──► INJECTION TESTING     (9 tool calls)
  ├── Stage 6 ──► AUTH TESTING          (16 tool calls)
  ├── Stage 7 ──► FRAMEWORK & EXPLOITS
  ├── Stage 8 ──► SSL/TLS TESTING
  └── Stage 9 ──► REPORTING
```

---

## Stages — Detailed

<details>
<summary><b>Stage 1 — Reconnaissance</b></summary>

| Tool | Purpose |
|------|---------|
| `whois` | Domain registration, registrar, expiry info |
| `nmap` | Full port scan, OS detection, service version |
| `nmap --script` | SMB, SMTP, RDP, SNMP, FTP-anon script scan |
| `masscan` | High-speed TCP port scan |
| `traceroute` | Network path mapping |
| `dnsrecon` | DNS record enumeration, zone transfer attempt |
| `subfinder` | Passive subdomain enumeration (100+ sources) |
| `amass` | Active + passive subdomain enumeration |
| `crt.sh` | Certificate transparency log search |
| `theHarvester` | Email, subdomain, IP, and social media harvest |
| `waybackurls` | Wayback Machine URL extraction |
| `gau` | Google and AlienVault URL harvest |
| `httpx` | Live host detection, titles, status codes, tech stack |
| `whatweb` | Technology fingerprinting |
| `wafw00f` | WAF detection (Cloudflare, Akamai, F5, Imperva...) |
| `tshark` | Passive network traffic analysis |
| `gowitness` | Subdomain screenshot capture |
| HIBP API | Email breach check (optional) |
| Shodan API | External threat intelligence (optional) |

</details>

<details>
<summary><b>Stage 2 — Headers & Fingerprint</b></summary>

- HTTP/HTTPS response header collection
- Security header audit: `Content-Security-Policy`, `HSTS`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`
- Cookie flag check: `HttpOnly`, `Secure`, `SameSite`
- Server / technology disclosure detection
- `robots.txt` and `sitemap.xml` analysis

</details>

<details>
<summary><b>Stage 3 — Web Scanning</b></summary>

| Tool | Purpose |
|------|---------|
| `nikto` | Web server misconfigurations, known vulnerabilities |
| `nuclei` | Template-based vulnerability scanning |
| `nuclei -t takeovers` | Subdomain takeover detection |
| `wpscan` | WordPress plugin, theme and user enumeration |
| `droopescan` | Drupal and Joomla vulnerability scanning |
| `corscanner` | CORS misconfiguration detection |
| `paramspider` | URL parameter discovery from web archives |
| `arjun` | Hidden HTTP parameter discovery |
| `zaproxy` | OWASP ZAP dynamic application security testing |

</details>

<details>
<summary><b>Stage 4 — Directory Discovery</b></summary>

| Tool | Modes |
|------|-------|
| `gobuster` | DIR, DNS, VHOST |
| `ffuf` | DIR, GET params, POST data, VHOST, Header fuzzing |
| `wfuzz` | DIR, POST data, Cookie fuzzing |
| `dirb` | Classic directory brute force |
| `feroxbuster` | Recursive content discovery |

</details>

<details>
<summary><b>Stage 5 — Injection Testing</b></summary>

| Attack Type | Tool |
|-------------|------|
| SQL Injection | `sqlmap` (URL, Forms, Wayback URLs) |
| XSS Reflected / Stored | `dalfox pipe`, `dalfox url`, `xsstrike` |
| XSS Blind | `dalfox --blind` |
| Command Injection | `commix` |
| JWT Attacks | `jwt_tool` (alg:none, RS→HS confusion, brute force) |
| SSRF | Manual payload injection |
| XXE | XML external entity payloads |
| SSTI | Template injection detection |
| Open Redirect | Header-based detection |

</details>

<details>
<summary><b>Stage 6 — Authentication Testing</b></summary>

**Hydra — 10 protocols:**
`SSH` · `FTP` · `HTTP/HTTPS` · `RDP` · `Telnet` · `MySQL` · `SMTP` · `SMB` · `VNC` · `PostgreSQL`

**Hash Cracking:**
- `john` — Dictionary attack (all hash formats)
- `hashcat` — Dictionary + Mask + Hybrid attack (GPU-accelerated)

**Additional:**
- `medusa` — Multi-protocol parallel brute force
- Vendor default credential check
- Rate-limited password spray

</details>

<details>
<summary><b>Stage 7 — Framework & Exploits</b></summary>

- `searchsploit` — CVE lookup for detected software versions
- `nuclei -t cves` — CVE template-based scanning
- `metasploit` — Auxiliary module integration
- OWASP ZAP — Active scan

</details>

<details>
<summary><b>Stage 8 — SSL/TLS Testing</b></summary>

- `sslscan` — Cipher suites, protocol versions, certificate info
- `testssl.sh` — Comprehensive TLS/SSL audit (BEAST, POODLE, Heartbleed, CRIME...)
- `sslyze` — Python-based TLS analysis
- `openssl` — Manual certificate inspection

</details>

<details>
<summary><b>Stage 9 — Reporting</b></summary>

- **TXT** — Plain text summary with per-tool analysis
- **HTML** — Dark-theme professional report with screenshot embeds and severity badges
- **PDF** — Print-ready professional report via `wkhtmltopdf`
- **JSON** — Machine-readable structured output
- **XML** — Integration-ready format
- **Comparison** — Multi-scan comparison report
- **SQLite** — Persistent scan history database

</details>

---

## Project Structure

```
saimum/
├── main_saimum.sh              ← Entry point / Main menu
├── Dockerfile                  ← Docker environment
├── config/
│   └── .saimum.conf.example    ← Configuration template
└── modules/
    ├── utils.sh                ← Core engine, logging, state management, menus
    ├── recon.sh                ← Stage 1: Reconnaissance
    ├── headers.sh              ← Stage 2: Headers & Fingerprint
    ├── webscanning.sh          ← Stage 3: Web Scanning
    ├── directory.sh            ← Stage 4: Directory Discovery
    ├── injection.sh            ← Stage 5: Injection Testing
    ├── auth.sh                 ← Stage 6: Auth & Password Testing
    ├── framework.sh            ← Stage 7: Framework & Exploits
    ├── ssl.sh                  ← Stage 8: SSL/TLS Testing
    └── report.sh               ← Stage 9: Report Generation
```

---

## Installation

### Prerequisites

```bash
# Kali Linux is recommended
# Go 1.21+ is required for Go-based tools

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
# Build the image
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
go install github.com/OJ/gobuster/v3@latest

# Add Go binaries to PATH
export PATH=$PATH:$(go env GOPATH)/bin

# Python tools
pip3 install --break-system-packages paramspider arjun corscanner droopescan xsstrike

# APT tools
sudo apt-get install -y nmap masscan nikto sqlmap hydra medusa \
  john hashcat wpscan gobuster feroxbuster wfuzz dirb \
  sslscan testssl.sh sslyze dnsrecon whatweb wafw00f \
  wkhtmltopdf amass sqlite3 commix

# Update Nuclei templates
nuclei -update-templates
```

---

## How to Use

### Basic Usage

```bash
./main_saimum.sh
```

An interactive menu will appear — select your target, scan mode, and stages from there.

### Command-Line Flags

```bash
# Normal scan — all stages
./main_saimum.sh -t target.com

# Stealth mode
./main_saimum.sh -t target.com -m 1

# Aggressive mode
./main_saimum.sh -t target.com -m 3

# Specific stages only
./main_saimum.sh -t target.com -s 1,3,5

# With proxy (Burp Suite)
./main_saimum.sh -t target.com -p http://127.0.0.1:8080

# With Tor
./main_saimum.sh -t target.com -p socks5://127.0.0.1:9050
```

### Scan Modes

| Mode | Flag | Speed | Noise Level | Coverage | Best For |
|------|------|-------|-------------|----------|----------|
| Stealth | `-m 1` | Slow | Minimal | Basic | Bug bounty, production systems |
| Normal | `-m 2` | Medium | Moderate | Full | Standard penetration testing |
| Aggressive | `-m 3` | Fast | High | Maximum | Lab environments, CTF |

### Stage Selection

```bash
# Run only Recon and Injection
./main_saimum.sh -t target.com -s 1,5

# Run Stages 3 through 6
./main_saimum.sh -t target.com -s 3,4,5,6

# Run all stages
./main_saimum.sh -t target.com -s all
```

### Pause & Resume

```bash
# Pause a running scan at any time
touch /tmp/.saimum_pause

# To resume, simply restart the script
./main_saimum.sh
# Select "Resume last scan" from the menu
```

---

## Configuration

```bash
cp config/.saimum.conf.example ~/.saimum.conf
nano ~/.saimum.conf
```

```bash
# ~/.saimum.conf

# Output directory
OUTPUT_BASE="$HOME/saimum_scans"

# Default scan mode: 1=Stealth  2=Normal  3=Aggressive
DEFAULT_SCAN_MODE=2

# Report format: 1=TXT  2=TXT+HTML  3=TXT+HTML+PDF
DEFAULT_REPORT_FORMAT=2

# Proxy (optional)
DEFAULT_PROXY=""                  # e.g. socks5://127.0.0.1:9050

# API Keys (optional)
SHODAN_API_KEY=""                 # Shodan threat intelligence
HIBP_API_KEY=""                   # HaveIBeenPwned breach check
WPSCAN_API_TOKEN=""               # WPScan vulnerability database
VIRUSTOTAL_API_KEY=""             # VirusTotal domain reputation

# Timeouts (seconds)
TIMEOUT_NMAP=300
TIMEOUT_NUCLEI=300
TIMEOUT_SQLMAP=300
TIMEOUT_HYDRA=180
TIMEOUT_ZAP=600
TIMEOUT_DEFAULT=120

# Wordlists
WORDLIST_SMALL="/usr/share/wordlists/dirb/small.txt"
WORDLIST_MEDIUM="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
WORDLIST_DNS="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"

# Screenshot capture
GOWITNESS_ENABLED=1

# SQLite scan history
SQLITE_HISTORY=1
SQLITE_DB="$HOME/.saimum_history.db"
```

---

## Example Output

### Terminal Summary

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     SAIMUM v3.0 — SCAN COMPLETE
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    Target   : demo.testfire.net
    Duration : 1h 17m 42s

    Findings:
     Critical :  3
     High     :  7
     Medium   : 12
     Low      :  6
     Info     : 24

    Reports:
     TXT  → ~/saimum_scans/demo.testfire.net_20240115/report.txt
     HTML → ~/saimum_scans/demo.testfire.net_20240115/report.html
     PDF  → ~/saimum_scans/demo.testfire.net_20240115/report.pdf
     JSON → ~/saimum_scans/demo.testfire.net_20240115/report.json
     XML  → ~/saimum_scans/demo.testfire.net_20240115/report.xml

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### HTML Report Preview

```
┌─────────────────────────────────────────────────────────────┐
│  SAIMUM v3.0 Security Report               [CRITICAL: 3]   │
│  Target: demo.testfire.net  |  Date: 2024-01-15            │
├─────────────────────────────────────────────────────────────┤
│  [CRITICAL]  SQL Injection                                  │
│  Parameter: account  |  Tool: sqlmap                       │
│  Evidence: SLEEP(5) — time-based blind confirmed           │
│  Fix: Use parameterized queries / prepared statements       │
├─────────────────────────────────────────────────────────────┤
│  [CRITICAL]  Reflected XSS                                 │
│  Parameter: search  |  Tool: dalfox                        │
│  POC: <script>alert(document.domain)</script>              │
│  Fix: Sanitize and encode all user-supplied input          │
├─────────────────────────────────────────────────────────────┤
│  [HIGH]      Missing HSTS Header                           │
│  URL: https://demo.testfire.net/                           │
│  Fix: Strict-Transport-Security: max-age=31536000          │
└─────────────────────────────────────────────────────────────┘
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
    },
    {
      "severity": "HIGH",
      "title": "Missing HSTS Header",
      "url": "https://demo.testfire.net/",
      "tool": "headers",
      "remediation": "Add Strict-Transport-Security header"
    }
  ]
}
```

---

## Output Directory Structure

```
~/saimum_scans/
└── target.com_20240115_143022/
    ├── report.txt
    ├── report.html
    ├── report.pdf
    ├── report.json
    ├── report.xml
    ├── screenshots/
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
    └── [stage]_[tool].txt
```

---

## Tool Arsenal (78+)

<details>
<summary>View full tool list</summary>

**Reconnaissance:**
`nmap` `masscan` `whois` `dnsrecon` `subfinder` `amass` `theHarvester` `httpx` `waybackurls` `gau` `gowitness` `whatweb` `wafw00f` `tshark` `traceroute`

**Web Scanning:**
`nikto` `nuclei` `wpscan` `droopescan` `corscanner` `arjun` `paramspider` `zaproxy`

**Directory Discovery:**
`gobuster` `ffuf` `wfuzz` `dirb` `feroxbuster`

**Injection Testing:**
`sqlmap` `dalfox` `xsstrike` `commix` `jwt_tool`

**Auth & Password:**
`hydra` `medusa` `john` `hashcat` `hashid`

**Framework & Exploits:**
`searchsploit` `metasploit` `nuclei-cve`

**SSL/TLS:**
`sslscan` `testssl.sh` `sslyze` `openssl`

**Reporting:**
`wkhtmltopdf` `sqlite3`

**APIs:**
Shodan · HaveIBeenPwned · WPScan API · VirusTotal · crt.sh

</details>

---

## API Integration (Optional)

| API | Purpose | Where to Get |
|-----|---------|--------------|
| **Shodan** | External IP intelligence, open port history | [shodan.io](https://shodan.io) |
| **HaveIBeenPwned** | Email breach detection | [haveibeenpwned.com/API/v3](https://haveibeenpwned.com/API/v3) |
| **WPScan** | WordPress CVE vulnerability database | [wpscan.com](https://wpscan.com/api) |
| **VirusTotal** | Domain and IP reputation scoring | [virustotal.com](https://www.virustotal.com/gui/my-apikey) |

```bash
# Add API keys to ~/.saimum.conf
SHODAN_API_KEY="your_key_here"
HIBP_API_KEY="your_key_here"
WPSCAN_API_TOKEN="your_key_here"
VIRUSTOTAL_API_KEY="your_key_here"
```

---

## FAQ

<details>
<summary><b>Does it work on distros other than Kali Linux?</b></summary>

Yes — Ubuntu and Debian will work, but some tools may need to be installed manually. Kali Linux is recommended because most security tools come pre-installed.

</details>

<details>
<summary><b>How long does a scan take?</b></summary>

| Mode | Estimated Time |
|------|----------------|
| Stealth | 2–4 hours |
| Normal | 45 minutes – 2 hours |
| Aggressive | 20–45 minutes |

Actual time depends on the target size and which stages are enabled.

</details>

<details>
<summary><b>The scan stopped midway. Can I resume?</b></summary>

```bash
./main_saimum.sh
# Select "Resume last scan" from the menu
# The script will automatically restore state from SQLite
```

</details>

<details>
<summary><b>How do I use a proxy?</b></summary>

```bash
# Burp Suite
./main_saimum.sh -t target.com -p http://127.0.0.1:8080

# Tor
./main_saimum.sh -t target.com -p socks5://127.0.0.1:9050
```

</details>

<details>
<summary><b>Can I run only specific stages?</b></summary>

```bash
# Only Recon and Injection
./main_saimum.sh -t target.com -s 1,5

# Stages 3 to 6
./main_saimum.sh -t target.com -s 3,4,5,6
```

</details>

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Permission denied` | `chmod +x main_saimum.sh modules/*.sh` |
| Tool not found | `sudo apt-get install <tool>` or see Go install section |
| Nuclei templates missing | Run `nuclei -update-templates` |
| `wkhtmltopdf` error | `sudo apt-get install wkhtmltopdf` |
| Go tools not in PATH | `export PATH=$PATH:$(go env GOPATH)/bin` |
| Docker permission denied | `sudo usermod -aG docker $USER` then logout and back in |

---

## Changelog

### v3.0 (Latest)
- Stage 2: Headers & Fingerprint module added
- Hashcat mask and hybrid attack modes
- XML report format added
- Multi-scan comparison report
- Rate-limited password spray
- Vendor default credential checking
- gowitness screenshot capture
- CDN detection (Cloudflare, Fastly, Akamai)
- SQLite scan history

### v2.0
- Pause and Resume support
- Proxy integration (Burp, SOCKS5, Tor)
- JSON output format
- Per-tool analysis output

### v1.0
- Initial 8-stage pipeline
- HTML and PDF report generation

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

```bash
# Fork the repository
git clone https://github.com/YOUR_USERNAME/saimum.git
cd saimum

# Create a new branch
git checkout -b feature/new-module

# Make your changes and commit
git commit -m "Add: new scanning module"

# Push and open a PR
git push origin feature/new-module
```

**Contribution Guidelines:**
- Add new modules inside `modules/`
- Use the `run_tool` wrapper for every tool call
- Always pass a timeout parameter
- Follow the existing stage structure

---

## Legal Disclaimer

```
╔══════════════════════════════════════════════════════════════════════╗
║                          IMPORTANT NOTICE                           ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  SAIMUM v3.0 is designed exclusively for authorized penetration     ║
║  testing and educational purposes.                                   ║
║                                                                      ║
║  Before using this tool, ensure that:                               ║
║                                                                      ║
║    You have explicit written permission to test the target system   ║
║    You are operating within the scope of a bug bounty program       ║
║    You are testing a system you own or have a lab environment       ║
║                                                                      ║
║  Unauthorized use of this tool against any system is illegal and    ║
║  may violate computer crime laws in your jurisdiction, including    ║
║  the Computer Fraud and Abuse Act (CFAA) and similar legislation    ║
║  worldwide.                                                          ║
║                                                                      ║
║  The author and contributors accept no liability for any misuse     ║
║  or damage caused by this tool.                                      ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

**This tool is provided "as is" for educational and authorized security testing only. Always obtain proper written authorization before testing any system you do not own.**

---

## Author

<div align="center">

**Md Saimum Habib**

[![Blog](https://img.shields.io/badge/Blog-saimumhabib.blogspot.com-orange?style=for-the-badge&logo=blogger&logoColor=white)](https://saimumhabib.blogspot.com)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black?style=for-the-badge&logo=github)](https://github.com)

*Security Researcher · Penetration Tester · Tool Developer*

*"Automate the boring parts of pentesting — focus on what matters."*

</div>

---

## License

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

**SAIMUM v3.0** — Built by [Md Saimum Habib](https://saimumhabib.blogspot.com)

If you find this useful, please leave a star!

</div>
