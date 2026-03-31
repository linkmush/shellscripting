Automationsdriven Säkerhetsförbättring — Submission

Innehåll
- report.md — Teoretisk rapport (Svenska)
- scripts/collect_logs.sh — Bash-skript (Linux)
- scripts/hardening_checks.ps1 — PowerShell-skript (Windows)
- scripts/analysis.py — Python-skript (plattformoberoende)
- sample_logs/syslog_sample.log — Exempeldata
- sample_outputs/analysis.json — Exempel på analysutdata
- requirements.txt — Python dependencies (aktuellt: inga externa paket)
- tooling.json — Lista över tillagda paket/verktyg
- .gitignore — Ignorera output-kataloger
- Makefile — Hjälp för att generera PDF med pandoc (valfritt)

Quick start
- Linux (Bash):
  - Kör: `bash submission/scripts/collect_logs.sh -a -o submission/out`
- Windows (PowerShell, kör som Administrator):
  - Kör: `powershell -ExecutionPolicy Bypass -File submission/scripts/hardening_checks.ps1 -CollectLogs -OutputDir .\\submission\\out`
- Analys (Python):
  - Kör: `python submission/scripts/analysis.py --input-dir submission/sample_logs --output submission/sample_outputs/analysis.json --threshold 5`

Bygga PDF (valfritt)
- För att konvertera `submission/report.md` till PDF (kräver `pandoc` och LaTeX):

  ```sh
  pandoc submission/report.md -o submission/report.pdf --pdf-engine=xelatex
  ```

Kommentarer
- Skripten är designade för att vara icke-destruktiva. Vissa insamlingar kräver root/Administrator.
- Använd en secrets manager i produktion; inga credentials är hårdkodade i skripten.
- Se `submission/tooling.json` för en översikt av rekommenderade systemverktyg.
