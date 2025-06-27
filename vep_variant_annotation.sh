#!/bin/bash
# Aman Pruthi 18MAR2024
# Description - Variant annotation using Ensemble VEP
# Input - VCF files generated using GATK Haplotypecaller
# Output - Annotated VCF files, HTML summaries, filtered TSV files, Annotated-vcf files with AF and Depth

mkdir -p ${PWD}/Variant-analysis_VEP
grep -v '#' ${PWD}/*Sample-Info.txt > ${PWD}/Sample-Info-for-VEP.txt
sample_info_file=${PWD}/Sample-Info-for-VEP.txt

##########################################
# 1. Annotate VCF files using Esemble VEP
##########################################

while IFS= read -r line; do
	sample_id=$(echo "$line" | awk '{print $1}')
	echo "Processing sample ID: $sample_id"
	/home/act/software/apruthi/ensembl-vep-release-111.0/vep \
		-i vcf_Haplotypecaller/${sample_id}.vcf \
		-o ${PWD}/Variant-analysis_VEP/${sample_id}_vep_annotated.vcf \
		--format vcf --vcf --symbol --terms SO --tsl --biotype --hgvs \
		--fasta /home/act/database/hsa/genome/hg38/hisat2_index_exome_ucsc/hg38.fa --offline \
		--cache --dir_cache /home/act/database/vep --everything  \
		--dir_plugins /home/act/database/vep/Plugins --force_overwrite \
		>> ${PWD}/Variant-analysis_VEP/${sample_id}_VEP_annotation.log
done < $sample_info_file

##########################################
# 2. Filter annotated VCFs to generate TSV files for each unique variant
##########################################

while IFS= read -r line; do     
	sample_id=$(echo "$line" | awk '{print $1}')
	sed 's/|/\t/g' ${PWD}/Variant-analysis_VEP/${sample_id}_vep_annotated.vcf > ${PWD}/Variant-analysis_VEP/${sample_id}_tmp.vcf
	header=`paste <(tail -n+61 ${PWD}/Variant-analysis_VEP/${sample_id}_tmp.vcf | head -1| sed 's/FORMAT.*//g') <(tail -n+59 ${PWD}/Variant-analysis_VEP/${sample_id}_tmp.vcf | head -1| sed 's/^.*Con/Con/g'| sed 's/">//g')`
	cat <(echo $header| sed 's/ /\t/g') <(tail -n+62 ${PWD}/Variant-analysis_VEP/${sample_id}_tmp.vcf) | \
		cut -f1,2,4,5,6,7,9,10,11,18,19,25,29,77 > ${PWD}/Variant-analysis_VEP/${sample_id}_filtered.tsv; 
done < $sample_info_file

##########################################
# 3. Add missing info in filtered TSVs from VCFs generated from GATK Haplotypecaller
##########################################

mkdir -p ${PWD}/Variant-analysis_VEP/Results

while IFS= read -r line; do
	sample_id=$(echo "$line" | awk '{print $1}')
	grep -v '#' vcf_Haplotypecaller/${sample_id}.vcf | cut -f1,2,4,5,10 | sed 's/:/\t/g'| sed 's/,/\t/g'| cut -f1,2,3,4,5,6,7,8 | \
	awk '$9=$7/$8' OFS='\t' > ${PWD}/Variant-analysis_VEP/${sample_id}_tmp.tsv
	cat <(echo -e "Chr\tPos\tRef\tAlt\tGT\tDepth\tRefDepth\tAltDepth\tAF\tQual\tFilt\tConsequence\tImpact\tGene\tVariant_Transcript\tProtein_Change\tExisting_Variation\tVariation_Type\tClinical_Significance") \
	<(awk 'BEGIN {FS=OFS="\t"} NR==FNR {a[$1,$2]=$0; next} ($1,$2) in a {print a[$1,$2],$5,$6,$7,$8,$9,$10,$11,$12,$13,$14}' \
	${PWD}/Variant-analysis_VEP/${sample_id}_tmp.tsv ${PWD}/Variant-analysis_VEP/${sample_id}_filtered.tsv) \
	> ${PWD}/Variant-analysis_VEP/Results/${sample_id}_annotated-vcf.tsv
done < $sample_info_file

rm ${PWD}/Variant-analysis_VEP/*tmp*
rm ${PWD}/Sample-Info-for-VEP.txt