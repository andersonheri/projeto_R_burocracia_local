# =============================================================================
# 01_construir_codebooks_conteudo.R
#
# O QUE ESTE SCRIPT FAZ, EM UMA FRASE:
#   Define, em R, as "regras de codificacao" (codebooks) das 10 variaveis de
#   CONTEUDO do codebook_burocracia_local.docx, e salva cada uma num arquivo
#   .yaml dentro da pasta codebooks/. Esses .yaml sao lidos pelo script
#   seguinte (02_classificacao_llm_conteudo.R) para o LLM saber exatamente
#   o que classificar.
#
# O QUE E' UM "CODEBOOK" AQUI (para quem esta comecando em R e no acR):
#   Um codebook e' basicamente uma FICHA DE INSTRUCOES para quem vai
#   classificar um texto -- no nosso caso, quem classifica e' um modelo de
#   linguagem (LLM), mas a ficha e' escrita do mesmo jeito que seria para
#   um codificador humano. Cada codebook tem:
#     - name          : o nome curto da variavel (ex.: "setor_politica").
#     - instructions  : o texto que explica, em portugues, o que observar
#                        no artigo para decidir a categoria.
#     - categories    : uma LISTA de categorias possiveis. Cada categoria
#                        tem, por sua vez:
#         - definition    : o que aquela categoria significa.
#         - examples_pos  : frase(s) de exemplo que SE ENCAIXAM na categoria.
#         - examples_neg  : frase(s) de exemplo que PARECEM se encaixar mas
#                            NAO se encaixam (ajuda o modelo a nao confundir
#                            categorias parecidas). Nem toda categoria tem.
#         - weight        : peso da categoria (aqui, sempre 1, exceto uma
#                            excecao pontual com peso 1.2 -- ver comentario
#                            no bloco 6).
#     - multilabel    : TRUE se o artigo pode se encaixar em MAIS DE UMA
#                        categoria ao mesmo tempo (so' acontece com
#                        "dimensao_teorica" aqui); FALSE se so' pode ter
#                        UMA categoria por artigo.
#     - lang          : idioma das instrucoes ("pt" = portugues).
#   A funcao `ac_qual_codebook()`, do pacote `acR`, so' organiza esses
#   pedacos no formato que o resto do pacote espera -- ela nao "pensa"
#   nada sozinha, so' empacota o que escrevemos abaixo.
#
# IMPORTANTE (leia antes de rodar em escala):
# As definicoes abaixo foram escritas a partir das descricoes curtas do
# codebook original. Os `examples_pos`/`examples_neg` sao ILUSTRATIVOS,
# nao trechos reais dos artigos do corpus final. Antes de rodar
# 02_classificacao_llm_conteudo.R no corpus final:
#   1. Rode ac_qual_code() numa amostra piloto de ~20-30 artigos.
#   2. Leia os `reasoning` e o `confidence_score` retornados.
#   3. Substitua os exemplos abaixo por trechos reais (titulo/abstract)
#      dos artigos do piloto que exemplifiquem bem cada categoria.
#   4. So depois rode a base completa.
# Isso segue a recomendacao metodologica do proprio acR (Krippendorff, 2018).
#
# MAPA DO SCRIPT:
#   Blocos 1 a 10 -- um codebook por bloco (mesma ordem do
#                    codebook_burocracia_local.docx). Cada bloco e'
#                    independente dos outros -- pode ler/editar um sem
#                    entender os demais.
#   Bloco final    -- junta os 10 codebooks numa lista e salva cada um em
#                    codebooks/{nome}.yaml.
# =============================================================================

library(acR)


# -----------------------------------------------------------------------------
# 1. Setor de politica publica
# -----------------------------------------------------------------------------
# Pergunta que esta variavel responde: em qual AREA EMPIRICA (saude,
# educacao, etc.) o artigo situa o caso estudado? So' pode ter UMA
# categoria por artigo (multilabel = FALSE).
cb_setor_politica <- ac_qual_codebook(
  name = "setor_politica",
  instructions = paste(
    "Classifique em qual area empirica de politica publica o artigo situa o",
    "caso estudado (o CAMPO DE ATUACAO da burocracia analisada, nao a teoria",
    "mobilizada). Baseie-se no que o titulo e o abstract descrevem como",
    "objeto empirico."
  ),
  categories = list(
    saude = list(
      definition = "Caso estudado em politicas ou servicos de saude (SUS, agentes de saude, vigilancia sanitaria, etc.).",
      examples_pos = c("Analisamos o desempenho de agentes comunitarios de saude em municipios do Nordeste."),
      weight = 1
    ),
    educacao = list(
      definition = "Caso estudado em politicas ou servicos educacionais (professores, gestao escolar, redes municipais de ensino).",
      examples_pos = c("O artigo examina a autonomia de diretores escolares na rede municipal de ensino."),
      weight = 1
    ),
    assistencia_social = list(
      definition = "Caso estudado em assistencia social (CRAS, CREAS, Bolsa Familia, burocracia do SUAS).",
      examples_pos = c("Investigamos a atuacao de assistentes sociais no CRAS de municipios paulistas."),
      weight = 1
    ),
    gestao_fiscal_administrativa_geral = list(
      definition = "Caso estudado em gestao fiscal, administrativa ou de pessoal do municipio, sem foco em um setor social especifico.",
      examples_pos = c("O estudo compara a capacidade administrativa e fiscal de secretarias municipais de administracao."),
      examples_neg = c("Analisamos o desempenho de agentes comunitarios de saude em municipios do Nordeste."),
      weight = 1
    ),
    meio_ambiente_infraestrutura = list(
      definition = "Caso estudado em meio ambiente, saneamento, mobilidade ou infraestrutura urbana.",
      examples_pos = c("O artigo trata da fiscalizacao ambiental exercida por burocratas municipais em areas de protecao."),
      weight = 1
    ),
    seguranca = list(
      definition = "Caso estudado em seguranca publica municipal (guardas municipais, policiamento comunitario, etc.).",
      examples_pos = c("Analisamos a discricionariedade de guardas municipais no policiamento de bairros perifericos."),
      weight = 1
    ),
    transversal = list(
      definition = "O artigo nao se ancora em um setor especifico; trata da burocracia local de forma geral ou comparando varios setores ao mesmo tempo (categoria 'Transversal' do codebook_burocracia_local.docx).",
      examples_pos = c("O estudo compara burocratas de diferentes secretarias municipais sem focar em uma politica especifica."),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 2. Dimensao teorica mobilizada
# -----------------------------------------------------------------------------
# Pergunta: qual(is) corrente(s) conceitual(is) orienta(m) a PERGUNTA do
# artigo? Diferente do bloco 1, aqui multilabel = TRUE: um artigo PODE
# mobilizar mais de uma dimensao teorica ao mesmo tempo (ex.: "Tecnica" e
# "Politica" juntas). E' por causa dessa variavel que o script 02 precisa
# de uma rotina especial (ver PARTE 4.2 la' -- o acR tem um bug conhecido
# com variaveis multilabel).
cb_dimensao_teorica <- ac_qual_codebook(
  name = "dimensao_teorica",
  instructions = paste(
    "Classifique qual(is) corrente(s) conceitual(is) orienta(m) a PERGUNTA do",
    "artigo, independentemente do setor empirico do caso. O artigo pode",
    "mobilizar mais de uma dimensao teorica ao mesmo tempo (ex.: 'Tecnica' e",
    "'Politica' juntas) -- classifique TODAS as que se aplicarem."
  ),
  categories = list(
    tecnica = list(
      definition = "Enfase em capacidade tecnica, competencia administrativa ou profissionalizacao da burocracia.",
      examples_pos = c("O artigo mede a capacidade tecnica dos quadros administrativos municipais."),
      weight = 1
    ),
    politica = list(
      definition = "Enfase em nomeacoes politicas, controle partidario ou relacao entre politicos eleitos e burocratas.",
      examples_pos = c("Investigamos como prefeitos usam cargos de confianca para controlar a burocracia."),
      examples_neg = c("O artigo mede a capacidade tecnica dos quadros administrativos municipais."),
      weight = 1
    ),
    discricionariedade = list(
      definition = "Enfase na margem de decisao do burocrata de linha de frente (street-level bureaucracy) na implementacao.",
      examples_pos = c("O estudo analisa como agentes de saude usam discricionariedade para adaptar a politica ao contexto local."),
      weight = 1
    ),
    representatividade = list(
      definition = "Enfase em burocracia representativa: composicao social/demografica dos burocratas e efeitos sobre equidade.",
      examples_pos = c("Avaliamos se a representatividade racial entre professores afeta resultados educacionais dos alunos."),
      weight = 1
    ),
    resiliencia_resistencia = list(
      definition = "Enfase na capacidade da burocracia de resistir a pressoes politicas, cortes ou choques (resiliencia institucional).",
      examples_pos = c("O artigo mostra como servidores de carreira resistiram ao desmonte de uma secretaria durante a crise fiscal."),
      weight = 1
    )
  ),
  multilabel = TRUE,   # banco humano registra combinacoes (ex.: "Tecnica | Politica")
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 3. Relacao politica-burocracia
# -----------------------------------------------------------------------------
# Pergunta: como o artigo descreve a interacao entre quem foi eleito/nomeado
# politicamente e quem ocupa a burocracia? A parte mais delicada desta
# variavel e' distinguir "conflito_resistencia" (confronto ABERTO, com
# palavras como greve/resistencia/tensao nao resolvida) de
# "barganha_acordo" (ha' negociacao, mesmo que tensa, sem confronto aberto)
# e de "controle_politico" (o politico manda e a burocracia obedece, sem
# tensao nem negociacao visivel).
cb_relacao_politica_burocracia <- ac_qual_codebook(
  name = "relacao_politica_burocracia",
  instructions = paste(
    "Classifique como o artigo descreve a interacao entre quem foi eleito ou",
    "nomeado politicamente e quem ocupa a burocracia: quem manda em quem, ou",
    "como negociam. ATENCAO especial a 'conflito_resistencia': diferente de",
    "'barganha_acordo' (ha' negociacao/concessao mutua, ainda que tensa) e de",
    "'controle_politico' (o politico impoe e a burocracia obedece/se adapta),",
    "'conflito_resistencia' exige um verbo/substantivo de CONFRONTO ABERTO no",
    "resumo (ex.: 'confronto', 'resistencia', 'greve', 'falha na adocao/",
    "implementacao por resistencia', 'tensao nao resolvida') -- nao basta",
    "haver problemas ou desafios na relacao, precisa haver oposicao explicita",
    "de um lado ao arranjo imposto pelo outro."
  ),
  categories = list(
    controle_politico = list(
      definition = "Politicos eleitos ou nomeados exercem controle hierarquico/decisorio sobre a burocracia.",
      examples_pos = c("O prefeito nomeia e demite livremente os secretarios, subordinando a burocracia a agenda politica."),
      weight = 1
    ),
    autonomia_tecnica_insulamento = list(
      definition = "A burocracia opera com insulamento, protegida de ingerencia politica direta.",
      examples_pos = c("Servidores de carreira mantem autonomia tecnica mesmo com trocas de governo."),
      examples_neg = c("O prefeito nomeia e demite livremente os secretarios, subordinando a burocracia a agenda politica."),
      weight = 1
    ),
    barganha_acordo = list(
      definition = "Politicos e burocratas negociam, trocam apoio ou fazem concessoes mutuas -- ha' acomodacao, nao confronto aberto.",
      examples_pos = c("Vereadores e servidores negociam a manutencao de cargos em troca de apoio a projetos do executivo."),
      examples_neg = c(
        "Das pressoes as ousadias: o confronto entre a descentralizacao tutelada e a gestao em rede no SUS -- descreve CONFRONTO explicito entre a descentralizacao tutelada (imposta) e a gestao em rede (resistencia local), nao uma negociacao/concessao mutua (classificado como conflito_resistencia, nao barganha_acordo)."
      ),
      weight = 1
    ),
    conflito_resistencia = list(
      definition = paste(
        "Ha' confronto ABERTO entre burocratas e atores politicos, com",
        "resistencia explicita de um lado ao arranjo/decisao do outro (greve,",
        "confronto, falha de adocao por resistencia, tensao nao resolvida) --",
        "nao apenas desafios ou problemas de implementacao em geral."
      ),
      examples_pos = c(
        "Servidores organizaram greve para resistir a uma reforma administrativa imposta pelo prefeito.",
        "Das pressoes as ousadias: o confronto entre a descentralizacao tutelada e a gestao em rede no SUS -- confronto explicito entre o modelo de descentralizacao tutelada imposto e a gestao em rede que resiste a ele.",
        "A falta de trabalho institucional e mudancas organizacionais incompletas em municipios brasileiros -- explica a FALHA da adocao compulsoria de novas praticas por resistencia organizacional, nao uma negociacao bem-sucedida."
      ),
      weight = 1
    ),
    nao_aborda_diretamente = list(
      definition = "O artigo nao discute explicitamente a relacao entre politicos e burocratas.",
      examples_pos = c("O estudo foca exclusivamente em indicadores de desempenho, sem discutir a relacao com o poder politico."),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 4. Explicacao do arranjo burocratico
# -----------------------------------------------------------------------------
# Pergunta: o que o artigo aponta como CAUSA de a burocracia estar
# organizada daquele jeito? Se o artigo nao discute causa nenhuma (e' so'
# descritivo, ou usa o arranjo como variavel de controle), a categoria e'
# "nao_aplicavel". Uma explicacao causal conta MESMO que nao venha com a
# palavra "porque" -- se o resumo diz que o estudo testa se X EXPLICA,
# INFLUENCIA ou e' PREDITOR do arranjo/desempenho, isso ja' conta.
cb_explicacao_arranjo <- ac_qual_codebook(
  name = "explicacao_arranjo",
  instructions = paste(
    "Classifique o que o artigo aponta como CAUSA de a burocracia estar",
    "organizada daquele jeito especifico (a explicacao causal proposta).",
    "Se o artigo nao discute causa alguma para o arranjo (ex.: e' apenas",
    "descritivo ou usa o arranjo como variavel de controle, sem explicar",
    "sua origem), use 'nao_aplicavel'. IMPORTANTE: a explicacao causal pode",
    "estar OPERACIONALIZADA como variavel independente/preditor num modelo",
    "empirico, nao precisa vir com a palavra 'porque' -- se o resumo diz que",
    "o estudo testa se X (ex.: profissionalizacao, desenho institucional,",
    "capacidade fiscal) EXPLICA, INFLUENCIA, DETERMINA ou e' PREDITOR do",
    "arranjo/desempenho da burocracia, isso conta como explicacao causal,",
    "NAO como 'nao_aplicavel'."
  ),
  categories = list(
    nao_aplicavel = list(
      definition = "O artigo nao aponta nenhuma causa/explicacao para o arranjo burocratico observado (uso descritivo, ou o arranjo e' tratado como dado, nao como algo a explicar).",
      examples_pos = c("O estudo apenas descreve o quadro de pessoal das secretarias municipais, sem discutir por que ele e' assim."),
      weight = 1
    ),
    politica_eleitoral = list(
      definition = "O arranjo e explicado por incentivos eleitorais, competicao partidaria ou ciclos politicos.",
      examples_pos = c("A rotatividade de cargos e explicada pela alternancia de coalizoes apos as eleicoes municipais."),
      weight = 1
    ),
    capacidade_administrativa_fiscal = list(
      definition = "O arranjo e explicado por restricoes, recursos ou fatores contingenciais administrativos e fiscais do municipio (inclui estudos que testam empiricamente esses fatores como determinantes de desempenho/eficiencia).",
      examples_pos = c(
        "Municipios com maior receita propria estruturam equipes tecnicas mais robustas.",
        "Influencia de fatores contingenciais no desempenho socioeconomico de governos locais -- testa se fatores contingenciais (ambiente externo, tecnologia, estrutura, recursos) influenciam o desempenho municipal."
      ),
      examples_neg = c("O estudo apenas descreve o quadro de pessoal das secretarias municipais, sem discutir por que ele e' assim."),
      weight = 1
    ),
    perfil_gestor_local = list(
      definition = "O arranjo e explicado por caracteristicas pessoais/profissionais do prefeito ou secretario (formacao, experiencia, estilo de gestao).",
      examples_pos = c("A trajetoria profissional do prefeito explica a escolha por profissionalizar a equipe tecnica."),
      weight = 1
    ),
    desenho_institucional_inducao_federal = list(
      definition = paste(
        "O arranjo e explicado por regras, incentivos, instrumentos ou",
        "condicionalidades definidas pelo governo federal/estadual (inducao",
        "vertical) -- inclui artigos sobre coordenacao intergovernamental,",
        "instrumentos de integracao de politicas (ex.: cadastros unicos,",
        "conselhos, redes de politica) quando o resumo trata esses",
        "instrumentos como o que MOLDA o arranjo local, nao so' como pano de",
        "fundo descritivo."
      ),
      examples_pos = c(
        "A exigencia federal de plano de carreira para acessar recursos do fundo nacional moldou a estrutura da secretaria.",
        "Os multiplos papeis dos governos estaduais na politica educacional brasileira -- analisa como a coordenacao do governo federal e' central para a consistencia das politicas sociais subnacionais, moldando o papel dos governos estaduais.",
        "Instrumentos e integracao de politicas publicas: a rede do Cadastro Unico -- analisa instrumentos de implementacao (o Cadastro Unico) como o que estrutura/integra a politica, nao apenas descreve a rede."
      ),
      examples_neg = c("O estudo apenas descreve o quadro de pessoal das secretarias municipais, sem discutir por que ele e' assim."),
      weight = 1
    ),
    profissionalizacao_carreira = list(
      definition = paste(
        "O arranjo/desempenho e' explicado pelo grau de profissionalizacao,",
        "qualificacao ou existencia de carreira burocratica consolidada --",
        "inclui estudos que testam empiricamente se a composicao/qualificacao",
        "da burocracia (ex.: proporcao de servidores com ensino superior,",
        "status profissional) EXPLICA ou INFLUENCIA outro resultado (ex.:",
        "digitalizacao, capacidade estatal, implementacao de politicas)."
      ),
      examples_pos = c(
        "A existencia de concurso publico e plano de carreira consolidado explica a estabilidade da equipe tecnica.",
        "A configuracao da composicao burocratica importa? O papel da burocracia na transformacao digital dos municipios brasileiros -- testa se a composicao e qualificacao da burocracia influenciam o processo de digitalizacao municipal.",
        "Burocracias profissionais ampliam capacidade estatal para implementar politicas? -- usa 'servidores com ensino superior' como proxy de profissionalizacao para explicar a capacidade estatal de implementacao."
      ),
      examples_neg = c("O estudo apenas descreve o quadro de pessoal das secretarias municipais, sem discutir por que ele e' assim."),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 5. Consequencia do arranjo burocratico (tipo de efeito)
# -----------------------------------------------------------------------------
# Pergunta: que TIPO de efeito o artigo atribui ao arranjo burocratico
# analisado? "desempenho_politica" e' a categoria generica/padrao -- so' use
# quando o efeito NAO se encaixar melhor em "resiliencia_institucional"
# (continuidade/estabilidade frente a choques) nem em
# "equidade_representatividade" (inclusao/representacao de grupos), que tem
# prioridade quando aplicaveis.
cb_consequencia_arranjo <- ac_qual_codebook(
  name = "consequencia_arranjo",
  instructions = paste(
    "Classifique que TIPO de efeito o artigo atribui ao arranjo burocratico",
    "analisado (desempenho, corrupcao, equidade, etc.). Se o artigo for",
    "teorico-descritivo e nao mensurar nenhum efeito empirico, use",
    "'nao_mensurado'. ATENCAO: 'resiliencia_institucional' e",
    "'equidade_representatividade' sao mais especificos que",
    "'desempenho_politica' e tem PRIORIDADE quando aplicaveis -- desempenho",
    "e' o efeito generico/padrao; so' classifique como desempenho se o",
    "efeito NAO for especificamente sobre continuidade/estabilidade frente a",
    "choques (resiliencia) nem sobre inclusao/representacao de grupos",
    "(equidade)."
  ),
  categories = list(
    desempenho_politica = list(
      definition = "O efeito medido e sobre o desempenho/qualidade da implementacao da politica publica -- categoria generica, usada quando o efeito NAO se encaixa melhor em resiliencia_institucional ou equidade_representatividade.",
      examples_pos = c("O arranjo burocratico esta associado a melhores indicadores de cobertura do servico."),
      weight = 1
    ),
    accountability_corrupcao = list(
      definition = "O efeito medido e sobre controle, transparencia, accountability ou corrupcao.",
      examples_pos = c("A rotatividade de cargos de confianca aumenta o risco de desvio de recursos publicos."),
      weight = 1
    ),
    equidade_representatividade = list(
      definition = paste(
        "O efeito medido e sobre equidade, inclusao, representatividade de",
        "grupos sociais OU sobre participacao/representacao em espacos",
        "deliberativos e conselhos de politica publica (mesmo sem falar de",
        "raca/genero explicitamente -- participacao de atores sociais em",
        "arenas decisorias tambem e' representatividade)."
      ),
      examples_pos = c(
        "A maior representatividade racial entre os burocratas reduziu desigualdades de acesso ao servico.",
        "O mapeamento da institucionalizacao dos conselhos gestores de politicas publicas nos municipios brasileiros -- analisa conselhos como espacos de participacao/representacao social nas politicas publicas."
      ),
      examples_neg = c("O arranjo burocratico esta associado a melhores indicadores de cobertura do servico."),
      weight = 1
    ),
    resiliencia_institucional = list(
      definition = paste(
        "O efeito medido e sobre a capacidade da burocracia de se manter",
        "estavel, continuar entregando servicos ou adaptar-se ativamente",
        "frente a choques, crises, pressoes politicas ou ambientes",
        "institucionais desfavoraveis -- inclui burocratas que criam",
        "estrategias/repertorios de acao para sustentar politicas em",
        "contextos adversos (ativismo/criatividade institucional), nao so'",
        "'sobreviver' passivamente."
      ),
      examples_pos = c(
        "A equipe tecnica manteve a continuidade do programa mesmo apos a troca de governo.",
        "Activism among bureaucrats: creative social housing work in a conservative institutional setting -- burocratas ativistas desenvolvem estrategias criativas para sustentar politicas de habitacao social num ambiente institucional desfavoravel/conservador."
      ),
      examples_neg = c("O arranjo burocratico esta associado a melhores indicadores de cobertura do servico."),
      weight = 1
    ),
    nao_mensurado = list(
      definition = "O artigo e teorico-descritivo e nao mensura empiricamente nenhum efeito do arranjo burocratico.",
      examples_pos = c("O texto discute conceitualmente os tipos de arranjo burocratico local, sem testar seus efeitos."),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 6. Valoracao da burocracia nos efeitos encontrados (direcao)
# -----------------------------------------------------------------------------
# Pergunta: o atributo burocratico analisado favorece ou prejudica o
# resultado observado? Repare que "ambivalente_mista" tem weight = 1.2 (as
# demais categorias, aqui e nos outros blocos, tem weight = 1) -- isso da'
# um peso levemente maior a essa categoria na hora do LLM decidir, por ser
# mais dificil de identificar. O ponto mais delicado da variavel e'
# distinguir "ambivalente_mista" (dois efeitos EXPLICITOS em direcoes
# opostas) de "neutra_descritiva" (o artigo so' descreve, sem avaliar em
# direcao nenhuma) -- ausencia de avaliacao NAO e' o mesmo que avaliacao
# mista.
cb_valoracao_burocracia <- ac_qual_codebook(
  name = "valoracao_burocracia",
  instructions = paste(
    "Classifique se o atributo burocratico analisado favorece (positiva) ou",
    "prejudica (negativa) o resultado observado, e' ambivalente/mista, ou o",
    "artigo e' meramente descritivo, sem atribuir direcao de valor (neutra).",
    "ATENCAO especial a 'ambivalente_mista' vs. 'neutra_descritiva': use",
    "ambivalente_mista SO' quando o resumo mencionar EXPLICITAMENTE efeitos",
    "em DUAS direcoes opostas (ex.: 'positivo em X mas negativo em Y',",
    "'melhora A e piora B', resultados 'mistos' ou 'heterogeneos' entre",
    "grupos/contextos). Se o artigo so' DESCREVE ou ANALISA um fenomeno sem",
    "chegar a nenhuma avaliacao de efeito (nem positiva, nem negativa, nem",
    "as duas), a categoria e' 'neutra_descritiva', nao 'ambivalente_mista' --",
    "ambivalente exige duas avaliacoes conflitantes, nao ausencia de",
    "avaliacao."
  ),
  categories = list(
    positiva = list(
      definition = "O atributo burocratico analisado favorece o resultado observado.",
      examples_pos = c("A profissionalizacao da equipe elevou a qualidade do servico prestado."),
      weight = 1
    ),
    negativa = list(
      definition = "O atributo burocratico analisado prejudica o resultado observado.",
      examples_pos = c("A alta rotatividade de cargos prejudicou a continuidade e a qualidade do servico."),
      weight = 1
    ),
    ambivalente_mista = list(
      definition = "O artigo encontra EFEITOS EXPLICITOS em direcoes opostas (positivo em um aspecto/contexto, negativo em outro), dependendo do contexto ou da dimensao analisada -- nao apenas describe um fenomeno sem avaliar.",
      examples_pos = c(
        "A insulamento tecnico melhorou a eficiencia, mas reduziu a responsividade a demandas locais."
      ),
      examples_neg = c(
        "O papel da burocracia de nivel de rua na implementacao e (re)formulacao da Politica Nacional de Humanizacao dos servicos de saude de Porto Alegre (RS) -- analisa a interacao entre planejamento e implementacao local via discricionariedade de burocratas de linha de frente, SEM concluir que houve efeito positivo em um aspecto e negativo em outro (e' descritivo/analitico, classificado como neutra_descritiva, nao ambivalente_mista).",
        "Analise espacial da burocracia da assistencia social nos municipios brasileiros -- descreve dados sobre capacidade de implementacao e sua distribuicao espacial, sem atribuir uma avaliacao de efeito misto/conflitante (neutra_descritiva, nao ambivalente_mista)."
      ),
      weight = 1.2
    ),
    neutra_descritiva = list(
      definition = paste(
        "O artigo descreve, mapeia ou analisa o atributo burocratico SEM",
        "atribuir uma direcao de valor ao efeito -- inclui estudos que",
        "analisam processos, interacoes ou capacidades sem concluir se o",
        "resultado foi bom ou ruim, ou se foi misto entre duas direcoes",
        "especificas."
      ),
      examples_pos = c(
        "O estudo mapeia os tipos de arranjo burocratico existentes nos municipios, sem avaliar seus efeitos.",
        "O papel da burocracia de nivel de rua na implementacao e (re)formulacao da Politica Nacional de Humanizacao dos servicos de saude de Porto Alegre (RS) -- analisa o processo de influencia mutua entre planejamento e implementacao local, sem avaliar se o resultado foi positivo, negativo ou misto."
      ),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 7. Enquadramento normativo da burocracia
# -----------------------------------------------------------------------------
# Pergunta: qual e' a mensagem de fundo do artigo sobre burocracia em
# geral? "ambivalente" NAO e' uma categoria residual -- so' use quando o
# resumo mencionar EXPLICITAMENTE tanto um elemento de risco/controle
# QUANTO um elemento de recurso/fortalecimento, sem que um dos dois
# predomine na conclusao. Um artigo que so' menciona desafios tecnicos a
# caminho de defender fortalecimento continua sendo
# "recurso_a_fortalecer" -- a mera existencia de um problema no meio do
# caminho nao torna o enquadramento ambivalente.
cb_enquadramento_normativo <- ac_qual_codebook(
  name = "enquadramento_normativo",
  instructions = paste(
    "Classifique qual e' a mensagem de fundo do artigo sobre burocracia em geral.",
    "ATENCAO especial a 'ambivalente': nao e' uma categoria residual/generica --",
    "so' use quando o resumo mencionar EXPLICITAMENTE tanto um elemento de risco/",
    "controle QUANTO um elemento de recurso/fortalecimento, sem que um dos dois",
    "predomine na conclusao. Resumos que so' mencionam capacidade, profissionalizacao",
    "ou desempenho administrativo (mesmo describendo desafios/limitacoes tecnicas ao",
    "longo do caminho) continuam sendo 'recurso_a_fortalecer' -- a mera existencia de",
    "um problema ou desafio NAO torna o enquadramento ambivalente; o que torna",
    "ambivalente e' o artigo apontar EFEITOS ou AVALIACOES em direcoes opostas."
  ),
  categories = list(
    risco_a_controlar = list(
      definition = "A burocracia e' tratada principalmente como um risco que precisa ser controlado, fiscalizado ou limitado.",
      examples_pos = c("O artigo enfatiza a necessidade de mais controles para conter o poder discricionario dos burocratas."),
      examples_neg = c(
        "Nomeacoes politicas nos governos municipais e performance burocratica: avaliando o desempenho -- o artigo demonstra padroes de nomeacoes politicas e como refletem o desempenho institucional, sem defender mais controle nem apontar so' risco (classificado como ambivalente, nao risco_a_controlar)."
      ),
      weight = 1
    ),
    recurso_a_fortalecer = list(
      definition = paste(
        "A burocracia e' tratada principalmente como um recurso ou capacidade a ser",
        "fortalecida -- inclui artigos que discutem desafios, limitacoes tecnicas ou",
        "obstaculos administrativos ENQUANTO PARTE do argumento de fortalecimento",
        "(ex.: 'a falta de X limita a capacidade, por isso e' preciso investir em Y'),",
        "desde que a conclusao/implicacao do resumo aponte para fortalecer, nao para",
        "controlar nem para um resultado misto."
      ),
      examples_pos = c("O artigo defende investimento em profissionalizacao como caminho para melhorar a politica publica."),
      examples_neg = c(
        "O artigo enfatiza a necessidade de mais controles para conter o poder discricionario dos burocratas.",
        "A (re)producao de entrelacamentos sociomateriais na pratica de transicao entre governos municipais -- estuda como servidores de carreira lidam com a transicao de governo por meio de praticas sociomateriais; nao defende fortalecimento nem aponta risco, descreve o fenomeno em si (classificado como ambivalente/sem inclinacao clara, nao recurso_a_fortalecer)."
      ),
      weight = 1
    ),
    ambivalente = list(
      definition = paste(
        "O artigo apresenta EFEITOS, AVALIACOES ou RESULTADOS em direcoes opostas",
        "sobre a burocracia (ex.: 'positivo em um contexto, negativo em outro',",
        "'melhora X mas piora Y'), OU e' um estudo primariamente descritivo/analitico",
        "que nao avalia a burocracia nem como risco a conter nem como recurso a",
        "fortalecer -- so' descreve/explica um fenomeno sem tomar posicao normativa",
        "clara em nenhuma das duas direcoes. NAO confundir com um artigo que apenas",
        "menciona desafios tecnicos a caminho de defender fortalecimento (esse e'",
        "'recurso_a_fortalecer', nao ambivalente)."
      ),
      examples_pos = c(
        "Nomeacoes politicas nos governos municipais e performance burocratica: avaliando o desempenho -- demonstra padroes de nomeacoes politicas que refletem variados niveis de qualidade institucional, sem concluir que nomeacoes sao so' risco ou so' precisam de mais capacidade tecnica.",
        "A estrutura de provisao dos servicos de saneamento basico no Brasil: uma analise comparativa do desempenho dos provedores publicos e privados -- compara desempenho de provedores publicos e privados sem evidencia forte de que um grupo supere o outro, resultado misto/inconclusivo.",
        "O papel da burocracia de nivel de rua na implementacao e (re)formulacao da Politica Nacional de Humanizacao dos servicos de saude de Porto Alegre (RS) -- analisa a discricionariedade de burocratas de linha de frente na (re)formulacao de politica, descrevendo o fenomeno sem posicionar a discricionariedade como risco a conter nem como capacidade a fortalecer."
      ),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 8. Grau de agencia atribuida ao burocrata
# -----------------------------------------------------------------------------
# Pergunta: o texto trata os burocratas como sujeitos que decidem e agem
# (resistem e/ou negociam), ou como pecas passivas de uma estrutura
# (numeros numa regressao, categorias administrativas sem voz propria)?
# Use "ambos" quando o desenho metodologico combina os dois olhares (ex.:
# mede a burocracia como variavel E tambem entrevista/da' voz aos
# burocratas -- combinacao quanti+quali), ou quando o burocrata tem margem
# de decisao MESMO sendo, ao mesmo tempo, peca de um sistema estruturado.
cb_grau_agencia <- ac_qual_codebook(
  name = "grau_agencia",
  instructions = paste(
    "Classifique se o texto trata os burocratas como sujeitos que decidem e",
    "agem (resistem e/ou negociam) ou como pecas passivas de uma estrutura",
    "(numeros numa regressao, categorias administrativas sem voz propria).",
    "ATENCAO especial a 'ambos': use quando o DESENHO METODOLOGICO combina",
    "os dois olhares (ex.: mede/quantifica a burocracia como variavel E",
    "tambem discute/entrevista/da voz a decisao e estrategia dos burocratas",
    "-- combinacao de metodos quanti+quali, ou de dados administrativos com",
    "entrevistas/etnografia), OU quando o proprio objeto do artigo e' sobre",
    "burocratas que atuam DENTRO de uma estrutura/instrumento formal (o",
    "burocrata tem margem de decisao MESMO sendo tambem, ao mesmo tempo,",
    "peca de um sistema estruturado, ex.: agente comunitario de saude que",
    "tem vinculo/funcao formal definida mas exerce escolhas na pratica)."
  ),
  categories = list(
    agente_com_escolhas_proprias = list(
      definition = "Os burocratas sao retratados PRINCIPAL OU EXCLUSIVAMENTE como atores com margem de decisao, estrategia ou resistencia propria -- sem tratamento simetrico como variavel/estrutura no mesmo estudo.",
      examples_pos = c("Os agentes de saude negociam ativamente a forma de implementar a politica no territorio."),
      examples_neg = c(
        "Entre o vinculo e o distanciamento: desafios na atuacao de Agentes Comunitarias de Saude -- embora enfatize a atuacao (escolhas) dos agentes comunitarios de saude, tambem os situa formalmente como pecas de um sistema estruturado de atencao primaria (PHC), o que aproxima de 'ambos' quando o resumo tambem trata a funcao formal deles como estrutura."
      ),
      weight = 1
    ),
    estrutura_instrumento_passivo = list(
      definition = "Os burocratas aparecem APENAS como categorias administrativas ou variaveis numericas, sem NENHUMA discussao de agencia, decisao ou estrategia propria no resumo.",
      examples_pos = c("O numero de servidores por secretaria e' usado como proxy de capacidade administrativa, sem discutir seu comportamento."),
      examples_neg = c("Os agentes de saude negociam ativamente a forma de implementar a politica no territorio."),
      weight = 1
    ),
    ambos = list(
      definition = paste(
        "O artigo combina os dois olhares: trata os burocratas tanto como",
        "estrutura/variavel administrativa QUANTO como agentes com escolhas",
        "proprias -- sinal tipico no resumo: combina metodo quantitativo",
        "(dados administrativos, indicadores) com metodo qualitativo",
        "(entrevistas, etnografia, estudo de caso sobre estrategias de",
        "atuacao), OU descreve o burocrata ocupando um papel/vinculo formal",
        "estruturado ao mesmo tempo que exerce escolhas dentro dele."
      ),
      examples_pos = c(
        "O estudo quantifica o quadro de pessoal, mas tambem entrevista servidores sobre suas estrategias de trabalho.",
        "Institucionalizacao da Politica Nacional de Residuos Solidos: dilemas e constrangimentos na Regiao Metropolitana de Aracaju (SE) -- avalia a institucionalizacao (estrutura formal) a partir da gestao compartilhada, usando pesquisa qualitativa com entrevistas sobre a atuacao dos atores dentro dessa estrutura.",
        "Entre o vinculo e o distanciamento: desafios na atuacao de Agentes Comunitarias de Saude -- agentes comunitarios de saude tem funcao formal estruturada (vinculo com familias no territorio) e, ao mesmo tempo, exercem escolhas praticas nessa atuacao."
      ),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 9. Referencia ao nivel federal como parametro
# -----------------------------------------------------------------------------
# Pergunta: o artigo usa o padrao federal/nacional como vara de medir a
# burocracia local, ou trata o caso local por si mesmo? So' 2 categorias,
# mutuamente exclusivas -- e' a variavel mais simples do arquivo.
cb_referencia_federal <- ac_qual_codebook(
  name = "referencia_federal",
  instructions = paste(
    "Classifique se o artigo usa o padrao federal/nacional como vara de medir",
    "a burocracia local, ou trata o caso local por si mesmo, sem esse",
    "referencial comparativo."
  ),
  categories = list(
    usa_federal_como_benchmark = list(
      definition = "O artigo compara explicitamente a burocracia local ao padrao ou a normas do governo federal.",
      examples_pos = c("Comparamos a profissionalizacao da burocracia municipal com os parametros do servico civil federal."),
      weight = 1
    ),
    trata_local_como_caso_autonomo = list(
      definition = "O artigo analisa a burocracia local sem usar o nivel federal como referencia comparativa.",
      examples_pos = c("O estudo analisa a burocracia municipal em seus proprios termos, sem comparacao com o governo federal."),
      examples_neg = c("Comparamos a profissionalizacao da burocracia municipal com os parametros do servico civil federal."),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# -----------------------------------------------------------------------------
# 10. Escopo empirico
# -----------------------------------------------------------------------------
# Pergunta: sobre quantos casos a conclusao do artigo se sustenta? Isso
# afeta o quanto o achado pode ser generalizado. 4 categorias, ordenadas
# aproximadamente do escopo mais estreito (caso_unico) ao mais amplo
# (amostra_grande_n_maior_30), mais uma categoria a parte para artigos sem
# nenhum caso empirico (teorico_sem_caso).
cb_escopo_empirico <- ac_qual_codebook(
  name = "escopo_empirico",
  instructions = paste(
    "Classifique sobre quantos casos a conclusao do artigo se sustenta, o",
    "que afeta o quanto se pode generalizar o achado."
  ),
  categories = list(
    caso_unico = list(
      definition = "O artigo se baseia em um unico municipio ou estudo de caso.",
      examples_pos = c("Este e' um estudo de caso sobre a Secretaria de Educacao de um unico municipio."),
      weight = 1
    ),
    municipios_comparados_n_pequeno = list(
      definition = "O artigo compara um numero pequeno de municipios (mais de um, mas nao uma amostra grande).",
      examples_pos = c("Comparamos a burocracia de tres municipios de porte medio no interior de Minas Gerais."),
      weight = 1
    ),
    amostra_grande_n_maior_30 = list(
      definition = "O artigo usa uma amostra grande, com mais de 30 municipios.",
      examples_pos = c("A analise cobre uma amostra de 250 municipios brasileiros com dados do Censo do Servidor Publico."),
      weight = 1
    ),
    teorico_sem_caso = list(
      definition = "O artigo e' teorico ou conceitual e nao analisa nenhum caso empirico concreto.",
      examples_pos = c("O artigo propõe uma tipologia teorica de arranjos burocraticos locais, sem aplicacao empirica."),
      weight = 1
    )
  ),
  multilabel = FALSE,
  lang = "pt"
)


# =============================================================================
# Bloco final -- junta os 10 codebooks e salva cada um em codebooks/{nome}.yaml
# =============================================================================
# `list(...)` abaixo so' agrupa os 10 objetos criados acima numa unica lista
# NOMEADA (cada elemento tem um nome, ex. "setor_politica"), para o script
# 02 conseguir percorrer todos de uma vez. Nada e' calculado aqui -- e' so'
# reunir o que ja foi construido nos blocos 1 a 10.
codebooks_burocracia_local <- list(
  setor_politica               = cb_setor_politica,
  dimensao_teorica             = cb_dimensao_teorica,
  relacao_politica_burocracia  = cb_relacao_politica_burocracia,
  explicacao_arranjo           = cb_explicacao_arranjo,
  consequencia_arranjo         = cb_consequencia_arranjo,
  valoracao_burocracia         = cb_valoracao_burocracia,
  enquadramento_normativo      = cb_enquadramento_normativo,
  grau_agencia                 = cb_grau_agencia,
  referencia_federal           = cb_referencia_federal,
  escopo_empirico              = cb_escopo_empirico
)

# Cria a pasta codebooks/ se ela ainda nao existir (showWarnings = FALSE so'
# evita um aviso desnecessario caso a pasta ja exista).
dir.create("codebooks", showWarnings = FALSE)

# Salva cada codebook em YAML, um arquivo por variavel (ex.: codebooks/
# setor_politica.yaml), para ficar versionavel no git e legivel fora do R.
# Um `for` simples percorre os 10 nomes da lista, um de cada vez -- em cada
# volta do loop, `nm` e' o nome de UMA variavel (ex.: "setor_politica" na
# primeira volta, "dimensao_teorica" na segunda, e assim por diante).
for (nm in names(codebooks_burocracia_local)) {
  ac_qual_save_codebook(
    codebooks_burocracia_local[[nm]],
    path = file.path("codebooks", paste0(nm, ".yaml"))
  )
}

message("Codebooks construidos e salvos em codebooks/. Revise antes de rodar 02_classificacao_llm_conteudo.R.")
