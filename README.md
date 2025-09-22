# VEP Variant Annotation & Summarization Pipeline

## Overview
This pipeline automates the process of:

- Annotating variants from VCF files using **Ensembl VEP** with the **NCBI RefSeq** database.
- Filtering annotated variants according to a transcript list (**CAP-PT** samples) or outputting unfiltered results (**general R&D**).
- Summarizing results into tabular format and combining them into a single Excel report.

The script prompts for all required input parameters at the start and executes the selected steps sequentially.

---

## Features
- Supports per-sample **VEP annotation** from a provided sample info file.
- Uses **NCBI RefSeq IDs** for transcripts & proteins (**CAP-PT compliant**).
- Optional transcript list filtering for CAP-PT samples.
- Generates:
  - Annotated VCF files
  - TSV summary tables
  - Combined Excel report

---

## Requirements

### Software
- `bash` (v4+)
- `awk`, `sed`, `grep`, `cut`
- [VEP (Ensembl Variant Effect Predictor)](https://www.ensembl.org/info/docs/tools/vep/index.html)
- Python 3 with:
  - `pandas`
  - `openpyxl`

### Databases
- **NCBI RefSeq** FASTA reference genome
- **VEP cache directory**
- **VEP plugins directory** (including `RefSeqHGVS` and `ReferenceQuality`)

---

## Input

### 1. Sample Info File (tab-delimited, `.txt`)
- **First column:** `Sample_ID`
- One sample per line (header in the first row)

**Example:**
Sample_ID
SampleA
SampleB

### 2. VCF Files
- Located in: `{vcf_input}/`
- Naming convention: `{Sample_ID}.vcf`

### 3. Transcript List *(optional, for CAP-PT filtering)*
- Text file with one transcript ID per line (**NCBI RefSeq IDs**)

---

## Output
- **Annotated VCFs:** `Variant-analysis_VEP/{Sample_ID}_vep_annotated.vcf`
- **Filtered TSVs:** `Variant-analysis_VEP/Results/{Sample_ID}.tsv`
- **Combined Excel file:** `{DATE}_vep_summaries.xlsx`

---

## Usage
```bash
bash vep_variant_annotation.sh Sample-Info.txt vcf_input
# Prompts:
# Do you want to run annotation? (y/n): y
# Do you want to summarize annotated variants? (y/n): y
# Is this an annotation for the CAP-PT samples? (y/n): y
# Please provide path to the list of transcripts: transcripts.txt
```

## Workflow Prompts
When running the script, you will be prompted with the following:

1. **Run annotation?** (`y/n`)
   - **y**: Run VEP on all samples in the Sample Info File.
   - **n**: Skip annotation.

2. **Summarize annotated variants?** (`y/n`)
   - **y**: Summarize and optionally filter (CAP-PT mode).
   - **n**: Skip summarization.

3. **Is this CAP-PT?** (`y/n`) *(only shown if summarization = y)*
   - **y**: Prompt for transcript list file for filtering.
   - **n**: Output all results without transcript-based filtering.

