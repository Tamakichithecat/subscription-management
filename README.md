# SubTrack Family

家族・グループで契約しているサブスクリプションを一元管理するiOSアプリ。

## 概要

- 家族グループでサブスクを共有・可視化
- 費用集計・多通貨対応（JPY / USD / EUR など）
- 更新日・解約日のプッシュ通知
- 相続を見越した契約者・支払い方法情報の一覧管理

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| iOS クライアント | Swift 5.9+ / SwiftUI / MVVM + Clean Architecture |
| バックエンド | Supabase（PostgreSQL / Auth / Realtime / Edge Functions） |
| プッシュ通知 | APNs（Apple Push Notification Service） |
| 為替レート | Open Exchange Rates API |

## ドキュメント

| ドキュメント | 説明 |
|------------|------|
| [要件定義書](docs/requirements.md) | 機能要件・非機能要件 |
| [システムアーキテクチャ設計書](docs/architecture.md) | 全体構成・技術スタック・セキュリティ設計 |
| [データモデル設計書](docs/data-model.md) | DB スキーマ・ER 図 |

## 開発ロードマップ

- **v1.0**: 手動登録・家族グループ・通知・多通貨・費用可視化
- **v1.1**: CSV インポート・検索強化・PDF エクスポート
- **v2.0**: メール・PDF 請求書からの自動読み取り
- **v2.1**: クレジットカード明細との連携

## 対応 OS

- iOS 16.0 以上
