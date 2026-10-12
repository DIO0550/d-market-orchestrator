# フェーズ 2: 目標確定

`SKILL.md` から、このフェーズに入るときに 1 回だけ読む。記号（`{dir}` `{TPL}` `{REF}` `{ISSUE}`）の意味とエスカレーション条件（A〜D、[../escalation-and-resume.md](../escalation-and-resume.md)）は `SKILL.md` から辿る。

## フェーズ 2: 目標確定（ユーザーと一緒に）

`goal.md` の要約（ゴール・完了条件の一覧・スコープ外）と、`implementation-plan.md` の概要と設計判断（ADR）を 3〜5 行で提示する（詳細はファイルを開いてもらう）。

1. 「未解決の確認事項」の `□` を AskUserQuestion で解消して `■` にする（回答を併記する）
2. AskUserQuestion で次を**1 回で**聞く

```yaml
- question: "この目標（完了条件）で確定し、満たすまでループして PR まで進めてよいですか？（以降は目標が揺らぐ・不可逆な操作・行き詰まりのときだけ確認します）"
  header: "目標の確定"
  options:
    - label: "確定して進める"
      description: "完了条件がすべて満たされるまでループし、PR を作って報告する"
    - label: "目標を直したい"
      description: "完了条件・スコープを直してから、もう一度確定を取る"
- question: "PR のベースブランチと、ループの上限はどうしますか？"
  header: "PR / 上限"
  options:
    - label: "{既定ブランチ} / 5 回（推奨）"
      description: "上限に達したら、残った条件と理由を示して確認する"
    - label: "{既定ブランチ} / 10 回"
      description: "大きめの変更向け"
```

- 開始時にユーザーの未コミットの変更があれば、扱い（含めない / 先にユーザーが退避する）も同じ質問の束で聞く
- 「目標を直したい」→ 回答を `goal.md` に反映して 1 に戻る（計画が変わるなら planner に直させる）
- 確定したら:
  1. `goal.md` の `**ステータス**:` を `■ 確定` に、「実行設定」に回答を書く（`check-goal.sh` が `□` の残りと確かめ方の欠けを止める）
  2. `echo looping > {dir}/STATE`（ここから run フォルダの外へ書ける。git 操作もこの後に行う）
  3. 今のブランチがベースブランチなら作業ブランチを切る（`git switch -c harness/{nnn}-{name}`）
  4. `git rev-parse HEAD > {dir}/BASE`
  5. 「完了したら PR で報告する。途中経過は `{dir}/loop-log.md` と `decisions.md` で追える。止まらずに回すには、テスト・lint の実行を許可するパーミッションが要る」と 1 行添える
