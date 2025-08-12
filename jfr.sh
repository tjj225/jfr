#!/bin/bash

# This script automates the process of starting and stopping a JFR recording
# and then "scrubbing" it to remove sensitive information.

# --- Configuration ---
# Set the keyword to search for in the process list.
# For example, "atoti" to find the atoti application's PID.
KEYWORD="atoti"

# --- Optional Parameters ---
# The first command-line argument can be used to set the sleep duration.
# If no argument is provided, it defaults to 5 seconds.
# Example usage: ./your_script_name.sh 10 JFR-APP
SLEEP_DELAY=${1:-5}
# The second command-line argument can be used to set the recording name.
# If no argument is provided, it defaults to the value of the KEYWORD variable.
RECORDING_NAME=${2:-"$KEYWORD"}

# --- Find the PID ---
# Use `ps -ef` to list all running processes,
# `grep` to filter for our keyword, and then
# `grep -v grep` to exclude the grep process itself.
# `awk` is used to get the second column, which is the PID.
# The `head -n 1` ensures we only get the first PID if multiple processes match.
echo "Searching for a Java process with the keyword: '$KEYWORD'..."
PID=$(ps -ef | grep java |grep "$KEYWORD" | grep -v grep | awk '{print $2}' | head -n 1)

# Check if a PID was found.
if [ -z "$PID" ]; then
    echo "Error: No process found with the keyword '$KEYWORD'."
    exit 1
fi

# Use the present working directory (pwd) as the base for file creation.
# Note: This means the output file will be generated in the directory from
# which the script is executed, not necessarily where the script file is located.
SCRIPT_DIR=$(pwd)
echo "Using script directory: $SCRIPT_DIR"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
BASENAME="${RECORDING_NAME}_${TIMESTAMP}.jfr"
TEMP_FILENAME="$SCRIPT_DIR/temp_$BASENAME"
OUTPUT_FILENAME="$SCRIPT_DIR/$BASENAME"



echo "Found process with PID: $PID"
echo "Using a sleep delay of ${SLEEP_DELAY} seconds."
echo "Using a recording name of: $RECORDING_NAME"

# --- JFR Commands ---
# Start the recording using the default settings, saving to a temporary file.
echo "--- Starting JFR recording '$RECORDING_NAME' on PID $PID and saving to '$TEMP_FILENAME' ---"
jcmd "$PID" JFR.start name="$RECORDING_NAME" filename="$TEMP_FILENAME"

# Give the recording a moment to start, using the optional delay
echo "Sleeping for ${SLEEP_DELAY} seconds before stopping the recording via jcmd..."
STOP_CMD="jcmd $PID JFR.stop name=\"$RECORDING_NAME\""
echo "$STOP_CMD"
sleep "$SLEEP_DELAY"
echo "--- Stopping JFR recording '$RECORDING_NAME' ---"
eval "$STOP_CMD"

# Scrub the temporary recording to remove sensitive information6
# --exclude-events jdk.InitialSystemProperty,jdk.SystemProperty,jdk.InitialEnvironmentVariable,jdk.EnvironmentVariable \
echo "--- Scrubbing sensitive events from the recording ---"
jfr scrub \
    --exclude-events jdk.InitialEnvironmentVariable,jdk.EnvironmentVariable \
    "$TEMP_FILENAME" \
    "$OUTPUT_FILENAME"

# Remove the temporary, unscrubbed recording file
echo "--- Cleaning up temporary file: '$TEMP_FILENAME' ---"
rm "$TEMP_FILENAME"

echo "Script complete."
echo "Final, scrubbed recording saved to: $OUTPUT_FILENAME"

