#!/bin/bash

set -e

# Validate AWS credentials first
echo "Validating AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "\033[31mERROR: AWS credentials are not valid or not configured. Please configure your AWS credentials and try again.\033[0m"
    exit 1
fi
echo -e "\033[32mAWS credentials validated successfully!\033[0m"

# Function to get table information
table() {
    type=$1

    # Loop until valid input is received
    while true; do
        echo -n "Enter the $type table name: "
        read TABLE_NAME
        echo -n "Enter the $type table region (e.g., us-east-1): "
        read TABLE_REGION

        # Check if both values are provided
        if [ -z "$TABLE_NAME" ] || [ -z "$TABLE_REGION" ]; then
            echo -e "\033[31mERROR: $type table name or region cannot be empty. Please try again.\033[0m"
            continue
        fi

        # Validate the table existence
        echo "Validating table existence..."
        if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$TABLE_REGION" &>/dev/null; then
            echo -e "\033[32mTable validation successful!\033[0m"
            break
        else
            echo -e "\033[31mERROR: Table '$TABLE_NAME' does not exist in region $TABLE_REGION. Please try again.\033[0m"
        fi
    done
}

# Source table
echo "Starting to collect source table information..."
table "source"
SOURCE_TABLE=$TABLE_NAME
SOURCE_TABLE_REGION=$TABLE_REGION

# Destination table
echo "Starting to collect destination table information..."
table "destination"
DEST_TABLE=$TABLE_NAME
DEST_TABLE_REGION=$TABLE_REGION

echo -n "Enter the temporary directory (default: dynamo_items): "
read TMP_DIR
TMP_DIR=${TMP_DIR:-dynamo_items}

# Confirm before proceeding
echo -n "Enter 'y' or 'Y' to proceed with export and import, or any other key to cancel: "
read CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Migration cancelled by user."
    exit 0
fi

# Create temporary directory
mkdir -p "$TMP_DIR"

# Step 1: Download all items from the original table
echo "Downloading data from $SOURCE_TABLE in region $SOURCE_TABLE_REGION..."
aws dynamodb scan --table-name "$SOURCE_TABLE" --region "$SOURCE_TABLE_REGION" --output json > "$TMP_DIR/all_items.json"

# Step 2: Count the number of items
ITEM_COUNT=$(jq '.Items | length' "$TMP_DIR/all_items.json")
echo "Items: $ITEM_COUNT"

# Step 3: Calculate the width needed for the numbering
WIDTH=$(echo "scale=0; l($ITEM_COUNT)/l(10)" | bc -l | awk '{print int($1)+1}')
echo "Calculated width for numbering: $WIDTH"

# Step 4: Separate each item into an individual JSON file
echo "Separating items..."
jq -c '.Items[]' "$TMP_DIR/all_items.json" | nl -n rz -w $WIDTH | while read -r line; do
    index=$(echo "$line" | awk '{print $1}')
    item_json=$(echo "$line" | sed 's/^[0-9]\+\s//')
    echo "$item_json" > "$TMP_DIR/item_$index.json"
done

# Step 5: Recreate the items in the destination table
echo "Inserting items into the table $DEST_TABLE in region $DEST_TABLE_REGION..."
for file in "$TMP_DIR"/item_*.json; do
    aws dynamodb put-item --table-name "$DEST_TABLE" --region "$DEST_TABLE_REGION" --item file://"$file"
done

echo "Process completed!"
