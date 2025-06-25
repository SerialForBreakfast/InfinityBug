#!/bin/bash

# capture_uitest_logs.sh
# Automated console log collection for HammerTime UITest execution
# 
# Usage: ./capture_uitest_logs.sh [test_name] [device_id]
#
# Features:
# - Captures unified logs during UITest execution
# - Filters by HammerTime subsystem
# - Saves both raw and filtered logs
# - Provides real-time console output

set -e

# Configuration
SUBSYSTEM="com.showblender.HammerTime"
TEST_NAME="${1:-UITest}"
DEVICE_ID="${2:-auto}"
OUTPUT_DIR="logs/UITestConsoleCapture"
TIMESTAMP=$(date +"%y%m%d-%H%M")
LOG_PREFIX="${TIMESTAMP}-${TEST_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 HammerTime UITest Console Log Capture${NC}"
echo -e "${BLUE}=========================================${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to find device ID if not provided
find_device_id() {
    if [ "$DEVICE_ID" = "auto" ]; then
        echo -e "${YELLOW}🔍 Auto-detecting Apple TV device...${NC}"
        DEVICE_ID=$(xcrun devicectl list devices | grep "Apple TV" | head -1 | awk '{print $1}')
        if [ -z "$DEVICE_ID" ]; then
            echo -e "${RED}❌ No Apple TV device found${NC}"
            echo "Available devices:"
            xcrun devicectl list devices
            exit 1
        fi
        echo -e "${GREEN}✅ Found Apple TV device: $DEVICE_ID${NC}"
    fi
}

# Function to start log streaming
start_log_streaming() {
    echo -e "${YELLOW}📡 Starting log streaming for subsystem: $SUBSYSTEM${NC}"
    
    # Raw log file
    RAW_LOG="$OUTPUT_DIR/${LOG_PREFIX}-raw.log"
    
    # Filtered log file  
    FILTERED_LOG="$OUTPUT_DIR/${LOG_PREFIX}-filtered.log"
    
    # Start log streaming in background
    xcrun devicectl log stream \
        --device "$DEVICE_ID" \
        --predicate "subsystem == \"$SUBSYSTEM\"" \
        > "$RAW_LOG" 2>&1 &
    
    LOG_PID=$!
    echo -e "${GREEN}✅ Log streaming started (PID: $LOG_PID)${NC}"
    echo -e "${BLUE}📁 Raw logs: $RAW_LOG${NC}"
    
    # Also start a filtered view for real-time monitoring
    tail -f "$RAW_LOG" | grep -E "(TestRunLogger|AXFocusDebugger|UITestExecution)" > "$FILTERED_LOG" &
    FILTER_PID=$!
    
    echo -e "${BLUE}📁 Filtered logs: $FILTERED_LOG${NC}"
    
    # Store PIDs for cleanup
    echo "$LOG_PID" > "$OUTPUT_DIR/.log_pid"
    echo "$FILTER_PID" > "$OUTPUT_DIR/.filter_pid"
}

# Function to stop log streaming
stop_log_streaming() {
    echo -e "${YELLOW}🛑 Stopping log streaming...${NC}"
    
    if [ -f "$OUTPUT_DIR/.log_pid" ]; then
        LOG_PID=$(cat "$OUTPUT_DIR/.log_pid")
        kill "$LOG_PID" 2>/dev/null || true
        rm "$OUTPUT_DIR/.log_pid"
    fi
    
    if [ -f "$OUTPUT_DIR/.filter_pid" ]; then
        FILTER_PID=$(cat "$OUTPUT_DIR/.filter_pid")
        kill "$FILTER_PID" 2>/dev/null || true
        rm "$OUTPUT_DIR/.filter_pid"
    fi
    
    echo -e "${GREEN}✅ Log streaming stopped${NC}"
}

# Function to generate summary
generate_summary() {
    echo -e "${BLUE}📊 Generating log summary...${NC}"
    
    SUMMARY_FILE="$OUTPUT_DIR/${LOG_PREFIX}-summary.txt"
    
    cat > "$SUMMARY_FILE" << EOF
HammerTime UITest Console Log Summary
====================================
Test Name: $TEST_NAME
Device ID: $DEVICE_ID
Timestamp: $TIMESTAMP
Subsystem: $SUBSYSTEM

Files Generated:
- Raw logs: ${LOG_PREFIX}-raw.log
- Filtered logs: ${LOG_PREFIX}-filtered.log
- Summary: ${LOG_PREFIX}-summary.txt

Log Statistics:
EOF
    
    # Add statistics if files exist
    if [ -f "$OUTPUT_DIR/${LOG_PREFIX}-raw.log" ]; then
        echo "- Total log entries: $(wc -l < "$OUTPUT_DIR/${LOG_PREFIX}-raw.log")" >> "$SUMMARY_FILE"
    fi
    
    if [ -f "$OUTPUT_DIR/${LOG_PREFIX}-filtered.log" ]; then
        echo "- Filtered entries: $(wc -l < "$OUTPUT_DIR/${LOG_PREFIX}-filtered.log")" >> "$SUMMARY_FILE"
        echo "- TestRunLogger entries: $(grep -c "TestRunLogger" "$OUTPUT_DIR/${LOG_PREFIX}-filtered.log" || echo 0)" >> "$SUMMARY_FILE"
        echo "- AXFocusDebugger entries: $(grep -c "AXFocusDebugger" "$OUTPUT_DIR/${LOG_PREFIX}-filtered.log" || echo 0)" >> "$SUMMARY_FILE"
    fi
    
    echo -e "${GREEN}✅ Summary saved: $SUMMARY_FILE${NC}"
}

# Function to display usage instructions
show_usage_instructions() {
    cat << EOF

${GREEN}🎯 NEXT STEPS:${NC}

1. ${YELLOW}Run your UITest:${NC}
   xcodebuild test -project HammerTime.xcodeproj \\
     -scheme HammerTime \\
     -destination 'platform=tvOS,id=$DEVICE_ID' \\
     -only-testing:HammerTimeUITests/FocusStressUITests/testComprehensiveConsoleCapture

2. ${YELLOW}Monitor real-time logs:${NC}
   tail -f "$OUTPUT_DIR/${LOG_PREFIX}-filtered.log"

3. ${YELLOW}Stop log capture when test completes:${NC}
   Press Ctrl+C or run: kill $LOG_PID

4. ${YELLOW}Access captured logs:${NC}
   - Raw: $OUTPUT_DIR/${LOG_PREFIX}-raw.log
   - Filtered: $OUTPUT_DIR/${LOG_PREFIX}-filtered.log
   - Summary: $OUTPUT_DIR/${LOG_PREFIX}-summary.txt

${BLUE}📱 Alternative Access Methods:${NC}
- Xcode Console: Window → Devices and Simulators → [Device] → Open Console
- Console.app: Search for "$SUBSYSTEM"
- Terminal: xcrun devicectl log collect --device $DEVICE_ID

EOF
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    stop_log_streaming
    generate_summary
    echo -e "${GREEN}✅ Log capture completed${NC}"
    exit 0
}

# Set up trap for cleanup
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    find_device_id
    start_log_streaming
    show_usage_instructions
    
    echo -e "${GREEN}🚀 Log capture is running. Press Ctrl+C to stop and generate summary.${NC}"
    
    # Keep script running until interrupted
    while true; do
        sleep 1
    done
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 