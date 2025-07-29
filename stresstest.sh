#!/bin/bash

# Default config
THREADS=2
CONNS=10
DURATION=60
TIMEOUT=10
FORMAT="table"

# Parse options
while [[ "$1" =~ ^- || "$1" == --* ]]; do
    case $1 in
        -t ) shift; THREADS=$1 ;;
        -c ) shift; CONNS=$1 ;;
        -d ) shift; DURATION=$1 ;;
        -f ) shift; FORMAT=$1 ;;  # table or json
        --timeout ) shift; TIMEOUT=$1 ;;
    esac
    shift
done

URLS=("$@")

# Helper to convert latency to milliseconds
convert_latency() {
    local val="$1"
    if [[ $val == *ms ]]; then
        echo "${val/ms/}" | awk '{printf "%.0f", $1}'
    elif [[ $val == *s ]]; then
        echo "${val/s/}" | awk '{printf "%.0f", $1 * 1000}'
    elif [[ $val == *us ]]; then
        echo "${val/us/}" | awk '{printf "%.0f", $1 / 1000}'
    else
        echo "99999"
    fi
}

# ✨ Show config - only in table format
if [[ "$FORMAT" == "table" ]]; then
    echo -e "\n🔧 Running stress test with parameters:"
    echo "  Threads      : $THREADS"
    echo "  Connections  : $CONNS"
    echo "  Duration     : ${DURATION}s"
    echo "  Timeout      : ${TIMEOUT}s"
    echo "  Output Format: $FORMAT"
    echo "  Sites to Test:"
    for url in "${URLS[@]}"; do
        echo "    - $url"
    done
    echo

    # Header
    printf "\n%-40s | %10s | %10s | %8s | %14s | %6s | %6s\n" \
        "URL" "Latency" "Req/sec" "Total" "Transfer/sec" "Errors" "Grade"
    printf -- "------------------------------------------------------------------------------------------------------------------\n"
fi

# Collector
RESULTS=()

# Loop through URLs
for URL in "${URLS[@]}"; do
    RAW=$(wrk -t"$THREADS" -c"$CONNS" -d"$DURATION" --timeout "$TIMEOUT" "$URL" 2>&1)

    LATENCY=$(echo "$RAW" | grep -i "Latency" | awk '{print $2}')
    REQSEC=$(echo "$RAW" | grep -i "Requests/sec" | awk '{print $2}')
    TRANSFER=$(echo "$RAW" | grep -i "Transfer/sec" | awk '{print $2}')
    TOTALREQ=$(echo "$RAW" | awk '/requests in/ {print $1}')

    SOCKET_LINE=$(echo "$RAW" | grep -i "Socket errors")
    CONNECTS=$(echo "$SOCKET_LINE" | awk -F'connect ' '{print $2}' | awk '{print $1}')
    READS=$(echo "$SOCKET_LINE" | awk -F'read ' '{print $2}' | awk '{print $1}')
    WRITES=$(echo "$SOCKET_LINE" | awk -F'write ' '{print $2}' | awk '{print $1}')
    TIMEOUTS=$(echo "$SOCKET_LINE" | awk -F'timeout ' '{print $2}' | awk '{print $1}')

    # Defaults
    [[ -z "$TOTALREQ" ]] && TOTALREQ=0
    [[ -z "$REQSEC" ]] && REQSEC=0
    [[ -z "$TRANSFER" ]] && TRANSFER="0B"
    [[ -z "$LATENCY" ]] && LATENCY="9999ms"
    [[ -z "$CONNECTS" ]] && CONNECTS=0
    [[ -z "$READS" ]] && READS=0
    [[ -z "$WRITES" ]] && WRITES=0
    [[ -z "$TIMEOUTS" ]] && TIMEOUTS=0

    ERROR_TOTAL=$((CONNECTS + READS + WRITES + TIMEOUTS))
    LAT_MS=$(convert_latency "$LATENCY")
    TIMEOUT_PCT=$(awk "BEGIN { if ($TOTALREQ > 0) print ($TIMEOUTS / $TOTALREQ) * 100; else print 100 }")

    # Grading
    if [[ $(awk "BEGIN {print ($REQSEC >= 200)}") -eq 1 && "$LAT_MS" -le 100 && $(awk "BEGIN {print ($TIMEOUT_PCT <= 1)}") -eq 1 && "$CONNECTS" -eq 0 ]]; then
        GRADE="A"
    elif [[ $(awk "BEGIN {print ($REQSEC >= 100)}") -eq 1 && "$LAT_MS" -le 300 && $(awk "BEGIN {print ($TIMEOUT_PCT <= 2)}") -eq 1 && "$CONNECTS" -eq 0 ]]; then
        GRADE="B"
    elif [[ $(awk "BEGIN {print ($REQSEC >= 25)}") -eq 1 && "$LAT_MS" -le 750 && $(awk "BEGIN {print ($TIMEOUT_PCT <= 5)}") -eq 1 ]]; then
        GRADE="C"
    elif [[ $(awk "BEGIN {print ($REQSEC >= 5)}") -eq 1 && "$LAT_MS" -le 1500 && $(awk "BEGIN {print ($TIMEOUT_PCT <= 10)}") -eq 1 ]]; then
        GRADE="D"
    else
        GRADE="F"
    fi

    # Table output
    if [[ "$FORMAT" == "table" ]]; then
        printf "%-40s | %10s | %10s | %8s | %14s | %6s | %6s\n" \
            "$URL" "$LATENCY" "$REQSEC" "$TOTALREQ" "$TRANSFER" "$ERROR_TOTAL" "$GRADE"
    fi

    # JSON output - simplified to match table columns
    RESULTS+=("{
        \"url\": \"$URL\",
        \"latency\": \"$LATENCY\",
        \"requests_per_sec\": \"$REQSEC\",
        \"total_requests\": \"$TOTALREQ\",
        \"transfer_per_sec\": \"$TRANSFER\",
        \"errors\": $ERROR_TOTAL,
        \"grade\": \"$GRADE\"
    }")
done

# JSON output with config included
if [[ "$FORMAT" == "json" ]]; then
    URLS_JSON=""
    for i in "${!URLS[@]}"; do
        if [[ $i -gt 0 ]]; then
            URLS_JSON+=", "
        fi
        URLS_JSON+="\"${URLS[$i]}\""
    done

    echo -e "{
  \"config\": {
    \"threads\": $THREADS,
    \"connections\": $CONNS,
    \"duration\": $DURATION,
    \"timeout\": $TIMEOUT,
    \"urls\": [$URLS_JSON]
  },
  \"results\": [
    $(IFS=,; echo "${RESULTS[*]}")
  ]
}"
fi