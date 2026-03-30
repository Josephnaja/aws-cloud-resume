#!/bin/bash
set -euo pipefail

# ============ CONFIGURATION ============
STACK_NAME="josephnaja-website"
REGION="us-east-1"  # Must be us-east-1 for ACM + CloudFront
DOMAIN="josephnaja.com"
LAMBDA_BUCKET="josephnaja-lambda-artifacts"
HOSTED_ZONE_ID="Z06157363U3CBN4Q3S3NT"

if [[ -z "$LAMBDA_BUCKET" || -z "$HOSTED_ZONE_ID" ]]; then
  echo "ERROR: Set LAMBDA_BUCKET and HOSTED_ZONE_ID in this script first."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ============ 1. Package Lambda ============
echo "📦 Packaging Lambda function..."
python "$PROJECT_DIR/lambda/package.py"
LAMBDA_ZIP="$PROJECT_DIR/lambda/visitor_counter.zip"

# ============ 2. Upload Lambda zip to S3 ============
echo "⬆️  Uploading Lambda package to s3://$LAMBDA_BUCKET/visitor_counter.zip..."
aws s3 cp "$LAMBDA_ZIP" "s3://$LAMBDA_BUCKET/visitor_counter.zip" --region "$REGION"

# ============ 3. Deploy CloudFormation stack ============
echo "🚀 Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$SCRIPT_DIR/template.yaml" \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    DomainName="$DOMAIN" \
    HostedZoneId="$HOSTED_ZONE_ID" \
    LambdaCodeBucket="$LAMBDA_BUCKET" \
    LambdaCodeKey="visitor_counter.zip"

# ============ 4. Seed DynamoDB ============
echo "🌱 Seeding DynamoDB visitor counter..."
aws dynamodb put-item \
  --table-name visitor-counter \
  --item '{"id": {"S": "visitors"}, "visit_count": {"N": "0"}}' \
  --condition-expression "attribute_not_exists(id)" \
  --region "$REGION" 2>/dev/null || echo "   (Table already seeded, skipping)"

# ============ 5. Get outputs ============
echo "📋 Stack outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs" \
  --output table

BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" \
  --output text)

DIST_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" \
  --output text)

# ============ 6. Upload website files ============
echo "⬆️  Uploading website files to S3..."
echo "   Source: $PROJECT_DIR"
echo "   Destination: s3://$BUCKET"
aws s3 cp "$PROJECT_DIR/index.html" "s3://$BUCKET/index.html" --region "$REGION"
aws s3 cp "$PROJECT_DIR/style.css" "s3://$BUCKET/style.css" --region "$REGION"
aws s3 cp "$PROJECT_DIR/script.js" "s3://$BUCKET/script.js" --region "$REGION"
aws s3 cp "$PROJECT_DIR/photo.jpeg" "s3://$BUCKET/photo.jpeg" --region "$REGION"

# ============ 7. Invalidate CloudFront cache ============
echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*"

echo ""
echo "✅ Deployment complete! Your site will be live at https://$DOMAIN"
echo "   (ACM certificate validation + CloudFront propagation may take 10-30 minutes on first deploy)"
