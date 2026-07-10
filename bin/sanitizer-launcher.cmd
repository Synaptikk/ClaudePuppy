@echo off
:: sanitizer-launcher.cmd (VDI variant)
:: Starts the claude sanitizing proxy on 127.0.0.1:8787.
::
:: Sets the Walmart-internal pypi mirror so first-run dep fetch (FastAPI,
:: uvicorn, httpx) succeeds. HTTP_PROXY is set so uv can reach the mirror;
:: it's inherited by the sanitizer subprocess but httpx will route the
:: internal upstream (puppy-backend.walmart.com) via sysproxy too, which is
:: how outbound corporate HTTP normally works on the VDI.
set UPSTREAM_URL=https://puppy-backend.walmart.com/anthropic
set DROP_KEYS=context_management
set UPSTREAM_CA=false
set UV_INDEX_URL=https://pypi.ci.artifacts.walmart.com/artifactory/api/pypi/external-pypi/simple
set UV_INSECURE_HOST=pypi.ci.artifacts.walmart.com
set HTTP_PROXY=http://sysproxy.wal-mart.com:8080
set HTTPS_PROXY=http://sysproxy.wal-mart.com:8080

echo Starting claude sanitizer on http://127.0.0.1:8787 ...
"H:\%USERNAME%\.uv-bin\uv.exe" run --script "H:\%USERNAME%\code-puppy-home\claude_sanitizer\sanitizer.py"
