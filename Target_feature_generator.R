#R 버전 문제, 혹은 bioconducter를 통해 설치해야해서, 설치되지 않는 package는 CRAN 통해 package dependency 설치해줘야함 
#원하는 protein에 대해 NCBI에 검색하면 gene symbol 검색가능

library(clusterProfiler)
library(org.Hs.eg.db)
library(ggnewscale)
library(dplyr); library(data.table)
library(AnnotationDbi)
library(DOSE)
library(UpSetR)
library(enrichplot)
library(ggupset)
library(writexl)
library(extrafont)
library(ggplot2)
library(stringr)
library(readxl)
library(topGO)
library(GSEABase)

#원하는 gene symbol 넣어줌, sample은 kymriah 보여줌
test.01 <- c("CD247", "TNFRSF9")

#다음 과정을 위해 symbol 형태의 GENE을 데이터를 패키지에 필요한 ENTREZID 형태로 전환, org.Hs.eg.db는 NCBI에서 Homo sapiens gene관련 DB 다운받은 것
eg = bitr(test.01, fromType="SYMBOL", toType="ENTREZID", OrgDb="org.Hs.eg.db")

#ENTREZID만 추출
test.02 <- eg$ENTREZID

#Disease association plot
#ENTREZID형태의 데이터를 enrich DGN함수에 넣어서 DisGeNet DB로 부터 유전자 관련 정보들을 import
test.03 <- enrichDGN(test.02)

#관련 disease들을 barplot 형태로 나타냄, showCategory 높일수록 더 많은 질병 보여줌, but 높일수록 관련성 낮아짐
barplot(test.03, showCategory=35)

test.04 <- setReadable(test.03, 'org.Hs.eg.db', 'ENTREZID')

#net형태의 그래프로 관련성을 표현, showCategory 설명 위와 같음
p1 <- cnetplot(test.04, foldChange=test.02)
cnetplot(test.04, showCategory = 35, foldChange=test.02)

#두 질병에 대해 확실하게 연관성이 있는 질병만 p-value 0.05 기준으로 잘라서 보여줌.
p2 <- cnetplot(test.04, categorySize="pvalue", foldChange=test.02)
cnetplot(test.04, categorySize="pvalue", foldChange=test.02)

#전반적으로 관련성 있는 질병들 모두 보여줌.
p3 <- cnetplot(test.04, foldChange=test.02, circular = TRUE, colorEdge = TRUE)
cnetplot(test.04, showCategory = 30, foldChange=NULL, circular = TRUE, colorEdge = TRUE)


