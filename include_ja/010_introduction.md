# Ｄｉｆｙローカル環境の構築

この章では難しい理論やシステム説明は無しで、早速Ｄｉｆｙを動かしてみましょう。簡単な「具体的スクリプト」と方法をこの章ではまとめます。前提条件はOSはLinux、DifyはDocker Compose、OllamaはDockerホスト側で動かす、モデルは **deepseek-r1:1.5b**を使用します。


### ゴール

* Ollama + `deepseek-r1:1.5b` 起動
* Dify（Docker）起動
* **DifyからOllamaに接続して、チャット応答が返る**

要するに、Dify（Docker上で動作）$\rightarrow$ Ollama [Deepseek-r1:1.5b]と繋いで動かしてみる訳です。



## Ollama導入 & deepseek-r1:1.5bの起動

### Ollama インストール

```bash
$ curl -fsSL https://ollama.com/install.sh | sh
```

### モデル取得＆単体テスト

```bash
$ ollama pull deepseek-r1:1.5b
$ ln -vs /usr/share/ollama/.ollama $HOME
$ ollama run deepseek-r1:1.5b
```

#### モデルの保存場所は通常以下になる。

この例ではsymlinkを$HOME（ホームディレクトリ）へ作成

```bash
$ du -sh /usr/share/ollama/.ollama/models/
1,1G    /usr/share/ollama/.ollama/models/
```

* 環境変数：モデルの保存場所変更する場合は設定可。

```
$ export OLLAMA_MODELS=/usr/share/ollama/.ollama/models/
```

#### DeepSeekをOllamaでダウンロード

```bash
$ ollama pull deepseek-r1:1.5b
pulling manifest 
pulling manifest 
pulling aabd4debf0c8: 100%  1.1 GB
pulling c5ad996bda6e: 100%   556 B
pulling 6e4c38e1172f: 100%  1.1 KB
pulling f4d24e9138dd: 100%   148 B
pulling a85fe2a2e58e: 100%   487 B
verifying sha256 digest 
writing manifest 
success 
```

#### DeepSeekの起動：受け答えしてみる。$\rightarrow$ 成功

```bash
$ ollama run deepseek-r1:1.5b
>>> What is your name?
Greetings! I'm DeepSeek-R1, an artificial intelligence assistant created by DeepSeek. I'm at your service and would be delighted to assist you with any 
inquiries or tasks you may have.

>>> Send a message (/? for help)
```

\newpage


## Dify事前チェック（Dockerが動くか確認）

```bash
$ docker --version
$ docker compose version
```

#### 出力例

```
$ docker --version
Docker version 28.1.1, build 4eba377

$ docker compose version
Docker Compose version v2.35.1
```

### GPUコンテナを念の為チェック

`nvidia-smi`コマンドでGPUのチェックをします。

```
$ nvidia-smi

```

![nvidia-smiの結果](img/nvidia-smi.png)

以下のようなシステム構成であることが分かりました。

| GPU                     | VRAM | Driver     | CUDA |
|:-----------------------:|:----:|:----------:|:----:|
| GeForce RTX 4060 | 8GB  | 535.230.02 | 12.2 |


## Dify（Docker Compose）を起動

公式のDocker Composeクイックスタートを参考にします。([docs.dify.ai Quick][1])

### Difyをclone（推奨：最新リリースタグ）

```bash
$ sudo apt-get update
$ sudo apt-get install -y jq curl git

git clone --branch "$(curl -s https://api.github.com/repos/langgenius/dify/releases/latest | jq -r .tag_name)" https://github.com/langgenius/dify.git
cd dify/docker
cp .env.example .env
docker compose up -d
```

### 起動確認（主要コンテナから起動）

```bash
docker compose ps
```

#### 起動確認：主要コンテナが稼働中

```
NAME                     IMAGE                                       COMMAND                  SERVICE         CREATED         STATUS                   PORTS
docker-api-1             langgenius/dify-api:1.13.0                  "/bin/bash /entrypoi…"   api             5 minutes ago   Up 5 minutes             5001/tcp
docker-db_postgres-1     postgres:15-alpine                          "docker-entrypoint.s…"   db_postgres     5 minutes ago   Up 5 minutes (healthy)   5432/tcp
docker-nginx-1           nginx:latest                                "sh -c 'cp /docker-e…"   nginx           5 minutes ago   Up 2 minutes             0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp
docker-plugin_daemon-1   langgenius/dify-plugin-daemon:0.5.3-local   "/bin/bash -c /app/e…"   plugin_daemon   5 minutes ago   Up 5 minutes             0.0.0.0:5003->5003/tcp, [::]:5003->5003/tcp
docker-redis-1           redis:6-alpine                              "docker-entrypoint.s…"   redis           5 minutes ago   Up 5 minutes (healthy)   6379/tcp
docker-sandbox-1         langgenius/dify-sandbox:0.2.12              "/main"                  sandbox         5 minutes ago   Up 5 minutes (healthy)
docker-ssrf_proxy-1      ubuntu/squid:latest                         "sh -c 'cp /docker-e…"   ssrf_proxy      5 minutes ago   Up 5 minutes             3128/tcp
docker-weaviate-1        semitechnologies/weaviate:1.27.0            "/bin/weaviate --hos…"   weaviate        5 minutes ago   Up 5 minutes
docker-web-1             langgenius/dify-web:1.13.0                  "/bin/sh ./entrypoin…"   web             5 minutes ago   Up 5 minutes             3000/tcp
docker-worker-1          langgenius/dify-api:1.13.0                  "/bin/bash /entrypoi…"   worker          5 minutes ago   Up 5 minutes             5001/tcp
docker-worker_beat-1     langgenius/dify-api:1.13.0                  "/bin/bash /entrypoi…"   worker_beat     5 minutes ago   Up 5 minutes             5001/tcp
```


Difyの初期セットアップ画面は通常 `http://localhost` （ポート８０番）で見えます（環境によりポートが異なる場合あり）。

![Dify Login](img/dify_login.png)

## Dify $\rightarrow$ Ollama接続

Dify公式は「DockerでDifyを動かすなら、OllamaのURLは `host.docker.internal` か LAN IP を使う」と明記しています([legacy-docs.dify.ai Ollama][2])。
Linuxは `host.docker.internal` が効かない/不安定なことがあるので、LAN IP方式が推奨になります。

### ホストLAN IPを取得

```bash
ip route get 1.1.1.1 | awk '{print $7; exit}'
```

例：`192.168.1.20` が出たら、以下は `http://192.168.1.20:11434`

### OllamaがLANから見えるようにする（重要）

Ollamaはデフォルトで `127.0.0.1:11434` にバインドします。外部（＝Difyコンテナ）から見せるには環境変数の`OLLAMA_HOST`を変えます。

#### OllamaをLANバインドで実行(OLLAMA_HOST環境変数を使うだけ)

ターミナルで：

```bash
$ LAN_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
$ OLLAMA_HOST=$LAN_IP:11434 ollama serve
```

別ターミナルで疎通確認：

```bash
$ curl http://$LAN_IP:11434/api/tags
```

例えば、以下のようなJSONが返れば設定完了。恒久化する場合はsystemdに環境変数を入れるやり方が定番ですが、最初は簡易設定で十分です。

```bash
{"models":[{"name":"deepseek-r1:1.5b","model":"deepseek-r1:1.5b","modified_at":"2026-02-13T06:56:58.294031073+01:00","size":1117322768,"digest":"e0979632db5a88d1a53884cb2a941772d10ff5d055aabaa6801c4e36f3a6c2d7","details":{"parent_model":"","format":"gguf","family":"qwen2","families":["qwen2"],"parameter_size":"1.8B","quantization_level":"Q4_K_M"}}]}
```


### Difyの画面でOllamaプロバイダー設定

Dify管理画面 $\rightarrow$ **Settings** $\rightarrow$ **Model Providers** $\rightarrow$ **Ollama**

![Difyログイン画面](img/dify_first_setup.png)

![Dify管理画面](img/dify_management.png)

![Dify設定画面](img/dify_settings.png)







[Add Model]ボタンを押して、

* **Model name**: `deepseek-r1:1.5b` $\rightarrow$ Dify公式のDeepSeek+Ollama事例でも同系モデルを前提
* **Base URL**: `http://<LAN_IP>:11434` $\rightarrow$ もしくは `http://host.docker.internal:11434` が効く環境ならそれも可能
* Model Type: Chat
* Context length: 4096（不明ならデフォルト）
  
[Add]ボタン追加したら成功。

![Difyモデル選択画面](img/dify_model_provider.png)

![Difyモデル選択画面 - Ollamaのインストール](img/dify_ollama_installation.png)



### 最小チャットアプリを作って動作確認
  
Difyで新規 App → Chat（または最もシンプルなテンプレ）を追加する。モデルに `deepseek-r1:1.5b` を指定して、1往復会話して応答が返れば最初の設定はクリア。




![Difyアプリ作成 - 最小チャットボットの作成](img/dify_first_chatbot_blank.png)

![Difyアプリ作成 - 最小チャットボットの設定](img/dify_first_deepseek_bot1.png)

![Difyアプリ作成 - 最小チャットボット](img/dify_deepseek_chatbot2.png)
  



## トラブルシューティング


###  `localhost:11434` を入れてしまう
  
Docker内のlocalhostなのでNG（Dify→Ollamaへ届かない）
  
###  `curl http://<LAN_IP>:11434/api/tags` が返らない
  
* Ollamaが 127.0.0.1 にしかバインドしてない
* `OLLAMA_HOST=0.0.0.0:11434 ollama serve` を実行し直す

### DifyからOllamaへLAN_IP経由で繋がらない

Difyコンテナ $\rightarrow$ Ollama(LAN_IP:11434) にTCP接続できていない（タイムアウト）

* ファイヤーウォール

```bash
$ sudo ufw allow 11434/tcp
```

* Dify上のDockerコンテナから確認

モデルが返れば成功

```bash
$ docker exec -it docker-api-1 sh -lc "apk add --no-cache curl >/dev/null 2>&1 || true; curl -sS http://192.168.81.215:11434/api/tags | head"
```

### Difyインターフェース上からOllamaのモデルが見つからない。

モデルが見えるか確認する。スペルミス等ありえる。モデルの設定は`.ollama`から読まれるが、実行ユーザーollamaとモデルの場所が違う場合にモデルが空になる。

* モデルが空の場合
```
{"models":[]}
```


* `.ollama`パスをちゃんとリンクする。

```
$ ln -vs /usr/share/ollama/.ollama ~
```

* 確認

```bash
$ LAN_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}') 
$ curl -s http://$LAN_IP:11434/api/tags

{"models":[{"name":"deepseek-r1:1.5b","model":"deepseek-r1:1.5b","modified_at":"2026-02-13T06:56:58.294031073+01:00","size":1117322768,"digest":"e0979632db5a88d1a53884cb2a941772d10ff5d055aabaa6801c4e36f3a6c2d7","details":{"parent_model":"","format":"gguf","family":"qwen2","families":["qwen2"],"parameter_size":"1.8B","quantization_level":"Q4_K_M"}}]}
```

  
## 参考リンク
  
  1. Dify Docker Compose クイックスタート（公式） ([docs.dify.ai Quick][1])
  2. Dify × Ollama 統合（公式：Base URLの注意が明確） ([legacy-docs.dify.ai Ollama][2])
  3. Ollama FAQ（OLLAMA_HOSTで公開できる） ([Ollama Docs FAQ][3])
  4. Ollama + DeepSeek + Dify のプライベートデプロイ ([legacy-docs.dify.ai DeepSeek][4])
  
  [1]: https://docs.dify.ai/en/self-host/quick-start/docker-compose "Deploy Dify with Docker Compose"
  [2]: https://legacy-docs.dify.ai/development/models-integration/ollama "Integrate Local Models Deployed by Ollama"
  [3]: https://docs.ollama.com/faq "FAQ"
  [4]: https://legacy-docs.dify.ai/ja-jp/learn-more/use-cases/private-ai-ollama-deepseek-dify "Ollama + DeepSeek + Dify"

  
