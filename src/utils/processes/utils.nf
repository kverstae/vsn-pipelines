nextflow.preview.dsl=2

import java.nio.file.Paths

if(!params.containsKey("test")) {
	binDir = "${workflow.projectDir}/src/utils/bin/"
} else {
	binDir = ""
}

process SC__FILE_CONVERTER {

	cache 'deep'
	container params.sc.scanpy.container
	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
	publishDir "${params.global.outdir}/data/intermediate", mode: 'symlink', overwrite: true

	input:
	tuple val(id), file(f)
	
	output:
	tuple val(id), file("${id}.SC__FILE_CONVERTER.${processParams.off}")
	
	script:
	processParams = params.sc.file_converter
	switch(processParams.iff) {
	
		case "10x_mtx":
			// Check if output was generated with CellRanger v2 or v3
			f_cellranger_outs_v2 = file("${f.toRealPath()}/${processParams.useFilteredMatrix ? "filtered" : "raw"}_gene_bc_matrices/")
			f_cellranger_outs_v3 = file("${f.toRealPath()}/${processParams.useFilteredMatrix ? "filtered" : "raw"}_feature_bc_matrix")
			
			if(f_cellranger_outs_v2.exists()) {
				genomes = f_cellranger_outs_v2.list()
				if(genomes.size() > 1 || genomes.size() == 0) {
					throw new Exception("None or multiple genomes detected for the output generated by CellRanger v2. Selecting custom genome is currently not implemented.")
				} else {
					f_cellranger_outs_v2 = file(Paths.get(f_cellranger_outs_v2.toString(), genomes[0]))
				}
				f = f_cellranger_outs_v2
			} else if(f_cellranger_outs_v3.exists()) {
				f = f_cellranger_outs_v3
			}

		break;
		
		case "csv":
		break;
		
		case "tsv":
		break;
		
		default:
		throw new Exception("The given input format ${processParams.iff} is not recognized.")
		break;

	}
	"""
	${binDir}sc_file_converter.py \
	--input-format $processParams.iff \
	--output-format $processParams.off ${f} "${id}.SC__FILE_CONVERTER.${processParams.off}"
	"""

}

process SC__FILE_CONVERTER_HELP {
	
	container params.sc.scanpy.container
	
	output:
	stdout()
	
	script:
	"""
	${binDir}sc_file_converter.py -h | awk '/-h/{y=1;next}y'
	"""

}

process SC__FILE_CONCATENATOR() {

	cache 'deep'
	container params.sc.scanpy.container
	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
	publishDir "${params.global.outdir}/data/intermediate", mode: 'symlink', overwrite: true

	input:
	file("*")
	
	output:
	tuple val(params.global.project_name), file("${params.global.project_name}.SC__FILE_CONCATENATOR.${processParams.off}")
	
	script:
	processParams = params.sc.file_concatenator
	"""
	${binDir}sc_file_concatenator.py \
		--file-format $processParams.off \
		${(processParams.containsKey('join')) ? '--join ' + processParams.join : ''} \
		--output "${params.global.project_name}.SC__FILE_CONCATENATOR.${processParams.off}" *
	"""

}

process SC__STAR_CONCATENATOR() {

	container "aertslab/sctx-scanpy:0.5.0"
	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
	publishDir "${params.global.outdir}/data/intermediate", mode: 'symlink', overwrite: true

	input:
	tuple val(id), file(f)
	
	output:
	tuple val(id), file("${params.global.project_name}.SC__STAR_CONCATENATOR.${processParams.off}")
	
	script:
	processParams = params.sc.star_concatenator
	id = params.global.project_name
	"""
	${binDir}sc_star_concatenator.py \
		--stranded ${processParams.stranded} \
		--output "${params.global.project_name}.SC__STAR_CONCATENATOR.${processParams.off}" $f
	"""

}

process SC__PUBLISH_H5AD {

    clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
    publishDir "${params.global.outdir}/data", mode: 'link', overwrite: true

    input:
    tuple val(id), file(fIn)
    val(fOutSuffix)

    output:
    tuple val(id), file("${id}.${fOutSuffix}.h5ad")
    
	script:
    """
    ln -s ${fIn} "${id}.${fOutSuffix}.h5ad"
    """

}
