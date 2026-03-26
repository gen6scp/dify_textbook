# Dify による VLM + RAG

本章では、中規模GPU環境（GeForce RTX 4060、VRAM 8GBを想定）で動作するローカル VLM（Vision-Language Model）を用いた RAG 構成を整理し、Dify 上での具体的な設定方法と実験手順をまとめる。目的は、画像やPDFを含む文書に対してローカルで検索・回答を行う実用システムを最短で構築することである。RTX 4060 8GB 環境でも

* Qwen2.5-VL 3B
* Dify
* RAG

を組み合わせることで、実用的な VLM システムは十分構築可能である。重要なのはモデルサイズではなく、ワークフロー設計、文書分割、検索精度である。この構成はそのまま法務AI、社内検索、技術文書解析等に応用できる。

#### Vision-Language Model (VLM)について

VLMは画像認識と大規模言語モデル（LLM）の技術を組み合わせたAIモデル。両者には以下のような違いがある。

|              | **LLM**                                                              | **VLM**                                                                      |
|--------------|----------------------------------------------------------------------|------------------------------------------------------------------------------|
| データの対象 | Text                                                                 | Text & Vision                                                                |
| 特徴         | テキストデータのパターンや文脈を学習し、言語処理タスクを高精度で実行 | 画像とテキストの両方を統合的に理解することで、異種データ間の関係性を学習する |
| 主な用途     | コード生成、文章要約、質問応答、テキスト分類、翻訳                   | 画像キャプション生成、画像に基づく質問応答、マルチモーダル検索               |



## 推奨構成一覧（GeForce RTX 4060 8GB前提）

| モデル                | VRAM     | 速度   | 安定  | 注釈             |
| :---------------:     | :------: | :----: | :---: | :--------------: |
| Qwen2.5-VL 3B         | 6GB      | 高     | 高    | 日本語・理解強い |
| Qwen2.5-VL 3B+FAISS   | 7GB      | 中     | 高    | 実用構成         |
| MiniCPM-V             | 7GB      | 中     | 高    | 軽量で安定       |
| LLaVA 7B（4bit）      | 8GB      | 中     | 中    | 初期検証向き     |
| Qwen2.5-VL 7B（4bit） | 8GB      | 低     | 低    | ギリギリ動作     |
| Qwen2.5-VL 3B+RAG+OCR | 8GB      | 低     | 中    | PDF精度良。複雑  |





## ベスト構成

中規模GPU環境で現実的でバランスが良い構成は以下である。

| 要素     | 内容                |
| ----     | ------------------- |
| モデル   | qwen2.5vl:3b        |
| 実行環境 | Ollama              |
| アプリ層 | Dify                |
| 検索     | FAISS               |
| 文書処理 | Dify Knowledge Base |
| OCR      | 必要に応じて追加    |

* [LLAMA 3.2 3B vs QWEN 2.5 3B (Logic and reasoning / Mathematics / RAG)](https://www.youtube.com/watch?v=8ItpRha2yEw)
* [Qwen 3.5 Locally: Can It Replace Paid AI Models?](https://www.youtube.com/watch?v=FcR-gUGfS4E)


#### システム構成

```
ユーザー入力（画像 or PDF）
↓
Dify Workflow
↓
Knowledge Retrieval（RAG）
↓
VLM（Qwen2.5-VL）
↓
回答生成
```

### FAISSについて

FAISSとは**「ベクトル（数値の並び）を高速に検索するためのライブラリ」**。正式名称は**Facebook AI Similarity Search**で、Metaが開発。AIやRAGでは、文章をそのまま検索を行わない。例えば、文章検索では

```text
文章
↓
Embedding（数値ベクトル）
↓
似ているものを探す
```

ここで重要なのが**高速に「似ているベクトル」を探す仕組み**で、それがFAISSになる。例えば、

```text
質問：「契約の解除条件は？」
```

これをベクトル化する。

```text
[0.12, -0.33, 0.98, ...]
```

そして文書も同じようにベクトル化して保存。FAISSは**一番近いベクトルを高速に探す**ことで、意味的に似ている文章を見つけることが出来る。通常の検索との違いは、例えばキーワード検索は**「携帯電話」という単語があるか**によって検索を行うが、FAISSは意味検索であり、**「携帯電話」に関する意味が近いか（＝意味検索）**で検索する。RAGの中では、 

```text
ユーザー質問
↓
Embedding
↓
FAISSで検索
↓
関連文書を取得
↓
LLMに渡す
```

つまりLLMの前段で「知識を探す役割」に当たる。

#### FAISSの速度的優位性

普通に全件比較すると$$(n)$だが、FAISSは**近似検索（ANN）**を使い**高速（サブ秒）**で検索できる。


* 数百万〜数億ベクトルでも高速
* GPU対応
* 近似検索（ANN）
* Python/C++対応


DifyではFAISSは直接見えないが、内部では

```text
Knowledge Base
↓
Embedding
↓
Vector DB（FAISSなど）
```

として使われる。FAISS以外の他の選択肢としては以下が存在する。

| 名前       | 特徴    |
| -------- | ----- |
| Chroma   | 軽量・簡単 |
| Weaviate | サーバ型  |
| Milvus   | 大規模向け |
| Pinecone | SaaS  |




## Dify VLM 設定手順

### Ollama 側準備

```
ollama pull qwen2.5vl:3b
ollama serve
```



### DifyにVLMモデル追加

![VLMモデル：エンドポイントとモデルの設定](img/dify_ollama_qwen2_vlm_1.png)

![VLMモデル：Vision Support: Yes](img/dify_ollama_qwen2_vlm_2.png)

![VLMモデル：qwen 2.5vl:3bの追加](img/dify_ollama_qwen2_vlm_3.png)


1. Settings → Model Providers → Ollama →　[Add Model]を選択
2. Custom または Ollama を選択
3. エンドポイント設定： `http://<LAN_IP>:11434`
4. モデル名：`qwen2.5vl:3b`
5. Vision Support：`Yes`



### Knowledge Base 作成

1. Knowledge → Create Knowledge
2. PDFアップロード（季刊邪馬台国130号 20ページ）
3. Chunk設定

| 項目         | 推奨値 |
| ---------- | --- |
| Chunk Size | 1024 |
| Overlap    | 50  |

4. Embedding モデル設定
   （軽量でOK）

![Knowledge Base - 主に画像主体の雑誌（季刊邪馬台国）を選択](img/dify_knowledge_base_yamataikoku.png)


### Workflow 作成

[Studio] -> [Create from Blank]　から新しいWorkflowをWorkflow Builderから作成する。

* App Name: `Historian - qwen2.5vlm:3b`
* Description: `An experimental historian workflow. This agentic flow has a knowledge of history.`

![Workflow Builder](img/dify_workflow_vlm_1.png)

#### ノード構成

![Workflow ノード構成](img/dify_workflow_vlm_2.png)

```
[User Input] → [Knowledge Retrieval] → [LLM（Qwen-2.5vl Vision）] → [Output]
```



![Workflow - User Inputの設定](img/dify_workflow_vlm_3.png)

![Workflow - Knowledge Retrievalの設定](img/dify_workflow_vlm_4.png)

![Workflow - LLM (Vision)の設定](img/dify_workflow_vlm_5.png)

![Workflow - Outputの設定](img/dify_workflow_vlm_6.png)



### LLMノード設定

重要ポイント

* Vision を有効化
* 入力に画像変数またはファイル変数指定
* RAG結果をコンテキストに追加

例プロンプト

* `{{}}`の部分はWorkflow Builder上で`{`を入力すると自動補完される。

```
Use the context to answer the user's question. 

Question: {{#query#}}
Context: {{#context#}}
```



## 実験

### 実験1：画像理解

入力

* UIスクリーンショット
* 図表

質問

```
この画像の内容を説明してください
```

評価

* 認識精度
* 説明の自然さ



### 実験2：PDF検索

入力

* 契約書
* 技術資料

質問

```
この文書の重要ポイントは何ですか
```

評価

* 検索精度
* 回答の網羅性



### 実験3：画像 + RAG

入力

* PDF + 図

質問

```
この図の意味を文書内容と合わせて説明してください
```

評価

* 文脈理解
* 複合推論



## 実測でのパフォーマンス目安

| 処理内容  | 時間   |
| ----- | ---- |
| 画像解析  | 2〜4秒 |
| RAG検索 | 1〜2秒 |
| 全体応答  | 3〜6秒 |


<!--
## トラブルシューティング

### メモリ不足

対策

* 3Bモデルを使用
* 4bit量子化
* context削減



### 応答が遅い

対策

* chunk数削減
* retrieval数を減らす



### 精度が低い

対策

* OCR追加
* rerank導入
* chunkサイズ調整



## 拡張案

* OCR（Tesseract）
* reranker（cross-encoder）
* マルチモーダルEmbedding
* LAN共有AI
-->


