#!/usr/bin/env nextflow

/*
 * MSI and TMB Nextflow pipeline
 * Input: BAM or VCF → MSI score + TMB calculation → Report
 */
nextflow.enable.dsl=2
params.bams   = "s3://aws-batch-input-bioinformatics/data/TRBOGG.bam"      // Or use VCFs
params.bai   = "s3://aws-batch-input-bioinformatics/data/TRBOGG.bam.bai"
params.genome = "s3://aws-batch-input-bioinformatics/genomics_ref_data/hg38.fa"
params.outdir = "s3://aws-batch-input-bioinformatics/tmd_msi/"
params.vcf     = "s3://aws-batch-input-bioinformatics/data/TRBOGG.hard-filtered.vcf.gz"

process MSI_ANALYSIS {
    
    container "539323004046.dkr.ecr.us-east-1.amazonaws.com/msi:latest"
    tag "${bam.simpleName}"
    

    input:
    path bam
    path bai
    path genome_file

    output:
    // Collect all files generated with the sample prefix
    path("${bam.simpleName}_output*")

    publishDir "${params.outdir}/msi", mode: 'copy'
    
    script:
    """
    echo "### MSI Analysis for ${bam.simpleName} ###"

    # Step 1: Scan genome to generate microsatellite reference, one time _microsatellites.list file geneation is enough
    msisensor-pro scan -d ${genome_file} -o ${bam.simpleName}_microsatellites.list

    # Step 2: Tumor-only MSI evaluation (PRO)
    msisensor-pro pro -d ${bam.simpleName}_microsatellites.list -t ${bam} -o ${bam.simpleName}_output

    echo "MSI Analysis completed for ${bam.simpleName}"
    """
}

process TMB_CALCULATION {
    container '539323004046.dkr.ecr.us-east-1.amazonaws.com/tmb-micromamba:latest'
    
    input:
    path vcf

    output:
    path "*.tmb.txt"   // publish any TMB result file

    publishDir "${params.outdir}/tmb", mode: 'copy'  // copy results to S3 or local dir

    script:
    """
    echo "### TMB Calculation for ${vcf.simpleName} ###"

    # Run your Python TMB script and save output to file
    python3 /usr/local/bin/calc_tmb.py ${vcf} > ${vcf.simpleName}.tmb.txt

    echo "TMB Calculation completed for ${vcf.simpleName}"
    """
}




workflow {
    bam_ch    = Channel.fromPath(params.bams)
    bai_ch    = Channel.fromPath(params.bai)
    vcf_ch    = Channel.fromPath(params.vcf)
    genome_ch = Channel.fromPath(params.genome)


    MSI_ANALYSIS(bam_ch, bai_ch, genome_ch)
    TMB_CALCULATION(vcf_ch)
}

