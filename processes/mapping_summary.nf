nextflow.preview.dsl=2

binDir = !params.containsKey("test") ? "${workflow.projectDir}/src/bwamaptools/bin/" : ""

toolParams = params.tools.bwamaptools

process SC__BWAMAPTOOLS__MAPPING_SUMMARY {

    container toolParams.container
    label 'compute_resources__default'

    input:
        tuple val(sampleId),
              path(bam),
              path(bai)

    output:
        tuple val(sampleId),
              path("${sampleId}.mapping_stats.tsv")

    script:
        def sampleParams = params.parseConfig(sampleId, params.global, toolParams.add_barcode_as_tag)
        processParams = sampleParams.local
        """
        ${binDir}mapping_summary.sh \
            ${sampleId} \
            ${bam} \
        """
}


