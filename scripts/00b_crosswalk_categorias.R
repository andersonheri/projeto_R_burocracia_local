# =============================================================================
# 00b_crosswalk_categorias.R
# Dicionario UNICO (fonte da verdade) que traduz entre os DOIS vocabularios
# usados no projeto:
#   - slugs do acR (scripts 01/02): snake_case, sem acento (ex.: "tecnica",
#     "gestao_fiscal_administrativa_geral") -- e' o que fica gravado nas
#     colunas "_llm" do banco (data/banco_114_llm_x_humano.xlsx), porque e'
#     a CHAVE ESTAVEL usada por 02 (reaproveitamento por variavel) e por
#     03 (comparacao humano x LLM).
#   - rotulos humanos (banco_final_114 / codebook_burocracia_local.docx):
#     em portugues, com acento e espaco (ex.: "Técnica",
#     "Gestão fiscal-administrativa geral").
#
# Antes este dicionario vivia só dentro de 03_validacao_humana.R. Foi
# extraido para ca' porque 02_classificacao_llm_conteudo.R tambem precisa
# dele agora, para gerar a copia com cabecalho E VALORES legiveis
# (data/banco_114_llm_x_humano_legivel.xlsx) sem re-rodar o LLM -- e' so'
# uma tradução de rotulo em cima do que ja foi classificado.
#
# IMPORTANTE: se voce alterar nomes de variavel ou categorias em
# 01_construir_codebooks_conteudo.R, atualize este arquivo tambem -- senao
# a comparacao/traducao falha silenciosamente (vira NA ou mantem o slug cru).
# =============================================================================

library(stringr)

# nome da variavel no acR (01/02)  ->  nome da coluna humana no banco_final_114
crosswalk_variaveis <- c(
  setor_politica               = "setor_politica_publica",
  dimensao_teorica              = "dimensao_teorica",       # multilabel, tratada a parte
  relacao_politica_burocracia  = "relacao_politica_burocracia",
  explicacao_arranjo           = "explicacao_arranjo",
  consequencia_arranjo         = "tipo_efeito",
  valoracao_burocracia         = "valoracao",
  enquadramento_normativo      = "enquadramento_normativo",
  grau_agencia                 = "grau_agencia",
  referencia_federal           = "referencia_federal",
  escopo_empirico               = "escopo_empirico"
)

# categoria_slug_llm -> rotulo humano (banco_final_114), por variavel
crosswalk_categorias <- list(
  setor_politica = c(
    saude                               = "Saúde",
    educacao                            = "Educação",
    assistencia_social                  = "Assistência social",
    gestao_fiscal_administrativa_geral  = "Gestão fiscal-administrativa geral",
    meio_ambiente_infraestrutura        = "Meio ambiente-infraestrutura",
    seguranca                           = "Segurança",
    transversal                         = "Transversal"
  ),
  relacao_politica_burocracia = c(
    controle_politico               = "Controle político",
    autonomia_tecnica_insulamento   = "Autonomia técnica-insulamento",
    barganha_acordo                 = "Barganha-acordo",
    conflito_resistencia            = "Conflito-resistência",
    nao_aborda_diretamente          = "Não aborda diretamente"
  ),
  explicacao_arranjo = c(
    nao_aplicavel                            = "Não aplicável",
    politica_eleitoral                       = "Política/eleitoral",
    capacidade_administrativa_fiscal         = "Capacidade administrativa-fiscal",
    perfil_gestor_local                      = "Perfil do gestor local",
    desenho_institucional_inducao_federal    = "Desenho institucional-indução federal",
    profissionalizacao_carreira              = "Profissionalização-carreira"
  ),
  consequencia_arranjo = c(
    desempenho_politica            = "Desempenho da política",
    accountability_corrupcao       = "Accountability-corrupção",
    equidade_representatividade    = "Equidade-representatividade",
    resiliencia_institucional      = "Resiliência institucional",
    nao_mensurado                  = "Não mensurado"
  ),
  valoracao_burocracia = c(
    positiva            = "Positiva",
    negativa             = "Negativa",
    ambivalente_mista    = "Ambivalente-mista",
    neutra_descritiva    = "Neutra-descritiva"
  ),
  enquadramento_normativo = c(
    risco_a_controlar        = "Risco a controlar",
    recurso_a_fortalecer     = "Recurso a fortalecer",
    ambivalente               = "Ambivalente"
  ),
  grau_agencia = c(
    agente_com_escolhas_proprias    = "Agente com escolhas próprias",
    estrutura_instrumento_passivo   = "Estrutura-instrumento passivo",
    ambos                            = "Ambos"
  ),
  referencia_federal = c(
    usa_federal_como_benchmark        = "Usa o federal como benchmark",
    trata_local_como_caso_autonomo    = "Trata o local como caso autônomo"
  ),
  escopo_empirico = c(
    caso_unico                          = "Caso único",
    municipios_comparados_n_pequeno     = "Municípios comparados (N pequeno)",
    amostra_grande_n_maior_30           = "Amostra grande (N>30 municípios)",
    teorico_sem_caso                    = "Teórico, sem caso"
  ),
  dimensao_teorica = c(
    tecnica                    = "Técnica",
    politica                   = "Política",
    discricionariedade         = "Discricionariedade",
    representatividade         = "Representatividade",
    resiliencia_resistencia    = "Resiliência-Resistência"
  )
)

# rotulo humano -> slug (usado em 03, para comparar humano x LLM na mesma
# "lingua"). Retorna NA se o rotulo nao existir no crosswalk (sinal de
# categoria nova/erro de digitacao no banco humano).
rotulo_para_slug <- function(rotulo, mapa) {
  idx <- match(str_squish(rotulo), str_squish(mapa))
  names(mapa)[idx]
}

# slug -> rotulo humano (usado em 02, para "traduzir" o que o LLM devolveu
# em algo legivel sem precisar rodar o LLM de novo). Se o slug nao existir
# no crosswalk (categoria nova, fora do dicionario), cai num fallback
# generico ("substitui _ por espaco e capitaliza") em vez de quebrar --
# assim nunca fica em branco, so' menos bonito.
slug_para_rotulo <- function(slug, mapa) {
  if (is.na(slug) || !nzchar(slug)) return(slug)
  rotulo <- unname(mapa[slug])
  if (is.na(rotulo)) {
    rotulo <- str_to_sentence(gsub("_", " ", slug))
  }
  rotulo
}

# Aplica slug_para_rotulo() a um valor que pode ter varias categorias
# separadas por "|" (caso multilabel, ex.: "tecnica|politica"), devolvendo
# "Técnica | Política" -- mesmo formato ja usado no banco humano original
# para dimensao_teorica (ver nota em 03_validacao_humana.R).
slugs_para_rotulo_multilabel <- function(valor, mapa) {
  if (is.na(valor) || !nzchar(valor)) return(valor)
  partes <- str_split(valor, "\\s*\\|\\s*")[[1]]
  rotulos <- vapply(partes, slug_para_rotulo, character(1), mapa = mapa)
  paste(rotulos, collapse = " | ")
}
