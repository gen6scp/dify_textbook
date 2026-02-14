This repository documents the full lifecycle of building a local AI platform using Dify, Ollama, and RAG — from PoC to deployment.

---
title: "Dify (Linux版)"
author: "Gen K. Mariendorf"
catch: "ローカルＬＬＭとＲＡＧで作る業務で使える実践ＡＩ基盤"
version: '第一版'
include-before: \input{tex/preface}
header-includes:
  - \usepackage{graphicx}
  - \usepackage{fancyhdr}
  - \usepackage{amsmath}
  - \usepackage{amssymb}
  - \usepackage{titlesec}
  - \usepackage{hyperref}
  - \usepackage{tcolorbox}
  - \usepackage{xcolor}
  - \usepackage{framed}
  - \definecolor{oreillyRed}{RGB}{227,26,28}
  - \definecolor{oreillyGray}{RGB}{51,51,51}
  - \titleformat{\chapter}[display]{\normalfont\huge\bfseries\color{oreillyRed}}{\chaptertitlename\ \thechapter}{20pt}{\Huge}
  - \titlespacing*{\chapter}{0pt}{50pt}{40pt}
  - \titleformat{\section}{\normalfont\Large\bfseries\color{oreillyRed}}{\thesection}{1em}{}
  - \titleformat{\subsection}{\normalfont\large\bfseries\color{oreillyRed}}{\thesubsection}{1em}{}
  - \pagestyle{fancy}
  - \fancyhf{}
  - \fancyhead[LE,RO]{\thepage}
  - \fancyhead[LO]{\nouppercase{\rightmark}}
  - \fancyhead[RE]{\nouppercase{\leftmark}}
  - \fancyfoot[C]{}
  - \newtcolorbox{sidebar}[1][]{colback=oreillyGray!5!white, colframe=oreillyGray, fonttitle=\bfseries, title=#1}
  - '\patchcmd{\LT@array}{\@mkpream{#2}}{\StrGobbleLeft{#2}{2}[\pream]\StrGobbleRight{\pream}{2}[\pream]\StrSubstitute{\pream}{l}{|l}[\pream]\@mkpream{@{}\pream|@{}}}{}{}'
csl: ieee.csl
---


