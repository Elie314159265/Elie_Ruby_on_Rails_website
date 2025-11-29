# ポートフォリオサイト テンプレート完全ガイド

このガイドでは、HTML/CSSの知識が少なくても、新しい記事ページを作成・更新できる方法を詳しく説明します。

---

## 📋 目次

1. [テンプレートの構造](#テンプレートの構造)
2. [新しい記事ページを作成する手順](#新しい記事ページを作成する手順)
3. [Tailwind CSSの基本](#tailwind-cssの基本)
4. [よく使うコンポーネント](#よく使うコンポーネント)
5. [実践例：記事ページの作成](#実践例記事ページの作成)
6. [トラブルシューティング](#トラブルシューティング)

---

## テンプレートの構造

### 📁 ファイル構成

```
app/
├── views/
│   ├── layouts/
│   │   └── application.html.erb  # 共通レイアウト（ヘッダー、フッター）
│   ├── pages/
│   │   └── index.html.erb         # トップページ
│   └── guides/
│       └── ruby_overview.html.erb # 記事ページの例
├── controllers/
│   ├── pages_controller.rb        # トップページ用コントローラー
│   └── guides_controller.rb       # 記事用コントローラー
└── assets/
    └── stylesheets/
        ├── application.css        # CSSマニフェスト
        └── portfolio.css          # カスタムCSS

config/
└── routes.rb                      # ルーティング設定
```

### 🎨 デザインシステム

このテンプレートは **Tailwind CSS** を使用しています。

**カラーパレット：**
- **水色（背景）**: `#e0f2fe` - ページ全体の背景色
- **濃い水色（アクセント）**: `#0284c7` - ボタンやリンクの色
- **濃いグレー（テキスト）**: `#0f172a` - 通常のテキスト色
- **白**: `#ffffff` - カードやナビゲーションの背景

---

## 新しい記事ページを作成する手順

### ステップ1: ビューファイルを作成する

記事のHTMLを作成します。

**例：「Railsの基礎」という記事を作成する場合**

```bash
# app/views/guides/rails_basics.html.erb というファイルを作成
touch app/views/guides/rails_basics.html.erb
```

または、エディタで直接ファイルを作成してください。

### ステップ2: HTMLを書く

作成したファイルに以下のテンプレートをコピーして編集します：

```erb
<%# ヒーローセクション - ページタイトル部分 %>
<div class="text-center mb-12 animate-fade-in-up">
  <h1 class="text-4xl font-bold text-gray-800 mb-4">
    Railsの基礎を学ぼう
  </h1>
  <p class="text-gray-600 text-lg">
    Ruby on Railsの基本的な概念を理解しよう
  </p>
</div>

<%# メインコンテンツ %>
<div class="bg-white rounded-2xl p-8 shadow-lg mb-8">

  <%# セクション1 %>
  <h2 class="text-2xl font-bold text-gray-800 mb-4 border-b-2 border-sky-500 pb-2">
    Railsとは？
  </h2>

  <p class="text-gray-700 mb-4 leading-relaxed">
    Ruby on Railsは、Rubyで書かれたWebアプリケーションフレームワークです。
    シンプルで効率的な開発を可能にします。
  </p>

  <%# コードブロック例 %>
  <div class="bg-gray-800 rounded-lg p-4 text-gray-200 text-sm font-mono mb-6 overflow-x-auto">
    <div class="flex mb-1">
      <span class="text-green-400 mr-2">$</span>
      <span>rails new myapp</span>
    </div>
    <div class="text-gray-400">Creating new Rails application...</div>
  </div>

  <%# セクション2 %>
  <h2 class="text-2xl font-bold text-gray-800 mb-4 border-b-2 border-sky-500 pb-2 mt-8">
    基本的なコマンド
  </h2>

  <ul class="space-y-2 mb-6">
    <li class="flex items-start">
      <span class="text-sky-500 mr-2">✓</span>
      <span class="text-gray-700"><code class="bg-gray-100 px-2 py-1 rounded">rails server</code> - サーバーを起動</span>
    </li>
    <li class="flex items-start">
      <span class="text-sky-500 mr-2">✓</span>
      <span class="text-gray-700"><code class="bg-gray-100 px-2 py-1 rounded">rails generate</code> - コードを生成</span>
    </li>
    <li class="flex items-start">
      <span class="text-sky-500 mr-2">✓</span>
      <span class="text-gray-700"><code class="bg-gray-100 px-2 py-1 rounded">rails console</code> - コンソールを起動</span>
    </li>
  </ul>

  <%# Tips カード %>
  <div class="bg-sky-50 border-l-4 border-sky-500 p-4 rounded mb-6">
    <p class="text-sm text-sky-800">
      <span class="font-bold">💡 Tips:</span> rails sでサーバーを起動できます（短縮形）
    </p>
  </div>

</div>

<%# ナビゲーション - 前後の記事へのリンク %>
<div class="flex justify-between mt-8">
  <%= link_to "← 前の記事", "/guides/ruby_overview", class: "text-sky-600 hover:text-sky-700 font-medium" %>
  <%= link_to "次の記事 →", "/guides/mvc_basics", class: "text-sky-600 hover:text-sky-700 font-medium" %>
</div>
```

### ステップ3: コントローラーにアクションを追加

`app/controllers/guides_controller.rb` を開いて、新しいアクションを追加します：

```ruby
class GuidesController < ApplicationController
  def ruby_overview
    # 既存のアクション
  end

  def rails_basics  # ← 追加
  end
end
```

**ファイルが存在しない場合は作成：**

```bash
# コントローラーを新規作成
touch app/controllers/guides_controller.rb
```

```ruby
# app/controllers/guides_controller.rb
class GuidesController < ApplicationController
  def rails_basics
  end
end
```

### ステップ4: ルーティングを追加

`config/routes.rb` を開いて、ルートを追加します：

```ruby
Rails.application.routes.draw do
  # 既存のルート
  get "guides/ruby_overview"

  # 新しいルートを追加 ↓
  get "guides/rails_basics"

  # その他のルート...
end
```

### ステップ5: 確認する

1. Railsサーバーが起動していることを確認（起動していない場合は `rails server` で起動）
2. ブラウザで `http://localhost:8080/guides/rails_basics` にアクセス
3. 作成したページが表示されれば成功！

---

## Tailwind CSSの基本

Tailwind CSSは、クラス名を使ってスタイルを適用するフレームワークです。

### よく使うクラス

#### テキスト関連
```html
<!-- 文字サイズ -->
<h1 class="text-4xl">大きな見出し</h1>
<h2 class="text-2xl">中くらいの見出し</h2>
<p class="text-base">通常のテキスト</p>
<span class="text-sm">小さいテキスト</span>

<!-- 文字色 -->
<p class="text-gray-800">濃いグレー</p>
<p class="text-sky-600">水色</p>
<p class="text-white">白</p>

<!-- 文字の太さ -->
<p class="font-bold">太字</p>
<p class="font-medium">中くらい</p>
<p class="font-normal">通常</p>
```

#### スペーシング（余白）
```html
<!-- マージン（外側の余白） -->
<div class="mb-4">下に余白</div>
<div class="mt-8">上に余白</div>
<div class="mx-auto">左右中央</div>

<!-- パディング（内側の余白） -->
<div class="p-4">全方向に余白</div>
<div class="px-6 py-4">左右に6、上下に4</div>
```

**数字の意味：**
- `4` = 1rem = 16px
- `6` = 1.5rem = 24px
- `8` = 2rem = 32px

#### 背景色
```html
<div class="bg-white">白背景</div>
<div class="bg-sky-100">薄い水色</div>
<div class="bg-gray-800">濃いグレー</div>
```

#### レイアウト
```html
<!-- Flexbox（横並び） -->
<div class="flex items-center space-x-4">
  <div>左</div>
  <div>右</div>
</div>

<!-- グリッド（格子状） -->
<div class="grid grid-cols-2 gap-4">
  <div>左カラム</div>
  <div>右カラム</div>
</div>
```

#### ボーダー・角丸
```html
<div class="border border-gray-200 rounded-lg">
  角丸の枠線
</div>
```

---

## よく使うコンポーネント

コピー&ペーストして使えるコンポーネント集です。

### 1. カードコンポーネント

```erb
<div class="bg-white rounded-2xl p-6 shadow-lg mb-6">
  <h3 class="text-xl font-bold text-gray-800 mb-3">カードタイトル</h3>
  <p class="text-gray-700 leading-relaxed">
    カードの内容をここに書きます。
  </p>
</div>
```

### 2. Tipsボックス（情報カード）

```erb
<div class="bg-sky-50 border-l-4 border-sky-500 p-4 rounded mb-6">
  <p class="text-sm text-sky-800">
    <span class="font-bold">💡 Tips:</span> ここに役立つ情報を書きます。
  </p>
</div>
```

### 3. 警告ボックス

```erb
<div class="bg-yellow-50 border-l-4 border-yellow-500 p-4 rounded mb-6">
  <p class="text-sm text-yellow-800">
    <span class="font-bold">⚠️ 注意:</span> 注意事項をここに書きます。
  </p>
</div>
```

### 4. コードブロック

```erb
<div class="bg-gray-800 rounded-lg p-4 text-gray-200 text-sm font-mono mb-6 overflow-x-auto">
  <div class="flex mb-1">
    <span class="text-green-400 mr-2">$</span>
    <span>コマンドをここに書く</span>
  </div>
  <div class="text-gray-400">出力結果</div>
</div>
```

### 5. インラインコード

```erb
<p>
  <code class="bg-gray-100 px-2 py-1 rounded text-sm">rails server</code>
  というコマンドでサーバーを起動します。
</p>
```

### 6. チェックリスト

```erb
<ul class="space-y-2 mb-6">
  <li class="flex items-start">
    <span class="text-sky-500 mr-2">✓</span>
    <span class="text-gray-700">項目1</span>
  </li>
  <li class="flex items-start">
    <span class="text-sky-500 mr-2">✓</span>
    <span class="text-gray-700">項目2</span>
  </li>
</ul>
```

### 7. セクション見出し

```erb
<h2 class="text-2xl font-bold text-gray-800 mb-4 border-b-2 border-sky-500 pb-2">
  セクションタイトル
</h2>
```

### 8. ボタン

```erb
<!-- プライマリボタン -->
<a href="#" class="inline-block bg-sky-600 text-white px-6 py-3 rounded-lg hover:bg-sky-700 transition-colors font-medium">
  クリックしてね
</a>

<!-- アウトラインボタン -->
<a href="#" class="inline-block border-2 border-sky-600 text-sky-600 px-6 py-3 rounded-lg hover:bg-sky-50 transition-colors font-medium">
  クリックしてね
</a>
```

### 9. 画像（レスポンシブ）

```erb
<img src="/path/to/image.png" alt="説明" class="w-full rounded-lg shadow-md mb-6">
```

### 10. 2カラムレイアウト

```erb
<div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
  <div class="bg-white rounded-lg p-6 shadow">
    左側のコンテンツ
  </div>
  <div class="bg-white rounded-lg p-6 shadow">
    右側のコンテンツ
  </div>
</div>
```

---

## 実践例：記事ページの作成

実際に「MVCの基礎」という記事を作成してみましょう。

### 1. ビューファイルを作成

```bash
touch app/views/guides/mvc_basics.html.erb
```

### 2. HTMLを書く

`app/views/guides/mvc_basics.html.erb` に以下を記述：

```erb
<%# ページタイトル %>
<div class="text-center mb-12">
  <h1 class="text-4xl font-bold text-gray-800 mb-4">
    MVCとは？ (Model-View-Controller)
  </h1>
  <p class="text-gray-600 text-lg">
    Railsの設計パターンMVCについて学ぼう
  </p>
</div>

<%# メインコンテンツ %>
<div class="bg-white rounded-2xl p-8 shadow-lg mb-8">

  <h2 class="text-2xl font-bold text-gray-800 mb-4 border-b-2 border-sky-500 pb-2">
    MVCとは何か？
  </h2>

  <p class="text-gray-700 mb-6 leading-relaxed">
    MVCは、アプリケーションを3つの役割に分けて管理する設計パターンです。
  </p>

  <%# 3つのカード %>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">

    <%# Model カード %>
    <div class="bg-blue-50 rounded-lg p-6 border-t-4 border-blue-500">
      <h3 class="text-xl font-bold text-blue-800 mb-3">Model</h3>
      <p class="text-gray-700 text-sm">
        データベースとのやり取りを担当します。データの保存や取得を行います。
      </p>
    </div>

    <%# View カード %>
    <div class="bg-green-50 rounded-lg p-6 border-t-4 border-green-500">
      <h3 class="text-xl font-bold text-green-800 mb-3">View</h3>
      <p class="text-gray-700 text-sm">
        ユーザーに見せる画面を担当します。HTMLを生成して表示します。
      </p>
    </div>

    <%# Controller カード %>
    <div class="bg-purple-50 rounded-lg p-6 border-t-4 border-purple-500">
      <h3 class="text-xl font-bold text-purple-800 mb-3">Controller</h3>
      <p class="text-gray-700 text-sm">
        ModelとViewの橋渡しをします。ユーザーのリクエストを処理します。
      </p>
    </div>

  </div>

  <h2 class="text-2xl font-bold text-gray-800 mb-4 border-b-2 border-sky-500 pb-2 mt-8">
    MVCの流れ
  </h2>

  <ol class="space-y-3 mb-6 list-decimal list-inside">
    <li class="text-gray-700">ユーザーがブラウザでURLにアクセス</li>
    <li class="text-gray-700">Controllerがリクエストを受け取る</li>
    <li class="text-gray-700">Controllerが必要に応じてModelにデータを要求</li>
    <li class="text-gray-700">Modelがデータベースからデータを取得</li>
    <li class="text-gray-700">ControllerがViewにデータを渡す</li>
    <li class="text-gray-700">ViewがHTMLを生成</li>
    <li class="text-gray-700">ユーザーのブラウザに表示</li>
  </ol>

  <%# Tipsボックス %>
  <div class="bg-sky-50 border-l-4 border-sky-500 p-4 rounded">
    <p class="text-sm text-sky-800">
      <span class="font-bold">💡 Tips:</span>
      MVCを使うと、コードの役割が明確になり、保守しやすくなります！
    </p>
  </div>

</div>

<%# ナビゲーション %>
<div class="flex justify-between">
  <%= link_to "← Railsの基礎", "/guides/rails_basics", class: "text-sky-600 hover:text-sky-700 font-medium" %>
  <%= link_to "ルーティング →", "/guides/routing", class: "text-sky-600 hover:text-sky-700 font-medium" %>
</div>
```

### 3. コントローラーを更新

`app/controllers/guides_controller.rb` に追加：

```ruby
class GuidesController < ApplicationController
  def ruby_overview
  end

  def mvc_basics  # 追加
  end
end
```

### 4. ルーティングを追加

`config/routes.rb` に追加：

```ruby
Rails.application.routes.draw do
  get "guides/ruby_overview"
  get "guides/mvc_basics"  # 追加

  # その他...
end
```

### 5. 確認

ブラウザで `http://localhost:8080/guides/mvc_basics` にアクセスして確認！

---

## トラブルシューティング

### Q1: ページが表示されない（404エラー）

**原因：** ルーティングが設定されていない

**解決方法：**
1. `config/routes.rb` にルートを追加したか確認
2. サーバーを再起動（`Ctrl+C` で停止 → `rails server` で起動）

### Q2: デザインが崩れた

**原因：** HTMLタグを間違って削除した可能性

**解決方法：**
```bash
# Gitで元に戻す
git checkout app/views/guides/ファイル名.html.erb
```

### Q3: 変更が反映されない

**原因：** ブラウザのキャッシュ

**解決方法：**
- スーパーリロード（`Ctrl + Shift + R` または `Cmd + Shift + R`）
- ブラウザのキャッシュをクリア

### Q4: Tailwindのクラスが効かない

**原因：** Tailwind CSSのCDNが読み込まれていない

**解決方法：**
`app/views/layouts/application.html.erb` に以下があるか確認：
```erb
<script src="https://cdn.tailwindcss.com"></script>
```

### Q5: コントローラーのエラーが出る

**エラー例：** `uninitialized constant GuidesController`

**解決方法：**
1. コントローラーファイルが存在するか確認
2. ファイル名が正しいか確認（`guides_controller.rb`）
3. クラス名が正しいか確認（`class GuidesController < ApplicationController`）

---

## 📚 参考リンク

- [Tailwind CSS公式ドキュメント](https://tailwindcss.com/docs)
- [Rails Guides（日本語）](https://railsguides.jp/)
- [HTML基礎（MDN）](https://developer.mozilla.org/ja/docs/Web/HTML)

---

## 🎯 まとめ

新しい記事を作成する基本的な流れ：

1. ✅ `app/views/guides/記事名.html.erb` を作成
2. ✅ HTMLを書く（このガイドのコンポーネントをコピー&ペースト）
3. ✅ `app/controllers/guides_controller.rb` にアクションを追加
4. ✅ `config/routes.rb` にルートを追加
5. ✅ ブラウザで確認

---

何か分からないことがあれば、このガイドを参考にしてください！
Happy Coding! 🚀
