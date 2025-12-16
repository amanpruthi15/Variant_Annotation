#!/bin/bash
# Aman Pruthi 12AUG2025
# Description: Annotate variants using VEP and summarize the annotations into an excel output
# Usage: bash vep_variant_annotation.sh Sample-Info.txt

Sample_Info_File="$1"
Date=$(date +"%Y-%m-%d")
Log_File="variant_annotation_pipeline_${Date}_$(date +"%H-%M-%S").log"
mkdir -p "${PWD}/Variant-analysis_VEP"

exec > >(tee -a "$Log_File") 2>&1

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

log "Pipeline started."
log "Sample info file: $Sample_Info_File"

Sample_Info=$(tail -n+2 "$Sample_Info_File" | cut -f1)

# Prompt all questions upfront
read -p "Do you want to run annotation? (y/n): " run_annotation
read -p "Do you want to summarize annotated variants? (y/n): " run_summary

if [[ "$run_summary" =~ ^[Yy]$ ]]; then
    read -p "Is this an annotation for the CAP-PT samples? (y/n): " is_cap_pt
    if [[ "$is_cap_pt" =~ ^[Yy]$ ]]; then
        read -p "Please provide path to the list of transcripts: " transcript_file
        log "CAP-PT transcript file: $transcript_file"
    fi
fi

# Validate user choices
if [[ "$run_annotation" =~ ^[Nn]$ ]] && [[ "$run_summary" =~ ^[Nn]$ ]]; then
    log "No action taken. Exiting."
    exit 0
fi

# ===========================
# Step 1: Annotation
# ===========================
if [[ "$run_annotation" =~ ^[Yy]$ ]]; then
    log "Annotation mode selected."

    for sample_id in $Sample_Info; do
        log "Running annotation for $sample_id"
        ensembl-vep-release-111.0/vep \
            -i vcf_Haplotypecaller/${sample_id}.vcf \
            -o ${PWD}/Variant-analysis_VEP/${sample_id}_vep_annotated.vcf \
            --format vcf --vcf --symbol --terms SO --tsl --biotype --hgvs \
            --fasta hg38.fa \
            --offline --refseq --cache \
            --dir_cache vep \
            --dir_plugins vep/Plugins \
            --plugin RefSeqHGVS \
            --plugin ReferenceQuality \
            --everything --force_overwrite \
            >> ${PWD}/Variant-analysis_VEP/${sample_id}_VEP_annotation.log 2>&1
        log "Finished annotation for $sample_id"
    done
fi

# ===========================
# Step 2: Summarization
# ===========================
if [[ "$run_summary" =~ ^[Yy]$ ]]; then
    log "Summarization mode selected."

    for sample_id in $Sample_Info; do
        log "Summarizing $sample_id"

        grep -v '#' Variant-analysis_VEP/${sample_id}_vep_annotated.vcf \
            | awk -F '\t' '{print $1,$2,$4,$5,$7,$10,$8}' OFS='\t' \
            | sed 's/AC..*CSQ=//g' \
            | awk -F'\t' 'BEGIN{OFS=FS} {$6 = gensub(/:/, "\t", "g", $6); print}' \
            | awk -F'\t' 'BEGIN{OFS=FS} {$7 = gensub(/,/, "\t", "g", $7); print}' \
            | cut -f1-9,12- \
            | awk -F'\t' 'BEGIN{OFS=FS} {$10 = gensub(/,/, "\t", "g", $10); print}' \
            > Variant-analysis_VEP/${sample_id}_tmp.tsv

        if [[ "$is_cap_pt" =~ ^[Yy]$ ]]; then
            awk -F'\t' -v list="$transcript_file" '
                BEGIN{OFS=FS;while((getline<list)>0)pats[++n]=$0}
                {out="";for(i=10;i<=NF;i++){for(p=1;p<=n;p++)if(index($i,pats[p])){out=out OFS $i;break}}
                 if(out!=""){for(i=1;i<=9;i++)printf "%s%s",$i,OFS;sub(/^\t/,"",out);print out}}
            ' Variant-analysis_VEP/${sample_id}_tmp.tsv > Variant-analysis_VEP/${sample_id}_filtered.tsv
        else
            cut -f-10 Variant-analysis_VEP/${sample_id}_tmp.tsv > Variant-analysis_VEP/${sample_id}_filtered.tsv
        fi

        sed 's/|/\t/g' Variant-analysis_VEP/${sample_id}_filtered.tsv \
            | cut -f-9,10-13,16,20,21,27,29,31,84 \
            > Variant-analysis_VEP/${sample_id}_final.tsv

        {
            echo -e "Chr\tPosition\tRef\tAlt\tFilter\tGenotype\tRef_Depth\tAlt_Depth\tTotal_Depth\tNucleotide_Change\tVariant_Classification\tImpact\tGene\tTranscript_ID\tCDS_Change\tProtein_Change\tdbSNP\tStrand\tVariant_Type\tClinical_Significance"
            cat Variant-analysis_VEP/${sample_id}_final.tsv
        } > Variant-analysis_VEP/${sample_id}_final_with_header.tsv
    done

    log "Summarization complete."

    mkdir -p "${PWD}/Variant-analysis_VEP/Results"
    mv ${PWD}/Variant-analysis_VEP/*header.tsv ${PWD}/Variant-analysis_VEP/Results
    rename '_final_with_header' '' ${PWD}/Variant-analysis_VEP/Results/*tsv

    log "Combining VEP summaries into Excel."
    python3 combine_text_to_excel.py ${PWD}/Variant-analysis_VEP/Results/ "${Date}_vep_summaries.xlsx" tsv

fi

log "Pipeline finished."
