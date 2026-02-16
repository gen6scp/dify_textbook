# Appendix: Dify DockerをUbuntuで使う

多少古いディストリビューションですが、Ubuntu20は安定しているのでこの版でDocker Compose V2が動作するようにします。クラウド環境だとそのまま最新のDockerやモジュールをインストールすれば良いでしょう。

### Dockerの事前環境

```bash
docker --version
docker-compose version
```

#### 出力例

```
$ docker --version
Docker version 24.0.5, build 24.0.5-0ubuntu1~20.04.1

$ docker-compose version
docker-compose version 1.25.0, build unknown
docker-py version: 4.1.0
CPython version: 3.8.10
OpenSSL version: OpenSSL 1.1.1f  31 Mar 2020
```


### 古いDocker関連を整理（安全）

```bash
sudo apt-get remove docker docker-engine docker.io containerd runc
```

（データは消えない）

#### Ubuntu20の標準へ戻す場合

```bash
sudo apt-get install docker.io
```

#### 公式Docker版
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

#### 完全削除

```bash
sudo apt-get purge docker.io
sudo rm -rf /var/lib/docker
```

これをやらない限りデータは残る。apt-get removeではデータは残るのが普通。


### 公式Dockerリポジトリ追加

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```



### 最新Docker Compose v2をインストール

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```


### 確認

```bash
docker --version
docker compose version
```

#### 出力

```
Docker version 28.1.1, build 4eba377
Docker Compose version v2.35.1
```

これでDify Dockerを動かす準備が整いました。
