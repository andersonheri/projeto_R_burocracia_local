# =============================================================================
# 00_setup_pacotes.R
# Instala e carrega as dependências do projeto. Roda uma única vez
# (ou sempre que um pacote estiver faltando).
# =============================================================================

pacotes_cran <- c(
  "remotes",         # instalar pacotes do GitHub (acR)
  "ellmer",          # interface unificada com LLMs (Google Gemini, usado no projeto; tambem suporta Groq, OpenAI, Anthropic, etc.)
  "dplyr",           # manipulação de dados
  "readr",           # leitura de CSV
  "tidyr",           # pivot/organização de tabelas
  "stringr",         # manipulação de texto
  "stringi",         # normalização de acentos/caixa (usado na triagem inicial, 00_triagem_inicial_rsl)
  "janitor",         # tabelas de frequência (tabyl)
  "openxlsx",        # leitura/escrita de .xlsx
  "scales",          # formatação de eixos/percentuais em gráficos e tabelas
  "purrr",           # iteração funcional (map sobre os 10 codebooks e sobre os periodicos na triagem inicial)
  "rlang",           # tidy eval (!!, :=, .data[[...]])
  "usethis",         # usethis::edit_r_environ() para editar o .Renviron com seguranca
  "irr",             # Alpha de Krippendorff, usado por acR::ac_qual_reliability()
  "cli",             # barra de progresso da rotina propria em 02 (mesmo padrao do acR)
  "jsonlite",        # le o JSON de resposta do LLM em 02 (dimensao_teorica)
  "tibble",          # tibble() -- usado em 02/03/04
  "ggplot2",         # graficos de 05_graficos_paper.R
  "easyScieloPack"   # busca no Scielo, usado em 00_triagem_inicial_rsl/0_GettingData.R
)

instalar_se_faltar <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
  }
}

invisible(lapply(pacotes_cran, instalar_se_faltar))

# acR não está no CRAN -- instalar do GitHub do Anderson
if (!requireNamespace("acR", quietly = TRUE)) {
  remotes::install_github("andersonheri/acR")
}

# Checagem da chave de API do Gemini (necessária no script 02) ------------
# A chave NUNCA deve ser escrita direto no script. Ela mora no arquivo
# ".Renviron" (fora do controle de versao -- ver .gitignore), lido
# automaticamente pelo R na inicializacao da sessao.
if (!file.exists(".Renviron") && file.exists(".Renviron.example")) {
  message(
    "Nao encontrei um '.Renviron' neste projeto (so' o modelo '.Renviron.example').\n",
    "Crie o seu com:\n",
    "  file.copy('.Renviron.example', '.Renviron')\n",
    "  usethis::edit_r_environ(scope = 'project')  # abre para voce colar a chave\n",
    "Depois REINICIE a sessao do R (Session > Restart R) e rode este script de novo."
  )
} else if (Sys.getenv("GEMINI_API_KEY") == "" && Sys.getenv("GOOGLE_API_KEY") == "") {
  message(
    "Aviso: GEMINI_API_KEY (ou GOOGLE_API_KEY) nao encontrada no ambiente.\n",
    "Edite o '.Renviron' do projeto (nao o script!) e adicione:\n",
    "  GEMINI_API_KEY=sua_chave_do_google_ai_studio\n",
    "Depois reinicie a sessao do R -- Sys.getenv() so' le o .Renviron no boot."
  )
} else {
  message("GEMINI_API_KEY encontrada. Pronto para rodar a classificacao.")
}

message("Setup concluido. Pacotes disponiveis: ", paste(pacotes_cran, collapse = ", "), ", acR")
