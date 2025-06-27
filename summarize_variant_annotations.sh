#!/bin/bash

# Aman Pruthi 10OCT2024
# Process the VEP and Funcotator output files
# Usage: Inside the merged_variants directory of the cfDNA project:
# $ bash summarize_variant_annotations.sh <Sample-Info.txt>

Sample_Info_File="$1"
Sample_Info=$(tail -n+2 "$Sample_Info_File" | cut -f1)
Date=$(date +"%Y-%m-%d")
Log_File="variant_annotation_$(date +"%Y-%m-%d_%H-%M-%S").log"

# Redirect both stdout and stderr to the log file
exec > >(tee -a "$Log_File") 2>&1

# Function to print log with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

log "Script started."

log "Generating VEP annotation summaries."

while read -r sample; do
    output_file="${sample}.vep.tsv"
    log "Processing VEP for sample: $sample"
    cat <(echo -e 'Chr\tPosition\tRef\tAlt\tQuality\tGenotype\tDepth\tRef_Depth\tAlt_Depth\tConsequence\tImpact\tGene\tBiotype\tHGVSc\tHGVSp\tExisting_variation\tStrand\tVariant_Classification\tHGNC_ID\tgnomADe_AF\tgnomADg_AF\tClinical_Significance') \
    <(grep -v '^#' "variants_${sample}.vep.vcf" | awk 'BEGIN{FS=OFS="\t"} {
        if (NF >= 8) {  # Ensure there are enough fields
            split($8, new_cols, /\|/);
            $8 = "";
            for (j=1; j<=length(new_cols); j++) $8 = $8 OFS new_cols[j];
            print $1, $2, $4, $5, $6, $10, new_cols[2], new_cols[3], new_cols[4], new_cols[8], new_cols[11], new_cols[12], new_cols[18], new_cols[20], new_cols[22], new_cols[24], new_cols[48], new_cols[57], new_cols[70];
        } else {
            print "Insufficient fields in line: " $0;  # Print warning for insufficient fields
        }
    }' | sed 's/HGNC://g' | sed 's/ENST.*:c/c/g' | sed 's/ENST.*:n/n/g' | sed 's/ENSP.*:p/p/g' | sed 's/:/\t/g' | cut -f1-7,9,11,14-26) > "$output_file"
    log "VEP summary saved for sample: $sample"
done <<< "$Sample_Info"

log "VEP annotation summaries completed."

log "Generating GATK Funcotator annotation summaries."

while read -r sample; do
    output_file="${sample}.funcotator.tsv"
    log "Processing Funcotator for sample: $sample"
    cat <(echo -e 'Chr\tPosition\tRef\tAlt\tQuality\tGene\tVariant_Classification\tVariant_Type\tTranscript_Strand\tcDNA_Change\tProtein_Change\tGermline_Mut\tClinVar_CLNSIG\tHGNC_ID\tdbSNP_ID\tGenotype\tRef_and_Alt_Depth\tAlt_Depth\tTotal_Depth') \
    <(grep -v '^#' "variants_${sample}.funcotated.vcf" | cut -f1,2,4,5,6,8,10 | sed 's/AB=.*\[//g' | sed 's/HGNC://g' | sed 's/|/\t/g' | \
    cut -f1,2,3,4,5,6,11,13,19,22,24,42,54,82,169,171 | sed 's/:/\t/g' | cut -f-19) > "$output_file"
    log "Funcotator summary saved for sample: $sample"
done <<< "$Sample_Info"

log "Funcotator annotation summaries completed."

# Move generated summaries into separate directories
mkdir -p funcotator vep
log "Moving Funcotator summaries to funcotator/ directory."
mv *funcotator.tsv funcotator/
log "Moving VEP summaries to vep/ directory."
mv *vep.tsv vep/

# Combine summaries into Excel sheets
log "Combining Funcotator summaries into Excel."
python3 /home/act/general-scripts/combine_text_to_excel.py funcotator "${Date}_funcotator_summaries.xlsx" tsv
log "Combining VEP summaries into Excel."
python3 /home/act/general-scripts/combine_text_to_excel.py vep "${Date}_vep_summaries.xlsx" tsv

log "Generated Excel summaries."

log "Script completed successfully."
