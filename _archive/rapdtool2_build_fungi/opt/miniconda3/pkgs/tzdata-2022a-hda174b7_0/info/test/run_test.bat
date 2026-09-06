



dirs="$(
  find "${PREFIX}" -mindepth 1 -maxdepth 2 \
  \! -path "${PREFIX}/share" \! -path "${PREFIX}/conda-meta*"
)"
test "${dirs}" = "${PREFIX}/share/zoneinfo"

IF %ERRORLEVEL% NEQ 0 exit /B 1
heads="$(
  find "${PREFIX}/share/zoneinfo" -type f \
    \! -name \*.zi \! -name \*.tab \! -name leapseconds \
    -exec head -c4 {} \; -printf \\n \
    | uniq
)"

IF %ERRORLEVEL% NEQ 0 exit /B 1
heads="$(
  find "${PREFIX}/share/zoneinfo" -type f \
    \! -name \*.zi \! -name \*.tab \! -name leapseconds \
    -exec head -c4 {} \; -print0 \
    | uniq \
    | cut -c1-4 \
)"
test "${heads}" = TZif

IF %ERRORLEVEL% NEQ 0 exit /B 1
exit /B 0
