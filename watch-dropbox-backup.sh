#!/bin/bash
#
# Watch Dropbox backup progress on pg2
# Displays status every 60 seconds
#

echo "Watching Dropbox backup on pg2 (Ctrl+C to stop)"
echo "================================================"

while true; do
    # Get the latest stats from the log
    stats=$(ssh pg2 'tail -20 /tmp/dropbox-s3-backup.log 2>/dev/null | grep -A 8 "^Transferred:" | head -9')

    if [ -z "$stats" ]; then
        echo "$(date '+%H:%M:%S') - No backup running or log not found"
    else
        # Extract key metrics
        elapsed=$(echo "$stats" | grep "Elapsed" | awk '{print $3}')
        checks=$(echo "$stats" | grep "Checks:" | head -1)
        transferred=$(echo "$stats" | grep "Transferred:" | head -1)

        # Parse checks line: "Checks: 1252 / 6799, 18%, Listed 60290"
        if [ -n "$checks" ]; then
            checked=$(echo "$checks" | awk '{print $2}')
            total=$(echo "$checks" | awk '{print $4}' | tr -d ',')
            pct=$(echo "$checks" | awk '{print $5}' | tr -d ',')
            listed=$(echo "$checks" | awk '{print $7}')

            # Calculate ETA based on check rate
            if [ "$checked" -gt 0 ] && [ -n "$elapsed" ]; then
                # Extract minutes from elapsed (format: 5m0.0s or 1h5m0.0s)
                mins=$(echo "$elapsed" | grep -oE '[0-9]+m' | tr -d 'm')
                hrs=$(echo "$elapsed" | grep -oE '[0-9]+h' | tr -d 'h')
                [ -z "$mins" ] && mins=0
                [ -z "$hrs" ] && hrs=0
                total_mins=$((hrs * 60 + mins))

                if [ "$total_mins" -gt 0 ]; then
                    rate=$((checked / total_mins))
                    if [ "$rate" -gt 0 ] && [ -n "$listed" ]; then
                        remaining=$((listed - checked))
                        eta_mins=$((remaining / rate))
                        eta_hrs=$((eta_mins / 60))
                        eta_mins_rem=$((eta_mins % 60))

                        echo ""
                        echo "$(date '+%H:%M:%S') | Elapsed: $elapsed | Checked: $checked/$listed ($pct) | Rate: ~${rate}/min | ETA: ~${eta_hrs}h ${eta_mins_rem}m"
                    fi
                fi
            fi
        fi

        # Show transfer info if any
        xfer=$(echo "$transferred" | grep -oE '[0-9.]+ [KMGT]?i?B' | head -1)
        if [ -n "$xfer" ] && [ "$xfer" != "0 B" ]; then
            echo "         Transferred: $xfer"
        fi
    fi

    sleep 60
done
