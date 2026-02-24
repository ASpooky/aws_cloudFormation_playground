# デプロイフロー

Lambda スタックを AWS にデプロイするまでの手順をまとめます。

---

## 全体の流れ

```
① デプロイ用 S3 バケットの確認・作成
        ↓
② iam-policy.yaml を S3 にアップロード
        ↓
③ lambda-stack.yaml を CloudFormation でデプロイ
```

---

## 前提条件

- AWS CLI がインストール済みで認証が通っていること
- 対象リージョンへのアクセス権限を持つ IAM ユーザー/ロールを使用していること
- 以下の権限が必要
  - `s3:CreateBucket`, `s3:PutObject`, `s3:GetObject`
  - `cloudformation:*`
  - `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole`
  - `lambda:CreateFunction`, `lambda:UpdateFunctionCode`

---

## ① デプロイ用 S3 バケットの確認・作成

CloudFormation のネストスタックはテンプレートを S3 から読み込む必要があります。
テンプレート格納専用の S3 バケットを用意します。

```bash
DEPLOY_BUCKET="<デプロイ用バケット名>"
REGION="ap-northeast-1"

# バケットの存在確認
if aws s3api head-bucket --bucket "${DEPLOY_BUCKET}" 2>/dev/null; then
  echo "バケットは既に存在します: ${DEPLOY_BUCKET}"
else
  echo "バケットを作成します: ${DEPLOY_BUCKET}"
  aws s3api create-bucket \
    --bucket "${DEPLOY_BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"

  # バージョニングを有効化
  aws s3api put-bucket-versioning \
    --bucket "${DEPLOY_BUCKET}" \
    --versioning-configuration Status=Enabled
fi
```

> **注意**: バケット名はグローバルで一意である必要があります。

---

## ② iam-policy.yaml を S3 にアップロード

ネストスタックとして参照するテンプレートをアップロードします。
すでにアップロード済みの場合はスキップします。

```bash
S3_KEY="templates/iam-policy.yaml"

if aws s3 ls "s3://${DEPLOY_BUCKET}/${S3_KEY}" 2>/dev/null | grep -q "iam-policy.yaml"; then
  echo "iam-policy.yaml は既に存在します。スキップします。"
else
  echo "iam-policy.yaml をアップロードします。"
  aws s3 cp src/iam-policy.yaml "s3://${DEPLOY_BUCKET}/${S3_KEY}"
fi
```

---

## ③ lambda-stack.yaml を CloudFormation でデプロイ

```bash
aws cloudformation deploy \
  --template-file src/lambda-stack.yaml \
  --stack-name my-lambda-stack \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    TemplateBucketName="${DEPLOY_BUCKET}"
```

- `CAPABILITY_NAMED_IAM`: IAM リソース（名前付きロール）を含むため必須
- デプロイ済みスタックへの再実行は差分更新になります

### 状態確認

```bash
aws cloudformation describe-stacks \
  --stack-name my-lambda-stack \
  --query "Stacks[0].StackStatus"
```

---

## CI/CD による自動デプロイ

GitHub Actions の `production` 環境を使った自動デプロイが設定されています。
詳細は `.github/workflows/deploy.yml` を参照してください。

### 必要な GitHub 設定

リポジトリの `Settings > Environments > production` に以下を設定します。

| 種別 | キー | 説明 |
|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` | AWS アクセスキー ID |
| Secret | `AWS_SECRET_ACCESS_KEY` | AWS シークレットアクセスキー |
| Variable | `AWS_REGION` | デプロイ先リージョン（例: `ap-northeast-1`） |
| Variable | `DEPLOY_BUCKET_NAME` | デプロイ用 S3 バケット名 |
| Variable | `CFN_STACK_NAME` | CloudFormation スタック名（例: `my-lambda-stack`） |

### トリガー

| イベント | 動作 |
|---|---|
| `main` ブランチへの push | 自動デプロイ |
| Actions 画面からの手動実行 | 手動デプロイ |

---

## ネストスタック構成

```
lambda-stack.yaml（親スタック）
  ├─ S3 バケット（Lambda コード格納用）
  ├─ IamPolicyStack（ネストスタック）
  │    └─ iam-policy.yaml（子テンプレート）
  │         └─ LambdaExecutionPolicy（マネージドポリシー）
  ├─ MylambdaRole（IAM ロール）
  │    └─ ↑ のポリシーをアタッチ
  └─ Lambda 関数
       └─ ↑ のロールを使用
```
