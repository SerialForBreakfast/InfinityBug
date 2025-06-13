#!/bin/bash

# Exit on any error
set -e

# Configuration
PROJECT_NAME="InfinityBug"
BUILD_RESULTS_DIR="../build_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BUILD_DIR="${BUILD_RESULTS_DIR}/build_${TIMESTAMP}"
LOG_DIR="${BUILD_DIR}/logs"
SUMMARY_FILE="${BUILD_DIR}/build_summary.txt"
TEST_RESULTS_DIR="${BUILD_DIR}/test_results"

# Get absolute path for build results
ABS_BUILD_DIR=$(cd "${BUILD_DIR}" 2>/dev/null || mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}" && pwd)

# Create necessary directories
mkdir -p "${LOG_DIR}" "${TEST_RESULTS_DIR}"

# Initialize summary file
echo "Build Summary - $(date)" > "${SUMMARY_FILE}"
echo "=================================" >> "${SUMMARY_FILE}"

# Logging function
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> "${SUMMARY_FILE}"
    echo "$message"
}

# Error handling function
handle_error() {
    local target=$1
    local log_file=$2
    local error_message=$3
    
    log_message "❌ ERROR: $error_message"
    log_message "See detailed logs in: $log_file"
    
    # Print the last 20 lines of the log file
    echo "Last 20 lines of log file:"
    echo "----------------------------------------"
    tail -n 20 "$log_file"
    echo "----------------------------------------"
    
    # Save error to test results
    echo "ERROR: $error_message" > "${TEST_RESULTS_DIR}/${target}_error.txt"
    echo "Full log available at: $log_file" >> "${TEST_RESULTS_DIR}/${target}_error.txt"
}

# Function to run build and test for a target
run_build_and_test() {
    local target=$1
    local log_file="${LOG_DIR}/${target}.log"
    local test_result_file="${TEST_RESULTS_DIR}/${target}_result.txt"
    
    log_message "Building target: ${target}"
    
    # Clean and build
    if ! xcodebuild clean -project "../${PROJECT_NAME}.xcodeproj" -target "${target}" -configuration Debug > "${log_file}" 2>&1; then
        handle_error "$target" "$log_file" "Clean failed for target ${target}"
        return 1
    fi
    
    if ! xcodebuild build -project "../${PROJECT_NAME}.xcodeproj" -target "${target}" -configuration Debug >> "${log_file}" 2>&1; then
        handle_error "$target" "$log_file" "Build failed for target ${target}"
        return 1
    fi
    
    # Run tests if it's a test target
    if [[ "${target}" == *"Tests"* ]]; then
        log_message "Running tests for: ${target}"
        if [[ "${target}" == *"UI"* ]]; then
            # For UI tests, use the main scheme with detailed output
            if ! xcodebuild test \
                -project "../${PROJECT_NAME}.xcodeproj" \
                -scheme "${PROJECT_NAME}" \
                -destination 'platform=tvOS Simulator,name=Apple TV' \
                -only-testing "${target}" \
                -resultBundlePath "${TEST_RESULTS_DIR}/${target}.xcresult" \
                -resultBundleVersion 3 \
                >> "${log_file}" 2>&1; then
                handle_error "$target" "$log_file" "UI Tests failed for target ${target}"
                return 1
            fi
        else
            # For unit tests, use the scheme with detailed output and always specify destination
            if ! xcodebuild test \
                -project "../${PROJECT_NAME}.xcodeproj" \
                -scheme "${PROJECT_NAME}" \
                -only-testing "${target}" \
                -destination 'platform=tvOS Simulator,name=Apple TV' \
                -resultBundlePath "${TEST_RESULTS_DIR}/${target}.xcresult" \
                -resultBundleVersion 3 \
                >> "${log_file}" 2>&1; then
                handle_error "$target" "$log_file" "Unit Tests failed for target ${target}"
                return 1
            fi
        fi
        
        # Save test results summary
        echo "Test Results for ${target}" > "${test_result_file}"
        echo "----------------------------------------" >> "${test_result_file}"
        grep -A 5 "Test Suite" "${log_file}" >> "${test_result_file}" 2>/dev/null || echo "No test results found" >> "${test_result_file}"
        
        # Save detailed test failures if any
        if grep -q "Failing tests:" "${log_file}"; then
            echo "Failing Tests:" >> "${test_result_file}"
            echo "----------------------------------------" >> "${test_result_file}"
            grep -A 10 "Failing tests:" "${log_file}" >> "${test_result_file}"
        fi
    fi
    
    log_message "✅ Completed ${target}"
    return 0
}

# Main execution
log_message "Starting build and test process"
log_message "Listing available targets..."

# Get available targets and filter out build configurations
TARGETS=$(xcodebuild -project "../${PROJECT_NAME}.xcodeproj" -list | grep -E "^[[:space:]]*[A-Za-z0-9_]+$" | sed 's/^[[:space:]]*//' | grep -v -E "^(Debug|Release)$")

if [ -z "$TARGETS" ]; then
    log_message "❌ No targets found in project"
    exit 1
fi

# Process each target
FAILED_TARGETS=()
for target in $TARGETS; do
    if ! run_build_and_test "$target"; then
        FAILED_TARGETS+=("$target")
    fi
done

# Final summary
if [ ${#FAILED_TARGETS[@]} -eq 0 ]; then
    log_message "✅ All targets completed successfully"
else
    log_message "❌ The following targets failed:"
    for target in "${FAILED_TARGETS[@]}"; do
        log_message "   - $target"
    done
    echo "\nSee logs and test results in: $ABS_BUILD_DIR"
    exit 1
fi

log_message "Build and test process completed"
echo "\nBuild and test results available at: $ABS_BUILD_DIR" 