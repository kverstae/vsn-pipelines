nextflow.preview.dsl=2

toolParams = params.sc.cellranger

process SC__CELLRANGER__MKFASTQ {

	publishDir "${params.global.outdir}/fastqs", saveAs: { outputF = file(it); "${outputF.getParent().getName()}/${outputF.name}" }, mode: 'link', overwrite: true
  	container toolParams.container

  	input:
		file(csv)
    	file(runFolder)

  	output:
    	path "*/outs/fastq_path/${flowCell}/*/*.fastq.gz"

  	script:
	  	rf = new File("${toolParams.mkfastq.runFolder}")
	  	runInfo = new File(rf, "RunInfo.xml").text
		flowCell = new XmlParser().parseText(runInfo).Run.Flowcell.text()

		"""
		cellranger mkfastq \
			--run=${runFolder} \
			--csv=${csv} \
			${(toolParams.mkfastq.containsKey('runID')) ? '--id ' + toolParams.mkfastq.runID: params.global.containsKey('project_name') ? '--id ' + params.global.project_name: ''} \
			${(toolParams.mkfastq.containsKey('samplesheet')) ? '--samplesheet ' + toolParams.mkfastq.samplesheet: ''} \
			${(toolParams.mkfastq.containsKey('ignoreDualIndex')) ? '--ignore-dual-index ' + toolParams.mkfastq.ignoreDualIndex: ''} \
			${(toolParams.mkfastq.containsKey('qc')) ? '--qc ' + toolParams.mkfastq.qc: ''} \
			${(toolParams.mkfastq.containsKey('lanes')) ? '--lanes ' + toolParams.mkfastq.lanes: ''} \
			${(toolParams.mkfastq.containsKey('useBasesMask')) ? '--use-bases-mask ' + toolParams.mkfastq.useBasesMask: ''} \
			${(toolParams.mkfastq.containsKey('deleteUndetermined')) ? '--delete-undetermined ' + toolParams.mkfastq.deleteUndetermined: ''} \
			${(toolParams.mkfastq.containsKey('outputDir')) ? '--output-dir ' + toolParams.mkfastq.outputDir: ''} \
			${(toolParams.mkfastq.containsKey('project')) ? '--project ' + toolParams.mkfastq.project: ''} \
			${(toolParams.mkfastq.containsKey('jobMode')) ? '--jobmode ' + toolParams.mkfastq.jobMode: ''} \
			${(toolParams.mkfastq.containsKey('localCores')) ? '--localcores ' + toolParams.mkfastq.localCores: ''} \
			${(toolParams.mkfastq.containsKey('localMem')) ? '--localmem ' + toolParams.mkfastq.localMem: ''}
	
		"""


}
