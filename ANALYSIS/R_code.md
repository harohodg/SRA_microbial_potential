Supp Figure 1 -> Estimated coverage and CheckM2 completion broken down by SRA library source + assay type (only top 7 displayed) for novel, successful Random and 1000X.
 
tb <- read.csv("~/Desktop/updated_pipeline_results_CUT_FILE_FOR_NOVEL_SUCCESSFUL_NO_TARANTELLAE.csv",header=TRUE)
tb$smash <- paste(tb$SRA_library_source,tb$SRA_assay_type)
ofinterest <- as.data.frame(head(tb %>% count(smash, sort = TRUE),n=7))$smash
tbnew <- tb[tb$smash %in% ofinterest,]
tbnew$smash <- factor(tbnew$smash, levels = ofinterest)
ggplot(tbnew,aes(cut_interval(log10(Estimated_cov),20),CHECKM_Completeness))+geom_boxplot()+facet_wrap(~smash, ncol = 1)+theme_bw()+theme(axis.text.x = element_text(angle = 45, hjust = 1))
 
Supp Figure 2A -> maximum contig length (from CheckM2) by successful/unsuccessful split by library source + assay type (only top 7 displayed) for novel 1000X.
 
Supp Figure 2B -> contig N50 (from CheckM2) by successful/unsuccessful split by library source + assay type (only top 7 displayed) for novel 1000X.
 
tb <- read.csv("~/Desktop/updated_pipeline_results_CUT_FILE_FOR_NOVEL_NO_TARANTELLAE.csv",header=TRUE)
tb$smash <- paste(tb$SRA_library_source,tb$SRA_assay_type)
ofinterest <- as.data.frame(head(tb %>% count(smash, sort = TRUE),n=7))$smash
tbnew <- tb[tb$smash %in% ofinterest,]
tbnew$smash <- factor(tbnew$smash, levels = ofinterest)
ggplot(tbnew,aes(smash,log10(CHECKM_Max_Contig_Length),col=successful))+geom_boxplot()+ coord_flip() +xlab("")
ggplot(tbnew,aes(smash,log10(CHECKM_Contig_N50),col=successful))+geom_boxplot()+ coord_flip() +xlab("")
