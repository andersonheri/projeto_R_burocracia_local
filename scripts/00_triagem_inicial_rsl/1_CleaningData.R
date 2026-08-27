# This script analysis the production on Bureaucracy in Brasil and LATAM
# This is part of the Chapter on XXXXXXX
# Last time run top to bottom: 21st jul 2026


##### Load datasets ######
library(dplyr)
library(readr)
library(stringr)
library(stringi)
library(ggplot2)
library(purrr)

##### Loading dataset #####
all_papers <- readRDS("Data/rawData/scielo_papers.RDS")



### Cleaning dataset #### ----

# standarising title and abstract -----
  all_papers <- all_papers %>%
    mutate(
      title_norm = stri_trans_general(title, "Latin-ASCII"),
      title_norm = stri_trans_tolower(title_norm),
      abstract_norm = stri_trans_general(abstract, "Latin-ASCII"),
      abstract_norm = stri_trans_tolower(abstract_norm))
  
# Checking for inconsistensies ----
  all_papers <- all_papers |>
    mutate(has_abstract = !is.na(abstract_norm),
      has_doi = !is.na(doi),
      title_len = nchar(title_norm),
      abstract_len = nchar(abstract_norm))
  
  
# Removing dplicates -----
  all_papers <- all_papers |>
    distinct(title, .keep_all = TRUE)
  
# Creating corpus with title + abstract -----
  all_papers <- all_papers %>%
    mutate(corpus_text = paste(title_norm, abstract_norm))
  
  
  
# Flagging papers: local and bureaucracy ----
  
  #creating terms -----
  bureau_terms <- c(
    "bureaucracy", "bureaucratic", "bureaucrat", "bureaucrats", "bureaucracies",
    "burocratas", "burocrata", "burocraticas", "burocraticos",
    "civil service", "civil servant", "civil servants",
    "public servant", "public servants",
    "public official", "public officials",
    "government official", "government officials",
    "public administration",
    "administrative capacity", "bureaucratic capacity",
    "bureaucratic professionalism", "professional bureaucracy",
    "merit bureaucracy", "merit system",
    "street-level bureaucracy", "street-level bureaucrat",
    "burocracia", "burocratico", "burocratica", "burocrata", "burocratas",
    "servidor publico", "servidores publicos",
    "funcionario publico", "funcionarios publicos",
    "administracao publica", "gestao publica", "nivel de rua", "street level", "gestor",
    "gestores", "gestoras", "teacher", "teachers", "professor", "professores", "professoras",
    "agentes de saude", "enfermeiro", "enfermeiras", "enfermeiros", "enfermeiras",
    "medicos", "medicas", "medico", "diretor", "diretora", "school principal",
    "servidor", "servidores", "servico", "servidor", "servidores", "public sector", "setor publico",
    "implementation", "policy implementation", "implementacao", "implementacao de politica publica"
  )
  
  level_terms <- c("local government", "local governments",
    "municipal government", "municipality", "municipalities",
    "municipal", "city government", "county government",
    "subnational government", "subnational", "city", "cidade",
    "regional government", "provincial government",
    "state government", "state-level", "local",
    "local administration", "municipal administration",
    "decentralized", "decentralisation", "decentralization",
    "governo local", "governo municipal", "governo estadual",
    "administracao municipal", "gestao municipal",
    "municipio", "municipios", "prefeitura", "prefeituras",
    "subnacional", "nivel de rua", "street level", "gestor de saude",
    "gestores", "gestoras", "teacher", "teachers", "professor", "professores", "professoras",
    "agentes de saude", "enfermeiro", "enfermeiras", "enfermeiros", "enfermeiras",
    "medicos", "medicas", "medico", "diretor", "diretora", "school principal",
    "servidores locais", "servico publico municipal", "servidor local", "servidores municipais", "public sector", "setor publico",
    "local implementation", "local policy implementation", "implementacao local", "implementacao de politica publica local", "city hall",
    "city halls", "digirente municipal", "dirigentes municipais", "local community", "mayor", "metropolis",
    "bombeiros", "prefeito", "prefeitos", "municipal officer", "municipal officers", "local official", "local officials",
    "frontline worker", "street-level bureaucrat", "cadunico")
  
  federal_terms <- c("presidente",
    "presidência", "presidencia", "governo federal", "governo da união", "união",
    "executivo federal", "poder executivo federal",
    "planalto", "palácio do planalto", "palacio do planalto", "ministério", "ministérios",
    "ministerio", "ministerios", "secretaria", "secretarias", "autarquia", "autarquias",
    "agência federal",    "agências federais", "agencia federal", "agencias federais",
    "empresa pública", "empresas públicas", "empresa publica", "empresas publicas",
    "órgão federal", "órgãos federais", "orgao federal",
    "orgaos federais", "administração pública federal", "administracao publica federal",
    "administração federal", "administracao federal", "serviço público federal",
    "servico publico federal", "servidor público",
    "servidor publico", "burocracia federal", "ibama",
    "receita federal", "incra", "inss", "dnit",
    "anvisa", "aneel", "anatel", "ans", "antt", "ana",
    "icmbio", "ipea", "funai", "polícia federal", "policia federal", "pf",
    "cgu",   "controladoria-geral da união", "agu", "advocacia-geral da união",
    "federal government", "federal bureaucracy",  "federal agency",
    "federal ministry", "public administration",  "federal civil service", "ministry", "ministries")
  
  bureau_regex <- str_c(bureau_terms, collapse = "|")
  level_regex  <- str_c(level_terms, collapse = "|")
  federal_regex <- str_c(federal_terms, collapse = "|")
  
  all_papers <- all_papers %>%
    mutate(
      bureau_match = str_detect(corpus_text, regex(bureau_regex, ignore_case = TRUE)),
      level_match  = str_detect(corpus_text, regex(level_regex, ignore_case = TRUE)),
      federal_match = str_detect(corpus_text, regex(federal_regex, ignore_case = TRUE)),
      local_bureaucracy = bureau_match & level_match,
    )
  
  #Subsetting for a only datataser with bure bureaucracy papers -----
  all_buro <- all_papers %>% filter(bureau_match == "TRUE")

## Save dataset for analysis -----
  write_rds(all_papers, "Data/AnalysisData/all_papers_category.RDS")
  write_rds(all_buro, "Data/AnalysisData/all_papers_bureaucracy.RDS")
  
  ###### END OF SCRIPT #######
  