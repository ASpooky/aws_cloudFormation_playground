# デプロイフロー（SAM CLI）

SAM CLI を使って Lambda スタックを AWS にデプロイするまでの手順をまとめます。

---

## 全体の流れ

```
① sam build
      ↓
② sam deploy
```

SAM CLI がデプロイ用 S3 バケットの作成・管理を自動で行うため、事前に S3 バケットを用意する必要はありません。

---

## 前提条件

- AWS CLI がインストール済みで認証が通っていること
- SAM CLI がインストール済みであること（`sam --version` で確認）
- 対象リージョンへのアクセス権限を持つ IAM ユーザー/ロールを使用していること
- 以下の権限が必要
  - `s3:*`（SAM が内部で使う S3 バケットの管理）
  - `cloudformation:*`
  - `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole`
  - `lambda:*`

---

## ① sam build

Lambda 関数のソースコードをパッケージングします。

```bash
sam build
```

- `src/lambda/` のソースコードが `.aws-sam/build/` にビルドされます
- デプロイ前に必ず実行してください

---

## ② sam deploy

CloudFormation スタックとして AWS にデプロイします。

```bash
sam deploy
```

設定は `samconfig.toml` に保存されているため、追加の引数は不要です。

### 初回実行時（samconfig.toml がない場合）

```bash
sam deploy --guided
```

対話形式で設定を入力すると `samconfig.toml` が自動生成されます。

| 項目 | 説明 |
|---|---|
| `stack_name` | CloudFormation スタック名（例: `sam-app`） |
| `resolve_s3 = true` | SAM が自動でデプロイ用 S3 バケットを作成・管理 |
| `s3_prefix` | S3 バケット内のプレフィックス |
| `capabilities = CAPABILITY_IAM` | IAM リソースを含む場合に必須 |
| `region` | デプロイ先リージョン（例: `ap-northeast-1`） |

---

## デプロイ後の確認

### スタックの状態確認

```bash
aws cloudformation describe-stacks \
  --stack-name sam-app \
  --region ap-northeast-1 \
  --query "Stacks[0].StackStatus"
```

### Lambda Function URL の確認

```bash
aws cloudformation describe-stacks \
  --stack-name sam-app \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs"
```

### Lambda の動作確認

```bash
aws lambda invoke \
  --function-name my-func \
  --region ap-northeast-1 \
  /tmp/response.json && cat /tmp/response.json
```

---

## スタック構成

```
sam-app（CloudFormation スタック）
  ├─ MySampleBucket（S3 バケット）
  ├─ MyFunctionRole（IAM ロール）
  └─ MyFunction（Lambda 関数 + Function URL）
```

`samconfig.toml` が管理する別スタック:
```
aws-sam-cli-managed-default（SAM が自動作成）
  └─ デプロイ用 S3 バケット（Lambda コードのアップロード先）
```

---

## トラブルシューティング

デプロイ失敗時は [troubleshooting.md](./troubleshooting.md) を参照してください。

よくある失敗原因:
- 同名のリソース（Lambda 関数名など）が別スタックに存在する → リソース名の競合
- `sam build` を実行せずに `sam deploy` した → ソースコードが古いまま
