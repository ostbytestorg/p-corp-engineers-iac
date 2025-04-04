#!/bin/bash
set -e  # Exit on error

# Directory containing app manifests (current directory)
APPS_DIR="$(dirname "$0")"

# Count number of YAML files
YAML_COUNT=$(find "$APPS_DIR" -maxdepth 1 -name "*.yaml" -o -name "*.yml" | wc -l)
if [ "$YAML_COUNT" -eq 0 ]; then
  echo "Warning: No YAML files found in $APPS_DIR"
  exit 0
fi

echo "Found $YAML_COUNT application manifests to apply"

# Process each YAML file
for yaml_file in "$APPS_DIR"/*.y*ml; do
  # Skip processing if the file doesn't exist
  # (This can happen if there are no yaml/yml files)
  [ -e "$yaml_file" ] || continue
  
  echo "----------------------------------------"
  echo "Applying manifest: $yaml_file"
  
  # Extract app name from the file for logging
  APP_NAME=$(basename "$yaml_file" | sed 's/\.yaml$//' | sed 's/\.yml$//')
  echo "Application: $APP_NAME"
  
  # Apply the manifest
  kubectl apply -f "$yaml_file"
  
  echo "Application $APP_NAME manifest applied successfully"
done

echo "----------------------------------------"
echo "All infrastructure application manifests applied successfully"