#!/usr/bin/env bash
set -euo pipefail

REPO="ASpooky/aws_cloudFormation_playground"

# ── 環境名の入力 ──────────────────────────────────────────
echo -n "development environment name [development]: "
read input_dev_name
dev_env="${input_dev_name:-development}"

echo -n "production environment name [production]: "
read input_prod_name
prod_env="${input_prod_name:-production}"

echo ""
echo "dev  environment : ${dev_env}"
echo "prod environment : ${prod_env}"

# ── デプロイブランチ名の入力 ──────────────────────────────
echo ""
echo -n "Deploy branch for ${dev_env} [develop]: "
read input_dev_branch
dev_branch="${input_dev_branch:-develop}"

echo -n "Deploy branch for ${prod_env} [main]: "
read input_prod_branch
prod_branch="${input_prod_branch:-main}"

# ── AWS 設定の入力 ────────────────────────────────────────
echo ""
echo -n "AWS_REGION [ap-northeast-1]: "
read input_region
aws_region="${input_region:-ap-northeast-1}"

echo -n "DEPLOY_BUCKET_NAME for ${dev_env} [my-cfn-dev-bucket]: "
read dev_bucket
dev_bucket="${dev_bucket:-my-cfn-dev-bucket}"

echo -n "CFN_STACK_NAME for ${dev_env} [my-lambda-stack-dev]: "
read dev_stack
dev_stack="${dev_stack:-my-lambda-stack-dev}"

echo -n "DEPLOY_BUCKET_NAME for ${prod_env} [my-cfn-deploy-bucket]: "
read prod_bucket
prod_bucket="${prod_bucket:-my-cfn-deploy-bucket}"

echo -n "CFN_STACK_NAME for ${prod_env} [my-lambda-stack]: "
read prod_stack
prod_stack="${prod_stack:-my-lambda-stack}"

# ── シークレットの入力 ────────────────────────────────────
echo ""
echo -n "AWS_ACCESS_KEY_ID (repository secret): "
read -s aws_key_id
echo ""

echo -n "AWS_SECRET_ACCESS_KEY (repository secret): "
read -s aws_secret_key
echo ""

# ── GitHub 環境の作成 ─────────────────────────────────────
echo ""
echo "Creating environments..."
gh api "repos/${REPO}/environments/${dev_env}"  --method PUT --silent
gh api "repos/${REPO}/environments/${prod_env}" --method PUT --silent
echo "  ✓ ${dev_env}, ${prod_env}"

# ── デプロイブランチポリシーの設定 ───────────────────────
echo "Setting deployment branch policies..."

# カスタムブランチポリシーを有効化
echo "{\"deployment_branch_policy\":{\"protected_branches\":false,\"custom_branch_policies\":true}}" \
  | gh api "repos/${REPO}/environments/${dev_env}"  --method PUT --input - --silent
echo "{\"deployment_branch_policy\":{\"protected_branches\":false,\"custom_branch_policies\":true}}" \
  | gh api "repos/${REPO}/environments/${prod_env}" --method PUT --input - --silent

# 許可ブランチを登録（既存ポリシーがある場合はスキップ）
gh api "repos/${REPO}/environments/${dev_env}/deployment-branch-policies" \
  --method POST --silent -f "name=${dev_branch}" 2>/dev/null \
  || echo "  (${dev_env}: policy for '${dev_branch}' already exists)"

gh api "repos/${REPO}/environments/${prod_env}/deployment-branch-policies" \
  --method POST --silent -f "name=${prod_branch}" 2>/dev/null \
  || echo "  (${prod_env}: policy for '${prod_branch}' already exists)"

echo "  ✓ ${dev_env} <- ${dev_branch}, ${prod_env} <- ${prod_branch}"

# ── 変数の設定 ────────────────────────────────────────────
echo "Setting variables..."

gh variable set AWS_REGION         --env "${dev_env}"  --body "${aws_region}"  --repo "${REPO}"
gh variable set DEPLOY_BUCKET_NAME --env "${dev_env}"  --body "${dev_bucket}"  --repo "${REPO}"
gh variable set CFN_STACK_NAME     --env "${dev_env}"  --body "${dev_stack}"   --repo "${REPO}"

gh variable set AWS_REGION         --env "${prod_env}" --body "${aws_region}"  --repo "${REPO}"
gh variable set DEPLOY_BUCKET_NAME --env "${prod_env}" --body "${prod_bucket}" --repo "${REPO}"
gh variable set CFN_STACK_NAME     --env "${prod_env}" --body "${prod_stack}"  --repo "${REPO}"

echo "  ✓ variables set for ${dev_env} and ${prod_env}"

# ── シークレットの設定（リポジトリ共通） ──────────────────
echo "Setting repository secrets..."
gh secret set AWS_ACCESS_KEY_ID     --body "${aws_key_id}"     --repo "${REPO}"
gh secret set AWS_SECRET_ACCESS_KEY --body "${aws_secret_key}" --repo "${REPO}"
echo "  ✓ secrets set"

echo ""
echo "Done! Check: https://github.com/${REPO}/settings/environments"
