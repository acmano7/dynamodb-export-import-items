# DynamoDB Export/Import Items

This script simplifies the export and import of data by extracting items from a small source table and importing them into a destination table.

## Notes

- This script uses DynamoDB's `scan` operation, which may be subject to throughput limits
- For large tables, consider AWS solutions (e.g., S3 bucket)
- This script does not handle table creation; ensure that the destination table exists before running it
- This script should be used for tables within the same AWS account.

## Prerequisites

- AWS CLI version 2 or later installed and configured with appropriate credentials
- `jq` command-line JSON processor
- `bc` command-line calculator
- Appropriate AWS IAM permissions to read from source table and write to destination table

## Usage

1. Make the script executable:
   ```bash
   chmod +x dynamodb-export-import-items.sh
   ```

2. Run the script:
   ```bash
   ./dynamodb-export-import-items.sh
   ```

You will be prompted to enter:
- Source table name and region
- Destination table name and region
- Temporary directory location for storing items

## How the Script Works

1. Creates a temporary directory to store exported items
2. Downloads all items from the source DynamoDB table
3. Counts the total number of items
4. Saves each item as a separate JSON file
5. Imports each item into the destination table

## Temporary Files

The script creates a temporary directory (named dynamo_items by default), containing:
- `all_items.json`: Complete export of all items
- Individual JSON files for each item (e.g., `item_001.json`, `item_002.json`, etc.)

Note: These files are not automatically cleaned up after the script completes.

