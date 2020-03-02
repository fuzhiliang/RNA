RNA shell pipeline

1、将所有样本拷贝到同一个目录下，统一命名为*_1.fq(.gz) 和 *_2.fq(.gz)  
2、将rnaseq_ballgown.R rnaseq_pipeline.config.sh rnaseq_pipeline.sh 放到同一个目录下  
3、修改配置文件 rnaseq_pipeline.config.sh  
run： 
sh rnaseq_pipeline.sh hg19_gff3_out_v3 >sh.log  
