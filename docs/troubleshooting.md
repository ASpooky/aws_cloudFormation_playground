# トラブルシューティング

SAM CLI / CloudFormation のデプロイで発生した問題と解決策をまとめます。

---

## リソース名の競合による changeset 失敗

### エラーメッセージ

```
Error: Failed to create changeset for the stack: sam-app, ex: Waiter ChangeSetCreateComplete failed:
Waiter encountered a terminal failure state: For expression "Status" we matched expected path: "FAILED"
Status: FAILED. Reason: The following hook(s)/validation failed:
[AWS::EarlyValidation::ResourceExistenceCheck].
```

### 原因

`template.yaml` に `FunctionName: my-func` のように**リソース名を明示している**場合、
同名のリソースが別のスタックにすでに存在すると CloudFormation の Early Validation で弾かれる。

```
既存スタック: my-lambda-stack ─── my-func（Lambda）
新規スタック: sam-app         ─── my-func（Lambda）← 衝突！
```

> **Early Validation とは**
> changeset 作成前に AWS が実施する事前チェック。デプロイを試みる前に既存リソースとの競合を検出する。

### 解決策

#### A. 古いスタックを削除してから再デプロイ（不要なスタックの場合）

```bash
aws cloudformation delete-stack --stack-name <古いスタック名> --region ap-northeast-1
# 削除完了を待ってから
sam deploy
```

#### B. `FunctionName` を省略して自動生成名にする（複数環境で使いまわす場合）

```yaml
# ❌ 明示するとスタックをまたいで競合する
FunctionName: my-func

# ✅ 省略すると CloudFormation が一意な名前を自動生成（例: sam-app-MyFunction-XXXX）
# FunctionName: の行ごと削除する
```

#### C. 環境名をプレフィックスにして名前を分ける

```yaml
Parameters:
  Environment:
    Type: String
    Default: dev

Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub "${Environment}-my-func"
```

### 確認コマンド

競合しているスタック・関数を事前に調べる:

```bash
# 既存のスタック一覧
aws cloudformation list-stacks \
  --region ap-northeast-1 \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query "StackSummaries[*].[StackName,StackStatus]" \
  --output table

# 対象の Lambda 関数がどのスタックに属するか
aws lambda get-function --function-name my-func --region ap-northeast-1
```

---

## Lambda Function URL が 403 Forbidden を返す

### 症状

デプロイは成功しているが、Function URL にアクセスすると 403 が返る。

```json
{"Message":"Forbidden. For troubleshoooting Function URL authorization issues, see: ..."}
```

`aws lambda invoke` で直接呼び出すと正常に動作する。

### 原因

`AWS::Lambda::Url` + `AWS::Lambda::Permission` を別リソースとして定義すると、
URL と権限の紐付けが意図通りに機能しないケースがある。

### 解決策

SAM ネイティブの `FunctionUrlConfig` を使う。URL の作成と公開権限を SAM が自動的に正しく設定してくれる。

```yaml
# ❌ 別リソースとして定義する方法（競合が起きやすい）
MyFunction:
  Type: AWS::Serverless::Function
  Properties:
    ...

MyFunctionUrlResource:
  Type: AWS::Lambda::Url
  Properties:
    TargetFunctionArn: !Ref MyFunction
    AuthType: NONE

MyFunctionUrlPermission:
  Type: AWS::Lambda::Permission
  Properties:
    FunctionName: !Ref MyFunction
    Action: lambda:InvokeFunctionUrl
    Principal: "*"
    FunctionUrlAuthType: NONE

# ✅ FunctionUrlConfig を使う（SAM 推奨）
MyFunction:
  Type: AWS::Serverless::Function
  Properties:
    ...
    FunctionUrlConfig:
      AuthType: NONE
```

Output の取得方法も変わる:

```yaml
Outputs:
  FunctionUrl:
    # ❌ 別リソースから取得する場合
    Value: !GetAtt MyFunctionUrlResource.FunctionUrl

    # ✅ FunctionUrlConfig を使った場合
    Value: !GetAtt MyFunction.FunctionUrl
```
