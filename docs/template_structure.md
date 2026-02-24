# CloudFormation テンプレート構成

CloudFormation テンプレートは以下のセクションで構成されます。
`Resources` のみ必須で、それ以外は任意です。

---

## セクション一覧

| セクション | 必須 | 概要 |
|---|:---:|---|
| `AWSTemplateFormatVersion` | - | テンプレートのバージョン（固定値） |
| `Description` | - | テンプレートの説明文 |
| `Metadata` | - | コンソール表示などのメタ情報 |
| `Parameters` | - | 実行時に渡す変数を定義 |
| `Conditions` | - | リソース作成の条件を定義 |
| `Mappings` | - | キーと値のマッピングテーブル |
| `Rules` | - | パラメータの検証ルール |
| `Resources` | **必須** | AWS リソースを定義 |
| `Outputs` | - | スタックの出力値を定義 |

---

## 各セクションの詳細

### AWSTemplateFormatVersion
テンプレートのフォーマットバージョンを指定します。現在は `"2010-09-09"` のみ有効です。

```yaml
AWSTemplateFormatVersion: "2010-09-09"
```

> 参考: https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/format-version-structure.html

---

### Description
テンプレートの説明を記述します。最大 **1024 バイト**まで記述できます。

```yaml
Description: "このテンプレートは VPC と EC2 を作成します。"
```

---

### Metadata
CloudFormation コンソールの見た目や動作を制御するメタ情報を定義します。
代表的な用途として `AWS::CloudFormation::Interface` によるパラメータグループの整理があります。

```yaml
Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label:
          default: "ネットワーク設定"
        Parameters:
          - VpcCidr
          - SubnetCidr
```

---

### Parameters
スタック作成・更新時に外部から値を渡すための変数を定義します。

```yaml
Parameters:
  EnvType:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - stg
      - prod
    Description: "デプロイ環境を選択してください。"
```

主なプロパティ:

| プロパティ | 説明 |
|---|---|
| `Type` | データ型（`String`, `Number`, `List<Number>` など） |
| `Default` | デフォルト値 |
| `AllowedValues` | 許可する値のリスト |
| `Description` | パラメータの説明 |
| `NoEcho` | `true` にするとコンソールにマスク表示（パスワードなど） |

---

### Conditions
パラメータ値などに基づいて、リソースを作成するかどうかの条件を定義します。
`Resources` や `Outputs` で `Condition` キーを使って参照します。

```yaml
Conditions:
  IsProd: !Equals [!Ref EnvType, prod]
```

---

### Mappings
リージョンや環境などのキーに対応する値をテーブル形式で定義します。
`!FindInMap` 関数で値を参照します。

```yaml
Mappings:
  RegionMap:
    ap-northeast-1:
      AMI: ami-0abcdef1234567890
    us-east-1:
      AMI: ami-0fedcba9876543210
```

```yaml
# 参照例
ImageId: !FindInMap [RegionMap, !Ref AWS::Region, AMI]
```

---

### Rules
パラメータの組み合わせや値を検証するルールを定義します。
条件を満たさない場合、スタックの作成・更新が拒否されます。

```yaml
Rules:
  ProdRequiresApproval:
    RuleCondition: !Equals [!Ref EnvType, prod]
    Assertions:
      - Assert: !Equals [!Ref ApprovalFlag, "true"]
        AssertDescription: "本番環境へのデプロイには ApprovalFlag=true が必要です。"
```

---

### Resources
**唯一の必須セクション**です。作成する AWS リソースをすべてここに定義します。

```yaml
Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: my-sample-bucket
      VersioningConfiguration:
        Status: Enabled
```

各リソースの `Properties` はリソースタイプによって異なります。
> 参考: https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/aws-template-resource-type-ref.html

---

### Outputs
スタックの出力値を定義します。
コンソールや CLI で確認できるほか、`Fn::ImportValue` を使ってクロススタック参照が可能です。

```yaml
Outputs:
  BucketName:
    Description: "作成された S3 バケット名"
    Value: !Ref MyBucket
    Export:
      Name: !Sub "${AWS::StackName}-BucketName"
```

> 参考: https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/outputs-section-structure.html
