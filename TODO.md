# TODO - Claude Code Pong

このプロジェクトのタスク管理。**作業開始時に必ず確認すること。**

## 進行中

- [ ] Step 1（スケルトン）から cc-pong.asm 制作開始

## 次にやる（優先順）

1. [x] **ステップ計画の設計** → `STEP_PLAN.md`（ルート）に保存済み
   - 10コアステップ + 2仕上げ（Phase A〜F）
   - APONG式カーネル前提

3. [ ] **cc-pong.asm 制作開始**
   - `STEP_PLAN.md` に沿ってステップ1から
   - 各ステップ完了ごとにユーザーがStellaで確認 → OKでコミット

## 完了

- [x] 02.asm / 02.bin をルートから削除（archive/terminal_02と重複）
- [x] archive/ を terminal_01 / terminal_02 / claude.ai_ver に整理
- [x] docs/, docs_reference/ を docs_atari/, docs_pong/ にリネーム
- [x] グローバル CLAUDE.md に「整理整頓と標準化の重視」を追記
- [x] STEP_PLAN.md 作成（10コア+2仕上げ）
- [x] Git初期化 & GitHub接続（main をデフォルトブランチ化、参考資料はローカルのみ）

## アイデア・保留事項

- 26→18ステップへスリム化案を出したが、APONG式採用で再考が必要
- サウンドは Video Olympics の効果音をできれば録音参考にしたい
- 完成後 Stella で他人にも遊んでもらいたい

## 参考資料へのリンク

- `docs_pong/AtariAge/APongJuly02.bin` - **再現ターゲットROM**（2026-05-29決定）
- `docs_pong/AtariAge/APONG09302005.asm` - **参考ソース**（同じAPONG実装）
- `docs_pong/Video Olympics.bin` - 元の候補（上下ラインあり、対象外に変更）
- `docs_atari/` - Atari 2600 全般リファレンス
- メモリ（自動読込）: project_goal_video_olympics, feedback_pong_implementation 他
