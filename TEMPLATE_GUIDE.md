# ポートフォリオテンプレート使い方ガイド

このガイドでは、HTML/CSSの知識がなくても簡単にポートフォリオページを編集できる方法を説明します。

## 📁 ファイル構成

- **app/views/pages/index.html.erb** - ページの内容を編集するファイル（ここを主に編集します）
- **app/assets/stylesheets/portfolio.css** - デザイン用のCSSファイル（基本的に編集不要）

---

## ✏️ 基本的な編集方法

### 1. テキストを変更する

`app/views/pages/index.html.erb` を開いて、**「★ここを変更★」** というコメントの下の部分を編集してください。

**例：タイトルを変更する**
```erb
<%# ★ここを変更★ メインタイトル %>
<h1>Elie の Ruby on Rails 学習記録 (･ω･)</h1>
```

↑ `<h1>` と `</h1>` の間のテキストだけを変更します：
```erb
<h1>あなたの名前 の学習記録</h1>
```

### 2. リストに項目を追加・削除する

リスト項目は `<li>...</li>` で囲まれています。

**項目を追加する場合：**
```erb
<ul class="topic-list">
  <li>既存の項目1</li>
  <li>既存の項目2</li>
  <li>新しい項目</li>  ← この行をコピー&ペーストして追加
</ul>
```

**項目を削除する場合：**
削除したい `<li>...</li>` の行全体を削除してください。

### 3. リンクを追加・変更する

リンクは以下の形式になっています：

```erb
<a href="リンク先のURL">表示されるテキスト</a>
```

**例：新しいリンクを追加**
```erb
<ul class="link-list">
  <li>
    <a href="/guides/ruby_overview">Rubyってなに？(゜-゜)</a>
  </li>
  <li>
    <a href="/新しいページのURL">新しいページ名</a>
  </li>
</ul>
```

### 4. 新しいセクションを追加する

ファイルの最後にテンプレートがあります。これをコピー&ペーストして使ってください：

```erb
<hr class="divider">

<h2 class="section-title">
  新しいセクションのタイトル
</h2>

<div class="text-block">
  <p>ここに説明文を書きます</p>
</div>
```

このテンプレートを `</div>` (メインコンテンツ終了) の**前**に貼り付けて、内容を編集します。

---

## 🎨 使用できるスタイル

### 1. 通常のテキストブロック
```erb
<div class="text-block">
  <p>ここに文章を書きます</p>
  <p>複数の段落を書けます</p>
</div>
```

### 2. ハイライト（黄色マーカー）
```erb
<span class="highlight">重要なテキスト</span>
```

### 3. コードブロック
```erb
<pre class="code-block">$ コマンドやコードをここに書く
結果もここに表示</pre>
```

### 4. 区切り線
```erb
<hr class="divider">
```

---

## 📝 編集時の注意点

### ✅ やってもOK
- `<h1>`, `<p>`, `<li>` などのタグの**中身のテキスト**を変更する
- `<li>...</li>` をコピー&ペーストしてリスト項目を増やす
- `href="..."` の中のURLを変更する
- セクション全体をコピー&ペーストして新しいセクションを作る

### ❌ やってはダメ
- `<div class="...">` などのHTMLタグ自体を削除する
- `class="..."` の部分を変更する（デザインが崩れます）
- `<%# コメント %>` の行を削除する（ガイドとして残しておくと便利です）

---

## 🔧 よくある質問

### Q1: 編集したのにページが変わらない
A: ブラウザをリロード（F5キー）してください。キャッシュが残っている場合は、強制リロード（Ctrl+F5 または Cmd+Shift+R）を試してください。

### Q2: デザインを変更したい
A: `app/assets/stylesheets/portfolio.css` を編集してください。ただし、CSSの知識が必要です。

### Q3: レイアウトが崩れてしまった
A: HTMLタグを間違って削除した可能性があります。バックアップから復元するか、gitで元に戻してください：
```bash
git checkout app/views/pages/index.html.erb
```

### Q4: 新しいページを作りたい
A: 以下の手順が必要です：
1. `app/views/pages/` に新しい `.html.erb` ファイルを作成
2. `app/controllers/pages_controller.rb` にアクションを追加
3. `config/routes.rb` にルートを追加

---

## 💡 編集例

### 例1: タイトルと説明を変更する

**変更前：**
```erb
<h1>Elie の Ruby on Rails 学習記録 (･ω･)</h1>
<p class="subtitle">
  このWebサイトではElieが Ruby on Rails の学んだことを記録していて、<br>
  今後Ruby on Railsを学ぶ方のために少しでも参考になればと思います(･ω･)
</p>
```

**変更後：**
```erb
<h1>田中太郎のプログラミング日記</h1>
<p class="subtitle">
  プログラミング初心者の学習記録です。<br>
  同じように学んでいる方の参考になれば嬉しいです！
</p>
```

### 例2: リストに項目を追加する

**変更前：**
```erb
<ul class="topic-list">
  <li>Rubyってなに？</li>
  <li>MVCとは？</li>
</ul>
```

**変更後：**
```erb
<ul class="topic-list">
  <li>Rubyってなに？</li>
  <li>MVCとは？</li>
  <li>Gitの使い方</li>
  <li>デプロイの方法</li>
</ul>
```

---

## 🚀 さらに詳しく学びたい方へ

- [HTML基礎](https://developer.mozilla.org/ja/docs/Web/HTML)
- [CSS基礎](https://developer.mozilla.org/ja/docs/Web/CSS)
- [Rails View入門](https://railsguides.jp/layouts_and_rendering.html)

---

何か分からないことがあれば、このファイルを参考にしてください！
