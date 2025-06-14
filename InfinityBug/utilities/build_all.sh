#!/bin/bash

# Exit on any error
set -e

# Configuration
PROJECT_NAME="InfinityBug"
SCHEME_NAME="InfinityBug"
WORKSPACE_NAME="InfinityBug"
BUILD_RESULTS_DIR="../build_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BUILD_DIR="${BUILD_RESULTS_DIR}/build_${TIMESTAMP}"
LOG_DIR="${BUILD_DIR}/logs"
SUMMARY_FILE="${BUILD_DIR}/build_summary.txt"

# Create necessary directories
mkdir -p "${BUILD_RESULTS_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${LOG_DIR}"

# Initialize summary file
echo "Build Summary - $(date)" > "${SUMMARY_FILE}"
echo "==========================================" >> "${SUMMARY_FILE}"

# Function to log messages
log_message() {
    local message="$1"
    local log_file="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $message" | tee -a "$log_file"
}

# Function to run build for a specific target
run_build() {
    local target="$1"
    local log_file="${LOG_DIR}/${target}_build.log"
    
    log_message "Starting build for target: $target" "${SUMMARY_FILE}"
    
    # Clean build folder
    xcodebuild clean -project "../${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -configuration Debug > "${log_file}" 2>&1 || {
        log_message "❌ Clean failed for $target" "${SUMMARY_FILE}"
        return 1
    }
    
    # Build target
    xcodebuild build -project "../${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' >> "${log_file}" 2>&1 || {
        log_message "❌ Build failed for $target" "${SUMMARY_FILE}"
        return 1
    }
    
    log_message "✅ Build successful for $target" "${SUMMARY_FILE}"
    return 0
}

# Main execution
log_message "Starting build process" "${SUMMARY_FILE}"

# Get all targets from the project
TARGETS=$(xcodebuild -project "../${PROJECT_NAME}.xcodeproj" -list | grep -A 100 "Targets:" | grep -v "Targets:" | grep -v "^$" | sed 's/^[ \t]*//')

# Run build for each target
for target in $TARGETS; do
    run_build "$target"
done

# Generate final summary
echo -e "\nBuild Process Complete" >> "${SUMMARY_FILE}"
echo "==========================================" >> "${SUMMARY_FILE}"
echo "Results can be found in: ${BUILD_DIR}" >> "${SUMMARY_FILE}"

log_message "Build process completed. Results in ${BUILD_DIR}" "${SUMMARY_FILE}" 