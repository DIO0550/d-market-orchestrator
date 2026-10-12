# Task: {目的を簡潔に記述}

## Implementation

- □ {実装タスク1}
- □ {実装タスク2}
- □ {実装タスク3}

<!--
構成ルール:

- 「## Implementation」は planner が書く、ループの 1 回目に implementer が上から実装する順番
- 2 回目以降は implementer が「## Loop {n}: 修正」を末尾に足し、その回のやること（未達の完了条件・採用された指摘・落ちた検査）を □ で並べてから実装する
- 未完了は行頭 □、完了は ■。implementer がタスクを終えるたびに更新する（まとめて更新しない）
- 検証（完了条件の判定）は goal-checker が行うので、ここには Verification を置かない
- TDD 構成: テスト主導が有効な場合は、機能単位 → RED / GREEN / REFACTOR のサブタスクで構成する
  （順序: シンプルな正常系 → バリエーション → 境界値 → 異常系・エッジケース）
- タスクは 1 ファイル 1 変更程度まで分割し、各行に明確な完了条件を持たせる

使用例:

# Task: Implement Block Button on Ranking Page

## Implementation

- □ Create content script for Ranking Page
  - □ RED: ブロックボタンが注入されるテストを書く
  - □ GREEN: injectBlockButtons を実装する
  - □ REFACTOR: watch.ts と共通の注入処理を寄せる
- □ Extract User ID from DOM
- □ Connect button to Blocklist Storage

## Loop 2: 修正

- □ C-2 未達: ブロック後に一覧から消えない（goal-checker: npm test -- ranking が 1 件失敗）
- □ L1-03 採用: ID 抽出の正規表現が数字以外も拾う
-->
