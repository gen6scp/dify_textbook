# ＲＡＧの実装と検証

この章ではPDF文書1本を使用して **RAGが動く**ことを目標にします。何はともあれ動いて検証するということに重点をおいてパラメータを変えて挙動を見てみましょう。

RAGについての概略を説明し、Chunk_size、Top_k、Temperature、Embeddingを触って差を観察し、どう精度が変わるのかを説明していきます。



## RAG（Retrieval Augmented Generation）の概略

![](img/rag_query_abstract.png)

#### 検索の流れ：質問 $\rightarrow$ Embedding（意味ベクトル化）$\rightarrow$ ベクトルDBで類似検索 $\rightarrow$ 関連チャンク Top_k 件取得 $\rightarrow$ LLMへ渡す $\rightarrow$ 回答生成
		  


RAG（Retrieval Augmented Generation）とは、大規模言語モデル（LLM）に外部知識を動的に参照させることで、回答の正確性と文脈適合性を高める手法である[@lewis2020rag][@facebook2020ragblog][@dify2026knowledge][@openai2026embeddings]。通常のLLMは事前学習されたパラメータの範囲内でのみ回答を生成するが、RAGでは質問に応じて関連文書を検索し、その情報をコンテキストとして与えた上で生成を行う。これにより、モデル自体を再学習することなく、最新情報や社内限定情報を活用できる。

RAGの基本構造は大きく三段階に分かれる。

1. 文書を適切な単位（Chunk）に分割し、それぞれをEmbedding（意味ベクトル化）する。
2. ユーザーの質問も同様にEmbeddingし、ベクトル空間上で類似度検索を行う。
3. 上位の関連チャンク（Top_k）をLLMへ渡し、それらを参照しながら回答を生成する。

この流れは「検索（Retrieval）」と「生成（Generation）」の明確な責任分離によって成立している。

実務導入においてRAGが重要視される理由は、モデルの再学習を行わずに企業独自の知識を活用できる点にある。社内マニュアル、契約書、技術仕様書などをナレッジとして登録することで、閉じた環境内でAIを活用できる。特にローカルLLMと組み合わせることで、データを外部に送信せずに業務支援AIを構築することも可能である。

重要なのは、RAGは単なる「検索＋生成」ではないという点である。検索精度はEmbeddingモデルとChunk設計に依存し、生成精度はプロンプト設計およびTemperatureなどの生成パラメータに依存する。つまりRAGの品質は、(1) 文書分割（Chunk）の妥当性、(2) 意味検索の精度（Embedding）、(3) 生成時の制御（Top_k）、という三つの設計要素のバランスで決まる。どれか一つが適合してないと、回答は不安定になる。RAGは「導入すれば自動で賢くなる」技術ではなく、実務上では設計と検証を繰り返す試行錯誤による工学的対象になる。

本書では、Difyを用いてローカルLLM環境下でRAGを構築し、Chunk設計、Embedding選択、Top_k調整、Temperature制御といった各要素がどのように精度へ影響するかを実験的に検証する。目的は単に動かすことではなく、動かして、調整し、なぜ精度が変わるのかを理解することにある。

用語説明：

![Embedding - テキストデータのベクトル化 (\@corpling.hypotheses.org)](img/rag_wordembedding.jpg)

* Chunk : 文脈の単位。元のドキュメントを**検索可能な単位に分割したテキスト片**のこと。RAGではPDFや文書全体をそのまま扱うのではなく、数百〜千文字程度の塊に分割してEmbeddingし、ベクトル検索する。チャンクが大きすぎるとノイズが混ざりやすく、小さすぎると文脈が壊れる。Chunk設計は「文脈の保存」と「検索精度」のバランス設計のこと。RAG精度はChunkに大きく依存する。
* Top_k : 情報量の制御。ベクトル検索で**上位何件のチャンクをLLMに渡すかを決めるパラメータ**のこと。例えば、$Top_k = 3$なら、質問に最も近い3つのチャンクを取得する。小さすぎると重要情報を取りこぼし、大きすぎると無関係な情報が混入し、生成精度が落ちる。Top_kは「情報の網羅性」と「ノイズ制御」のトレードオフ調整レバーになる。
* Embedding : 意味の変換。**テキストを意味を保持した数値ベクトルに変換する処理**のこと。RAGではこのベクトル同士の距離（類似度）で関連文書を検索する。Embeddingモデルが弱いと、意味検索が正しく働かず、質問と無関係なチャンクが選ばれる。特に日本語を扱う場合は、multilingual対応モデルを選ぶことが精度に直結する。EmbeddingはRAGの“検索の質”を決める基礎になる。
* Temperature : 表現の揺らぎ。LLMの**出力のランダム性（＝創造性）を制御する値**。低い（例: 0.1〜0.3）ほど決定的で安定した出力になり、高い（例: 0.7〜1.0）ほど多様で創造的になる。例えば、画像生成AIでは影響が顕著に見える（低いと同じような画像ばかりになり、高いとクリエイティブに感じる）。RAG用途では通常、事実性が重要なため低めに設定するのが基本。Temperatureは検索精度には影響せず、生成の表現と揺らぎに影響する。




		  



## Dify上でKnowledge Base（知識基盤）を作る

#### Dify $\Rightarrow$ Knowledge $\Rightarrow$ Create Knowledge $\Rightarrow$ Import from file $\Rightarrow$ PDFをアップロード

### 準備

![Hands-on Machine Learning with Scikit-Learn, Keras & TensorFlow](img/oreilly_hands_on_ML.png)

* PDFを用意する（20〜30ページ）。おすすめは「章がはっきりしていて用語が繰り返し出る」技術文書。（例：プロトコル解説、API仕様の一部、社内手順書の抜粋など）
  - この例では、英文のO'Reillyの「[Hands-on Machine Learning with Scikit-Learn, Keras & TensorFlow](https://amzn.to/4cqxXpd)」の第１章（約３０ページ）を使用します。
* Knowledge Base作成時に選ぶ “Chunk Mode” は後から変更できない。ただし区切り文字や最大長などのチャンク設定は調整可能。 ([docs.dify.ai - Chunk][rag1])
* TopK、Score Threshold、Rerankは「検索で拾うチャンクの量と質」を直接変える。([docs.dify.ai - Index Method][rag2])



## 設定

### Chunking設定


「Chunking and cleaning text」画面で設定します。まずは以下の２パターンを同じPDFファイルで比較する。

1. 粗い：max chunk length 800〜1200 くらい
2. 細かい：max chunk length 300〜500 くらい

Difyは「各ドキュメントごとにチャンク設定を持てる」ので、同じKnowledge内でも比較しやすい。


### Embeddingモデルを選ぶ（最初は外部推奨）

日本語が混ざる可能性があるなら **multilingual系**が無難。Difyチュートリアルでも言及がある。

設計としては

* 生成（回答）：Ollama deepseek-r1:1.5b（ローカル）
* Embedding（検索）：外部（multilingual）

で行う。この例ではO'Reillyの英文テキストを使うのでこの部分は深く考えない。


### Retrieval設定（TopK / Score Threshold / Rerank）

Knowledge作成後（または設定画面）で **Indexing method / Retrieval settings** を触る。

### TopKの比較（最低2点）

* **TopK = 2**
* **TopK = 6**

TopKは「拾うチャンク数」。小さいと取りこぼし、大きいとノイズ混入が増えやすい、というトレードオフ。

### Score Threshold

0.3 / 0.5 / 0.7 あたりで試す。これは、高いほど厳選、低いほど拾う。

### Rerank

Rerankが使える構成なら「TopKで多めに拾って、Rerankで上位を整列」が効きます（使えるモデルがあれば）。Difyのモデル種別として rerank が存在する点は公式にも説明があります。


## 検索テスト

### Difyの「Retrieval Test」で“検索の質”を評価

非常に重要な項目といて、Knowledge（データセット）には **テスト検索（Retrieve / Test retrieval）**があり、まずここで「検索が正しく当たってるか」を見ます。

### テスト用クエリ例（PDFが技術文書の場合）

文書として機械学習の本の第一章を与えているので、その知識を問い合わせてみます。

* 「この文書で定義されている◯◯とは？」
* 「◯◯の手順を箇条書きで」
* 「◯◯の前提条件は？」
* 「エラーコード◯◯の意味は？」

**ここで見るべき観点**

* 上位チャンクが「質問と同じ節」から取れているか
* 余計な章が混ざっていないか
* チャンクが短すぎて文脈が欠けていないか（細かすぎ問題）
* チャンクが長すぎて要点が埋もれていないか（粗すぎ問題）


## 使ってみる

### アプリ側（チャットボット）で temperature を比較する

前章で作ったDeepSeekチャットアプリ（Ollama）に **Knowledgeを紐づけ**てRAG回答させます（「Integrate knowledge within apps」）。

temperature比較はこの2点で十分：

1. **temp = 0.2**（堅め：根拠重視）
2. **temp = 0.7**（柔らかめ：言い回し増える）

RAGで重要なのは「検索が当たってる」ことなので、tempは最後に触る。

### 任意：APIでRetrievalを叩いて再現性を上げる

Difyには **Dataset retrieve（テスト検索）API**がある。UIで見た結果を、APIでも同条件で再現できる。




## まとめ


```md
# RAG検証ログ

## PDF
- タイトル：
- ページ数：
- 想定用途（FAQ / 手順 / 仕様参照）：

## 実験パラメータ
### Chunk
- A: max chunk length = ___
- B: max chunk length = ___
- chunk mode = ___（※作成時固定）

### Retrieval
- TopK: 2 / 6
- Score threshold: 0.3 / 0.5 / 0.7
- Rerank: on/off（モデル名: ___）

### Embedding
- provider/model: ___（multilingualか？）

### Generation
- LLM: deepseek-r1:1.5b (Ollama)
- temperature: 0.2 / 0.7

## テストクエリ（5個）
1)
2)
3)
4)
5)

## 観察結果（結論から）
- 一番良かった組み合わせ：
- 悪かった組み合わせ：

## なぜ精度が変わったか（重要）
- チャンクが粗い→（例：ノイズ増/要点が埋まる）
- チャンクが細かい→（例：文脈欠落/断片化）
- TopKが小さい→取りこぼし
- TopKが大きい→低関連チャンク混入
- threshold高い→厳選されるが漏れる
- threshold低い→拾うがノイズ増
- embeddingが合わない→意味検索が弱い（特に多言語）
```






## 参考リンク

1. Chunking and cleaning text（チャンク設定） ([docs.dify.ai - Chunk][rag1])
2. Setting indexing methods（TopK/thresholdなど） ([docs.dify.ai - Index Method][rag2])
3. Integrate knowledge within apps ([docs.dify.ai - Within Apps][rag9])
4. Retrieval test & TopKの意味（補助） ([raglegacy-docs.dify.ai - Retreval Test][rag6])
5. Retrieve chunks API（任意で再現性） ([ragdocs.dify.ai - Retrieve Chunks][rag8])





[rag1]: https://docs.dify.ai/en/use-dify/knowledge/create-knowledge/chunking-and-cleaning-text "Configure the Chunk Settings"
[rag2]: https://docs.dify.ai/en/use-dify/knowledge/create-knowledge/setting-indexing-methods "Specify the Index Method and Retrieval Settings"
[rag3]: https://docs.dify.ai/en/use-dify/knowledge/create-knowledge/import-text-data/readme "Upload Local Files"
[rag4]: https://docs.dify.ai/en/use-dify/knowledge/manage-knowledge/maintain-knowledge-documents "Manage Knowledge Content"
[rag5]: https://docs.dify.ai/en/use-dify/tutorials/customer-service-bot "Customer Service Bot With Knowledge Base"
[rag6]: https://legacy-docs.dify.ai/guides/knowledge-base/retrieval-test-and-citation "Retrieval Test / Citation and Attributions"
[rag7]: https://docs.dify.ai/versions/legacy/en/user-guide/models/model-configuration "Model Configuration"
[rag8]: https://docs.dify.ai/api-reference/datasets/retrieve-chunks-from-a-knowledge-base-test-retrieval "Retrieve Chunks from a Knowledge Base / Test Retrieval"
[rag9]: https://docs.dify.ai/en/use-dify/knowledge/integrate-knowledge-within-application "Integrate Knowledge within Apps"
